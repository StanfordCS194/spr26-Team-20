// =============================================================================
// provisioning.cpp — SoftAP + captive-portal implementation (STUB)
// =============================================================================
// This is a scaffold. Fill in:
//   1. SoftAP bring-up with a per-device password (derived from MAC).
//   2. HTTP endpoints:
//        GET  /info      -> JSON { device_id, firmware_version }
//        POST /provision -> accepts { ssid, password, token }
//                           test-connects, writes NVS on success
//   3. A completion flag set by the POST handler.
//   4. A short delay between HTTP response and AP teardown so the phone
//      actually receives the 200 before losing the connection.
// =============================================================================
#include "provisioning.h"

#include <Arduino.h>
#include <WiFi.h>
#include <Preferences.h>

#include "config.h"

static bool g_complete = false;
// TODO: static AsyncWebServer g_server(PRINTIMATE_HTTP_PORT);

void provisioning_begin() {
    PRINTIMATE_LOG_I("Provisioning: starting SoftAP");
    g_complete = false;

    // Build SSID "Printimate-Setup-XXXX" from MAC.
    uint8_t mac[6];
    WiFi.macAddress(mac);
    char ssid[48];
    snprintf(ssid, sizeof(ssid), "%s-Setup-%02X%02X",
             PRINTIMATE_DEVICE_NAME_PREFIX, mac[4], mac[5]);

    // TODO: generate a strong random password, persist it to NVS so we can
    // reprint it on demand, and have the printer print it during setup mode.
    const char* tempPassword = "printimate";  // placeholder

    WiFi.mode(WIFI_AP);
    WiFi.softAP(ssid, tempPassword, PRINTIMATE_AP_CHANNEL,
                /*ssid_hidden=*/0, PRINTIMATE_AP_MAX_CLIENTS);

    PRINTIMATE_LOG_I("AP up: SSID='%s' IP=%s",
                     ssid, WiFi.softAPIP().toString().c_str());

    // TODO: g_server.on("/info", HTTP_GET, handleInfo);
    // TODO: g_server.on("/provision", HTTP_POST, handleProvision);
    // TODO: g_server.begin();
}

void provisioning_loop() {
    // AsyncWebServer runs on its own task, so nothing to do here yet.
    // TODO: if using a sync server instead, call handleClient() here.
}

void provisioning_end() {
<<<<<<< Updated upstream
    PRINTIMATE_LOG_I("Provisioning: tearing down AP");
    // TODO: g_server.end();
    WiFi.softAPdisconnect(/*wifioff=*/true);
=======
    PRINTIMATE_LOG_I("Provisioning: tearing down (BLE memory will be freed)");
    // The NETWORK_PROV_SCHEME_HANDLER_FREE_BLE handler we passed to
    // beginProvision() arranges for the manager to be deinitialized AND
    // the BLE stack memory to be released on PROV_END. Calling
    // network_prov_mgr_deinit() ourselves here would be a double-free of
    // the manager's internal FreeRTOS queues — the framework already did
    // it. Leaving this function as effectively a no-op (just logging) is
    // intentional. If we ever stop using the FREE_BLE handler, this is
    // where the explicit deinit would belong.
>>>>>>> Stashed changes
}

bool provisioning_isComplete() {
    return g_complete;
}
<<<<<<< Updated upstream
=======

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

    // Wipe Wi-Fi creds stored by the provisioning manager. Safe to call even
    // if the manager is not currently initialized — it'll do a one-shot init.
    //
    // IMPORTANT: in the network_prov API, two similarly-named functions
    // exist with different semantics:
    //   - network_prov_mgr_reset_provisioning():
    //       resets the manager's internal state machine. Does NOT wipe creds.
    //   - network_prov_mgr_reset_wifi_provisioning():
    //       wipes the stored Wi-Fi credentials.
    // We want the second one for a factory reset. (In the older wifi_prov API,
    // the first name had the credential-wiping semantics — beware when
    // copy-pasting from older examples or rolling back the platform pin.)
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
        "{\"ver\":\"v1\",\"name\":\"%s\",\"pid\":\"%s\",\"pop\":\"%s\","
        "\"transport\":\"ble\",\"security\":2}",
        g_serviceName, PRINTIMATE_PID, g_pop
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
    snprintf(g_serviceName, sizeof(g_serviceName), "PROV_%s", PRINTIMATE_PID);
}

// will do later if have time
//
// Per-device PoP. Generated once at first boot and persisted in NVS so it
// survives reboots and matches the QR code we print for the recipient.
//static void loadOrGeneratePoP() {
//    Preferences prefs;
//    prefs.begin(PRINTIMATE_NVS_NAMESPACE, /*readOnly=*/false);
//
//    String stored = prefs.getString(PRINTIMATE_NVS_KEY_POP, "");
//    if (stored.length() == PRINTIMATE_POP_LEN) {
//        strncpy(g_pop, stored.c_str(), sizeof(g_pop) - 1);
//    } else {
//        // Generate a fresh PoP. esp_random() is hardware-RNG backed.
//        static const char alphabet[] =
//            "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";  // ambiguous chars removed
//        const size_t alphabetLen = sizeof(alphabet) - 1;
//        for (size_t i = 0; i < PRINTIMATE_POP_LEN; ++i) {
//            g_pop[i] = alphabet[esp_random() % alphabetLen];
//        }
//        g_pop[PRINTIMATE_POP_LEN] = '\0';
//        prefs.putString(PRINTIMATE_NVS_KEY_POP, g_pop);
//        PRINTIMATE_LOG_I("Generated new PoP and stored in NVS");
//    }
//    prefs.end();
//}

static void loadOrGeneratePoP() {
    // DEMO SHORTCUT: fixed PoP shared with the Flutter app. See config.h for
    // the production plan that replaces this with per-device random PoPs.
    strncpy(g_pop, PRINTIMATE_DEMO_FIXED_POP, sizeof(g_pop) - 1);
    g_pop[sizeof(g_pop) - 1] = '\0';
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
>>>>>>> Stashed changes
