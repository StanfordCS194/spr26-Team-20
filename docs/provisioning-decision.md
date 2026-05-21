# Provisioning: SoftAP vs BLE

**One-page decision doc for Carlos and Niklas.** This is about how the phone hands WiFi credentials to the printer the first time it's plugged in. We picked SoftAP in the firmware scaffold. I think we should switch to BLE. Here's why — short version first, details below.

---

## TL;DR

> **Switching to BLE costs Carlos ~2–3 days of firmware rework and saves the app team ~2 weeks of iOS pain. Net win for the demo and for scope discipline.**

The deep-dive from last week flagged this as the single highest-leverage architecture call we'd make. Both the firmware and the Flutter side have mature first-party Espressif libraries for BLE provisioning — it's a paved road that Sonos, Hue, and every modern smart-home product uses.

---

## Side-by-side

| Dimension | SoftAP + captive portal | BLE Unified Provisioning |
|---|---|---|
| **User leaves the app mid-setup?** | Yes, to join "Printimate-Setup-XXXX" in WiFi settings | No — stays in the app |
| **iOS shows "no internet" warning?** | Yes (unavoidable) | No |
| **Can we show a WiFi list on iOS?** | No — iOS hides the scan API, user types SSID | Yes — printer scans, returns list over BLE |
| **Requires paid Apple Dev account?** | Yes (for `NEHotspotConfiguration` entitlement) | No (until TestFlight) |
| **Firmware effort** | ~1 week of Async web server + HTTP handlers + NVS + retry logic | ~2–3 days to swap in `WiFiProv.h` (Espressif's wrapper) |
| **Flutter app effort** | ~1–2 weeks to build AP-join → WiFi-scan → POST → rejoin-home-WiFi flow from primitives | ~2 days; `esp_provisioning_ble` pub package wraps it in a 4-call API |
| **Security** | Hand-rolled; HTTP over shared-password AP | SRP6a key exchange + AES-GCM baked in |
| **Library maturity** | Custom code on both ends | Espressif ships official iOS + Android reference apps |
| **What it feels like** | Clunky but possible | Polished |

---

## What the user actually does

### SoftAP flow (current plan)

1. Plug in the printer. It broadcasts "Printimate-Setup-4F2A".
2. App says *"Go to Settings → WiFi → join Printimate-Setup-4F2A."*
3. User leaves the app, opens iOS Settings, finds and taps the network.
4. iOS asks for the AP password (or the app provides it via `NEHotspotConfiguration`).
5. iOS shows a ⚠ *"This network has no internet connection"* banner.
6. User comes back to the app. App loads `http://192.168.4.1/provision`.
7. **User types their home WiFi SSID** (iOS won't let us show a list).
8. User types their home WiFi password.
9. Printer accepts creds, drops AP, reboots onto home WiFi.
10. Phone is still stuck on the now-dead printer AP. User reopens Settings, rejoins home WiFi manually (or another `NEHotspotConfiguration` call).

Ten steps, three context switches out of the app, one system warning, one SSID type-in. Every step is an opportunity for a grandparent to give up.

### BLE flow (proposal)

1. Plug in the printer. It advertises over BLE.
2. In the app, user taps **Pair a printer**.
3. App shows "Printimate-4F2A" in a list. User taps it.
4. App shows the home WiFi networks the printer picked up, user taps theirs, types password.
5. Success checkmark. Done.

Five steps, zero context switches, one app, one password entry.

---

## Firmware impact

Carlos, what changes in your code:

- `platformio.ini`: drop `ESPAsyncWebServer` from `lib_deps`. BLE is built into Arduino-ESP32, no extra library.
- `provisioning.cpp`: replace the SoftAP + HTTP scaffold with `WiFiProv.beginProvision(...)`. This one call gives you BLE advertising, secure handshake, WiFi scan proxying, credential receive, and NVS persistence. ~30 lines instead of hundreds.
- `main.cpp` state machine: unchanged. `Provisioning` → `ConnectingWifi` → `Registering` → `Ready` still works. Only the entry/exit hooks change.
- Partition table, OTA, the boot state machine, reset button, backoff — all untouched.

**Estimated rework:** 2–3 days, less than what's left to finish SoftAP.

Reference apps:
- Espressif ESP-IDF component: [`wifi_provisioning`](https://docs.espressif.com/projects/esp-idf/en/latest/esp32/api-reference/provisioning/wifi_provisioning.html)
- Arduino wrapper: [`WiFiProv.h` example](https://github.com/espressif/arduino-esp32/tree/master/libraries/WiFiProv/examples)
- Official iOS SDK + demo: [`esp-idf-provisioning-ios`](https://github.com/espressif/esp-idf-provisioning-ios)
- Official Android SDK + demo: [`esp-idf-provisioning-android`](https://github.com/espressif/esp-idf-provisioning-android)

---

## App impact

Braedan, what changes on your side:

- Add `esp_provisioning_ble` to `pubspec.yaml` — wraps Espressif's protocomm over `flutter_blue_plus` (already in deps).
- Drop any plan to add `wifi_iot` or `flutter_hotspot_config`.
- No `NEHotspotConfiguration` entitlement needed. No paid Apple Developer account required just to make provisioning work (we still want one eventually for TestFlight).
- BLE permission copy in `Info.plist` is already set.

---

## Printer-side UX bonus

Both flows need a way to kick off pairing. BLE gives us a clean pattern:

- Print a QR code on the receipt containing Espressif's standard payload:
  ```
  {"ver":"v1","name":"PROV_4F2A","pop":"a1b2c3d4","transport":"ble","security":2}
  ```
- The Flutter app scans it with `mobile_scanner`, connects directly — no typing a device code.

You can do a similar thing with SoftAP (QR containing the AP password), but the rest of the flow is still the ten steps above.

---

## Open question for Carlos

Is there a reason you picked SoftAP that I'm missing? The scaffold looks well-designed, I just want to make sure we're not re-litigating a decision you had a good reason for. If it was "this is what I'd worked with before" or "I didn't know `WiFiProv.h` existed", I'd like to make the switch now while nothing's committed to the harder path yet.

---

## Proposal

1. This week: Carlos reworks `provisioning.cpp` to use `WiFiProv.h`.
2. This week: I add `esp_provisioning_ble` to `pubspec.yaml` and stub out the pair screen against an nRF Connect fake peripheral while firmware catches up.
3. Week 2: end-to-end smoke test — app scans BLE, sends creds, printer joins WiFi, publishes "online" to MQTT.

Reply on Slack or in this doc's PR and we can lock the decision.
