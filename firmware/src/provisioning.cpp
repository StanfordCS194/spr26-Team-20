// =============================================================================
// provisioning.cpp — BLE Wi-Fi provisioning implementation
// =============================================================================
// Implementation notes:
//
//   1. The whole flow is driven by `WiFi.onEvent(...)`. WiFiProv emits a
//      sequence of events:
//         ARDUINO_EVENT_PROV_START         — BLE advertising up
//         ARDUINO_EVENT_PROV_CRED_RECV     — phone sent SSID/password
//         ARDUINO_EVENT_PROV_CRED_FAIL     — Wi-Fi association failed
//         ARDUINO_EVENT_PROV_CRED_SUCCESS  — Wi-Fi joined OK
//         ARDUINO_EVENT_PROV_END           — BLE torn down by lib
//      We only set `g_complete = true` on CRED_SUCCESS (followed by GOT_IP
//      from the Wi-Fi event group), so a typo in the password keeps the
//      device in provisioning mode rather than dropping out and stranding
//      the user mid-setup.
//
//   2. The "proof of possession" (PoP) string is a shared secret the phone
//      must present to the device to derive the session key. Hard-coding
//      the same PoP across all devices defeats the point. We generate a
//      device-specific PoP from the MAC at first boot, store it in NVS,
//      and print it (a) over Serial for dev visibility and (b) on the
//      thermal printer + as a QR code once the printer driver is ready.
//      For now the QR code is logged to Serial as a fallback.
//
//   3. The default 128-bit service UUID from Espressif's example is fine
//      for our needs — we do not need a custom one and changing it would
//      mean the off-the-shelf reference apps wouldn't see our device.
//
//   4. We pass `reset_provisioned = false` so the device picks up stored
//      credentials on subsequent boots. The factory-reset path explicitly
//      calls `network_prov_mgr_reset_wifi_provisioning()` before reboot.
// =============================================================================
#include "provisioning.h"

#include <WiFi.h>
#include <WiFiProv.h>
#include <Preferences.h>
#include <esp_wifi.h>
#include <wifi_provisioning/manager.h>

#include "config.h"

// ---- Module state -----------------------------------------------------------
static volatile bool g_complete = false;
static char          g_serviceName[24] = {0};      // "PROV_XXXX"
static char          g_pop[PRINTIMATE_POP_LEN + 1] = {0};

// Default UUID from the Espressif WiFiProv example. Keeps us compatible with
// the reference iOS/Android apps and the Flutter `esp_provisioning_ble`
// package out of the box.
static const uint8_t kServiceUUID[16] = {
    0xb4, 0xdf, 0x5a, 0x1c, 0x3f, 0x6b, 0xf4, 0xbf,
    0xea, 0x4a, 0x82, 0x03, 0x04, 0x90, 0x1a, 0x02,
};

// ---- Forward declarations ---------------------------------------------------
static void onWiFiProvEvent(arduino_event_t *event);
static void buildServiceName();
static void loadOrGeneratePoP();

// =============================================================================
// Public API
// =============================================================================
void provisioning_begin() {
    PRINTIMATE_LOG_I("Provisioning: starting BLE flow");
    g_complete = false;

    buildServiceName();
    loadOrGeneratePoP();

    PRINTIMATE_LOG_I("BLE service name: %s", g_serviceName);
    PRINTIMATE_LOG_I("Proof of possession: %s", g_pop);

    WiFi.onEvent(onWiFiProvEvent);

    // Hand off to the library. Args:
    //   scheme               — BLE transport
    //   scheme_handler       — let the lib free BLE memory at end-of-prov
    //   security             — SECURITY_1 = SRP6a + AES-CTR (PoP required)
    //   pop                  — our per-device proof of possession
    //   service_name         — BLE adv name shown in the app
    //   service_key          — unused for BLE; only meaningful for SoftAP
    //   uuid                 — 128-bit service UUID
    //   reset_provisioned    — false; honor stored creds across reboots
    WiFiProv.beginProvision(
        NETWORK_PROV_SCHEME_BLE,
        NETWORK_PROV_SCHEME_HANDLER_FREE_BLE,
        NETWORK_PROV_SECURITY_1,
        g_pop,
        g_serviceName,
        /*service_key=*/nullptr,
        const_cast<uint8_t*>(kServiceUUID),
        /*reset_provisioned=*/false
    );

    // Until the thermal printer driver is up, log the QR payload so devs
    // can scan from Serial during bring-up. Niklas's printer module will
    // eventually replace this with an actual printed QR receipt.
    provisioning_logQR();
}

void provisioning_loop() {
    // No-op. WiFiProv runs on its own FreeRTOS task; we react in events.
}

void provisioning_end() {
    PRINTIMATE_LOG_I("Provisioning: tearing down (BLE memory will be freed)");
    // The NETWORK_PROV_SCHEME_HANDLER_FREE_BLE handler we passed to
    // beginProvision() arranges for the BLE stack memory to be released
    // on PROV_END. We just need to make sure the manager itself is
    // de-initialized so we don't leak its task.
    network_prov_mgr_deinit();
}

bool provisioning_isComplete() {
    return g_complete;
}

bool provisioning_hasStoredCredentials() {
    // Ask the IDF directly rather than peeking at NVS by hand. This works
    // whether or not WiFiProv has been initialized yet.
    wifi_config_t cfg;
    if (esp_wifi_get_config(WIFI_IF_STA, &cfg) != ESP_OK) {
        return false;
    }
    return cfg.sta.ssid[0] != 0;
}

