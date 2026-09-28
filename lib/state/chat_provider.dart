import 'package:flutter/foundation.dart';

import '../data/buddy_chat_api.dart';
import '../data/chat_repository.dart';
import '../models/chat_message.dart';
import 'progress_provider.dart';

class ChatProvider extends ChangeNotifier {
  ChatProvider({
    required this._repository,
    required this._api,
    required this._progressProvider,
    required this._level,
  });

  final ChatRepository _repository;
  final BuddyChatApi _api;
  final ProgressProvider _progressProvider;
  final String _level;

  List<ChatMessage> _messages = const [];
  String? _error;

  List<ChatMessage> get messages => _messages;
  String? get error => _error;

  Future<void> load() async {
    _messages = await _repository.loadAll();
    notifyListeners();
  }

  Future<void> sendMessage(String text) async {
    _error = null;
    final userMessage = ChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      sender: 'user',
      text: text,
      createdAt: DateTime.now(),
    );
    // Persisted before the network call - never lost if it fails.
    await _repository.add(userMessage);
    _messages = [..._messages, userMessage];
    notifyListeners();

    try {
      final history = _messages.length > 1
          ? _messages.sublist(0, _messages.length - 1)
          : const <ChatMessage>[];
      final reply = await _api.sendMessage(history: history, message: text, level: _level);
      final aiMessage = ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        sender: 'ai',
        text: reply.reply,
        correction: reply.correction,
        explanation: reply.explanation,
        createdAt: DateTime.now(),
      );
      await _repository.add(aiMessage);
      _messages = [..._messages, aiMessage];
      await _progressProvider.recordSession(
        newWords: reply.correction != null ? 1 : 0,
        challengesCompleted: 0,
      );
    } on BuddyChatException catch (e) {
      _error = e.message;
    }
    notifyListeners();
  }
}
