import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nicogym/member/member_hub.dart';
import 'package:nicogym/workouts/exercise.dart';

void main() {
  const exercise = Exercise(
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

  testWidgets('filters the signed-in exercise library by body area', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MemberHubScreen(
          exerciseLoader: () async => const [exercise],
          onOpenExercise: (_) {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('TOÀN THÂN'), findsOneWidget);
    expect(find.text('Ngực'), findsWidgets);
    expect(find.text('Chest press'), findsOneWidget);
  });

  testWidgets('keeps the schedule until a recovery suggestion is confirmed', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MemberHubScreen(
          exerciseLoader: () async => const [exercise],
          onOpenExercise: (_) {},
          initialTab: 1,
        ),
      ),
    );

    expect(find.text('Chân + Mông'), findsWidgets);
    expect(find.text('Đổi sang Ngực + Tay sau?'), findsOneWidget);
    await tester.tap(find.text('Xác nhận đổi'));
    await tester.pump();

    expect(find.text('Ngực + Tay sau'), findsWidgets);
    expect(find.text('Đổi sang Ngực + Tay sau?'), findsNothing);
  });
}
