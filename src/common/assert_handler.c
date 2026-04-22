#include "common/assert_handler.h"
#include "common/defines.h"
#include "drivers/uart.h"
#include "external/printf/printf.h"
#include <msp430.h>

/* Software breakpoint for MSP430-GCC */
#define BREAKPOINT __asm volatile("CLR.B R3");

/* Max string size: "ASSERT 0xFFFF\n" */
#define ASSERT_STRING_MAX_SIZE (15u + 6u + 1u)

/* --- UART TRACE --- */
static void assert_trace(uint16_t program_counter)
{
    uart_init_assert();

    // small delay to stabilize UART
    BUSY_WAIT_ms(10);

    char assert_string[ASSERT_STRING_MAX_SIZE];
    snprintf(assert_string, sizeof(assert_string), "ASSERT 0x%x\n", program_counter);

    uart_trace_assert(assert_string);
}

/* --- LED INIT (renamed to match tutorial) */
static void assert_blink_led(void)
{
#if defined(LAUNCHPAD)
    P1SEL &= ~(BIT0 | BIT6);
    P1SEL2 &= ~(BIT0 | BIT6);
    P1DIR |= (BIT0 | BIT6);
    P1REN &= ~(BIT0 | BIT6);
#elif defined(NSUMO)
    P2SEL &= ~(BIT6);
    P2SEL2 &= ~(BIT6);
    P2DIR |= (BIT6);
    P2REN &= ~(BIT6);
#endif
}

/* --- MAIN HANDLER --- */
void assert_handler(uint16_t program_counter)
{
#if ASSERT_ENABLE_BREAKPOINT
    BREAKPOINT;
#endif

    assert_blink_led(); // ✅ FIXED

    while (1) {
        // keep sending UART (reliable)
        assert_trace(program_counter);

        // blink LED
#if defined(LAUNCHPAD)
        P1OUT ^= BIT0;
        P1OUT ^= BIT6;
#elif defined(NSUMO)
        P2OUT ^= BIT6;
#endif

        BUSY_WAIT_ms(500);
    }
}