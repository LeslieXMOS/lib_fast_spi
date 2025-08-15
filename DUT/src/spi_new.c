#include "spi_new.h"
#include <xcore/port.h>
#include <xcore/channel.h>
#include <xcore/select.h>
#include <xcore/port.h>
#include <xcore/port_protocol.h>
#include <xcore/triggerable.h>

void new_spi_master_init(spi_master_handle_t* handle, port_t p_sck, port_t p_miso, port_t p_mosi, port_t p_cs, xclock_t clk_blk, bool cs_assert_low) {
    handle->p_sck = p_sck;
    handle->p_miso = p_miso;
    handle->p_mosi = p_mosi;
    handle->p_cs = p_cs;
    handle->clk_blk = clk_blk;

    clock_enable(clk_blk);
    clock_set_divide(clk_blk, 0);
    clock_set_source_clk_ref(clk_blk);
    handle->clk_divider = 0;
    handle->clk_src = spi_clock_source_ref_clk;

    // sck
    port_start_buffered(p_sck, 32);
    port_out(p_sck, 0x0);
    port_sync(p_sck);
    port_set_clock(p_sck, clk_blk);
    // mosi
    port_start_buffered(p_mosi, 32);
    port_out(p_mosi, 0);
    port_sync(p_mosi);
    port_set_clock(p_mosi, clk_blk);
    // miso
    port_start_buffered(p_miso, 32);
    port_set_clock(p_miso, clk_blk);
    // cs
    handle->cs_deassert_pattern = cs_assert_low ? 0xFFFFFFFF : 0x0;
    port_enable(p_cs);
    port_out(p_cs, handle->cs_deassert_pattern);
    port_sync(p_cs);
    port_set_clock(p_cs, clk_blk);
}

void new_spi_master_device_init(
    spi_master_handle_t* master, 
    spi_master_device_handle_t* handle, 
    uint32_t cs_pin,
    uint8_t cpol, uint8_t cpha,
    spi_clock_source_t source_clk,
    uint32_t clk_divider
) {
    handle->master = master;
    handle->cs_bit_mask = master->cs_deassert_pattern ? ~(1 << cs_pin) : 1 << cs_pin;
    handle->clk_src = source_clk;
    new_spi_master_set_clk_div(handle, clk_divider);
    if (cpol == 0) {
        handle->clk_pattern = cpha == 0 ? 0xAAAAAAAA : 0x55555555;
        handle->idle_clk_pattern = 0x0;
    } else {
        handle->clk_pattern = cpha == 0 ? 0x55555555 : 0xAAAAAAAA;
        handle->idle_clk_pattern = 0xFFFFFFFF;
    }
}

void new_spi_master_set_clk_div(spi_master_device_handle_t* handle, uint32_t clk_divider) {
    handle->clk_divider = clk_divider;
    // input sample base on core clock to spi clock ratio
    unsigned core_div;
    unsigned ref_div;
    unsigned local_tile_id = get_local_tile_id();
    read_pswitch_reg(local_tile_id, XS1_PSWITCH_PLL_CLK_DIVIDER_NUM, &core_div);
    read_sswitch_reg(local_tile_id, XS1_SSWITCH_REF_CLK_DIVIDER_NUM, &ref_div);
    core_div += 1;
    ref_div += 1;
    if (handle->clk_src == spi_clock_source_ref_clk) {
        ref_div *= (handle->clk_divider + 1);
    } else {
        ref_div = core_div * (handle->clk_divider + 1);
    }
    uint32_t ratio = ref_div / core_div;
    if (handle->clk_src == spi_clock_source_ref_clk) {
        if (ratio < 3) {
            handle->input_delay = 32 + 2;
            handle->input_delay_1B = 16 + 2;
        } else if (ratio < 13) {
            handle->input_delay = 32 + 1;
            handle->input_delay_1B = 16 + 1;
        } else {
            handle->input_delay = 32;
            handle->input_delay_1B = 16;
        }
    } else {
        if (ratio < 4) {
            handle->input_delay = 32 + 2;
            handle->input_delay_1B = 16 + 2;
        } else if (ratio < 8) {
            handle->input_delay = 32 + 1;
            handle->input_delay_1B = 16 + 1;
        } else {
            handle->input_delay = 32;
            handle->input_delay_1B = 16;
        }
    }
}

