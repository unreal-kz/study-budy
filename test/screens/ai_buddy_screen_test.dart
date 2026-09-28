import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_budy/data/buddy_chat_api.dart';
import 'package:study_budy/data/chat_repository.dart';
import 'package:study_budy/data/progress_repository.dart';
import 'package:study_budy/screens/ai_buddy/ai_buddy_screen.dart';
import 'package:study_budy/state/chat_provider.dart';
import 'package:study_budy/state/progress_provider.dart';

class _ScriptedApi extends BuddyChatApi {
  _ScriptedApi(this._reply) : super(baseUrl: 'http://unused');
  final BuddyReply _reply;

  @override
  Future<BuddyReply> sendMessage({
    required List history,
    required String message,
    required String level,
  }) async =>
      _reply;
}

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

Future<ChatProvider> _pumpAiBuddy(WidgetTester tester, BuddyChatApi api) async {
  SharedPreferences.setMockInitialValues({});
  final progressProvider = ProgressProvider(ProgressRepository());
  await progressProvider.load();
  final chatProvider = ChatProvider(
    repository: ChatRepository(),
    api: api,
    progressProvider: progressProvider,
    level: 'B1',
  );
  await chatProvider.load();

  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: chatProvider,
      child: const MaterialApp(home: AiBuddyScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return chatProvider;
}

void main() {
  testWidgets('sending a message shows the reply and the correction card', (tester) async {
    await _pumpAiBuddy(
      tester,
      _ScriptedApi(const BuddyReply(
        reply: 'Nice!',
        correction: 'I went to school yesterday.',
        explanation: 'Past tense of go is went.',
      )),
    );

    await tester.enterText(find.byKey(const Key('ai_buddy_input')), 'I go to school yesterday.');
    await tester.tap(find.byKey(const Key('ai_buddy_send')));
    await tester.pumpAndSettle();

    expect(find.text('Nice!'), findsOneWidget);
    expect(find.byKey(const Key('ai_feedback_card')), findsOneWidget);
    expect(find.textContaining('I went to school yesterday.'), findsOneWidget);
  });

  testWidgets('a failed backend call shows an inline error, not a crash', (tester) async {
    await _pumpAiBuddy(tester, _FailingApi());

    await tester.enterText(find.byKey(const Key('ai_buddy_input')), 'Hi');
    await tester.tap(find.byKey(const Key('ai_buddy_send')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ai_buddy_error')), findsOneWidget);
    expect(find.text('Hi'), findsOneWidget); // the user's message is still shown
  });
}
