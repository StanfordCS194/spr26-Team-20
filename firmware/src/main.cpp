// =============================================================================
// main.cpp — Printimate firmware entry point & boot state machine
// =============================================================================
// This file contains the top-level state machine described in the design doc.
// Each state's real work is delegated to a module (provisioning.cpp,
// printer.cpp, mqtt_client.cpp). Keep this file focused on orchestration.
// =============================================================================
#include <Arduino.h>
#include <Preferences.h>
#include <WiFi.h>

#include "config.h"
#include "pins.h"
#include "provisioning.h"
// #include "printer.h"       // Niklas will flesh out
// #include "mqtt_client.h"   // stub for now

// ---- State machine ----------------------------------------------------------
enum class BootState {
    Boot,
    CheckCredentials,
    Provisioning,
    ConnectingWifi,
    Registering,
    Ready,
    Reconnecting,
};

static BootState g_state = BootState::Boot;
static BootState g_prevState = BootState::Boot;

// Retry tracking for CONNECTING_WIFI / REGISTERING.
static int      g_wifiRetryCount = 0;
static uint32_t g_lastRetryMs    = 0;

// Reset button tracking.
static uint32_t g_buttonDownSinceMs = 0;

// ---- Forward declarations ---------------------------------------------------
static void initPeripherals();
static void onStateEntry(BootState s);
static void onStateExit(BootState s);
static void transitionTo(BootState next);
static void checkResetButton();
static uint32_t backoffMs(int attempt);
static const char* stateName(BootState s);

// =============================================================================
// Arduino entry points
// =============================================================================
void setup() {
    Serial.begin(PRINTIMATE_SERIAL_BAUD);
    delay(200);  // give the USB-serial bridge a moment to come up
    Serial.println();
    Serial.println(F("=== Printimate firmware booting ==="));
    Serial.print(F("Version: "));
    Serial.println(PRINTIMATE_FIRMWARE_VERSION);
    Serial.print(F("Build env: "));
    Serial.println(PRINTIMATE_BUILD_ENV);

    initPeripherals();
    transitionTo(BootState::CheckCredentials);
}

void loop() {
    checkResetButton();

    switch (g_state) {
        case BootState::Boot:
            // Unreachable after setup(); guard just in case.
            transitionTo(BootState::CheckCredentials);
            break;

        case BootState::CheckCredentials: {
            Preferences prefs;
            prefs.begin(PRINTIMATE_NVS_NAMESPACE, /*readOnly=*/true);
            bool hasCreds = prefs.isKey(PRINTIMATE_NVS_KEY_SSID) &&
                            prefs.isKey(PRINTIMATE_NVS_KEY_PASS);
            prefs.end();
            transitionTo(hasCreds ? BootState::ConnectingWifi
                                  : BootState::Provisioning);
            break;
        }

        case BootState::Provisioning:
            // All work happens in provisioning.cpp. Poll for completion.
            provisioning_loop();
            if (provisioning_isComplete()) {
                transitionTo(BootState::ConnectingWifi);
            }
            break;

        case BootState::ConnectingWifi: {
            wl_status_t ws = WiFi.status();
            if (ws == WL_CONNECTED) {
                PRINTIMATE_LOG_I("WiFi connected, IP=%s",
                                 WiFi.localIP().toString().c_str());
                g_wifiRetryCount = 0;
                // TODO: check NVS for device token; skip to Ready if present.
                transitionTo(BootState::Registering);
            } else if (millis() - g_lastRetryMs > backoffMs(g_wifiRetryCount)) {
                if (g_wifiRetryCount >= PRINTIMATE_WIFI_MAX_RETRIES) {
                    PRINTIMATE_LOG_W("WiFi creds look stale, falling back to provisioning");
                    transitionTo(BootState::Provisioning);
                } else {
                    Preferences prefs;
                    prefs.begin(PRINTIMATE_NVS_NAMESPACE, /*readOnly=*/true);
                    String ssid = prefs.getString(PRINTIMATE_NVS_KEY_SSID, "");
                    String pass = prefs.getString(PRINTIMATE_NVS_KEY_PASS, "");
                    prefs.end();
                    PRINTIMATE_LOG_I("WiFi connect attempt %d to '%s'",
                                     g_wifiRetryCount + 1, ssid.c_str());
                    WiFi.begin(ssid.c_str(), pass.c_str());
                    g_wifiRetryCount++;
                    g_lastRetryMs = millis();
                }
            }
            break;
        }

        case BootState::Registering:
            // TODO: call backend /devices/register; store token in NVS.
            // Stub: pretend it succeeded after a moment.
            PRINTIMATE_LOG_I("Registering with backend (stub)");
            delay(500);
            transitionTo(BootState::Ready);
            break;

        case BootState::Ready:
            // TODO: mqtt_client_loop() + printer_handleJobs();
            // If MQTT drops, transition to Reconnecting.
            break;

        case BootState::Reconnecting:
            // TODO: retry MQTT with backoff; return to Ready on success.
            break;
    }

    // Keep loop() cooperative — yield to FreeRTOS so WiFi/TCP tasks run.
    delay(10);
}

