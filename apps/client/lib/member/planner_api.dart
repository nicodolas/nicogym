import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:nicogym/auth/auth_api.dart';

class PlannedSession {
  const PlannedSession({required this.day, required this.title});

  final int day;
  final String title;

  Map<String, Object> toJson() => {'day': day, 'title': title};

  factory PlannedSession.fromJson(Map<String, dynamic> json) =>
      PlannedSession(day: json['day'] as int, title: json['title'] as String);
}

class PlannerState {
  const PlannerState({
    required this.weeklySchedule,
    required this.recoveryHours,
    required this.todayWorkout,
  });

  static const defaults = PlannerState(
    weeklySchedule: [
      PlannedSession(day: 1, title: 'Ngực + Tay sau'),
      PlannedSession(day: 3, title: 'Lưng + Tay trước'),
      PlannedSession(day: 5, title: 'Chân + Mông'),
    ],
    recoveryHours: 48,
    todayWorkout: 'Chân + Mông',
  );

  final List<PlannedSession> weeklySchedule;
  final int recoveryHours;
  final String todayWorkout;

  Map<String, Object> toJson() => {
    'weeklySchedule': weeklySchedule.map((item) => item.toJson()).toList(),
    'recoveryHours': recoveryHours,
    'todayWorkout': todayWorkout,
  };

  factory PlannerState.fromJson(Map<String, dynamic> json) => PlannerState(
    weeklySchedule: (json['weeklySchedule'] as List<dynamic>)
        .map((item) => PlannedSession.fromJson(item as Map<String, dynamic>))
        .toList(),
    recoveryHours: json['recoveryHours'] as int,
    todayWorkout: json['todayWorkout'] as String,
  );
}

abstract interface class PlannerRepository {
  Future<PlannerState?> load();
  Future<PlannerState> save(PlannerState state);
}

class PlannerApi implements PlannerRepository {
  PlannerApi({
    required this.baseUrl,
    required this.tokenStore,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final Uri baseUrl;
  final TokenStore tokenStore;
  final http.Client _client;

  @override
  Future<PlannerState?> load() async {
    final response = await _client.get(
      baseUrl.resolve('/api/planner'),
      headers: await _headers(),
    );
    final payload = await _decode(response);
    final data = payload['data'];
    return data == null
        ? null
        : PlannerState.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<PlannerState> save(PlannerState state) async {
    final response = await _client.put(
      baseUrl.resolve('/api/planner'),
      headers: await _headers(json: true),
      body: jsonEncode(state.toJson()),
    );
    final payload = await _decode(response);
    return PlannerState.fromJson(payload['data'] as Map<String, dynamic>);
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

  Future<Map<String, dynamic>> _decode(http.Response response) async {
    if (response.statusCode == 401) {
      await tokenStore.clear();
      throw const AuthException('Phiên đăng nhập đã hết hạn.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const AuthException('Không đồng bộ được lịch tập.');
    }
    final dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw const AuthException('Máy chủ trả về dữ liệu không hợp lệ.');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const AuthException('Máy chủ trả về dữ liệu không hợp lệ.');
    }
    return decoded;
  }
}
