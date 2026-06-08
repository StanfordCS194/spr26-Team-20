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

// Statically allocated buffer for HTTP responses
static char buf[PRINTIMATE_MAX_RESPONSE_BYTES];

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

// Full-width solid divider line, 3 pixels tall.
static constexpr int kDividerHeightPx = 3;
static const uint8_t kDivider[] = {
    0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
    0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
    0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
};
static_assert(sizeof(kDivider) == kDividerHeightPx * (PRINTIMATE_PRINTER_WIDTH_PX / 8),
              "kDivider byte count does not match printer width * height");

// =============================================================================
// printer_begin
// =============================================================================
void printer_begin(Printer &p) {
    g_printerSerial.begin(9600, SERIAL_8N1, PIN_PRINTER_RX, PIN_PRINTER_TX);
    g_thermalPrinter.begin();
    p.initialized = true;
    p.consecutiveErrors = 0;

    PRINTIMATE_LOG_I("Printer: UART2 ready (TX=%d RX=%d)", PIN_PRINTER_TX, PIN_PRINTER_RX);
}

// =============================================================================
// base64_decode_inplace
// =============================================================================
// Decodes base64 in s[], writing decoded bytes back from the start (safe
// because output is always ≤ 75% of input length). Returns byte count.
static int base64_decode_inplace(char *s) {
    auto decode_char = [](char c) -> int {
        if (c >= 'A' && c <= 'Z') return c - 'A';
        if (c >= 'a' && c <= 'z') return c - 'a' + 26;
        if (c >= '0' && c <= '9') return c - '0' + 52;
        if (c == '+') return 62;
        if (c == '/') return 63;
        return -1;
    };

    uint8_t *out = (uint8_t *)s;
    int j = 0;

    for (int i = 0; s[i]; i += 4) {
        // Read all four encoded bytes before writing anything (in-place safety).
        char r0 = s[i], r1 = s[i+1], r2 = s[i+2], r3 = s[i+3];

        int v0 = decode_char(r0), v1 = decode_char(r1);
        if (v0 < 0 || v1 < 0) break;
        out[j++] = (v0 << 2) | (v1 >> 4);

        if (r2 == '=' || r2 == '\0') break;
        int v2 = decode_char(r2);
        if (v2 < 0) break;
        out[j++] = (v1 << 4) | (v2 >> 2);

        if (r3 == '=' || r3 == '\0') break;
        int v3 = decode_char(r3);
        if (v3 < 0) break;
        out[j++] = (v2 << 6) | v3;
    }

    return j;
}

// =============================================================================
// printer_printMessage
// =============================================================================
void printer_printMessage(Printer &p, const Message &msg) {
    g_thermalPrinter.printBitmap(PRINTIMATE_PRINTER_WIDTH_PX, kDividerHeightPx, kDivider, false);
    g_thermalPrinter.println();
    g_thermalPrinter.print("From: ");
    g_thermalPrinter.println(msg.authorName);
    g_thermalPrinter.print("Sent: ");
    g_thermalPrinter.println(formatTimestampPT(msg.sentTimestamp));

    // Message text is now contained within images
    // g_thermalPrinter.println();
    // g_thermalPrinter.println(msg.messageText);

    // Print all images
    for (int i = 0; i < msg.imageCount; i++) {
        const Image &img = msg.images[i];
        if (!img.bitmap || img.width <= 0 || img.height <= 0) continue;
        int bytes = base64_decode_inplace(img.bitmap);
        PRINTIMATE_LOG_I("Printer: image %d/%d: %dx%d px, %d bytes decoded",
                         i + 1, msg.imageCount, img.width, img.height, bytes);
        g_thermalPrinter.printBitmap(img.width, img.height,
                                     (const uint8_t *)img.bitmap, false);
    }

    g_thermalPrinter.feed(3);
}

// =============================================================================
// http_receive_into
// =============================================================================
// Reads the HTTP response body into out[0..outLen-1], null-terminates it, and
// returns the byte count. Returns -1 if the stream is unavailable.
static int http_receive_into(HTTPClient &http, char *out, size_t outLen) {
    WiFiClient *stream = http.getStreamPtr();
    if (!stream) return -1;

    int contentLen = http.getSize();
    size_t received = 0;
    const size_t limit = outLen - 1;
    const unsigned long deadline = millis() + 5000;

    while (received < limit && millis() < deadline) {
        int avail = stream->available();
        if (avail > 0) {
            size_t toRead = min((size_t)avail, limit - received);
            received += stream->readBytes(out + received, toRead);
        } else if (contentLen >= 0 && (int)received >= contentLen) {
            break;
        } else {
            delay(1);
        }
    }
    if (received >= limit) {
        PRINTIMATE_LOG_E("Printer: response exceeded buffer (%d bytes), truncated", (int)outLen);
        return -1;
    }
    out[received] = '\0';
    return (int)received;
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
    int bodyLen = http_receive_into(http, (char *)buf, sizeof(buf));
    http.end();
    PRINTIMATE_LOG_I("Printer: received response (%d bytes)", bodyLen);
    if (bodyLen < 0) {
        PRINTIMATE_LOG_E("Printer: failed to read response body");
        p.consecutiveErrors++;
        return false;
    }

    // Parse the JSON array. ArduinoJson v7 allocates from the heap; the doc
    // is freed when it goes out of scope at the end of this function.
    JsonDocument doc;
    DeserializationError err = deserializeJson(doc, buf, bodyLen);
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

        for (JsonObject imgObj : obj["images"].as<JsonArray>()) {
            if (msg.imageCount >= PRINTIMATE_MAX_IMAGES_PER_MESSAGE) break;
            Image &img  = msg.images[msg.imageCount++];
            img.width   = imgObj["width"]  | 0;
            img.height  = imgObj["height"] | 0;
            img.bitmap  = (char *)imgObj["bitmap"].as<const char *>();
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
