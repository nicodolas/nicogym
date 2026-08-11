import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:nicogym/auth/auth_api.dart';

class PlannedSession {
  const PlannedSession({required this.day, required this.title});

  final int day;
  final String title;

  Map<String, Object> toJson() => {'day': day, 'title': title};

  factory PlannedSession.fromJson(Map<String, dynamic> json) {
    final day = json['day'];
    final title = json['title'];
    if (day is! int ||
        day < 1 ||
        day > 7 ||
        title is! String ||
        title.isEmpty) {
      throw const FormatException('invalid planned session');
    }
    return PlannedSession(day: day, title: title);
  }
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

  factory PlannerState.fromJson(Map<String, dynamic> json) {
    final schedule = json['weeklySchedule'];
    final recoveryHours = json['recoveryHours'];
    final todayWorkout = json['todayWorkout'];
    if (schedule is! List<dynamic> ||
        schedule.isEmpty ||
        recoveryHours is! int ||
        recoveryHours < 24 ||
        recoveryHours > 96 ||
        todayWorkout is! String ||
        todayWorkout.isEmpty) {
      throw const FormatException('invalid planner state');
    }
    return PlannerState(
      weeklySchedule: schedule.map((item) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException('invalid planned session');
        }
        return PlannedSession.fromJson(item);
      }).toList(),
      recoveryHours: recoveryHours,
      todayWorkout: todayWorkout,
    );
  }
}

abstract interface class PlannerRepository {
  Future<PlannerState?> load();
  Future<PlannerState> save(PlannerState state);
}

abstract interface class PlannerCache {
  Future<PlannerState?> read();
  Future<void> write(PlannerState state);
}

class SecurePlannerCache implements PlannerCache {
  SecurePlannerCache({required this.tokenStore, FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'planner_state_v1';
  final TokenStore tokenStore;
  final FlutterSecureStorage _storage;

  @override
  Future<PlannerState?> read() async {
    final value = await _storage.read(key: _key);
    if (value == null) return null;
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      final token = await tokenStore.read();
      if (token == null || decoded['ownerToken'] != token) {
        await _storage.delete(key: _key);
        return null;
      }
      final state = decoded['state'];
      if (state is! Map<String, dynamic>) throw const FormatException();
      return PlannerState.fromJson(state);
    } catch (_) {
      await _storage.delete(key: _key);
      return null;
    }
  }

  @override
  Future<void> write(PlannerState state) async {
    final token = await tokenStore.read();
    if (token == null || token.isEmpty) return;
    await _storage.write(
      key: _key,
      value: jsonEncode({'ownerToken': token, 'state': state.toJson()}),
    );
  }
}

class CachedPlannerRepository implements PlannerRepository {
  CachedPlannerRepository({required this.remote, required this.cache});

  final PlannerApi remote;
  final PlannerCache cache;

  @override
  Future<PlannerState?> load() async {
    try {
      final state = await remote.load();
      if (state != null) await cache.write(state);
      return state ?? await cache.read();
    } catch (_) {
      final cached = await cache.read();
      if (cached != null) return cached;
      rethrow;
    }
  }

  @override
  Future<PlannerState> save(PlannerState state) async {
    await cache.write(state);
    return remote.save(state);
  }

  void close() => remote.close();
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
  static const _timeout = Duration(seconds: 12);

  @override
  Future<PlannerState?> load() async {
    final http.Response response;
    try {
      response = await _client
          .get(baseUrl.resolve('/api/planner'), headers: await _headers())
          .timeout(_timeout);
    } on TimeoutException {
      throw const AuthException('Kết nối đồng bộ quá chậm.');
    }
    final payload = await _decode(response);
    final data = payload['data'];
    if (data == null) return null;
    try {
      if (data is! Map<String, dynamic>) throw const FormatException();
      return PlannerState.fromJson(data);
    } on FormatException {
      throw const AuthException('Máy chủ trả về dữ liệu không hợp lệ.');
    }
  }

  @override
  Future<PlannerState> save(PlannerState state) async {
    final http.Response response;
    try {
      response = await _client
          .put(
            baseUrl.resolve('/api/planner'),
            headers: await _headers(json: true),
            body: jsonEncode(state.toJson()),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw const AuthException('Kết nối đồng bộ quá chậm.');
    }
    final payload = await _decode(response);
    try {
      final data = payload['data'];
      if (data is! Map<String, dynamic>) throw const FormatException();
      return PlannerState.fromJson(data);
    } on FormatException {
      throw const AuthException('Máy chủ trả về dữ liệu không hợp lệ.');
    }
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

  void close() => _client.close();
}
