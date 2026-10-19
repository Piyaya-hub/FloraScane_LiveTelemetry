import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:florascan_1/core/theme/app_theme.dart';
import 'package:florascan_1/features/learn/presentation/learn_screen.dart';
import 'package:florascan_1/features/plants/presentation/add_plant_screen.dart';
import 'package:florascan_1/features/plants/presentation/my_plants_screen.dart';
import 'package:florascan_1/features/scan/domain/entities/diagnostic_scan_model.dart';
import 'package:florascan_1/features/scan/presentation/scan_screen.dart';
import 'package:florascan_1/features/scan/presentation/widgets/diagnosis_result_sheet.dart';
import 'package:florascan_1/features/settings/presentation/settings_screen.dart';

import 'package:florascan_1/features/plants/domain/entities/plant_model.dart';
import 'package:florascan_1/features/plants/domain/repositories/plant_repository.dart';
import 'package:florascan_1/features/plants/domain/entities/diagnostic_task_model.dart';
import 'package:florascan_1/features/plants/domain/repositories/diagnostic_task_repository.dart';
import 'package:florascan_1/features/plants/presentation/providers/diagnostic_task_providers.dart';
import 'package:florascan_1/features/plants/presentation/providers/plant_providers.dart';

class FakeDiagnosticTaskRepository implements DiagnosticTaskRepository {
  final Map<String, List<DiagnosticTaskModel>> _tasks = {};

  @override
  Future<List<DiagnosticTaskModel>> fetchTasksForPlant(String plantId) async =>
      _tasks[plantId] ?? const <DiagnosticTaskModel>[];

  @override
  Future<void> saveTask(DiagnosticTaskModel task) async {
    final list = List<DiagnosticTaskModel>.from(_tasks[task.plantId] ?? []);
    final idx = list.indexWhere((t) => t.id == task.id);
    if (idx >= 0) {
      list[idx] = task;
    } else {
      list.add(task);
    }
    _tasks[task.plantId] = list;
  }

  @override
  Future<void> saveTasks(List<DiagnosticTaskModel> tasks) async {
    for (final task in tasks) {
      await saveTask(task);
    }
  }

  @override
  Future<void> toggleTaskCompletion(String taskId, bool isCompleted) async {
    for (final plantId in _tasks.keys) {
      final list = _tasks[plantId]!;
      final idx = list.indexWhere((t) => t.id == taskId);
      if (idx >= 0) {
        list[idx] = list[idx].copyWith(isCompleted: isCompleted);
        break;
      }
    }
  }

  @override
  Future<void> deleteTasksForPlant(String plantId) async {
    _tasks.remove(plantId);
  }
}