void provisioning_factoryReset() {
    PRINTIMATE_LOG_W("Provisioning: factory reset requested");

    // Wipe our own settings (PoP, device token, etc.).
    Preferences prefs;
    prefs.begin(PRINTIMATE_NVS_NAMESPACE, /*readOnly=*/false);
    prefs.clear();
    prefs.end();

    // Wipe Wi-Fi creds stored by WiFiProv. Safe to call even if the prov
    // manager is not currently initialized — it'll do a one-shot init.
    network_prov_mgr_config_t cfg = {};
    cfg.scheme = network_prov_scheme_ble;
    cfg.scheme_event_handler = NETWORK_PROV_EVENT_HANDLER_NONE;
    if (network_prov_mgr_init(cfg) == ESP_OK) {
        network_prov_mgr_reset_wifi_provisioning();
        network_prov_mgr_deinit();
    }
}

void provisioning_logQR() {
    // Standard QR payload understood by the Espressif provisioning apps
    // and the `esp_provisioning_ble` Flutter package.
    PRINTIMATE_LOG_I(
        "Provisioning QR payload: "
        "{\"ver\":\"v1\",\"name\":\"%s\",\"pop\":\"%s\","
        "\"transport\":\"ble\",\"security\":2}",
        g_serviceName, g_pop
    );
    // Convenience: the same payload as a hosted QR URL Niklas can scan
    // during bring-up before the on-device QR printing is wired up.
    PRINTIMATE_LOG_I(
        "Or render at: https://espressif.github.io/esp-jumpstart/qrcode.html"
        "?data=%%7B%%22ver%%22%%3A%%22v1%%22%%2C%%22name%%22%%3A%%22%s%%22"
        "%%2C%%22pop%%22%%3A%%22%s%%22%%2C%%22transport%%22%%3A%%22ble%%22"
        "%%2C%%22security%%22%%3A2%%7D",
        g_serviceName, g_pop
    );
}

// =============================================================================
// Internals
// =============================================================================

// Build "PROV_XXXX" from the last two MAC bytes. Matches the convention used
// by Espressif's reference apps and keeps the name short enough to fit in
// the 31-byte BLE advertising packet.
static void buildServiceName() {
    uint8_t mac[6];
    WiFi.macAddress(mac);
    snprintf(g_serviceName, sizeof(g_serviceName),
             "PROV_%02X%02X", mac[4], mac[5]);
}

// Per-device PoP. Generated once at first boot and persisted in NVS so it
// survives reboots and matches the QR code we print for the recipient.
static void loadOrGeneratePoP() {
    Preferences prefs;
    prefs.begin(PRINTIMATE_NVS_NAMESPACE, /*readOnly=*/false);

    String stored = prefs.getString(PRINTIMATE_NVS_KEY_POP, "");
    if (stored.length() == PRINTIMATE_POP_LEN) {
        strncpy(g_pop, stored.c_str(), sizeof(g_pop) - 1);
    } else {
        // Generate a fresh PoP. esp_random() is hardware-RNG backed.
        static const char alphabet[] =
            "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";  // ambiguous chars removed
        const size_t alphabetLen = sizeof(alphabet) - 1;
        for (size_t i = 0; i < PRINTIMATE_POP_LEN; ++i) {
            g_pop[i] = alphabet[esp_random() % alphabetLen];
        }
        g_pop[PRINTIMATE_POP_LEN] = '\0';
        prefs.putString(PRINTIMATE_NVS_KEY_POP, g_pop);
        PRINTIMATE_LOG_I("Generated new PoP and stored in NVS");
    }
    prefs.end();
}

// Single event sink for both Wi-Fi and provisioning events emitted by the
// library. We only flip `g_complete` once we have an IP, so a CRED_SUCCESS
// without IP (transient) doesn't prematurely end provisioning.
static void onWiFiProvEvent(arduino_event_t *event) {
    switch (event->event_id) {
        case ARDUINO_EVENT_PROV_START:
            PRINTIMATE_LOG_I("BLE advertising; waiting for credentials");
            break;

        case ARDUINO_EVENT_PROV_CRED_RECV: {
            const auto& info = event->event_info.prov_cred_recv;
            // NOTE: do not log the password in production builds. Guard
            // with the build-env macro so dev builds still surface it.
            #ifdef PRINTIMATE_BUILD_ENV_IS_DEV
            PRINTIMATE_LOG_I("Received credentials: SSID='%s' PASS='%s'",
                             (const char*)info.ssid, (const char*)info.password);
            #else
            PRINTIMATE_LOG_I("Received credentials: SSID='%s'",
                             (const char*)info.ssid);
            #endif
            break;
        }

        case ARDUINO_EVENT_PROV_CRED_FAIL: {
            const auto& info = event->event_info.prov_fail_reason;
            if (info == NETWORK_PROV_WIFI_STA_AUTH_ERROR) {
                PRINTIMATE_LOG_W("Provisioning failed: bad Wi-Fi password");
            } else {
                PRINTIMATE_LOG_W("Provisioning failed: AP not found");
            }
            // Stay in provisioning so the user can retry from the app.
            break;
        }

        case ARDUINO_EVENT_PROV_CRED_SUCCESS:
            PRINTIMATE_LOG_I("Credentials accepted; Wi-Fi associating");
            break;

        case ARDUINO_EVENT_PROV_END:
            PRINTIMATE_LOG_I("Provisioning manager ended");
            break;

        case ARDUINO_EVENT_WIFI_STA_GOT_IP:
            // This is the real "we're good" signal. CRED_SUCCESS only means
            // the password was right; GOT_IP means DHCP completed.
            PRINTIMATE_LOG_I("Got IP %s — provisioning complete",
                             IPAddress(event->event_info.got_ip.ip_info.ip.addr)
                                 .toString().c_str());
            g_complete = true;
            break;

        default:
            break;
    }
}
