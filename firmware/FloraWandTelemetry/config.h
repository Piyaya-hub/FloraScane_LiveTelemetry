#pragma once
// Verify against actual wiring before uploading. Classic ESP32 ADC1 pins.
constexpr uint8_t DHT_PIN = 4;
constexpr uint8_t LIGHT_PIN = 33;
constexpr uint8_t SOIL_PIN = 32; // Change to 34 if the probe is wired to GPIO34.
constexpr uint32_t SAMPLE_INTERVAL_MS = 2000;
constexpr char SERVICE_UUID[] = "0000ff01-0000-1000-8000-00805f9b34fb";
constexpr char TELEMETRY_UUID[] = "0000ff02-0000-1000-8000-00805f9b34fb";
