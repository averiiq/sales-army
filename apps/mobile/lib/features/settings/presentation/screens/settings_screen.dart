import 'package:flutter/material.dart';
import 'package:salesarmy/features/profile/presentation/screens/profile_and_settings_screen.dart';

export 'package:salesarmy/features/profile/presentation/screens/profile_and_settings_screen.dart';

/// Legacy backwards-compatible export of SettingsScreen.
/// Unifies settings and profile information into a single executive page.
class SettingsScreen extends StatelessWidget {
  final VoidCallback? onSignOut;

  const SettingsScreen({super.key, this.onSignOut});

  @override
  Widget build(BuildContext context) {
    return ProfileAndSettingsScreen(initialTab: 1, onSignOut: onSignOut);
  }
}
