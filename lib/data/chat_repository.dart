import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_message.dart';

class ChatRepository {
  static const _key = 'chat_messages';

  Future<List<ChatMessage>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const <String>[];
    final messages = <ChatMessage>[];
    for (final s in raw) {
      try {
        messages.add(ChatMessage.fromJson(jsonDecode(s) as Map<String, dynamic>));
      } catch (_) {
        // Skip a corrupted entry rather than losing/crashing the whole list.
      }
    }
    return messages;
  }

  Future<void> add(ChatMessage message) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const <String>[];
    await prefs.setStringList(_key, [...raw, jsonEncode(message.toJson())]);
  }
}
