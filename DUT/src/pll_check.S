#define FUNCTION_NAME pll_check

/*
unsigned pll_check(
    unsigned tile_id
);
*/

    #define NSTACKWORDS 32

    #define WATCHDOG_COUNT_REG 0xF023
    #define PASS_LOWER_BOUND 999
    #define PASS_UPPER_BOUND 1010
    #define PASS_CNT 0

    .cc_top FUNCTION_NAME.function
    .type   FUNCTION_NAME,@function

    .issue_mode dual
    .align 16
    .globl FUNCTION_NAME
.globl FUNCTION_NAME.nstackwords
.set   FUNCTION_NAME.nstackwords, NSTACKWORDS
FUNCTION_NAME:
    { dualentsp NSTACKWORDS;}

    stw r4, sp[0]
    stw r5, sp[1]
    stw r6, sp[2]
    stw r7, sp[3]
    stw r8, sp[4]
    stw r9, sp[5]
    stw r10, sp[6]

    // Setup read sswitch reg
    ldc r5, 0xc30c
    { shl  r0, r0, 0x10     ; getr r11, 0x2     }
    { or   r0, r0, r5       ; nop               }
    { setd res[r11], r0     ; nop               }
    ldc r5, WATCHDOG_COUNT_REG
    { shr  r0, r11, 0x8     ; shr r2, r5, 0x8   }
    { shl  r0, r0, 0x8      ; nop               }
    { or   r0, r0, r2       ; ldc r7, 0x0       }
    ldc  r4, 0xc1
    { ldc  r1, 0x0          ; ldc r2, 0x0       }

read_switch_loop:
    { gettime r9            ; bu read_switch    }
read_switch_done:
    { gettime r8            ; nop               }
    { sub r8, r8, r9        ; nop               }
    ldc r7, PASS_LOWER_BOUND
    ldc r9, PASS_UPPER_BOUND
    { lsu r7, r7, r8        ; lsu r9, r8, r9    }
    { and r7, r7, r9        ; add r1, r8, 0     }
    { bt  r7, exit          ; nop               }
    { bu  read_switch_loop  ; nop               }
    
read_switch:
    // need r0 r4 r5, r8 last_cnt, r6 cur_cnt, r7 eq_cnt
    { outct res[r11], r4        ; nop               }
    { out   res[r11], r0        ; nop               }
    { outt  res[r11], r5        ; nop               }
    { outct res[r11], 0x1       ; nop               }
    { chkct res[r11], 0x3       ; nop               }
    { in    r6, res[r11]        ; add r8, r6, 0x0   }
    { chkct res[r11], 0x1       ; eq  r7, r8, r6    }
    { bt    r7, read_switch     ; nop               }
    { bu    read_switch_done    ; nop               }
    
exit:
    // release resources
    { freer res[r11]        ; add r0, r1, 0 }
    ldw r4, sp[0]
    ldw r5, sp[1]
    ldw r6, sp[2]
    ldw r7, sp[3]
    ldw r8, sp[4]
    ldw r9, sp[5]
    ldw r10, sp[6]
    retsp NSTACKWORDS

    .cc_bottom FUNCTION_NAME.function