// =============================================================================
// State machine plumbing
// =============================================================================
static void transitionTo(BootState next) {
    if (next == g_state) return;
    PRINTIMATE_LOG_I("State: %s -> %s", stateName(g_state), stateName(next));
    onStateExit(g_state);
    g_prevState = g_state;
    g_state = next;
    onStateEntry(next);
}

static void onStateEntry(BootState s) {
    switch (s) {
        case BootState::Provisioning:
            provisioning_begin();
            // TODO: pulse red LED
            break;
        case BootState::ConnectingWifi:
            WiFi.mode(WIFI_STA);
            g_wifiRetryCount = 0;
            g_lastRetryMs = 0;  // force an immediate first attempt
            // TODO: pulse blue LED
            break;
        case BootState::Ready:
            // TODO: solid green LED; connect MQTT
            break;
        default: break;
    }
}

static void onStateExit(BootState s) {
    switch (s) {
        case BootState::Provisioning:
            provisioning_end();
            break;
        default: break;
    }
}

// =============================================================================
// Helpers
// =============================================================================
static void initPeripherals() {
    pinMode(PIN_STATUS_LED_R, OUTPUT);
    pinMode(PIN_STATUS_LED_G, OUTPUT);
    pinMode(PIN_STATUS_LED_B, OUTPUT);
    pinMode(PIN_BUZZER, OUTPUT);
    pinMode(PIN_RESET_BUTTON, INPUT_PULLUP);
    // Printer UART init deferred to printer_begin() (Niklas).
}

static void checkResetButton() {
    bool pressed = (digitalRead(PIN_RESET_BUTTON) == LOW) ==
                   (PIN_RESET_BUTTON_ACTIVE_LOW != 0);
    if (pressed) {
        if (g_buttonDownSinceMs == 0) {
            g_buttonDownSinceMs = millis();
        } else if (millis() - g_buttonDownSinceMs >= PRINTIMATE_RESET_HOLD_MS) {
            PRINTIMATE_LOG_W("Reset button held; wiping NVS and rebooting");
            Preferences prefs;
            prefs.begin(PRINTIMATE_NVS_NAMESPACE, /*readOnly=*/false);
            prefs.clear();
            prefs.end();
            delay(200);
            ESP.restart();
        }
    } else {
        g_buttonDownSinceMs = 0;
    }
}

// Exponential backoff with a cap: 1s, 2s, 4s, 8s, 16s, 30s, 30s...
static uint32_t backoffMs(int attempt) {
    uint32_t ms = PRINTIMATE_WIFI_RETRY_BASE_MS << attempt;
    if (ms > PRINTIMATE_WIFI_RETRY_MAX_MS) ms = PRINTIMATE_WIFI_RETRY_MAX_MS;
    return ms;
}

static const char* stateName(BootState s) {
    switch (s) {
        case BootState::Boot:             return "Boot";
        case BootState::CheckCredentials: return "CheckCredentials";
        case BootState::Provisioning:     return "Provisioning";
        case BootState::ConnectingWifi:   return "ConnectingWifi";
        case BootState::Registering:      return "Registering";
        case BootState::Ready:            return "Ready";
        case BootState::Reconnecting:     return "Reconnecting";
    }
    return "?";
}
