# Phase 1: ESP32 hardware telemetry

## Scope and data flow

Actual DHT22 and ADC acquisition -> eight-byte BLE notifications -> flutter_blue_plus
transport -> strict decoder -> FloraWandNotifier -> hardwareTelemetryProvider -> existing
Home telemetry card. No database write, calibration, inferred lux, battery data, or
agronomic interpretation occurs in this path. Database snapshots remain separate.

Startup is disconnected with null readings and no device identity. Select a real
advertised device in Settings. Discovery shows nearby BLE devices, including older firmware that advertises no
service UUID. Select the ESP32 by name or ID. Connection
requires the exact service/characteristic and notification support. A connection
alone means **awaiting first reading**. Valid packets set the local receivedAt and
lastSampledAt; invalid packets set a data error without changing the last successful
sample. Six seconds without a valid packet marks telemetry stale (configurable through
floraWandFreshnessProvider; sampling interval is nominally two seconds). Home shows
`--` for unavailable/stale/error data, and no fabricated normal measurements.
Disconnect clears readings and identity. Reconnect manually through Settings; each
new connection awaits a new packet. There is no simulated or automatic connection.

CalibratedTelemetry remains a separate legacy type. The BLE state's nullable legacy
telemetry getter is intentionally unavailable in Phase 1. Small guards in existing
scan/plant consumers prevent raw ADCs being treated as calibrated percentages or lux;
no diagnosis, fusion, or calibration algorithm was changed. Existing plant persistence
retains its pre-existing missing-value convention. This is not a new plant workflow.

## Wire protocol

Advertised service: `0000ff01-0000-1000-8000-00805f9b34fb`

Read/notify characteristic: `0000ff02-0000-1000-8000-00805f9b34fb`

Exactly eight bytes, little endian; no battery field or alternative formats:

| Offset | Type | Meaning | Accepted range |
|---|---|---|---|
| 0-1 | uint16 | Soil moisture raw ADC | 0-4095 |
| 2-3 | int16 | Ambient Celsius multiplied by 10 | -400 through 800 |
| 4-5 | uint16 | Relative humidity percent multiplied by 10 | 0-1000 |
| 6-7 | uint16 | Light raw ADC | 0-4095 |

Example: `98 08 09 01 AF 02 D2 04` = soil 2200, temperature 26.5 C,
humidity 68.7%, light 1234. No framing, checksum, sensor timestamp, or sequence
number exists in this first protocol; receivedAt is local reception time.
A valid ADC range cannot prove a probe is plugged in: floating or saturated inputs
may still be in range. Calibration, probe detection and wire fault diagnostics are
outside this milestone.

Invalid DHT22/range readings are logged on Serial and **no notification is sent**.
The receiver consequently becomes stale. Before any valid sample it remains awaiting
the first reading; this protocol has no separate sensor-error packet.

The firmware also supports reads, but never returns its previous cached sample as
new telemetry. A read attempts acquisition only if two seconds have elapsed since
the last attempt. If not due, or if acquisition fails, it returns an empty value
(explicitly unavailable, not another packet format). Flutter rejects that response
without updating receivedAt; the next valid notification restores live status.
The receiver does not perform an initial characteristic read or subscribe to a
cached/replayed value stream. Normal operation needs no manual refresh.

## Arduino IDE upload

1. Use a **classic ESP32** board with BLE and GPIO32/33/34 available. ESP32-S2
   has no BLE; other ESP32 variants need their pin configuration reviewed.
2. Install the Espressif **esp32** board package in Arduino IDE Boards Manager
   (implementation targets the Arduino-ESP32 3.x BLE API). Select the actual board
   and USB serial port. BLEDevice/BLEServer/BLE2902 come with that board package;
   do not install an unrelated BLE library.
3. Install **DHT sensor library by Adafruit** and its **Adafruit Unified Sensor**
   dependency through Library Manager.
4. Open `firmware/FloraWandTelemetry/FloraWandTelemetry.ino`; `config.h` is in
   the same sketch folder. Verify DHT22 data is really on GPIO4, LDR divider output
   on GPIO33, and soil sensor output on GPIO32. Set SOIL_PIN to 34 if actually wired
   there. These defaults are not a claim about your physical wiring.
5. Connect common ground. Use sensor/divider outputs safe for the ESP32's 3.3 V
   inputs; never connect a 5 V analog output directly. A bare DHT22 needs its data
   pull-up to 3.3 V (modules may include it). The LDR requires a voltage divider.
   GPIO34 is input-only, without an internal pull-up/down.
6. Verify/compile and upload. Use the board's BOOT button if required by its uploader.
   Open Serial Monitor at 115200 baud. After startup, real readings should appear
   about every two seconds, or a sensor acquisition failure message.

