/* GPIO read/write driver; Linux 5.15 ABI v1. */
#define _POSIX_C_SOURCE 200809L
#include "hcsr04_driver.h"
#include <errno.h>
#include <fcntl.h>
#include <linux/gpio.h>
#include <poll.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <time.h>
#include <unistd.h>
static uint64_t now_ns(void) {
    struct timespec ts; if(clock_gettime(CLOCK_MONOTONIC,&ts)) return 0;
    return (uint64_t)ts.tv_sec*1000000000ULL+(uint64_t)ts.tv_nsec;
}
static int set_trig(int fd, int level) {
    struct gpiohandle_data data={0}; data.values[0]=(unsigned char)level;
    return ioctl(fd,GPIOHANDLE_SET_LINE_VALUES_IOCTL,&data);
}
static int edge(int fd, uint64_t deadline, struct gpioevent_data *ev, const volatile sig_atomic_t *cancelled) {
    while(!*cancelled) {
        uint64_t now=now_ns(); if(now>=deadline) return 0;
        struct pollfd p={.fd=fd,.events=POLLIN};
        int rc=poll(&p,1,(int)((deadline-now+999999)/1000000));
        if(rc<0) { if(errno==EINTR) continue; return -1; }
        if(!rc) continue;
        if(p.revents & (POLLERR|POLLHUP|POLLNVAL)) { errno=EIO; return -1; }
        ssize_t n=read(fd,ev,sizeof(*ev));
        if(n==(ssize_t)sizeof(*ev)) return 1;
        if(n<0 && (errno==EAGAIN || errno==EINTR)) continue;
        errno=EIO; return -1;
    }
    return 0;
}
int hcsr04_open(hcsr04_device *device) {
    if(!device) { errno=EINVAL; return -1; }
    *device=(hcsr04_device){.trigger_fd=-1,.echo_fd=-1,.sent_ns=0};
    FILE *f=fopen("/proc/device-tree/fpga-region/firmware-name","rb");
    char firmware[128]={0}; if(!f) { perror("firmware"); return -1; }
    size_t bytes=fread(firmware,1,sizeof(firmware)-1,f);
    int failed=ferror(f); fclose(f);
    if(failed || !bytes || bytes==sizeof(firmware)-1) { errno=EIO; return -1; }
    if(strcmp(firmware,"ubiety-gy521-emio.bit.bin")) { fprintf(stderr,"Expected verified EMIO app; refusing GPIO access\n"); return -1; }
    const char *overlays[]={"ubiety-gy521-i2c","gy521-i2c","dht11-j2-pin1"};
    for(size_t i=0;i<3;i++) { char path[256]; snprintf(path,sizeof(path),"/sys/kernel/config/device-tree/overlays/%s",overlays[i]);
        if(!access(path,F_OK)) { fprintf(stderr,"Conflicting sensor overlay: %s\n",path); return -1; } }
    int chip=-1, matches=0;
    for(int i=0;i<32;i++) { char path[64]; snprintf(path,sizeof(path),"/dev/gpiochip%d",i);
        int fd=open(path,O_RDONLY|O_CLOEXEC); if(fd<0) continue;
        struct gpiochip_info info={0};
        if(!ioctl(fd,GPIO_GET_CHIPINFO_IOCTL,&info) && !strcmp(info.label,"zynqmp_gpio") && info.lines==174) {
            matches++; if(chip>=0) close(chip); chip=fd;
        } else close(fd);
    }
    if(matches!=1) { fprintf(stderr,"Expected exactly one zynqmp_gpio controller with 174 lines\n"); if(chip>=0) close(chip); return -1; }
    /* Claim echo input before requesting trigger output. Busy lines fail safely. */
    struct gpioevent_request echo={0}; echo.lineoffset=79;
    echo.handleflags=GPIOHANDLE_REQUEST_INPUT; echo.eventflags=GPIOEVENT_REQUEST_BOTH_EDGES;
    strcpy(echo.consumer_label,"hcsr04-echo");
    if(ioctl(chip,GPIO_GET_LINEEVENT_IOCTL,&echo)) { perror("claim ECHO input/events"); close(chip); return -1; }
    int flags=fcntl(echo.fd,F_GETFL); if(flags<0 || fcntl(echo.fd,F_SETFL,flags|O_NONBLOCK)<0) { perror("nonblock"); close(echo.fd); close(chip); return -1; }
    struct gpiohandle_request trig={0}; trig.lineoffsets[0]=78; trig.flags=GPIOHANDLE_REQUEST_OUTPUT;
    trig.lines=1; trig.default_values[0]=0; strcpy(trig.consumer_label,"hcsr04-trig");
    if(ioctl(chip,GPIO_GET_LINEHANDLE_IOCTL,&trig)) { perror("claim TRIG low"); close(echo.fd); close(chip); return -1; }
    close(chip);
    device->trigger_fd=trig.fd; device->echo_fd=echo.fd;
    return 0;
}
hcsr04_status hcsr04_write_trigger(hcsr04_device *device) {
    device->sent_ns=0;
    struct gpioevent_data ev;
    for(;;) {
        ssize_t n=read(device->echo_fd,&ev,sizeof(ev));
        if(n==(ssize_t)sizeof(ev)) continue;
        if(n<0 && errno==EINTR) continue;
        if(n<0 && errno==EAGAIN) break;
        errno=EIO; return HCSR04_IO_ERROR;
    }
    struct gpiohandle_data level={0};
    if(ioctl(device->echo_fd,GPIOHANDLE_GET_LINE_VALUES_IOCTL,&level)) return HCSR04_IO_ERROR;
    if(level.values[0]) return HCSR04_STUCK_HIGH;
    uint64_t sent=now_ns(); if(!sent) return HCSR04_IO_ERROR;
    if(set_trig(device->trigger_fd,1)) return HCSR04_IO_ERROR;
    uint64_t high=now_ns();
    if(!high) { (void)set_trig(device->trigger_fd,0); return HCSR04_IO_ERROR; }
    while(now_ns()-high<10000ULL) {}
    if(set_trig(device->trigger_fd,0)) return HCSR04_IO_ERROR;
    device->sent_ns=sent;
    return HCSR04_OK;
}
hcsr04_status hcsr04_read_echo(hcsr04_device *device,hcsr04_echo *echo,
                               const volatile sig_atomic_t *cancelled) {
    *echo=(hcsr04_echo){0};
    if(!device->sent_ns) { errno=EINVAL; return HCSR04_IO_ERROR; }
    uint64_t sent=device->sent_ns; device->sent_ns=0;
    struct gpioevent_data ev; int rc;
    while((rc=edge(device->echo_fd,sent+40000000ULL,&ev,cancelled))>0) {
        if(ev.timestamp<sent) continue;
        if(ev.id==GPIOEVENT_EVENT_RISING_EDGE) {
            if(echo->rising_ns) break;
            echo->rising_ns=ev.timestamp;
        } else if(ev.id==GPIOEVENT_EVENT_FALLING_EDGE && echo->rising_ns) {
            echo->falling_ns=ev.timestamp;
            if(echo->falling_ns>echo->rising_ns) return HCSR04_OK;
            break;
        }
    }
    if(rc<0) return HCSR04_IO_ERROR;
    if(*cancelled) return HCSR04_CANCELLED;
    return echo->rising_ns?HCSR04_FALL_TIMEOUT:HCSR04_RISE_TIMEOUT;
}
void hcsr04_close(hcsr04_device *device) {
    if(device->trigger_fd>=0) { (void)set_trig(device->trigger_fd,0); close(device->trigger_fd); }
    if(device->echo_fd>=0) close(device->echo_fd);
    device->trigger_fd=-1; device->echo_fd=-1; device->sent_ns=0;
}
