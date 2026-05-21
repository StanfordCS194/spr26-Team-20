# ESP32 ↔ Firestore polling — minimal viable hookup

Goal: simplest end-to-end working pipeline for **app → Firestore → ESP32 prints**, without a Cloud Function, MQTT broker, or any extra Firebase product. Trades latency and tight security for low complexity. Designed to be the v0 we throw away when we move to the Cloud Function + MQTT architecture.

Project ID: `printimate-44033` · Region: pick once and don't move it.

Verified against the Firestore REST API as of April 2026.

---

## 1. Architecture

```
[Flutter app] --add()--> [Firestore: messages/{id}] <--POST runQuery--> [ESP32 polls every 3s]
                                  ^                                            |
                                  |                                            v
                                  +---PATCH status: "printed" ----------------+
```

- App writes a document into the `messages` collection.
- ESP32 polls Firestore via `:runQuery` filtering for its own `recipientPrinterId` and `status == "queued"`.
- For each match, the ESP32 prints, then PATCHes the document to `status: "printed"` so it doesn't reprint on the next poll.

**No Cloud Functions, no MQTT, no Realtime Database.** Just REST.

---

## 2. Firestore document shape

`messages/{auto-id}`:

```jsonc
{
  "senderUid":          "xCqZ...",            // Firebase Auth uid of sender
  "recipientPrinterId": "PRT-12345-ABCD",     // string the ESP32 also knows itself by
  "body":               "Happy birthday!",     // free-text message; may be empty
  "imageBase64":        "iVBORw0KGgo...",     // 1-bit PNG, base64; may be empty
  "imageWidth":         384,                   // px width baked into the dithered PNG
  "createdAt":          <serverTimestamp>,
  "status":             "queued"               // "queued" | "printed" | "failed"
}
```

Only fields that need querying need to be indexed. Firestore auto-indexes single-field equality, so `recipientPrinterId == X AND status == Y` works without a composite index for now. **If we later add `orderBy(createdAt)`, Firestore will prompt us to create a composite index — accept the prompt.**

---

## 3. Security rules (dev-permissive)

Paste this into Firestore Console → Rules. **It is intentionally loose for a hackathon-grade demo.** Tighten before any non-team user touches the app.

```
rules_version = '2';
service cloud.firestore {
  match /databases/{db}/documents {

    // Authenticated app users can create messages and read their own.
    match /messages/{messageId} {
      allow create: if request.auth != null
                    && request.auth.uid == request.resource.data.senderUid;
      allow read:   if request.auth != null
                    && (request.auth.uid == resource.data.senderUid
                        || request.auth.uid == resource.data.recipientUid);
      allow update: if true;   // DEV ONLY — printer needs to flip status without auth
      allow delete: if false;
    }
  }
}
```

The `allow update: if true` is what lets the ESP32 PATCH `status` using only the public Web API key. Yes, that means anyone with the API key can flip arbitrary message status — fine for v0, not fine for production. Two acceptable hardenings later:

- **(a)** make the ESP32 sign in to Firebase Auth (anonymous or via a per-printer email/password) and rule on `request.auth.uid == resource.data.recipientPrinterOwnerUid`.
- **(b)** move to the Cloud Function + MQTT pattern, at which point the ESP32 stops touching Firestore directly.

---

## 4. The Flutter side — write a real document

Currently `lib/features/send/send_screen.dart` `_send()` is a stub. Replace the body with:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// inside _send():
final user = FirebaseAuth.instance.currentUser!;
await FirebaseFirestore.instance.collection('messages').add({
  'senderUid':          user.uid,
  'recipientPrinterId': 'PRT-12345-ABCD',     // hardcode for v0; pick a real ID from the device
  'body':               text,
  'imageBase64':        _base64Image ?? '',
  'imageWidth':         _printerWidthPx,
  'createdAt':          FieldValue.serverTimestamp(),
  'status':             'queued',
});
```

Add the dep:
```yaml
# pubspec.yaml
dependencies:
  cloud_firestore: ^5.4.0
