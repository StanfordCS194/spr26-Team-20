# Printimate Firmware

ESP32 firmware for the Printimate thermal printer. Runs on an **ESP32 DevKit V1**
(ESP-WROOM-32 module, CP2102 USB-serial bridge).

## Team conventions

- **Target board:** DOIT ESP32 DEVKIT V1 (30-pin, CP2102)
- **Framework:** Arduino-ESP32, pinned to version `6.9.0` of the `espressif32`
  platform (see `platformio.ini`)
- **Toolchain:** managed automatically by PlatformIO — don't install the Arduino
  IDE core separately; it'll cause confusion
- **Style:** plain `.cpp` / `.h`, not `.ino`. Each module (provisioning,
  printer, MQTT) has its own pair of files.

## One-time setup

1. Install [VS Code](https://code.visualstudio.com/) and the **PlatformIO IDE**
   extension from the marketplace.
2. Install the **Silicon Labs CP210x VCP driver** so your OS recognizes the
   board: https://www.silabs.com/developers/usb-to-uart-bridge-vcp-drivers
3. Clone this repo and open it in VS Code. PlatformIO will auto-detect the
   project and prompt to install the toolchain on first open (takes a few
   minutes the first time).
4. Copy the secrets template:
   ```
   cp include/secrets.example.h include/secrets.h
   ```
   Fill in values for your dev environment. **Do not commit `secrets.h`.**

## Building and flashing

From the VS Code PlatformIO sidebar, or the terminal:

```bash
# Build only (default env is 'dev')
pio run

# Build + upload
pio run -t upload

# Open serial monitor
pio device monitor

# Build + upload + monitor in one step
pio run -t upload -t monitor

# Production build (minimal logs, optimized)
pio run -e prod -t upload
```

If upload fails with `Failed to connect... Timed out waiting for packet
header`, the auto-reset circuit is being uncooperative. Hold the **BOOT**
button, tap **EN**, release **BOOT**, then re-run upload.

## Project layout

```
printimate-firmware/
├── platformio.ini         # build environments, library pins
├── partitions.csv         # flash layout (dual OTA + NVS + LittleFS + coredump)
├── include/
│   ├── config.h           # project-wide constants
│   ├── pins.h             # physical pin assignments
│   └── secrets.example.h  # template; copy to secrets.h locally
├── src/
│   ├── main.cpp           # boot state machine (entry point)
│   ├── provisioning.{h,cpp}  # SoftAP + captive portal (Felipe-owned: Carlos)
│   ├── printer.{h,cpp}       # thermal driver (Niklas, TBD)
│   └── mqtt_client.{h,cpp}   # backend messaging (TBD)
└── test/                  # unit tests (PlatformIO's built-in framework)
```

## Module ownership

| Module | Owner | Status |
|--------|-------|--------|
| Boot state machine (`main.cpp`) | Carlos | Scaffold present; registering/ready to wire up |
| Provisioning (`provisioning.cpp`) | Carlos | Stub; captive portal + NVS writes TBD |
| Printer driver (`printer.cpp`) | Niklas | Not started |
| MQTT client (`mqtt_client.cpp`) | TBD | Not started |
| Backend API | Felipe | See separate repo |
| Flutter app | Braedan | See separate repo |
| UX / front-end | Luke | See separate repo |

## Flash memory map (quick reference)

| Partition | Size | Purpose |
|-----------|------|---------|
| nvs | 20 KB | WiFi creds, device token, settings |
| otadata | 8 KB | tracks active OTA slot |
| app0 | 1.875 MB | OTA slot A |
| app1 | 1.875 MB | OTA slot B |
| spiffs | 128 KB | fonts / logos if needed |
| coredump | 64 KB | crash dumps |

Don't change `partitions.csv` without coordinating — reflashing a device with a
different partition table requires a full erase (`pio run -t erase`), not just
a re-upload.

## Debugging tips

- `Serial.println` is your friend. The PlatformIO monitor has
  `esp32_exception_decoder` enabled, so panics will show file:line.
- `log_i`, `log_w`, `log_e`, `log_d` macros respect `CORE_DEBUG_LEVEL` and add
  timestamps + tags. Use them via the `PRINTIMATE_LOG_*` wrappers in
  `config.h`.
- `ESP.getFreeHeap()` and `ESP.getMinFreeHeap()` are the fastest way to catch
  heap issues. Print them periodically during development.
- To factory-reset a device: hold the BOOT button for 5 seconds while running,
  or run `pio run -t erase` to wipe all flash.
