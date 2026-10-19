#include <Arduino.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLE2902.h>
#include <DHT.h>
#include <math.h>
#include <atomic>
#include "config.h"

DHT dht(DHT_PIN, DHT22);
BLECharacteristic* telemetry;
SemaphoreHandle_t sensorMutex;
std::atomic<bool> connected{false};
std::atomic<bool> restartAdvertising{false};
uint32_t lastAttempt = 0; // Protected by sensorMutex.

void put16(uint8_t* packet, size_t offset, uint16_t value) {
  packet[offset] = value & 0xff;
  packet[offset + 1] = value >> 8;
}

// Caller holds sensorMutex. Never resend a cached reading as a new sample.
bool acquire() {
  const uint32_t now = millis();
  if (uint32_t(now - lastAttempt) < SAMPLE_INTERVAL_MS) return false;
  lastAttempt = now;
  const float humidity = dht.readHumidity();
  const float temperature = dht.readTemperature();
  // Start the next interval after DHT access, avoiding library cache reuse.
  lastAttempt = millis();
  const uint16_t soil = analogRead(SOIL_PIN);
  const uint16_t light = analogRead(LIGHT_PIN);
  if (!isfinite(temperature) || !isfinite(humidity) ||
      temperature < -40 || temperature > 80 || humidity < 0 || humidity > 100 ||
      soil > 4095 || light > 4095) {
    Serial.println("Sensor acquisition failed; no telemetry packet sent");
    return false;
  }
  // Exactly 8 bytes, little endian: soil u16, Celsius*10 i16,
  // humidity percent*10 u16, light u16. ADC values are raw 12-bit counts.
  uint8_t packet[8];
  put16(packet, 0, soil);
  put16(packet, 2, static_cast<uint16_t>(static_cast<int16_t>(lroundf(temperature * 10))));
  put16(packet, 4, static_cast<uint16_t>(lroundf(humidity * 10)));
  put16(packet, 6, light);
  telemetry->setValue(packet, sizeof(packet));
  Serial.printf("soil=%u temp=%.1f humidity=%.1f light=%u\n", soil, temperature, humidity, light);
  return true;
}

class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer*) override { connected = true; }
  void onDisconnect(BLEServer*) override {
    connected = false;
    restartAdvertising = true;
  }
};
class TelemetryCallbacks : public BLECharacteristicCallbacks {
  void onRead(BLECharacteristic* characteristic) override {
    xSemaphoreTake(sensorMutex, portMAX_DELAY);
    if (!acquire()) {
      // Empty read is explicitly unavailable (failed sensor or sample not due).
      // It is NOT a telemetry packet; Flutter rejects it without refreshing time.
      characteristic->setValue("");
    }
    xSemaphoreGive(sensorMutex);
  }
};

void setup() {
  Serial.begin(115200);
  sensorMutex = xSemaphoreCreateMutex();
  if (sensorMutex == nullptr) { Serial.println("Mutex allocation failed"); abort(); }
  dht.begin();
  pinMode(SOIL_PIN, INPUT);
  pinMode(LIGHT_PIN, INPUT);
  analogReadResolution(12); // Raw range 0..4095, no moisture or lux conversion.
  analogSetPinAttenuation(SOIL_PIN, ADC_11db);
  analogSetPinAttenuation(LIGHT_PIN, ADC_11db);
  BLEDevice::init("FloraWand");
  BLEServer* server = BLEDevice::createServer();
  server->setCallbacks(new ServerCallbacks());
  BLEService* service = server->createService(SERVICE_UUID);
  telemetry = service->createCharacteristic(TELEMETRY_UUID,
    BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY);
  telemetry->addDescriptor(new BLE2902());
  telemetry->setCallbacks(new TelemetryCallbacks());
  telemetry->setValue("");
  service->start();
  BLEAdvertising* advertising = BLEDevice::getAdvertising();
  advertising->addServiceUUID(SERVICE_UUID);
  advertising->setScanResponse(true);
  advertising->start();
}

void loop() {
  if (restartAdvertising.exchange(false)) BLEDevice::startAdvertising();
  xSemaphoreTake(sensorMutex, portMAX_DELAY);
  if (acquire() && connected.load()) telemetry->notify();
  xSemaphoreGive(sensorMutex);
  delay(10);
}