```
Then `flutter pub get`.

The recipient printer ID is hardcoded for now — that's fine; we'll fix the friend-picker in a later PR.

---

## 5. The ESP32 side — polling every 3 seconds

### Required libraries (already in `firmware/platformio.ini`)
- `bblanchon/ArduinoJson@^7.2.0` — JSON encode/decode.
- `WiFiClientSecure` and `HTTPClient` — built into the Arduino-ESP32 core.

No new lib_deps needed. The `PubSubClient` already in there is unused for v0 and can stay (we'll use it when we eventually move to MQTT).

### Config additions

`firmware/include/config.h`:
```cpp
#define FIRESTORE_PROJECT_ID    "printimate-44033"
#define FIRESTORE_API_KEY       "YOUR_WEB_API_KEY"   // from firebase_options.dart
#define FIRESTORE_POLL_INTERVAL_MS  3000
#define MY_PRINTER_ID           "PRT-12345-ABCD"     // baked in for v0
```

Real per-device printer IDs go in NVS later via the existing provisioning flow.

### Endpoints we hit

**Query for queued messages** (POST):
```
https://firestore.googleapis.com/v1/projects/printimate-44033/databases/(default)/documents:runQuery?key={API_KEY}
```

Body:
```json
{
  "structuredQuery": {
    "from": [{ "collectionId": "messages" }],
    "where": {
      "compositeFilter": {
        "op": "AND",
        "filters": [
          {
            "fieldFilter": {
              "field": { "fieldPath": "recipientPrinterId" },
              "op": "EQUAL",
              "value": { "stringValue": "PRT-12345-ABCD" }
            }
          },
          {
            "fieldFilter": {
              "field": { "fieldPath": "status" },
              "op": "EQUAL",
              "value": { "stringValue": "queued" }
            }
          }
        ]
      }
    },
    "limit": 5
  }
}
```

`limit: 5` is a safety net — if the printer is offline for a day and 200 messages backed up, we don't try to deserialize them all at once on the ESP32.

**Mark as printed** (PATCH):
```
https://firestore.googleapis.com/v1/projects/printimate-44033/databases/(default)/documents/messages/{id}?updateMask.fieldPaths=status&key={API_KEY}
```

Body:
```json
{ "fields": { "status": { "stringValue": "printed" } } }
```

### Skeleton to drop into `firmware/src/firestore_poll.cpp` (new file)

```cpp
#include "firestore_poll.h"
#include "config.h"
#include <Arduino.h>
#include <ArduinoJson.h>
#include <HTTPClient.h>
#include <WiFiClientSecure.h>

namespace {
  uint32_t g_lastPollMs = 0;
  WiFiClientSecure g_tls;

  String firestoreUrl(const char* tail) {
    String u = "https://firestore.googleapis.com/v1/projects/";
    u += FIRESTORE_PROJECT_ID;
    u += "/databases/(default)/documents";
    u += tail;
    return u;
  }

  bool patchStatus(const String& docName, const char* status) {
    // docName looks like "projects/.../databases/(default)/documents/messages/{id}".
    // Strip the prefix to match our URL builder.
    int idx = docName.indexOf("/documents/");
    if (idx < 0) return false;
    String path = docName.substring(idx + strlen("/documents"));  // /messages/{id}

    String url = firestoreUrl(path.c_str());
    url += "?updateMask.fieldPaths=status&key=";
    url += FIRESTORE_API_KEY;

    HTTPClient http;
    http.begin(g_tls, url);
    http.addHeader("Content-Type", "application/json");

    String body = "{\"fields\":{\"status\":{\"stringValue\":\"";
    body += status;
    body += "\"}}}";

    int code = http.PATCH(body);
    http.end();
    return code >= 200 && code < 300;
  }

  void handleDocument(JsonObject doc) {
    const char* name = doc["name"];                     // doc resource path
    JsonObject fields = doc["fields"];
    const char* body  = fields["body"]["stringValue"]   | "";
    const char* image = fields["imageBase64"]["stringValue"] | "";

    Serial.printf("[firestore] printing message: %s\n", name);
    // TODO(niklas): hand `body` and `image` to the thermal printer driver.
    // printer_printText(body);
    // if (strlen(image) > 0) printer_printImageBase64(image);

    // After printing, flip status so we don't re-pick it.
    if (!patchStatus(String(name), "printed")) {
      Serial.println(F("[firestore] PATCH failed"));
    }
  }

