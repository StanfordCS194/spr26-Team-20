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
    PRINTIMATE_LOG_I("Provisioning: tearing down AP");
    // TODO: g_server.end();
    WiFi.softAPdisconnect(/*wifioff=*/true);
}

bool provisioning_isComplete() {
    return g_complete;
}
