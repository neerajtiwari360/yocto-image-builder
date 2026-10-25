#include "distance.h"
int distance_from_echo(uint64_t rise,uint64_t fall,double *us,double *cm) {
    if(!rise || fall<=rise || !us || !cm) return -1;
    *us=(double)(fall-rise)/1000.0; *cm=*us/58.0;
    return 0;
}
