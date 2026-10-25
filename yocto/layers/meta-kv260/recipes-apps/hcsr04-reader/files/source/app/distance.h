#ifndef HCSR04_DISTANCE_H
#define HCSR04_DISTANCE_H
#include <stdint.h>
/* Application conversion. Returns -1 for reversed or missing timestamps. */
int distance_from_echo(uint64_t rise, uint64_t fall, double *us, double *cm);
#endif
