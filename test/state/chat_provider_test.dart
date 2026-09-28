import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_budy/data/buddy_chat_api.dart';
import 'package:study_budy/data/chat_repository.dart';
import 'package:study_budy/data/progress_repository.dart';
import 'package:study_budy/state/chat_provider.dart';
import 'package:study_budy/state/progress_provider.dart';

class _FailingApi extends BuddyChatApi {
  _FailingApi() : super(baseUrl: 'http://unused');

  @override
  Future<BuddyReply> sendMessage({
    required List history,
    required String message,
    required String level,
  }) {
    throw BuddyChatException("Can't reach your practice partner right now.");
  }
}

/// Simulates a 200 response with a malformed body shape: BuddyReply.fromJson
/// throws a raw TypeError, not a BuddyChatException.
class _MalformedResponseApi extends BuddyChatApi {
  _MalformedResponseApi() : super(baseUrl: 'http://unused');

  @override
  Future<BuddyReply> sendMessage({
    required List history,
    required String message,
    required String level,
  }) {
    throw TypeError();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('sendMessage keeps the user message locally even if the API call fails', () async {
    final progressProvider = ProgressProvider(ProgressRepository());
    await progressProvider.load();

    final chatProvider = ChatProvider(
      repository: ChatRepository(),
      api: _FailingApi(),
      progressProvider: progressProvider,
      level: 'B1',
    );
    await chatProvider.load();

    await chatProvider.sendMessage('I go to school yesterday.');

    expect(chatProvider.messages, hasLength(1));
    expect(chatProvider.messages.first.text, 'I go to school yesterday.');
    expect(chatProvider.error, isNotNull);

    final persisted = await ChatRepository().loadAll();
    expect(persisted, hasLength(1));
  });

  test('sendMessage sets an error and notifies even on a non-BuddyChatException failure', () async {
    final progressProvider = ProgressProvider(ProgressRepository());
    await progressProvider.load();

    final chatProvider = ChatProvider(
      repository: ChatRepository(),
      api: _MalformedResponseApi(),
      progressProvider: progressProvider,
      level: 'B1',
    );
    await chatProvider.load();

    var notified = false;
    chatProvider.addListener(() => notified = true);

    await chatProvider.sendMessage('Hi there.');

    expect(chatProvider.error, isNotNull);
    expect(notified, isTrue);
    expect(chatProvider.messages, hasLength(1));
    expect(chatProvider.messages.first.text, 'Hi there.');
  });
}
