import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/core/services/supabase_service.dart';
import 'package:salesarmy/features/auth/data/services/auth_service.dart';
import 'package:salesarmy/features/admin/presentation/screens/super_admin_console.dart';

/// Dedicated standalone portal for SaaS Super Admin authentication.
/// Accessible via separate route: `/#/admin` or `/#/super-admin`.
class SuperAdminPortalPage extends StatefulWidget {
  const SuperAdminPortalPage({super.key});

  @override
  State<SuperAdminPortalPage> createState() => _SuperAdminPortalPageState();
}

class _SuperAdminPortalPageState extends State<SuperAdminPortalPage> {
  bool _isAuthenticated = false;

  @override
  Widget build(BuildContext context) {
    if (_isAuthenticated) {
      return SuperAdminConsole(
        onExitConsole: () {
          setState(() => _isAuthenticated = false);
        },
        onSignOut: () {
          setState(() => _isAuthenticated = false);
        },
      );
    }

    return SuperAdminLoginScreen(
      onLoginSuccess: () {
        setState(() => _isAuthenticated = true);
      },
    );
  }
}

/// Administrative login screen separated completely from the distributor app.
class SuperAdminLoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const SuperAdminLoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<SuperAdminLoginScreen> createState() => _SuperAdminLoginScreenState();
}

class _SuperAdminLoginScreenState extends State<SuperAdminLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleAdminLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Please enter both super admin email and passcode.';
      });
      return;
    }

    AuthService? authService;
    try {
      authService = context.read<AuthService>();
    } catch (_) {}

    try {
      // 1. Supabase-First Authentication & RBAC Check
      if (SupabaseService.instance.isInitialized) {
        try {
          final supaRes = await SupabaseService.instance.signInWithEmailPassword(
            email: email,
            password: password,
          );
          if (supaRes?.user != null) {
            final uid = supaRes!.user!.id;
            final profile = await SupabaseService.instance.fetchUserProfile(uid);
            final role = profile?['role']?.toString();
            if (role != 'super_admin') {
              setState(() {
                _isLoading = false;
                _errorMessage = 'Access Denied: This account does not have admin console access.';
              });
              await SupabaseService.instance.signOut();
              return;
            }

            // Successfully authenticated and authorized as super_admin
            if (mounted) {
              try {
                context.read<AppState>().initForTenant('platform_tenant', uid, role: 'super_admin');
                context.read<AppState>().toggleSuperAdminMode(true);
              } catch (_) {}
              widget.onLoginSuccess();
            }
            return;
          }
        } catch (supaErr) {
          if (mounted) {
            setState(() {
              _errorMessage = 'Invalid administrative credentials.';
            });
          }
          return;
        }
      }

      if (authService != null) {
        final userCred = await authService.signInWithEmailPassword(email, password);

        if (userCred != null && userCred.user != null) {
          final profile = await authService.getUserProfile(userCred.user!.uid);
          if (profile?.role != 'super_admin') {
            setState(() {
              _isLoading = false;
              _errorMessage = 'Access Denied: Account does not possess super_admin privileges.';
            });
            await authService.signOut();
            return;
          }

          if (mounted) {
            try {
              final uid = userCred.user?.uid ?? 'admin_uid';
              context.read<AppState>().initForTenant('platform_tenant', uid, role: 'super_admin');
              context.read<AppState>().toggleSuperAdminMode(true);
            } catch (_) {}
            widget.onLoginSuccess();
          }
          return;
        }
      }

      if (mounted) {
        setState(() {
          _errorMessage = 'Invalid administrative credentials.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Authentication failed. Please verify your administrative credentials.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark slate administrative background
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B), // Elevated slate card
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF334155), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Shield Icon
                    Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1D4ED8).withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF3B82F6), width: 1.5),
                        ),
                        child: const Icon(
                          Icons.admin_panel_settings_rounded,
                          size: 34,
                          color: Color(0xFF60A5FA),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Portal Badge
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E3A8A).withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF2563EB)),
                        ),
                        child: const Text(
                          'RESTRICTED ADMINISTRATIVE GATEWAY',
                          style: TextStyle(
                            color: Color(0xFF93C5FD),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Title
                    const Text(
                      'SaaS Super Admin Console',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Log in to manage platform tenants, subscriptions, gateways and billing.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF94A3B8),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Error Message Banner
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7F1D1D).withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFDC2626)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Color(0xFFFCA5A5), size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Email Field
                    const Text(
                      'Super Admin Email',
                      style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _emailController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF64748B), size: 18),
                        hintText: 'admin@salesarmy.saas',
                        hintStyle: const TextStyle(color: Color(0xFF475569), fontSize: 13.5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF334155)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF334155)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Password / Passcode Field
                    const Text(
                      'Master Admin Passcode',
                      style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF64748B), size: 18),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: const Color(0xFF64748B),
                            size: 18,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        hintText: '••••••••••••',
                        hintStyle: const TextStyle(color: Color(0xFF475569), fontSize: 13.5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF334155)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF334155)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Login Button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleAdminLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1D4ED8),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.login_rounded, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Enter Super Admin Console',
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 20),

                    // Return to Distributor App Link
                    Center(
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.pushReplacementNamed(context, '/');
                        },
                        icon: const Icon(Icons.arrow_back_rounded, size: 15, color: Color(0xFF94A3B8)),
                        label: const Text(
                          'Return to Distributor App',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
