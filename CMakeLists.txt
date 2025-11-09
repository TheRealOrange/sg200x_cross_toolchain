cmake_minimum_required(VERSION 3.25)
project(test_toolchain C)

set(CMAKE_C_STANDARD 17)

add_executable(test_exec test.c)
