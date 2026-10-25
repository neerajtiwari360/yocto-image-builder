#define _POSIX_C_SOURCE 200809L
#include "hcsr04_driver.h"
#include "distance.h"
#include <errno.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
static volatile sig_atomic_t stopped;
static void on_signal(int sig) { (void)sig; stopped=1; }
static const char *status_text(hcsr04_status status) {
    switch(status) {
    case HCSR04_STUCK_HIGH: return "echo_stuck_high";
    case HCSR04_RISE_TIMEOUT: return "rise_timeout";
    case HCSR04_FALL_TIMEOUT: return "fall_timeout";
    case HCSR04_CANCELLED: return "cancelled";
    default: return "io_error";
    }
}
int main(int argc,char **argv) {
    if((argc!=3 && argc!=4) || strcmp(argv[1],"--confirm-protected-wiring")) {
        fprintf(stderr,"Usage: %s --confirm-protected-wiring --wait|--samples=N [--period-ms=61..1000]\n"
            "Requires verified J2 wiring, ECHO divider, GY-521 disconnected.\n",argv[0]); return 2;
    }
    int wait_mode=!strcmp(argv[2],"--wait"),count=10;
    if(!wait_mode) {
        char *end; if(strncmp(argv[2],"--samples=",10)) return 2;
        errno=0; long n=strtol(argv[2]+10,&end,10);
        if(errno || end==argv[2]+10 || *end || n<1 || n>10000) return 2;
        count=(int)n;
    }
    long period_ms=100;
    if(argc==4) {
        char *end;
        if(strncmp(argv[3],"--period-ms=",12)) return 2;
        errno=0; period_ms=strtol(argv[3]+12,&end,10);
        if(errno || end==argv[3]+12 || *end || period_ms<61 || period_ms>1000) {
            fprintf(stderr,"Period must be 61..1000 ms (>60ms sensor guidance).\n"); return 2;
        }
    }
    struct sigaction sa={0}; sa.sa_handler=on_signal; sigemptyset(&sa.sa_mask);
    sigaction(SIGINT,&sa,NULL); sigaction(SIGTERM,&sa,NULL); sigaction(SIGHUP,&sa,NULL);
    hcsr04_device device;
    if(hcsr04_open(&device)) { perror("open HC-SR04 hardware"); return 1; }
    fprintf(stderr,"READY: J2.1 TRIG held LOW; J2.3 ECHO input with kernel edge timestamps.\n");
    if(wait_mode) {
        fprintf(stderr,"No pulses yet. Waiting for ENTER after sensor power is confirmed (10 readings).\n");
        if(getchar()==EOF) stopped=1;
    }
    puts("sample,echo_us,distance_cm,status,trigger_monotonic_ns,echo_rising_ns,echo_falling_ns"); fflush(stdout);
    int errors=0;
    for(int i=0;i<count && !stopped;i++) {
        struct timespec cycle;
        if(clock_gettime(CLOCK_MONOTONIC,&cycle)) { errors++; break; }
        uint64_t cycle_ns=(uint64_t)cycle.tv_sec*1000000000ULL+(uint64_t)cycle.tv_nsec;
        hcsr04_echo echo={0};
        hcsr04_status status=hcsr04_write_trigger(&device);
        uint64_t trigger_ns=device.sent_ns;
        if(status==HCSR04_OK) status=hcsr04_read_echo(&device,&echo,&stopped);
        if(status==HCSR04_OK) {
            double us,cm;
            if(distance_from_echo(echo.rising_ns,echo.falling_ns,&us,&cm)) {
                printf("%d,,,invalid_timestamps,%llu,%llu,%llu\n",i,(unsigned long long)trigger_ns,(unsigned long long)echo.rising_ns,(unsigned long long)echo.falling_ns); errors++;
            } else {
                const char *label=(cm>=2.0 && cm<=400.0)?"ok":"out_of_range";
                printf("%d,%.3f,%.2f,%s,%llu,%llu,%llu\n",i,us,cm,label,(unsigned long long)trigger_ns,(unsigned long long)echo.rising_ns,(unsigned long long)echo.falling_ns);
                if(strcmp(label,"ok")) errors++;
            }
        } else {
            printf("%d,,,%s,%llu,%llu,%llu\n",i,status_text(status),(unsigned long long)trigger_ns,(unsigned long long)echo.rising_ns,(unsigned long long)echo.falling_ns); errors++;
            if(status==HCSR04_IO_ERROR) { perror("GPIO transfer"); break; }
            if(status==HCSR04_CANCELLED) break;
        }
        fflush(stdout);
        /* No catch-up bursts: pace from this attempt, including echo time.
           sent_ns is sampled just before the GPIO write, so this measures
           host trigger-request timing, not the electrical pulse edge. */
        uint64_t next=(trigger_ns?trigger_ns:cycle_ns)+(uint64_t)period_ms*1000000ULL;
        struct timespec deadline={.tv_sec=(time_t)(next/1000000000ULL),
                                  .tv_nsec=(long)(next%1000000000ULL)};
        int rc;
        while(!stopped && (rc=clock_nanosleep(CLOCK_MONOTONIC,TIMER_ABSTIME,&deadline,NULL))==EINTR) {}
        (void)rc;
    }
    hcsr04_close(&device);
    fprintf(stderr,"Finished; invalid/failed readings=%d. Trigger set low before release.\n",errors);
    return (errors || stopped)?1:0;
}
