// =============================================================================
// config.h — Project-wide constants
// =============================================================================
// Anything that is (a) referenced by more than one module, or (b) likely to be
// tuned during development, lives here. Keeps magic numbers out of .cpp files.
//
// Things that are *secret* (passwords, API keys) go in secrets.h, not here.
// =============================================================================
#pragma once

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
#define PRINTIMATE_POP_LEN           8

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

// ---- Message limits ---------------------------------------------------------
// Enforced at firmware boundary; the backend should enforce these too so we
// never receive anything larger. See Felipe's backend spec.
#define PRINTIMATE_MAX_TEXT_CHARS     500
#define PRINTIMATE_MAX_IMAGE_BYTES    (200 * 1024)  // 200 KB after 1-bit dither

// ---- MQTT -------------------------------------------------------------------
#define PRINTIMATE_MQTT_KEEPALIVE_SEC 60
#define PRINTIMATE_MQTT_BUFFER_SIZE   2048   // envelope only; images fetched via HTTPS

// ---- Debug helpers ----------------------------------------------------------
// Use PRINTIMATE_LOG_* rather than Serial.print directly so we can route logs
// (e.g., also to a ring buffer for coredump) in one place later.
#include <Arduino.h>
#define PRINTIMATE_LOG_I(fmt, ...) log_i(fmt, ##__VA_ARGS__)
#define PRINTIMATE_LOG_W(fmt, ...) log_w(fmt, ##__VA_ARGS__)
#define PRINTIMATE_LOG_E(fmt, ...) log_e(fmt, ##__VA_ARGS__)
#define PRINTIMATE_LOG_D(fmt, ...) log_d(fmt, ##__VA_ARGS__)
