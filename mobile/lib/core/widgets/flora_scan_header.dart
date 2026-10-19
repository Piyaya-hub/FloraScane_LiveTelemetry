import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../ble/flora_wand_ble_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'app_icon.dart';

/// Top bar header matching the Google Stitch FloraScan navigation header.
class FloraScanHeader extends StatefulWidget implements PreferredSizeWidget {
  const FloraScanHeader({
    required this.subtitle,
    super.key,
    this.showBack = false,
    this.onBack,
  });

  final String subtitle;
  final bool showBack;
  final VoidCallback? onBack;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  State<FloraScanHeader> createState() => _FloraScanHeaderState();
}

class _FloraScanHeaderState extends State<FloraScanHeader> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.92),
        border: Border(
          bottom: BorderSide(
            color: isDark ? colorScheme.outlineVariant.withValues(alpha: 0.3) : const Color(0x10000000),
            width: 1,
          ),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left: Back button or App Logo + Titles (Flex bounded)
            Expanded(
              child: Row(
                children: [
                  if (widget.showBack)
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
                      onPressed: widget.onBack ?? () => Navigator.maybePop(context),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: FloraScanAppIcon(size: 28),
                    ),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FloraScan',
                          style: AppTypography.headlineMedium.copyWith(
                            color: isDark ? colorScheme.primary : AppColors.primaryContainer,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            height: 1.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          widget.subtitle,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 11,
                            height: 1.1,
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
            // Right: Responsive Wand Status + Profile Avatar
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (MediaQuery.sizeOf(context).width > 420) ...[
                  // Reactive wand status pill
                  Consumer(
                    builder: (context, ref, child) {
                      final wandState = ref.watch(floraWandNotifierProvider);
                      final isConnected = wandState.isConnected;
                      final dotColor = isConnected
                          ? AppColors.secondary
                          : (wandState.isScanning ? AppColors.tertiary : AppColors.error);
                      final text = isConnected
                          ? 'Wand connected'
                          : (wandState.isScanning ? 'Wand...' : 'Wand Off');

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(9999),
                          border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: dotColor,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              text,
                              style: AppTypography.telemetrySmall.copyWith(
                                color: AppColors.onSurfaceVariant,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                ],
                // Profile Avatar
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.secondaryContainer,
                    border: Border.all(color: AppColors.secondaryFixedDim, width: 1.5),
                  ),
                  child: const Center(
                    child: Text(
                      '👨‍🌾',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
