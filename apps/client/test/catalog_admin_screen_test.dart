import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nicogym/admin/catalog_api.dart';
import 'package:nicogym/member/member_hub.dart';
import 'package:nicogym/workouts/exercise.dart';

void main() {
  testWidgets('shows admin import only for a persisted admin role', (
    tester,
  ) async {
    final repository = _FakeCatalogRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: MemberHubScreen(
          exerciseLoader: () async => const <Exercise>[],
          onOpenExercise: (_) {},
          catalogRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Quản trị'), findsOneWidget);
    await tester.tap(find.text('Quản trị'));
    await tester.pumpAndSettle();

    expect(find.text('QUẢN LÝ BÀI TẬP'), findsOneWidget);
    expect(find.byKey(const Key('exercise-json-input')), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kiểm tra JSON'));
    await tester.pumpAndSettle();

    expect(find.text('BẢN XEM TRƯỚC'), findsOneWidget);
    expect(find.text('1 bài mới · 0 bài cập nhật'), findsOneWidget);
    await tester.ensureVisible(find.text('Xác nhận cập nhật danh mục'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xác nhận cập nhật danh mục'));
    await tester.pumpAndSettle();
    expect(repository.appliedToken, 'signed-preview-token');
  });

  testWidgets('context help explains the next action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MemberHubScreen(
          exerciseLoader: () async => const <Exercise>[],
          onOpenExercise: (_) {},
        ),
      ),
    );
    await tester.tap(find.byTooltip('Hướng dẫn'));
    await tester.pumpAndSettle();
    expect(find.text('Không gian của bạn'), findsOneWidget);
    expect(
      find.textContaining('lịch đã xếp luôn được ưu tiên'),
      findsOneWidget,
    );
  });

}

class _FakeCatalogRepository implements CatalogRepository {
  String? appliedToken;

  @override
  Future<void> apply(String previewToken) async => appliedToken = previewToken;

  @override
  Future<List<Exercise>> loadExercises() async => const [];

  @override
  Future<MemberIdentity> me() async =>
      const MemberIdentity(id: 'admin-1', role: 'admin');

  @override
  Future<ImportPreview> preview(String jsonText, String mode) async =>
      const ImportPreview(
        token: 'signed-preview-token',
        creates: 1,
        updates: 0,
      );
}
