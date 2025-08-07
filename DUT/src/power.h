#ifndef _POWER_H_
#define _POWER_H_

#include <stdint.h>
#include <platform.h>

void enable_core_divider(void);
void set_core_clock_divider(unsigned tileid, unsigned div);
void switch_power_down(void);
void switch_power_up(void);
void disable_core_clock(unsigned tileid);
void pll_bypass_on(void);
void pll_bypass_off(void);

#endif