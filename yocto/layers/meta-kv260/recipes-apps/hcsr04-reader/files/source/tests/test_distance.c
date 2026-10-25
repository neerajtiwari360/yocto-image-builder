#include "distance.h"
#include <assert.h>
#include <math.h>
#include <stdio.h>
int main(void) {
    double us,cm;
    assert(!distance_from_echo(1000000000ULL,1003480000ULL,&us,&cm));
    assert(fabs(us-3480.0)<0.00001 && fabs(cm-60.0)<0.00001);
    assert(!distance_from_echo(1000000000ULL,1000116000ULL,&us,&cm));
    assert(fabs(cm-2.0)<0.00001);
    assert(distance_from_echo(0,10,&us,&cm)==-1);
    assert(distance_from_echo(10,10,&us,&cm)==-1);
    assert(distance_from_echo(20,10,&us,&cm)==-1);
    assert(distance_from_echo(10,20,0,&cm)==-1);
    puts("PASS: application distance conversion and invalid timestamps");
    return 0;
}
