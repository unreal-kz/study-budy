import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/profile_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/initial_avatar.dart';

const levelLabels = {
  'A1': 'A1 — Beginner',
  'A2': 'A2 — Elementary',
  'B1': 'B1 — Intermediate',
  'B2': 'B2 — Upper-Intermediate',
};

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
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.cream50,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.pine800,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Text(
                          'SB',
                          style: textTheme.headlineSmall?.copyWith(color: AppColors.cream50),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text('Study Buddy', style: textTheme.headlineLarge, textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      Text(
                        'SPEAK. CONNECT. GROW.',
                        style: textTheme.titleSmall?.copyWith(
                          color: AppColors.green600,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: const [
                          _OnboardingPill(label: 'Practice English', bg: Color(0xFFE4EFEA), fg: AppColors.pine800),
                          _OnboardingPill(label: 'Make Friends', bg: Color(0xFFFBE9CE), fg: AppColors.warnText),
                          _OnboardingPill(label: 'Be a Better You', bg: Color(0xFFF4E3F3), fg: Color(0xFF7A3E77)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 64,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            _OverlappingAvatar(initial: 'A', color: AppColors.gold500, offset: -32),
                            _OverlappingAvatar(initial: 'D', color: AppColors.pine800, offset: 0),
                            _OverlappingAvatar(initial: 'K', color: AppColors.green600, offset: 32),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        '"A global mindset starts with a conversation."',
                        textAlign: TextAlign.center,
                        style: textTheme.titleSmall?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: AppColors.neutral500,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        key: const Key('onboarding_name'),
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'YOUR NAME', hintText: 'Daryn'),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        key: const Key('onboarding_level'),
                        initialValue: _level,
                        decoration: const InputDecoration(labelText: 'ENGLISH LEVEL'),
                        items: [
                          for (final l in _levels)
                            DropdownMenuItem(value: l, child: Text(levelLabels[l] ?? l)),
                        ],
                        onChanged: (value) => setState(() => _level = value!),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  key: const Key('onboarding_submit'),
                  onPressed: () {
                    final name = _nameController.text.trim();
                    if (name.isEmpty) return;
                    context.read<ProfileProvider>().completeOnboarding(name: name, level: _level);
                  },
                  child: const Text('Get Started'),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'A safe space for real conversations — made by students, for students.',
                textAlign: TextAlign.center,
                style: textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingPill extends StatelessWidget {
  const _OnboardingPill({required this.label, required this.bg, required this.fg});

  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _OverlappingAvatar extends StatelessWidget {
  const _OverlappingAvatar({required this.initial, required this.color, required this.offset});

  final String initial;
  final Color color;
  final double offset;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(offset, 0),
      child: Container(
        decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.cream50),
        padding: const EdgeInsets.all(3),
        child: InitialAvatar(initial: initial, color: color, size: 64),
      ),
    );
  }
}
