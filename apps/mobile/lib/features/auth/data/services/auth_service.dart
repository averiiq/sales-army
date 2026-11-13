import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:salesarmy/features/auth/data/models/user_model.dart';
import 'package:salesarmy/features/admin/data/models/tenant_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;
import 'package:salesarmy/core/services/supabase_service.dart';

class AppAuthResult {
  final bool isSuccess;
  final String? uid;
  final String? email;
  final String? name;
  final String role;
  final String tenantId;
  final String? token;
  final String? errorMessage;
  final TenantModel? tenant;
  final Map<String, dynamic>? profile;

  const AppAuthResult({
    required this.isSuccess,
    this.uid,
    this.email,
    this.name,
    this.role = 'unassigned',
    this.tenantId = '',
    this.token,
    this.errorMessage,
    this.tenant,
    this.profile,
  });

  factory AppAuthResult.success({
    required String uid,
    required String email,
    String? name,
    required String role,
    required String tenantId,
    String? token,
    TenantModel? tenant,
    Map<String, dynamic>? profile,
  }) {
    return AppAuthResult(
      isSuccess: true,
      uid: uid,
      email: email,
      name: name,
      role: role,
      tenantId: tenantId,
      token: token,
      tenant: tenant,
      profile: profile,
    );
  }

  factory AppAuthResult.failure(String message) {
    return AppAuthResult(
      isSuccess: false,
      errorMessage: message,
    );
  }
}

class GoogleAuthResult {
  final bool isSuccess;
  final String? uid;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final String role;
  final String tenantId;
  final String? errorMessage;
  final bool isNewUser;

  const GoogleAuthResult({
    required this.isSuccess,
    this.uid,
    this.email,
    this.displayName,
    this.photoUrl,
    this.role = 'unassigned',
    this.tenantId = '',
    this.errorMessage,
    this.isNewUser = false,
  });

  factory GoogleAuthResult.success({
    required String uid,
    required String email,
    String? displayName,
    String? photoUrl,
    required String role,
    required String tenantId,
    bool isNewUser = false,
  }) {
    return GoogleAuthResult(
      isSuccess: true,
      uid: uid,
      email: email,
      displayName: displayName,
      photoUrl: photoUrl,
      role: role,
      tenantId: tenantId,
      isNewUser: isNewUser,
    );
  }

  factory GoogleAuthResult.failure(String message) {
    return GoogleAuthResult(
      isSuccess: false,
      errorMessage: message,
    );
  }
}

/// Minimal credential returned by [AuthService.signInWithEmailPassword].
/// Mirrors just the `.user.uid` surface the few remaining callers rely on.
class AuthCredential {
  final AuthUser? user;
  const AuthCredential({this.user});
}

class AuthUser {
  final String uid;
  final String? email;
  final String? displayName;
  const AuthUser({required this.uid, this.email, this.displayName});
}

class AuthService {
  static const bool demoMode = false;

  AuthService();

  static String mapDbRoleToAppRole(String? dbRole, [String? email]) {
    if (dbRole == null || dbRole.isEmpty) return 'unassigned';
    final r = dbRole.toLowerCase().trim();
    if (r == 'super_admin' || r == 'super admin') return 'super_admin';
    if (r == 'owner' || r == 'distributor') return 'Owner';
    if (r == 'sales_person' || r.contains('sales')) return 'Field Sales';
    if (r == 'delivery_agent' || r.contains('deliver')) return 'Delivery Staff';
    if (r == 'manager' || r.contains('store') || r.contains('warehouse')) return 'Store Manager';
    if (r == 'accountant' || r.contains('account')) return 'Accountant';
    return 'unassigned';
  }

  /// Sign out of all authentication sources.
  Future<void> signOut() async {
    try {
      await SupabaseService.instance.signOut();
    } catch (_) {}
  }

