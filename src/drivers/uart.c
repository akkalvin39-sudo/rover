#include "drivers/uart.h"
#include "common/ring_buffer.h"
#include "common/assert_handler.h"
#include "common/defines.h"
#include <msp430.h>
#include <assert.h>
#include <stdint.h>

#define UART_BUFFER_SIZE (16)
static uint8_t buffer[UART_BUFFER_SIZE];
static struct ring_buffer tx_buffer = { .buffer = buffer, .size = sizeof(buffer) };

#define SMCLK (16000000u)
#define BRCLK (SMCLK)
#define UART_BAUD_RATE (115200u)

static_assert(UART_BAUD_RATE < (BRCLK / 3.0f), "Baudrate must be smaller than 1/3 of input clock");

#define UART_DIVISOR ((float)BRCLK / UART_BAUD_RATE)
static_assert(UART_DIVISOR < 0xFFFFu, "Divisor fits in 16-bit");

#define UART_DIVISOR_INT_16BIT ((uint16_t)UART_DIVISOR)
#define UART_DIVISOR_INT_LOW_BYTE (UART_DIVISOR_INT_16BIT & 0xFF)
#define UART_DIVISOR_INT_HIGH_BYTE (UART_DIVISOR_INT_16BIT >> 8)
#define UART_DIVISOR_FRACTIONAL (UART_DIVISOR - UART_DIVISOR_INT_16BIT)
#define UART_UCBRS ((uint8_t)(8 * UART_DIVISOR_FRACTIONAL))
#define UART_UCBRF (0)
#define UART_UC0S16 (0)

static inline void uart_tx_clear_interrupt(void)
{
    IFG2 &= ~UCA0TXIFG;
}

static inline void uart_tx_enable_interrupt(void)
{
    UC0IE |= UCA0TXIE;
}

static inline void uart_tx_disable_interrupt(void)
{
    UC0IE &= ~UCA0TXIE;
}

static void uart_tx_start(void)
{
    if (!ring_buffer_empty(&tx_buffer)) {
        UCA0TXBUF = ring_buffer_peek(&tx_buffer);
    }
}

INTERRUPT_FUNCTION(USCIAB0TX_VECTOR) isr_uart_tx()
{
    ASSERT_INTERRUPT(!ring_buffer_empty(&tx_buffer));

    ring_buffer_get(&tx_buffer);
    uart_tx_clear_interrupt();

    if (!ring_buffer_empty(&tx_buffer)) {
        uart_tx_start();
    }
}

static void uart_configure(void)
{
    UCA0CTL1 |= UCSWRST;

    UCA0CTL0 = 0;
    UCA0CTL1 |= UCSSEL_2;

    // ✅ UART pins (CRITICAL FIX)
    P1SEL |= BIT1 | BIT2;
    P1SEL2 |= BIT1 | BIT2;

    UCA0BR0 = UART_DIVISOR_INT_LOW_BYTE;
    UCA0BR1 = UART_DIVISOR_INT_HIGH_BYTE;

    UCA0MCTL = (UART_UCBRF << 4) + (UART_UCBRS << 1) + UART_UC0S16;

    UCA0CTL1 &= ~UCSWRST;
}

static bool initialized = false;

void uart_init(void)
{
    ASSERT(!initialized);
    uart_configure();
    uart_tx_clear_interrupt();
    uart_tx_enable_interrupt();
    initialized = true;
}

void _putchar(char c)
{
    while (ring_buffer_full(&tx_buffer)) { }

    uart_tx_disable_interrupt();
    const bool tx_ongoing = !ring_buffer_empty(&tx_buffer);

    ring_buffer_put(&tx_buffer, c);

    if (!tx_ongoing) {
        uart_tx_start();
    }

    uart_tx_enable_interrupt();

    if (c == '\n') {
        _putchar('\r');
    }
}

/* ===== ASSERT MODE (POLLING UART) ===== */

void uart_init_assert(void)
{
    uart_tx_disable_interrupt();
    uart_configure();

    // ✅ CRITICAL FIX: enable TX flag for polling
    IFG2 |= UCA0TXIFG;
}

static void uart_putchar_polling(char c)
{
    while (!(IFG2 & UCA0TXIFG)) { }

    UCA0TXBUF = c;

    if (c == '\n') {
        while (!(IFG2 & UCA0TXIFG)) { }
        uart_putchar_polling('\r');
    }
}

void uart_trace_assert(const char *string)
{
    int i = 0;
    while (string[i] != '\0') {
        uart_putchar_polling(string[i]);
        i++;
    }
}