import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'flora_wand_state.dart';

class FloraWandGattUuids {
  FloraWandGattUuids._();
  static final serviceUuid = Guid('12345678-1234-1234-1234-123456789000');
  static final telemetryCharacteristicUuid = Guid(
    '12345678-1234-1234-1234-123456789001',
  );
}

/// Injectable hardware boundary; production always uses flutter_blue_plus.
abstract class FloraWandTransport {
  Stream<List<FloraWandDiscoveredDevice>> get discoveries;
  Stream<void> get disconnections;
  Stream<List<int>> get packets;
  Future<void> startScan(Duration timeout);
  Future<void> stopScan();
  Future<void> connect(String id);
  Future<void> subscribe();
  Future<void> read();
  Future<void> disconnect();
  Future<void> dispose();
}

class FlutterBlueFloraWandTransport implements FloraWandTransport {
  FlutterBlueFloraWandTransport({this.scanResults});

  final Stream<List<ScanResult>>? scanResults;
  final _packets = StreamController<List<int>>.broadcast();
  final _disconnections = StreamController<void>.broadcast();
  BluetoothDevice? _device;
  BluetoothCharacteristic? _characteristic;
  StreamSubscription<BluetoothConnectionState>? _connection;
  StreamSubscription<List<int>>? _values;
  @override
  Stream<List<int>> get packets => _packets.stream;
  @override
  Stream<void> get disconnections => _disconnections.stream;
  @override
  Stream<List<FloraWandDiscoveredDevice>> get discoveries =>
      (scanResults ?? FlutterBluePlus.onScanResults).map(
        (results) => results
            .map(
              (r) => FloraWandDiscoveredDevice(
                id: r.device.remoteId.str,
                name: r.advertisementData.advName.isNotEmpty
                    ? r.advertisementData.advName
                    : r.device.platformName.isNotEmpty
                    ? r.device.platformName
                    : 'Unnamed BLE device',
                rssi: r.rssi,
              ),
            )
            .toList(),
      );
  @override
  Future<void> startScan(Duration timeout) => FlutterBluePlus.startScan(
    // Advertising need not contain the services exposed by GATT. Older ESP32
    // firmware may advertise only a name, or a different service. Let the user
    // select real nearby devices; validate the telemetry service after connect.
    timeout: timeout,
  );
  @override
  Future<void> stopScan() => FlutterBluePlus.stopScan();
  @override
  Future<void> connect(String id) async {
    final device = BluetoothDevice.fromId(id);
    _device = device;
    await device.connect(
      license: License.nonprofit,
      // The sketch sends text longer than the default 20-byte ATT payload.
      mtu: 512,
      timeout: const Duration(seconds: 10),
    );
    if (_device != device) {
      await device.disconnect();
      throw StateError('Connection cancelled');
    }
    _connection = device.connectionState.listen((value) {
      if (value == BluetoothConnectionState.disconnected) {
        _disconnections.add(null);
      }
    }, onError: _disconnections.addError);
    final services = await device.discoverServices();
    if (_device != device) throw StateError('Connection cancelled');
    for (final service in services) {
      if (service.uuid != FloraWandGattUuids.serviceUuid) continue;
      for (final characteristic in service.characteristics) {
        if (characteristic.uuid ==
                FloraWandGattUuids.telemetryCharacteristicUuid &&
            characteristic.properties.notify) {
          _characteristic = characteristic;
        }
      }
    }
    if (_characteristic == null) {
      throw StateError(
        'ESP32 found, but its firmware does not expose the required FloraWand '
        'service 12345678-1234-1234-1234-123456789000 and sensor '
        'characteristic 12345678-1234-1234-1234-123456789001. '
        'Select the FloraScan-Wand running your Arduino sketch.',
      );
    }
  }

  @override
  Future<void> subscribe() async {
    final characteristic = _characteristic!;
    // onValueReceived emits reads and notifications, but does not replay cached data.
    _values = characteristic.onValueReceived.listen(
      _packets.add,
      onError: _packets.addError,
    );
    await characteristic.setNotifyValue(true);
    // Wait for a notification. An initial read could replay an old cached sample.
  }

  @override
  Future<void> read() async {
    final characteristic = _characteristic;
    if (characteristic == null || !characteristic.properties.read) {
      throw StateError('Telemetry read unavailable');
    }
    await characteristic.read(); // Delivered once via onValueReceived.
  }

  @override
  Future<void> disconnect() async {
    final device = _device;
    _device = null;
    _characteristic = null;
    await _connection?.cancel();
    _connection = null;
    await _values?.cancel();
    _values = null;
    await device?.disconnect();
  }

  @override
  Future<void> dispose() async {
    try {
      await stopScan();
    } catch (_) {
      /* Adapter may be unavailable. */
    }
    try {
      await disconnect();
    } finally {
      await _packets.close();
      await _disconnections.close();
    }
  }
}
