import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'flora_wand_calibration_service.dart';
import 'flora_wand_state.dart';
import 'flora_wand_transport.dart';
export 'flora_wand_calibration_service.dart';
export 'flora_wand_state.dart';
export 'flora_wand_transport.dart';

final floraWandTransportProvider = Provider<FloraWandTransport>(
  (ref) => FlutterBlueFloraWandTransport(),
);
final floraWandFreshnessProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 6),
);
final floraWandClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);
final floraWandCalibrationServiceProvider = Provider(
  (ref) => const FloraWandCalibrationService(),
);
final floraWandNotifierProvider =
    NotifierProvider<FloraWandNotifier, FloraWandState>(FloraWandNotifier.new);

class FloraWandNotifier extends Notifier<FloraWandState> {
  late FloraWandTransport _transport;
  StreamSubscription<List<FloraWandDiscoveredDevice>>? _scan;
  StreamSubscription<List<int>>? _packets;
  StreamSubscription<void>? _disconnects;
  Timer? _scanTimer;
  Timer? _freshnessTimer;
  bool _disposed = false;
  bool _connectBusy = false;
  int _generation = 0;
  bool _current(int generation) => !_disposed && generation == _generation;

  @override
  FloraWandState build() {
    _transport = ref.read(floraWandTransportProvider);
    ref.onDispose(() {
      _disposed = true;
      _generation++;
      _scanTimer?.cancel();
      _freshnessTimer?.cancel();
      _scan?.cancel();
      _packets?.cancel();
      _disconnects?.cancel();
      unawaited(_transport.dispose().catchError((Object _) {}));
    });
    return FloraWandState.initial();
  }

  Future<void> startScan({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    if (state.isConnected || state.isConnecting) return;
    await stopScan();
    if (_disposed) return;
    final generation = ++_generation;
    state = state.copyWith(
      connectionState: FloraWandConnectionState.scanning,
      discoveredDevices: [],
      clearError: true,
    );
    try {
      _scan = _transport.discoveries.listen(
        (devices) {
          if (!_current(generation)) return;
          final merged = {
            for (final d in state.discoveredDevices) d.id: d,
            for (final d in devices) d.id: d,
          };
          state = state.copyWith(discoveredDevices: merged.values.toList());
        },
        onError: (Object e) {
          if (_current(generation)) _scanError(e);
        },
      );
      await _transport.startScan(timeout);
      if (!_current(generation)) return;
      _scanTimer = Timer(timeout, () {
        if (_current(generation)) unawaited(stopScan());
      });
    } catch (e) {
      if (_current(generation)) _scanError(e);
    }
  }

  void _scanError(Object e) {
    _scanTimer?.cancel();
    _scan?.cancel();
    state = state.copyWith(
      connectionState: FloraWandConnectionState.error,
      errorMessage: 'Scan failed: $e',
    );
  }

  Future<void> stopScan() async {
    _scanTimer?.cancel();
    await _scan?.cancel();
    _scan = null;
    try {
      await _transport.stopScan();
    } catch (_) {
      /* Nothing to stop on unsupported adapters. */
    }
    if (!_disposed && state.isScanning) {
      state = state.copyWith(
        connectionState: FloraWandConnectionState.disconnected,
      );
    }
  }

  Future<bool> connect(FloraWandDiscoveredDevice device) async {
    if (_connectBusy || _disposed) return false;
    _connectBusy = true;
    try {
      return await _connect(device);
    } finally {
      _connectBusy = false;
    }
  }

  Future<bool> _connect(FloraWandDiscoveredDevice device) async {
    if (state.isConnecting || _disposed) return false;
    await disconnect(isUserInitiated: false);
    if (_disposed) return false;
    final generation = ++_generation;
    state = state.copyWith(
      connectionState: FloraWandConnectionState.connecting,
      clearError: true,
    );
    try {
      _disconnects = _transport.disconnections.listen(
        (_) {
          if (_current(generation)) {
            unawaited(disconnect(isUserInitiated: false));
          }
        },
        onError: (Object e) {
          if (_current(generation)) {
            unawaited(disconnect(isUserInitiated: false));
          }
        },
      );
      await _transport.connect(device.id);
      if (!_current(generation)) return false;
      state = state.copyWith(
        connectionState: FloraWandConnectionState.connected,
        connectedDevice: device,
        dataStatus: FloraWandDataStatus.awaitingFirstReading,
      );
      _packets = _transport.packets.listen(
        (bytes) {
          if (_current(generation)) _receive(bytes);
        },
        onError: (Object e) {
          if (_current(generation)) _dataError('Telemetry stream failed: $e');
        },
      );
      await _transport.subscribe();
      return _current(generation) && state.isConnected;
    } catch (e) {
      if (!_current(generation)) return false;
      await disconnect(isUserInitiated: false);
      if (!_disposed) {
        state = state.copyWith(
          connectionState: FloraWandConnectionState.error,
          errorMessage: 'Connection failed: $e',
        );
      }
      return false;
    }
  }

  void _receive(List<int> bytes) {
    if (!state.isConnected) return;
    try {
      final reading = FloraWandTelemetry.decode(
        bytes,
        ref.read(floraWandClockProvider)(),
      );
      state = state.copyWith(
        rawTelemetry: reading,
        dataStatus: FloraWandDataStatus.live,
        clearError: true,
      );
      _freshnessTimer?.cancel();
      _freshnessTimer = Timer(ref.read(floraWandFreshnessProvider), () {
        if (!_disposed && state.isConnected) {
          state = state.copyWith(dataStatus: FloraWandDataStatus.stale);
        }
      });
    } on FormatException catch (e) {
      _dataError(e.message);
    }
  }

  void _dataError(String message) {
    state = state.copyWith(
      dataStatus: FloraWandDataStatus.error,
      errorMessage: message,
    );
  }

  Future<void> disconnect({bool isUserInitiated = true}) async {
    ++_generation;
    _freshnessTimer?.cancel();
    await _packets?.cancel();
    _packets = null;
    await _disconnects?.cancel();
    _disconnects = null;
    if (!_disposed) {
      state = state.copyWith(
        connectionState: FloraWandConnectionState.disconnected,
        dataStatus: FloraWandDataStatus.unavailable,
        clearTelemetry: true,
        clearConnectedDevice: true,
        clearError: true,
        isSampling: false,
      );
    }
    await stopScan();
    try {
      await _transport.disconnect();
    } catch (e) {
      if (!_disposed) {
        state = state.copyWith(errorMessage: 'Disconnect failed: $e');
      }
    }
  }

  /// Firmware performs a fresh acquisition on read (subject to DHT's 2 s interval).
  Future<void> triggerSample() async {
    if (!state.isConnected || state.isSampling) return;
    final generation = _generation;
    state = state.copyWith(isSampling: true);
    try {
      await _transport.read();
    } catch (e) {
      if (_current(generation)) _dataError('Read failed: $e');
    } finally {
      if (_current(generation)) state = state.copyWith(isSampling: false);
    }
  }
}
