import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:florascan_1/core/ble/flora_wand_transport.dart';

ScanResult advertisement(String id, String name, List<Guid> services) =>
    ScanResult(
      device: BluetoothDevice.fromId(id),
      advertisementData: AdvertisementData(
        advName: name,
        txPowerLevel: null,
        appearance: null,
        connectable: true,
        manufacturerData: {},
        serviceData: {},
        serviceUuids: services,
      ),
      rssi: -62,
      timeStamp: DateTime.utc(2026, 10, 19),
    );

void main() {
  test('discovery retains older ESP32 advertisements without FF01', () async {
    final transport = FlutterBlueFloraWandTransport(
      scanResults: Stream.value([
        advertisement('AA:BB:CC:DD:EE:01', 'ESP32', []),
        advertisement('AA:BB:CC:DD:EE:02', 'My plant sensor', [Guid('180f')]),
        advertisement('AA:BB:CC:DD:EE:03', 'FloraWand', [
          FloraWandGattUuids.serviceUuid,
        ]),
      ]),
    );
    final devices = await transport.discoveries.first;
    expect(devices.map((d) => d.name), [
      'ESP32',
      'My plant sensor',
      'FloraWand',
    ]);
    expect(devices.first.id, 'AA:BB:CC:DD:EE:01');
    expect(devices.first.rssi, -62);
  });

  test(
    'unnamed real advertisements retain identity without pretending to be FloraWand',
    () async {
      final transport = FlutterBlueFloraWandTransport(
        scanResults: Stream.value([advertisement('AA:BB:CC:DD:EE:04', '', [])]),
      );
      final devices = await transport.discoveries.first;
      expect(devices.single.name, 'Unnamed BLE device');
      expect(devices.single.id, 'AA:BB:CC:DD:EE:04');
    },
  );

  test('empty scan never manufactures a device', () async {
    final transport = FlutterBlueFloraWandTransport(
      scanResults: Stream.value([]),
    );
    expect(await transport.discoveries.first, isEmpty);
  });
}