void new_spi_master_init_xfer(spi_master_device_handle_t* handle) {
    if (handle->clk_src != handle->master->clk_src) {
        handle->master->clk_src = handle->clk_src;
        if (handle->clk_src == spi_clock_source_ref_clk) {
            clock_set_source_clk_ref(handle->master->clk_blk);
        } else {
            clock_set_source_clk_xcore(handle->master->clk_blk);
        }
    }
    if (handle->clk_divider != handle->master->clk_divider) {
        handle->master->clk_divider = handle->clk_divider;
        clock_set_divide(handle->master->clk_blk, handle->clk_divider);
    }
    if (handle->idle_clk_pattern != handle->master->idle_clk_pattern) {
        handle->master->idle_clk_pattern = handle->idle_clk_pattern;
        port_set_clock(handle->master->p_sck, XS1_CLKBLK_REF);
        port_out(handle->master->p_sck, handle->idle_clk_pattern);
        port_set_clock(handle->master->p_sck, handle->master->clk_blk);
        port_clear_buffer(handle->master->p_sck);
    }
    port_clear_buffer(handle->master->p_sck);
    port_clear_buffer(handle->master->p_mosi);
    port_endin(handle->master->p_miso);
    port_clear_buffer(handle->master->p_miso);
    port_clear_buffer(handle->master->p_miso);
}

extern unsigned spi_master_short_xfer(
    port_t p_sck,
    port_t p_miso,
    port_t p_mosi,
    port_t p_cs,
    xclock_t clk_blk,
    uint8_t* tx_buf,
    uint8_t* rx_buf,
    size_t xfer_len,
    size_t input_delay_1B,
    size_t input_delay,
    uint32_t clk_pattern,
    uint32_t finish_cs_pattern,
    uint32_t idle_clk_pattern
);

extern unsigned spi_master_burst_xfer(
    port_t p_sck,
    port_t p_miso,
    port_t p_mosi,
    port_t p_cs,
    xclock_t clk_blk,
    uint8_t* tx_buf,
    uint8_t* rx_buf,
    size_t xfer_len,
    size_t input_delay_1B,
    size_t input_delay,
    uint32_t clk_pattern,
    uint32_t finish_cs_pattern,
    uint32_t idle_clk_pattern
);

void new_spi_master_xfer(spi_master_device_handle_t* handle, uint8_t* tx_buf, uint8_t* rx_buf, size_t xfer_len) {
    port_out(handle->master->p_cs, handle->cs_bit_mask);
    if (xfer_len < 5) {
        spi_master_short_xfer(
            handle->master->p_sck,
            handle->master->p_miso,
            handle->master->p_mosi,
            handle->master->p_cs,
            handle->master->clk_blk,
            tx_buf, rx_buf, xfer_len,
            handle->input_delay_1B, handle->input_delay,
            handle->clk_pattern, handle->master->cs_deassert_pattern,
            handle->idle_clk_pattern
        );
    } else {
        spi_master_burst_xfer(
            handle->master->p_sck,
            handle->master->p_miso,
            handle->master->p_mosi,
            handle->master->p_cs,
            handle->master->clk_blk,
            tx_buf, rx_buf, xfer_len,
            handle->input_delay_1B, handle->input_delay,
            handle->clk_pattern, handle->master->cs_deassert_pattern,
            handle->idle_clk_pattern
        );
    }
}

#define ASSERTED 1

void new_spi_slave_set_xfer_width(
    spi_slave_handle_t* handler,
    uint32_t transfer_width
) {
    port_set_transfer_width(handler->p_mosi, transfer_width);
    port_set_transfer_width(handler->p_miso, transfer_width);
    handler->xfer_width = transfer_width;
}

