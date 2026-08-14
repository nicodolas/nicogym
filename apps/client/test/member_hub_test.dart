import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nicogym/member/member_hub.dart';
import 'package:nicogym/member/planner_api.dart';
import 'package:nicogym/member/progress_api.dart';
import 'package:nicogym/workouts/exercise.dart';

void main() {
  const chestExercise = Exercise(
    id: 'chest-press',
    name: 'Chest press',
    prescription: '3 × 10',
    primaryMuscles: ['Ngực'],
    equipment: 'Máy',
    summary: 'Đẩy tay cầm.',
    setup: ['Chỉnh ghế.'],
    steps: ['Đẩy có kiểm soát.'],
    cues: ['Vai hạ'],
    mistakes: ['Nhún vai'],
    safety: 'Dừng nếu đau.',
    sourceLabel: 'ACE',
    sourceUrl: 'https://example.com',
    videoUrl: 'https://example.com',
    category: 'Ngực',
  );

  const legExercise = Exercise(
    id: 'leg-press',
    name: 'Leg press',
    prescription: '3 × 10',
    primaryMuscles: ['Đùi trước'],
    equipment: 'Máy',
    summary: 'Đẩy bàn máy.',
    setup: ['Đặt chân.'],
    steps: ['Đẩy có kiểm soát.'],
    cues: ['Gối theo hướng mũi chân'],
    mistakes: ['Khóa gối'],
    safety: 'Dừng nếu đau.',
    sourceLabel: 'ACE',
    sourceUrl: 'https://example.com',
    videoUrl: 'https://example.com',
    category: 'Chân & Mông',
  );

  testWidgets('filters the signed-in exercise library by body area', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MemberHubScreen(
          exerciseLoader: () async => const [chestExercise, legExercise],
          onOpenExercise: (_) {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('TOÀN THÂN'), findsOneWidget);
    expect(find.text('Ngực'), findsWidgets);
    expect(find.text('Chest press'), findsOneWidget);
    expect(find.text('Leg press'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Ngực'));
    await tester.pump();

    expect(find.text('Chest press'), findsOneWidget);
    expect(find.text('Leg press'), findsNothing);
  });

  testWidgets('keeps the schedule until a recovery suggestion is confirmed', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MemberHubScreen(
          exerciseLoader: () async => const [chestExercise],
          onOpenExercise: (_) {},
          initialTab: 1,
        ),
      ),
    );

    expect(find.text('Chân + Mông'), findsWidgets);
    expect(find.text('Đổi sang Ngực + Tay sau?'), findsOneWidget);
    expect(
      find.textContaining('Chưa có lịch sử tập, tạm dùng mặc định'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Đổi sang Ngực + Tay sau'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đổi sang Ngực + Tay sau'));
    await tester.pump();

    final todayCard = find.byKey(const Key('today-workout-card'));
    await tester.drag(find.byType(ListView), const Offset(0, 300));
    await tester.pump();
    expect(
      find.descendant(of: todayCard, matching: find.text('Chân + Mông')),
      findsNothing,
    );
    expect(
      find.descendant(of: todayCard, matching: find.text('Ngực + Tay sau')),
      findsOneWidget,
    );
    expect(find.text('Đổi sang Ngực + Tay sau?'), findsNothing);
  });

  testWidgets('dismisses the suggestion when keeping the old schedule', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MemberHubScreen(
          exerciseLoader: () async => const [chestExercise],
          onOpenExercise: (_) {},
          initialTab: 1,
        ),
      ),
    );

    await tester.ensureVisible(find.text('Giữ lịch hôm nay'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Giữ lịch hôm nay'));
    await tester.pump();

    expect(find.text('Chân + Mông'), findsWidgets);
    expect(find.text('Đổi sang Ngực + Tay sau?'), findsNothing);
  });

  testWidgets('loads and saves the signed-in planner through its repository', (
    tester,
  ) async {
    final repository = _MemoryPlannerRepository(
      const PlannerState(
        weeklySchedule: [PlannedSession(day: 2, title: 'Vai + Core')],
        recoveryHours: 72,
        todayWorkout: 'Chân + Mông',
        suggestionAccepted: false,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MemberHubScreen(
          exerciseLoader: () async => const [chestExercise],
          onOpenExercise: (_) {},
          initialTab: 1,
          plannerRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Đổi sang Vai + Core'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đổi sang Vai + Core'));
    await tester.pumpAndSettle();
    expect(repository.saved?.todayWorkout, 'Vai + Core');
    expect(repository.saved?.recoveryHours, 72);

    await tester.scrollUntilVisible(find.text('Vai + Core').last, 300);
    expect(find.text('Vai + Core'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('72 giờ trước khi tập lại cùng nhóm cơ'),
      300,
    );
    expect(find.text('72 giờ trước khi tập lại cùng nhóm cơ'), findsOneWidget);
  });

  testWidgets('creates an editable starter plan for a new member', (
    tester,
  ) async {
    final repository = _MemoryPlannerRepository(null);
    await tester.pumpWidget(
      MaterialApp(
        home: MemberHubScreen(
          exerciseLoader: () async => const [chestExercise],
          onOpenExercise: (_) {},
          initialTab: 1,
          plannerRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('planner-onboarding')), findsOneWidget);
    await tester.tap(find.text('Khỏe hơn'));
    await tester.tap(find.text('4 buổi'));
    await tester.ensureVisible(find.text('60 phút'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('60 phút'));
    await tester.ensureVisible(find.byKey(const Key('create-sample-plan')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create-sample-plan')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('planner-onboarding')), findsNothing);
    expect(repository.saved?.weeklySchedule, hasLength(4));
    expect(
      repository.saved!.weeklySchedule.map((session) => session.title),
      contains(repository.saved?.todayWorkout),
    );
    expect(repository.saved?.goal, 'general_fitness');
    expect(repository.saved?.sessionMinutes, 60);
    expect(find.text('60 phút · 5 bài · 15 hiệp'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('schedule-1')),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const Key('schedule-1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Toàn thân B');
    await tester.tap(find.text('Lưu'));
    await tester.pump();
    expect(find.text('Tên buổi tập đã tồn tại.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'Buổi toàn thân mới');
    await tester.pump();
    expect(find.text('Tên buổi tập đã tồn tại.'), findsNothing);
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();

    expect(repository.saved?.weeklySchedule.first.title, 'Buổi toàn thân mới');
  });

  testWidgets('submits the latest planner snapshot while a save is pending', (
    tester,
  ) async {
    final repository = _DelayedPlannerRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: MemberHubScreen(
          exerciseLoader: () async => const [chestExercise],
          onOpenExercise: (_) {},
          initialTab: 1,
          plannerRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.byType(Slider), 300);
    final slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged!(60);
    slider.onChangeEnd!(60);
    slider.onChanged!(72);
    slider.onChangeEnd!(72);
    await tester.pump();

    expect(repository.saved, hasLength(2));
    expect(repository.saved.first.recoveryHours, 60);
    expect(repository.saved.last.recoveryHours, 72);

    repository.completeAll();
    await tester.pumpAndSettle();
  });

  testWidgets('shows synchronized workout progress and recent sets', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MemberHubScreen(
          exerciseLoader: () async => const [chestExercise],
          onOpenExercise: (_) {},
          initialTab: 2,
          progressRepository: _MemoryProgressRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('TIẾN ĐỘ'), findsOneWidget);
    final progress = find.byKey(const Key('progress-view'));
    expect(
      find.descendant(of: progress, matching: find.text('2')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: progress, matching: find.text('6')),
      findsOneWidget,
    );
    expect(find.text('2400.4 kg'), findsOneWidget);
    expect(find.text('Leg press'), findsOneWidget);
    expect(find.text('40.125 kg × 10'), findsOneWidget);
  });

  testWidgets('loads progress only after its tab is opened', (tester) async {
    final repository = _CountingProgressRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: MemberHubScreen(
          exerciseLoader: () async => const [chestExercise],
          onOpenExercise: (_) {},
          progressRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.loads, 0);
    await tester.tap(find.text('Tiến độ'));
    await tester.pumpAndSettle();
    expect(repository.loads, 1);

    await tester.tap(find.text('Thư viện'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tiến độ'));
    await tester.pumpAndSettle();
    expect(repository.loads, 2);
  });

  testWidgets('explains how to begin when progress is empty', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MemberHubScreen(
          exerciseLoader: () async => const [chestExercise],
          onOpenExercise: (_) {},
          initialTab: 2,
          progressRepository: _EmptyProgressRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Ghi hiệp đầu tiên để bắt đầu theo dõi tiến độ.'),
      findsOneWidget,
    );
  });

  testWidgets('shows a useful progress error and retry action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MemberHubScreen(
          exerciseLoader: () async => const [chestExercise],
          onOpenExercise: (_) {},
          initialTab: 2,
          progressRepository: _FailingProgressRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Phiên đăng nhập đã hết hạn.'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
    expect(find.byType(RefreshIndicator), findsOneWidget);
    expect(
      tester
          .widget<ListView>(find.byKey(const Key('progress-error-view')))
          .physics,
      isA<AlwaysScrollableScrollPhysics>(),
    );
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Phiên đăng nhập đã hết hạn.'), findsOneWidget);
  });
}

class _MemoryProgressRepository implements ProgressRepository {
  @override
  Future<ProgressSummary> load() async => ProgressSummary(
    sessions: 2,
    sets: 6,
    volumeKg: 2400.4,
    latest: [
      ProgressEntry(
        exerciseSlug: 'leg-press',
        exerciseName: 'Leg press',
        loadKg: 40.125,
        repetitions: 10,
        completedAt: DateTime(2026, 8, 13),
      ),
    ],
  );
}

class _CountingProgressRepository implements ProgressRepository {
  int loads = 0;

  @override
  Future<ProgressSummary> load() async {
    loads += 1;
    return const ProgressSummary(sessions: 0, sets: 0, volumeKg: 0, latest: []);
  }
}

class _EmptyProgressRepository implements ProgressRepository {
  @override
  Future<ProgressSummary> load() async =>
      const ProgressSummary(sessions: 0, sets: 0, volumeKg: 0, latest: []);
}

class _FailingProgressRepository implements ProgressRepository {
  @override
  Future<ProgressSummary> load() async {
    throw const ProgressException('Phiên đăng nhập đã hết hạn.');
  }
}

class _MemoryPlannerRepository implements PlannerRepository {
  _MemoryPlannerRepository(this.initial);

  final PlannerState? initial;
  PlannerState? saved;

  @override
  Future<PlannerLoadResult> load() async => PlannerLoadResult(state: initial);

  @override
  Future<PlannerState> save(PlannerState state) async => saved = state;
}

class _DelayedPlannerRepository implements PlannerRepository {
  final List<PlannerState> saved = [];
  final List<Completer<PlannerState>> _saves = [];

  @override
  Future<PlannerLoadResult> load() async =>
      const PlannerLoadResult(state: PlannerState.defaults);

  @override
  Future<PlannerState> save(PlannerState state) {
    saved.add(state);
    final completion = Completer<PlannerState>();
    _saves.add(completion);
    return completion.future;
  }

  void completeAll() {
    for (var index = 0; index < _saves.length; index++) {
      if (!_saves[index].isCompleted) _saves[index].complete(saved[index]);
    }
  }
}
