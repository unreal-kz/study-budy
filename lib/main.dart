import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/buddy_chat_api.dart';
import 'data/chat_repository.dart';
import 'data/profile_repository.dart';
import 'data/progress_repository.dart';
import 'router/app_router.dart';
import 'state/chat_provider.dart';
import 'state/profile_provider.dart';
import 'state/progress_provider.dart';
import 'theme/app_theme.dart';

const backendBaseUrl = String.fromEnvironment(
  'BACKEND_BASE_URL',
  defaultValue: 'http://localhost:8000',
);

// Empty by default -> no X-App-Token header sent, matching the backend's
// unauthenticated local-dev default (see server/.env.example APP_TOKEN).
const appToken = String.fromEnvironment('APP_TOKEN', defaultValue: '');

void main() {
  runApp(const StudyBudyApp());
}

class StudyBudyApp extends StatelessWidget {
  const StudyBudyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProfileProvider(ProfileRepository())..load()),
        ChangeNotifierProvider(create: (_) => ProgressProvider(ProgressRepository())..load()),
      ],
      child: Builder(
        builder: (context) {
          // Built once: go_router's own `refreshListenable` handles redirect
          // reactivity, so the router must not be reconstructed on every
          // provider rebuild (that would reset navigation to initialLocation).
          final router = buildRouter(context.read<ProfileProvider>());
          return Consumer2<ProfileProvider, ProgressProvider>(
            builder: (context, profileProvider, progressProvider, _) {
              return ChangeNotifierProvider(
                key: ValueKey(profileProvider.profile.level),
                create: (_) => ChatProvider(
                  repository: ChatRepository(),
                  api: BuddyChatApi(baseUrl: backendBaseUrl, appToken: appToken),
                  progressProvider: progressProvider,
                  level: profileProvider.profile.level,
                )..load(),
                child: MaterialApp.router(
                  title: 'Study Buddy',
                  theme: AppTheme.light,
                  routerConfig: router,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
