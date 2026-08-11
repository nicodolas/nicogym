import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nicogym/auth/auth_api.dart';

class MemoryTokenStore implements TokenStore {
  String? value;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String token) async => value = token;
}

void main() {
  test(
    'sign in stores the mobile bearer token returned by Better Auth',
    () async {
      final tokenStore = MemoryTokenStore();
      final api = AuthApi(
        baseUrl: Uri.parse('https://api.example.com'),
        tokenStore: tokenStore,
        client: MockClient((request) async {
          expect(request.url.path, '/api/auth/sign-in/email');
          return http.Response(
            '{"user":{"id":"user-1","email":"nico@example.com"}}',
            200,
            headers: {'set-auth-token': 'signed-session-token'},
          );
        }),
      );

      final user = await api.signIn(
        email: 'nico@example.com',
        password: 'safe-password',
      );

      expect(user.email, 'nico@example.com');
      expect(await tokenStore.read(), 'signed-session-token');
    },
  );

  test('sign in surfaces a safe message for invalid credentials', () async {
    final api = AuthApi(
      baseUrl: Uri.parse('https://api.example.com'),
      tokenStore: MemoryTokenStore(),
      client: MockClient((_) async => http.Response('{"message":"bad"}', 401)),
    );

    await expectLater(
      api.signIn(email: 'nico@example.com', password: 'wrong-password'),
      throwsA(
        isA<AuthException>().having(
          (error) => error.message,
          'message',
          'Email hoặc mật khẩu chưa đúng.',
        ),
      ),
    );
  });

  test('sign up explains Better Auth password requirements', () async {
    final api = AuthApi(
      baseUrl: Uri.parse('https://api.example.com'),
      tokenStore: MemoryTokenStore(),
      client: MockClient(
        (_) async => http.Response(
          '{"message":"Password too short","code":"PASSWORD_TOO_SHORT"}',
          400,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );

    await expectLater(
      api.signUp(
        name: 'Nico',
        email: 'nico@example.com',
        password: 'too-short',
      ),
      throwsA(
        isA<AuthException>().having(
          (error) => error.message,
          'message',
          'Mật khẩu cần có ít nhất 12 ký tự.',
        ),
      ),
    );
  });

  test('sign up explains when an email is already registered', () async {
    final api = AuthApi(
      baseUrl: Uri.parse('https://api.example.com'),
      tokenStore: MemoryTokenStore(),
      client: MockClient(
        (_) async => http.Response(
          '{"code":"USER_ALREADY_EXISTS_USE_ANOTHER_EMAIL"}',
          422,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );

    await expectLater(
      api.signUp(
        name: 'Nico',
        email: 'nico@example.com',
        password: 'long-enough-password',
      ),
      throwsA(
        isA<AuthException>().having(
          (error) => error.message,
          'message',
          'Email này đã có tài khoản. Hãy đăng nhập.',
        ),
      ),
    );
  });

  test('sign in converts malformed success payloads to a safe error', () async {
    final tokenStore = MemoryTokenStore();
    final api = AuthApi(
      baseUrl: Uri.parse('https://api.example.com'),
      tokenStore: tokenStore,
      client: MockClient(
        (_) async => http.Response(
          '{not-json',
          200,
          headers: {'set-auth-token': 'must-not-be-stored'},
        ),
      ),
    );

    await expectLater(
      api.signIn(email: 'nico@example.com', password: 'password'),
      throwsA(
        isA<AuthException>().having(
          (error) => error.message,
          'message',
          'Máy chủ trả về dữ liệu không hợp lệ.',
        ),
      ),
    );
    expect(await tokenStore.read(), isNull);
  });
}
