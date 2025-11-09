/*
 * Cross-compilation validation test for SG200x
 * Simple test to verify toolchain works correctly
 */

#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <errno.h>
#include <string.h>

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
        printf("\nfloating point math FAILED (sqrt(16) = %f)\n", result);
        return 1;
    }
    printf("floating point math PASSED\n");
    
    // test malloc
    void *ptr = malloc(1024);
    if (ptr == NULL) {
        printf("\nmemory allocation FAILED\n");
        return 1;
    }
    printf("\nmemory allocation PASSED\n");
    free(ptr);

    // test file i/o
    const char* test_file = "/tmp/cross_compile_test.txt";
    const char* test_str = "aevkoflhbvlypfnvuyktvlnstulhvs";
    FILE* f = fopen(test_file, "w");
    if (f == NULL) {
        printf("file i/o FAILED (cannot open file for writing /tmp): errno %d\n", errno);
        return 1;
    }
    fprintf(f, "%s", test_str);
    fclose(f);

    f = fopen(test_file, "r");
    if (f == NULL) {
        printf("file i/o FAILED (cannot open file for reading /tmp)\n");
        remove(test_file);
        return 1;
    }
    char buffer[100];
    if (fgets(buffer, sizeof(buffer), f) != NULL) {
        if (memcmp(buffer, test_str, strlen(test_str)) != 0) {
            printf("file i/o FAILED (read mismatch: \"%s\")\n", buffer);
            fclose(f);
            remove(test_file);
            return 1;
        }
        printf("file i/o PASSED\n");
    } else {
        printf("file i/o FAILED (failed to read back data)\n");
        fclose(f);
        remove(test_file);
        return 1;
    }
    fclose(f);
    remove(test_file);
    
    printf("\ntests PASSED\n");
    
    return 0;
}
