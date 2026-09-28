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
  bool _isSending = false;

  List<ChatMessage> get messages => _messages;
  String? get error => _error;
  bool get isSending => _isSending;

  Future<void> load() async {
    _messages = await _repository.loadAll();
    notifyListeners();
  }

  Future<void> sendMessage(String text) async {
    // A reply already in flight (likely a Render cold start, up to ~90s) -
    // ignore a second tap rather than firing a parallel request.
    if (_isSending) return;

    _error = null;
    _isSending = true;
    notifyListeners();
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
    } catch (_) {
      // Anything else (e.g. a malformed 200 body throwing a raw TypeError
      // out of BuddyReply.fromJson) must still surface as a visible error,
      // not fail silently after the user's message is already shown.
      _error = "Can't reach your practice partner right now.";
    }
    _isSending = false;
    notifyListeners();
  }
}
