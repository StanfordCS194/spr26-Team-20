// =============================================================================
// secrets.example.h — Template for local development secrets
// =============================================================================
// DO NOT commit a populated secrets.h. This file exists so each team member
// can copy it to `secrets.h` and fill in values for their own dev environment:
//
//     cp include/secrets.example.h include/secrets.h
//
// `secrets.h` is listed in .gitignore.
//
// In production, these values are NOT baked into firmware — they arrive during
// device provisioning via the SoftAP captive portal. The constants below are
// only for development convenience (e.g., skipping the provisioning flow when
// iterating on other parts of the code).
// =============================================================================
#pragma once

// ---- Development WiFi (optional) -------------------------------------------
// If set, the dev firmware can skip provisioning and connect directly.
// Leave blank (empty string) to force normal provisioning flow.
#define DEV_WIFI_SSID         ""
#define DEV_WIFI_PASSWORD     ""

// ---- Backend endpoints ------------------------------------------------------
// Coordinate with Felipe for the real values once his backend is up.
#define PRINTIMATE_API_BASE_URL  "https://api.printimate.example.com"
#define PRINTIMATE_MQTT_HOST     "mqtt.printimate.example.com"
#define PRINTIMATE_MQTT_PORT     8883   // TLS

// ---- Dev-only registration token -------------------------------------------
// Temporary until Felipe's pairing flow is wired up.
#define DEV_DEVICE_TOKEN      ""
