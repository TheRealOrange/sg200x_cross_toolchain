set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR riscv64)

# use riscv64-none-linux-musl for riscstar toolchain
set(CROSS_PREFIX "riscv64-none-linux-gnu")

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
# optimise for c906 (sg2000 riscv64 cores)
set(CMAKE_C_FLAGS_INIT "--sysroot=${CMAKE_SYSROOT} -march=rv64imafdcv -O2 -pipe")
set(CMAKE_CXX_FLAGS_INIT "--sysroot=${CMAKE_SYSROOT} -march=rv64imafdcv -O2 -pipe")
set(CMAKE_EXE_LINKER_FLAGS_INIT "--sysroot=${CMAKE_SYSROOT}")
set(CMAKE_SHARED_LINKER_FLAGS_INIT "--sysroot=${CMAKE_SYSROOT}")

# release optimizations
set(CMAKE_C_FLAGS_RELEASE "-O3 -flto -ffunction-sections -fdata-sections")
set(CMAKE_CXX_FLAGS_RELEASE "-O3 -flto -ffunction-sections -fdata-sections")
set(CMAKE_EXE_LINKER_FLAGS_RELEASE "-Wl,--gc-sections -flto")
set(CMAKE_SHARED_LINKER_FLAGS_RELEASE "-Wl,--gc-sections -flto")

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