ADC setup is explicitly 12 bits with 11 dB per-pin attenuation. Counts are not
volts, moisture percentages, or lux. Sources: [Espressif ADC API](https://docs.espressif.com/projects/arduino-esp32/en/latest/api/adc.html)
and [Espressif BLE notification example](https://github.com/espressif/arduino-esp32/blob/master/libraries/BLE/examples/Notify/Notify.ino).

## Android live verification (requires physical hardware)

1. From `mobile`, run `flutter pub get` and `flutter run` with the Android phone
   attached and USB debugging enabled. Enable Bluetooth. Existing manifest entries
   cover BLE; flutter_blue_plus requests runtime permissions during scan/connect.
   Allow Nearby Devices on Android 12+, or location permission and Location services
   on older Android releases. Permission denial should show a scan/connection error.
2. Start with ESP32 off. Home must show Offline and four `--` readings, no battery
   percentage and no invented wand identity. Open Settings' pairing sheet: no
   fabricated result should appear.
3. Power the flashed ESP32 and reopen the pairing sheet. Select FloraWand and
   Pair & Connect. Home should briefly await a reading, then update automatically.
   Compare its raw soil/light, Celsius and humidity with Serial Monitor. Change
   light exposure and the soil probe's environment and confirm subsequent updates.
4. Leave BLE connected and disconnect DHT22 data/power safely. Serial should report
   failure. After six seconds since the last valid packet, Home must say Stale
   telemetry with `--`, rather than retaining apparently live numbers. Reconnect
   DHT22 and verify automatic recovery with the next valid packet.
5. Power off ESP32 or move out of range; allow the BLE supervision timeout to detect
   the link loss. Confirm Offline and cleared readings. Turn it on, scan and reconnect
   through Settings, and confirm the previous sample is not reused.
6. Test Bluetooth off, permission denial, repeated connect/disconnect, and app
   background/resume. Confirm errors are visible and packets resume after reconnect.
7. Optional read test: Read Another Pot performs a characteristic read. A read before
   the next sampling interval can report a data error (empty unavailable response);
   the next normal notification restores live data. It must never advance the
   timestamp just because the read request completed.

Record board/package/library versions, wiring, phone/Android version and observed
values when performing this procedure. No hardware verification has been performed
in this implementation session.

## Changed files

- `firmware/FloraWandTelemetry/FloraWandTelemetry.ino`: real acquisition, encoding,
  read/notify GATT server, advertising restart and explicit failure handling.
- `firmware/FloraWandTelemetry/config.h`: centralized pin, UUID and interval settings.
- `mobile/lib/core/ble/flora_wand_packet.dart`: immutable raw reading and strict decoder.
- `mobile/lib/core/ble/flora_wand_transport.dart`: injectable flutter_blue_plus transport.
- `mobile/lib/core/ble/flora_wand_ble_service.dart`: lifecycle, validation, freshness,
  cancellation, reads and Riverpod publication; removes simulation and calibration.
- `mobile/lib/core/ble/flora_wand_state.dart`: honest connection and data status.
- `mobile/lib/features/home/presentation/providers/telemetry_providers.dart`: separate
  reactive hardware state from database snapshots.
- `mobile/lib/features/home/presentation/home_screen.dart`: four raw/live readouts and status.
- `mobile/lib/core/widgets/flora_scan_header.dart` and
  `mobile/lib/features/settings/presentation/settings_screen.dart`: remove battery claims.
- `mobile/lib/features/scan/presentation/scan_screen.dart`,
  `mobile/lib/features/scan/presentation/widgets/diagnosis_result_sheet.dart`, and
  `mobile/lib/features/plants/presentation/add_plant_screen.dart`: nullable calibrated
  telemetry compatibility guards only.
- `mobile/test/unit/flora_wand_ble_test.dart`: hardware-free protocol/lifecycle tests.
- `mobile/test/unit/flora_wand_calibration_test.dart`: preserves the original separate
  calibration tests; calibration is not invoked by Phase 1 acquisition.
- `mobile/test/widget/home_screen_test.dart` and
  `mobile/test/widget/stitch_screens_test.dart`: honest offline expectations and
  compact-screen raw ADC layout checks.
- `docs/phase1-telemetry.md`: this protocol, upload and verification guide.

## Verification

Focused tests: `flutter test --no-pub test/unit/flora_wand_ble_test.dart test/unit/flora_wand_calibration_test.dart`
passed all 20 tests. Firmware compilation and physical ESP32/Android BLE operation
have not been verified: arduino-cli/board toolchain and hardware are unavailable.
`flutter analyze --no-pub` reports no issues. The full `flutter test --no-pub`
suite passed all 80 tests. After adding an additional extreme-value compact-screen
check, the Home widget file passed all four tests. The full suite emitted
google_fonts download warnings but completed successfully. `git diff --check`
also passed.

## Discovery compatibility fix

The pairing scan no longer filters by advertised UUID or device name. Older ESP32
firmware can be discovered even when FF01 is absent from its advertisement. GATT
FF01/FF02 and the eight-byte telemetry protocol are still checked after connection;
discovery does not establish compatibility with arbitrary older firmware. Scan again
is available in the pairing sheet; connection failures now remain visible after it closes.
Bluetooth Classic-only firmware cannot be discovered by this BLE library.

Discovery-fix validation: Flutter analysis passed with no issues. The BLE, discovery,
Settings and existing screen regression run passed 38 tests. A subsequent run including
the new 25-device compact pairing/retry/error test passed all seven discovery and
Settings tests. Physical discovery with the previous ESP32 firmware still requires
verification on the Android phone.
