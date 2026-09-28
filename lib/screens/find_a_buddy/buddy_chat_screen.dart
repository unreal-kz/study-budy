import 'package:flutter/material.dart';

class BuddyChatScreen extends StatelessWidget {
  const BuddyChatScreen({required this.buddyId, super.key});

  final String buddyId;

  @override
  Widget build(BuildContext context) =>
      Scaffold(appBar: AppBar(title: Text('Chat: $buddyId')));
}
