import 'package:flutter/foundation.dart';
import 'flora_wand_calibration_service.dart';
import 'flora_wand_packet.dart';
export 'flora_wand_packet.dart';

enum FloraWandConnectionState {
  disconnected,
  scanning,
  connecting,
  connected,
  error,
}

enum FloraWandDataStatus {
  unavailable,
  awaitingFirstReading,
  live,
  stale,
  error,
}

@immutable
class FloraWandDiscoveredDevice {
  const FloraWandDiscoveredDevice({
    required this.id,
    required this.name,
    required this.rssi,
  });
  final String id;
  final String name;
  final int rssi;
  @override
  bool operator ==(Object other) =>
      other is FloraWandDiscoveredDevice && id == other.id;
  @override
  int get hashCode => id.hashCode;
}

@immutable
class FloraWandState {
  const FloraWandState({
    this.connectionState = FloraWandConnectionState.disconnected,
    this.dataStatus = FloraWandDataStatus.unavailable,
    this.rawTelemetry,
    this.connectedDevice,
    this.discoveredDevices = const [],
    this.errorMessage,
    this.isSampling = false,
  });
  final FloraWandConnectionState connectionState;
  final FloraWandDataStatus dataStatus;
  final FloraWandTelemetry? rawTelemetry;
  final FloraWandDiscoveredDevice? connectedDevice;
  final List<FloraWandDiscoveredDevice> discoveredDevices;
  final String? errorMessage;
  final bool isSampling;

  // Compatibility boundary: Phase 1 does not produce calibrated telemetry.
  // Existing diagnosis/plant consumers must explicitly handle its absence.
  CalibratedTelemetry? get telemetry => null;
  DateTime? get lastSampledAt => rawTelemetry?.receivedAt;
  bool get isConnected => connectionState == FloraWandConnectionState.connected;
  bool get isScanning => connectionState == FloraWandConnectionState.scanning;
  bool get isConnecting =>
      connectionState == FloraWandConnectionState.connecting;
  bool get hasLiveData => isConnected && dataStatus == FloraWandDataStatus.live;
  String get statusLabel => switch (connectionState) {
    FloraWandConnectionState.disconnected => 'FloraWand Offline',
    FloraWandConnectionState.scanning => 'FloraWand Searching...',
    FloraWandConnectionState.connecting => 'FloraWand Connecting...',
    FloraWandConnectionState.error => errorMessage ?? 'Connection error',
    FloraWandConnectionState.connected => switch (dataStatus) {
      FloraWandDataStatus.live => 'Receiving live data',
      FloraWandDataStatus.stale => 'Stale telemetry',
      FloraWandDataStatus.error => errorMessage ?? 'Telemetry error',
      _ => 'Connected, awaiting first reading',
    },
  };
  String get deviceName => connectedDevice?.name ?? 'No FloraWand connected';
  String get hardwareId => connectedDevice?.id ?? '--';

  FloraWandState copyWith({
    FloraWandConnectionState? connectionState,
    FloraWandDataStatus? dataStatus,
    FloraWandTelemetry? rawTelemetry,
    bool clearTelemetry = false,
    FloraWandDiscoveredDevice? connectedDevice,
    bool clearConnectedDevice = false,
    List<FloraWandDiscoveredDevice>? discoveredDevices,
    String? errorMessage,
    bool clearError = false,
    bool? isSampling,
  }) => FloraWandState(
    connectionState: connectionState ?? this.connectionState,
    dataStatus: dataStatus ?? this.dataStatus,
    rawTelemetry: clearTelemetry ? null : rawTelemetry ?? this.rawTelemetry,
    connectedDevice: clearConnectedDevice
        ? null
        : connectedDevice ?? this.connectedDevice,
    discoveredDevices: discoveredDevices ?? this.discoveredDevices,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    isSampling: isSampling ?? this.isSampling,
  );
  factory FloraWandState.initial() => const FloraWandState();
}
