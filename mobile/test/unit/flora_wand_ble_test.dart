import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:florascan_1/core/ble/flora_wand_ble_service.dart';
import 'package:florascan_1/features/home/presentation/providers/telemetry_providers.dart';

const device = FloraWandDiscoveredDevice(
  id: 'test',
  name: 'Test transport',
  rssi: -60,
);
List<int> packet({
  int soil = 2200,
  int temp = 265,
  int humidity = 687,
  int light = 1234,
}) {
  final b = ByteData(8)
    ..setUint16(0, soil, Endian.little)
    ..setInt16(2, temp, Endian.little)
    ..setUint16(4, humidity, Endian.little)
    ..setUint16(6, light, Endian.little);
  return b.buffer.asUint8List();
}

class FakeTransport implements FloraWandTransport {
  final samples = StreamController<List<int>>.broadcast(sync: true);
  final drops = StreamController<void>.broadcast(sync: true);
  final found = StreamController<List<FloraWandDiscoveredDevice>>.broadcast(
    sync: true,
  );
  bool unavailable = false;
  bool missingCharacteristic = false;
  List<int>? readResponse;
  Completer<void>? pendingConnection;
  @override
  Stream<List<int>> get packets => samples.stream;
  @override
  Stream<void> get disconnections => drops.stream;
  @override
  Stream<List<FloraWandDiscoveredDevice>> get discoveries => found.stream;
  @override
  Future<void> startScan(Duration timeout) async {
    if (unavailable) throw StateError('Unavailable');
  }

  @override
  Future<void> stopScan() async {}
  @override
  Future<void> connect(String id) async {
    if (unavailable || missingCharacteristic) {
      throw StateError('Connection unavailable');
    }
    await pendingConnection?.future;
  }

  @override
  Future<void> subscribe() async {}
  @override
  Future<void> read() async {
    if (readResponse != null) samples.add(readResponse!);
  }

  @override
  Future<void> disconnect() async {}
  @override
  Future<void> dispose() async {
    await samples.close();
    await drops.close();
    await found.close();
  }
}

