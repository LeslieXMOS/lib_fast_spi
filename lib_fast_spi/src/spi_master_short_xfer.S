#define FUNCTION_NAME spi_master_short_xfer

/*
tx_buf and rx_buf needs to be word aligned, xfer_len > 0
void spi_master_short_xfer(
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
*/

    #define NSTACKWORDS 32

    #define RUN_STARTR 0x000f
    #define RUN_STOPR  0x0007

    .cc_top FUNCTION_NAME.function
    .type   FUNCTION_NAME,@function

    .issue_mode dual

    .align 4
    .align 16
    .globl FUNCTION_NAME
.globl FUNCTION_NAME.nstackwords
.set   FUNCTION_NAME.nstackwords, NSTACKWORDS
FUNCTION_NAME:
    { dualentsp NSTACKWORDS;}

    std r4, r5, sp[2]   // sp[5] sp[4]
    std r6, r7, sp[3]   // sp[7] sp[6]
    std r8, r9, sp[4]   // sp[9] sp[8]
    std r3, r10, sp[5]  // sp[11] sp[10]
    /*
     * r0: p_sck,
     * r1: p_miso,
     * r2: p_mosi,
     * : p_cs,
     * : clk_blk,
     * r3: tx_buf,
     * r4: rx_buf,
     * r5: xfer_len
     */
    //ldw r6, sp[NSTACKWORDS+1]
    ldw r3, sp[NSTACKWORDS+2]
    ldw r4, sp[NSTACKWORDS+3]
    ldw r5, sp[NSTACKWORDS+4]

prepare:
    { ldw r8, r3[0]         ; shl r6, r5, 4             }   // r8: tx_buf[0], r6: cs deassert clk_time
    { bitrev r8, r8         ; ldw r11, sp[NSTACKWORDS+7]}   // r11: clk_pattern
    { byterev r8, r8        ; add r6, r6, 1             }   // r6: cs deassert clk_time
    { add r9, r8, 0         ; eq r3, r5, 0x4            }   // r9 = r8, for zip operation
    zip r9, r8, 0
    { bt r3, xfer_4B        ; eq r3, r5, 0x3            }
    { bt r3, xfer_3B        ; eq r3, r5, 0x2            }
    { bt r3, xfer_2B        ; nop                       }

xfer_1B:
    outpw res[r0], r11, 16
    outpw res[r2], r8, 16
    { ldw r8, sp[NSTACKWORDS+5] ; nop                       }   // r8: input_delay_1B
    { setpt res[r1], r8         ; ldw r3, sp[NSTACKWORDS+1] }   // set input delay, r8 free now, r3: clk_blk
    { ldw r8, sp[11]            ; setc res[r3], RUN_STARTR  }   // r8: p_cs, clk start
    { ldw r7, sp[NSTACKWORDS+8] ; setpt res[r8], r6         }   // r7: cs_pattern, cs delay set
    { out res[r8], r7           ; ldw r10, sp[NSTACKWORDS+9]}
    outpw res[r0], r10, 1
    { in r8, res[r1]            ; nop                       }
    { bitrev r8, r8             ; ldc r9, 0                 }
    unzip r10, r8, 0
    st8 r8, r4[r9]
    bu exit

xfer_2B:
    { out res[r0], r11          ; ldw r10, sp[NSTACKWORDS+6]}   // r10: input_delay
    { out res[r2], r8           ; ldw r3, sp[NSTACKWORDS+1] }   // r3: clk_blk
    { setpt res[r1], r10        ; ldw r8, sp[11]            }   // set input delay, r8 free now, r8: p_cs
    { setc res[r3], RUN_STARTR  ; ldw r7, sp[NSTACKWORDS+8] }   // clk start, r7: cs_pattern
    { setpt res[r8], r6         ; nop                       }   // cs delay set
    { out res[r8], r7           ; ldw r10, sp[NSTACKWORDS+9]}
    outpw res[r0], r10, 1
    { in r8, res[r1]            ; nop                       }
    unzip r9, r8, 0
    { byterev r8, r8            ; nop                       }
    { bitrev r8, r8             ; ldc r9, 0                 }
    st16 r8, r4[r9]
    bu exit

xfer_3B:
    { out res[r0], r11          ; ldw r10, sp[NSTACKWORDS+6]}   // r10: input_delay
    { out res[r2], r8           ; ldw r3, sp[NSTACKWORDS+1] }   // r3: clk_blk
    { setpt res[r1], r10        ; ldw r8, sp[11]            }   // set input delay, r8 free now, r8: p_cs
    { setc res[r3], RUN_STARTR  ; ldw r7, sp[NSTACKWORDS+8] }   // clk start, r7: cs_pattern
    { setpt res[r8], r6         ; nop                       }   // cs delay set
    { out res[r8], r7           ; nop                       }
    outpw res[r0], r11, 16
    outpw res[r2], r9, 16
    { in r8, res[r1]            ; ldw r10, sp[NSTACKWORDS+9]}
    outpw res[r0], r10, 1
    { in r9, res[r1]            ; nop                       }
    unzip r9, r8, 0
    { byterev r8, r8            ; nop                       }
    { bitrev r8, r8             ; ldc r9, 0                 }
    st16 r8, r4[r9]
    { shr r8, r8, 16            ; ldc r9, 2                 }
    st8 r9, r4[r9]
    bu exit

xfer_4B:
    { out res[r0], r11          ; ldw r10, sp[NSTACKWORDS+6]}   // r10: input_delay
    { out res[r2], r8           ; ldw r3, sp[NSTACKWORDS+1] }   // r3: clk_blk
    { setpt res[r1], r10        ; ldw r8, sp[11]            }   // set input delay, r8 free now, r8: p_cs
    { setc res[r3], RUN_STARTR  ; ldw r7, sp[NSTACKWORDS+8] }   // clk start, r7: cs_pattern
    { setpt res[r8], r6         ; nop                       }   // cs delay set
    { out res[r8], r7           ; nop                       }
    { out res[r0], r11          ; nop                       }
    { out res[r2], r9           ; nop                       }
    { in r8, res[r1]            ; ldw r10, sp[NSTACKWORDS+9]}
    outpw res[r0], r10, 1
    { in r9, res[r1]            ; nop                       }
    unzip r9, r8, 0
    { byterev r8, r8            ; nop                       }
    { bitrev r8, r8             ; nop                       }
    { stw r8, r4[0]             ; nop                       }

exit:
    setc res[r3], RUN_STOPR
    add r0, r10, 0

    ldd r4, r5, sp[2]   // sp[5] sp[4]
    ldd r6, r7, sp[3]   // sp[7] sp[6]
    ldd r8, r9, sp[4]   // sp[9] sp[8]
    ldw r10, sp[10]     // sp[10]
    retsp NSTACKWORDS

    .cc_bottom FUNCTION_NAME.function