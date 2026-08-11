import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nicogym/auth/auth_api.dart';
import 'package:nicogym/auth/auth_screen.dart';

class _MemoryTokenStore implements TokenStore {
  @override
  Future<void> clear() async {}

  @override
  Future<String?> read() async => null;

  @override
  Future<void> write(String token) async {}
}

Widget _app(http.Client client) => MaterialApp(
  home: AuthScreen(
    authApi: AuthApi(
      baseUrl: Uri.parse('https://api.example.com'),
      tokenStore: _MemoryTokenStore(),
      client: client,
    ),
  ),
);

void main() {
  testWidgets('registration blocks passwords shorter than server minimum', (
    tester,
  ) async {
    var requests = 0;
    await tester.pumpWidget(
      _app(
        MockClient((_) async {
          requests += 1;
          return http.Response('{}', 500);
        }),
      ),
    );

    await tester.tap(find.text('Tạo tài khoản'));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('auth-name')), 'Nico');
    await tester.enterText(
      find.byKey(const Key('auth-email')),
      'nico@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('auth-password')),
      '1234567890',
    );
    await tester.enterText(
      find.byKey(const Key('auth-confirm-password')),
      '1234567890',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(find.text('Mật khẩu cần có ít nhất 12 ký tự.'), findsOneWidget);
    expect(requests, 0);
  });

  testWidgets('registration surfaces a useful duplicate-email message', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        MockClient(
          (_) async => http.Response(
            '{"code":"USER_ALREADY_EXISTS_USE_ANOTHER_EMAIL"}',
            422,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Tạo tài khoản'));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('auth-name')), 'Nico');
    await tester.enterText(
      find.byKey(const Key('auth-email')),
      'nico@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('auth-password')),
      'long-enough-password',
    );
    await tester.enterText(
      find.byKey(const Key('auth-confirm-password')),
      'long-enough-password',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(
      find.text('Email này đã có tài khoản. Hãy đăng nhập.'),
      findsOneWidget,
    );
  });
}
