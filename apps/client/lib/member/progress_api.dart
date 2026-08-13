import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:nicogym/auth/auth_api.dart';

class ProgressEntry {
  const ProgressEntry({
    required this.exerciseSlug,
    required this.exerciseName,
    required this.loadKg,
    required this.repetitions,
    required this.completedAt,
  });

  final String exerciseSlug;
  final String exerciseName;
  final double loadKg;
  final int repetitions;
  final DateTime completedAt;

  factory ProgressEntry.fromJson(Map<String, dynamic> json) => ProgressEntry(
    exerciseSlug: json['exerciseSlug'] as String,
    exerciseName: json['exerciseName'] as String,
    loadKg: (json['loadKg'] as num).toDouble(),
    repetitions: json['repetitions'] as int,
    completedAt: DateTime.parse(json['completedAt'] as String).toLocal(),
  );
}

class ProgressSummary {
  const ProgressSummary({
    required this.sessions,
    required this.sets,
    required this.volumeKg,
    required this.latest,
  });

  final int sessions;
  final int sets;
  final double volumeKg;
  final List<ProgressEntry> latest;

  factory ProgressSummary.fromJson(Map<String, dynamic> json) {
    final latest = json['latest'];
    if (json['sessions'] is! int ||
        json['sets'] is! int ||
        json['volumeKg'] is! num ||
        latest is! List<dynamic>) {
      throw const FormatException('invalid progress summary');
    }
    return ProgressSummary(
      sessions: json['sessions'] as int,
      sets: json['sets'] as int,
      volumeKg: (json['volumeKg'] as num).toDouble(),
      latest: latest
          .map((item) => ProgressEntry.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

abstract interface class ProgressRepository {
  Future<ProgressSummary> load();
}

class ProgressApi implements ProgressRepository {
  ProgressApi({
    required this.baseUrl,
    required this.tokenStore,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final Uri baseUrl;
  final ConditionalTokenStore tokenStore;
  final http.Client _client;
  final Set<Future<void>> _pendingRequests = {};

  @override
  Future<ProgressSummary> load() => _track(_requestProgress());

  Future<ProgressSummary> _requestProgress() async {
    try {
      final token = await tokenStore.read();
      if (token == null || token.isEmpty) {
        throw const ProgressException('Đăng nhập để xem tiến độ.');
      }
      final response = await _client
          .get(
            baseUrl.resolve('/api/progress'),
            headers: {'authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 401) {
        await tokenStore.clearIfMatches(token);
        throw const ProgressException('Phiên đăng nhập đã hết hạn.');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const ProgressException('Chưa tải được tiến độ.');
      }
      final payload = jsonDecode(response.body);
      if (payload is! Map<String, dynamic> ||
          payload['data'] is! Map<String, dynamic>) {
        throw const FormatException('invalid progress response');
      }
      return ProgressSummary.fromJson(payload['data'] as Map<String, dynamic>);
    } on ProgressException {
      rethrow;
    } on FormatException {
      throw const ProgressException(
        'Máy chủ trả về dữ liệu tiến độ không hợp lệ.',
      );
    } on TypeError {
      throw const ProgressException(
        'Máy chủ trả về dữ liệu tiến độ không hợp lệ.',
      );
    } catch (_) {
      throw const ProgressException('Không kết nối được máy chủ.');
    }
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

class ProgressException implements Exception {
  const ProgressException(this.message);
  final String message;
}
