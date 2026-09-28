import 'package:flutter_test/flutter_test.dart';
import 'package:study_budy/models/chat_message.dart';

void main() {
  test('ChatMessage round-trips through JSON, including nulls', () {
    final message = ChatMessage(
      id: '1',
      sender: 'user',
      text: 'Hello',
      createdAt: DateTime.utc(2026, 1, 1),
    );
    final restored = ChatMessage.fromJson(message.toJson());
    expect(restored.text, 'Hello');
    expect(restored.correction, isNull);
    expect(restored.createdAt, DateTime.utc(2026, 1, 1));
  });

  test('ChatMessage round-trips with correction/explanation set', () {
    final message = ChatMessage(
      id: '2',
      sender: 'ai',
      text: 'Nice!',
      correction: 'I went to school.',
      explanation: 'Past tense of go is went.',
      createdAt: DateTime.utc(2026, 1, 2),
    );
    final restored = ChatMessage.fromJson(message.toJson());
    expect(restored.correction, 'I went to school.');
    expect(restored.explanation, 'Past tense of go is went.');
  });
}
