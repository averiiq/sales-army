import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:salesarmy/features/auth/data/models/user_model.dart';
import 'package:salesarmy/features/admin/data/models/tenant_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;
import 'package:salesarmy/core/services/supabase_service.dart';
import 'package:salesarmy/core/utils/app_error.dart';

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
    if (!await SupabaseService.instance.ensureInitialized()) {
      return AppAuthResult.failure(
        SupabaseService.unreachableMessage,
      );
    }
    supa.AuthResponse? res;
    try {
      res = await SupabaseService.instance.signInWithEmailPassword(
        email: cleanEmail,
        password: cleanPassword,
      );
    } catch (e) {
      debugPrint('Supabase signInWithEmailPassword failed: $e');
      // Report the real reason: wrong password, unconfirmed email, no network…
      // (no auto-creating accounts and no offline bypass).
      return AppAuthResult.failure(AppError.message(e, action: 'sign you in'));
    }

    if (res?.user != null) {
      return _buildAuthResultFromSupabase(res!.user!, cleanEmail, res.session?.accessToken);
    }
    return AppAuthResult.failure('Incorrect email or password.');
  }

  Future<AppAuthResult> _buildAuthResultFromSupabase(
    supa.User user,
    String cleanEmail,
    String? accessToken,
  ) async {
    final uid = user.id;
    var profile = await SupabaseService.instance.fetchUserProfile(uid);

    // No agency yet (e.g. first login after confirming the sign-up email):
    // finish onboarding from the details saved at sign-up. Role and tenant are
    // never taken from user metadata, which the user can edit.
    if (profile == null || profile['tenant_id'] == null || profile['tenant_id'].toString().isEmpty) {
      final pending = await SupabaseService.instance.takePendingAgency(cleanEmail);
      if (pending == null) {
        await SupabaseService.instance.signOut();
        return AppAuthResult.failure(
          'Your account is not linked to an agency yet. Please use Sign Up to register your agency, or ask your agency owner to add you.',
        );
      }
      final onboard = await SupabaseService.instance.onboardCurrentUserAsOwner(
        businessName: pending['businessName']?.toString() ?? '',
        contactPerson: pending['contactPerson']?.toString() ?? cleanEmail.split('@').first,
        mobile: pending['mobile']?.toString() ?? '',
        city: pending['city']?.toString() ?? '',
        gstin: pending['gstin']?.toString(),
      );
      if (onboard['success'] != true) {
        await SupabaseService.instance.signOut();
        return AppAuthResult.failure(onboard['error']?.toString() ?? 'Could not finish setting up your agency.');
      }
      await SupabaseService.instance.clearPendingAgency(cleanEmail);
      profile = await SupabaseService.instance.fetchUserProfile(uid);
      if (profile == null) {
        await SupabaseService.instance.signOut();
        return AppAuthResult.failure('Your agency was created, but your profile could not be loaded. Please sign in again.');
      }
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

    if (!await SupabaseService.instance.ensureInitialized()) {
      return {'success': false, 'message': SupabaseService.unreachableMessage};
    }
    try {
      await SupabaseService.instance.sendEmailOtp(email: cleanEmail);
    } catch (e) {
      // Previously swallowed and reported as "sent" — now the user sees why.
      debugPrint('sendEmailOtp failed: $e');
      return {'success': false, 'message': AppError.message(e, action: 'send the code')};
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
    if (!await SupabaseService.instance.ensureInitialized()) {
      return AppAuthResult.failure(SupabaseService.unreachableMessage);
    }
    try {
      final authRes = await SupabaseService.instance.verifyEmailOtp(
        email: cleanEmail,
        token: cleanOtp,
      );
      verifiedUser = authRes?.user;
      accessToken = authRes?.session?.accessToken;
    } catch (e) {
      debugPrint('Supabase verifyEmailOtp failed: $e');
      final msg = e.toString().toLowerCase();
      if (!(msg.contains('expired') || msg.contains('invalid') || msg.contains('token'))) {
        return AppAuthResult.failure(AppError.message(e, action: 'verify the code'));
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
    if (!await supabase.ensureInitialized()) {
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
      sub = client.auth.onAuthStateChange.listen(
        (state) {
          if (state.event == supa.AuthChangeEvent.signedIn && state.session?.user != null) {
            if (!completer.isCompleted) completer.complete(state.session!.user);
          }
        },
        // The SDK reports a failed code exchange (expired link, no network,
        // blocked redirect) as a stream error — surface it instead of hanging.
        onError: (Object e) {
          if (!completer.isCompleted) completer.completeError(e);
        },
      );

      // Already signed in (e.g. the redirect was processed before we
      // subscribed): use that session straight away.
      final existing = client.auth.currentSession?.user;
      if (existing != null && existing.appMetadata['provider'] == 'google') {
        await sub.cancel();
        return completeGoogleSignIn(existing);
      }

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
      return completeGoogleSignIn(user);
    } on supa.AuthException catch (e) {
      debugPrint('Google Sign-In auth error: ${e.message}');
      return GoogleAuthResult.failure(_googleErrorMessage(e.message));
    } catch (e) {
      debugPrint('Google Sign-In error: $e');
      return GoogleAuthResult.failure(_googleErrorMessage(e.toString()));
    }
  }

  static String _googleErrorMessage(String raw) {
    final m = raw.toLowerCase();
    if (m.contains('socket') || m.contains('network') || m.contains('failed host lookup') || m.contains('timed out')) {
      return 'Google sign-in could not reach the server. Check your internet connection and try again.';
    }
    if (m.contains('code verifier') || m.contains('flow state') || m.contains('expired') || m.contains('invalid')) {
      return 'The Google sign-in link expired. Please tap "Continue with Google" again.';
    }
    return 'Google sign-in could not be completed ($raw). Please try again.';
  }

  /// Finishes a Google sign-in once Supabase has a session for [user]:
  /// returning users get their workspace, new users go to agency onboarding.
  /// Also used when the app is (re)opened by the Google redirect.
  Future<GoogleAuthResult> completeGoogleSignIn(supa.User user) async {
    final supabase = SupabaseService.instance;
    try {
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
      debugPrint('Google Sign-In profile lookup error: $e');
      return GoogleAuthResult.failure(_googleErrorMessage(e.toString()));
    }
  }
}
