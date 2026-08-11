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
    required this.suggestionAccepted,
  });

  static const defaults = PlannerState(
    weeklySchedule: [
      PlannedSession(day: 1, title: 'Ngực + Tay sau'),
      PlannedSession(day: 3, title: 'Lưng + Tay trước'),
      PlannedSession(day: 5, title: 'Chân + Mông'),
    ],
    recoveryHours: 48,
    todayWorkout: 'Chân + Mông',
    suggestionAccepted: false,
  );

  final List<PlannedSession> weeklySchedule;
  final int recoveryHours;
  final String todayWorkout;
  final bool suggestionAccepted;

  Map<String, Object> toJson() => {
    'weeklySchedule': weeklySchedule.map((item) => item.toJson()).toList(),
    'recoveryHours': recoveryHours,
    'todayWorkout': todayWorkout,
    'suggestionAccepted': suggestionAccepted,
  };

  factory PlannerState.fromJson(Map<String, dynamic> json) {
    final schedule = json['weeklySchedule'];
    final recoveryHours = json['recoveryHours'];
    final todayWorkout = json['todayWorkout'];
    final suggestionAccepted = json['suggestionAccepted'];
    if (schedule is! List<dynamic> ||
        schedule.isEmpty ||
        recoveryHours is! int ||
        recoveryHours < 24 ||
        recoveryHours > 96 ||
        todayWorkout is! String ||
        todayWorkout.isEmpty ||
        suggestionAccepted is! bool) {
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
      suggestionAccepted: suggestionAccepted,
    );
  }
}

abstract interface class PlannerRepository {
  Future<PlannerLoadResult> load();
  Future<PlannerState> save(PlannerState state);
}

class PlannerLoadResult {
  const PlannerLoadResult({
    required this.state,
    this.usedOfflineFallback = false,
  });
  final PlannerState? state;
  final bool usedOfflineFallback;
}

abstract interface class PlannerCache {
  Future<CachedPlannerState?> read();
  Future<void> write(PlannerState state, {required bool dirty});
}

class CachedPlannerState {
  const CachedPlannerState({required this.state, required this.dirty});
  final PlannerState state;
  final bool dirty;
}

class SecurePlannerCache implements PlannerCache {
  SecurePlannerCache({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'planner_state_v1';
  final FlutterSecureStorage _storage;

  @override
  Future<CachedPlannerState?> read() async {
    final value = await _storage.read(key: _key);
    if (value == null) return null;
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      final state = decoded['state'];
      final dirty = decoded['dirty'];
      if (state is! Map<String, dynamic> || dirty is! bool) {
        throw const FormatException();
      }
      return CachedPlannerState(
        state: PlannerState.fromJson(state),
        dirty: dirty,
      );
    } catch (_) {
      await _storage.delete(key: _key);
      return null;
    }
  }

  @override
  Future<void> write(PlannerState state, {required bool dirty}) async {
    await _storage.write(
      key: _key,
      value: jsonEncode({'dirty': dirty, 'state': state.toJson()}),
    );
  }
}

class CachedPlannerRepository implements PlannerRepository {
  CachedPlannerRepository({required this.remote, required this.cache});

  final PlannerApi remote;
  final PlannerCache cache;
  int _activeOperations = 0;
  Completer<void>? _idleCompleter;

  @override
  Future<PlannerLoadResult> load() async {
    _beginOperation();
    try {
      final cached = await cache.read();
      if (cached?.dirty ?? false) {
        try {
          final synced = await remote.save(cached!.state);
          await cache.write(synced, dirty: false);
          return PlannerLoadResult(state: synced);
        } catch (_) {
          return PlannerLoadResult(
            state: cached!.state,
            usedOfflineFallback: true,
          );
        }
      }
      final remoteResult = await remote.load();
      final state = remoteResult.state;
      if (state != null) await cache.write(state, dirty: false);
      return PlannerLoadResult(state: state ?? cached?.state);
    } catch (_) {
      final cached = await cache.read();
      if (cached != null) {
        return PlannerLoadResult(
          state: cached.state,
          usedOfflineFallback: true,
        );
      }
      rethrow;
    } finally {
      _endOperation();
    }
  }

  @override
  Future<PlannerState> save(PlannerState state) async {
    _beginOperation();
    try {
      await cache.write(state, dirty: true);
      final synced = await remote.save(state);
      await cache.write(synced, dirty: false);
      return synced;
    } finally {
      _endOperation();
    }
  }

  Future<void> whenIdle() async {
    if (_activeOperations > 0) await _idleCompleter!.future;
  }

  void _beginOperation() {
    if (_activeOperations++ == 0) _idleCompleter = Completer<void>();
  }

  void _endOperation() {
    _activeOperations--;
    if (_activeOperations == 0) _idleCompleter?.complete();
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
  Future<PlannerLoadResult> load() async {
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
    if (data == null) return const PlannerLoadResult(state: null);
    try {
      if (data is! Map<String, dynamic>) throw const FormatException();
      return PlannerLoadResult(state: PlannerState.fromJson(data));
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
