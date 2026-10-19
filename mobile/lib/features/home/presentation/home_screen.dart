import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/flora_scan_header.dart';
import '../../../core/widgets/sproutly_mascot.dart';
import '../../plants/domain/entities/plant_model.dart';
import '../../plants/presentation/providers/plant_providers.dart';
import '../../scan/domain/entities/diagnostic_scan_model.dart';
import '../../scan/presentation/providers/diagnostic_providers.dart';
import '../../../core/ble/flora_wand_ble_service.dart';
import '../domain/entities/field_telemetry_model.dart';
import 'providers/telemetry_providers.dart';

/// Main home dashboard screen strictly dedicated to viewing real-time agronomic data.
///
/// Adheres to Clean Architecture and SRP:
/// - Strictly read-only presentation (data mutation resides exclusively in "My Plants").
/// - Reactively consumes [liveTelemetryProvider], [plantListNotifierProvider], and [recentScansProvider].
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wandState = ref.watch(hardwareTelemetryProvider);
    final telemetryAsync = ref.watch(liveTelemetryProvider);
    final plantsAsync = ref.watch(plantListNotifierProvider);
    final scansAsync = ref.watch(recentScansProvider);

    final telemetry = telemetryAsync.value;
    final plants = plantsAsync.value ?? const <PlantModel>[];
    final scans = scansAsync.value ?? const <DiagnosticScanResult>[];

    final attentionPlants = plants
        .where((p) =>
            p.healthStatus == PlantHealthStatus.caution ||
            p.healthStatus == PlantHealthStatus.critical)
        .toList();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: const FloraScanHeader(subtitle: 'Home'),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(plantListNotifierProvider.notifier).reload();
            if (context.mounted) {
              ref.invalidate(baseTelemetrySnapshotProvider);
              ref.invalidate(liveTelemetryProvider);
              ref.invalidate(recentScansProvider);
            }
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Top Warm Greeting Card with Sproutly Mascot
              _buildGreetingCard(context, telemetry, scans),

              const SizedBox(height: 16),

              // 2. Handheld Sensor Wand Status & Live Telemetry Card (Read-Only)
              _buildTelemetryCard(context, ref, wandState, telemetry, plants),

              const SizedBox(height: 18),

              // 3. Plants That Need Attention (Read-Only Focal Alert Stream)
              _buildAttentionSection(context, attentionPlants, hasNoPlants: plants.isEmpty),

              const SizedBox(height: 18),

              // 4. Latest Diagnosis Summary Card (Read-Only Scan History)
              _buildLatestDiagnosisCard(context, scans),

              const SizedBox(height: 18),

              // 5. Rotating Care Tip Featuring Sproutly
              _buildCareTipCard(),

              const SizedBox(height: 18),

              // 6. Prominent Navigation CTA to Optical Scout
              _buildInspectBanner(context),

              const SizedBox(height: 20),
            ],
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildGreetingCard(
    BuildContext context,
    FieldTelemetrySnapshot? telemetry,
    List<DiagnosticScanResult> scans,
  ) {
    final onnxLatency = scans.isNotEmpty
        ? scans.first.inferenceLatencyMs
        : (telemetry?.localInferenceLatencyMs ?? 38);
    final onnxStatus = scans.isNotEmpty
        ? 'ONNX ${onnxLatency}ms • Local Active'
        : 'ONNX ${onnxLatency}ms • Local Ready';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          SproutlyMascot(
            size: 64,
            badgeEmoji: '🌱',
            badgeColor: AppColors.primaryContainer,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Sproutly says: Hello! Your plants are thriving! 🌿'),
                  duration: Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Good morning!',
                  style: AppTypography.headlineSmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Let's check your plants.",
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.secondary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        onnxStatus,
                        style: AppTypography.telemetrySmall.copyWith(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryCard(
    BuildContext context,
    WidgetRef ref,
    FloraWandState wandState,
    FieldTelemetrySnapshot? telemetry,
    List<PlantModel> plants,
  ) {
    final isConnected = wandState.isConnected;
    final activePotLabel = plants.isNotEmpty
        ? 'Active Plot: ${plants.first.name}'
        : 'No registered plots';

    final reading = wandState.hasLiveData ? wandState.rawTelemetry : null;
    final dataLabel = switch (wandState.dataStatus) {
      FloraWandDataStatus.live => 'Live',
      FloraWandDataStatus.stale => 'Stale',
      FloraWandDataStatus.error => 'Error',
      _ => 'Unavailable',
    };
    final moistureVal = reading?.soilMoistureRawAdc.toString() ?? '--';
    final tempVal = reading?.temperatureCelsius.toStringAsFixed(1) ?? '--';
    final humidityVal = reading?.humidityPercent.toStringAsFixed(1) ?? '--';
    final parVal = reading?.lightRawAdc.toString() ?? '--';
    final moistureProgress = reading == null ? 0.0 : reading.soilMoistureRawAdc / 4095;
    final tempProgress = reading == null ? 0.0 : (reading.temperatureCelsius + 40) / 120;
    final humidityProgress = reading == null ? 0.0 : reading.humidityPercent / 100;
    final parProgress = reading == null ? 0.0 : reading.lightRawAdc / 4095;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.secondaryContainer,
                      ),
                      child: const Icon(
                        Icons.sensors,
                        color: AppColors.onSecondaryContainer,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            wandState.statusLabel,
                            style: AppTypography.headlineSmall.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            activePotLabel,
                            style: AppTypography.telemetrySmall.copyWith(
                              fontSize: 11,
                              color: AppColors.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.sensors,
                      size: 14,
                      color: AppColors.secondary,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      isConnected ? 'BLE' : 'Offline',
                      style: AppTypography.telemetrySmall.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.bluetooth,
                      size: 13,
                      color: AppColors.secondary,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 4 Telemetry Metrics Grid (2x2)
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.5,
            children: [
              _TelemetryMiniCard(
                icon: Icons.water_drop,
                iconColor: AppColors.secondary,
                label: 'Soil Moist.',
                statusTag: dataLabel,
                statusBg: AppColors.secondaryFixed,
                statusTextColor: AppColors.onSecondaryFixedVariant,
                numericValue: moistureVal,
                unit: 'raw ADC',
                progressPercent: moistureProgress,
                progressColor: AppColors.secondary,
              ),
              _TelemetryMiniCard(
                icon: Icons.thermostat,
                iconColor: AppColors.tertiaryContainer,
                label: 'Air Temp',
                statusTag: dataLabel,
                statusBg: AppColors.secondaryFixed,
                statusTextColor: AppColors.onSecondaryFixedVariant,
                numericValue: tempVal,
                unit: '°C',
                progressPercent: tempProgress,
                progressColor: AppColors.secondaryFixedDim,
              ),
              _TelemetryMiniCard(
                icon: Icons.cloud,
                iconColor: AppColors.secondary,
                label: 'Humidity',
                statusTag: dataLabel,
                statusBg: AppColors.secondaryFixed,
                statusTextColor: AppColors.onSecondaryFixedVariant,
                numericValue: humidityVal,
                unit: '%',
                progressPercent: humidityProgress,
                progressColor: AppColors.secondary,
              ),
              _TelemetryMiniCard(
                icon: Icons.wb_sunny,
                iconColor: AppColors.tertiaryFixedDim,
                label: 'Light',
                statusTag: dataLabel,
                statusBg: AppColors.secondaryFixed,
                statusTextColor: AppColors.onSecondaryFixedVariant,
                numericValue: parVal,
                unit: 'raw ADC',
                progressPercent: parProgress,
                progressColor: AppColors.tertiaryFixedDim,
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Read another pot action button (Read-only prompt)
          OutlinedButton.icon(
            onPressed: !isConnected || wandState.isSampling ? null : () async {
              await ref.read(floraWandNotifierProvider.notifier).triggerSample();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ref.read(floraWandNotifierProvider).statusLabel),
                    duration: Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            icon: const Icon(Icons.sync, size: 18),
            label: const Text('Read Another Pot'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              backgroundColor: AppColors.surfaceContainerHigh,
              foregroundColor: AppColors.onSurface,
              side: BorderSide.none,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttentionSection(
    BuildContext context,
    List<PlantModel> attentionPlants, {
    required bool hasNoPlants,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Plants That Need Attention',
                style: AppTypography.headlineSmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${attentionPlants.length} Tracked',
              style: AppTypography.telemetrySmall.copyWith(
                color: AppColors.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (hasNoPlants)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.yard_outlined, color: AppColors.secondary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No Plants Added Yet',
                        style: AppTypography.headlineSmall.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Your garden is waiting. Head over to My Plants to register your first plant!',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else if (attentionPlants.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: AppColors.secondary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'All Monitored Crops Healthy!',
                        style: AppTypography.headlineSmall.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                      ),
                      Text(
                        'All registered plots are operating within nominal agronomic thresholds.',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          for (int i = 0; i < attentionPlants.length; i++) ...[
            _buildPlantAttentionCard(context, attentionPlants[i]),
            if (i < attentionPlants.length - 1) const SizedBox(height: 10),
          ],
      ],
    );
  }

  Widget _buildPlantAttentionCard(BuildContext context, PlantModel plant) {
    final isCritical = plant.healthStatus == PlantHealthStatus.critical;
    final tagLabel = isCritical ? 'Needs Care' : 'Needs Care';
    final diagnosis = plant.primaryDiagnosis ??
        (plant.notes.isNotEmpty ? plant.notes : 'Canopy inspection recommended');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        plant.cropFamily.toLowerCase().contains('chili')
                            ? Icons.local_fire_department
                            : Icons.eco,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            plant.name,
                            style: AppTypography.bodyLarge.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurface,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${plant.variety} • Soil ${plant.soilMoisturePercent.toStringAsFixed(0)}%',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.onSurfaceVariant,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isCritical ? AppColors.errorContainer : AppColors.tertiaryFixed,
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCritical ? AppColors.error : AppColors.tertiary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      tagLabel,
                      style: AppTypography.labelUi.copyWith(
                        color: isCritical
                            ? AppColors.onErrorContainer
                            : AppColors.onTertiaryFixed,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: isCritical ? AppColors.error : AppColors.tertiary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    diagnosis,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.onSurface,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: () => context.go(AppRoutes.scan),
            icon: const Icon(Icons.arrow_forward, size: 16),
            label: const Text('Check Now'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              backgroundColor: AppColors.primaryContainer,
              foregroundColor: AppColors.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLatestDiagnosisCard(
    BuildContext context,
    List<DiagnosticScanResult> scans,
  ) {
    if (scans.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Color(0x0D000000), blurRadius: 10, offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.biotech, color: AppColors.secondary, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Latest Diagnosis',
                    style: AppTypography.headlineSmall.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Icon(Icons.qr_code_scanner, size: 36, color: AppColors.secondary),
            const SizedBox(height: 8),
            Text(
              'No Diagnostic Scans Yet',
              style: AppTypography.headlineSmall.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Capture or upload a leaf photo to get real-time offline AI diagnosis.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => context.go(AppRoutes.scan),
              icon: const Icon(Icons.camera_alt, size: 16),
              label: const Text('Start First Scan'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(40),
                backgroundColor: AppColors.surfaceContainerHigh,
                foregroundColor: AppColors.primary,
                side: BorderSide.none,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      );
    }

    final latest = scans.first;

    final condition = latest.detectedCondition;
    final crop = latest.targetCrop;
    final pathogen = latest.scientificPathogen;
    final confidence = '${latest.confidencePercentage.toStringAsFixed(0)}%';
    final symptoms = latest.symptoms.isNotEmpty
        ? latest.symptoms.first
        : 'Fungal leaf spots detected, but your soil moisture and humidity are optimal.';
    final action = latest.organicTreatment.isNotEmpty
        ? latest.organicTreatment
        : 'Snip affected bottom leaves & spray baking soda solution.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x0D000000), blurRadius: 10, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.biotech, color: AppColors.error, size: 22),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Latest Diagnosis',
                        style: AppTypography.headlineSmall.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppColors.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.errorContainer,
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: Text(
                        'DISEASE',
                        style: AppTypography.labelUi.copyWith(
                          color: AppColors.onErrorContainer,
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        child: Text(
                          '$confidence Conf.',
                          style: AppTypography.telemetrySmall.copyWith(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 10,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryContainer,
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        child: Text(
                          '${latest.inferenceLatencyMs}ms ONNX',
                          style: AppTypography.telemetrySmall.copyWith(
                            color: AppColors.onSecondaryContainer,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Crop: $crop ($pathogen)',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        condition,
                        style: AppTypography.telemetrySmall.copyWith(
                          color: AppColors.error,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  symptoms,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.onSurface,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.tertiaryFixed,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.content_cut, color: AppColors.tertiary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'IMMEDIATE ACTION',
                        style: AppTypography.labelUi.copyWith(
                          fontSize: 9,
                          letterSpacing: 0.8,
                          color: AppColors.onTertiaryFixed.withValues(alpha: 0.8),
                        ),
                      ),
                      Text(
                        action,
                        style: AppTypography.bodySmall.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.onTertiaryFixed,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => context.go(AppRoutes.scan),
            icon: const Icon(Icons.medical_services, size: 16),
            label: const Text('View Full Advice & Recipe'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              backgroundColor: AppColors.surfaceContainerHigh,
              foregroundColor: AppColors.primary,
              side: BorderSide.none,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCareTipCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          const SproutlyMascot(
            size: 48,
            badgeEmoji: '💡',
            badgeColor: AppColors.tertiaryContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'QUICK GARDENING TIP',
                  style: AppTypography.labelUi.copyWith(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Water in the early morning at the soil base, not over the leaves, to prevent fungal mold!',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.onSurface,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInspectBanner(BuildContext context) {
    return InkWell(
      onTap: () => context.go(AppRoutes.scan),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primaryContainer,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Color(0x22012D1D), blurRadius: 10, offset: Offset(0, 3)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondaryFixed,
              ),
              child: const Icon(
                Icons.center_focus_strong,
                color: AppColors.onSecondaryFixedVariant,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ready to Inspect?',
                    style: AppTypography.headlineSmall.copyWith(
                      color: AppColors.onPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    'Tap to test a leaf with your camera & wand.',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.onPrimaryContainer,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: AppColors.onPrimaryContainer,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

class _TelemetryMiniCard extends StatelessWidget {
  const _TelemetryMiniCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.statusTag,
    required this.statusBg,
    required this.statusTextColor,
    required this.numericValue,
    required this.unit,
    required this.progressPercent,
    required this.progressColor,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String statusTag;
  final Color statusBg;
  final Color statusTextColor;
  final String numericValue;
  final String unit;
  final double progressPercent;
  final Color progressColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(icon, size: 14, color: iconColor),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        label,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Text(
                    statusTag,
                    style: AppTypography.labelUi.copyWith(
                      color: statusTextColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  numericValue,
                  style: AppTypography.telemetryLarge.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(width: 2),
                Text(
                  unit,
                  style: AppTypography.telemetrySmall.copyWith(
                    fontSize: 11,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(9999),
            child: LinearProgressIndicator(
              value: progressPercent,
              minHeight: 5,
              backgroundColor: AppColors.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
        ],
      ),
    );
  }
}
