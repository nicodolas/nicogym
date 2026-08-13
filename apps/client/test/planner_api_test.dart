import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nicogym/auth/auth_api.dart';
import 'package:nicogym/member/planner_api.dart';

void main() {
  test('loads planner state with the bearer session', () async {
    late http.Request captured;
    final api = PlannerApi(
      baseUrl: Uri.parse('https://api.example.test'),
      tokenStore: _TokenStore('session-token'),
      client: MockClient((request) async {
        captured = request;
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'data': {
                'weeklySchedule': [
                  {'day': 1, 'title': 'Ngực + Tay sau'},
                ],
                'recoveryHours': 48,
                'todayWorkout': 'Chân + Mông',
                'suggestionAccepted': false,
              },
            }),
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final state = await api.load();
    expect(captured.headers['authorization'], 'Bearer session-token');
    expect(state.state?.weeklySchedule.single.day, 1);
    expect(state.state?.recoveryHours, 48);
  });

  test('saves the complete planner state', () async {
    late http.Request captured;
    final api = PlannerApi(
      baseUrl: Uri.parse('https://api.example.test'),
      tokenStore: _TokenStore('session-token'),
      client: MockClient((request) async {
        captured = request;
        return http.Response.bytes(
          utf8.encode(jsonEncode({'data': jsonDecode(request.body)})),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    await api.save(PlannerState.defaults);
    expect(captured.method, 'PUT');
    expect(jsonDecode(captured.body), PlannerState.defaults.toJson());
  });

  test('converts malformed successful state into a safe error', () async {
    final api = PlannerApi(
      baseUrl: Uri.parse('https://api.example.test'),
      tokenStore: _TokenStore('session-token'),
      client: MockClient(
        (_) async => http.Response('{"data":{"recoveryHours":"bad"}}', 200),
      ),
    );

    await expectLater(api.load(), throwsA(isA<AuthException>()));
  });

  test('writes through to cache before a remote save failure', () async {
    final cache = _MemoryPlannerCache();
    final remote = PlannerApi(
      baseUrl: Uri.parse('https://api.example.test'),
      tokenStore: _TokenStore('session-token'),
      client: MockClient((_) async => http.Response('offline', 503)),
    );
    final repository = CachedPlannerRepository(remote: remote, cache: cache);

    await expectLater(
      repository.save(PlannerState.defaults),
      throwsA(isA<AuthException>()),
    );
    expect(cache.state?.todayWorkout, 'Chân + Mông');
    expect(cache.entry?.dirty, isTrue);
    repository.close();
  });

  test('marks a cached load as an offline fallback', () async {
    final cache = _MemoryPlannerCache()
      ..entry = const CachedPlannerState(
        state: PlannerState.defaults,
        dirty: false,
      );
    final repository = CachedPlannerRepository(
      remote: PlannerApi(
        baseUrl: Uri.parse('https://api.example.test'),
        tokenStore: _TokenStore('session-token'),
        client: MockClient((_) async => http.Response('offline', 503)),
      ),
      cache: cache,
    );

    final result = await repository.load();
    expect(result.state?.todayWorkout, 'Chân + Mông');
    expect(result.usedOfflineFallback, isTrue);
    repository.close();
  });

  test(
    'whenIdle includes the latest save queued during an active save',
    () async {
      final firstResponse = Completer<http.Response>();
      final requests = <http.Request>[];
      final repository = CachedPlannerRepository(
        remote: PlannerApi(
          baseUrl: Uri.parse('https://api.example.test'),
          tokenStore: _TokenStore('session-token'),
          client: MockClient((request) async {
            requests.add(request);
            if (requests.length == 1) return firstResponse.future;
            return http.Response.bytes(
              utf8.encode(jsonEncode({'data': jsonDecode(request.body)})),
              200,
            );
          }),
        ),
        cache: _MemoryPlannerCache(),
      );
      const latest = PlannerState(
        weeklySchedule: [
          PlannedSession(day: 1, title: 'Ngực + Tay sau'),
          PlannedSession(day: 3, title: 'Lưng + Tay trước'),
          PlannedSession(day: 5, title: 'Chân + Mông'),
        ],
        recoveryHours: 72,
        todayWorkout: 'Chân + Mông',
        suggestionAccepted: false,
      );

      final firstSave = repository.save(PlannerState.defaults);
      await Future<void>.delayed(Duration.zero);
      final latestSave = repository.save(latest);
      final idle = repository.whenIdle();
      firstResponse.complete(
        http.Response.bytes(
          utf8.encode(jsonEncode({'data': PlannerState.defaults.toJson()})),
          200,
        ),
      );

      await Future.wait([firstSave, latestSave, idle]);
      expect(requests, hasLength(2));
      expect(jsonDecode(requests.last.body)['recoveryHours'], 72);
      repository.close();
    },
  );
}

class _MemoryPlannerCache implements PlannerCache {
  CachedPlannerState? entry;
  PlannerState? get state => entry?.state;

  @override
  Future<CachedPlannerState?> read() async => entry;

  @override
  Future<void> write(PlannerState value, {required bool dirty}) async =>
      entry = CachedPlannerState(state: value, dirty: dirty);
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
