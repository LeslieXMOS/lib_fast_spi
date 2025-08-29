#define FUNCTION_NAME spi_slave_reg_xfer

/*
tx_buf and rx_buf needs to be word aligned, xfer_len > 0
void spi_slave_reg_xfer(
    port_t p_miso,
    port_t p_mosi,
    port_t p_cs,
    void* reg_map,
    size_t reg_map_len,
    size_t num_nop,
    size_t miso_offset
);
*/

    #define NSTACKWORDS 32
    #define COND_NONE   0x0001
    #define COND_NEQ    0x0019
    #define RUN_CLRBUF  0x0017
    #define IDLE        0
    #define WR_ADDR     1
    #define RD_ADDR     2
    #define WR_DATA     3
    #define RD_DATA     4
    #define WR_NOP      5
    #define RD_END      6
    #define WR_PART     7
    #define RD_PART     8

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
     * r0: p_miso,
     * r1: p_mosi,
     * r2: p_cs,
     * r3: reg_map,
     * r4: reg_map_len
     * r5: state
     */
    ldw r4, sp[NSTACKWORDS+1]

prepare:
    // setup event
    { clre                      ; ldc r11, 1            }   // clear all event first
    { setc res[r2], COND_NEQ    ; nop                   }   // p_cs pin neq
    { setd res[r2], r11         ; nop                   }
    { in r11, res[r2]           ; nop                   }   // wait until cs deassert
    { setd res[r2], r11         ; nop                   }   // p_cs event trigger neq 0
    { setc res[r1], COND_NONE   ; nop                   }   // p_mosi none
    { endin r11, res[r1]        ; nop                   }
    { setc res[r1], RUN_CLRBUF  ; nop                   }
    { setc res[r1], RUN_CLRBUF  ; nop                   }   // make sure p_mosi is all clear
    { setc res[r0], RUN_CLRBUF  ; nop                   }
    { setc res[r0], RUN_CLRBUF  ; nop                   }   // make sure p_miso is all clear
    { add r4, r3, r4            ; ldap r11, cs_handle   }   // r4: end of reg_map
    { setv res[r2], r11         ; ldap r11, setup_handle}   // set cs event
    { setv res[r1], r11         ; ldc r5, IDLE          }   // set mosi event, r5: state (IDLE)
    { eeu res[r1]               ; nop                   }   // enable mosi event
    { eeu res[r2]               ; nop                   }   // enable cs event
    { waiteu                    ; nop                   }

cs_handle:
    { in r11, res[r2]       ; nop                   }   // r5: state (IDLE)
    { setd res[r2], r11     ; eq r11, r11, 0        }   // r6: check if cs deassert, should call callback or clean up
    { bt r11, xfer_cleanup  ; nop                   }
    { waiteu                ; nop                   }

setup_handle:
    { getts r6, res[r1]     ; ldw r9, sp[NSTACKWORDS+2] }   // r9: nop cycle
    { in r5, res[r1]        ; add r6, r6, r9            }   // r5: in data, r6: next xfer time, r9 free now
    { bitrev r5, r5         ; mkmsk r9, 2               }   // r9: mask for address align check
    { byterev r5, r5        ; nop                       }
    { zext r5, 8            ; shr r8, r5, 8             }   // r5: state, r8: address
    { add r8, r3, r8        ; nop                       }
    { nop                   ; lsu r7, r8, r4            }   // r7: check if address overflow
    { bf r7, cleanup_done   ; lsu r7, r8, r3            }   // r7: check if address underflow
    { bt r7, cleanup_done   ; eq r7, r5, RD_DATA        }   // r8: real address
    { bt r7, setup_rd       ; eq r7, r5, WR_DATA        }
    { bf r7, cleanup_done   ; nop                       }

setup_wr:
    { sub r6, r6, 1         ; and r7, r8, r9            }   // r6: next in time, r7: address offset (byte)
    { sub r8, r8, r7        ; shl r7, r7, 3             }   // r8: aligned address, r7: address offset (bit)
    { setpt res[r1], r6     ; ldw r6, r8[0]             }   // r6: aligned data
    { byterev r6, r6        ; ldc r10, 32               }
    { bitrev r6, r6         ; ldap r11, wr_nop          }
    { mkmsk r11, r7         ; setv res[r1], r11         }
    { and r6, r6, r11       ; nop                       }   // r6: partial offset data
    { ldc r5, WR_NOP        ; sub r10, r10, r7          }   // r10: partial wr bit
    { waiteu                ; nop                       }

