import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

abstract interface class TokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

class SecureTokenStore implements TokenStore {
  SecureTokenStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _tokenKey = 'better_auth_session';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: _tokenKey);

  @override
  Future<void> write(String token) =>
      _storage.write(key: _tokenKey, value: token);

  @override
  Future<void> clear() => _storage.delete(key: _tokenKey);
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
    );
  }

  Future<AuthUser> _authenticate({
    required String path,
    required Map<String, String> body,
  }) async {
    http.Response response;
    try {
      response = await _client.post(
        baseUrl.resolve(path),
        headers: const {'content-type': 'application/json'},
        body: jsonEncode(body),
      );
    } on http.ClientException {
      throw const AuthException('Không kết nối được máy chủ.');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const AuthException('Email hoặc mật khẩu chưa đúng.');
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

    final token = response.headers['set-auth-token'];
    if (token != null && token.isNotEmpty) await tokenStore.write(token);
    return AuthUser(id: user['id'] as String, email: user['email'] as String);
  }
}
