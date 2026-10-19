import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/sproutly_mascot.dart';
import '../../../core/ble/flora_wand_ble_service.dart';
import '../domain/entities/plant_model.dart';
import 'providers/plant_providers.dart';

/// Form screen for adding a new crop plot strictly matching Google Stitch specifications.
class AddPlantScreen extends ConsumerStatefulWidget {
  const AddPlantScreen({super.key});

  @override
  ConsumerState<AddPlantScreen> createState() => _AddPlantScreenState();
}

class _AddPlantScreenState extends ConsumerState<AddPlantScreen> {
  final _formKey = GlobalKey<FormState>();

  String _selectedCrop = 'tomato';
  late final TextEditingController _nicknameController;
  late final TextEditingController _dateController;
  String _selectedGrowthStage = 'vegetative';
  String _selectedLocation = 'balcony';
  String _selectedContainer = 'earthen';
  bool _isWandPaired = true;

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController();
    final now = DateTime.now();
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    _dateController = TextEditingController(text: 'Today, ${months[now.month - 1]} ${now.day}, ${now.year}');
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  void _savePlant() {
    if (!_formKey.currentState!.validate()) return;

    final cropName = switch (_selectedCrop) {
      'tomato' => 'Tomato',
      'chili' => 'Red Chili',
      'eggplant' => 'Eggplant',
      _ => 'Custom Plant',
    };

    final newPlant = PlantModel(
      id: 'plot_${DateTime.now().millisecondsSinceEpoch}',
      name: _nicknameController.text.trim(),
      cropFamily: 'Solanaceae',
      variety: '$cropName Standard',
      stage: switch (_selectedGrowthStage) {
        'seedling' => CropGrowthStage.vegetative,
        'flowering' => CropGrowthStage.flowering,
        'fruiting' => CropGrowthStage.fruiting,
        _ => CropGrowthStage.vegetative,
      },
      healthStatus: PlantHealthStatus.healthy,
      soilMoisturePercent: ref.read(floraWandNotifierProvider).telemetry?.soilMoisturePercent ?? 0.0,
      soilTemperatureCelsius: ref.read(floraWandNotifierProvider).telemetry?.temperatureCelsius ?? 0.0,
      npkSummary: 'Pending calibrated probe scan',
      lastScannedAt: DateTime.now(),
      primaryDiagnosis: 'Baseline registered - Healthy',
      notes: 'Growing in $_selectedLocation using $_selectedContainer container.',
    );

    ref.read(plantListNotifierProvider.notifier).addPlant(newPlant);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Registered "${newPlant.name}" to garden logs!'),
        behavior: SnackBarBehavior.floating,
      ),
    );

    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.95),
            border: const Border(bottom: BorderSide(color: Color(0x10000000), width: 1)),
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.onSurface),
                      onPressed: () => context.pop(),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add New Plant',
                          style: AppTypography.headlineSmall.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: AppColors.onSurface,
                          ),
                        ),
                        Text(
                          'GARDEN LOG SETUP',
                          style: AppTypography.labelUi.copyWith(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Step Progress Tracker
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primaryContainer,
                            ),
                            child: Center(
                              child: Text(
                                '1',
                                style: AppTypography.labelUi.copyWith(
                                  color: AppColors.onPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Step 1 of 4',
                            style: AppTypography.headlineSmall.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppColors.onSurface,
                            ),
                          ),
                          Text(
                            ' • Select plant type',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryFixed,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'SETUP ACTIVE',
                          style: AppTypography.labelUi.copyWith(
                            color: AppColors.onSecondaryFixedVariant,
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Friendly Mascot Prompt
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const SproutlyMascot(size: 42),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'FloraScan Agri-Guide',
                              style: AppTypography.headlineSmall.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: AppColors.onSecondaryContainer,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Tip: Select your crop type to automatically load pre-calibrated soil moisture targets and sunlight requirements for high-yield growth!',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.onSecondaryContainer,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // STEP 1: Quick Crop Presets
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Plant Type / Crop Profile',
                          style: AppTypography.headlineSmall.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppColors.onSurface,
                          ),
                        ),
                        Text(
                          'Calibrated profiles for hyper-local scouting',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryFixed,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Preset Ready',
                        style: AppTypography.labelUi.copyWith(
                          color: AppColors.onSecondaryFixedVariant,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Crop Preset Cards
                _buildCropPresetCard(
                  key: 'tomato',
                  title: 'Tomato',
                  scientific: '(Solanum lycopersicum)',
                  moisture: '60-70%',
                  sunlight: '6-8 hrs',
                  icon: Icons.eco,
                  iconBg: const Color(0xFFFFEBEE),
                  iconColor: const Color(0xFFC62828),
                ),
                const SizedBox(height: 8),

                _buildCropPresetCard(
                  key: 'chili',
                  title: 'Red Chili',
                  scientific: '(Capsicum frutescens)',
                  moisture: '40-55%',
                  sunlight: 'Full Sun',
                  icon: Icons.local_fire_department,
                  iconBg: const Color(0xFFFFF8E1),
                  iconColor: const Color(0xFFF57F17),
                ),
                const SizedBox(height: 8),

                _buildCropPresetCard(
                  key: 'eggplant',
                  title: 'Eggplant',
                  scientific: '(Solanum melongena)',
                  moisture: '65-75%',
                  sunlight: 'Warm Climate',
                  icon: Icons.spa,
                  iconBg: const Color(0xFFF3E5F5),
                  iconColor: const Color(0xFF6A1B9A),
                ),

                const SizedBox(height: 16),

                // STEP 2: Plant Details & Nickname
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary,
                            ),
                            child: Center(
                              child: Text(
                                '2',
                                style: AppTypography.labelUi.copyWith(
                                  color: AppColors.onPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Plant Details & Nickname',
                            style: AppTypography.headlineSmall.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppColors.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Plant Photo Documentation box
                      Container(
                        padding: const EdgeInsets.all(10),
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
                                Row(
                                  children: [
                                    const Icon(Icons.photo_camera, size: 16, color: AppColors.secondary),
                                    const SizedBox(width: 6),
                                    Text(
                                      'PLANT PHOTO DOCUMENTATION',
                                      style: AppTypography.labelUi.copyWith(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceContainer,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Gallery Record',
                                    style: AppTypography.labelUi.copyWith(
                                      fontSize: 8,
                                      color: AppColors.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Standard camera capture to identify and document your plant's growth over time.",
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.add_a_photo, size: 16),
                              label: const Text('Take Photo or Choose from Gallery'),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(40),
                                backgroundColor: AppColors.surfaceContainer,
                                foregroundColor: AppColors.onSurface,
                                side: BorderSide.none,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      Text(
                        'PLANT NICKNAME',
                        style: AppTypography.labelUi.copyWith(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextFormField(
                        controller: _nicknameController,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.label, size: 18, color: AppColors.secondary),
                          hintText: 'e.g., Cherry Tomato - Balcony',
                          filled: true,
                          fillColor: AppColors.surfaceContainer,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Enter a nickname' : null,
                      ),

                      const SizedBox(height: 12),

                      Text(
                        'DATE PLANTED',
                        style: AppTypography.labelUi.copyWith(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextFormField(
                        controller: _dateController,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.calendar_today, size: 18, color: AppColors.onSurfaceVariant),
                          filled: true,
                          fillColor: AppColors.surfaceContainer,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),

                      const SizedBox(height: 12),

                      Text(
                        'GROWTH STAGE',
                        style: AppTypography.labelUi.copyWith(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildStageChip('seedling', 'Seedling', Icons.find_replace),
                          _buildStageChip('vegetative', 'Vegetative', Icons.spa),
                          _buildStageChip('flowering', 'Flowering', Icons.local_florist),
                          _buildStageChip('fruiting', 'Fruiting', Icons.eco),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // STEP 3: Location & Container
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary,
                            ),
                            child: Center(
                              child: Text(
                                '3',
                                style: AppTypography.labelUi.copyWith(
                                  color: AppColors.onPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Location & Container',
                            style: AppTypography.headlineSmall.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppColors.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      Text(
                        'GROWING LOCATION',
                        style: AppTypography.labelUi.copyWith(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildLocationChip('balcony', 'Balcony', Icons.balcony),
                          _buildLocationChip('backyard', 'Backyard Bed', Icons.yard),
                          _buildLocationChip('patio', 'Patio Pots', Icons.deck),
                          _buildLocationChip('indoor', 'Indoor Window', Icons.window),
                        ],
                      ),

                      const SizedBox(height: 12),

                      Text(
                        'CONTAINER TYPE',
                        style: AppTypography.labelUi.copyWith(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildContainerChip('earthen', 'Earthen Pot'),
                          _buildContainerChip('growbag', 'Grow Bag'),
                          _buildContainerChip('raised', 'Raised Bed'),
                          _buildContainerChip('direct', 'Direct Soil'),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // STEP 4: FloraScan IoT Wand Link
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.secondaryContainer,
                                ),
                                child: Center(
                                  child: Text(
                                    '4',
                                    style: AppTypography.labelUi.copyWith(
                                      color: AppColors.onSecondaryContainer,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'FloraScan IoT Wand',
                                style: AppTypography.headlineSmall.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: AppColors.onPrimary,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _isWandPaired ? AppColors.secondary : AppColors.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(9999),
                            ),
                            child: Text(
                              _isWandPaired ? 'BLE Active' : 'Standby',
                              style: AppTypography.labelUi.copyWith(
                                color: _isWandPaired ? AppColors.secondaryFixed : AppColors.onSurfaceVariant,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Pair hardware probe for real-time soil moisture and instant edge leaf diagnostics.',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.onPrimaryContainer,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.sensors,
                                  color: _isWandPaired ? AppColors.secondaryFixed : Colors.white38,
                                  size: 22,
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _isWandPaired ? 'FloraScan IoT Wand' : 'Probe Disconnected',
                                      style: AppTypography.headlineSmall.copyWith(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.onPrimary,
                                      ),
                                    ),
                                    Text(
                                      _isWandPaired
                                          ? 'BLE Connected • Telemetry Synced'
                                          : 'Toggle to pair Bluetooth hardware probe',
                                      style: AppTypography.telemetrySmall.copyWith(
                                        fontSize: 10,
                                        color: _isWandPaired ? AppColors.secondaryFixed : Colors.white60,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Switch.adaptive(
                              value: _isWandPaired,
                              activeThumbColor: AppColors.secondaryContainer,
                              onChanged: (val) => setState(() => _isWandPaired = val),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Bottom Buttons
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: OutlinedButton(
                        onPressed: () => context.pop(),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          backgroundColor: AppColors.surfaceContainer,
                          foregroundColor: AppColors.onSurface,
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _savePlant,
                        icon: const Icon(Icons.add_circle, size: 18),
                        label: const Text('Save Plant'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          backgroundColor: AppColors.primaryContainer,
                          foregroundColor: AppColors.onPrimary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCropPresetCard({
    required String key,
    required String title,
    required String scientific,
    required String moisture,
    required String sunlight,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
  }) {
    final isSelected = _selectedCrop == key;
    return InkWell(
      onTap: () => setState(() => _selectedCrop = key),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: AppTypography.headlineSmall.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppColors.onSurface,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          scientific,
                          style: AppTypography.bodySmall.copyWith(
                            fontSize: 11,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.water_drop, size: 10, color: AppColors.secondary),
                              const SizedBox(width: 2),
                              Text(
                                moisture,
                                style: AppTypography.telemetrySmall.copyWith(fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.wb_sunny, size: 10, color: AppColors.tertiaryContainer),
                              const SizedBox(width: 2),
                              Text(
                                sunlight,
                                style: AppTypography.telemetrySmall.copyWith(fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.secondary : AppColors.surfaceContainer,
              ),
              child: isSelected ? const Icon(Icons.check, size: 14, color: AppColors.onSecondary) : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStageChip(String key, String label, IconData icon) {
    final isSelected = _selectedGrowthStage == key;
    return InkWell(
      onTap: () => setState(() => _selectedGrowthStage = key),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryContainer : AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? AppColors.onPrimary : AppColors.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.onPrimary : AppColors.onSurface,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationChip(String key, String label, IconData icon) {
    final isSelected = _selectedLocation == key;
    return InkWell(
      onTap: () => setState(() => _selectedLocation = key),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.secondaryContainer : AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? AppColors.onSecondaryContainer : AppColors.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.onSecondaryContainer : AppColors.onSurface,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContainerChip(String key, String label) {
    final isSelected = _selectedContainer == key;
    return InkWell(
      onTap: () => setState(() => _selectedContainer = key),
      borderRadius: BorderRadius.circular(9999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(9999),
        ),
        child: Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? AppColors.onPrimary : AppColors.onSurface,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}
