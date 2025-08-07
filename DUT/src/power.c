#include <xs1.h>
#include <platform.h>
#include <xcore/hwtimer.h>
#include <stdio.h>

// Modify from AN01009

unsigned switchDivNum = 0;

void switch_power_down(void) {
    write_sswitch_reg(get_local_tile_id(), XS1_SSWITCH_CLK_DIVIDER_NUM, (500 - 1));
    switchDivNum = (500-1);
}

void switch_power_up(void) {
    write_sswitch_reg(get_local_tile_id(), XS1_SSWITCH_CLK_DIVIDER_NUM, (1 - 1));   // Divide by 1
    switchDivNum = (1-1);
}

void set_core_clock_divider(unsigned tileid, unsigned div) {
    write_pswitch_reg(tileid, XS1_PSWITCH_PLL_CLK_DIVIDER_NUM, div - 1);
}

void enable_core_divider(void) {
    // First ensure we have initialised core divider to /1 so no nasty surprises when enabling the divider
    set_core_clock_divider(get_local_tile_id(), 1);

    unsigned val = getps(XS1_PS_XCORE_CTRL0);
    setps(XS1_PS_XCORE_CTRL0, val | (1 << 4)); // Set enable divider bit
    delay_milliseconds(10);
}

void disable_core_clock(unsigned tileid) {
    write_pswitch_reg(tileid, XS1_PSWITCH_PLL_CLK_DIVIDER_NUM, XS1_PLL_CLK_DISABLE_MASK);
}

// Whole chip power down VCO @ 1MHz, output @ 0.125MHz. This sets the VCO to near off power whilst still operating
// R = 24, F = 1, OD = 8
#define PLL_CTL_VCO1_BYPASS  0x93800117 // Don't reset, in bypass, VCO @ 1MHz, output @ 0.125MHz.

unsigned pllCtrlVal = 0;    // State for entry/exit to PLL off mode
unsigned pllClkDiv;

// May be called from either tile but must be the same tile as pll_bypass_off()
void pll_bypass_on(void) {
    unsigned local_tile_id = get_local_tile_id();
    // Grab original setting once only
    if(pllCtrlVal == 0){
        read_sswitch_reg(local_tile_id, XS1_SSWITCH_PLL_CTL_NUM, &pllCtrlVal);
        read_pswitch_reg(local_tile_id, XS1_PSWITCH_PLL_CLK_DIVIDER_NUM, &pllClkDiv);
        pllCtrlVal &= ~0xF0000000;
    }
    delay_microseconds(500); // TODO - this is needed for pll_bypass to be robust
    write_pswitch_reg(local_tile_id, XS1_PSWITCH_PLL_CLK_DIVIDER_NUM, 0); // core clock 24mhz now
    // Enable bypass and power VCO down
    write_sswitch_reg(local_tile_id, XS1_SSWITCH_PLL_CTL_NUM, PLL_CTL_VCO1_BYPASS);
    write_sswitch_reg(local_tile_id, XS1_SSWITCH_REF_CLK_DIVIDER_NUM, 0); // ref clock 24mhz
}

extern unsigned pll_check(unsigned tile_id);

// Note this takes up to 500us to resume. Chip will not be clocked until PLL is stable
// May be called from either tile but must be the same tile as pll_bypass_on()
void pll_bypass_off(void) {    
    unsigned local_tile_id = get_local_tile_id();

    if(pllCtrlVal == 0){
        return; // we haven't done bypass_on yet
    }
    // Set old value stored by pll_bypass_on
    unsigned new_val = pllCtrlVal;
    new_val |= 0x40000000; // Don't wait for PLL lock
    new_val |= 0x80000000; // Do not reset chip on PLL write

    write_sswitch_reg(local_tile_id, XS1_SSWITCH_CLK_DIVIDER_NUM, (1 - 1));   // power up switch first
    write_sswitch_reg(local_tile_id, XS1_SSWITCH_PLL_CTL_NUM, new_val);
    write_sswitch_reg(local_tile_id, XS1_SSWITCH_REF_CLK_DIVIDER_NUM, 5); // ref clock 100mhz

    // Setup watchdog to monitor pll lock state
    write_sswitch_reg(local_tile_id, XS1_SSWITCH_WATCHDOG_PRESCALER_WRAP_NUM, 239); // 10 us ticks
    write_sswitch_reg(local_tile_id, XS1_SSWITCH_WATCHDOG_COUNT_NUM, 0xFFF);
    write_sswitch_reg(local_tile_id, XS1_SSWITCH_WATCHDOG_CFG_NUM, XS1_WATCHDOG_COUNT_ENABLE_SET(0, 1));

    pll_check(local_tile_id);
    
    write_sswitch_reg(local_tile_id, XS1_SSWITCH_WATCHDOG_CFG_NUM, 0);

    write_pswitch_reg(local_tile_id, XS1_PSWITCH_PLL_CLK_DIVIDER_NUM, pllClkDiv);
    write_sswitch_reg(local_tile_id, XS1_SSWITCH_CLK_DIVIDER_NUM, switchDivNum);   // restore switch setting

}