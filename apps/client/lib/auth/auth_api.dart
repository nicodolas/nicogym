import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

const minAuthPasswordLength = 12;
const authPasswordRequirementMessage =
    'Mật khẩu cần có ít nhất $minAuthPasswordLength ký tự.';

abstract interface class TokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

abstract interface class UserScopedTokenStore implements TokenStore {
  Future<void> writeForUser(String token, String userId);
}

class SecureTokenStore implements UserScopedTokenStore {
  SecureTokenStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _tokenKey = 'better_auth_session';
  static const _plannerCacheKey = 'planner_state_v1';
  static const _userIdKey = 'better_auth_user_id';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: _tokenKey);

  @override
  Future<void> write(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  @override
  Future<void> writeForUser(String token, String userId) async {
    final previousUserId = await _storage.read(key: _userIdKey);
    if (previousUserId != userId) {
      await _storage.delete(key: _plannerCacheKey);
    }
    await _storage.write(key: _userIdKey, value: userId);
    await write(token);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userIdKey);
    await _storage.delete(key: _plannerCacheKey);
  }
}

class AuthUser {
  const AuthUser({required this.id, required this.email});

  final String id;
  final String email;
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthApi {
  AuthApi({
    required this.baseUrl,
    required this.tokenStore,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final Uri baseUrl;
  final TokenStore tokenStore;
  final http.Client _client;

  Future<AuthUser> signIn({required String email, required String password}) {
    return _authenticate(
      path: '/api/auth/sign-in/email',
      body: {'email': email.trim(), 'password': password},
      registering: false,
    );
  }

  Future<AuthUser> signUp({
    required String name,
    required String email,
    required String password,
  }) {
    return _authenticate(
      path: '/api/auth/sign-up/email',
      body: {'name': name.trim(), 'email': email.trim(), 'password': password},
      registering: true,
    );
  }

  Future<AuthUser> _authenticate({
    required String path,
    required Map<String, String> body,
    required bool registering,
  }) async {
    http.Response response;
    try {
      response = await _client
          .post(
            baseUrl.resolve(path),
            headers: const {'content-type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 12));
    } on TimeoutException {
      throw const AuthException('Máy chủ phản hồi quá chậm. Hãy thử lại.');
    } on http.ClientException {
      throw const AuthException('Không kết nối được máy chủ.');
    } on Exception {
      throw const AuthException('Không thể thiết lập kết nối an toàn.');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(_errorMessage(response, registering: registering));
    }

    final dynamic payload;
    try {
      payload = jsonDecode(response.body);
    } on FormatException {
      throw const AuthException('Máy chủ trả về dữ liệu không hợp lệ.');
    }

    if (payload is! Map<String, dynamic>) {
      throw const AuthException('Máy chủ trả về dữ liệu không hợp lệ.');
    }
    final user = payload['user'];
    if (user is! Map<String, dynamic> ||
        user['id'] is! String ||
        user['email'] is! String) {
      throw const AuthException('Máy chủ trả về dữ liệu không hợp lệ.');
    }

    final userId = user['id'] as String;
    final token = response.headers['set-auth-token'];
    if (token != null && token.isNotEmpty) {
      if (tokenStore case final UserScopedTokenStore scopedStore) {
        await scopedStore.writeForUser(token, userId);
      } else {
        await tokenStore.write(token);
      }
    }
    return AuthUser(id: userId, email: user['email'] as String);
  }

  String _errorMessage(http.Response response, {required bool registering}) {
    String? code;
    try {
      final payload = jsonDecode(response.body);
      if (payload is Map<String, dynamic> && payload['code'] is String) {
        code = payload['code'] as String;
      }
    } on FormatException {
      // Never expose untrusted server text to the member.
    }

    switch (code) {
      case 'PASSWORD_TOO_SHORT':
        return authPasswordRequirementMessage;
      case 'USER_ALREADY_EXISTS':
      case 'USER_ALREADY_EXISTS_USE_ANOTHER_EMAIL':
        return 'Email này đã có tài khoản. Hãy đăng nhập.';
      case 'INVALID_EMAIL':
      case 'INVALID_EMAIL_OR_PASSWORD':
        return registering
            ? 'Email chưa đúng định dạng.'
            : 'Email hoặc mật khẩu chưa đúng.';
      case 'INVALID_PASSWORD':
        return registering
            ? 'Mật khẩu chưa hợp lệ. Hãy thử mật khẩu khác.'
            : 'Email hoặc mật khẩu chưa đúng.';
    }

    if (response.statusCode == 429) {
      return 'Bạn thao tác quá nhanh. Vui lòng chờ một phút rồi thử lại.';
    }
    if (response.statusCode >= 500) {
      return 'Máy chủ đang bận. Hãy thử lại sau ít phút.';
    }
    return registering
        ? 'Chưa thể tạo tài khoản. Kiểm tra thông tin rồi thử lại.'
        : 'Email hoặc mật khẩu chưa đúng.';
  }
}
