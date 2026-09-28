import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/ai_buddy/ai_buddy_screen.dart';
import '../screens/community/community_screen.dart';
import '../screens/find_a_buddy/buddy_chat_screen.dart';
import '../screens/find_a_buddy/find_a_buddy_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/progress/progress_screen.dart';
import '../state/profile_provider.dart';

const tabPaths = ['/home', '/community', '/ai-buddy', '/progress', '/profile'];
const tabLabels = ['Home', 'Community', 'AI Buddy', 'Progress', 'Profile'];
const tabIcons = [
  Icons.home,
  Icons.groups,
  Icons.smart_toy,
  Icons.trending_up,
  Icons.person,
];

GoRouter buildRouter(ProfileProvider profileProvider) {
  return GoRouter(
    initialLocation: '/home',
    refreshListenable: profileProvider,
    redirect: (context, state) {
      final onboarded = profileProvider.profile.onboardingComplete;
      final onOnboarding = state.matchedLocation == '/onboarding';
      if (!onboarded && !onOnboarding) return '/onboarding';
      if (onboarded && onOnboarding) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
          GoRoute(path: '/community', builder: (_, _) => const CommunityScreen()),
          GoRoute(path: '/ai-buddy', builder: (_, _) => const AiBuddyScreen()),
          GoRoute(path: '/progress', builder: (_, _) => const ProgressScreen()),
          GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
        ],
      ),
      GoRoute(path: '/find-a-buddy', builder: (_, _) => const FindABuddyScreen()),
      GoRoute(
        path: '/buddy-chat/:buddyId',
        builder: (context, state) =>
            BuddyChatScreen(buddyId: state.pathParameters['buddyId']!),
      ),
    ],
  );
}

class AppShell extends StatelessWidget {
  const AppShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = tabPaths.indexOf(location);
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex < 0 ? 0 : currentIndex,
        onDestinationSelected: (index) => context.go(tabPaths[index]),
        destinations: [
          for (var i = 0; i < tabPaths.length; i++)
            NavigationDestination(icon: Icon(tabIcons[i]), label: tabLabels[i]),
        ],
      ),
    );
  }
}
