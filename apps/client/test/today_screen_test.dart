import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nicogym/app.dart';
import 'package:nicogym/auth/auth_api.dart';
import 'package:nicogym/workouts/exercise.dart';

void main() {
  final signedInTokenStore = _TestTokenStore('signed-in');
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
    await tester.pumpWidget(NicoGymApp(exerciseLoader: loadTestExercises));
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
    await tester.pump();

    expect(find.text('40 kg × 10'), findsOneWidget);
    expect(find.text('HIỆP 2'), findsOneWidget);
  });

  testWidgets('opens the Romanian deadlift guide from the workout list', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(NicoGymApp(exerciseLoader: loadTestExercises));
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

  testWidgets('shows the configured APK download action', (tester) async {
    useMobileViewport(tester);
    await tester.pumpWidget(
      const NicoGymApp(apkDownloadUrl: 'https://example.com/nicogym.apk'),
    );

    expect(find.byTooltip('Tải Android'), findsOneWidget);
  });

  testWidgets('opens login and registration from the account action', (
    tester,
  ) async {
    useMobileViewport(tester);
    await tester.pumpWidget(const NicoGymApp());
    await tester.tap(find.byTooltip('Tài khoản'));
    await tester.pumpAndSettle();

    expect(find.text('ĐĂNG NHẬP'), findsOneWidget);
    await tester.tap(find.text('Tạo tài khoản'));
    await tester.pump();

    expect(find.text('TẠO TÀI KHOẢN'), findsOneWidget);
  });

  testWidgets('shows account status instead of login when signed in', (
    tester,
  ) async {
    useMobileViewport(tester);
    final tokenStore = _TestTokenStore('signed-session-token');
    await tester.pumpWidget(NicoGymApp(memberTokenStore: tokenStore));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Đã đăng nhập'), findsOneWidget);
    await tester.tap(find.byTooltip('Đã đăng nhập'));
    await tester.pumpAndSettle();

    expect(find.text('ĐÃ ĐĂNG NHẬP'), findsOneWidget);
    expect(find.text('Đăng nhập lại'), findsNothing);

    await tester.tap(find.text('Đăng xuất'));
    await tester.pumpAndSettle();

    expect(tokenStore.token, isNull);
    expect(find.byTooltip('Tài khoản'), findsOneWidget);
  });

  testWidgets('opens the full member library for a signed-in user', (
    tester,
  ) async {
    useMobileViewport(tester);
    await tester.pumpWidget(
      NicoGymApp(
        exerciseLoader: loadTestExercises,
        memberTokenStore: signedInTokenStore,
      ),
    );

    await tester.tap(find.byTooltip('Thư viện và lịch tập'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('KHÔNG GIAN CỦA BẠN'), findsOneWidget);
    expect(find.text('TOÀN THÂN'), findsOneWidget);
  });
}

class _TestTokenStore implements TokenStore {
  _TestTokenStore(this.token);

  String? token;

  @override
  Future<void> clear() async => token = null;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String value) async => token = value;
}
