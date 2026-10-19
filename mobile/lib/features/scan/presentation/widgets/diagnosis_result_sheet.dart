import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/sproutly_mascot.dart';
import '../../../plants/domain/entities/plant_model.dart';
import '../../../plants/presentation/providers/diagnostic_task_providers.dart';
import '../../../plants/presentation/providers/plant_providers.dart';
import '../../../../core/ble/flora_wand_ble_service.dart';
import '../../domain/entities/diagnostic_scan_model.dart';

/// Modal bottom sheet or full-view diagnostic report strictly mimicking Google Stitch.
class DiagnosisResultSheet extends ConsumerStatefulWidget {
  const DiagnosisResultSheet({
    required this.result,
    required this.onDismiss,
    super.key,
  });

  final DiagnosticScanResult result;
  final VoidCallback onDismiss;

  @override
  ConsumerState<DiagnosisResultSheet> createState() => _DiagnosisResultSheetState();
}

class _DiagnosisResultSheetState extends ConsumerState<DiagnosisResultSheet> {
  // Checkbox states for Tier 1 action items
  bool _step1Checked = false;
  bool _step2Checked = false;
  bool _step3Checked = false;

  // Accordion toggle states for "Why?" explanations
  bool _showWhyMoisture = false;
  bool _showWhyTemp = false;
  bool _showWhyHumidity = false;
  bool _showWhyLight = false;

  PlantModel? _selectedPlant;

  String _resolveCrop(PlantModel plant) {
    final lowerName = plant.name.toLowerCase();
    final lowerVariety = plant.variety.toLowerCase();
    final lowerFamily = plant.cropFamily.toLowerCase();
    if (lowerName.contains('tomato') || lowerVariety.contains('tomato') || lowerFamily.contains('tomato') || lowerVariety.contains('lycopersicum')) {
      return 'Tomato';
    }
    if (lowerName.contains('chili') || lowerName.contains('pepper') || lowerVariety.contains('chili') || lowerVariety.contains('capsicum')) {
      return 'Chili';
    }
    if (lowerName.contains('eggplant') || lowerVariety.contains('eggplant') || lowerVariety.contains('melongena') || lowerName.contains('aubergine')) {
      return 'Eggplant';
    }
    return 'Tomato';
  }

  String _resolveTargetCrop(String rawCrop) {
    final lower = rawCrop.toLowerCase();
    if (lower.contains('chili') || lower.contains('pepper')) return 'Chili';
    if (lower.contains('eggplant') || lower.contains('aubergine')) return 'Eggplant';
    return 'Tomato';
  }

