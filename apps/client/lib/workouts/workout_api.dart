import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:nicogym/auth/auth_api.dart';

abstract interface class WorkoutRepository {
  Future<String> startExercise(String exerciseSlug);
  Future<void> logSet({
    required String workoutExerciseId,
    required double loadKg,
    required int repetitions,
  });
}

class WorkoutApi implements WorkoutRepository {
  WorkoutApi({
    required this.baseUrl,
    required this.tokenStore,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final Uri baseUrl;
  final TokenStore tokenStore;
  final http.Client _client;
  static const _timeout = Duration(seconds: 15);

  @override
  Future<String> startExercise(String exerciseSlug) async {
    final payload = await _post('/api/workout-sessions', {
      'exerciseSlug': exerciseSlug,
    });
    final data = payload['data'];
    final workoutExerciseId = data is Map<String, dynamic>
        ? data['workoutExerciseId']
        : null;
    if (workoutExerciseId is! String || workoutExerciseId.isEmpty) {
      throw const WorkoutSyncException('Máy chủ trả về buổi tập không hợp lệ.');
    }
    return workoutExerciseId;
  }

  @override
  Future<void> logSet({
    required String workoutExerciseId,
    required double loadKg,
    required int repetitions,
  }) async {
    await _post('/api/workout-sets', {
      'workoutExerciseId': workoutExerciseId,
      'loadKg': loadKg,
      'repetitions': repetitions,
    });
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final token = await tokenStore.read();
    if (token == null || token.isEmpty) {
      throw const WorkoutSyncException('Đăng nhập để đồng bộ buổi tập.');
    }
    try {
      final response = await _client
          .post(
            baseUrl.resolve(path),
            headers: {
              'authorization': 'Bearer $token',
              'content-type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(_timeout);
      Map<String, dynamic>? payload;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) payload = decoded;
      } on FormatException {
        // Use the safe error below.
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw WorkoutSyncException(switch (payload?['error']) {
          'unauthorized' => 'Phiên đăng nhập đã hết hạn.',
          'exercise_not_found' => 'Bài tập này chưa có trên máy chủ.',
          'rate_limit_exceeded' => 'Bạn thao tác quá nhanh. Hãy thử lại sau.',
          _ => 'Chưa thể đồng bộ buổi tập lúc này.',
        });
      }
      if (payload == null) {
        throw const WorkoutSyncException(
          'Máy chủ trả về dữ liệu không hợp lệ.',
        );
      }
      return payload;
    } on WorkoutSyncException {
      rethrow;
    } catch (_) {
      throw const WorkoutSyncException('Không kết nối được máy chủ.');
    }
  }

  void close() => _client.close();
}

class WorkoutSyncException implements Exception {
  const WorkoutSyncException(this.message);
  final String message;
}