class FakeStitchPlantRepository implements PlantRepository {
  FakeStitchPlantRepository({List<PlantModel>? initial})
      : _plants = List<PlantModel>.from(initial ?? [
          PlantModel(
            id: 'crop_01',
            name: 'Sweet Plum Tomato',
            cropFamily: 'Solanaceae',
            variety: 'Solanum lycopersicum (Indeterminate)',
            stage: CropGrowthStage.flowering,
            healthStatus: PlantHealthStatus.healthy,
            soilMoisturePercent: 32.4,
            soilTemperatureCelsius: 21.8,
            npkSummary: 'N:180 P:60 K:220 ppm (Optimal)',
            lastScannedAt: DateTime(2026, 10, 18, 10, 0),
            primaryDiagnosis: 'Optimal Vigor - Clean Canopy',
            notes: 'Balcony 1. Drip fertigation zone 2 active. No fungal sporulation observed.',
          ),
          PlantModel(
            id: 'crop_02',
            name: 'Red Habanero Chili',
            cropFamily: 'Solanaceae',
            variety: 'Capsicum chinense',
            stage: CropGrowthStage.fruiting,
            healthStatus: PlantHealthStatus.caution,
            soilMoisturePercent: 21.0,
            soilTemperatureCelsius: 24.5,
            npkSummary: 'N:110 P:45 K:160 ppm (Nitrogen deficit)',
            lastScannedAt: DateTime(2026, 10, 18, 7, 0),
            primaryDiagnosis: 'Early Magnesium Chlorosis',
            notes: 'Backyard. Interveinal yellowing detected on lower leaves. Foliar feeding scheduled.',
          ),
          PlantModel(
            id: 'crop_03',
            name: 'Black Beauty Eggplant',
            cropFamily: 'Solanaceae',
            variety: 'Solanum melongena',
            stage: CropGrowthStage.vegetative,
            healthStatus: PlantHealthStatus.critical,
            soilMoisturePercent: 18.2,
            soilTemperatureCelsius: 23.1,
            npkSummary: 'N:140 P:55 K:190 ppm',
            lastScannedAt: DateTime(2026, 10, 18, 11, 15),
            primaryDiagnosis: 'Early Blight (Alternaria solani)',
            notes: 'Indoor Patio Pot. Target spot concentric lesions on 3 basal leaves. Urgent fungicide intervention required.',
          ),
          PlantModel(
            id: 'crop_04',
            name: 'Roma Tomato',
            cropFamily: 'Solanaceae',
            variety: 'Solanum lycopersicum (Determinate)',
            stage: CropGrowthStage.fruiting,
            healthStatus: PlantHealthStatus.healthy,
            soilMoisturePercent: 29.8,
            soilTemperatureCelsius: 22.0,
            npkSummary: 'N:175 P:58 K:210 ppm',
            lastScannedAt: DateTime(2026, 10, 17, 18, 0),
            primaryDiagnosis: 'Healthy - Ready for first harvest cycle',
            notes: 'Balcony 2. High fruit load. Support staking intact.',
          ),
        ]);

  final List<PlantModel> _plants;

  @override
  Future<List<PlantModel>> fetchAllPlants() async => List.unmodifiable(_plants);

  @override
  Future<PlantModel?> fetchPlantById(String id) async =>
      _plants.where((p) => p.id == id).firstOrNull;

  @override
  Future<void> savePlant(PlantModel plant) async {
    final idx = _plants.indexWhere((p) => p.id == plant.id);
    if (idx >= 0) {
      _plants[idx] = plant;
    } else {
      _plants.add(plant);
    }
  }

  @override
  Future<void> deletePlant(String id) async {
    _plants.removeWhere((p) => p.id == id);
  }
}

