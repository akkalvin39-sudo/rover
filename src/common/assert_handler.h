#ifndef ASSERT_HANDLER_H
#define ASSERT_HANDLER_H

// Assert implementation suitable for a microcontroller

// When enabled, `assert_handler()` triggers a software breakpoint (useful for inspecting
// the call stack with a debugger attached).
// When disabled, asserts still blink the LED continuously.
#ifndef ASSERT_ENABLE_BREAKPOINT
#define ASSERT_ENABLE_BREAKPOINT 0
#endif

#define ASSERT(expression)                                                                         \
    do {                                                                                           \
        if (!(expression)) {                                                                       \
            assert_handler();                                                                      \
        }                                                                                          \
    } while (0)

void assert_handler(void);

#endif // ASSERT_HANDLER_H