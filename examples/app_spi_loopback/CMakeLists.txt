# cmake
cmake_minimum_required(VERSION 3.21)
include($ENV{XMOS_CMAKE_PATH}/xcommon.cmake)
project(app_spi_loopback)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# root
set(XMOS_SANDBOX_DIR ${CMAKE_SOURCE_DIR}/../../../)

# target
set(APP_HW_TARGET XK_VOICE_L71.xn)
set(APP_XSCOPE_SRCS basic.xscope)

# Dependencies
set(APP_DEPENDENT_MODULES 
    "lib_fast_spi"
)

set(APP_COMPILER_FLAGS -Os -g -DNUM_NOP=4)

XMOS_REGISTER_APP()