void new_spi_slave(
    spi_slave_handle_t* handler,
    port_t p_sck,
    port_t p_mosi,
    port_t p_miso,
    port_t p_cs,
    xclock_t cb_clk,
    new_spi_slave_callback_group_t* callbacks,
    int cpol,
    int cpha
) {

    handler->p_sck = p_sck;
    handler->p_mosi = p_mosi;
    handler->p_miso = p_miso;
    handler->p_cs = p_cs;
    handler->clk_blk = cb_clk;
    handler->callbacks = callbacks;

    /* Setup the chip select port */
    port_enable(p_cs);
    port_set_invert(p_cs);

    /* Setup the SCLK port and associated clock block */
    port_enable(p_sck);
    clock_enable(cb_clk);
    clock_set_source_port(cb_clk, p_sck);
    clock_set_divide(cb_clk, 0);    /* Ensure divide is 0 */

    /* Setup the MOSI port */
    // port_start_buffered(p_mosi, 32);
    port_enable(p_mosi);
    port_protocol_in_strobed_slave(p_mosi, p_cs, cb_clk);
    // port_set_transfer_width(p_mosi, 32);

    port_set_clock(p_cs, cb_clk);
    /* Setup the MISO port */
    if (p_miso != 0) {
        port_enable(p_miso);
        port_protocol_out_strobed_slave(p_miso, p_cs, cb_clk, 0);
        // port_set_transfer_width(p_miso, 32);
    }

    new_spi_slave_set_xfer_width(handler, 32);

    if (cpol != cpha) {
        port_set_invert(p_sck);
    } else {
        port_set_no_invert(p_sck);
    }

    clock_start(cb_clk);

    port_sync(p_sck);

    /* Wait until CS is not asserted to begin */
    handler->cs_val = port_in_when_pinsneq(p_cs, PORT_UNBUFFERED, ASSERTED);

    // triggerable_enable_trigger(p_cs);
    port_set_trigger_in_not_equal(p_cs, handler->cs_val);
    
    triggerable_enable_trigger(p_mosi);

    // printf("started\n");
    uint32_t d_list[5] = {0};
    size_t d_cnt = 0;

    // SELECT_RES(
    //     CASE_THEN(p_cs, cs_handler),
    //     CASE_THEN(p_mosi, xfer_handler)) {
    //         cs_handler: {
    //             handler->cs_val = port_in(p_cs);
    //             handler->callbacks->xfer_started_cb(
    //                 handler->callbacks->app_data,
    //                 &handler->tx_buf, &handler->tx_len,
    //                 &handler->rx_buf, &handler->rx_len);
    //             handler->xfer_idx = 0;
    //             port_set_trigger_in_not_equal(p_cs, handler->cs_val);
    //             continue;
    //         }
    //         xfer_handler: {
    //             uint32_t d = port_in(p_mosi);
    //             uint32_t mask;
    //             asm volatile("mkmsk %0, %1": "=r"(mask) : "r"(handler->xfer_width));
    //             d = bitrev(d) & mask;
    //             uint32_t xfer_remain = handler->xfer_width;
    //             while (xfer_remain) {

    //             }
    //             continue;
    //         }
    //     }
}

extern unsigned spi_slave_reg_xfer(
    port_t p_miso,
    port_t p_mosi,
    port_t p_cs,
    void* reg_map,
    size_t reg_map_len,
    size_t num_nop,
    size_t miso_offset // set to non zero when clk to data timing can't match with desire clk rate, can't use when num_nop is not zero
);

static void set_pad_delay(port_t p, int pad_delay) {
    int c_word = XS1_SETC_MODE_LONG;
    c_word = XS1_SETC_LMODE_SET(c_word, XS1_SETC_LMODE_PIN_DELAY); 
    c_word = XS1_SETC_VALUE_SET(c_word, pad_delay); 
    // port_write_control_word(p, c_word); 
    asm volatile( "setc res[%0], %1" :: "r" (p), "r" (c_word));
}

