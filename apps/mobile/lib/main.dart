import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:salesarmy/features/auth/data/services/auth_service.dart';
import 'package:salesarmy/features/admin/data/services/tenant_service.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/core/theme/app_theme.dart';
import 'package:salesarmy/features/auth/presentation/screens/splash_screen.dart';
import 'package:salesarmy/features/auth/presentation/screens/login_screen.dart';
import 'package:salesarmy/core/navigation/main_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salesarmy/core/services/supabase_service.dart';

import 'package:salesarmy/core/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await SupabaseService.instance.initialize();
  } catch (e) {
    debugPrint("Supabase initialize note: $e (Falling back to offline/local storage)");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<SupabaseService>.value(value: SupabaseService.instance),
        ChangeNotifierProvider<AppState>(create: (_) => AppState(loadMockData: false)),
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<TenantService>(create: (_) => TenantService()),
      ],
      child: Consumer<AppState>(
        builder: (context, appState, _) {
          NotificationService.instance.initialize(appState);
          return MaterialApp(
            navigatorKey: rootNavigatorKey,
            title: 'SalesArmy',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: appState.themeMode,
            initialRoute: '/',
            routes: {
              '/': (_) => const AppEntryWrapper(),
            },
          );
        },
      ),
    );
  }
}

class AppEntryWrapper extends StatefulWidget {
  const AppEntryWrapper({super.key});

  @override
  State<AppEntryWrapper> createState() => _AppEntryWrapperState();
}

class _AppEntryWrapperState extends State<AppEntryWrapper> {
  bool _showSplash = true;
  bool _sessionRestorationComplete = false;
  bool _loggedIn = false;

  static const String _prefKeySessionLoggedIn = 'salesarmy_session_logged_in_v1';
  static const String _prefKeySessionRole = 'salesarmy_session_role_v1';
  static const String _prefKeySessionTenantId = 'salesarmy_session_tenant_id_v1';
  static const String _prefKeySessionUid = 'salesarmy_session_uid_v1';

