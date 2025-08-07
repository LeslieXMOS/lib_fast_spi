#define FUNCTION_NAME spi_master_burst_xfer


/*
tx_buf and rx_buf needs to be word aligned, xfer_len > 0
void spi_master_burst_xfer(
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
    #define RUN_CLRBUF 0x0017

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
     * r6: clk_blk,
     * r3: tx_buf,
     * r4: rx_buf,
     * r5: xfer_len
     */
    //ldw r6, sp[NSTACKWORDS+1]
    ldw r3, sp[NSTACKWORDS+2]
    ldw r4, sp[NSTACKWORDS+3]
    ldw r5, sp[NSTACKWORDS+4]

burst_prepare:
    { ldw r8, r3[0]         ; shl r6, r5, 4             }   // r6: cs deassert clk_time
    { bitrev r8, r8         ; ldw r11, sp[NSTACKWORDS+7]}   // r11: clk_pattern
    { byterev r8, r8        ; ldw r7, sp[NSTACKWORDS+6] }   // r7: input_delay
    { add r9, r8, 0         ; setpt res[r1], r7         }   // r9 = r8, for zip operation, r7 free now
    zip r9, r8, 0
    { out res[r0], r11      ; ldw r10, sp[NSTACKWORDS+8]}   // output sck clk pattern, r10: cs_pattern
    { out res[r2], r8       ; ldw r8, sp[NSTACKWORDS+1] }   // output mosi (0, 1 Bytes), r8: clk_blk
    { eq r7, r5, 0x5        ; nop                       }
    { bt r7, first_xfer_5B  ; setc res[r8], RUN_STARTR  }   // clk blk start, r8 free now

first_xfer:
    { ldw r7, sp[11];       ; add r6, r6, 1         }   // r7: p_cs, r6: cs deassert clk_time, 
    { setpt res[r7], r6     ; add r3, r3, 4         }   // tx_buf += 4
    { out res[r7], r10      ; sub r4, r4, 4         }   // rx_buf -= 4, as loop will +=4 before store
    { out res[r0], r11      ; ldw r6, r3[0]         }   // output sck clk pattern, r6: tx_buf[4]
    { out res[r2], r9       ; byterev r6, r6        }   // output mosi (2, 3 Bytes)
    { bitrev r6, r6         ; sub r5, r5, 4         }   // xfer_len -= 4
    { add r7, r6, 0         ; ldc r10, 0x5          }   // r7 = r6, for zip operation
    zip r7, r6, 0
    { lsu r10, r5, r10      ; out res[r0], r11      }   // output sck clk pattern
    { bt r10, remainder_xfer; out res[r2], r6       }   // output mosi (0, 1 Bytes), r6 r10 free now

xfer_loop:
    { in r8, res[r1]        ; add r4, r4, 4         }   // rx_buf += 4
    { in r9, res[r1]        ; add r3, r3, 4         }   // tx_buf += 4
    unzip r9, r8, 0
    { byterev r9, r9        ; ldc r10, 0x6          }
    { bitrev r9, r9         ; nop      }
    { out res[r0], r11      ; stw r9, r4[0]         }   // output sck clk pattern, store 0,1,2,3 Bytes to rx_buf
    { out res[r2], r7       ; ldw r6, r3[0]         }   // output mosi (2, 3 Bytes), r7 free now
    { byterev r6, r6        ; sub r5, r5, 4         }   // xfer_len -= 4
    { bitrev r6, r6         ; lsu r10, r5, r10      }   // r10 = xfer_len < 6
    { out res[r0], r11      ; add r7, r6, 0         }   // output sck clk pattern, r7 = r6, for zip operation
    zip r7, r6, 0
    { out res[r2], r6       ; bf r10, xfer_loop     }   // output mosi (0, 1 Bytes), r6 free now

