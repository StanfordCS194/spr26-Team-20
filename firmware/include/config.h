// =============================================================================
// config.h — Project-wide constants
// =============================================================================
// Anything that is (a) referenced by more than one module, or (b) likely to be
// tuned during development, lives here. Keeps magic numbers out of .cpp files.
//
// Things that are *secret* (passwords, API keys) go in secrets.h, not here.
// =============================================================================
#pragma once

// ---- Device identity --------------------------------------------------------
// Hardcoded printer ID (PID). One per physical device. Burned into firmware
// at flash time. We chose hardcoded PIDs (rather than backend-assigned) so
// the app can call POST /setup/{pid} immediately after provisioning with no
// intermediate handshake. See team sync notes 2026-04-XX.
//
#ifndef PRINTIMATE_PID
#define PRINTIMATE_PID  "printer1"   // default
#endif

// ---- Provisioning (BLE) -----------------------------------------------------
// The BLE service name is "PROV_<PID>". The app discovers devices by the
// "PROV_" prefix and parses the PID out of the suffix — this lets the app
// learn the PID without any custom protocomm endpoints or hardcoded mapping
// tables. See provisioning.cpp::buildServiceName() for construction.
//
// Note: the PID is broadcast in cleartext during provisioning. PIDs are not
// secrets (they're printed on the device, and surfaced to users in the app),
// so this is acceptable. Don't extend this name to include sensitive data.

// =============================================================================
// DEMO SHORTCUT — REMOVE BEFORE ANY USER-FACING RELEASE
// =============================================================================
// For the CS194 demo we use a fixed proof-of-possession (PoP) compiled into
// both firmware and the Flutter app. This means *any* phone running our app
// build can pair with *any* of our printers. That's fine for a controlled
// demo with 2-5 units in our hands; it would be a security hole in production.
//
// Production plan (deferred):
//   - Each device generates a random PoP at first boot, persists in NVS
//   - PoP is printed on a setup receipt along with a QR code containing
//     {pid, pop, service_name}
//   - App scans QR to extract PoP, then pairs
//
// To remove the shortcut:
//   1. Restore the loadOrGeneratePoP() body in provisioning.cpp
//   2. Add QR scanner to Flutter app (Braedan)
//   3. Update provisioning_logQR() to print to thermal printer, not Serial
// =============================================================================
#define PRINTIMATE_DEMO_FIXED_POP  "printimate"

// ---- Identity ---------------------------------------------------------------
// PRINTIMATE_FIRMWARE_VERSION is injected by platformio.ini via -D.
// Access via the macro; do not redefine here.

#define PRINTIMATE_DEVICE_NAME_PREFIX "Printimate"

// ---- Serial -----------------------------------------------------------------
#define PRINTIMATE_SERIAL_BAUD 115200

// ---- Provisioning (BLE mode, via Espressif WiFiProv) -----------------------
// BLE service name is built at runtime as "PROV_XXXX" from the last 2 MAC
// bytes (matches Espressif convention; recognized by reference apps).
//
// PoP = "proof of possession" — the device-specific shared secret the phone
// must present during the SRP handshake. Per-device, generated at first
// boot, persisted in NVS, printed on the receipt + as a QR code.
#define PRINTIMATE_POP_LEN           10

// ---- WiFi connection retry/backoff -----------------------------------------
#define PRINTIMATE_WIFI_MAX_RETRIES      5
#define PRINTIMATE_WIFI_RETRY_BASE_MS    1000   // exponential: 1s, 2s, 4s, 8s, 16s
#define PRINTIMATE_WIFI_RETRY_MAX_MS     30000  // cap individual retry wait

// ---- Reset button -----------------------------------------------------------
// Long-press duration that triggers factory reset (NVS wipe + reboot to AP).
#define PRINTIMATE_RESET_HOLD_MS    5000

// ---- NVS namespace ----------------------------------------------------------
// All our keys live under this namespace so we don't collide with library-
// internal uses of NVS.
#define PRINTIMATE_NVS_NAMESPACE    "printimate"

// NVS keys. Keep names <= 15 chars (NVS limit).
// Note: Wi-Fi SSID/password are stored by WiFiProv in the IDF's own NVS
// namespace (`nvs.net80211`), not under our namespace. We only store
// our own metadata (PoP, device token, settings) here.
#define PRINTIMATE_NVS_KEY_POP       "ble_pop"
#define PRINTIMATE_NVS_KEY_TOKEN     "dev_token"

// ---- Printer connection health ----------------------------------------------
// If this many consecutive fetch attempts fail, the device assumes connectivity
// has been lost and transitions back to Reconnecting to re-establish the link.
#define PRINTIMATE_PRINTER_MAX_CONSECUTIVE_ERRORS  10

// ---- Message limits ---------------------------------------------------------
// Enforced at firmware boundary; the backend should enforce these too so we
// never receive anything larger. See Felipe's backend spec.
#define PRINTIMATE_MAX_TEXT_CHARS           500
#define PRINTIMATE_MAX_IMAGE_BYTES          (200 * 1024)  // 200 KB after 1-bit dither
#define PRINTIMATE_MAX_IMAGES_PER_MESSAGE   4

// ---- Debug helpers ----------------------------------------------------------
// Use PRINTIMATE_LOG_* rather than Serial.print directly so we can route logs
// (e.g., also to a ring buffer for coredump) in one place later.
#include <Arduino.h>
#define PRINTIMATE_LOG_I(fmt, ...) log_i(fmt, ##__VA_ARGS__)
#define PRINTIMATE_LOG_W(fmt, ...) log_w(fmt, ##__VA_ARGS__)
#define PRINTIMATE_LOG_E(fmt, ...) log_e(fmt, ##__VA_ARGS__)
#define PRINTIMATE_LOG_D(fmt, ...) log_d(fmt, ##__VA_ARGS__)
