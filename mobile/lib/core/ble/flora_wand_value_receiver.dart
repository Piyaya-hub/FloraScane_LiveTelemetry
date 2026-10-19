import 'dart:async';
import 'package:flutter/foundation.dart';
import 'flora_wand_packet.dart';

/// Recovers the complete characteristic value when Arduino notifications are
/// truncated by the negotiated MTU. Reads and notifications share the FBP stream.
class FloraWandValueReceiver {
  FloraWandValueReceiver({
    required Stream<List<int>> values,
    required this.readValue,
    required this.onPacket,
    required this.onError,
    this.pollInterval = const Duration(seconds: 2),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    _subscription = values.listen(
      _onValue,
      onError: (Object e) {
        if (!_closed) onError(e);
      },
    );
  }

  final Future<List<int>> Function()? readValue;
  final void Function(List<int>) onPacket;
  final void Function(Object) onError;
  final Duration pollInterval;
  final DateTime Function() _clock;
  late final StreamSubscription<List<int>> _subscription;
  Timer? _pollTimer;
  DateTime? _lastNotification;
  List<int>? _lastPublished;
  bool _reading = false;
  bool _closed = false;

  /// Called after notification subscription succeeds. An initial read obtains
  /// the sketch's current value; polling only helps when notifications stop.
  void start() {
    if (_closed || readValue == null) return;
    unawaited(readLatest());
    _pollTimer = Timer.periodic(pollInterval, (_) {
      final last = _lastNotification;
      if (last == null || _clock().difference(last) >= pollInterval) {
        unawaited(readLatest());
      }
    });
  }

  void _onValue(List<int> bytes) {
    // Suppress the read echo; handle its result once.
    if (_closed || _reading) return;
    _lastNotification = _clock();
    try {
      _publish(bytes);
    } on FormatException catch (e) {
      if (readValue != null) {
        // Never join fragments from different samples or invent missing fields.
        unawaited(readLatest(fromNotification: true));
      } else {
        onError(e);
      }
    }
  }

  void _publish(List<int> bytes) {
    FloraWandTelemetry.decode(bytes, _clock());
    _lastPublished = List<int>.of(bytes);
    onPacket(bytes);
  }

  Future<void> readLatest({bool fromNotification = false}) async {
    final read = readValue;
    if (_closed || _reading || read == null) return;
    _reading = true;
    try {
      final bytes = await read();
      if (_closed) return;
      // Validate even an unchanged result, so a sensor failure remains explicit.
      FloraWandTelemetry.decode(bytes, _clock());
      // No sequence/timestamp exists in the sketch's payload. Without a new
      // notification, unchanged reads cannot prove a new acquisition occurred.
      if (fromNotification || !listEquals(bytes, _lastPublished)) {
        _publish(bytes);
      }
    } catch (e) {
      if (!_closed) onError(e);
    } finally {
      _reading = false;
    }
  }

  Future<void> dispose() async {
    _closed = true;
    _pollTimer?.cancel();
    await _subscription.cancel();
  }
}
