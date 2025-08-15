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
    { setv res[r2], r11         ; ldap r11, xfer_handle }   // set cs event
    { setv res[r1], r11         ; ldc r5, IDLE          }   // set mosi event, r5: state (IDLE)
    { eeu res[r1]               ; nop                   }   // enable mosi event
    { eeu res[r2]               ; nop                   }   // enable cs event
    { waiteu                    ; nop                   }

cs_handle:
    { in r6, res[r2]        ; nop                   }   // r5: state (IDLE)
    { setd res[r2], r6      ; eq r6, r6, 0          }   // r6: check if cs deassert, should call callback or clean up
    { bt r6, xfer_cleanup   ; nop                   }
    { waiteu                ; nop                   }

xfer_handle:
    { getts r6, res[r1]     ; eq r11, r5, IDLE      }   // r6: miso input port time, r11: if state is IDLE
    { bt r11, setup         ; in r7, res[r1]        }
    { bitrev r7, r7         ; ldw r9, r8[0]         }
    { byterev r7, r7        ; bitrev r9, r9         }
    { eq r11, r5, WR_DATA   ; byterev r9, r9        }
    { bt r11, mosi          ; eq r11, r5, RD_DATA   }
    { bt r11, miso          ; eq r11, r5, WR_NOP    }
    { bt r11, clear_nop     ; nop                   }

mosi:
    { stw r7, r8[0]         ; add r8, r8, 4         }
    //{ bu exit; add r0, r7, 0}
    { waiteu                ; nop                   }

miso:
    { out res[r0], r9       ; add r8, r8, 4         }
    { waiteu                ; nop                   }

clear_nop:
    { ldc r5, WR_DATA       ; nop                   }   // looks like need to set r5 before waiteu
    { waiteu                ; nop                   }

setup:
    { bitrev r7, r7         ; mkmsk r8, 8               }   // r8: state bitmask
    { byterev r7, r7        ; ldw r9, sp[NSTACKWORDS+2] }   // r9: nop cycle
    { and r5, r7, r8        ; shr r8, r7, 8             }   // r5: state, r8: address, r7 free now
    { add r8, r3, r8        ; mkmsk r10, 2              }   // r8: real address, r10: address offset bitmask
    { add r6, r6, r9        ; and r10, r8, r10          }   // r6: next xfer time, r10: offset byte, r9 free now
    { eq r7, r5, WR_DATA    ; ldc r9, 4                 }   // r9: 4 (for partial read)
    { bt r7, setup_wr       ; eq r7, r5, RD_DATA        }
    //{ add r0, r5, 0; bu exit}
    { bt r7, setup_rd       ; nop                       }           

setup_wr:
    { ldc r7, 1             ; ldc r5, WR_NOP            }
    { sub r6, r6, r7        ; nop                       }
    { setpt res[r1], r6     ; nop                       }
    { waiteu                ; nop                       }

setup_rd:
    { ldw r9, r8[0]         ; add r8, r8, 4             }
    { bitrev r9, r9         ; ldw r10, r8[0]            }
    { byterev r9, r9        ; ldw r7, sp[NSTACKWORDS+3] }   // miso offset
    { sub r6, r6, r7        ; nop                       }
    { setpt res[r0], r6     ; bitrev r10, r10           }
    { out res[r0], r9       ; byterev r10, r10          }
    { out res[r0], r10      ; add r8, r8, 4             }
    { waiteu                ; nop                       }

xfer_cleanup:   // TODO: read the remaining
    { setc res[r0], RUN_CLRBUF  ; ldc r10, 32           }   // make sure p_miso is all clear
    { setc res[r0], RUN_CLRBUF  ; eq r7, r5, WR_DATA    }   // giving more time for p_mosi load data
    { endin r9, res[r1]         ; bf r7, cleanup_done   }   // r9: num bit in
    { in r11, res[r1]           ; ldc r7, 0             }   // r11: last bit of data
    { bitrev r11, r11           ; sub r10, r10, r9      }   // r10: num useless bit
    { byterev r11, r11          ; shr r9, r9, 3         }   // r9: num byte left
    { shr r11, r11, r10         ; bf r9, cleanup_done   }

