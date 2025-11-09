/*
 * Cross-compilation validation test for SG200x
 * Simple test to verify toolchain works correctly
 */

#include <stdio.h>
#include <stdlib.h>
#include <math.h>

// jank method to test if it is linked against musl libc or glibc
#define _GNU_SOURCE
#include <features.h>
#ifndef __USE_GNU
    // if __USE_GNU is not defined with _GNU_SOURCE, its probably musl
    #define __MUSL__
#endif
#undef _GNU_SOURCE

int main(void) {
    printf("s200x cross-compile test\n");
    
    // Detect architecture
#if defined(__aarch64__)
    printf("arch: arm64\n");
#elif defined(__riscv)
    printf("arch: riscv64\n");
#else
    printf("arch: something's wrong\n");
#endif

    // Detect C library
#if defined(__GLIBC__)
    printf("c lib: glibc %d.%d\n", __GLIBC__, __GLIBC_MINOR__);
#elif defined(__MUSL__)
    printf("c lib: musl\n");
#else
    printf("c lib: oopsies\n");
#endif
    
    // test fpu math
    double result = sqrt(16.0);
    if (result != 4.0) {
        printf("\ntest FAILED (sqrt(16) = %f)\n", result);
        return 1;
    }
    
    // test malloc
    void *ptr = malloc(1024);
    if (ptr == NULL) {
        printf("\nmemory allocation FAILED\n");
        return 1;
    }
    free(ptr);
    
    printf("\ntests PASSED\n");
    
    return 0;
}