  @override
  void initState() {
    super.initState();
    _restoreSavedSession();

    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted && (!_sessionRestorationComplete || _showSplash)) {
        setState(() {
          _sessionRestorationComplete = true;
          _showSplash = false;
        });
      }
    });
  }

  Future<void> _restoreSavedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool(_prefKeySessionLoggedIn) ?? false;
      final savedRole = prefs.getString(_prefKeySessionRole);
      final savedTenantId = prefs.getString(_prefKeySessionTenantId);
      final savedUid = prefs.getString(_prefKeySessionUid);

      if (isLoggedIn && mounted) {
        final targetRole = (savedRole != null && savedRole.isNotEmpty) ? savedRole : 'Owner';
        final isSuperAdmin = (targetRole == 'super_admin');
        // Hard-require a saved tenant id. Previously fell back to
        // `tenant_shree_ganesh_traders`, which dumped every un-tagged account
        // into the shared demo tenant — causing users to see each other's
        // shops, orders and bills. Now: no tenant → wipe the session and
        // force a fresh login.
        final targetTenantId = (savedTenantId != null && savedTenantId.isNotEmpty)
            ? savedTenantId
            : (isSuperAdmin ? 'platform_tenant' : '');
        final targetUid = (savedUid != null && savedUid.isNotEmpty) ? savedUid : '';

        if (targetTenantId.isEmpty || targetUid.isEmpty) {
          await _saveSession(isLoggedIn: false);
          return;
        }

        final appState = context.read<AppState>();
        // Set role FIRST so toggleSuperAdminMode's `isSuperAdminUser` check
        // passes. Previously `toggleSuperAdminMode(true)` ran before
        // currentUserRole was populated, threw StateError, got swallowed by
        // the outer catch, and left the user stuck on the login screen.
        appState.initForTenant(targetTenantId, targetUid, role: targetRole);
        appState.setActiveRole(targetRole);
        if (isSuperAdmin) {
          try {
            appState.toggleSuperAdminMode(true);
          } catch (_) {}
        }
        setState(() {
          _loggedIn = true;
        });
        return;
      }

      final supaUser = SupabaseService.instance.currentUser;
      if (supaUser != null) {
        final supaClient = SupabaseService.instance.client;
        if (supaClient != null) {
          try {
            await supaClient.auth.refreshSession().timeout(const Duration(seconds: 3));
          } catch (_) {}

          final profile = await SupabaseService.instance
              .fetchUserProfile(supaUser.id)
              .timeout(const Duration(seconds: 3));
          if (profile != null && profile['is_active'] != false) {
            final targetRole = AuthService.mapDbRoleToAppRole(
                profile['role']?.toString(), supaUser.email ?? '');
            // Profile MUST carry a tenant_id — otherwise this account was
            // never properly onboarded and must not be allowed in. Previous
            // fallback to `tenant_shree_ganesh_traders` leaked data across
            // workspaces.
            final rawTenantId = profile['tenant_id']?.toString();
            final targetTenantId = (rawTenantId != null && rawTenantId.isNotEmpty)
                ? rawTenantId
                : (targetRole == 'super_admin' ? 'platform_tenant' : '');

            if (targetTenantId.isEmpty) {
              // Session is unusable — profile exists but is unassigned to a
              // tenant. Force sign-out so the user re-registers properly.
              try {
                await supaClient.auth.signOut();
              } catch (_) {}
              return;
            }

            if (mounted) {
              final appState = context.read<AppState>();
              appState.initForTenant(targetTenantId, supaUser.id, role: targetRole);
              appState.setActiveRole(targetRole);
              if (targetRole == 'super_admin') {
                try {
                  appState.toggleSuperAdminMode(true);
                } catch (_) {}
              }
              await _saveSession(isLoggedIn: true, role: targetRole, tenantId: targetTenantId, uid: supaUser.id);
              setState(() {
                _loggedIn = true;
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Session restoration note: $e');
    } finally {
      if (mounted) {
        setState(() {
          _sessionRestorationComplete = true;
        });
      }
    }
  }

  Future<void> _saveSession({
    required bool isLoggedIn,
    String? role,
    String? tenantId,
    String? uid,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKeySessionLoggedIn, isLoggedIn);
      if (role != null) {
        await prefs.setString(_prefKeySessionRole, role);
      } else {
        await prefs.remove(_prefKeySessionRole);
      }
      if (tenantId != null) {
        await prefs.setString(_prefKeySessionTenantId, tenantId);
      }
      if (uid != null) {
        await prefs.setString(_prefKeySessionUid, uid);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash || !_sessionRestorationComplete) {
      return SplashScreen(
        onFinished: () {
          if (mounted) {
            setState(() => _showSplash = false);
          }
        },
      );
    }

    if (_loggedIn) {
      return MainShell(
        onSignOut: () async {
          final appState = context.read<AppState>();
          final auth = context.read<AuthService>();
          await _saveSession(isLoggedIn: false);
          appState.signOutSession();
          try {
            await auth.signOut();
          } catch (_) {}
          if (mounted) {
            setState(() {
              _loggedIn = false;
            });
          }
        },
      );
    }

    return LoginScreen(
      onRoleLogin: (role) async {
        final appState = context.read<AppState>();
        final isSuperAdmin = (role.toLowerCase().trim() == 'super_admin' ||
            role.toLowerCase().trim() == 'super admin');
        final targetRole = isSuperAdmin ? 'super_admin' : role;
        // Pull the tenant/uid from AppState, which should have been populated
        // by the login screen's _executeLoginWithRole. If AppState still has
        // no tenant_id, we must NOT invent a demo one — bail out so the user
        // retries login.
        final tid = (appState.currentTenantId != null && appState.currentTenantId!.isNotEmpty)
            ? appState.currentTenantId!
            : (isSuperAdmin ? 'platform_tenant' : '');
        final uid = (appState.currentUid != null && appState.currentUid!.isNotEmpty)
            ? appState.currentUid!
            : '';
        if (tid.isEmpty || uid.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Workspace missing. Please sign in again.'),
            backgroundColor: Color(0xFFDC2626),
          ));
          return;
        }

        // Order: set role first so toggleSuperAdminMode doesn't trip the
        // StateError guard, then await the session write so the login flag
        // is durably on disk before we flip the UI.
        appState.initForTenant(tid, uid, role: targetRole);
        appState.setActiveRole(targetRole);
        if (isSuperAdmin) {
          try {
            appState.toggleSuperAdminMode(true);
          } catch (_) {}
        }
        await _saveSession(isLoggedIn: true, role: targetRole, tenantId: tid, uid: uid);
        if (!mounted) return;
        setState(() {
          _loggedIn = true;
        });
      },
    );
  }
}
