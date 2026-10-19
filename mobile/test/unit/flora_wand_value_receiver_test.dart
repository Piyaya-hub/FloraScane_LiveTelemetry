import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:florascan_1/core/ble/flora_wand_value_receiver.dart';

List<int> sample([int soil = 3039]) =>
    utf8.encode('moisture=$soil,temp=29.7,humidity=75.7,light=80.00');
Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  late StreamController<List<int>> values;
  late List<List<int>> packets;
  late List<Object> errors;
  FloraWandValueReceiver? receiver;
  setUp(() {
    values = StreamController<List<int>>.broadcast(sync: true);
    packets = [];
    errors = [];
  });
  tearDown(() async {
    await receiver?.dispose();
    receiver = null;
    await values.close();
  });
  test(
    '20-byte notification recovers complete text using characteristic read',
    () async {
      var reads = 0;
      receiver = FloraWandValueReceiver(
        values: values.stream,
        readValue: () async {
          reads++;
          await Future<void>.value();
          values.add(sample()); // FBP also emits reads on onValueReceived.
          return sample();
        },
        onPacket: packets.add,
        onError: errors.add,
      );
      values.add(sample().sublist(0, 20));
      await flush();
      expect(reads, 1);
      expect(packets, [sample()]);
      expect(errors, isEmpty);
      // A new notification proves activity even if all four values are unchanged.
      values.add(sample().sublist(0, 20));
      await flush();
      expect(packets.length, 2);
    },
  );
  test('full notifications publish immediately without unnecessary reads', () {
    var reads = 0;
    receiver = FloraWandValueReceiver(
      values: values.stream,
      readValue: () async {
        reads++;
        return sample();
      },
      onPacket: packets.add,
      onError: errors.add,
    );
    values.add(sample());
    values.add(sample());
    expect(packets, [sample(), sample()]);
    expect(reads, 0);
  });
  test(
    'polling obtains changing values when notifications are absent',
    () async {
      var soil = 3039;
      receiver = FloraWandValueReceiver(
        values: values.stream,
        readValue: () async => sample(soil),
        pollInterval: const Duration(milliseconds: 10),
        onPacket: packets.add,
        onError: errors.add,
      );
      receiver!.start();
      await flush();
      expect(packets, [sample(3039)]);
      soil = 3040;
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(packets, [sample(3039), sample(3040)]);
      expect(errors, isEmpty);
    },
  );
  test(
    'unchanged cached reads cannot keep telemetry artificially fresh',
    () async {
      var reads = 0;
      receiver = FloraWandValueReceiver(
        values: values.stream,
        readValue: () async {
          reads++;
          values.add(sample());
          return sample();
        },
        pollInterval: const Duration(milliseconds: 10),
        onPacket: packets.add,
        onError: errors.add,
      );
      receiver!.start();
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(reads, greaterThan(1));
      expect(packets, [sample()]);
    },
  );
  test(
    'invalid read never manufactures data and a subsequent sample recovers',
    () async {
      List<int> response = utf8.encode(
        'moisture=3039,temp=nan,humidity=nan,light=80.00',
      );
      receiver = FloraWandValueReceiver(
        values: values.stream,
        readValue: () async {
          await Future<void>.value();
          values.add(response);
          return response;
        },
        onPacket: packets.add,
        onError: errors.add,
      );
      values.add(sample().sublist(0, 20));
      await flush();
      expect(packets, isEmpty);
      expect(errors.single, isFormatException);
      response = sample();
      values.add(sample().sublist(0, 20));
      await flush();
      expect(packets, [sample()]);
    },
  );
  test('read failure is reported and retry can recover', () async {
    var fails = true;
    receiver = FloraWandValueReceiver(
      values: values.stream,
      readValue: () async {
        if (fails) throw StateError('Read failed');
        return sample();
      },
      onPacket: packets.add,
      onError: errors.add,
    );
    values.add(sample().sublist(0, 20));
    await flush();
    expect(errors.single, isStateError);
    expect(packets, isEmpty);
    fails = false;
    values.add(sample().sublist(0, 20));
    await flush();
    expect(packets, [sample()]);
  });
  test(
    'concurrent recovery is serialized and disconnect ignores in-flight read',
    () async {
      var reads = 0;
      final pending = Completer<List<int>>();
      receiver = FloraWandValueReceiver(
        values: values.stream,
        readValue: () {
          reads++;
          return pending.future;
        },
        onPacket: packets.add,
        onError: errors.add,
      );
      values.add(sample().sublist(0, 20));
      values.add(sample().sublist(0, 20));
      expect(reads, 1);
      await receiver!.dispose();
      pending.complete(sample());
      await flush();
      expect(packets, isEmpty);
      expect(errors, isEmpty);
    },
  );
}