  void _openPlantPickerSheet(BuildContext context, List<PlantModel> plants) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return _PlantSearchPickerSheet(
          plants: plants,
          initialCropFilter: _resolveTargetCrop(widget.result.targetCrop),
          currentSelectedPlantId: _selectedPlant?.id,
          onPlantSelected: (plant) {
            setState(() {
              _selectedPlant = plant;
            });
            Navigator.of(modalCtx).pop();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final plantsAsync = ref.watch(plantListNotifierProvider);
    final wandState = ref.watch(floraWandNotifierProvider);
    final telemetry = wandState.telemetry;
    final allPlants = plantsAsync.value ?? const <PlantModel>[];

    final targetCropCategory = _resolveTargetCrop(widget.result.targetCrop);
    final PlantModel? activePlant = (_selectedPlant != null && allPlants.any((p) => p.id == _selectedPlant!.id))
        ? allPlants.firstWhere((p) => p.id == _selectedPlant!.id)
        : (allPlants.isNotEmpty
            ? allPlants.firstWhere(
                (p) => _resolveCrop(p).toLowerCase() == targetCropCategory.toLowerCase(),
                orElse: () => allPlants.first,
              )
            : null);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Top Telemetry & Edge AI Sync Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.surfaceContainerLow,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.secondary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'IoT Wand Linked • ${widget.result.inferenceLatencyMs}ms Local ONNX',
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.labelUi.copyWith(
                              color: AppColors.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryContainer,
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          size: 13,
                          color: AppColors.onSecondaryContainer,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'STEP 5 OF 5',
                          style: AppTypography.labelUi.copyWith(
                            color: AppColors.onSecondaryContainer,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Crop Identity Badge
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x06000000),
                            blurRadius: 6,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceContainer,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.yard,
                                    color: AppColors.primary,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            'CROP CONFIRMED',
                                            style: AppTypography.labelUi.copyWith(
                                              color: AppColors.secondary,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 9,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Icon(
                                            Icons.verified,
                                            size: 13,
                                            color: AppColors.secondary,
                                          ),
                                        ],
                                      ),
                                      Text(
                                        'Roma Tomato, Balcony Pot',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.headlineSmall.copyWith(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: AppColors.onSurface,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.tune, color: AppColors.onSurfaceVariant),
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // 2. Master Unified Verdict Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0A000000),
                            blurRadius: 8,
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
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.errorContainer,
                                    borderRadius: BorderRadius.circular(9999),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.warning,
                                        size: 13,
                                        color: AppColors.onErrorContainer,
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          'Dual Action Required',
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTypography.labelUi.copyWith(
                                            color: AppColors.onErrorContainer,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(9999),
                                ),
                                child: Text(
                                  'High Confidence',
                                  style: AppTypography.telemetrySmall.copyWith(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'BOTH: DISEASE & ENVIRONMENT PROBLEM',
                            style: AppTypography.headlineSmall.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: AppColors.onSurface,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Your tomato leaf has early fungal leaf spots (Early Blight). At the same time, your soil is currently too wet, which encourages the fungus to spread quickly.',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.onSurfaceVariant,
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Mascot encouragement
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const SproutlyMascot(
                                  size: 46,
                                  badgeEmoji: '🌿',
                                  badgeColor: AppColors.secondary,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '"Don\'t worry, we caught it early!"',
                                        style: AppTypography.headlineSmall.copyWith(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Follow the 3 quick steps below to keep your balcony Roma thriving.',
                                        style: AppTypography.bodySmall.copyWith(
                                          color: AppColors.onSurfaceVariant,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // 3. Side-by-Side Visual Comparison
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Optical Evidence',
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.headlineSmall.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AppColors.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'RETICLE ANALYSIS',
                          style: AppTypography.labelUi.copyWith(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        // Left: Captured Leaf
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  height: 100,
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Stack(
                                    children: [
                                      Center(
                                        child: Icon(
                                          Icons.center_focus_strong,
                                          size: 44,
                                          color: AppColors.error.withValues(alpha: 0.7),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 4,
                                        left: 4,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.inverseSurface.withValues(alpha: 0.85),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'Live Scan',
                                            style: AppTypography.labelUi.copyWith(
                                              color: AppColors.inverseOnSurface,
                                              fontSize: 8,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Your Captured Leaf',
                                  style: AppTypography.bodySmall.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.onSurface,
                                  ),
                                ),
                                Text(
                                  'Distinct bullseye rings',
                                  style: AppTypography.bodySmall.copyWith(
                                    fontSize: 10,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Right: Reference Catalog
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  height: 100,
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceContainer,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Stack(
                                    children: [
                                      const Center(
                                        child: Icon(
                                          Icons.biotech,
                                          size: 44,
                                          color: AppColors.secondary,
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 4,
                                        left: 4,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.inverseSurface.withValues(alpha: 0.85),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'FloraScan Base',
                                            style: AppTypography.labelUi.copyWith(
                                              color: AppColors.inverseOnSurface,
                                              fontSize: 8,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Early Blight',
                                  style: AppTypography.bodySmall.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.onSurface,
                                  ),
                                ),
                                Text(
                                  'Alternaria solani',
                                  style: AppTypography.bodySmall.copyWith(
                                    fontSize: 10,
                                    fontStyle: FontStyle.italic,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    if (telemetry == null)
                      const Text('Calibrated telemetry unavailable'),
                    if (telemetry != null) ...[
                    // 4. Surroundings Telemetry: 4 Wand Sensors
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "What Your Plant's Surroundings Say",
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.headlineSmall.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: AppColors.onSurface,
                                ),
                              ),
                              Text(
                                wandState.isConnected
                                    ? 'Live ${wandState.deviceName} probe telemetry'
                                    : 'Real-time Bluetooth probe telemetry',
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.bodySmall.copyWith(
                                  fontSize: 11,
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (wandState.isConnected) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.secondaryContainer,
                                  borderRadius: BorderRadius.circular(9999),
                                ),
                                child: Text(
                                  '${telemetry.batteryPercent}% PWR',
                                  style: AppTypography.labelUi.copyWith(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.onSecondaryContainer,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Icon(
                              Icons.sensors,
                              color: wandState.isConnected ? AppColors.secondary : AppColors.outline,
                              size: 20,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Sensor 1: Soil Moisture
                    _buildWandSensorCard(
                      title: 'Soil Moisture',
                      icon: Icons.water_drop,
                      value: telemetry.formattedMoisture,
                      target: 'Target: 50–70%',
                      statusTag: telemetry.soilMoistureTag,
                      isError: telemetry.isMoistureWarning,
                      summary: !telemetry.isProbeInserted
                          ? 'Probe blades in open air. Insert into soil.'
                          : telemetry.soilMoisturePercent > 70
                              ? 'Roots are staying waterlogged.'
                              : telemetry.soilMoisturePercent < 50
                                  ? 'Soil is dry; roots need hydration.'
                                  : 'Optimal root-zone moisture level.',
                      isExpanded: _showWhyMoisture,
                      onToggleWhy: () => setState(() => _showWhyMoisture = !_showWhyMoisture),
                      whyText:
                          'Why Soil Moisture Matters: Saturated soil limits root oxygen and triggers spore multiplication of soil-borne blight pathogens that splash onto lower foliage.',
                    ),
                    const SizedBox(height: 8),

                    // Sensor 2: Air Temperature
                    _buildWandSensorCard(
                      title: 'Air Temperature',
                      icon: Icons.thermostat,
                      value: telemetry.formattedTemperature,
                      target: 'Target: 22–30°C',
                      statusTag: telemetry.temperatureTag,
                      isError: telemetry.isTemperatureWarning,
                      summary: telemetry.temperatureCelsius > 32
                          ? 'Heat stress elevates foliar transpiration.'
                          : telemetry.temperatureCelsius < 18
                              ? 'Cool temperatures slow down nutrient uptake.'
                              : 'Comfortable growth temp.',
                      isExpanded: _showWhyTemp,
                      onToggleWhy: () => setState(() => _showWhyTemp = !_showWhyTemp),
                      whyText:
                          'Why Temperature Matters: Roma tomatoes metabolize sugars efficiently between 22°C and 30°C. 28°C supports cellular repair while plants fight off leaf infections.',
                    ),
                    const SizedBox(height: 8),

                    // Sensor 3: Humidity
                    _buildWandSensorCard(
                      title: 'Humidity',
                      icon: Icons.cloud,
                      value: telemetry.formattedHumidity,
                      target: 'Target: 50–75%',
                      statusTag: telemetry.humidityTag,
                      isError: telemetry.isHumidityWarning,
                      summary: telemetry.humidityPercent > 75
                          ? 'Damp air traps mold spores.'
                          : telemetry.humidityPercent < 45
                              ? 'Arid air accelerates leaf desiccation.'
                              : 'Healthy ambient relative humidity.',
                      isExpanded: _showWhyHumidity,
                      onToggleWhy: () => setState(() => _showWhyHumidity = !_showWhyHumidity),
                      whyText:
                          'Why Humidity Matters: Stagnant balcony humidity above 75% keeps water drops lingering on leaves, which acts as a germination incubator for fungal spores.',
                    ),
                    const SizedBox(height: 8),

                    // Sensor 4: Light
                    _buildWandSensorCard(
                      title: 'Light',
                      icon: Icons.wb_sunny,
                      value: telemetry.formattedLight,
                      target: 'Target: 30k–60k Lux',
                      statusTag: telemetry.lightTag,
                      isError: telemetry.isLightWarning,
                      summary: telemetry.lightLux > 60000
                          ? 'Direct solar intensity is scorching leaves.'
                          : telemetry.lightLux < 10000
                              ? 'Insufficient light slows photosynthesis.'
                              : 'Plenty of natural sunlight.',
                      isExpanded: _showWhyLight,
                      onToggleWhy: () => setState(() => _showWhyLight = !_showWhyLight),
                      whyText:
                          'Why Light Matters: Strong natural sunlight boosts tomato leaf cuticle thickness and speeds surface evaporation, strengthening plant natural defense.',
                    ),

                    const SizedBox(height: 18),

                    ],
                    // 5. Prioritized Action Plan
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'What to Do Now',
                                style: AppTypography.headlineSmall.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: AppColors.onSurface,
                                ),
                              ),
                              Text(
                                'Prioritized checklist in strict order',
                                style: AppTypography.bodySmall.copyWith(
                                  fontSize: 11,
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.checklist, color: AppColors.primary, size: 22),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Priority Tier 1: Simple Fixes First
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.primary,
                                ),
                                child: Center(
                                  child: Text(
                                    '1',
                                    style: AppTypography.labelUi.copyWith(
                                      color: AppColors.onPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'SIMPLE FIXES FIRST',
                                  style: AppTypography.headlineSmall.copyWith(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _buildChecklistItem(
                            value: _step1Checked,
                            title: 'Stop watering for 2 days until top 2 inches of soil feel dry.',
                            subtitle: 'Check topsoil with your fingertip or wand depth probe.',
                            onChanged: (val) => setState(() => _step1Checked = val ?? false),
                          ),
                          _buildChecklistItem(
                            value: _step2Checked,
                            title: 'Snip off the 3 yellowing bottom leaves with clean scissors and throw in trash (do not compost).',
                            subtitle: 'Wipe scissors with rubbing alcohol after cutting.',
                            onChanged: (val) => setState(() => _step2Checked = val ?? false),
                          ),
                          _buildChecklistItem(
                            value: _step3Checked,
                            title: 'Move pot 1 foot away from the wall for better breeze.',
                            subtitle: 'Breaks up balcony air stagnation and lowers micro-humidity.',
                            onChanged: (val) => setState(() => _step3Checked = val ?? false),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Priority Tier 2: Eco-Friendly Options
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.secondary,
                                ),
                                child: Center(
                                  child: Text(
                                    '2',
                                    style: AppTypography.labelUi.copyWith(
                                      color: AppColors.onSecondary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'ECO-FRIENDLY OPTIONS',
                                  style: AppTypography.headlineSmall.copyWith(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.secondary,
                                  ),
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.science, color: AppColors.secondary, size: 16),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Baking Soda Spray',
                                        style: AppTypography.bodyMedium.copyWith(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Mix 1 tbsp baking soda + 1 tsp mild liquid soap into 1 liter water. Spray tops and bottoms of remaining leaves tomorrow morning.',
                                  style: AppTypography.bodySmall.copyWith(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.eco, color: AppColors.secondary, size: 16),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Organic Neem Oil',
                                        style: AppTypography.bodyMedium.copyWith(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Apply once every 7 days as a natural shield to suppress fungal spore germination.',
                                  style: AppTypography.bodySmall.copyWith(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Priority Tier 3: Chemicals (Last Resort)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.error,
                                ),
                                child: Center(
                                  child: Text(
                                    '3',
                                    style: AppTypography.labelUi.copyWith(
                                      color: AppColors.onError,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'CHEMICALS (LAST RESORT ONLY)',
                                  style: AppTypography.headlineSmall.copyWith(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.error,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.errorContainer.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Copper Fungicide Spray',
                                  style: AppTypography.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Use only if spots keep spreading after 1 week of drying and organic spray.',
                                  style: AppTypography.bodySmall.copyWith(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 1. Target Plant Plot Selector Section
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.surfaceContainerHigh),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.yard_outlined, size: 16, color: AppColors.primary),
                                  const SizedBox(width: 6),
                                  Text(
                                    'TARGET PLANT PLOT',
                                    style: AppTypography.labelUi.copyWith(
                                      color: AppColors.onSurfaceVariant,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                              if (allPlants.isNotEmpty)
                                TextButton.icon(
                                  onPressed: () => _openPlantPickerSheet(context, allPlants),
                                  icon: const Icon(Icons.search, size: 13),
                                  label: const Text('Change / Search'),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    minimumSize: const Size(0, 26),
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    foregroundColor: AppColors.primary,
                                    textStyle: AppTypography.labelUi.copyWith(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (activePlant != null) ...[
                            InkWell(
                              onTap: () => _openPlantPickerSheet(context, allPlants),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        _resolveCrop(activePlant) == 'Chili'
                                            ? Icons.local_fire_department
                                            : (_resolveCrop(activePlant) == 'Eggplant'
                                                ? Icons.spa
                                                : Icons.eco),
                                        size: 20,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            activePlant.name,
                                            style: AppTypography.bodyMedium.copyWith(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                              color: AppColors.onSurface,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            activePlant.variety.isNotEmpty
                                                ? activePlant.variety
                                                : '${_resolveCrop(activePlant)} Plot',
                                            style: AppTypography.bodySmall.copyWith(
                                              fontSize: 11,
                                              color: AppColors.onSurfaceVariant,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: activePlant.healthStatus == PlantHealthStatus.healthy
                                            ? AppColors.secondaryContainer
                                            : (activePlant.healthStatus == PlantHealthStatus.caution
                                                ? AppColors.tertiaryContainer
                                                : AppColors.errorContainer),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        activePlant.healthStatus.name.toUpperCase(),
                                        style: AppTypography.labelUi.copyWith(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: activePlant.healthStatus == PlantHealthStatus.healthy
                                              ? AppColors.onSecondaryContainer
                                              : (activePlant.healthStatus == PlantHealthStatus.caution
                                                  ? AppColors.onTertiaryContainer
                                                  : AppColors.onErrorContainer),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ] else ...[
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline, size: 16, color: AppColors.onSurfaceVariant),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'No registered plants found. Add plants in My Plants first to save scan diagnostics.',
                                      style: AppTypography.bodySmall.copyWith(
                                        fontSize: 11,
                                        color: AppColors.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Primary Action Button: Save Diagnosis to Plant
                    ElevatedButton.icon(
                      onPressed: activePlant == null
                          ? () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please register a crop plot in My Plants first.'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          : () async {
                              final severity = widget.result.severity;
                              final newStatus = severity == DiagnosticSeverity.severe
                                  ? PlantHealthStatus.critical
                                  : (severity == DiagnosticSeverity.caution
                                      ? PlantHealthStatus.caution
                                      : PlantHealthStatus.healthy);

                              final updated = activePlant.copyWith(
                                healthStatus: newStatus,
                                primaryDiagnosis: '${widget.result.detectedCondition} (${widget.result.confidencePercentage.toStringAsFixed(1)}%)',
                                lastScannedAt: widget.result.scannedAt,
                              );

                              await ref.read(plantListNotifierProvider.notifier).addPlant(updated);

                              if (newStatus != PlantHealthStatus.healthy) {
                                await ref
                                    .read(plantDiagnosticTasksNotifierProvider(updated.id).notifier)
                                    .initializeTasksIfEmpty(updated);
                              }

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Updated diagnostics for "${updated.name}"! Status: ${newStatus.name.toUpperCase()}.'),
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor: AppColors.primary,
                                  ),
                                );
                                widget.onDismiss();
                              }
                            },
                      icon: const Icon(Icons.bookmark, size: 18),
                      label: Text(
                        activePlant != null
                            ? 'Save Diagnosis to ${activePlant.name}'
                            : 'Save Diagnosis to Plant',
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: activePlant == null
                                ? () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Select or register a plant first to log treatment.'),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                : () async {
                                    final treatment = widget.result.organicTreatment.isNotEmpty
                                        ? widget.result.organicTreatment
                                        : 'Applied treatment protocol for ${widget.result.detectedCondition}.';
                                    final updated = activePlant.copyWith(
                                      notes: activePlant.notes.isEmpty
                                          ? 'Treatment: $treatment'
                                          : '${activePlant.notes}\n• Treatment: $treatment',
                                      lastScannedAt: DateTime.now(),
                                    );
                                    await ref.read(plantListNotifierProvider.notifier).addPlant(updated);

                                    if (updated.healthStatus != PlantHealthStatus.healthy) {
                                      await ref
                                          .read(plantDiagnosticTasksNotifierProvider(updated.id).notifier)
                                          .initializeTasksIfEmpty(updated);
                                    }
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Treatment logged to "${activePlant.name}" history!'),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  },
                            icon: const Icon(Icons.edit_calendar, size: 16),
                            label: const Text(
                              'Log Treatment',
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              minimumSize: const Size.fromHeight(46),
                              backgroundColor: AppColors.surfaceContainerHigh,
                              foregroundColor: AppColors.onSurface,
                              side: BorderSide.none,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: widget.onDismiss,
                            icon: const Icon(Icons.document_scanner, size: 16),
                            label: const Text(
                              'Scan Again',
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              minimumSize: const Size.fromHeight(46),
                              backgroundColor: AppColors.surfaceContainerHigh,
                              foregroundColor: AppColors.onSurface,
                              side: BorderSide.none,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWandSensorCard({
    required String title,
    required IconData icon,
    required String value,
    required String target,
    required String statusTag,
    required bool isError,
    required String summary,
    required bool isExpanded,
    required VoidCallback onToggleWhy,
    required String whyText,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
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
                    Icon(icon, size: 16, color: isError ? AppColors.error : AppColors.secondary),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        title,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isError ? AppColors.errorContainer : AppColors.secondaryContainer,
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    child: Text(
                      statusTag,
                      style: AppTypography.labelUi.copyWith(
                        color: isError ? AppColors.onErrorContainer : AppColors.onSecondaryContainer,
                        fontWeight: FontWeight.w700,
                        fontSize: 9,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: onToggleWhy,
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Text(
                            'Why?',
                            style: AppTypography.labelUi.copyWith(
                              fontSize: 9,
                              color: AppColors.onSurface,
                            ),
                          ),
                          Icon(
                            isExpanded ? Icons.expand_less : Icons.expand_more,
                            size: 14,
                            color: AppColors.onSurface,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                value,
                style: AppTypography.telemetryLarge.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  target,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            summary,
            style: AppTypography.bodySmall.copyWith(
              color: isError ? AppColors.error : AppColors.secondary,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
          if (isExpanded) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                whyText,
                style: AppTypography.bodySmall.copyWith(
                  fontSize: 11,
                  color: AppColors.onSurface,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChecklistItem({
    required bool value,
    required String title,
    required String subtitle,
    required ValueChanged<bool?> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: value,
                activeColor: AppColors.primary,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: onChanged,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.bodyMedium.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.bodySmall.copyWith(
                      fontSize: 11,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet dialog allowing the user to search, filter by crop category, and select which registered plant to update.
class _PlantSearchPickerSheet extends StatefulWidget {
  const _PlantSearchPickerSheet({
    required this.plants,
    required this.initialCropFilter,
    required this.currentSelectedPlantId,
    required this.onPlantSelected,
  });

  final List<PlantModel> plants;
  final String initialCropFilter;
  final String? currentSelectedPlantId;
  final ValueChanged<PlantModel> onPlantSelected;

  @override
  State<_PlantSearchPickerSheet> createState() => _PlantSearchPickerSheetState();
}

class _PlantSearchPickerSheetState extends State<_PlantSearchPickerSheet> {
  late String _selectedCropFilter;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedCropFilter = widget.initialCropFilter;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _resolveCrop(PlantModel plant) {
    final lowerName = plant.name.toLowerCase();
    final lowerVariety = plant.variety.toLowerCase();
    final lowerFamily = plant.cropFamily.toLowerCase();
    if (lowerName.contains('tomato') || lowerVariety.contains('tomato') || lowerFamily.contains('tomato') || lowerVariety.contains('lycopersicum')) {
      return 'Tomato';
    }
    if (lowerName.contains('chili') || lowerName.contains('pepper') || lowerVariety.contains('chili') || lowerVariety.contains('capsicum')) {
      return 'Chili';
    }
    if (lowerName.contains('eggplant') || lowerVariety.contains('eggplant') || lowerVariety.contains('melongena') || lowerName.contains('aubergine')) {
      return 'Eggplant';
    }
    return 'Tomato';
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = widget.plants.where((p) {
      final cropMatch = _selectedCropFilter == 'All' ||
          _resolveCrop(p).toLowerCase() == _selectedCropFilter.toLowerCase();
      if (!cropMatch) return false;
      if (query.isEmpty) return true;
      return p.name.toLowerCase().contains(query) ||
          p.variety.toLowerCase().contains(query) ||
          p.notes.toLowerCase().contains(query);
    }).toList();

    final tomatoCount = widget.plants.where((p) => _resolveCrop(p) == 'Tomato').length;
    final chiliCount = widget.plants.where((p) => _resolveCrop(p) == 'Chili').length;
    final eggplantCount = widget.plants.where((p) => _resolveCrop(p) == 'Eggplant').length;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header title & close
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Scanned Plant',
                        style: AppTypography.headlineSmall.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: AppColors.onSurface,
                        ),
                      ),
                      Text(
                        'Filter by category or search by crop name',
                        style: AppTypography.bodySmall.copyWith(
                          fontSize: 11,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // Search text input
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search plant by title or variety...',
                  hintStyle: AppTypography.bodySmall.copyWith(color: AppColors.onSurfaceVariant),
                  prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.primary),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.surfaceContainerLow,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),

            const SizedBox(height: 10),

            // Crop Category Filter Chips (All, Tomato, Chili, Eggplant)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildCategoryChip('All', 'All (${widget.plants.length})'),
                  const SizedBox(width: 8),
                  _buildCategoryChip('Tomato', '🍅 Tomato ($tomatoCount)'),
                  const SizedBox(width: 8),
                  _buildCategoryChip('Chili', '🌶️ Chili ($chiliCount)'),
                  const SizedBox(width: 8),
                  _buildCategoryChip('Eggplant', '🍆 Eggplant ($eggplantCount)'),
                ],
              ),
            ),

            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.surfaceContainerHigh),

            // Filtered Plant List
            Flexible(
              child: filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.yard_outlined, size: 36, color: AppColors.onSurfaceVariant.withValues(alpha: 0.5)),
                          const SizedBox(height: 8),
                          Text(
                            'No matching plants found',
                            style: AppTypography.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Try changing the crop category filter or clear your search keyword.',
                            textAlign: TextAlign.center,
                            style: AppTypography.bodySmall.copyWith(
                              fontSize: 11,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: filtered.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (ctx, idx) {
                        final plant = filtered[idx];
                        final isSelected = plant.id == widget.currentSelectedPlantId;
                        return InkWell(
                          onTap: () => widget.onPlantSelected(plant),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primaryContainer.withValues(alpha: 0.25)
                                  : AppColors.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.surfaceContainerHigh,
                                width: isSelected ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.surfaceContainer,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    _resolveCrop(plant) == 'Chili'
                                        ? Icons.local_fire_department
                                        : (_resolveCrop(plant) == 'Eggplant'
                                            ? Icons.spa
                                            : Icons.eco),
                                    size: 22,
                                    color: isSelected
                                        ? AppColors.onPrimary
                                        : AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        plant.name,
                                        style: AppTypography.bodyMedium.copyWith(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: AppColors.onSurface,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        plant.variety.isNotEmpty
                                            ? plant.variety
                                            : '${_resolveCrop(plant)} Plot',
                                        style: AppTypography.bodySmall.copyWith(
                                          fontSize: 11,
                                          color: AppColors.onSurfaceVariant,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: plant.healthStatus == PlantHealthStatus.healthy
                                        ? AppColors.secondaryContainer
                                        : (plant.healthStatus == PlantHealthStatus.caution
                                            ? AppColors.tertiaryContainer
                                            : AppColors.errorContainer),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    plant.healthStatus.name.toUpperCase(),
                                    style: AppTypography.labelUi.copyWith(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: plant.healthStatus == PlantHealthStatus.healthy
                                          ? AppColors.onSecondaryContainer
                                          : (plant.healthStatus == PlantHealthStatus.caution
                                              ? AppColors.onTertiaryContainer
                                              : AppColors.onErrorContainer),
                                    ),
                                  ),
                                ),
                                if (isSelected) ...[
                                  const SizedBox(width: 8),
                                  const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String category, String label) {
    final isSelected = _selectedCropFilter.toLowerCase() == category.toLowerCase();
    return InkWell(
      onTap: () => setState(() => _selectedCropFilter = category),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.outlineVariant,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.labelUi.copyWith(
            color: isSelected ? AppColors.onPrimary : AppColors.onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}
