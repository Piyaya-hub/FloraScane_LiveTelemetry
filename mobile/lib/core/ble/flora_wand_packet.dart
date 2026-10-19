import 'package:flutter/foundation.dart';

/// Phase 1: exactly eight bytes, little endian. No battery or fallback formats.
/// [0..1] soil ADC uint16; [2..3] Celsius x10 int16;
/// [4..5] RH percent x10 uint16; [6..7] light ADC uint16.
@immutable
class FloraWandTelemetry {
  const FloraWandTelemetry({
    required this.soilMoistureRawAdc,
    required this.temperatureCelsius,
    required this.humidityPercent,
    required this.lightRawAdc,
    required this.receivedAt,
  });

  final int soilMoistureRawAdc;
  final double temperatureCelsius;
  final double humidityPercent;
  final int lightRawAdc;
  final DateTime receivedAt;

  factory FloraWandTelemetry.decode(List<int> packet, DateTime receivedAt) {
    if (packet.length != 8 || packet.any((b) => b < 0 || b > 255)) {
      throw const FormatException('Expected exactly eight bytes');
    }
    final data = ByteData.sublistView(Uint8List.fromList(packet));
    final soil = data.getUint16(0, Endian.little);
    final temperature = data.getInt16(2, Endian.little) / 10.0;
    final humidity = data.getUint16(4, Endian.little) / 10.0;
    final light = data.getUint16(6, Endian.little);
    if (soil > 4095 ||
        light > 4095 ||
        temperature < -40 ||
        temperature > 80 ||
        humidity > 100) {
      throw const FormatException('Sensor reading outside ADC/DHT22 range');
    }
    return FloraWandTelemetry(
      soilMoistureRawAdc: soil,
      temperatureCelsius: temperature,
      humidityPercent: humidity,
      lightRawAdc: light,
      receivedAt: receivedAt,
    );
  }
}
