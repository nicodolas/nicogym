import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nicogym/app.dart';
import 'package:nicogym/features/workout/workout_screen.dart';
import 'package:nicogym/workouts/exercise.dart';
import 'package:nicogym/workouts/workout_api.dart';

void main() {
  const testExercises = [
    Exercise(
      id: 'leg-press',
      name: 'Leg press',
      prescription: '3 × 8–10',
      primaryMuscles: ['Đùi trước', 'Mông'],
      equipment: 'Máy leg press',
      summary: 'Đẩy bàn máy bằng cả bàn chân.',
      setup: ['Đặt chân rộng ngang vai.'],
      steps: ['Hạ có kiểm soát.', 'Đẩy qua cả bàn chân.'],
      cues: ['Đầu gối đi cùng hướng mũi chân'],
      mistakes: ['Khóa cứng đầu gối'],
      safety: 'Dừng nếu đau nhói.',
      sourceLabel: 'ACE Exercise Library',
      sourceUrl: 'https://example.com/source',
      videoUrl: 'https://example.com/video',
    ),
    Exercise(
      id: 'romanian-deadlift',
      name: 'Romanian deadlift',
      prescription: '3 × 8',
      primaryMuscles: ['Đùi sau', 'Mông'],
      equipment: 'Thanh đòn',
      summary: 'Gập tại hông.',
      setup: ['Giữ tạ trước đùi.'],
      steps: ['Đẩy hông ra sau.'],
      cues: ['Hông lùi, không ngồi xổm'],
      mistakes: ['Cong lưng'],
      safety: 'Tập hip hinge không tạ trước.',
      sourceLabel: 'ACE Exercise Library',
      sourceUrl: 'https://example.com/source',
      videoUrl: 'https://example.com/video',
    ),
  ];

  Future<List<Exercise>> loadTestExercises() async => testExercises;

  void useMobileViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('shows today workout and recovery status', (tester) async {
    useMobileViewport(tester);
    await tester.pumpWidget(NicoGymApp(exerciseLoader: loadTestExercises));

    expect(find.text('HÔM NAY'), findsOneWidget);
    expect(find.text('CHÂN + MÔNG'), findsOneWidget);
    expect(find.text('3/5 nhóm cơ sẵn sàng'), findsOneWidget);
    expect(find.text('Bắt đầu buổi tập'), findsOneWidget);
  });

  testWidgets('shows only the compact base app version', (tester) async {
    useMobileViewport(tester);
    await tester.pumpWidget(
      NicoGymApp(exerciseLoader: loadTestExercises, baseAppVersion: '1.1.1+5'),
    );

    await tester.pump(const Duration(milliseconds: 100));
    await tester.scrollUntilVisible(
      find.text('v1.1.1+5'),
      500,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('v1.1.1+5'), findsOneWidget);
    expect(find.textContaining('OTA'), findsNothing);
  });

  testWidgets('opens workout mode and logs a set quickly', (tester) async {
    useMobileViewport(tester);
    final workoutRepository = _MemoryWorkoutRepository();
    await tester.pumpWidget(
      NicoGymApp(
        exerciseLoader: loadTestExercises,
        workoutRepository: workoutRepository,
      ),
    );
    await tester.tap(find.text('Bắt đầu buổi tập'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Leg press'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('load-input')),
      400,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('HIỆP 1'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('load-input')), '40');
    await tester.enterText(find.byKey(const Key('reps-input')), '10');
    await tester.tap(find.text('Ghi hiệp'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -250));
    await tester.pumpAndSettle();

    expect(find.text('40 kg × 10'), findsOneWidget);
    expect(find.text('HIỆP 2'), findsOneWidget);
    expect(find.text('Đã đồng bộ hiệp 1'), findsOneWidget);
    expect(find.byKey(const Key('previous-set')), findsOneWidget);
    expect(find.byKey(const Key('rest-timer')), findsOneWidget);
    expect(find.textContaining('1:30'), findsOneWidget);
    await tester.tap(find.text('+30s'));
    await tester.pump();
    expect(find.textContaining('2:00'), findsOneWidget);
    await tester.tap(find.text('Bỏ qua'));
    await tester.pump();
    expect(find.byKey(const Key('rest-timer')), findsNothing);
    expect(workoutRepository.logged, [(40.0, 10)]);
  });

  testWidgets('keeps a set visible when synchronization fails', (tester) async {
    useMobileViewport(tester);
    final workoutRepository = _FailingWorkoutRepository();
    await tester.pumpWidget(
      NicoGymApp(
        exerciseLoader: loadTestExercises,
        workoutRepository: workoutRepository,
      ),
    );
    await tester.tap(find.text('Bắt đầu buổi tập'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('load-input')),
      400,
      scrollable: find.byType(Scrollable).last,
    );

    await tester.enterText(find.byKey(const Key('load-input')), '40');
    await tester.enterText(find.byKey(const Key('reps-input')), '10');
    await tester.ensureVisible(find.text('Ghi hiệp'));
    await tester.tap(find.text('Ghi hiệp'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -250));
    await tester.pumpAndSettle();

    expect(find.text('40 kg × 10'), findsOneWidget);
    expect(find.text('HIỆP 2'), findsOneWidget);
    expect(
      find.text('Mạng đang gián đoạn, hiệp vẫn được giữ.'),
      findsOneWidget,
    );
  });

  testWidgets('rest timer expires accurately while the app is paused', (
    tester,
  ) async {
    useMobileViewport(tester);
    var now = DateTime(2026, 8, 13, 20);
    await tester.pumpWidget(
      MaterialApp(
        home: WorkoutScreen(
          exercise: testExercises.first,
          now: () => now,
          workoutRepository: _MemoryWorkoutRepository(),
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('Ghi hiệp'),
      400,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Ghi hiệp'));
    await tester.pump();
    expect(find.byKey(const Key('rest-timer')), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = now.add(const Duration(seconds: 91));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(find.byKey(const Key('rest-timer')), findsNothing);
  });

  testWidgets('retries pending sets after synchronization recovers', (
    tester,
  ) async {
    useMobileViewport(tester);
    final workoutRepository = _RecoveringWorkoutRepository();
    await tester.pumpWidget(
      NicoGymApp(
        exerciseLoader: loadTestExercises,
        workoutRepository: workoutRepository,
      ),
    );
    await tester.tap(find.text('Bắt đầu buổi tập'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('load-input')),
      400,
      scrollable: find.byType(Scrollable).last,
    );

    await tester.tap(find.text('Ghi hiệp'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Ghi hiệp'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Ghi hiệp'));
    await tester.pumpAndSettle();

    expect(workoutRepository.logged, [(40.0, 10), (40.0, 10)]);
    expect(
      workoutRepository.attemptOperationIds[0],
      workoutRepository.attemptOperationIds[1],
    );
    expect(
      workoutRepository.attemptOperationIds[1],
      isNot(workoutRepository.attemptOperationIds[2]),
    );
    expect(find.text('Đã đồng bộ hiệp 2'), findsOneWidget);
  });

  testWidgets('retries session creation without losing pending sets', (
    tester,
  ) async {
    useMobileViewport(tester);
    final workoutRepository = _RecoveringSessionRepository();
    await tester.pumpWidget(
      NicoGymApp(
        exerciseLoader: loadTestExercises,
        workoutRepository: workoutRepository,
      ),
    );
    await tester.tap(find.text('Bắt đầu buổi tập'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('load-input')),
      400,
      scrollable: find.byType(Scrollable).last,
    );

    await tester.tap(find.text('Ghi hiệp'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Ghi hiệp'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Ghi hiệp'));
    await tester.pumpAndSettle();

    expect(workoutRepository.startAttempts, 2);
    expect(workoutRepository.startOperationIds.toSet(), hasLength(1));
    expect(workoutRepository.logged, [(40.0, 10), (40.0, 10)]);
  });

  testWidgets('opens the Romanian deadlift guide from the workout list', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final workoutRepository = _MemoryWorkoutRepository();
    await tester.pumpWidget(
      NicoGymApp(
        exerciseLoader: loadTestExercises,
        workoutRepository: workoutRepository,
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
    await tester.pump();
    await tester.tap(find.text('Romanian deadlift'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('CÁCH THỰC HIỆN'), findsOneWidget);
    expect(find.text('Hông lùi, không ngồi xổm'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Xem video mẫu'),
      350,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Xem video mẫu'), findsOneWidget);
    expect(find.text('Nguồn: ACE Exercise Library'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('load-input')),
      350,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.ensureVisible(find.text('Ghi hiệp'));
    await tester.tap(find.text('Ghi hiệp'));
    await tester.pumpAndSettle();
    expect(workoutRepository.startedSlugs, contains('romanian-deadlift'));
  });

  testWidgets('can go back or retry when the exercise library fails', (
    tester,
  ) async {
    useMobileViewport(tester);
    var attempts = 0;
    Future<List<Exercise>> flakyLoader() async {
      attempts += 1;
      if (attempts <= 2) throw Exception('fixture load failed');
      return testExercises;
    }

    await tester.pumpWidget(NicoGymApp(exerciseLoader: flakyLoader));
    await tester.tap(find.text('Bắt đầu buổi tập'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byTooltip('Back'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Leg press'), findsOneWidget);
  });

  testWidgets('requires confirmation before applying a suggestion', (
    tester,
  ) async {
    useMobileViewport(tester);
    await tester.pumpWidget(const NicoGymApp(showRecoverySuggestion: true));

    expect(find.text('Lịch hiện tại vẫn được giữ'), findsOneWidget);
    await tester.tap(find.text('Xem gợi ý'));
    await tester.pumpAndSettle();

    expect(find.text('Đổi sang Ngực + Vai?'), findsOneWidget);
    expect(find.text('Giữ lịch chân'), findsOneWidget);
    expect(find.text('Xác nhận đổi'), findsOneWidget);
  });
}

class _MemoryWorkoutRepository implements WorkoutRepository {
  final List<(double, int)> logged = [];
  final List<String> startedSlugs = [];

  @override
  Future<String> startExercise(
    String exerciseSlug, {
    required String operationId,
  }) async {
    startedSlugs.add(exerciseSlug);
    return 'workout-exercise-1';
  }

  @override
  Future<void> logSet({
    required String workoutExerciseId,
    required String operationId,
    required double loadKg,
    required int repetitions,
  }) async => logged.add((loadKg, repetitions));
}

class _FailingWorkoutRepository implements WorkoutRepository {
  @override
  Future<String> startExercise(
    String exerciseSlug, {
    required String operationId,
  }) async => 'workout-exercise-1';

  @override
  Future<void> logSet({
    required String workoutExerciseId,
    required String operationId,
    required double loadKg,
    required int repetitions,
  }) async {
    throw const WorkoutSyncException('Mạng đang gián đoạn, hiệp vẫn được giữ.');
  }
}

class _RecoveringWorkoutRepository implements WorkoutRepository {
  final List<(double, int)> logged = [];
  final List<String> attemptOperationIds = [];
  var attempts = 0;

  @override
  Future<String> startExercise(
    String exerciseSlug, {
    required String operationId,
  }) async => 'workout-exercise-1';

  @override
  Future<void> logSet({
    required String workoutExerciseId,
    required String operationId,
    required double loadKg,
    required int repetitions,
  }) async {
    attempts += 1;
    attemptOperationIds.add(operationId);
    if (attempts == 1) {
      throw const WorkoutSyncException('Mạng đang gián đoạn.');
    }
    logged.add((loadKg, repetitions));
  }
}

class _RecoveringSessionRepository implements WorkoutRepository {
  final List<(double, int)> logged = [];
  final List<String> startOperationIds = [];
  var startAttempts = 0;

  @override
  Future<String> startExercise(
    String exerciseSlug, {
    required String operationId,
  }) async {
    startAttempts += 1;
    startOperationIds.add(operationId);
    if (startAttempts == 1) {
      throw const WorkoutSyncException('Mạng đang gián đoạn.');
    }
    return 'workout-exercise-1';
  }

  @override
  Future<void> logSet({
    required String workoutExerciseId,
    required String operationId,
    required double loadKg,
    required int repetitions,
  }) async => logged.add((loadKg, repetitions));
}
