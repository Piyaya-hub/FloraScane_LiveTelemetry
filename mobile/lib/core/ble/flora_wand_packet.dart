import 'dart:convert';

import 'package:flutter/foundation.dart';

/// FloraScan-Wand Arduino sketch: one UTF-8 notification per sensor sample.
/// Example: moisture=3039,temp=29.7,humidity=75.7,light=80.00.
/// The sketch formats light as a float (e.g. 1234.00), but it is an ADC count.
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
    if (packet.isEmpty ||
        packet.length > 128 ||
        packet.any((b) => b < 0 || b > 255)) {
      throw const FormatException('Invalid sensor notification');
    }
    final text = utf8.decode(packet).trim();
    // Match the complete known firmware format. Never fill a missing field
    // with a default, or interpret a truncated text notification as binary.
    // Exact decimal precision also rejects a cut-off final light value.
    final match = RegExp(
      r'^moisture=(\d+),temp=(-?\d+\.\d),humidity=(\d+\.\d),light=(\d+\.\d{2})$',
    ).firstMatch(text);
    if (match == null || match.end != text.length) {
      throw const FormatException(
        'Expected complete moisture,temp,humidity,light sensor data',
      );
    }
    final soil = int.tryParse(match.group(1)!);
    final temperature = double.parse(match.group(2)!);
    final humidity = double.parse(match.group(3)!);
    final light = double.parse(match.group(4)!);
    if (soil == null ||
        soil > 4095 ||
        !temperature.isFinite ||
        temperature < -40 ||
        temperature > 80 ||
        !humidity.isFinite ||
        humidity > 100 ||
        !light.isFinite ||
        light > 4095 ||
        light != light.truncateToDouble()) {
      throw const FormatException('Sensor reading outside ADC/DHT22 range');
    }
    return FloraWandTelemetry(
      soilMoistureRawAdc: soil,
      temperatureCelsius: temperature,
      humidityPercent: humidity,
      lightRawAdc: light.toInt(),
      receivedAt: receivedAt,
    );
  }
}