setup_rd:
    { and r9, r8, r9        ; ldw r7, sp[NSTACKWORDS+3] }   // r9: address offset (byte), r7: miso offset
    { sub r6, r6, r7        ; sub r8, r8, r9            }   // r6: next out time, r8: aligned address, r7 free now
    { setpt res[r0], r6     ; shl r9, r9, 3             }   // r9: address offset (bit)
    { setpt res[r1], r6     ; ldw r7, r8[0]             }   // set p_mosi time, to trigger event, r7: aligned data
    { bitrev r6, r7         ; nop                       }
    { byterev r6, r6        ; ldc r7, 32                }
    { shr r6, r6, r9        ; sub r9, r7, r9            }   // r9: partial out bit
    outpw res[r0], r6, r9
    { ldw r6, r8[1]         ; add r8, r8, 8             }
    { bitrev r6, r6         ; ldap r11, rd_xfer         }
    { byterev r6, r6        ; setv res[r1], r11         }
    { waiteu                ; nop                       }

wr_nop:
    { in r5, res[r1]        ; ldap r11, wr_xfer     }
    { setv res[r1], r11     ; ldc r5, WR_DATA       }
    { waiteu                ; nop                   }

wr_xfer:
    { in r9, res[r1]        ; nop                       }
    { shl r9, r9, r7        ; shr r11, r9, r10          }   // r9: lower partial data, r11: upper partial data
    { or r9, r9, r6         ; add r6, r11, 0            }   // r9: complete bit&byte rev data, r6: upper partial data, r11 is free
    { bitrev r9, r9         ; lsu r11, r8, r4           }
    { byterev r9, r9        ; bf r11, cleanup_done      }
    { stw r9, r8[0]         ; add r8, r8, 4             }
    { waiteu                ; nop                       }        

rd_xfer:
    { out res[r0], r6       ; ldw r6, r8[0]             }
    { bitrev r6, r6         ; add r8, r8, 4             }
    { lsu r10, r8, r4       ; in r11, res[r1]           }   // r11 read dummy value from p_mosi to keep event keep firing
    { byterev r6, r6        ; bf r10, cleanup_done      }
    { waiteu                ; nop                       }

xfer_cleanup:
    { setc res[r0], RUN_CLRBUF  ; eq r11, r5, WR_DATA   }   // make sure p_miso is all clear
    { setc res[r0], RUN_CLRBUF  ; bf r11, cleanup_done  }   // giving more time for p_mosi load data
    { bitrev r6, r6             ; bf r7, wr_cleanup     }
    { byterev r6, r6            ; lsu r11, r8, r4       }
    { bf r11, cleanup_done      ; ldc r11, 0           }
clean_loop_1:
    st8 r6, r8[r11]
    { shr r6, r6, 8             ; sub r7, r7, 8         }
    { bt r7, clean_loop_1       ; add r8, r8, 1         }
wr_cleanup:
    { endin r7, res[r1]         ; ldc r6, 32            }   // r7: num bit in
    { in r9, res[r1]            ; sub r6, r6, r7        }   // r6: num useless bit
    { shr r9, r9, r6            ; shr r7, r7, 3         }   // r7: num byte in
    { bitrev r9, r9             ; bf r7, cleanup_done   }
    { byterev r9, r9            ; lsu r11, r8, r4       }
    { ldc r11, 0                ; bf r11, cleanup_done  }
clean_loop_2:
    st8 r9, r8[r11]
    { shr r9, r9, 8             ; sub r7, r7, 1         }
    { bt r7, clean_loop_2       ; add r8, r8, 1         }
cleanup_done:
    { clrpt res[r1]             ; nop                   }
    { setc res[r1], RUN_CLRBUF  ; ldc r5, IDLE          }   // make sure p_mosi is all clear
    { setc res[r1], RUN_CLRBUF  ; ldap r11, setup_handle}
    { setv res[r1], r11         ; nop                   }
    { waiteu                    ; nop                   }

exit:
    ldd r4, r5, sp[2]   // sp[5] sp[4]
    ldd r6, r7, sp[3]   // sp[7] sp[6]
    ldd r8, r9, sp[4]   // sp[9] sp[8]
    ldw r10, sp[10]     // sp[10]
    retsp NSTACKWORDS

    .cc_bottom FUNCTION_NAME.function