st8_loop:
    st8 r11, r8[r7]
    { shr r11, r11, 8           ; sub r9, r9, 1         }
    { bt r9, st8_loop           ; add r8, r8, 1         }

cleanup_done:
    { clrpt res[r1]             ; nop                   }
    { setc res[r1], RUN_CLRBUF  ; ldc r5, IDLE          }   // make sure p_mosi is all clear
    { setc res[r1], RUN_CLRBUF  ; nop                   }
    { waiteu                    ; nop                   }

    //{add r0, r9, 0;bu exit}
/*
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
    { setv res[r2], r11         ; ldap r11, xfer_handle }   // set cs event
    { setv res[r1], r11         ; ldc r5, IDLE          }   // set mosi event, r5: state (IDLE)
    { eeu res[r1]               ; nop                   }   // enable mosi event
    { eeu res[r2]               ; nop                   }   // enable cs event
    { waiteu                    ; nop                   }

cs_handle:
    { in r6, res[r2]        ; nop                   }   // r5: state (IDLE)
    { setd res[r2], r6      ; eq r6, r6, 0          }   // r6: check if cs deassert, should call callback or clean up
    { bt r6, xfer_cleanup   ; nop                   }
    { waiteu                ; nop                   }

xfer_handle:
    { getts r6, res[r1]     ; eq r11, r5, IDLE      }   // r6: miso input port time, r11: if state is IDLE
    { bt r11, setup         ; in r7, res[r1]        }
    { bitrev r7, r7         ; ldw r9, r8[0]         }
    { byterev r7, r7        ; bitrev r9, r9         }
    { eq r11, r5, WR_DATA   ; byterev r9, r9        }
    { bt r11, mosi          ; eq r11, r5, RD_DATA   }
    { bt r11, miso          ; nop                   }

mosi:
    { stw r7, r8[0]         ; add r8, r8, 4         }
    //{ bu exit; add r0, r7, 0}
    { waiteu                ; nop                   }

miso:
    { out res[r0], r9       ; add r8, r8, 4         }
    { waiteu                ; nop                   }

setup:
    { bitrev r7, r7         ; mkmsk r8, 8               }   // r8: state bitmask
    { byterev r7, r7        ; ldw r9, sp[NSTACKWORDS+2] }   // r9: nop cycle
    { and r5, r7, r8        ; shr r8, r7, 8             }   // r5: state, r8: address, r7 free now
    { add r8, r3, r8        ; mkmsk r10, 2              }   // r8: real address, r10: address offset bitmask
    { add r6, r6, r9        ; and r10, r8, r10          }   // r6: next xfer time, r10: offset byte, r9 free now
    { eq r7, r5, WR_DATA    ; nop                       }
    { bt r7, setup_wr       ; eq r7, r5, RD_DATA        }
    //{ add r0, r5, 0; bu exit}
    { bt r7, setup_rd       ; nop                       }           

// assume address word align first
setup_wr:
    { ldc r7, 31            ; nop   }
    { add r6, r6, r7        ; nop   }
    { setpt res[r1], r6     ; nop   }
    { waiteu                ; nop   }

setup_rd:
    { ldw r9, r8[0]         ; add r8, r8, 4             }
    { bitrev r9, r9         ; ldw r10, r8[0]            }
    { byterev r9, r9        ; ldw r7, sp[NSTACKWORDS+3] }   // miso offset
    { sub r6, r6, r7        ; nop                       }
    { setpt res[r0], r6     ; bitrev r10, r10           }
    { out res[r0], r9       ; byterev r10, r10          }
    { out res[r0], r10      ; add r8, r8, 4             }
    { waiteu                ; nop                       }

xfer_cleanup:   // TODO: read the remaining
    { setc res[r0], RUN_CLRBUF  ; eq r7, r5, WR_DATA    }   // make sure p_miso is all clear
    { setc res[r0], RUN_CLRBUF  ; ldc r5, IDLE          }   // giving more time for p_mosi load data
    { getts r6, res[r1]         ; bf r7, cleanup_done   }   // r6: last mosi time or maybe the first input time
    { clrpt res[r1]             ; nop                   }
    { endin r11, res[r1]        ; nop                   }
    { getts r9, res[r1]         ; nop                   }   // r9: lastest mosi time
    { lsu r10, r9, r6           ; nop                   }   // r10: is first incomplete xfer
    { in r11, res[r1]           ; ldc r7, 0             }
    { bt r10, first_xfer_cleanup; add r6, r6, 1         }
    { bitrev r11, r11           ; sub r6, r9, r6        }
    { byterev r11, r11          ; bt r6, st8_loop       }
    bu cleanup_done

first_xfer_cleanup:
    //{add r0, r9, 0;bu exit}
    { sub r10, r6, r9           ; mkmsk r9, 2           }   // r10: bit unread, r9: mask to check if r8 word align
    { shr r11, r11, r10         ; shr r10, r10, 3       }   // r11: remain xfer part, r10: byte unread
    { and r9, r8, r9            ; ldc r6, 4             }
    { sub r9, r6, r9            ; lsu r7, r6, r10       }   // r9: byte to read, r7: if xfer still in nop state
    { bt r7, cleanup_done       ; sub r6, r9, r10       }   // r6: byte left xfer
    { bitrev r11, r11           ; ldc r7, 0             }
    { byterev r11, r11          ; bf r6, cleanup_done   }

st8_loop:
    st8 r11, r8[r7]
    { shr r11, r11, 8           ; sub r6, r6, 1         }
    { bt r6, st8_loop           ; add r8, r8, 1         }

cleanup_done:
    { setc res[r1], RUN_CLRBUF  ; nop                   }   // make sure p_mosi is all clear
    { setc res[r1], RUN_CLRBUF  ; nop                   }
    { waiteu                    ; nop                   }
*/