static void set_clk_rise_delay(xclock_t clk, int delay) {
    int c_word = XS1_SETC_MODE_LONG;
    c_word = XS1_SETC_LMODE_SET(c_word, XS1_SETC_LMODE_RISE_DELAY); 
    c_word = XS1_SETC_VALUE_SET(c_word, delay);
    asm volatile( "setc res[%0], %1" :: "r" (clk), "r" (c_word));
}

static void set_clk_fall_delay(xclock_t clk, int delay) {
    int c_word = XS1_SETC_MODE_LONG;
    c_word = XS1_SETC_LMODE_SET(c_word, XS1_SETC_LMODE_FALL_DELAY); 
    c_word = XS1_SETC_VALUE_SET(c_word, delay);
    asm volatile( "setc res[%0], %1" :: "r" (clk), "r" (c_word));
}

void spi_slave_reg(
    spi_slave_reg_handle_t* handler,
    port_t p_sck,
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
) {
    handler->p_sck = p_sck;
    handler->p_mosi = p_mosi;
    handler->p_miso = p_miso;
    handler->p_cs = p_cs;
    handler->clk_blk = cb_clk;

    /* Setup the chip select port */
    port_enable(p_cs);
    port_set_invert(p_cs);

    /* Setup the SCK port and associated clock block */
    port_enable(p_sck);
    clock_enable(cb_clk);
    clock_set_source_port(cb_clk, p_sck);
    clock_set_divide(cb_clk, 0);    /* Ensure divide is 0 */

    /* Setup the MOSI port */
    port_enable(p_mosi);
    port_protocol_in_strobed_slave(p_mosi, p_cs, cb_clk);
    port_set_transfer_width(p_mosi, 32);

    // port_set_clock(p_cs, cb_clk);
    /* Setup the MISO port */
    if (p_miso != 0) {
        port_enable(p_miso);
        port_protocol_out_strobed_slave(p_miso, p_cs, cb_clk, 0);
        port_set_transfer_width(p_miso, 32);
    }

    if (cpol != cpha) {
        port_set_invert(p_sck);
    } else {
        port_set_no_invert(p_sck);
    }

    // set_clk_rise_delay(cb_clk, 1);
    // set_clk_fall_delay(cb_clk, 1);
    clock_start(cb_clk);

    port_sync(p_sck);

    /* Wait until CS is not asserted to begin */
    handler->cs_val = port_in_when_pinsneq(p_cs, PORT_UNBUFFERED, ASSERTED);

    triggerable_enable_trigger(p_cs);
    port_set_trigger_in_not_equal(p_cs, handler->cs_val);
    // printf("%d\n", handler->cs_val);
    
    triggerable_enable_trigger(p_mosi);

    // SELECT_RES(
    //     CASE_THEN(p_cs, cs_handler),
    //     CASE_THEN(p_mosi, xfer_handler)) {
    //         cs_handler: {
    //             handler->cs_val = port_in(p_cs);
    //             port_set_trigger_in_not_equal(p_cs, handler->cs_val);
    //             continue;
    //         }
    //         xfer_handler: {
    //             volatile uint32_t data = port_in(p_mosi);
    //             printf("%x\n", data);
    //             continue;
    //         }
    //     }

    set_pad_delay(p_mosi, 1);

    printf("r%x\n",spi_slave_reg_xfer(
        p_miso, p_mosi, p_cs,
        reg_map, reg_map_len,
        num_nop*8+1,
        miso_offset
    )
    );
    for (int i = 0; i < 4; ++i) {
        printf("%x\n", ((uint8_t*)reg_map)[i]);
    }
}


void spi_slave_update_reg(spi_slave_reg_handle_t* handler, uint32_t addr, size_t len) {
    // memcpy(&handler->reg_map->reg[addr], &handler->reg_map->shadow[addr], len);
}