  /// Low-level email+password sign in used by super-admin login flow. Returns
  /// an [AuthCredential] when sign-in succeeds, or null when it does not.
  Future<AuthCredential?> signInWithEmailPassword(String email, String password) async {
    if (!SupabaseService.instance.isInitialized) return null;
    try {
      final res = await SupabaseService.instance.signInWithEmailPassword(
        email: email,
        password: password,
      );
      final user = res?.user;
      if (user == null) return null;
      return AuthCredential(
        user: AuthUser(
          uid: user.id,
          email: user.email,
          displayName: user.userMetadata?['name']?.toString(),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  /// Fetch a user profile from Supabase.
  Future<UserModel?> getUserProfile(String uid) async {
    try {
      final profile = await SupabaseService.instance.fetchUserProfile(uid);
      if (profile != null) {
        return UserModel.fromMap(Map<String, dynamic>.from(profile), uid);
      }
    } catch (e) {
      debugPrint('getUserProfile error: $e');
    }
    return null;
  }

  /// Multi-tier authenticator — now Supabase-only with a local-registered-users
  /// fallback and a demo-credential safety net preserved for QA.
  Future<AppAuthResult> authenticateUser({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanPassword = password.trim();

    if (cleanEmail.isEmpty || cleanPassword.isEmpty) {
      return AppAuthResult.failure('Please enter both email and password.');
    }

    // 1. Supabase Cloud Authentication (with auto-heal + auto-provision)
    if (SupabaseService.instance.isInitialized) {
      supa.AuthResponse? res;
      try {
        res = await SupabaseService.instance.signInWithEmailPassword(
          email: cleanEmail,
          password: cleanPassword,
        );
      } catch (e) {
        if (kDebugMode) debugPrint('Supabase signInWithEmailPassword attempt: $e');
        // Login failed — do NOT auto-create accounts. Users must register explicitly.
      }

      if (res?.user != null) {
        return _buildAuthResultFromSupabase(res!.user!, cleanEmail, res.session?.accessToken);
      }
    }

    // If Supabase is unreachable or authentication failed, fail cleanly
    // without insecure plaintext bypasses or unauthenticated mock sessions (Audit C-2, H-5 fix).
    return AppAuthResult.failure('Invalid email or password, or authentication server unreachable. Please verify credentials.');
  }

  Future<AppAuthResult> _buildAuthResultFromSupabase(
    supa.User user,
    String cleanEmail,
    String? accessToken,
  ) async {
    final uid = user.id;
    var profile = await SupabaseService.instance.fetchUserProfile(uid);

    if (profile == null) {
      final autoRole = user.userMetadata?['role']?.toString() ?? 'Owner';
      final autoTenant = user.userMetadata?['tenant_id']?.toString() ?? '';
      final autoName = user.userMetadata?['name']?.toString() ?? cleanEmail.split('@').first;
      if (autoTenant.isEmpty) {
        await SupabaseService.instance.signOut();
        return AppAuthResult.failure('Your account is not linked to a workspace. Please sign up to onboard your agency.');
      }
      profile = {
        'id': uid,
        'email': cleanEmail,
        'name': autoName,
        'role': autoRole,
        'tenant_id': autoTenant,
        'is_active': true,
        'account_status': 'active',
      };
      try {
        await SupabaseService.instance.upsertUserProfile(
          uid: uid,
          email: cleanEmail,
          name: autoName,
          role: autoRole,
          tenantId: autoTenant,
        );
      } catch (_) {}
    } else if (profile['tenant_id'] == null || profile['tenant_id'].toString().isEmpty) {
      await SupabaseService.instance.signOut();
      return AppAuthResult.failure('Your account is not linked to a workspace. Please sign up to onboard your agency.');
    }

    if (profile['is_active'] == false ||
        profile['account_status'] == 'suspended' ||
        profile['account_status'] == 'banned' ||
        profile['account_status'] == 'deactivated') {
      await SupabaseService.instance.signOut();
      return AppAuthResult.failure('Your account has been deactivated. Please contact administrator.');
    }

    final dbRole = profile['role']?.toString() ?? 'owner';
    final role = mapDbRoleToAppRole(dbRole, cleanEmail);
    final tenantId = profile['tenant_id']?.toString() ??
        (role == 'super_admin' ? 'platform_tenant' : '');

    if (tenantId.isEmpty) {
      await SupabaseService.instance.signOut();
      return AppAuthResult.failure('Your workspace is not configured. Please contact your administrator.');
    }

    TenantModel? loadedTenant;
    try {
      final tMap = await SupabaseService.instance.fetchTenant(tenantId);
      if (tMap != null) loadedTenant = TenantModel.fromMap(tMap, tenantId);
    } catch (_) {}

    return AppAuthResult.success(
      uid: uid,
      email: user.email ?? cleanEmail,
      name: profile['name']?.toString() ?? user.userMetadata?['name']?.toString() ?? cleanEmail.split('@').first,
      role: role == 'unassigned' ? 'Owner' : role,
      tenantId: tenantId,
      token: accessToken,
      tenant: loadedTenant,
      profile: profile,
    );
  }

  Future<Map<String, dynamic>> sendEmailOtp(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      return {'success': false, 'message': 'Please enter a valid email address.'};
    }

    if (SupabaseService.instance.isInitialized) {
      try {
        await SupabaseService.instance.sendEmailOtp(email: cleanEmail);
      } catch (e) {
        debugPrint('sendEmailOtp notice: $e');
      }
    }
    return {'success': true, 'message': 'Verification code dispatched to $cleanEmail'};
  }

  Future<AppAuthResult> verifyEmailOtp({
    required String email,
    required String otp,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanOtp = otp.trim();

    if (cleanEmail.isEmpty || cleanOtp.isEmpty) {
      return AppAuthResult.failure('Please enter your email and verification code.');
    }

    supa.User? verifiedUser;
    String? accessToken;

    // Verify OTP strictly through Supabase — no bypass codes in production.
    if (SupabaseService.instance.isInitialized) {
      try {
        final authRes = await SupabaseService.instance.verifyEmailOtp(
          email: cleanEmail,
          token: cleanOtp,
        );
        verifiedUser = authRes?.user;
        accessToken = authRes?.session?.accessToken;
      } catch (e) {
        if (kDebugMode) debugPrint('Supabase verifyEmailOtp token note: $e');
      }
    }

    if (verifiedUser != null) {
      return _buildAuthResultFromSupabase(verifiedUser, cleanEmail, accessToken);
    }

    return AppAuthResult.failure('Invalid or expired verification code. Please request a new code.');
  }

  /// Google Sign-In via Supabase OAuth browser flow.
  ///
  /// Flow:
  ///  1. [SupabaseService.signInWithGoogleOAuth] launches the system browser
  ///     pointed at Supabase's Google OAuth URL.
  ///  2. User authenticates with Google in the browser.
  ///  3. Supabase redirects back to the app via the `io.supabase.salesarmy`
  ///     deep link (see AndroidManifest.xml intent-filter).
  ///  4. The Supabase SDK catches the deep link and fires an
  ///     `AuthChangeEvent.signedIn` on `authStateChanges`.
  ///  5. We await that event here (up to 2 minutes) and then resolve the
  ///     user's profile to decide if agency onboarding is still needed.
  ///
  /// Prerequisites — see [SupabaseService.oauthRedirectUri] for the dashboard
  /// configuration that must exist in Supabase and Google Cloud Console.
  Future<GoogleAuthResult?> signInWithGoogle() async {
    final supabase = SupabaseService.instance;
    if (!supabase.isInitialized) {
      return GoogleAuthResult.failure(
        'Cloud sign-in is unavailable. Please check your connection and try again.',
      );
    }
    final client = supabase.client;
    if (client == null) {
      return GoogleAuthResult.failure(
        'Cloud sign-in is unavailable. Please check your connection and try again.',
      );
    }

    try {
      // Future that completes when the Supabase SDK posts a signedIn event
      // (triggered when the deep-link redirect hits the app).
      final completer = Completer<supa.User?>();
      late final StreamSubscription<supa.AuthState> sub;
      sub = client.auth.onAuthStateChange.listen((state) {
        if (state.event == supa.AuthChangeEvent.signedIn && state.session?.user != null) {
          if (!completer.isCompleted) completer.complete(state.session!.user);
        }
      });

      final launched = await supabase.signInWithGoogleOAuth();
      if (!launched) {
        await sub.cancel();
        return GoogleAuthResult.failure(
          'Could not open Google sign-in. Please check your browser and try again.',
        );
      }

      final user = await completer.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () => null,
      );
      await sub.cancel();

      if (user == null) {
        return GoogleAuthResult.failure(
          'Google sign-in was cancelled or timed out. Please try again.',
        );
      }

      final email = (user.email ?? '').trim().toLowerCase();
      final meta = user.userMetadata ?? const <String, dynamic>{};
      final displayName = (meta['name'] ?? meta['full_name'] ?? '').toString().trim();
      final photoUrl = (meta['avatar_url'] ?? meta['picture'] ?? '').toString();
      final effectiveName = displayName.isNotEmpty
          ? displayName
          : (email.isNotEmpty ? email.split('@').first : 'Owner');

      // Look up an existing profile — if found, this is a returning user and
      // we route them straight into their existing workspace. Supabase links
      // the Google identity to any pre-existing `auth.users` row with the
      // same email, so email signups + Google logins share the same uid.
      final profile = await supabase.fetchUserProfile(user.id);
      if (profile != null && profile['tenant_id'] != null) {
        final tenantId = profile['tenant_id'].toString();
        final role = mapDbRoleToAppRole(profile['role']?.toString(), email);
        return GoogleAuthResult.success(
          uid: user.id,
          email: email,
          displayName: profile['name']?.toString() ?? effectiveName,
          photoUrl: photoUrl.isNotEmpty ? photoUrl : null,
          role: role,
          tenantId: tenantId,
        );
      }

      // No profile yet → brand new user. Caller must show the agency
      // onboarding dialog and finish provisioning via
      // SupabaseService.registerAgencyOwnerAndSeed.
      return GoogleAuthResult.success(
        uid: user.id,
        email: email,
        displayName: effectiveName,
        photoUrl: photoUrl.isNotEmpty ? photoUrl : null,
        role: 'Owner',
        tenantId: '',
        isNewUser: true,
      );
    } catch (e) {
      debugPrint('Google Sign-In error: $e');
      return GoogleAuthResult.failure(
        'Google sign-in failed. Please sign in with your email instead.',
      );
    }
  }
}
