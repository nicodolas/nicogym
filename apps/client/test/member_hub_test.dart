import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nicogym/member/member_hub.dart';
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
    await tester.tap(find.text('Xác nhận đổi'));
    await tester.pump();

    final todayCard = find.byKey(const Key('today-workout-card'));
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

    await tester.tap(find.text('Giữ lịch cũ'));
    await tester.pump();

    expect(find.text('Chân + Mông'), findsWidgets);
    expect(find.text('Đổi sang Ngực + Tay sau?'), findsNothing);
  });
}
