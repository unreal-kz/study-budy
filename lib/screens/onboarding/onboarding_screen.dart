import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/profile_provider.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _nameController = TextEditingController();
  String _level = 'A1';

  static const _levels = ['A1', 'A2', 'B1', 'B2'];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Welcome to Study Buddy')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('onboarding_name'),
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Your name'),
            ),
            const SizedBox(height: 16),
            DropdownButton<String>(
              key: const Key('onboarding_level'),
              value: _level,
              items: _levels
                  .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                  .toList(),
              onChanged: (value) => setState(() => _level = value!),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              key: const Key('onboarding_submit'),
              onPressed: () {
                final name = _nameController.text.trim();
                if (name.isEmpty) return;
                context
                    .read<ProfileProvider>()
                    .completeOnboarding(name: name, level: _level);
              },
              child: const Text('Get Started'),
            ),
          ],
        ),
      ),
    );
  }
}