void main() {
  final time = DateTime.utc(2026, 10, 19);
  test('packet decodes raw ADC, signed temperature and humidity tenths', () {
    final r = FloraWandTelemetry.decode(packet(), time);
    expect(r.soilMoistureRawAdc, 2200);
    expect(r.temperatureCelsius, 26.5);
    expect(r.humidityPercent, 68.7);
    expect(r.lightRawAdc, 1234);
    expect(r.receivedAt, time);
    expect(
      FloraWandTelemetry.decode(packet(temp: -53), time).temperatureCelsius,
      -5.3,
    );
  });
  test('inclusive sensor range boundaries', () {
    final r = FloraWandTelemetry.decode(
      packet(soil: 0, light: 4095, temp: -400, humidity: 0),
      time,
    );
    expect(r.temperatureCelsius, -40);
    expect(r.soilMoistureRawAdc, 0);
    expect(r.lightRawAdc, 4095);
    final upper = FloraWandTelemetry.decode(
      packet(soil: 4095, light: 0, temp: 800, humidity: 1000),
      time,
    );
    expect(upper.temperatureCelsius, 80);
    expect(upper.humidityPercent, 100);
  });
  test(
    'rejects malformed, extra, incomplete, text and invalid sensor packets',
    () {
      for (final bytes in <List<int>>[
        [],
        [1],
        List.filled(7, 0),
        List.filled(9, 0),
        List.filled(16, 0),
        '2200,26.5,68,900'.codeUnits,
        [-1, ...List.filled(7, 0)],
        [256, ...List.filled(7, 0)],
        packet(soil: 4096),
        packet(light: 65535),
        packet(temp: -401),
        packet(temp: 801),
        packet(temp: 32767),
        packet(humidity: 1001),
      ]) {
        expect(
          () => FloraWandTelemetry.decode(bytes, time),
          throwsFormatException,
        );
      }
    },
  );
  late FakeTransport transport;
  late ProviderContainer container;
  late FloraWandNotifier notifier;
  setUp(() {
    transport = FakeTransport();
    container = ProviderContainer(
      overrides: [
        floraWandTransportProvider.overrideWithValue(transport),
        floraWandClockProvider.overrideWithValue(() => time),
      ],
    );
    notifier = container.read(floraWandNotifierProvider.notifier);
  });
  tearDown(() => container.dispose());
  FloraWandState current() => container.read(floraWandNotifierProvider);
  test(
    'startup disconnected with no measurements, timestamp or invented identity',
    () {
      expect(current().connectionState, FloraWandConnectionState.disconnected);
      expect(current().rawTelemetry, isNull);
      expect(current().telemetry, isNull);
      expect(current().lastSampledAt, isNull);
      expect(current().connectedDevice, isNull);
    },
  );
  test('scan only publishes transport discovery events', () async {
    await notifier.startScan();
    expect(current().discoveredDevices, isEmpty);
    transport.found.add([device]);
    expect(current().discoveredDevices, [device]);
    await notifier.stopScan();
    expect(current().isScanning, isFalse);
  });
  test('unavailable hardware never fabricates data or connection', () async {
    transport.unavailable = true;
    await notifier.startScan();
    expect(current().discoveredDevices, isEmpty);
    expect(current().connectionState, FloraWandConnectionState.error);
    expect(await notifier.connect(device), isFalse);
    await notifier.triggerSample();
    expect(current().isConnected, isFalse);
    expect(current().rawTelemetry, isNull);
    expect(current().lastSampledAt, isNull);
  });
  test('missing characteristic fails connection', () async {
    transport.missingCharacteristic = true;
    expect(await notifier.connect(device), isFalse);
    expect(current().connectionState, FloraWandConnectionState.error);
  });
  test(
    'connected awaits data; Riverpod reacts to every valid hardware packet',
    () async {
      final changes = <FloraWandState>[];
      container.listen(
        hardwareTelemetryProvider,
        (_, next) => changes.add(next),
        fireImmediately: true,
      );
      expect(await notifier.connect(device), isTrue);
      expect(current().dataStatus, FloraWandDataStatus.awaitingFirstReading);
      expect(current().lastSampledAt, isNull);
      transport.samples.add(packet());
      await container.pump();
      expect(
        container
            .read(hardwareTelemetryProvider)
            .rawTelemetry
            ?.temperatureCelsius,
        26.5,
      );
      transport.samples.add(packet(temp: -53));
      await container.pump();
      expect(changes.last.rawTelemetry?.temperatureCelsius, -5.3);
      expect(changes.last.hasLiveData, isTrue);
      expect(changes.last.lastSampledAt, time);
      expect(changes.last.telemetry, isNull);
    },
  );
  test(
    'invalid packets never refresh last success and valid packets recover',
    () async {
      await notifier.connect(device);
      transport.samples.add([1]);
      expect(current().lastSampledAt, isNull);
      expect(current().dataStatus, FloraWandDataStatus.error);
      transport.samples.add(packet());
      final reading = current().rawTelemetry;
      transport.samples.add(packet(humidity: 1001));
      expect(current().rawTelemetry, same(reading));
      expect(current().lastSampledAt, time);
      expect(current().hasLiveData, isFalse);
      transport.samples.add(packet());
      expect(current().hasLiveData, isTrue);
      expect(current().errorMessage, isNull);
    },
  );
  test(
    'freshness expires automatically and invalid packets cannot extend it',
    () async {
      container.dispose();
      transport = FakeTransport();
      container = ProviderContainer(
        overrides: [
          floraWandTransportProvider.overrideWithValue(transport),
          floraWandFreshnessProvider.overrideWithValue(
            const Duration(milliseconds: 30),
          ),
          floraWandClockProvider.overrideWithValue(() => time),
        ],
      );
      notifier = container.read(floraWandNotifierProvider.notifier);
      await notifier.connect(device);
      transport.samples.add(packet());
      expect(current().hasLiveData, isTrue);
      transport.samples.add([1]);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(current().dataStatus, FloraWandDataStatus.stale);
      expect(current().lastSampledAt, time);
      transport.samples.add(packet());
      expect(current().hasLiveData, isTrue);
      await notifier.disconnect();
    },
  );
  test('read completion alone cannot refresh data', () async {
    await notifier.connect(device);
    await notifier.triggerSample();
    expect(current().lastSampledAt, isNull);
    transport.readResponse = [];
    await notifier.triggerSample();
    expect(current().lastSampledAt, isNull);
    transport.readResponse = packet();
    await notifier.triggerSample();
    expect(current().hasLiveData, isTrue);
    expect(current().isSampling, isFalse);
  });
  test('unexpected disconnect and reconnect require a new packet', () async {
    await notifier.connect(device);
    transport.samples.add(packet());
    transport.drops.add(null);
    await Future<void>.delayed(Duration.zero);
    expect(current().isConnected, isFalse);
    expect(current().rawTelemetry, isNull);
    transport.samples.add(packet());
    expect(current().rawTelemetry, isNull);
    await notifier.connect(device);
    expect(current().dataStatus, FloraWandDataStatus.awaitingFirstReading);
    expect(current().lastSampledAt, isNull);
    transport.samples.add(packet(temp: 300));
    expect(current().rawTelemetry?.temperatureCelsius, 30);
    await notifier.disconnect();
    expect(current().connectedDevice, isNull);
  });
  test('disconnect cancels pending connection completion', () async {
    transport.pendingConnection = Completer<void>();
    final connecting = notifier.connect(device);
    await Future<void>.delayed(Duration.zero);
    expect(current().isConnecting, isTrue);
    await notifier.disconnect();
    transport.pendingConnection!.complete();
    expect(await connecting, isFalse);
    expect(current().isConnected, isFalse);
  });
}
