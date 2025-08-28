#ifndef _FAST_SPI_H_
#define _FAST_SPI_H_

#include <stdint.h>
#include <stdbool.h>
#include <platform.h>
#include <xcore/parallel.h>
#include <xcore/channel.h>
#include <xcore/port.h>
#include <xcore/clock.h>

typedef struct fast_spi_xfer {
    size_t dev_id;
    uint8_t* tx_buf;
    uint8_t* rx_buf;
    size_t len;
} fast_spi_xfer_t;

typedef enum fast_spi_clock_source {
    fast_spi_clock_source_core_clk,
    fast_spi_clock_source_ref_clk
} fast_spi_clock_source_t;

typedef struct {
    port_t p_sck;
    port_t p_miso;
    port_t p_mosi;
    port_t p_cs;
    xclock_t clk_blk;
    fast_spi_clock_source_t clk_src;
    unsigned clk_divider;
    uint32_t idle_clk_pattern;
    uint32_t cs_deassert_pattern;
} fast_spi_master_handle_t;

typedef struct {
    fast_spi_master_handle_t* master;
    unsigned cs_bit_mask;
    fast_spi_clock_source_t clk_src;
    unsigned clk_divider;
    uint32_t clk_pattern;
    uint32_t idle_clk_pattern;
    size_t input_delay_1B;
    size_t input_delay;
} fast_spi_master_device_handle_t;

typedef struct {
    port_t p_sck;
    port_t p_miso;
    port_t p_mosi;
    port_t p_cs;
    xclock_t clk_blk;
    uint32_t cs_val;
    uint32_t nop_cycle;
    void* reg_map;
    size_t reg_map_len;
} fast_spi_slave_reg_handle_t;

void fast_spi_master_init(fast_spi_master_handle_t* handle, port_t p_sck, port_t p_miso, port_t p_mosi, port_t p_cs, xclock_t clk_blk, bool cs_assert_low);
void fast_spi_master_device_init(
    fast_spi_master_handle_t* master,
    fast_spi_master_device_handle_t* handle, 
    uint32_t cs_pin,
    uint8_t cpol, uint8_t cpha,
    fast_spi_clock_source_t source_clk,
    uint32_t clk_divider
);
void fast_spi_master_set_clk_div(fast_spi_master_device_handle_t* handle, uint32_t clk_divider);
void fast_spi_master_init_xfer(fast_spi_master_device_handle_t* handle);
void fast_spi_master_xfer(fast_spi_master_device_handle_t* handle, uint8_t* tx_buf, uint8_t* rx_buf, size_t xfer_len);

DECLARE_JOB(fast_spi_slave_reg, (fast_spi_slave_reg_handle_t*, port_t, port_t, port_t, port_t, xclock_t, void*, size_t, int, int, size_t, size_t));
void fast_spi_slave_reg(
    fast_spi_slave_reg_handle_t* handler,
    port_t p_sclk,
    port_t p_mosi,
    port_t p_miso,
    port_t p_cs,
    xclock_t cb_clk,
    void* reg_map,
    size_t reg_map_len,
    int cpol,
    int cpha,
    size_t num_nop,
    size_t miso_offset // set to non zero when clk to data timing can't match with desire clk rate, can't use when num_nop is not zero
);

void fast_spi_slave_update_reg(fast_spi_slave_reg_handle_t* handler, uint32_t addr, size_t len);

#endif