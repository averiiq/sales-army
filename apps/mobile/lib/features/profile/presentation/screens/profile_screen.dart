import 'package:flutter/material.dart';
import 'package:salesarmy/features/profile/presentation/screens/profile_and_settings_screen.dart';

export 'package:salesarmy/features/profile/presentation/screens/profile_and_settings_screen.dart';

/// Legacy backwards-compatible export of ProfileScreen.
/// Unifies profile information and settings into a single executive page.
class ProfileScreen extends StatelessWidget {
  final VoidCallback? onSignOut;
  const ProfileScreen({super.key, this.onSignOut});

  @override
  Widget build(BuildContext context) {
    return ProfileAndSettingsScreen(initialTab: 0, onSignOut: onSignOut);
  }
}
