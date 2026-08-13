import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nicogym/auth/auth_api.dart';
import 'package:nicogym/member/progress_api.dart';

void main() {
  test('loads the authenticated member progress summary', () async {
    final api = ProgressApi(
      baseUrl: Uri.parse('https://api.example.test'),
      tokenStore: _TokenStore('token'),
      client: MockClient((request) async {
        expect(request.headers['authorization'], 'Bearer token');
        return http.Response(
          jsonEncode({
            'data': {
              'sessions': 2,
              'sets': 6,
              'volumeKg': 2400,
              'latest': [
                {
                  'exerciseSlug': 'leg-press',
                  'exerciseName': 'Leg press',
                  'loadKg': 40,
                  'repetitions': 10,
                  'completedAt': '2026-08-13T07:00:00.000Z',
                },
              ],
            },
          }),
          200,
        );
      }),
    );

    final result = await api.load();
    expect(result.sessions, 2);
    expect(result.sets, 6);
    expect(result.volumeKg, 2400);
    expect(result.latest.single.exerciseName, 'Leg press');
  });

  test('clears the expired token on unauthorized', () async {
    final store = _TokenStore('expired');
    final api = ProgressApi(
      baseUrl: Uri.parse('https://api.example.test'),
      tokenStore: store,
      client: MockClient((_) async => http.Response('', 401)),
    );

    await expectLater(api.load(), throwsA(isA<ProgressException>()));
    expect(store.token, isNull);
  });

  test('distinguishes malformed server data from a network failure', () async {
    final api = ProgressApi(
      baseUrl: Uri.parse('https://api.example.test'),
      tokenStore: _TokenStore('token'),
      client: MockClient((_) async => http.Response('{broken', 200)),
    );

    await expectLater(
      api.load(),
      throwsA(
        isA<ProgressException>().having(
          (error) => error.message,
          'message',
          'Máy chủ trả về dữ liệu tiến độ không hợp lệ.',
        ),
      ),
    );
  });

  test(
    'waits for an in-flight progress request before becoming idle',
    () async {
      final response = Completer<http.Response>();
      final api = ProgressApi(
        baseUrl: Uri.parse('https://api.example.test'),
        tokenStore: _TokenStore('token'),
        client: MockClient((_) => response.future),
      );

      final request = api.load();
      var idle = false;
      final waiting = api.whenIdle().then((_) => idle = true);
      await Future<void>.delayed(Duration.zero);
      expect(idle, isFalse);

      response.complete(
        http.Response(
          jsonEncode({
            'data': {'sessions': 0, 'sets': 0, 'volumeKg': 0, 'latest': []},
          }),
          200,
        ),
      );
      await request;
      await waiting;
      expect(idle, isTrue);
    },
  );
}

class _TokenStore implements ConditionalTokenStore {
  _TokenStore(this.token);
  String? token;

  @override
  Future<void> clear() async => token = null;

  @override
  Future<bool> clearIfMatches(String expectedToken) async {
    if (token != expectedToken) return false;
    token = null;
    return true;
  }

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String value) async => token = value;
}
