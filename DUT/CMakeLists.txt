# cmake
cmake_minimum_required(VERSION 3.21)
include($ENV{XMOS_CMAKE_PATH}/xcommon.cmake)
project(dut)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# root
set(XMOS_SANDBOX_DIR ${CMAKE_SOURCE_DIR}/../sandbox)

# target
set(APP_HW_TARGET XK_VOICE_L71.xn)
set(APP_XSCOPE_SRCS basic.xscope)

# Dependencies
set(APP_DEPENDENT_MODULES 
)

# SPI master task x1, SPI slave task x1
# tile0 600MHz, tile1 600MHz
set(APP_COMPILER_FLAGS_test0 -O3 -mno-dual-issue -DSPI_TASK -DTILE_CLK_DIV=1)
# tile0 600MHz, tile1 off
set(APP_COMPILER_FLAGS_test1 -O3 -mno-dual-issue -DSPI_TASK -DTILE1_OFF)
# tile0 300MHz, tile1 off
set(APP_COMPILER_FLAGS_test2 -O3 -mno-dual-issue -DSPI_TASK -DTILE1_OFF -DTILE_CLK_DIV=2)
# tile0 200MHz, tile1 off
set(APP_COMPILER_FLAGS_test3 -O3 -mno-dual-issue -DSPI_TASK -DTILE1_OFF -DTILE_CLK_DIV=3)
# tile0 150MHz, tile1 off
set(APP_COMPILER_FLAGS_test4 -O3 -mno-dual-issue -DSPI_TASK -DTILE1_OFF -DTILE_CLK_DIV=4)
# tile0 120MHz, tile1 off
set(APP_COMPILER_FLAGS_test5 -O3 -mno-dual-issue -DSPI_TASK -DTILE1_OFF -DTILE_CLK_DIV=5)
# tile0 100MHz, tile1 off
set(APP_COMPILER_FLAGS_test6 -O3 -mno-dual-issue -DSPI_TASK -DTILE1_OFF -DTILE_CLK_DIV=6)
# PLL bypass on, tile0 24MHz, tile1 off
set(APP_COMPILER_FLAGS_test7 -O3 -mno-dual-issue -DSPI_TASK -DTILE1_OFF -DPLL_BYPASS_ON)

set(APP_COMPILER_FLAGS_xsim_test -O3 -mno-dual-issue -DSPI_TASK -DXSIM_ON)

XMOS_REGISTER_APP()
