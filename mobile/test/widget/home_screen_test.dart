import 'package:flutter/material.dart';
import 'package:florascan_1/core/ble/flora_wand_state.dart';
import 'package:florascan_1/features/home/presentation/providers/telemetry_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:florascan_1/core/theme/app_theme.dart';
import 'package:florascan_1/features/home/presentation/home_screen.dart';

void main() {
  testWidgets('HomeScreen renders faithfully matching Google Stitch specifications', (tester) async {
    // Arrange
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const HomeScreen(),
        ),
      ),
    );

    // Act
    await tester.pumpAndSettle();

    // Assert (AAA Pattern adhering to Software Engineer standards)
    expect(find.text('FloraScan'), findsOneWidget);
    expect(find.text('Good morning!'), findsOneWidget);
    expect(find.text("Let's check your plants."), findsOneWidget);
    expect(find.text('FloraWand Offline'), findsOneWidget);
    expect(find.text('Soil Moist.'), findsOneWidget);
    expect(find.text('Plants That Need Attention'), findsOneWidget);
    expect(find.text('Latest Diagnosis'), findsOneWidget);
    expect(find.text('Ready to Inspect?'), findsOneWidget);
  });

  testWidgets('HomeScreen renders without RenderFlex overflow on narrow viewport (360x640)', (tester) async {
    // Arrange
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const HomeScreen(),
        ),
      ),
    );

    // Act
    await tester.pumpAndSettle();

    // Assert (AAA Pattern)
    expect(tester.takeException(), isNull);
    expect(find.text('FloraWand Offline'), findsOneWidget);
    expect(find.text('92%'), findsNothing);
    expect(find.text('--'), findsNWidgets(4));
    expect(find.text('raw ADC'), findsNWidgets(2));
  });

  testWidgets('HomeScreen renders without RenderFlex overflow on ultra-compact viewport (320x568)', (tester) async {
    // Arrange
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const HomeScreen(),
        ),
      ),
    );

    // Act
    await tester.pumpAndSettle();

    // Assert (AAA Pattern)
    expect(tester.takeException(), isNull);
    expect(find.text('FloraWand Offline'), findsOneWidget);
    expect(find.text('92%'), findsNothing);
    expect(find.text('--'), findsNWidgets(4));
    expect(find.text('raw ADC'), findsNWidgets(2));
  });
  testWidgets('raw sensor extremes fit a compact screen', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [hardwareTelemetryProvider.overrideWithValue(FloraWandState(
        connectionState: FloraWandConnectionState.connected,
        dataStatus: FloraWandDataStatus.live,
        rawTelemetry: FloraWandTelemetry(
          soilMoistureRawAdc: 4095, temperatureCelsius: -40,
          humidityPercent: 100, lightRawAdc: 4095,
          receivedAt: DateTime.utc(2026, 10, 19),
        ),
      ))],
      child: MaterialApp(theme: AppTheme.lightTheme, home: const HomeScreen()),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('4095'), findsNWidgets(2));
    expect(find.text('-40.0'), findsOneWidget);
    expect(find.text('100.0'), findsOneWidget);
    expect(find.text('raw ADC'), findsNWidgets(2));
  });
}
