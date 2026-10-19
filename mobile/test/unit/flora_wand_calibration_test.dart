import 'package:flutter_test/flutter_test.dart';
import 'package:florascan_1/core/ble/flora_wand_calibration_service.dart';

void main() {
  group('FloraWandCalibrationService Agronomy Math & Status Tests', () {
    const calibrationService = FloraWandCalibrationService();

    test(
      'Calibrates 1200 ADC to 100% moisture and detects waterlogged status',
      () {
        // Arrange & Act (AAA Pattern)
        final result = calibrationService.calibrate(
          rawMoisture: 1200,
          rawTemperature: 25.0,
          rawHumidity: 60.0,
          rawLight: 1000.0,
          rawBattery: 95,
        );

        // Assert
        expect(result.soilMoisturePercent, equals(100.0));
        expect(result.soilMoistureTag, equals('Waterlogged'));
        expect(result.isMoistureWarning, isTrue);
        expect(result.isProbeInserted, isTrue);
        expect(result.formattedMoisture, equals('100%'));
      },
    );

    test('Calibrates 2200 ADC to 50% moisture with Good status', () {
      // Arrange & Act
      final result = calibrationService.calibrate(
        rawMoisture: 2200,
        rawTemperature: 24.0,
        rawHumidity: 65.0,
        rawLight: 850.0,
        rawBattery: 90,
      );

      // Assert
      expect(result.soilMoisturePercent, equals(50.0));
      expect(result.soilMoistureTag, equals('Good'));
      expect(result.isMoistureWarning, isFalse);
      expect(result.isProbeInserted, isTrue);
    });

    test('Calibrates 3200 ADC to 0% moisture with Too Dry status', () {
      // Arrange & Act
      final result = calibrationService.calibrate(
        rawMoisture: 3200,
        rawTemperature: 24.0,
        rawHumidity: 50.0,
        rawLight: 850.0,
        rawBattery: 85,
      );

      // Assert
      expect(result.soilMoisturePercent, equals(0.0));
      expect(result.soilMoistureTag, equals('Too Dry'));
      expect(result.isMoistureWarning, isTrue);
      expect(result.isProbeInserted, isTrue);
    });

    test('Detects capacitive probe ungrounded in open air when ADC > 3400', () {
      // Arrange & Act
      final result = calibrationService.calibrate(
        rawMoisture: 3850,
        rawTemperature: 26.0,
        rawHumidity: 60.0,
        rawLight: 500.0,
        rawBattery: 80,
      );

      // Assert
      expect(result.isProbeInserted, isFalse);
      expect(result.soilMoistureTag, equals('Probe in Air'));
      expect(result.soilMoisturePercent, equals(0.0));
      expect(result.isMoistureWarning, isTrue);
    });

    test('Evaluates thermal boundaries: Good, Too Hot, Too Cold', () {
      // Normal temperature
      final normal = calibrationService.calibrate(
        rawMoisture: 2200,
        rawTemperature: 26.5,
        rawHumidity: 60.0,
        rawLight: 500.0,
        rawBattery: 80,
      );
      expect(normal.temperatureTag, equals('Good'));
      expect(normal.isTemperatureWarning, isFalse);
      expect(normal.formattedTemperature, equals('26.5°C'));

      // Too Hot (> 32°C)
      final hot = calibrationService.calibrate(
        rawMoisture: 2200,
        rawTemperature: 36.2,
        rawHumidity: 60.0,
        rawLight: 500.0,
        rawBattery: 80,
      );
      expect(hot.temperatureTag, equals('Too Hot'));
      expect(hot.isTemperatureWarning, isTrue);

      // Too Cold (< 15°C)
      final cold = calibrationService.calibrate(
        rawMoisture: 2200,
        rawTemperature: 14.1,
        rawHumidity: 60.0,
        rawLight: 500.0,
        rawBattery: 80,
      );
      expect(cold.temperatureTag, equals('Chilly'));
      expect(cold.isTemperatureWarning, isTrue);
    });

    test(
      'Evaluates relative humidity boundaries: Good, High Mold Risk, Dry Air',
      () {
        final highHum = calibrationService.calibrate(
          rawMoisture: 2200,
          rawTemperature: 25.0,
          rawHumidity: 88.0,
          rawLight: 500.0,
          rawBattery: 80,
        );
        expect(highHum.humidityTag, equals('High Mold Risk'));
        expect(highHum.isHumidityWarning, isTrue);

        final aridHum = calibrationService.calibrate(
          rawMoisture: 2200,
          rawTemperature: 25.0,
          rawHumidity: 25.0,
          rawLight: 500.0,
          rawBattery: 80,
        );
        expect(aridHum.humidityTag, equals('Dry Air'));
        expect(aridHum.isHumidityWarning, isTrue);
      },
    );

    test('Evaluates illuminance formatting and tags', () {
      final bright = calibrationService.calibrate(
        rawMoisture: 2200,
        rawTemperature: 25.0,
        rawHumidity: 60.0,
        rawLight: 42000.0,
        rawBattery: 80,
      );
      expect(bright.formattedLight, equals('42.0k Lux'));
      expect(bright.lightTag, equals('Bright'));
      expect(bright.isLightWarning, isFalse);

      final dim = calibrationService.calibrate(
        rawMoisture: 2200,
        rawTemperature: 25.0,
        rawHumidity: 60.0,
        rawLight: 3950.0,
        rawBattery: 80,
      );
      expect(dim.lightLux, closeTo(63.0, 1.0));
      expect(dim.lightTag, equals('Low Light'));
      expect(dim.isLightWarning, isTrue);
    });
  });
}
