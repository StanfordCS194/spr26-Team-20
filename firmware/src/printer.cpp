// =============================================================================
// printer.cpp — Thermal printer implementation
// =============================================================================
#include "printer.h"

#include <Arduino.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <time.h>
#include "Adafruit_Thermal.h"

#include "config.h"
#include "pins.h"
#include "secrets.h"

// =============================================================================
// formatTimestampPT
// =============================================================================
// Parses an ISO 8601 UTC timestamp and returns "HH:MM" in US Pacific Time,
// with DST handled via the POSIX tz database string for the Pacific zone.
//
// In the future, this should support arbitrary timezones but for now we hard-code
// PT since we only have a few printers for testing.
static String formatTimestampPT(const String &iso) {
    struct tm utcTm = {};
    if (sscanf(iso.c_str(), "%d-%d-%dT%d:%d:%d",
               &utcTm.tm_year, &utcTm.tm_mon, &utcTm.tm_mday,
               &utcTm.tm_hour, &utcTm.tm_min, &utcTm.tm_sec) < 6) {
        return iso;  // unparseable — fall back to raw string
    }
    utcTm.tm_year -= 1900;
    utcTm.tm_mon  -= 1;
    utcTm.tm_isdst = 0;

    // mktime treats the struct as local time, so temporarily set TZ=UTC so
    // the parsed fields are interpreted correctly before converting to PT.
    setenv("TZ", "UTC0", 1);
    tzset();
    time_t t = mktime(&utcTm);

    // PST8PDT,M3.2.0,M11.1.0 = Pacific Standard (UTC-8) / Daylight (UTC-7),
    // switching on the 2nd Sunday of March and 1st Sunday of November.
    setenv("TZ", "PST8PDT,M3.2.0,M11.1.0", 1);
    tzset();
    struct tm ptTm;
    localtime_r(&t, &ptTm);

    char buf[6];
    snprintf(buf, sizeof(buf), "%02d:%02d", ptTm.tm_hour, ptTm.tm_min);
    return String(buf);
}

// Static hardware objects — avoids constructor-ordering issues on ESP32/Arduino.
static HardwareSerial g_printerSerial(PRINTER_UART_NUM);
static Adafruit_Thermal g_thermalPrinter(&g_printerSerial);

// =============================================================================
// printer_begin
// =============================================================================
void printer_begin(Printer &p) {
    g_printerSerial.begin(9600, SERIAL_8N1, PIN_PRINTER_RX, PIN_PRINTER_TX);
    g_thermalPrinter.begin();
    p.initialized = true;

    PRINTIMATE_LOG_I("Printer: UART2 ready (TX=%d RX=%d)", PIN_PRINTER_TX, PIN_PRINTER_RX);

    // Startup banner — gives the user a physical confirmation the device is online.
    g_thermalPrinter.println("=== Printimate Online ===");
    g_thermalPrinter.print("MAC: ");
    g_thermalPrinter.println(WiFi.macAddress());
    g_thermalPrinter.print("IP:  ");
    g_thermalPrinter.println(WiFi.localIP());
    g_thermalPrinter.feed(2);
}

// =============================================================================
// printer_printMessage
// =============================================================================
void printer_printMessage(Printer &p, const Message &msg) {
    g_thermalPrinter.println("================================");
    g_thermalPrinter.print("From: ");
    g_thermalPrinter.println(msg.authorName);
    g_thermalPrinter.print("Sent: ");
    g_thermalPrinter.println(formatTimestampPT(msg.sentTimestamp));
    g_thermalPrinter.println();
    g_thermalPrinter.println(msg.messageText);

    if (msg.imageCount > 0) {
        // TODO: fetch each URL via HTTPS and print as a 1-bit dithered bitmap.
        // Max size: PRINTIMATE_MAX_IMAGE_BYTES. See Felipe's image spec.
        PRINTIMATE_LOG_W("Printer: %d image(s) — image printing not yet implemented",
                         msg.imageCount);
    }

    g_thermalPrinter.feed(3);
}

// =============================================================================
// printer_fetchAndPrintMessages
// =============================================================================
// Polls the backend for pending messages and prints each one. Called every
// ~5 s from the Ready state loop. Increments p.consecutiveErrors on any
// failure (network, HTTP, or JSON) so the caller can detect a dead connection
// and transition to Reconnecting. Resets the counter on a clean 200 response.
bool printer_fetchAndPrintMessages(Printer &p) {
    if (!p.initialized) {
        PRINTIMATE_LOG_W("Printer: not initialised, skipping fetch");
        return false;
    }
    if (WiFi.status() != WL_CONNECTED) {
        PRINTIMATE_LOG_W("Printer: WiFi not connected, skipping fetch");
        return false;
    }

    // Build request. DEV_DEVICE_TOKEN is empty in production — the real token
    // will come from NVS once the registration flow is wired up.
    String url = String(PRINTIMATE_API_BASE_URL) + "/messages?pid=" + DEV_DEVICE_TOKEN;
    PRINTIMATE_LOG_I("Printer: GET %s", url.c_str());

    HTTPClient http;
    http.begin(url);

    if (strlen(DEV_DEVICE_TOKEN) > 0) {
        http.addHeader("Authorization", String("Bearer ") + DEV_DEVICE_TOKEN);
    }

    int code = http.GET();
    PRINTIMATE_LOG_I("Printer: HTTP %d", code);

    if (code != HTTP_CODE_OK) {
        if (code > 0) {
            PRINTIMATE_LOG_W("Printer: non-200 response, skipping print");
        } else {
            PRINTIMATE_LOG_E("Printer: request failed: %s", http.errorToString(code).c_str());
        }
        http.end();
        p.consecutiveErrors++;
        return false;
    }

    // Read the full response body before closing the connection.
    String body = http.getString();
    http.end();

    // Parse the JSON array. ArduinoJson v7 allocates from the heap; the doc
    // is freed when it goes out of scope at the end of this function.
    JsonDocument doc;
    DeserializationError err = deserializeJson(doc, body);
    if (err) {
        PRINTIMATE_LOG_E("Printer: JSON parse failed: %s", err.c_str());
        p.consecutiveErrors++;
        return false;
    }

    // Iterate over messages and print each one.
    int printed = 0;
    for (JsonObject obj : doc.as<JsonArray>()) {
        Message msg;
        msg.authorUid      = obj["authorUid"]      | "";
        msg.destinationPid = obj["destinationPid"] | "";
        msg.authorName     = obj["authorName"]     | "";
        msg.sentTimestamp  = obj["sentTimestamp"]  | "";
        msg.messageText    = obj["messageText"]    | "";
        msg.printed        = obj["printed"]        | false;

        // Collect image URLs up to the per-message cap; extras are silently
        // dropped. Actual fetching is deferred to printer_printMessage.
        for (const char *imgUrl : obj["images"].as<JsonArray>()) {
            if (msg.imageCount < PRINTIMATE_MAX_IMAGES_PER_MESSAGE) {
                msg.images[msg.imageCount++] = imgUrl;
            }
        }

        if (!msg.printed) {
            printer_printMessage(p, msg);
            printed++;
        }
    }

    PRINTIMATE_LOG_I("Printer: printed %d message(s)", printed);
    p.consecutiveErrors = 0;
    return true;
}
