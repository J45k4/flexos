/* Ordinary Linux application fixture: no FlexOS APIs or platform hooks. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <sys/time.h>
static _Thread_local int tls_value = 17;
int main(int argc, char **argv) {
    char *p = malloc(300000);
    if (!p || argc != 1 || !argv[0] || tls_value != 17) return 71;
    memset(p, 42, 300000);
    tls_value = 23;
    struct timespec t;
    struct timeval wall;
    if (clock_gettime(CLOCK_MONOTONIC, &t) || gettimeofday(&wall, NULL)) return 72;
    if (p[299999] != 42 || tls_value != 23 || wall.tv_sec < 1700000000) return 73;
    printf("LIBC PASS: startup, TLS, malloc, stdio, clocks\n");
    free(p);
    return 0;
}
