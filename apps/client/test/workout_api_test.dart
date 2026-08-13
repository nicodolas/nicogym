import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nicogym/auth/auth_api.dart';
import 'package:nicogym/workouts/workout_api.dart';

void main() {
  test('starts an exercise and logs a set with the bearer session', () async {
    final requests = <http.Request>[];
    final api = WorkoutApi(
      baseUrl: Uri.parse('https://api.example.test'),
      tokenStore: _TokenStore('session-token'),
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/workout-sessions') {
          return http.Response(
            jsonEncode({
              'data': {'workoutExerciseId': 'workout-exercise-1'},
            }),
            201,
          );
        }
        return http.Response(
          jsonEncode({'data': jsonDecode(request.body)}),
          201,
        );
      }),
    );

    final id = await api.startExercise(
      'leg-press',
      operationId: 'session-operation-1',
    );
    await api.logSet(
      workoutExerciseId: id,
      operationId: 'set-operation-1',
      loadKg: 40,
      repetitions: 10,
    );

    expect(requests, hasLength(2));
    expect(requests.first.headers['authorization'], 'Bearer session-token');
    expect(jsonDecode(requests.first.body), {
      'exerciseSlug': 'leg-press',
      'operationId': 'session-operation-1',
    });
    expect(jsonDecode(requests.last.body), {
      'workoutExerciseId': 'workout-exercise-1',
      'operationId': 'set-operation-1',
      'loadKg': 40.0,
      'repetitions': 10,
    });
  });

  test('explains when workout sync requires login', () async {
    final api = WorkoutApi(
      baseUrl: Uri.parse('https://api.example.test'),
      tokenStore: _TokenStore(null),
      client: MockClient((_) async => http.Response('', 500)),
    );

    await expectLater(
      api.startExercise('leg-press', operationId: 'session-operation-1'),
      throwsA(
        isA<WorkoutSyncException>().having(
          (error) => error.message,
          'message',
          'Đăng nhập để đồng bộ buổi tập.',
        ),
      ),
    );
  });

  test('clears an expired token after an unauthorized response', () async {
    final tokenStore = _TokenStore('expired-token');
    final api = WorkoutApi(
      baseUrl: Uri.parse('https://api.example.test'),
      tokenStore: tokenStore,
      client: MockClient((_) async => http.Response('', 401)),
    );

    await expectLater(
      api.startExercise('leg-press', operationId: 'session-operation-1'),
      throwsA(isA<WorkoutSyncException>()),
    );

    expect(tokenStore.token, isNull);
  });

  test(
    'does not clear a newer token after an older request gets 401',
    () async {
      final tokenStore = _RotatingTokenStore();
      final api = WorkoutApi(
        baseUrl: Uri.parse('https://api.example.test'),
        tokenStore: tokenStore,
        client: MockClient((_) async => http.Response('', 401)),
      );

      await expectLater(
        api.startExercise('leg-press', operationId: 'session-operation-1'),
        throwsA(isA<WorkoutSyncException>()),
      );

      expect(await tokenStore.read(), 'new-token');
      expect(tokenStore.clearCalls, 0);
    },
  );

  test('converts secure storage failures into sync errors', () async {
    final api = WorkoutApi(
      baseUrl: Uri.parse('https://api.example.test'),
      tokenStore: _ThrowingTokenStore(),
      client: MockClient((_) async => http.Response('', 500)),
    );

    await expectLater(
      api.startExercise('leg-press', operationId: 'session-operation-1'),
      throwsA(
        isA<WorkoutSyncException>().having(
          (error) => error.message,
          'message',
          'Không kết nối được máy chủ.',
        ),
      ),
    );
  });

  for (final testCase in [
    (
      status: 404,
      body: {'error': 'exercise_not_found'},
      message: 'Bài tập này chưa có trên máy chủ.',
    ),
    (
      status: 429,
      body: {'error': 'rate_limit_exceeded'},
      message: 'Bạn thao tác quá nhanh. Hãy thử lại sau.',
    ),
  ]) {
    test('maps ${testCase.body['error']} to a safe message', () async {
      final api = WorkoutApi(
        baseUrl: Uri.parse('https://api.example.test'),
        tokenStore: _TokenStore('session-token'),
        client: MockClient(
          (_) async =>
              http.Response(jsonEncode(testCase.body), testCase.status),
        ),
      );

      await expectLater(
        api.startExercise('leg-press', operationId: 'session-operation-1'),
        throwsA(
          isA<WorkoutSyncException>().having(
            (error) => error.message,
            'message',
            testCase.message,
          ),
        ),
      );
    });
  }

  test('rejects a successful response with a malformed body', () async {
    final api = WorkoutApi(
      baseUrl: Uri.parse('https://api.example.test'),
      tokenStore: _TokenStore('session-token'),
      client: MockClient((_) async => http.Response('[]', 201)),
    );

    await expectLater(
      api.startExercise('leg-press', operationId: 'session-operation-1'),
      throwsA(
        isA<WorkoutSyncException>().having(
          (error) => error.message,
          'message',
          'Máy chủ trả về dữ liệu không hợp lệ.',
        ),
      ),
    );
  });
}

class _TokenStore implements TokenStore {
  _TokenStore(this.token);
  String? token;

  @override
  Future<void> clear() async => token = null;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String value) async => token = value;
}

class _ThrowingTokenStore implements TokenStore {
  @override
  Future<void> clear() async {}

  @override
  Future<String?> read() => throw StateError('storage unavailable');

  @override
  Future<void> write(String value) async {}
}

class _RotatingTokenStore implements TokenStore {
  var reads = 0;
  var clearCalls = 0;

  @override
  Future<void> clear() async => clearCalls += 1;

  @override
  Future<String?> read() async {
    reads += 1;
    return reads == 1 ? 'old-token' : 'new-token';
  }

  @override
  Future<void> write(String value) async {}
}
