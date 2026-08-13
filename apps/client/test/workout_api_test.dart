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

    final id = await api.startExercise('leg-press');
    await api.logSet(workoutExerciseId: id, loadKg: 40, repetitions: 10);

    expect(requests, hasLength(2));
    expect(requests.first.headers['authorization'], 'Bearer session-token');
    expect(jsonDecode(requests.first.body), {'exerciseSlug': 'leg-press'});
    expect(jsonDecode(requests.last.body), {
      'workoutExerciseId': 'workout-exercise-1',
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
      api.startExercise('leg-press'),
      throwsA(
        isA<WorkoutSyncException>().having(
          (error) => error.message,
          'message',
          'Đăng nhập để đồng bộ buổi tập.',
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