  void poll() {
    String url = firestoreUrl(":runQuery");
    url += "?key=";
    url += FIRESTORE_API_KEY;

    HTTPClient http;
    http.begin(g_tls, url);
    http.addHeader("Content-Type", "application/json");

    // Build query body. Using a small-ish stack JSON doc.
    JsonDocument req;
    auto sq = req["structuredQuery"].to<JsonObject>();
    auto from = sq["from"].to<JsonArray>().add<JsonObject>();
    from["collectionId"] = "messages";

    auto cf = sq["where"]["compositeFilter"].to<JsonObject>();
    cf["op"] = "AND";
    auto filters = cf["filters"].to<JsonArray>();

    auto addEq = [&](const char* field, const char* value) {
      auto ff = filters.add<JsonObject>()["fieldFilter"].to<JsonObject>();
      ff["field"]["fieldPath"] = field;
      ff["op"] = "EQUAL";
      ff["value"]["stringValue"] = value;
    };
    addEq("recipientPrinterId", MY_PRINTER_ID);
    addEq("status", "queued");
    sq["limit"] = 5;

    String body;
    serializeJson(req, body);

    int code = http.POST(body);
    if (code != 200) {
      Serial.printf("[firestore] runQuery HTTP %d\n", code);
      http.end();
      return;
    }

    String resp = http.getString();
    http.end();

    // runQuery returns a JSON array. Each element either has a `document`
    // field (a hit) or only `readTime` (the empty terminator).
    JsonDocument out;
    DeserializationError err = deserializeJson(out, resp);
    if (err) {
      Serial.printf("[firestore] parse error: %s\n", err.c_str());
      return;
    }
    for (JsonObject element : out.as<JsonArray>()) {
      if (element["document"].is<JsonObject>()) {
        handleDocument(element["document"].as<JsonObject>());
      }
    }
  }
}

void firestore_poll_begin() {
  g_tls.setInsecure();   // DEV ONLY: skip cert validation. Pin Google Trust
                         // Services R1 root cert before shipping.
}

void firestore_poll_loop() {
  if (WiFi.status() != WL_CONNECTED) return;
  if (millis() - g_lastPollMs < FIRESTORE_POLL_INTERVAL_MS) return;
  g_lastPollMs = millis();
  poll();
}
```

### Wiring it into the existing state machine

In `firmware/src/main.cpp`:

```cpp
#include "firestore_poll.h"

// onStateEntry(BootState::Ready):
firestore_poll_begin();

// inside loop(), case BootState::Ready:
firestore_poll_loop();
```

That's it. No other state-machine changes.

---

## 6. Manual smoke test

1. Set Firestore rules per §3, hit **Publish** in the Firebase console.
2. Run the Flutter app, sign in, type a message, hit Send. Confirm a doc appears under `messages` in the Firestore console with `status: "queued"` and your printer's ID.
3. Flash the firmware. Watch serial monitor at 115200 baud:
   - You should see `[firestore] printing message: projects/printimate-44033/.../messages/...` within 3 seconds.
   - The doc's `status` in the console should flip to `"printed"`.
4. Send another message; same loop should fire again.

If step 3 silently does nothing, check (in order): WiFi connected?, API key correct?, security rules saved (rules editor has its own publish step that's easy to miss)?, document's `recipientPrinterId` exactly matches `MY_PRINTER_ID` (case-sensitive)?

---

## 7. Known limitations of v0

| Limitation | Impact | Fix later |
|---|---|---|
| Polls every 3s | Up to 3s latency on prints | Move to Cloud Function + MQTT (or RTDB stream) |
| Each poll = 1 read + N reads for hits | ~28K reads/day per printer at 3s | Same as above; or back off when idle |
| `setInsecure()` skips TLS cert validation | MITM possible on hostile WiFi | Pin Google Trust Services R1 root CA |
| `allow update: if true` rule | Anyone with API key can flip statuses | ESP32 signs in via Firebase Auth, rule by uid |
| Hardcoded `MY_PRINTER_ID` | Every flashed device claims to be this ID | Generate per-device, store in NVS, register in `printers/{id}` |
| Image base64 held in RAM as String | OOM risk on big images (>~50KB) | Stream-decode base64 directly to printer driver, drop intermediate buffer |
| No retry on PATCH failure | Doc could stay `queued` and reprint forever on the next poll | Track printed IDs in a small NVS-backed ring buffer |

None of these block the demo. All of them block "ship to other people."

---

## 8. Sources

- [Cloud Firestore REST API guide — Firebase docs](https://firebase.google.com/docs/firestore/use-rest-api)
- [`StructuredQuery` REST reference — Firebase docs](https://firebase.google.com/docs/firestore/reference/rest/v1/StructuredQuery)
- [`projects.databases.documents.patch` REST reference — Google Cloud docs](https://cloud.google.com/firestore/docs/reference/rest/v1/projects.databases.documents/patch)
- [Sending data from ESP32 to Firestore via REST — thomazrb (2025)](https://thomazrb.github.io/posts/esp32-firebase-db/)
- [Using ArduinoJson with HTTPClient — ArduinoJson docs](https://arduinojson.org/v6/how-to/use-arduinojson-with-httpclient/)
- [`mobizt/FirebaseClient` — current Mobizt Arduino lib](https://github.com/mobizt/FirebaseClient) (alternative if we ever want lib-managed auth/streaming on the ESP32 side)
