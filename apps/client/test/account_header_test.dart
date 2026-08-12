import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nicogym/app.dart';
import 'package:nicogym/auth/auth_api.dart';
import 'package:nicogym/workouts/exercise.dart';

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
  ];

  Future<List<Exercise>> loadTestExercises() async => testExercises;

  void useMobileViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

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
    await tester.pumpWidget(
      NicoGymApp(memberTokenStore: _TestTokenStore(null)),
    );
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

  testWidgets('waits for a delayed persisted session before account routing', (
    tester,
  ) async {
    useMobileViewport(tester);
    final tokenStore = _DelayedTokenStore('persisted-session-token');
    await tester.pumpWidget(NicoGymApp(memberTokenStore: tokenStore));

    await tester.tap(find.byTooltip('Tài khoản'));
    await tester.pump();
    expect(find.text('ĐĂNG NHẬP'), findsNothing);

    tokenStore.completeReads();
    await tester.pumpAndSettle();

    expect(tokenStore.readCount, 1);
    expect(find.text('ĐÃ ĐĂNG NHẬP'), findsOneWidget);
    expect(find.text('ĐĂNG NHẬP'), findsNothing);
  });

  testWidgets('coalesces rapid account taps into one navigation', (
    tester,
  ) async {
    useMobileViewport(tester);
    final tokenStore = _DelayedTokenStore(null);
    await tester.pumpWidget(NicoGymApp(memberTokenStore: tokenStore));

    await tester.tap(find.byTooltip('Tài khoản'));
    await tester.tap(find.byTooltip('Tài khoản'));
    tokenStore.completeReads();
    await tester.pumpAndSettle();

    expect(find.text('ĐĂNG NHẬP'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('ĐĂNG NHẬP'), findsNothing);
    expect(find.text('HÔM NAY'), findsOneWidget);
  });

  testWidgets('secure storage read failures degrade to signed out', (
    tester,
  ) async {
    useMobileViewport(tester);
    await tester.pumpWidget(
      NicoGymApp(memberTokenStore: _ThrowingTokenStore()),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byTooltip('Tài khoản'), findsOneWidget);
  });

  testWidgets('member navigation handles secure storage read failures', (
    tester,
  ) async {
    useMobileViewport(tester);
    await tester.pumpWidget(
      NicoGymApp(memberTokenStore: _ThrowingTokenStore()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Thư viện và lịch tập'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('ĐĂNG NHẬP'), findsOneWidget);
  });

  testWidgets('opens the full member library for a signed-in user', (
    tester,
  ) async {
    useMobileViewport(tester);
    await tester.pumpWidget(
      NicoGymApp(
        exerciseLoader: loadTestExercises,
        memberTokenStore: _TestTokenStore('signed-in'),
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

class _DelayedTokenStore implements TokenStore {
  _DelayedTokenStore(this.token);

  String? token;
  final List<Completer<String?>> _reads = [];
  int get readCount => _reads.length;

  @override
  Future<void> clear() async => token = null;

  @override
  Future<String?> read() {
    final completer = Completer<String?>();
    _reads.add(completer);
    return completer.future;
  }

  void completeReads() {
    for (final read in _reads) {
      if (!read.isCompleted) read.complete(token);
    }
  }

  @override
  Future<void> write(String value) async => token = value;
}

class _ThrowingTokenStore implements TokenStore {
  @override
  Future<void> clear() async {}

  @override
  Future<String?> read() => Future<String?>.error(StateError('unavailable'));

  @override
  Future<void> write(String value) async {}
}
