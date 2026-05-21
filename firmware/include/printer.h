// =============================================================================
// printer.h — Thermal printer interface
// =============================================================================
// Manages the Adafruit thermal printer on UART2 (pins defined in pins.h).
// Hardware objects live as statics in printer.cpp; this struct carries only
// the thin state needed by the boot state machine.
//
// Typical lifecycle:
//   1. printer_begin()               — called once on entry to Ready state
//   2. printer_fetchAndPrintMessages() — polled every ~5 s in the Ready loop
// =============================================================================
#pragma once

#include <Arduino.h>
#include "config.h"

// ---- Message ----------------------------------------------------------------
// Mirrors the backend Message type. sentTimestamp is kept as a raw ISO-8601
// string; images holds the URLs of any attachments (fetched separately).
struct Message {
    String authorUid;
    String destinationPid;
    String authorName;
    String sentTimestamp;
    String messageText;
    String images[PRINTIMATE_MAX_IMAGES_PER_MESSAGE];
    int    imageCount = 0;
    bool   printed    = false;
};

// ---- Printer ----------------------------------------------------------------
struct Printer {
    bool initialized      = false;
    int  consecutiveErrors = 0;
};

// Initialise UART2 and the Adafruit_Thermal driver. Prints a startup banner
// (MAC + IP) so the user knows the device is online. Call from onStateEntry(Ready).
void printer_begin(Printer &p);

// HTTP GET to PRINTIMATE_API_BASE_URL/messages, parse JSON, and call
// printer_printMessage for each entry. Returns true if at least one message
// was printed, false on any network or parse error.
bool printer_fetchAndPrintMessages(Printer &p);

// Format and print a single Message to the thermal printer.
void printer_printMessage(Printer &p, const Message &msg);
