import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:salesarmy/core/utils/app_error.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/core/services/supabase_service.dart';
import 'package:salesarmy/features/auth/data/services/auth_service.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/features/admin/data/models/tenant_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback? onDemoDistributorLogin;
  final VoidCallback? onDemoSuperAdminLogin;
  final ValueChanged<String>? onRoleLogin;
  final AuthService? authService;

  const LoginScreen({
    super.key,
    this.onDemoDistributorLogin,
    this.onDemoSuperAdminLogin,
    this.onRoleLogin,
    this.authService,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final AuthService _authService = widget.authService ?? AuthService();

  // Mode & Tabs: 0 = Password, 1 = Email OTP
  bool _isSignUpMode = false;
  int _selectedTab = 0;

  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _agencyNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  final _otpController = TextEditingController();

  // State
  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;
  bool _otpSent = false;
  int _resendCountdown = 0;
  Timer? _countdownTimer;

  // Google sign-in started by the button (vs. a redirect that reopened the app).
  bool _googleFlowInProgress = false;
  bool _handlingGoogleSession = false;
  StreamSubscription<dynamic>? _authSub;

  @override
  void initState() {
    super.initState();
    // If Android reopened the app from the Google redirect, Supabase finishes
    // the sign-in on its own. Pick that session up here instead of leaving
    // the user on the login screen.
    WidgetsBinding.instance.addPostFrameCallback((_) => _resumeGoogleSession());
    _authSub = SupabaseService.instance.authStateChanges?.listen(
      (state) {
        // Ignore sign-ins this screen started itself (email / OTP / button).
        if (!_googleFlowInProgress && !_isLoading && state.session?.user != null && state.event.name == 'signedIn') {
          _resumeGoogleSession();
        }
      },
      onError: (Object e) {
        if (!mounted || _googleFlowInProgress) return;
        setState(() => _errorMessage = 'Google sign-in could not be completed. Please try again.');
      },
    );
  }

  bool _isGoogleUser(dynamic user) {
    if (user == null) return false;
    if (user.appMetadata['provider'] == 'google') return true;
    final ids = user.identities as List?;
    return ids != null && ids.any((i) => i.provider == 'google');
  }

  Future<void> _resumeGoogleSession() async {
    if (_handlingGoogleSession || _googleFlowInProgress || !mounted) return;
    final user = SupabaseService.instance.currentUser;
    if (!_isGoogleUser(user)) return;
    _handlingGoogleSession = true;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final result = await _authService.completeGoogleSignIn(user!);
      await _applyGoogleResult(result);
    } finally {
      _handlingGoogleSession = false;
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _countdownTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _agencyNameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  AppState? _getAppState() {
    try {
      return Provider.of<AppState>(context, listen: false);
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistSessionLocally(String role, {bool isAdmin = false, String? tenantId, String? uid}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('salesarmy_session_logged_in_v1', true);
      await prefs.setString('salesarmy_session_role_v1', role);
      await prefs.setBool('salesarmy_session_is_admin_v1', isAdmin);
      if (tenantId != null) await prefs.setString('salesarmy_session_tenant_id_v1', tenantId);
      if (uid != null) await prefs.setString('salesarmy_session_uid_v1', uid);
    } catch (_) {}
  }

  Future<void> _recordRegisteredUserLocally({
    required String email,
    required String name,
    required String uid,
    String role = 'Owner',
    String tenantId = '',
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final usersJson = prefs.getString('salesarmy_local_registered_users_v1');
      Map<String, dynamic> users = {};
      if (usersJson != null && usersJson.isNotEmpty) {
        users = Map<String, dynamic>.from(json.decode(usersJson));
      }
      // Never serialize plaintext passwords to local storage (Audit C-2 fix)
      users[email.toLowerCase().trim()] = {
        'uid': uid,
        'email': email.toLowerCase().trim(),
        'name': name.trim(),
        'role': role,
        'tenant_id': tenantId,
        'created_at': DateTime.now().toIso8601String(),
      };
      await prefs.setString('salesarmy_local_registered_users_v1', json.encode(users));
    } catch (_) {}
  }

  Future<void> _executeLoginWithRole(
    String role, {
    String? tenantId,
    String? uid,
    TenantModel? loadedTenant,
  }) async {
    if (uid == null || uid.isEmpty || tenantId == null || tenantId.isEmpty || role == 'unassigned') {
      setState(() => _errorMessage = 'A verified account and workspace are required.');
      return;
    }
    final appState = _getAppState();
    appState?.setActiveRole(role);

    final isAdmin = role.toLowerCase() == 'super admin' || role.toLowerCase() == 'super_admin';
    final effectiveTenantId = tenantId;
    final effectiveUid = uid;

    appState?.initForTenant(
      effectiveTenantId,
      effectiveUid,
      loadedTenant: loadedTenant,
      role: role,
    );
    // Await the prefs write so the login flag is durable on disk before the
    // UI transitions. Previously fire-and-forget — if the user force-closed
    // the app seconds later, the write could be dropped.
    await _persistSessionLocally(role, isAdmin: isAdmin, tenantId: effectiveTenantId, uid: effectiveUid);

    if (isAdmin) {
      if (widget.onDemoSuperAdminLogin != null) {
        widget.onDemoSuperAdminLogin!();
      } else if (widget.onRoleLogin != null) {
        widget.onRoleLogin!('super_admin');
      } else {
        appState?.toggleSuperAdminMode(true);
        if (widget.onDemoDistributorLogin != null) widget.onDemoDistributorLogin!();
      }
      return;
    }

    if (widget.onRoleLogin != null) {
      widget.onRoleLogin!(role);
    } else if (widget.onDemoDistributorLogin != null) {
      widget.onDemoDistributorLogin!();
    }
  }

  // Delegates to AuthService.mapDbRoleToAppRole — single source of truth.
  String _mapDatabaseRoleToUiRole(String? dbRole) =>
      AuthService.mapDbRoleToAppRole(dbRole);

  // 1. Email & Password Authentication
  Future<void> _handleEmailPasswordAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please enter both email and password');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isSignUpMode) {
        final agencyName = _agencyNameController.text.trim();
        final name = _nameController.text.trim();
        final phone = _phoneController.text.trim();
        final city = _cityController.text.trim();

        // Reject blank onboarding fields — previously these silently defaulted
        // to the demo tenant ("Shree Ganesh Traders" / Mumbai / +91 98765 43210),
        // which caused every blank signup to collide into one shared tenant.
        if (agencyName.isEmpty || name.isEmpty || phone.isEmpty || city.isEmpty) {
          setState(() {
            _errorMessage = 'Please fill in agency name, owner name, mobile, and city to launch your workspace.';
            _isLoading = false;
          });
          return;
        }
        if (password.length < 6) {
          setState(() {
            _errorMessage = 'Password must be at least 6 characters.';
            _isLoading = false;
          });
          return;
        }

        // 1. Complete Agency Onboarding (Seamlessly handles both brand new and already-used emails)
        final regRes = await SupabaseService.instance.registerAgencyOwnerAndSeed(
          businessName: agencyName,
          representativeName: name,
          email: email,
          password: password,
          phone: phone,
          city: city,
        );

        final tenantId = regRes['tenantId']?.toString() ?? '';
        final uid = regRes['uid']?.toString() ?? '';
        if (regRes['success'] != true || tenantId.isEmpty || uid.isEmpty) {
          if (regRes['needsEmailConfirmation'] == true) {
            // Account exists now — switch to sign-in so they can log in after confirming.
            setState(() => _isSignUpMode = false);
          }
          setState(() {
            _errorMessage = regRes['error']?.toString() ??
                'Could not provision your workspace. Please try again or contact support.';
            _isLoading = false;
          });
          return;
        }

        // 2. Persist credentials and session locally
        await _recordRegisteredUserLocally(
          email: email,
          name: name,
          uid: uid,
          role: 'Owner',
          tenantId: tenantId,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Agency "$agencyName" registered and launched!'),
              backgroundColor: const Color(0xFF059669),
              duration: const Duration(seconds: 3),
            ),
          );
          _executeLoginWithRole('Owner', tenantId: tenantId, uid: uid);
        }
        return;
      }

      final authResult = await _authService.authenticateUser(
        email: email,
        password: password,
      );

      if (authResult.isSuccess) {
        await _recordRegisteredUserLocally(
          email: email,
          name: authResult.name ?? email.split('@').first,
          uid: authResult.uid ?? 'usr_${email.hashCode}',
          role: authResult.role,
          tenantId: authResult.tenantId,
        );
        if (mounted) {
          _executeLoginWithRole(
            authResult.role,
            tenantId: authResult.tenantId,
            uid: authResult.uid,
            loadedTenant: authResult.tenant,
          );
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = authResult.errorMessage ?? 'Invalid email or password. Please verify credentials.';
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = AppError.message(e, action: 'sign you in'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 2. Email OTP Authentication
  Future<void> _handleSendEmailOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMessage = 'Please enter a valid email address');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _authService.sendEmailOtp(email);
      if (!mounted) return;
      if (res['success'] == true) {
        setState(() {
          _otpSent = true;
          _resendCountdown = 30;
          _otpController.clear();
        });

        _startCountdown();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('6-digit code sent to $email. Enter it below to sign in.'),
            backgroundColor: const Color(0xFF059669),
          ),
        );
      } else {
        setState(() => _errorMessage =
            res['message']?.toString() ?? 'Failed to send verification code.');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Error dispatching OTP.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _handleVerifyEmailOtp() async {
    final email = _emailController.text.trim();
    final otp = _otpController.text.trim();

    if (email.isEmpty) {
      setState(() => _errorMessage = 'Please enter your email address');
      return;
    }

    if (otp.length != 6 || int.tryParse(otp) == null) {
      setState(() => _errorMessage = 'Enter the 6-digit code from your email.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _authService.verifyEmailOtp(email: email, otp: otp);
      if (result.isSuccess) {
        await _recordRegisteredUserLocally(
          email: email,
          name: result.name ?? email.split('@').first,
          uid: result.uid ?? 'usr_${email.hashCode}',
          role: result.role,
          tenantId: result.tenantId,
        );
        if (mounted) {
          _executeLoginWithRole(
            result.role,
            tenantId: result.tenantId,
            uid: result.uid,
            loadedTenant: result.tenant,
          );
        }
      } else {
        if (mounted) {
          setState(() => _errorMessage = result.errorMessage ?? 'Invalid verification code');
        }
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = AppError.message(e, action: 'verify the code'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 3. Google Sign-In / Sign-Up
  Future<void> _handleGoogleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _googleFlowInProgress = true;
      final result = await _authService.signInWithGoogle();
      _googleFlowInProgress = false;
      await _applyGoogleResult(result);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Google sign-in is unavailable. Please sign in with your email.';
        });
      }
    } finally {
      _googleFlowInProgress = false;
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Routes a finished Google sign-in: error message, agency onboarding for
  /// new users, or straight into the workspace for returning users.
  Future<void> _applyGoogleResult(GoogleAuthResult? result) async {
    {
      if (result == null || !result.isSuccess) {
        if (mounted) {
          setState(() {
            _errorMessage = result?.errorMessage ??
                'Google sign-in is unavailable. Please sign in with your email.';
          });
        }
        return;
      }

      final email = result.email ?? '';
      final name = result.displayName ?? (email.isNotEmpty ? email.split('@').first : 'Owner');

      // Brand-new Google user — collect agency details before provisioning.
      if (result.isNewUser || result.tenantId.isEmpty) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showAgencyOnboardingDialog(email: email, name: name);
        }
        return;
      }

      // Returning user — straight into their existing workspace.
      final targetRole = _mapDatabaseRoleToUiRole(result.role);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Signed in with Google as $name'),
            backgroundColor: const Color(0xFF059669),
          ),
        );
        _executeLoginWithRole(
          targetRole,
          tenantId: result.tenantId,
          uid: result.uid,
        );
      }
    }
  }

  void _showAgencyOnboardingDialog({required String email, required String name}) {
    final agencyController = TextEditingController();
    final cityController = TextEditingController();
    final phoneController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '🏢 Complete Agency Onboarding',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Set up your agency details to launch your distribution operations',
                style: TextStyle(fontSize: 12.5, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: agencyController,
                decoration: const InputDecoration(
                  labelText: 'Agency / Firm Name',
                  hintText: 'e.g. Apex Traders',
                  prefixIcon: Icon(Icons.store_rounded),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cityController,
                decoration: const InputDecoration(
                  labelText: 'City & Territory',
                  hintText: 'e.g. Mumbai',
                  prefixIcon: Icon(Icons.location_city_rounded),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Mobile Number',
                  hintText: 'e.g. +91 98765 43210',
                  prefixIcon: Icon(Icons.phone_rounded),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E56E2),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final bName = agencyController.text.trim();
                    final phoneVal = phoneController.text.trim();
                    final cityVal = cityController.text.trim();
                    if (bName.isEmpty || phoneVal.isEmpty || cityVal.isEmpty) {
                      showAppError(ctx, 'Agency name, mobile, and city are all required.');
                      return;
                    }
                    Navigator.pop(ctx);
                    setState(() => _isLoading = true);
                    // The Google OAuth session already exists — just create the
                    // agency for this signed-in user (no password involved).
                    final regRes = await SupabaseService.instance.onboardCurrentUserAsOwner(
                      businessName: bName,
                      contactPerson: name,
                      mobile: phoneVal,
                      city: cityVal,
                    );
                    final tenantId = regRes['tenantId']?.toString() ?? '';
                    final uid = regRes['uid']?.toString() ?? '';
                    if (regRes['success'] != true || tenantId.isEmpty || uid.isEmpty) {
                      if (mounted) {
                        setState(() => _isLoading = false);
                        showAppError(context, regRes['error']?.toString() ?? 'Could not provision workspace. Please try again.');
                      }
                      return;
                    }
                    await _recordRegisteredUserLocally(
                      email: email,
                      name: name,
                      uid: uid,
                      role: 'Owner',
                      tenantId: tenantId,
                    );
                    if (mounted) {
                      setState(() => _isLoading = false);
                      _executeLoginWithRole('Owner', tenantId: tenantId, uid: uid);
                    }
                  },
                  child: const Text('Complete Onboarding & Launch', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textHeading = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSub = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final inputBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: primaryBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Brand Header
                  Center(
                    child: Container(
                      width: 84,
                      height: 84,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: borderCol),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/SalesArmy Logo 2.png',
                        fit: BoxFit.contain,
                        semanticLabel: 'SalesArmy',
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.star_rounded,
                          size: 44,
                          color: Color(0xFFFFCC00),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'SalesArmy',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: textHeading,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isSignUpMode ? 'Create an account to get started' : 'Sign in to access your business operations',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: textSub,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Main Clean Card
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderCol),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Error Banner
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      color: Color(0xFFEF4444),
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Mode Selector: Password vs Email OTP
                        Container(
                          height: 42,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: inputBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setState(() {
                                      _selectedTab = 0;
                                      _errorMessage = null;
                                    });
                                  },
                                  child: Container(
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: _selectedTab == 0 ? cardBg : Colors.transparent,
                                      borderRadius: BorderRadius.circular(9),
                                      boxShadow: _selectedTab == 0
                                          ? [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.08),
                                                blurRadius: 4,
                                                offset: const Offset(0, 1),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.lock_outline_rounded,
                                          size: 15,
                                          color: _selectedTab == 0 ? const Color(0xFF1E56E2) : textSub,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Password',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: _selectedTab == 0 ? FontWeight.w800 : FontWeight.w600,
                                            color: _selectedTab == 0 ? textHeading : textSub,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setState(() {
                                      _selectedTab = 1;
                                      _errorMessage = null;
                                    });
                                  },
                                  child: Container(
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: _selectedTab == 1 ? cardBg : Colors.transparent,
                                      borderRadius: BorderRadius.circular(9),
                                      boxShadow: _selectedTab == 1
                                          ? [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.08),
                                                blurRadius: 4,
                                                offset: const Offset(0, 1),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.mark_email_read_outlined,
                                          size: 15,
                                          color: _selectedTab == 1 ? const Color(0xFF1E56E2) : textSub,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Email OTP',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: _selectedTab == 1 ? FontWeight.w800 : FontWeight.w600,
                                            color: _selectedTab == 1 ? textHeading : textSub,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Agency Onboarding Fields (Only in Sign Up Mode)
                        if (_isSignUpMode) ...[
                          Text(
                            'Agency / Firm Name',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: textHeading,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _agencyNameController,
                            style: TextStyle(fontSize: 14, color: textHeading),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: inputBg,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                              prefixIcon: Icon(Icons.store_rounded, size: 18, color: textSub),
                              hintText: 'e.g. Shree Ganesh Traders',
                              hintStyle: TextStyle(fontSize: 13, color: textSub.withValues(alpha: 0.7)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: borderCol),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: borderCol),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFF1E56E2), width: 1.5),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          Text(
                            'Owner / Representative Name',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: textHeading,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _nameController,
                            style: TextStyle(fontSize: 14, color: textHeading),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: inputBg,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                              prefixIcon: Icon(Icons.person_outline_rounded, size: 18, color: textSub),
                              hintText: 'John Doe',
                              hintStyle: TextStyle(fontSize: 13, color: textSub.withValues(alpha: 0.7)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: borderCol),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: borderCol),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFF1E56E2), width: 1.5),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Mobile Number',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: textHeading,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: _phoneController,
                                      keyboardType: TextInputType.phone,
                                      style: TextStyle(fontSize: 14, color: textHeading),
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: inputBg,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                                        prefixIcon: Icon(Icons.phone_outlined, size: 18, color: textSub),
                                        hintText: '+91 9876543210',
                                        hintStyle: TextStyle(fontSize: 13, color: textSub.withValues(alpha: 0.7)),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(color: borderCol),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(color: borderCol),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: const BorderSide(color: Color(0xFF1E56E2), width: 1.5),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'City',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: textHeading,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: _cityController,
                                      style: TextStyle(fontSize: 14, color: textHeading),
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: inputBg,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                                        prefixIcon: Icon(Icons.location_city_rounded, size: 18, color: textSub),
                                        hintText: 'Mumbai',
                                        hintStyle: TextStyle(fontSize: 13, color: textSub.withValues(alpha: 0.7)),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(color: borderCol),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(color: borderCol),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: const BorderSide(color: Color(0xFF1E56E2), width: 1.5),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Email Field (Common to both modes)
                        Text(
                          'Email Address',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: textHeading,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: TextStyle(fontSize: 14, color: textHeading),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: inputBg,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                            prefixIcon: Icon(Icons.mail_outline_rounded, size: 18, color: textSub),
                            hintText: 'user@company.com',
                            hintStyle: TextStyle(fontSize: 13, color: textSub.withValues(alpha: 0.7)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: borderCol),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: borderCol),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF1E56E2), width: 1.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Form content based on selected tab:
                        if (_selectedTab == 0) ...[
                          // Password Field
                          Text(
                            'Password',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: textHeading,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: TextStyle(fontSize: 14, color: textHeading),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: inputBg,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                              prefixIcon: Icon(Icons.lock_outline_rounded, size: 18, color: textSub),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  size: 18,
                                  color: textSub,
                                ),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                              hintText: '••••••••',
                              hintStyle: TextStyle(fontSize: 14, color: textSub.withValues(alpha: 0.7)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: borderCol),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: borderCol),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFF1E56E2), width: 1.5),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Submit Action: Email & Password
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleEmailPasswordAuth,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E56E2),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : Text(
                                      _isSignUpMode ? 'Register Agency & Launch' : 'Sign In',
                                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                                    ),
                            ),
                          ),
                        ] else ...[
                          // Email OTP Tab
                          if (_otpSent) ...[
                            Text(
                              '6-digit code from your email',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: textHeading,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _otpController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              maxLength: 6,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              style: TextStyle(
                                fontSize: 18,
                                letterSpacing: 8,
                                fontWeight: FontWeight.w800,
                                color: textHeading,
                              ),
                              decoration: InputDecoration(
                                counterText: '',
                                filled: true,
                                fillColor: inputBg,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                                hintText: '123456',
                                hintStyle: TextStyle(
                                  fontSize: 16,
                                  letterSpacing: 8,
                                  color: textSub.withValues(alpha: 0.5),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: borderCol),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: borderCol),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFF1E56E2), width: 1.5),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Resend Code & Change Email Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                TextButton(
                                  onPressed: () => setState(() => _otpSent = false),
                                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                                  child: const Text('Change email', style: TextStyle(fontSize: 12)),
                                ),
                                _resendCountdown > 0
                                    ? Text(
                                        'Resend in ${_resendCountdown}s',
                                        style: TextStyle(fontSize: 12, color: textSub),
                                      )
                                    : TextButton(
                                        onPressed: _isLoading ? null : _handleSendEmailOtp,
                                        style: TextButton.styleFrom(padding: EdgeInsets.zero),
                                        child: const Text('Resend code', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                      ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Submit Action: Verify OTP
                            SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _handleVerifyEmailOtp,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF059669),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : Text(
                                        _isSignUpMode ? 'Verify & Register' : 'Verify & Sign In',
                                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                                      ),
                              ),
                            ),
                          ] else ...[
                            // Initial Send OTP Button
                            SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _handleSendEmailOtp,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E56E2),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
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
                                          Icon(Icons.send_rounded, size: 16),
                                          SizedBox(width: 8),
                                          Text(
                                            'Send Verification Code',
                                            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ],
                        ],

                        const SizedBox(height: 20),

                        // Minimal Divider
                        Row(
                          children: [
                            Expanded(child: Divider(color: borderCol)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'OR',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: textSub,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            Expanded(child: Divider(color: borderCol)),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Google Authentication Button
                        SizedBox(
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: _isLoading ? null : _handleGoogleLogin,
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: borderCol, width: 1.2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: SvgPicture.asset(
                              'assets/google_g_logo.svg',
                              width: 20,
                              height: 20,
                              semanticsLabel: 'Google',
                            ),
                            label: Text(
                              _isSignUpMode ? 'Sign up with Google' : 'Continue with Google',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: textHeading,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Bottom Mode Switcher
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isSignUpMode ? 'Already have an account?' : "Don't have an account?",
                        style: TextStyle(fontSize: 13, color: textSub),
                      ),
                      const SizedBox(width: 4),
                      TextButton(
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _isSignUpMode = !_isSignUpMode;
                            _errorMessage = null;
                            _otpSent = false;
                          });
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          _isSignUpMode ? 'Sign In' : 'Sign Up',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E56E2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
