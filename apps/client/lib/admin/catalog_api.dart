import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:nicogym/auth/auth_api.dart';
import 'package:nicogym/workouts/exercise.dart';

class MemberIdentity {
  const MemberIdentity({required this.id, required this.role});

  final String id;
  final String role;
  bool get isAdmin => role == 'admin';
}

class ImportPreview {
  const ImportPreview({
    required this.token,
    required this.creates,
    required this.updates,
  });

  final String token;
  final int creates;
  final int updates;
}

abstract interface class CatalogRepository {
  Future<MemberIdentity> me();
  Future<List<Exercise>> loadExercises();
  Future<ImportPreview> preview(String jsonText, String mode);
  Future<void> apply(String previewToken);
}

class CatalogApi implements CatalogRepository {
  CatalogApi({
    required this.baseUrl,
    required this.tokenStore,
    http.Client? client,
    this.requestTimeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client();

  final Uri baseUrl;
  final TokenStore tokenStore;
  final Duration requestTimeout;
  final http.Client _client;
  final Set<Future<void>> _pendingRequests = {};

  @override
  Future<MemberIdentity> me() async {
    final payload = await _get('/api/me');
    final data = payload['data'];
    if (data is! Map<String, dynamic>) throw const FormatException();
    return MemberIdentity(
      id: data['id'] as String,
      role: data['role'] as String,
    );
  }

  @override
  Future<List<Exercise>> loadExercises() async {
    final payload = await _get('/api/exercises');
    final data = payload['data'];
    if (data is! List) throw const FormatException();
    return data
        .map((item) => Exercise.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<ImportPreview> preview(String jsonText, String mode) async {
    final decoded = jsonDecode(jsonText);
    final exercises = decoded is List ? decoded : [decoded];
    final payload = await _post('/api/admin/exercises/import/preview', {
      'mode': mode,
      'exercises': exercises,
    });
    final data = payload['data'] as Map<String, dynamic>;
    final summary = data['summary'] as Map<String, dynamic>;
    return ImportPreview(
      token: data['token'] as String,
      creates: summary['creates'] as int,
      updates: summary['updates'] as int,
    );
  }

  @override
  Future<void> apply(String previewToken) async {
    await _post('/api/admin/exercises/import/apply', {
      'previewToken': previewToken,
    });
  }

  Future<Map<String, dynamic>> _get(String path) => _track(_requestGet(path));

  Future<Map<String, dynamic>> _requestGet(String path) async {
    final headers = await _headers().timeout(requestTimeout);
    final response = await _client
        .get(baseUrl.resolve(path), headers: headers)
        .timeout(requestTimeout);
    return _decode(response);
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) =>
      _track(_requestPost(path, body));

  Future<Map<String, dynamic>> _requestPost(
    String path,
    Map<String, dynamic> body,
  ) async {
    final headers = await _headers(json: true).timeout(requestTimeout);
    final response = await _client
        .post(baseUrl.resolve(path), headers: headers, body: jsonEncode(body))
        .timeout(requestTimeout);
    return _decode(response);
  }

  Future<Map<String, String>> _headers({bool json = false}) async {
    final token = await tokenStore.read();
    if (token == null || token.isEmpty) {
      throw const AuthException('Phiên đăng nhập đã hết hạn.');
    }
    return {
      'authorization': 'Bearer $token',
      if (json) 'content-type': 'application/json',
    };
  }

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic>? payload;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) payload = decoded;
    } on FormatException {
      // Use the safe fallback below.
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final code = payload?['error'];
      throw AuthException(switch (code) {
        'admin_required' => 'Tài khoản này không có quyền quản trị.',
        'exercise_already_exists' => 'Có mã bài tập đã tồn tại.',
        'exercise_not_found' => 'Có bài tập cần cập nhật nhưng chưa tồn tại.',
        'stale_catalog_preview' =>
          'Danh mục vừa thay đổi. Hãy kiểm tra JSON lại.',
        'invalid_exercise_import' =>
          'JSON chưa đúng cấu trúc hoặc vượt giới hạn.',
        _ => 'Không thể đồng bộ danh mục lúc này.',
      });
    }
    if (payload == null) throw const FormatException();
    return payload;
  }

  Future<T> _track<T>(Future<T> request) {
    late final Future<void> completion;
    completion = request
        .then<void>((_) {}, onError: (_, _) {})
        .whenComplete(() => _pendingRequests.remove(completion));
    _pendingRequests.add(completion);
    return request;
  }

  Future<void> whenIdle() async {
    while (_pendingRequests.isNotEmpty) {
      await Future.wait(_pendingRequests.toList(growable: false));
    }
  }

  void close() => _client.close();
}