remainder_xfer:
    { in r9, res[r1]        ; add r4, r4, 4         }   // rx_buf += 4
    { in r8, res[r1]        ; ldc r10, 8            }
    unzip r8, r9, 0
    { byterev r8, r8        ; add r3, r3, 4         }   // tx_buf += 4
    { bitrev r8, r8         ; ldw r6, r3[0]         }
    { stw r8, r4[0]         ; eq r10, r5, 0x5       }
    { bt r10, remainder_5B  ; eq r10, r5, 0x4       }
    { bt r10, remainder_4B  ; eq r10, r5, 0x3       }
    { bt r10, remainder_3B  ; nop                   }

remainder_2B:
    { ldw r10, sp[NSTACKWORDS+9]    ; nop           }
    outpw res[r0], r10, 1
    { in r8, res[r1]                ; nop           }
    unzip r9, r8, 0
    { byterev r9, r9                ; add r4, r4, 4 }   // rx_buf += 4
    { bitrev r9, r9                 ; ldc r10, 0    }
    st16 r9, r4[r10]
    bu exit

remainder_3B:
    outpw res[r0], r11, 16  // output sck clk pattern
    outpw res[r2], r7, 16   // output mosi (2 Byte)
    { in r8, res[r1]        ; ldw r10, sp[NSTACKWORDS+9]}
    outpw res[r0], r10, 1
    { in r9, res[r1]        ; add r4, r4, 4             }   // rx_buf += 4
    unzip r9, r8, 0
    { byterev r9, r9        ; nop                       }
    { bitrev r9, r9         ; ldc r6, 0                 }
    st16 r9, r4[r6]
    { shr r9, r9, 16        ; ldc r7, 0x2               }
    st8 r9, r4[r7]
    bu exit

remainder_4B:
    { out res[r0], r11      ; nop                       }   // output sck clk pattern
    { out res[r2], r7       ; nop                       }   // output mosi (2, 3 Bytes)
    { in r8, res[r1]        ; ldw r10, sp[NSTACKWORDS+9]}
    outpw res[r0], r10, 1
    { in r9, res[r1]        ; add r4, r4, 4             }   // rx_buf += 4
    unzip r9, r8, 0
    { byterev r9, r9        ; nop                       }
    { bitrev r9, r9         ; nop                       }
    { stw r9, r4[0]         ; nop                       }
    bu exit

first_xfer_5B:
    { ldw r7, sp[11];       ; add r6, r6, 1         }   // r7: p_cs, r6: cs deassert clk_time, 
    { setpt res[r7], r6     ; add r3, r3, 4         }   // tx_buf += 4
    { out res[r7], r10      ; ldw r6, r3[0]         }   // r6: tx_buf[4]
    { add r7, r9, 0         ; sub r4, r4, 4         }   // rx_buf -= 4, as remainder_5B will +=4 before store

remainder_5B:
    { out res[r0], r11      ; byterev r6, r6            }   // output sck clk pattern
    { out res[r2], r7       ; bitrev r6, r6             }   // output mosi (2, 3 Bytes)
    { in r8, res[r1]        ; add r7, r6, 0             }
    zip r7, r6, 0
    outpw res[r0], r11, 16
    outpw res[r2], r6, 16
    { in r9, res[r1]        ; nop                       }
    unzip r9, r8, 0
    { byterev r9, r9        ; add r4, r4, 4             }   // rx_buf += 4
    { bitrev r9, r9         ; ldw r10, sp[NSTACKWORDS+9]}
    outpw res[r0], r10, 1
    { stw r9, r4[0]         ; in r9, res[r1]            }   // input miso
    unzip r8, r9, 0
    { byterev r8, r8        ; add r4, r4, 4             }
    { bitrev r8, r8         ; ldc r7, 0x0               }
    st8 r8, r4[r7]

exit:
    { ldw r3, sp[11]        ; nop                       }   // r3: p_cs
    { syncr res[r3]         ; ldw r6, sp[NSTACKWORDS+1] }
    setc res[r6], RUN_STOPR
    add r0, r10, 0

    ldd r4, r5, sp[2]   // sp[5] sp[4]
    ldd r6, r7, sp[3]   // sp[7] sp[6]
    ldd r8, r9, sp[4]   // sp[9] sp[8]
    ldw r10, sp[10]     // sp[10]
    retsp NSTACKWORDS

    .cc_bottom FUNCTION_NAME.function