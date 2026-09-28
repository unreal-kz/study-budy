import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_budy/data/buddy_chat_api.dart';

void main() {
  test('sendMessage returns a parsed BuddyReply on 200', () async {
    final mockClient = MockClient((request) async {
      expect(request.url.path, '/buddy/chat');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['message'], 'I go to school yesterday.');
      expect(body['level'], 'A2');
      return http.Response(
        jsonEncode({
          'reply': 'Nice!',
          'correction': 'I went to school yesterday.',
          'explanation': 'Past tense of go is went.',
        }),
        200,
      );
    });

    final api = BuddyChatApi(baseUrl: 'http://localhost:8000', client: mockClient);
    final reply = await api.sendMessage(
      history: const [],
      message: 'I go to school yesterday.',
      level: 'A2',
    );

    expect(reply.reply, 'Nice!');
    expect(reply.correction, 'I went to school yesterday.');
  });

  test('sendMessage throws BuddyChatException on 429', () async {
    final mockClient = MockClient((request) async => http.Response('', 429));
    final api = BuddyChatApi(baseUrl: 'http://localhost:8000', client: mockClient);

    expect(
      () => api.sendMessage(history: const [], message: 'Hi', level: 'B1'),
      throwsA(isA<BuddyChatException>()),
    );
  });

  test('sendMessage throws BuddyChatException when the server is unreachable', () async {
    final mockClient = MockClient((request) async => throw Exception('connection refused'));
    final api = BuddyChatApi(baseUrl: 'http://localhost:8000', client: mockClient);

    expect(
      () => api.sendMessage(history: const [], message: 'Hi', level: 'B1'),
      throwsA(isA<BuddyChatException>()),
    );
  });

  test('sendMessage sends X-App-Token header when appToken is set', () async {
    final mockClient = MockClient((request) async {
      expect(request.headers['X-App-Token'], 'my-secret');
      return http.Response(
        jsonEncode({'reply': 'ok', 'correction': null, 'explanation': null}),
        200,
      );
    });

    final api = BuddyChatApi(
      baseUrl: 'http://localhost:8000',
      appToken: 'my-secret',
      client: mockClient,
    );
    await api.sendMessage(history: const [], message: 'Hi', level: 'B1');
  });

  test('sendMessage omits X-App-Token header when appToken is empty', () async {
    final mockClient = MockClient((request) async {
      expect(request.headers.containsKey('X-App-Token'), isFalse);
      return http.Response(
        jsonEncode({'reply': 'ok', 'correction': null, 'explanation': null}),
        200,
      );
    });

    final api = BuddyChatApi(baseUrl: 'http://localhost:8000', client: mockClient);
    await api.sendMessage(history: const [], message: 'Hi', level: 'B1');
  });
}
