// =============================================================================
// provisioning.h — BLE Wi-Fi provisioning (Espressif WiFiProv)
// =============================================================================
// Architectural decision: we use BLE provisioning via Espressif's WiFiProv
// library rather than a SoftAP captive portal. See `docs/adr-001-ble-prov.md`
// (Braedan's decision doc) for rationale. Short version: the iOS user
// experience for SoftAP is rough (forced trip out of the app to Settings,
// "no internet" warnings, manual SSID entry), and Espressif ships a polished
// first-party SDK on iOS, Android, and Flutter that talks to WiFiProv directly.
//
// What this module does:
//   - On `provisioning_begin()`, starts BLE advertising as "PROV_XXXX" and
//     waits for an app to push Wi-Fi credentials over an authenticated GATT
//     channel. The library handles the GATT, the Protocomm handshake, the
//     SRP/AES exchange, and the NVS write of credentials.
//   - On successful credential receipt + Wi-Fi association, sets the
//     `complete` flag so the boot state machine can transition out.
//   - On `provisioning_end()`, tears down BLE (frees ~30-60 KB of RAM that
//     the BLE stack was holding) — important because the BLE stack is large
//     and we don't need it after first-time setup.
//
// What this module deliberately does NOT do:
//   - Manage Wi-Fi credentials in our own NVS namespace. WiFiProv stores
//     them in the `nvs.net80211` namespace using the same format the IDF
//     expects. We never touch them directly.
//   - Run anything in `loop()`. Provisioning is fully event-driven; the
//     loop hook is a no-op.
// =============================================================================
#pragma once

#include <Arduino.h>

// ---- State machine integration ---------------------------------------------
void provisioning_begin();
void provisioning_loop();   // currently a no-op; kept for symmetry
void provisioning_end();
bool provisioning_isComplete();

// ---- Helpers used by main.cpp ----------------------------------------------
// Returns true if WiFiProv has Wi-Fi credentials stored from a previous
// provisioning session. Use this in CheckCredentials state to skip provisioning.
bool provisioning_hasStoredCredentials();

// Fully wipes WiFiProv's stored credentials. Call from the factory-reset
// handler (long-press of the reset button).
void provisioning_factoryReset();

// Prints the BLE provisioning QR payload to Serial as a fallback if the
// printer isn't ready yet. The payload format is the standard one accepted
// by Espressif's iOS/Android/Flutter provisioning SDKs.
void provisioning_logQR();
