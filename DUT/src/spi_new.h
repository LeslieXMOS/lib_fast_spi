#ifndef _SPI_NEW_H_
#define _SPI_NEW_H_

#include <stdint.h>
#include <stdbool.h>
#include <platform.h>
#include <xcore/parallel.h>
#include <xcore/channel.h>
#include <xcore/port.h>
#include <xcore/clock.h>

typedef struct spi_xfer {
    size_t dev_id;
    uint8_t* tx_buf;
    uint8_t* rx_buf;
    size_t len;
} spi_xfer_t;

typedef enum spi_clock_source {
    spi_clock_source_core_clk,
    spi_clock_source_ref_clk
} spi_clock_source_t;

typedef struct spi_master_handle {
    port_t p_sck;
    port_t p_miso;
    port_t p_mosi;
    port_t p_cs;
    xclock_t clk_blk;
    spi_clock_source_t clk_src;
    unsigned clk_divider;
    uint32_t idle_clk_pattern;
    uint32_t cs_deassert_pattern;
} spi_master_handle_t;

typedef struct spi_master_device_handle {
    spi_master_handle_t* master;
    unsigned cs_bit_mask;
    spi_clock_source_t clk_src;
    unsigned clk_divider;
    uint32_t clk_pattern;
    uint32_t idle_clk_pattern;
    size_t input_delay_1B;
    size_t input_delay;
} spi_master_device_handle_t;

#define NEW_SPI_CALLBACK_ATTR __attribute__((fptrgroup("new_spi_callback")))
typedef struct {
    /** Pointer to the application's slave_transaction_started_t function to be called by the SPI device */
    NEW_SPI_CALLBACK_ATTR void (*xfer_started_cb)(void *app_data, uint8_t **out_buf, size_t *outbuf_len, uint8_t **in_buf, size_t *inbuf_len);

    /** Pointer to the application's slave_transaction_ended_t function to be called by the SPI device
     *  Note: The time spent in this callback must be less than the minimum CS deassertion to reassertion
     *  time.  If this is violated the first word of the proceeding transaction will be lost.
     */
    NEW_SPI_CALLBACK_ATTR void (*xfer_ended_cb)(void *app_data, size_t *out_len, uint8_t **in_buf, size_t *in_len);

    /** Pointer to application specific data which is passed to each callback. */
    void *app_data;
} new_spi_slave_callback_group_t;


typedef struct spi_slave_handle {
    port_t p_sck;
    port_t p_miso;
    port_t p_mosi;
    port_t p_cs;
    xclock_t clk_blk;
    uint32_t cs_val;
    uint32_t xfer_width;
    uint32_t xfer_idx;
    uint8_t* tx_buf;
    uint32_t tx_len;
    uint8_t* rx_buf;
    uint32_t rx_len;
    new_spi_slave_callback_group_t* callbacks;
} spi_slave_handle_t;

typedef enum {
    spi_slave_reg_idle,
    spi_slave_reg_wait_addr,
    spi_slave_reg_write,
    spi_slave_reg_read,
    spi_slave_reg_read_write
} spi_slave_reg_xfer_state_t;

typedef struct {
    void* a;
    void* b;
    size_t len;
    size_t shadow_idx;
} spi_slave_reg_t;

typedef struct spi_slave_reg_handle {
    port_t p_sck;
    port_t p_miso;
    port_t p_mosi;
    port_t p_cs;
    xclock_t clk_blk;
    uint32_t cs_val;
    uint32_t nop_cycle;
    spi_slave_reg_t* reg_map;
    size_t reg_map_len;
    spi_slave_reg_xfer_state_t xfer_state;
} spi_slave_reg_handle_t;

void new_spi_master_init(spi_master_handle_t* handle, port_t p_sck, port_t p_miso, port_t p_mosi, port_t p_cs, xclock_t clk_blk, bool cs_assert_low);
void new_spi_master_device_init(
    spi_master_handle_t* master,
    spi_master_device_handle_t* handle, 
    uint32_t cs_pin,
    uint8_t cpol, uint8_t cpha,
    spi_clock_source_t source_clk,
    uint32_t clk_divider
);
void new_spi_master_set_clk_div(spi_master_device_handle_t* handle, uint32_t clk_divider);
void new_spi_master_init_xfer(spi_master_device_handle_t* handle);
void new_spi_master_xfer(spi_master_device_handle_t* handle, uint8_t* tx_buf, uint8_t* rx_buf, size_t xfer_len);
DECLARE_JOB(new_spi_slave, (spi_slave_handle_t*, port_t, port_t, port_t, port_t, xclock_t, new_spi_slave_callback_group_t*, int, int));
void new_spi_slave(
    spi_slave_handle_t* handler,
    port_t p_sclk,
    port_t p_mosi,
    port_t p_miso,
    port_t p_cs,
    xclock_t cb_clk,
    new_spi_slave_callback_group_t* callbacks,
    int cpol,
    int cpha
);

DECLARE_JOB(spi_slave_reg, (spi_slave_reg_handle_t*, port_t, port_t, port_t, port_t, xclock_t, spi_slave_reg_t*, size_t, int, int, size_t, size_t));
void spi_slave_reg(
    spi_slave_reg_handle_t* handler,
    port_t p_sclk,
    port_t p_mosi,
    port_t p_miso,
    port_t p_cs,
    xclock_t cb_clk,
    spi_slave_reg_t* reg_map,
    size_t reg_map_len,
    int cpol,
    int cpha,
    size_t num_nop,
    size_t miso_offset // set to non zero when clk to data timing can't match with desire clk rate, can't use when num_nop is not zero
);

void spi_slave_update_reg(spi_slave_reg_handle_t* handler, uint32_t addr, size_t len);

#endif