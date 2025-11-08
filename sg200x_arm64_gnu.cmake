set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

# use aarch64-none-linux-gnu for arm's official toolchain
set(CROSS_PREFIX "aarch64-none-linux-gnu")

set(CMAKE_SYSROOT /opt/sysroot)
set(CMAKE_FIND_ROOT_PATH ${CMAKE_SYSROOT})

set(CMAKE_C_COMPILER ${CROSS_PREFIX}-gcc)
set(CMAKE_CXX_COMPILER ${CROSS_PREFIX}-g++)
set(CMAKE_AR ${CROSS_PREFIX}-ar)
set(CMAKE_RANLIB ${CROSS_PREFIX}-ranlib)
set(CMAKE_STRIP ${CROSS_PREFIX}-strip)
set(CMAKE_OBJCOPY ${CROSS_PREFIX}-objcopy)
set(CMAKE_OBJDUMP ${CROSS_PREFIX}-objdump)

# force the compiler to use only the sysroot
# optimise for cortex-a53 (sg2000 arm64 cores)
set(CMAKE_C_FLAGS_INIT "--sysroot=${CMAKE_SYSROOT} -mcpu=cortex-a53")
set(CMAKE_CXX_FLAGS_INIT "--sysroot=${CMAKE_SYSROOT} -mcpu=cortex-a53")
set(CMAKE_EXE_LINKER_FLAGS_INIT "--sysroot=${CMAKE_SYSROOT}")
set(CMAKE_SHARED_LINKER_FLAGS_INIT "--sysroot=${CMAKE_SYSROOT}")

# search for programs only in the build host directories
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)

# search for libraries and headers only in the target directories
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

message(STATUS "Using toolchains:")
message(STATUS "    CMAKE_SYSROOT: ${CMAKE_SYSROOT}")
message(STATUS "    CMAKE_FIND_ROOT_PATH: ${CMAKE_FIND_ROOT_PATH}")
message(STATUS "    CMAKE_C_COMPILER: ${CMAKE_C_COMPILER}")
message(STATUS "    CMAKE_CXX_COMPILER: ${CMAKE_CXX_COMPILER}")
execute_process(
        COMMAND ${CMAKE_C_COMPILER} --sysroot=${CMAKE_SYSROOT} -print-file-name=libc.so
        OUTPUT_VARIABLE LIBC_PATH
        OUTPUT_STRIP_TRAILING_WHITESPACE
)
message(STATUS "    libc.so path: ${LIBC_PATH}")