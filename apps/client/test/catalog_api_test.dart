import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:nicogym/admin/catalog_api.dart';
import 'package:nicogym/auth/auth_api.dart';

void main() {
  test('waits for in-flight catalog requests before closing', () async {
    final client = _DelayedClient();
    final api = CatalogApi(
      baseUrl: Uri.parse('https://example.com'),
      tokenStore: _TokenStore(),
      client: client,
    );

    final exercises = api.loadExercises();
    var idle = false;
    final waiting = api.whenIdle().then((_) => idle = true);
    await Future<void>.delayed(Duration.zero);

    expect(idle, isFalse);
    expect(client.closed, isFalse);

    client.complete({'data': <Object>[]});
    await exercises;
    await waiting;
    api.close();

    expect(idle, isTrue);
    expect(client.closed, isTrue);
  });

  test('a timed-out token read cannot start a later request', () async {
    final tokenStore = _SlowTokenStore();
    final client = _DelayedClient();
    final api = CatalogApi(
      baseUrl: Uri.parse('https://example.com'),
      tokenStore: tokenStore,
      client: client,
      requestTimeout: const Duration(milliseconds: 10),
    );

    await expectLater(api.loadExercises(), throwsA(isA<TimeoutException>()));
    await api.whenIdle();
    api.close();
    tokenStore.complete('late-token');
    await Future<void>.delayed(Duration.zero);

    expect(client.sendCount, 0);
  });
}

class _DelayedClient extends http.BaseClient {
  final _response = Completer<http.StreamedResponse>();
  bool closed = false;
  int sendCount = 0;

  void complete(Map<String, Object> payload) {
    _response.complete(
      http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(payload))),
        200,
        headers: {'content-type': 'application/json'},
      ),
    );
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    sendCount += 1;
    return _response.future;
  }

  @override
  void close() {
    closed = true;
    super.close();
  }
}

class _TokenStore implements TokenStore {
  @override
  Future<void> clear() async {}

  @override
  Future<String?> read() async => 'token';

  @override
  Future<void> write(String value) async {}
}

class _SlowTokenStore implements TokenStore {
  final _token = Completer<String?>();

  void complete(String value) => _token.complete(value);

  @override
  Future<void> clear() async {}

  @override
  Future<String?> read() => _token.future;

  @override
  Future<void> write(String value) async {}
}
