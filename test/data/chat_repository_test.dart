import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_budy/data/chat_repository.dart';
import 'package:study_budy/models/chat_message.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('loadAll() returns empty list initially', () async {
    final repo = ChatRepository();
    expect(await repo.loadAll(), isEmpty);
  });

  test('add() appends and preserves order', () async {
    final repo = ChatRepository();
    await repo.add(ChatMessage(
      id: '1', sender: 'user', text: 'Hi', createdAt: DateTime.utc(2026, 1, 1),
    ));
    await repo.add(ChatMessage(
      id: '2', sender: 'ai', text: 'Hello!', createdAt: DateTime.utc(2026, 1, 1, 0, 0, 1),
    ));
    final messages = await repo.loadAll();
    expect(messages.map((m) => m.id).toList(), ['1', '2']);
  });

  test('loadAll() skips a corrupted entry but keeps the valid ones', () async {
    SharedPreferences.setMockInitialValues({
      'chat_messages': ['not valid json', jsonEncode(ChatMessage(
        id: '1', sender: 'user', text: 'Hi', createdAt: DateTime.utc(2026, 1, 1),
      ).toJson())],
    });
    final repo = ChatRepository();
    final messages = await repo.loadAll();
    expect(messages, hasLength(1));
    expect(messages.first.id, '1');
  });
}