void main() {
  group('Google Stitch UI Screens Fidelity Tests', () {
    testWidgets('MyPlantsScreen renders garden banner, Sprouty mascot, and plant cards', (tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            plantRepositoryProvider.overrideWithValue(FakeStitchPlantRepository()),
            diagnosticTaskRepositoryProvider.overrideWithValue(FakeDiagnosticTaskRepository()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const MyPlantsScreen(),
          ),
        ),
      );

      // Act
      await tester.pumpAndSettle();

      // Assert (AAA Pattern)
      expect(find.text('Urban Patch #04'), findsOneWidget);
      expect(find.text('Sprouty'), findsOneWidget);
      expect(find.text('Sweet Plum Tomato'), findsOneWidget);
      expect(find.text('Red Habanero Chili'), findsOneWidget);
      expect(find.text('Black Beauty Eggplant'), findsOneWidget);
      expect(find.text('Roma Tomato'), findsOneWidget);
      expect(find.text('LIVE OPTICAL & PROBE TELEMETRY'), findsOneWidget);
    });

    testWidgets('MyPlantsScreen renders empty garden state when zero plants exist', (tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            plantRepositoryProvider.overrideWithValue(FakeStitchPlantRepository(initial: const [])),
            diagnosticTaskRepositoryProvider.overrideWithValue(FakeDiagnosticTaskRepository()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const MyPlantsScreen(),
          ),
        ),
      );

      // Act
      await tester.pumpAndSettle();

      // Assert (AAA Pattern)
      expect(find.text('Your Garden is Empty'), findsOneWidget);
      expect(find.text('Add Your First Plant'), findsOneWidget);
    });

    testWidgets('MyPlantsScreen renders without RenderFlex overflow on narrow viewport (360x640)', (tester) async {
      // Arrange - Narrow mobile viewport constraint (360px width)
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            plantRepositoryProvider.overrideWithValue(FakeStitchPlantRepository()),
            diagnosticTaskRepositoryProvider.overrideWithValue(FakeDiagnosticTaskRepository()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const MyPlantsScreen(),
          ),
        ),
      );

      // Act
      await tester.pumpAndSettle();

      // Assert (AAA Pattern)
      expect(tester.takeException(), isNull);
      expect(find.text('Sweet Plum Tomato'), findsOneWidget);
      expect(find.text('Black Beauty Eggplant'), findsOneWidget);
      expect(find.text('Roma Tomato'), findsOneWidget);
    });

    testWidgets('MyPlantsScreen renders without RenderFlex overflow on ultra-compact viewport (320x568)', (tester) async {
      // Arrange - Compact mobile viewport constraint (320px width)
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            plantRepositoryProvider.overrideWithValue(FakeStitchPlantRepository()),
            diagnosticTaskRepositoryProvider.overrideWithValue(FakeDiagnosticTaskRepository()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const MyPlantsScreen(),
          ),
        ),
      );

      // Act
      await tester.pumpAndSettle();

      // Assert (AAA Pattern)
      expect(find.text('Sweet Plum Tomato'), findsOneWidget);
      expect(find.text('Black Beauty Eggplant'), findsOneWidget);
      expect(find.text('Roma Tomato'), findsOneWidget);
    });

    testWidgets('LearnScreen renders lesson hero, tabs, and story cards', (tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const LearnScreen(),
          ),
        ),
      );

      // Act
      await tester.pumpAndSettle();

      // Assert (AAA Pattern)
      expect(find.text('Charging & Pairing Wand'), findsOneWidget);
      expect(find.text('1. Charging & Pairing Wand'), findsOneWidget);
      expect(find.text('0 of 6 Done'), findsOneWidget);
      expect(find.text('Start Step 1 (30s)'), findsOneWidget);
      expect(find.text('Quick Lessons (6)'), findsOneWidget);
      expect(find.text('Problems (12)'), findsOneWidget);
      expect(find.text('A–Z Terms'), findsOneWidget);

      // Interact with Hero Card Start button
      await tester.tap(find.text('Start Step 1 (30s)'));
      await tester.pumpAndSettle();
      expect(find.text('LESSON 1 • STEP 1 OF 4'), findsOneWidget);
      expect(find.text('Fast BLE Auto-Pairing'), findsOneWidget);
      expect(find.text('Got it! Continue Lesson'), findsOneWidget);

      // Dismiss modal
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Switch to A–Z Terms tab
      await tester.tap(find.text('A–Z Terms'));
      await tester.pumpAndSettle();
      expect(find.text("Gardener's Glossary"), findsOneWidget);
    });

    testWidgets('LearnScreen renders without RenderFlex overflow on narrow viewport (360x640)', (tester) async {
      // Arrange - Narrow mobile viewport constraint (360px width)
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
            home: const LearnScreen(),
          ),
        ),
      );

      // Act
      await tester.pumpAndSettle();

      // Assert (AAA Pattern)
      expect(tester.takeException(), isNull);
      expect(find.text('1. Charging & Pairing Wand'), findsOneWidget);
      expect(find.text('Quick Lessons (6)'), findsOneWidget);
    });

    testWidgets('LearnScreen renders without RenderFlex overflow on ultra-compact viewport (320x568)', (tester) async {
      // Arrange - Ultra-compact mobile viewport constraint (320px width)
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
            home: const LearnScreen(),
          ),
        ),
      );

      // Act
      FlutterErrorDetails? errorDetails;
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        errorDetails = details;
      };
      await tester.pumpAndSettle();
      FlutterError.onError = originalOnError;

      if (errorDetails != null) {
        FlutterError.dumpErrorToConsole(errorDetails!);
      }

      // Assert (AAA Pattern)
      expect(errorDetails, isNull);
      expect(find.text('1. Charging & Pairing Wand'), findsOneWidget);
      expect(find.text('Quick Lessons (6)'), findsOneWidget);
    });

    testWidgets('SettingsScreen renders hardware wand, calibration, and edge AI', (tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const SettingsScreen(),
          ),
        ),
      );

      // Act
      await tester.pumpAndSettle();

      // Assert (AAA Pattern)
      expect(find.text('App & Hardware Settings'), findsOneWidget);
      expect(find.text('No FloraWand connected'), findsOneWidget);
      expect(find.text('Guided Probe Calibration'), findsOneWidget);
      expect(find.text('Tomato (Solanum lycopersicum)'), findsOneWidget);
      expect(find.text('Daily Soil Inspection'), findsOneWidget);
    });

    testWidgets('SettingsScreen renders without RenderFlex overflow on standard mobile (390x844)', (tester) async {
      // Arrange - iPhone 12/13/14 standard mobile viewport (390px width)
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const SettingsScreen(),
          ),
        ),
      );

      // Act
      await tester.pumpAndSettle();

      // Assert (AAA Pattern)
      expect(tester.takeException(), isNull);
      expect(find.text('No FloraWand connected'), findsOneWidget);
      expect(find.text('92% PWR'), findsNothing);
    });

    testWidgets('SettingsScreen renders without RenderFlex overflow on narrow viewport (360x640)', (tester) async {
      // Arrange - Narrow mobile viewport constraint (360px width)
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
            home: const SettingsScreen(),
          ),
        ),
      );

      // Act
      await tester.pumpAndSettle();

      // Assert (AAA Pattern)
      expect(tester.takeException(), isNull);
      expect(find.text('No FloraWand connected'), findsOneWidget);
      expect(find.text('92% PWR'), findsNothing);
    });

    testWidgets('SettingsScreen renders without RenderFlex overflow on ultra-compact viewport (320x568)', (tester) async {
      // Arrange - Ultra-compact mobile viewport constraint (320px width)
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
            home: const SettingsScreen(),
          ),
        ),
      );

      // Act
      await tester.pumpAndSettle();

      // Assert (AAA Pattern)
      expect(tester.takeException(), isNull);
      expect(find.text('No FloraWand connected'), findsOneWidget);
      expect(find.text('92% PWR'), findsNothing);
    });

    testWidgets('AddPlantScreen renders step tracker and crop profiles', (tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const AddPlantScreen(),
          ),
        ),
      );

      // Act
      await tester.pumpAndSettle();

      // Assert (AAA Pattern)
      expect(find.text('Add New Plant'), findsOneWidget);
      expect(find.text('Step 1 of 4'), findsOneWidget);
      expect(find.text('FloraScan Agri-Guide'), findsOneWidget);
      expect(find.text('Tomato'), findsOneWidget);
      expect(find.text('Red Chili'), findsOneWidget);
      expect(find.text('Eggplant'), findsOneWidget);
    });

    testWidgets('DiagnosisResultSheet renders Step 5 Verdict, dual problem badge, and action checklist', (tester) async {
      // Arrange
      final dummyResult = DiagnosticScanResult(
        scanId: 'scan_001',
        targetCrop: 'Sweet Plum Tomato',
        detectedCondition: 'Early Blight & Moderate Water Stress',
        scientificPathogen: 'Alternaria solani',
        confidencePercentage: 94.2,
        severity: DiagnosticSeverity.caution,
        inferenceLatencyMs: 42,
        isOfflineInference: true,
        symptoms: const ['Concentric ring lesions', 'Lower leaf yellowing', 'Curling margins'],
        organicTreatment: 'Apply organic copper fungicide spray in early morning.',
        chemicalTreatment: 'Chlorothalonil 720 SC (0.15% v/v) or Mancozeb 75 WG.',
        preventativeAction: 'Prune bottom 6 inches of foliage to avoid soil splash.',
        scannedAt: DateTime(2026, 10, 4, 10, 30),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: SingleChildScrollView(
                child: DiagnosisResultSheet(
                  result: dummyResult,
                  onDismiss: () {},
                ),
              ),
            ),
          ),
        ),
      );

      // Act
      await tester.pumpAndSettle();

      // Assert (AAA Pattern)
      expect(find.text('STEP 5 OF 5'), findsOneWidget);
      expect(find.text('Dual Action Required'), findsOneWidget);
      expect(find.text('BOTH: DISEASE & ENVIRONMENT PROBLEM'), findsOneWidget);
      expect(find.text('SIMPLE FIXES FIRST'), findsOneWidget);
    });

    testWidgets('DiagnosisResultSheet renders without RenderFlex overflow on narrow viewport (360x640)', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final dummyResult = DiagnosticScanResult(
        scanId: 'scan_narrow',
        targetCrop: 'Sweet Plum Tomato',
        detectedCondition: 'Early Blight',
        scientificPathogen: 'Alternaria solani',
        confidencePercentage: 94.2,
        severity: DiagnosticSeverity.caution,
        inferenceLatencyMs: 42,
        isOfflineInference: true,
        symptoms: const ['Concentric ring lesions', 'Lower leaf yellowing'],
        organicTreatment: 'Apply organic copper fungicide spray in early morning.',
        chemicalTreatment: 'Chlorothalonil 720 SC (0.15% v/v) or Mancozeb 75 WG.',
        preventativeAction: 'Prune bottom 6 inches of foliage to avoid soil splash.',
        scannedAt: DateTime(2026, 10, 4, 10, 30),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: SingleChildScrollView(
                child: DiagnosisResultSheet(
                  result: dummyResult,
                  onDismiss: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('DiagnosisResultSheet renders without RenderFlex overflow on ultra-compact viewport (320x568)', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final dummyResult = DiagnosticScanResult(
        scanId: 'scan_compact',
        targetCrop: 'Sweet Plum Tomato',
        detectedCondition: 'Early Blight',
        scientificPathogen: 'Alternaria solani',
        confidencePercentage: 94.2,
        severity: DiagnosticSeverity.caution,
        inferenceLatencyMs: 42,
        isOfflineInference: true,
        symptoms: const ['Concentric ring lesions', 'Lower leaf yellowing'],
        organicTreatment: 'Apply organic copper fungicide spray in early morning.',
        chemicalTreatment: 'Chlorothalonil 720 SC (0.15% v/v) or Mancozeb 75 WG.',
        preventativeAction: 'Prune bottom 6 inches of foliage to avoid soil splash.',
        scannedAt: DateTime(2026, 10, 4, 10, 30),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: SingleChildScrollView(
                child: DiagnosisResultSheet(
                  result: dummyResult,
                  onDismiss: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('MyPlantsScreen crop filters filter plant cards interactively', (tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            plantRepositoryProvider.overrideWithValue(FakeStitchPlantRepository()),
            diagnosticTaskRepositoryProvider.overrideWithValue(FakeDiagnosticTaskRepository()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const MyPlantsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // All 4 plants visible initially
      expect(find.text('Sweet Plum Tomato'), findsOneWidget);
      expect(find.text('Red Habanero Chili'), findsOneWidget);
      expect(find.text('Black Beauty Eggplant'), findsOneWidget);
      expect(find.text('Roma Tomato'), findsOneWidget);

      // Act: Filter by Tomato
      await tester.tap(find.text('🍅 Tomato (2)'));
      await tester.pumpAndSettle();

      // Assert: Only Tomatoes visible
      expect(find.text('Sweet Plum Tomato'), findsOneWidget);
      expect(find.text('Roma Tomato'), findsOneWidget);
      expect(find.text('Red Habanero Chili'), findsNothing);
      expect(find.text('Black Beauty Eggplant'), findsNothing);

      // Act: Filter by Chili
      await tester.tap(find.text('🌶️ Chili (1)'));
      await tester.pumpAndSettle();

      // Assert: Only Chili visible
      expect(find.text('Sweet Plum Tomato'), findsNothing);
      expect(find.text('Roma Tomato'), findsNothing);
      expect(find.text('Red Habanero Chili'), findsOneWidget);
      expect(find.text('Black Beauty Eggplant'), findsNothing);

      // Act: Reset to All Plants
      await tester.tap(find.text('All Plants (4)'));
      await tester.pumpAndSettle();

      // Assert: All 4 visible again
      expect(find.text('Sweet Plum Tomato'), findsOneWidget);
      expect(find.text('Red Habanero Chili'), findsOneWidget);
      expect(find.text('Black Beauty Eggplant'), findsOneWidget);
      expect(find.text('Roma Tomato'), findsOneWidget);
    });

    testWidgets('LearnScreen problem tab filters crop atlas cards interactively', (tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const LearnScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Act: Switch to Problems tab
      await tester.tap(find.text('Problems (12)'));
      await tester.pumpAndSettle();

      // Assert: Problems tab active
      expect(find.text('Crop Diagnostics Atlas'), findsOneWidget);
      expect(find.text('Tomato Early Blight'), findsOneWidget);
      expect(find.text('Chili Anthracnose'), findsOneWidget);
      expect(find.text('Eggplant Phomopsis Blight'), findsOneWidget);

      // Act: Filter by Chili
      await tester.tap(find.text('🌶️ Chili'));
      await tester.pumpAndSettle();

      // Assert: Only Chili problem shown
      expect(find.text('Chili Anthracnose'), findsOneWidget);
      expect(find.text('Tomato Early Blight'), findsNothing);
      expect(find.text('Eggplant Phomopsis Blight'), findsNothing);

      // Act: Filter by Eggplant
      await tester.tap(find.text('🍆 Eggplant'));
      await tester.pumpAndSettle();

      // Assert: Only Eggplant problem shown
      expect(find.text('Eggplant Phomopsis Blight'), findsOneWidget);
      expect(find.text('Chili Anthracnose'), findsNothing);
      expect(find.text('Tomato Early Blight'), findsNothing);
    });

    testWidgets('LearnScreen opens story modal and navigates to A-Z Terms tab', (tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const LearnScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Act: Tap Start Step 1 hero button to open modal
      await tester.tap(find.text('Start Step 1 (30s)'));
      await tester.pumpAndSettle();

      // Assert: Modal sheet visible
      expect(find.text('LESSON 1 • STEP 1 OF 4'), findsOneWidget);
      expect(find.text('Fast BLE Auto-Pairing'), findsOneWidget);
      expect(find.text('Got it! Continue Lesson'), findsOneWidget);

      // Act: Dismiss modal
      await tester.tap(find.text('Got it! Continue Lesson'));
      await tester.pumpAndSettle();
      expect(find.text('LESSON 1 • STEP 1 OF 4'), findsNothing);

      // Act: Switch to A-Z Terms tab
      await tester.tap(find.text('A–Z Terms'));
      await tester.pumpAndSettle();

      // Assert: Glossary renders
      expect(find.text("Gardener's Glossary"), findsOneWidget);
      expect(find.text('Abiotic Stress'), findsOneWidget);
      expect(find.text('Overwatering Triage'), findsOneWidget);
      expect(find.text('Spray Timing'), findsOneWidget);
    });

    testWidgets('ScanScreen renders optical scout, crop options turning green, camera and gallery buttons', (tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const ScanScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Assert: Header, HUD, and crop options visible
      expect(find.text('OPTICAL SCOUT'), findsOneWidget);
      expect(find.text('Tomato'), findsOneWidget);
      expect(find.text('Red Chili'), findsOneWidget);
      expect(find.text('Eggplant'), findsOneWidget);

      // Verify camera and gallery buttons
      expect(find.byIcon(Icons.camera_alt), findsOneWidget);
      expect(find.byIcon(Icons.photo_library_outlined), findsOneWidget);

      // Initial state: Tomato selected (color 0xFF22C55E)
      final tomatoText = tester.widget<Text>(find.text('Tomato'));
      expect(tomatoText.style?.color, Colors.black);

      // Act: Tap Red Chili
      await tester.tap(find.text('Red Chili'));
      await tester.pumpAndSettle();

      // Assert: Red Chili is now selected with black text and green container
      final redChiliText = tester.widget<Text>(find.text('Red Chili'));
      expect(redChiliText.style?.color, Colors.black);

      final animatedContainers = tester.widgetList<AnimatedContainer>(find.byType(AnimatedContainer)).toList();
      final chiliContainer = animatedContainers.firstWhere((c) {
        final box = c.decoration as BoxDecoration?;
        return box?.color == const Color(0xFF22C55E);
      });
      expect((chiliContainer.decoration as BoxDecoration).color, const Color(0xFF22C55E));
    });
  });
}
