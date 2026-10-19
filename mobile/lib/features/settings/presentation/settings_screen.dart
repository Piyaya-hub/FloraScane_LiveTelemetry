import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ble/flora_wand_ble_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/flora_scan_header.dart';
import 'providers/settings_providers.dart';

/// Settings screen managing hardware IoT wand, Edge AI models, and field units matching Google Stitch.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isHomeGardenScale = true; // true = Home Garden, false = Farm Scale
  bool _isEnglish = true;
  bool _isCelsius = true;
  bool _dailyInspectionEnabled = true;

  void _showPairingModal(BuildContext context) {
    ref.read(floraWandNotifierProvider.notifier).startScan();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            final wandState = ref.watch(floraWandNotifierProvider);
            final devices = wandState.discoveredDevices;
            final colorScheme = Theme.of(context).colorScheme;

            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
                child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.bluetooth_searching, color: AppColors.secondary, size: 22),
                        const SizedBox(width: 8),
                        Expanded(child: Text(
                          'Nearby BLE Devices',
                          style: AppTypography.headlineSmall.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
                        )),
                        if (wandState.isScanning)
                          const SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Select your ESP32 by name or device ID. Other nearby BLE devices may also appear.',
                      style: AppTypography.bodySmall.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (!wandState.isScanning && !wandState.isConnecting)
                      TextButton.icon(
                        onPressed: () => ref.read(floraWandNotifierProvider.notifier).startScan(),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Scan again'),
                      ),
                    if (devices.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        alignment: Alignment.center,
                        child: Text(
                          wandState.isScanning
                              ? 'Searching for nearby BLE devices...'
                              : (wandState.errorMessage ?? 'No BLE devices found. Check ESP32 power, Bluetooth and Nearby Devices permission. On older Android phones, enable Location.'),
                          style: AppTypography.bodyMedium.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: devices.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final dev = devices[i];
                          final isCurrent =
                              wandState.connectedDevice?.id == dev.id && wandState.isConnected;

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: colorScheme.primaryContainer,
                              ),
                              child: const Icon(Icons.sensors, color: AppColors.onPrimary, size: 18),
                            ),
                            title: Text(
                              dev.name,
                              style: AppTypography.headlineSmall.copyWith(fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              'ID: ${dev.id} • Signal: ${dev.rssi} dBm',
                              style: AppTypography.telemetrySmall.copyWith(fontSize: 11),
                            ),
                            trailing: ElevatedButton(
                              onPressed: isCurrent
                                  ? null
                                  : () async {
                                      final notifier = ref.read(floraWandNotifierProvider.notifier);
                                      final messenger = ScaffoldMessenger.of(this.context);
                                      Navigator.pop(ctx);
                                      final success = await notifier.connect(dev);
                                      if (!mounted) return;
                                      messenger.hideCurrentSnackBar();
                                      messenger.showSnackBar(SnackBar(
                                        content: Text(success
                                            ? 'Connected. Waiting for sensor telemetry.'
                                            : (this.ref.read(floraWandNotifierProvider).errorMessage ?? 'Failed to connect to ${dev.name}.')),
                                        behavior: SnackBarBehavior.floating,
                                      ));
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorScheme.primaryContainer,
                                foregroundColor: colorScheme.onPrimary,
                              ),
                              child: Text(isCurrent ? 'Paired' : 'Pair & Connect'),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeThemeMode = ref.watch(themeModeProvider);
    final wandState = ref.watch(floraWandNotifierProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: const FloraScanHeader(subtitle: 'Settings'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header title row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'App & Hardware Settings',
                          style: AppTypography.headlineSmall.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                            color: colorScheme.primary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Configured for standalone off-grid field agronomy',
                          style: AppTypography.bodySmall.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Section 1: Biometric Sensor Wand
              _buildSectionTitle(context, Icons.bluetooth_searching, 'BIOMETRIC SENSOR WAND', 'BLE Synced'),
              const SizedBox(height: 8),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? colorScheme.outlineVariant.withValues(alpha: 0.25) : Colors.transparent,
                  ),
                  boxShadow: isDark
                      ? const []
                      : const [
                          BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2)),
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
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.sensors, color: AppColors.onPrimary, size: 22),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            wandState.deviceName,
                                            style: AppTypography.headlineSmall.copyWith(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                              color: colorScheme.onSurface,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: AppColors.secondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      'Firmware v1.4.2 • Hardware ID ${wandState.hardwareId}',
                                      style: AppTypography.telemetrySmall.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                        fontSize: 10,
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
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? colorScheme.secondaryContainer : AppColors.secondaryFixed,
                            borderRadius: BorderRadius.circular(9999),
                          ),
                          child: Text(
                            'BLE',
                            style: AppTypography.labelUi.copyWith(
                              color: isDark ? colorScheme.onSecondaryContainer : AppColors.onSecondaryFixedVariant,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Telemetry baseline progress
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  'Optical Sensor Temp',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '28.4°C (Optimal)',
                                style: AppTypography.telemetrySmall.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(9999),
                            child: LinearProgressIndicator(
                              value: 0.72,
                              minHeight: 5,
                              backgroundColor: colorScheme.surfaceContainerHighest,
                              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.secondary),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  'Soil Probe Response: 12ms',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontSize: 10,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Signal -48 dBm',
                                style: AppTypography.telemetrySmall.copyWith(
                                  fontSize: 10,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Guided calibration
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.tune, color: colorScheme.primary, size: 16),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Guided Probe Calibration',
                                  style: AppTypography.headlineSmall.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    color: colorScheme.primary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Recalibrate field probes seasonally: Zero-point in dry ambient air (0%), saturation probe in distilled water (100%), and zero-lux baseline in covered lens.',
                            style: AppTypography.bodySmall.copyWith(
                              fontSize: 10,
                              color: colorScheme.onSurfaceVariant,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Calibrating Soil Probe (0%/100%)... OK!'),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.water_drop, size: 14, color: AppColors.secondary),
                                  label: const Text('Soil 0%/100%'),
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: colorScheme.surfaceContainerLowest,
                                    foregroundColor: colorScheme.primary,
                                    side: BorderSide(
                                      color: isDark ? colorScheme.outlineVariant.withValues(alpha: 0.3) : Colors.transparent,
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Calibrating Optical Lux Sensor... OK!'),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.wb_sunny, size: 14, color: AppColors.secondary),
                                  label: const Text('Lux Zero-Point'),
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: colorScheme.surfaceContainerLowest,
                                    foregroundColor: colorScheme.primary,
                                    side: BorderSide(
                                      color: isDark ? colorScheme.outlineVariant.withValues(alpha: 0.3) : Colors.transparent,
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Wand action buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              _showPairingModal(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Scanning for nearby BLE devices...'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            icon: const Icon(Icons.sync, size: 16),
                            label: const Text('Pair New Wand'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(44),
                              backgroundColor: colorScheme.primaryContainer,
                              foregroundColor: colorScheme.onPrimary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () async {
                            await ref.read(floraWandNotifierProvider.notifier).disconnect();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Wand disconnected safely.'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.bluetooth_disabled, size: 16),
                          label: const Text('Disconnect'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            backgroundColor: colorScheme.surfaceContainerHigh,
                            foregroundColor: colorScheme.error,
                            side: BorderSide.none,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Section 2: Garden Preferences & UI
              _buildSectionTitle(context, Icons.yard, 'GARDEN OPERATIONS & UI', null),
              const SizedBox(height: 8),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? colorScheme.outlineVariant.withValues(alpha: 0.25) : Colors.transparent,
                  ),
                  boxShadow: isDark
                      ? const []
                      : const [
                          BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2)),
                        ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Theme Mode Selector (Light / Dark / System)
                    Row(
                      children: [
                        Icon(Icons.palette_outlined, size: 16, color: colorScheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          'Display Theme',
                          style: AppTypography.headlineSmall.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildThemeSegment(
                              context: context,
                              title: 'Light',
                              icon: Icons.light_mode_outlined,
                              isSelected: activeThemeMode == ThemeMode.light,
                              onTap: () {
                                ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.light);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Theme set to Light Mode'),
                                    duration: Duration(milliseconds: 900),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                            ),
                          ),
                          Expanded(
                            child: _buildThemeSegment(
                              context: context,
                              title: 'Dark',
                              icon: Icons.dark_mode_outlined,
                              isSelected: activeThemeMode == ThemeMode.dark,
                              onTap: () {
                                ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Theme set to Dark Mode'),
                                    duration: Duration(milliseconds: 900),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                            ),
                          ),
                          Expanded(
                            child: _buildThemeSegment(
                              context: context,
                              title: 'System',
                              icon: Icons.brightness_auto_outlined,
                              isSelected: activeThemeMode == ThemeMode.system,
                              onTap: () {
                                ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.system);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Theme set to System Default'),
                                    duration: Duration(milliseconds: 900),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Operating Scale
                    Row(
                      children: [
                        Icon(Icons.agriculture_rounded, size: 16, color: colorScheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          'Operating Scale',
                          style: AppTypography.headlineSmall.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _isHomeGardenScale = true),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: _isHomeGardenScale ? colorScheme.surfaceContainerLowest : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Column(
                                    children: [
                                      Text(
                                        'Home Garden',
                                        style: AppTypography.bodySmall.copyWith(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                          color: _isHomeGardenScale ? colorScheme.primary : colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      Text(
                                        '(Pots & Balcony)',
                                        style: AppTypography.bodySmall.copyWith(
                                          fontSize: 10,
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _isHomeGardenScale = false),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: !_isHomeGardenScale ? colorScheme.surfaceContainerLowest : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Column(
                                    children: [
                                      Text(
                                        'Farm Scale',
                                        style: AppTypography.bodySmall.copyWith(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                          color: !_isHomeGardenScale ? colorScheme.primary : colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      Text(
                                        '(Zones & Rows)',
                                        style: AppTypography.bodySmall.copyWith(
                                          fontSize: 10,
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Language toggle
                    Row(
                      children: [
                        Icon(Icons.language, size: 16, color: colorScheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          'Language',
                          style: AppTypography.headlineSmall.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setState(() => _isEnglish = true);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Language set to English'),
                                    duration: Duration(milliseconds: 900),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: _isEnglish ? colorScheme.surfaceContainerLowest : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    'English',
                                    style: AppTypography.bodySmall.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: _isEnglish ? colorScheme.primary : colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setState(() => _isEnglish = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Language set to Filipino'),
                                    duration: Duration(milliseconds: 900),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: !_isEnglish ? colorScheme.surfaceContainerLowest : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    'Filipino',
                                    style: AppTypography.bodySmall.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: !_isEnglish ? colorScheme.primary : colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Temperature toggle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Temperature Metric',
                                style: AppTypography.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Sensor wand probe display unit',
                                style: AppTypography.bodySmall.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              InkWell(
                                onTap: () => setState(() => _isCelsius = true),
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _isCelsius ? colorScheme.surfaceContainerLowest : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '°C',
                                    style: AppTypography.telemetrySmall.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: _isCelsius ? colorScheme.primary : colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: () => setState(() => _isCelsius = false),
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: !_isCelsius ? colorScheme.surfaceContainerLowest : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '°F',
                                    style: AppTypography.telemetrySmall.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: !_isCelsius ? colorScheme.primary : colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Daily inspection switch
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Daily Soil Inspection',
                                style: AppTypography.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Morning wand check at 7:30 AM',
                                style: AppTypography.bodySmall.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: _dailyInspectionEnabled,
                          activeTrackColor: AppColors.secondary,
                          onChanged: (val) => setState(() => _dailyInspectionEnabled = val),
                        ),
                      ],
                    ),

                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.verified_user, size: 14, color: AppColors.secondary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '100% local hardware notifications. Never relies on cellular or internet.',
                              style: AppTypography.bodySmall.copyWith(
                                fontSize: 10,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Section 3: Offline Edge AI
              _buildSectionTitle(context, Icons.memory, 'OFFLINE EDGE AI (ONNX BUNDLED)', '13.5 MB Zero-Data'),
              const SizedBox(height: 8),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? colorScheme.outlineVariant.withValues(alpha: 0.25) : Colors.transparent,
                  ),
                  boxShadow: isDark
                      ? const []
                      : const [
                          BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2)),
                        ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Neural Diagnostic Quantized Packs',
                                style: AppTypography.headlineSmall.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: colorScheme.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Hardware-accelerated NPU inference (~38ms)',
                                style: AppTypography.bodySmall.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 10,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? colorScheme.secondaryContainer : AppColors.secondaryFixed,
                            borderRadius: BorderRadius.circular(9999),
                          ),
                          child: Text(
                            'Ready (3/3)',
                            style: AppTypography.labelUi.copyWith(
                              color: isDark ? colorScheme.onSecondaryContainer : AppColors.onSecondaryFixedVariant,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Crop 1: Tomato
                    _buildAiModelRow(context, 'Tomato (Solanum lycopersicum)', 'Model v2.1 • 4.2 MB • Early Blight, Leaf Mold', Icons.eco),
                    const SizedBox(height: 6),
                    // Crop 2: Chili
                    _buildAiModelRow(context, 'Red Chili (Capsicum frutescens)', 'Model v2.0 • 3.9 MB • Anthracnose, Leaf Curl', Icons.local_fire_department),
                    const SizedBox(height: 6),
                    // Crop 3: Eggplant
                    _buildAiModelRow(context, 'Eggplant (Solanum melongena)', 'Model v1.9 • 3.7 MB • Phomopsis Blight, Fruit Borer', Icons.spa),

                    const SizedBox(height: 10),
                    Text(
                      'Engine: ONNX Runtime Mobile',
                      style: AppTypography.bodySmall.copyWith(fontSize: 10, color: colorScheme.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Section 4: Data, Privacy & Storage
              _buildSectionTitle(context, Icons.shield, 'DATA, PRIVACY & LOCAL STORAGE', null),
              const SizedBox(height: 8),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? colorScheme.outlineVariant.withValues(alpha: 0.25) : Colors.transparent,
                  ),
                  boxShadow: isDark
                      ? const []
                      : const [
                          BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2)),
                        ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Zero External Tracking Guarantee',
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'All agricultural images and sensor records remain strictly on this device. You retain 100% data ownership.',
                      style: AppTypography.bodySmall.copyWith(color: colorScheme.onSurfaceVariant, fontSize: 11),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, IconData icon, String title, String? badge) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Icon(icon, size: 14, color: colorScheme.primary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.labelUi.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 10,
                    letterSpacing: 0.8,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        if (badge != null) ...[
          const SizedBox(width: 6),
          Text(
            badge,
            style: AppTypography.telemetrySmall.copyWith(
              color: isDark ? colorScheme.secondary : AppColors.secondary,
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAiModelRow(BuildContext context, String name, String details, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: colorScheme.primary, size: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: AppTypography.bodySmall.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        details,
                        style: AppTypography.bodySmall.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 10,
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
          const SizedBox(width: 6),
          Icon(Icons.check_circle, size: 16, color: colorScheme.secondary),
        ],
      ),
    );
  }

  Widget _buildThemeSegment({
    required BuildContext context,
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.surfaceContainerLowest : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                title,
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
