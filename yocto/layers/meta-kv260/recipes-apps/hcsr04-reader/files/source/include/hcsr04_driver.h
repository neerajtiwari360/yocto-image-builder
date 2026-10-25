#ifndef HCSR04_DRIVER_H
#define HCSR04_DRIVER_H
#include <stdint.h>
#include <signal.h>
/* Userspace GPIO hardware driver: raw timestamps only, no distance or CSV. */
typedef struct { int trigger_fd, echo_fd; uint64_t sent_ns; } hcsr04_device;
typedef struct { uint64_t rising_ns, falling_ns; } hcsr04_echo;
typedef enum { HCSR04_OK=0, HCSR04_IO_ERROR=-1, HCSR04_STUCK_HIGH=1,
    HCSR04_RISE_TIMEOUT=2, HCSR04_FALL_TIMEOUT=3, HCSR04_CANCELLED=4 } hcsr04_status;
/* Initializes verified KV260 J2.1/J2.3, trigger low and echo input. */
int hcsr04_open(hcsr04_device *device);
/* Clears stale events, checks ECHO idle, writes a >=10us TRIG pulse. */
hcsr04_status hcsr04_write_trigger(hcsr04_device *device);
/* Reads raw kernel edge timestamps, with a 40ms deadline from trigger. */
hcsr04_status hcsr04_read_echo(hcsr04_device *device, hcsr04_echo *echo,
                               const volatile sig_atomic_t *cancelled);
/* Attempts trigger low then releases both lines. */
void hcsr04_close(hcsr04_device *device);
#endif
