#include "common/assert_handler.h"
#include "common/defines.h"
#include <msp430.h>

/* Software breakpoint for MSP430-GCC */
#define BREAKPOINT __asm volatile("CLR.B R3");

/*
 * Assert handler:
 * - Minimal dependencies (no drivers)
 * - Works for both LAUNCHPAD and NSUMO
 * - Infinite loop with LED indication
 */
void assert_handler(void)
{
#if defined(LAUNCHPAD)

    // --- Configure LED1 (P1.0 - Green) ---
    P1SEL &= ~(BIT0);
    P1SEL2 &= ~(BIT0);
    P1DIR |= (BIT0);
    P1REN &= ~(BIT0);

    // --- Configure LED2 (P1.6 - Red) ---
    P1SEL &= ~(BIT6);
    P1SEL2 &= ~(BIT6);
    P1DIR |= (BIT6);
    P1REN &= ~(BIT6);

#elif defined(NSUMO)

    // --- Configure LED (P2.6) ---
    P2SEL &= ~(BIT6);
    P2SEL2 &= ~(BIT6);
    P2DIR |= (BIT6);
    P2REN &= ~(BIT6);

#endif

#if ASSERT_ENABLE_BREAKPOINT
    BREAKPOINT;
#endif

    while (1) {
#if defined(LAUNCHPAD)

        // Alternate LEDs (clear error pattern)
        P1OUT |= BIT0; // Green ON
        P1OUT &= ~BIT6; // Red OFF
        BUSY_WAIT_ms(250);

        P1OUT &= ~BIT0; // Green OFF
        P1OUT |= BIT6; // Red ON
        BUSY_WAIT_ms(250);

#elif defined(NSUMO)

        // Single LED blink
        P2OUT ^= BIT6;
        BUSY_WAIT_ms(250);

#endif
    }
}