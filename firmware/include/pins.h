// =============================================================================
// pins.h — Physical pin assignments for the Printimate hardware
// =============================================================================
// Edit this file and only this file when hardware wiring changes. Every other
// module should reference these macros, never raw GPIO numbers.
//
// ESP32 DevKit V1 GPIO hazards to remember:
//   - GPIO 6–11: connected to the onboard SPI flash. DO NOT USE.
//   - GPIO 1, 3: UART0 TX/RX, used by the CP2102 for serial debug. Avoid.
//   - GPIO 34–39: input-only. No output, no internal pull-ups/downs.
//   - GPIO 0, 2, 12, 15: strapping pins. Boot behavior depends on their
//     level at reset. Usable, but wire carefully (don't hold GPIO0 low at
//     boot unless you mean to enter download mode).
// =============================================================================
#pragma once

// ---- Thermal printer UART (Niklas's domain) --------------------------------
// We use UART2 so UART0 stays free for the serial console.
#define PIN_PRINTER_TX      17   // ESP32 TX -> Printer RX
#define PIN_PRINTER_RX      16   // ESP32 RX -> Printer TX
#define PIN_PRINTER_POWER   -1   // -1 = unused; set to a GPIO if we add a power
                                 // enable MOSFET to let the ESP cut printer power

// ---- Status indicators ------------------------------------------------------
// Separate RGB pins so we can signal boot state via color:
//   - red pulsing       : provisioning (AP up, waiting for creds)
//   - blue pulsing      : connecting to WiFi
//   - green solid       : ready, backend connected
//   - red solid         : fatal error (check serial)
#define PIN_STATUS_LED_R    25
#define PIN_STATUS_LED_G    26
#define PIN_STATUS_LED_B    27

// Buzzer / speaker — chirps when a new message arrives (pre-print).
#define PIN_BUZZER          14

// ---- User input -------------------------------------------------------------
// Dual-purpose with the onboard BOOT button on GPIO0:
//   - short press while running: (reserved, currently no-op)
//   - long press >= PRINTIMATE_RESET_HOLD_MS: factory reset
#define PIN_RESET_BUTTON     0
#define PIN_RESET_BUTTON_ACTIVE_LOW  1   // BOOT button pulls to GND when pressed
