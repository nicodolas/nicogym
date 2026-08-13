import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nicogym/member/member_hub.dart';
import 'package:nicogym/member/planner_api.dart';
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
