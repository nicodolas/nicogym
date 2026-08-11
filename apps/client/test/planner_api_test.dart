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
    expect(state?.weeklySchedule.single.day, 1);
    expect(state?.recoveryHours, 48);
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