/*
setup_rw:
    { bitrev r7, r7         ; mkmsk r8, 8               }
    { byterev r7, r7        ; ldw r9, sp[NSTACKWORDS+2] }   // r9: nop cycle
    { and r5, r7, r8        ; shr r7, r7, 8             }   // r5: WR_DATA/RD_DATA, r7: address
    { add r7, r3, r7        ; mkmsk r10, 2              }   // r7: &reg_map[address], r10: mask to check if word align
    { add r6, r6, r9        ; and r10, r7, r10          }   // r6: xfer time, r10: if address word align
    { bt r10, setup_part_rw ; ldc r8, 0x4               }

setup_part_rw:
    { sub r8, r8, r10       ; ldc r10, 0x8              }   // r8: how many byte for partial rw
    { shl r10, r10, r8      ; eq r11, r5, WR_DATA       }   // r10: how many bit for partial rw
    { bt r11, setup_part_w  ; eq r11, r5, RD_DATA       }
    { bt r11, setup_part_r  ; ldc r5, IDLE              }
    { waiteu                ; nop                       }

setup_part_w:   // mosi
    { add r6, r6, r10       ; add r7, r7, r8            }   // r6: nop cycle + partial cycle, r7: address+partial_w_byte
    { sub r6, r6, 1         ; sub r7, r7, 4             }   // r6: nop cycle + partial cycle - 1, r8: word aligned address
    { setpt res[r1], r6     ; ldc r5, WR_PART           }
    { waiteu                ; nop                       }

setup_part_r:   // miso
    { setpt res[r1], r6     ; add r7, r7, r8            }   // r7: address + partial_w_byte
    { ldc r11, 32           ; sub r7, r7, 4             }   // r7: word aligned address
    { ldw r9, r7[0]         ; sub r11, r11, r10         }   // r9: data, r11: offset bit
    { shr r11, r9, r11      ; add r7, r7, 4             }   // r7: next data address
    { bitrev r11, r11       ; ldw r9, r7[0]             }   // r9: next data
    { byterev r11, r11      ; bitrev r9, r9             }
    outpw res[r0], r11, r10
    { byterev r9, r9        ; add r7, r7, 4             }   // r7: next next data address
    { out res[r0], r9       ; ldw r8, r7[0]             }
    { waiteu                ; nop                       }
*/

exit:
    ldd r4, r5, sp[2]   // sp[5] sp[4]
    ldd r6, r7, sp[3]   // sp[7] sp[6]
    ldd r8, r9, sp[4]   // sp[9] sp[8]
    ldw r10, sp[10]     // sp[10]
    retsp NSTACKWORDS

    .cc_bottom FUNCTION_NAME.function