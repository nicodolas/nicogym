import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nicogym/app.dart';

void main() {
  void useMobileViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('shows today workout and recovery status', (tester) async {
    useMobileViewport(tester);
    await tester.pumpWidget(const NicoGymApp());

    expect(find.text('HÔM NAY'), findsOneWidget);
    expect(find.text('CHÂN + MÔNG'), findsOneWidget);
    expect(find.text('3/5 nhóm cơ sẵn sàng'), findsOneWidget);
    expect(find.text('Bắt đầu buổi tập'), findsOneWidget);
  });

  testWidgets('opens workout mode and logs a set quickly', (tester) async {
    useMobileViewport(tester);
    await tester.pumpWidget(const NicoGymApp());
    await tester.tap(find.text('Bắt đầu buổi tập'));
    await tester.pumpAndSettle();

    expect(find.text('Leg press'), findsOneWidget);
    expect(find.text('HIỆP 1'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('load-input')), '40');
    await tester.enterText(find.byKey(const Key('reps-input')), '10');
    await tester.tap(find.text('Ghi hiệp'));
    await tester.pump();

    expect(find.text('40 kg × 10'), findsOneWidget);
    expect(find.text('HIỆP 2'), findsOneWidget);
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
}
