import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ble/flora_wand_ble_service.dart';
import '../../../../core/database/app_database.dart';
import '../../data/repositories/local_telemetry_repository.dart';
import '../../domain/entities/field_telemetry_model.dart';
import '../../domain/repositories/telemetry_repository.dart';

/// Dependency injection provider for [TelemetryRepository].
///
/// Injects local database-backed telemetry repository.
final telemetryRepositoryProvider = Provider<TelemetryRepository>((ref) {
  final appDb = ref.watch(appDatabaseProvider);
  return LocalTelemetryRepository(appDb);
});

/// Infrequently fetched base SQLite database snapshot (on-demand/startup).
final baseTelemetrySnapshotProvider = FutureProvider<FieldTelemetrySnapshot>((
  ref,
) async {
  final repository = ref.watch(telemetryRepositoryProvider);
  return repository.fetchLatestTelemetry();
});

/// Existing database snapshot remains separate from uncalibrated hardware data.
final liveTelemetryProvider = Provider<AsyncValue<FieldTelemetrySnapshot>>((
  ref,
) {
  return ref.watch(baseTelemetrySnapshotProvider);
});

/// Synchronous hardware state; never gated by database loading or errors.
final hardwareTelemetryProvider = Provider<FloraWandState>((ref) {
  return ref.watch(floraWandNotifierProvider);
});
