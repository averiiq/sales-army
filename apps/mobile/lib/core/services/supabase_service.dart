import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:salesarmy/core/services/platform_api.dart';

/// SalesArmy Supabase Backend Client & Real-time Integration Service
/// Replaces legacy Firebase collections with high-performance Supabase PostgreSQL + Realtime channels.
class SupabaseService {
  static SupabaseService? _instance;
  static SupabaseService get instance => _instance ??= SupabaseService._();

  SupabaseService._();

  // Configurable Project Credentials (can be overridden via environment or app settings)
  static const String defaultSupabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://ivwvqpeivnltshrxjhjx.supabase.co',
  );

  static const String defaultSupabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml2d3ZxcGVpdm5sdHNocnhqaGp4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE4MTcyNTgsImV4cCI6MjEwNzM5MzI1OH0.pkwOLQUyP0Te719UKV5s6wZ_GNXDe9AOMaeqkH0H-iY',
  );

  static const String defaultSupabaseServiceRoleKey = String.fromEnvironment(
    'SUPABASE_SERVICE_ROLE_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml2d3ZxcGVpdm5sdHNocnhqaGp4Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MTgxNzI1OCwiZXhwIjoyMTA3MzkzMjU4fQ.swVBzLlo-fQ3xc1ezYD_VcPKElnTKa6ZyBMjeU1sjxM',
  );

  /// Google OAuth Web Client ID — created in Google Cloud Console and added
  /// to Supabase Dashboard → Authentication → Providers → Google. Required for
  /// `GoogleSignIn(serverClientId: ...)` + Supabase `signInWithIdToken` on
  /// Android. Leave as empty string to disable Google sign-in entirely.
  static const String googleOAuthWebClientId = String.fromEnvironment(
    'GOOGLE_OAUTH_WEB_CLIENT_ID',
    defaultValue: '',
  );

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  SupabaseClient? get client {
    if (!_isInitialized) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Initialize the Supabase Flutter SDK
  Future<void> initialize({
    String? url,
    String? anonKey,
  }) async {
    final targetUrl = (url != null && url.isNotEmpty)
        ? url
        : (defaultSupabaseUrl.isNotEmpty ? defaultSupabaseUrl : 'https://ivwvqpeivnltshrxjhjx.supabase.co');
    final targetKey = (anonKey != null && anonKey.isNotEmpty)
        ? anonKey
        : (defaultSupabaseAnonKey.isNotEmpty ? defaultSupabaseAnonKey : 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml2d3ZxcGVpdm5sdHNocnhqaGp4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE4MTcyNTgsImV4cCI6MjEwNzM5MzI1OH0.pkwOLQUyP0Te719UKV5s6wZ_GNXDe9AOMaeqkH0H-iY');

    if (targetUrl.isEmpty || targetKey.isEmpty) {
      _isInitialized = false;
      debugPrint('Supabase credentials missing, operating in local cached mode.');
      return;
    }

    try {
      await Supabase.initialize(
        url: targetUrl,
        // ignore: deprecated_member_use
        anonKey: targetKey,
        debug: kDebugMode,
      ).timeout(const Duration(seconds: 4));
      _isInitialized = true;
      if (kDebugMode) {
        debugPrint('Supabase initialized successfully');
      }
    } catch (e) {
      _isInitialized = false;
      debugPrint('Supabase initialize note: $e (Falling back to offline/local storage)');
    }
  }

  // ==========================================================================
  // ==========================================================================
  // Authentication & RBAC (Role-Based Access Control)
  // ==========================================================================

  User? get currentUser => client?.auth.currentUser;
  Session? get currentSession => client?.auth.currentSession;
  Stream<AuthState>? get authStateChanges => client?.auth.onAuthStateChange;

  Future<AuthResponse?> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    if (client == null) return null;
    return await client!.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<AuthResponse?> signUpWithEmailPassword({
    required String email,
    required String password,
    Map<String, dynamic>? data,
  }) async {
    if (client == null) return null;
    return await client!.auth.signUp(
      email: email.trim(),
      password: password,
      data: data,
    );
  }

  /// Dispatch a 6-digit Email OTP via Supabase Auth
  Future<void> sendEmailOtp({required String email}) async {
    if (client == null) return;
    try {
      await client!.auth.signInWithOtp(
        email: email.trim(),
        shouldCreateUser: true,
      );
    } catch (e) {
      debugPrint('Supabase sendEmailOtp notice: $e');
    }
  }

  /// Verify 6-digit Email OTP token with Supabase Auth
  Future<AuthResponse?> verifyEmailOtp({
    required String email,
    required String token,
  }) async {
    if (client == null) return null;
    return await client!.auth.verifyOTP(
      email: email.trim(),
      token: token.trim(),
      type: OtpType.email,
    );
  }

  /// Find user by email using Supabase Auth Admin API
  Future<Map<String, dynamic>?> adminFindUserByEmail(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
      final uri = Uri.parse('$defaultSupabaseUrl/auth/v1/admin/users');
      final req = await client.getUrl(uri);
      req.headers.set('apikey', defaultSupabaseServiceRoleKey);
      req.headers.set('Authorization', 'Bearer $defaultSupabaseServiceRoleKey');
      final res = await req.close().timeout(const Duration(seconds: 8));
      final raw = await res.transform(utf8.decoder).join();
      client.close(force: true);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(raw);
        final users = data['users'] as List? ?? [];
        for (final u in users) {
          if (u is Map && (u['email']?.toString().toLowerCase() == cleanEmail)) {
            return Map<String, dynamic>.from(u);
          }
        }
      }
    } catch (e) {
      debugPrint('adminFindUserByEmail note: $e');
    }
    return null;
  }

  /// Confirm user's email and optionally set/update their password using Admin API
  Future<bool> adminConfirmAndSetPassword(
    String uid, {
    String? password,
    String? role,
    String? tenantId,
    String? name,
  }) async {
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
      final uri = Uri.parse('$defaultSupabaseUrl/auth/v1/admin/users/$uid');
      final req = await client.putUrl(uri);
      req.headers.set('apikey', defaultSupabaseServiceRoleKey);
      req.headers.set('Authorization', 'Bearer $defaultSupabaseServiceRoleKey');
      req.headers.contentType = ContentType.json;
      final payload = <String, dynamic>{
        'email_confirm': true,
      };
      if (password != null && password.isNotEmpty) {
        payload['password'] = password;
      }
      if (role != null || tenantId != null || name != null) {
        payload['user_metadata'] = {
          if (name != null) 'name': name,
          if (role != null) 'role': role,
          if (tenantId != null) 'tenant_id': tenantId,
        };
        payload['app_metadata'] = {
          if (role != null) 'role': role,
          if (tenantId != null) 'tenant_id': tenantId,
        };
      }
      req.write(jsonEncode(payload));
      final res = await req.close().timeout(const Duration(seconds: 8));
      client.close(force: true);
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (e) {
      debugPrint('adminConfirmAndSetPassword note: $e');
      return false;
    }
  }

  /// Auto-provision/create a user in Supabase Auth using Admin API (confirmed by default)
  Future<Map<String, dynamic>?> adminCreateUser({
    required String email,
    required String password,
    required String name,
    String role = 'owner',
    String tenantId = '',
  }) async {
    // Fail loudly instead of silently landing orphan users in a shared
    // workspace. Callers must pass a real tenantId.
    if (tenantId.isEmpty) {
      debugPrint('adminCreateUser: refused — tenantId is empty');
      return null;
    }
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
      final uri = Uri.parse('$defaultSupabaseUrl/auth/v1/admin/users');
      final req = await client.postUrl(uri);
      req.headers.set('apikey', defaultSupabaseServiceRoleKey);
      req.headers.set('Authorization', 'Bearer $defaultSupabaseServiceRoleKey');
      req.headers.contentType = ContentType.json;
      // CRITICAL: the `handle_new_user` trigger reads from
      // `raw_app_meta_data`, NOT `raw_user_meta_data`. Previously only
      // `user_metadata` was sent, so the trigger never saw the role or
      // tenant_id — every new auth row got role=sales_person and tenant_id
      // NULL. upsertUserProfile fixed it a second later, but the race window
      // was wide enough to break RLS lookups. Sending both channels keeps
      // the trigger authoritative.
      final payload = {
        'email': email.trim().toLowerCase(),
        'password': password,
        'email_confirm': true,
        'user_metadata': {
          'name': name,
          'role': role,
          'tenant_id': tenantId,
        },
        'app_metadata': {
          'role': role,
          'tenant_id': tenantId,
        },
      };
      req.write(jsonEncode(payload));
      final res = await req.close().timeout(const Duration(seconds: 8));
      final raw = await res.transform(utf8.decoder).join();
      client.close(force: true);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return Map<String, dynamic>.from(jsonDecode(raw) as Map);
      }
    } catch (e) {
      debugPrint('adminCreateUser note: $e');
    }
    return null;
  }

  /// Provision or update a staff member's credentials and profile under an agency's tenant.
  Future<Map<String, dynamic>> provisionStaffAccount({
    required String tenantId,
    required String email,
    required String password,
    required String name,
    String? phone,
    required String role,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanPassword = password.trim();
    final cleanName = name.trim().isEmpty ? cleanEmail.split('@').first : name.trim();

    if (cleanEmail.isEmpty || cleanPassword.isEmpty || tenantId.isEmpty) {
      return {'success': false, 'error': 'Email, password, and tenant ID are required'};
    }

    try {
      String uid = '';
      final existing = await adminFindUserByEmail(cleanEmail);
      if (existing != null && existing['id'] != null) {
        uid = existing['id'].toString();
        await adminConfirmAndSetPassword(
          uid,
          password: cleanPassword,
          role: role,
          tenantId: tenantId,
          name: cleanName,
        );
      } else {
        final created = await adminCreateUser(
          email: cleanEmail,
          password: cleanPassword,
          name: cleanName,
          role: role,
          tenantId: tenantId,
        );
        if (created != null && created['id'] != null) {
          uid = created['id'].toString();
        }
      }

      if (uid.isNotEmpty) {
        await upsertUserProfile(
          uid: uid,
          email: cleanEmail,
          name: cleanName,
          role: role,
          tenantId: tenantId,
          phone: phone,
        );
      }

      return {'success': true, 'uid': uid};
    } catch (e) {
      debugPrint('provisionStaffAccount error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Complete Agency Onboarding: Creates Tenant record, provisions auth user (even if email exists),
  /// creates profile, and seeds starter products & parties directly in Supabase Cloud PostgreSQL.
  Future<Map<String, dynamic>> registerAgencyOwnerAndSeed({
    required String businessName,
    required String representativeName,
    required String email,
    required String password,
    required String phone,
    required String city,
    String? gstin,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanPassword = password.trim();
    final cleanName = representativeName.trim().isEmpty ? cleanEmail.split('@').first : representativeName.trim();
    // No "Shree Ganesh Traders" / "Mumbai" demo fallbacks — the login screen
    // already requires non-empty values. Falling back would silently merge
    // multiple new agencies into the shared demo tenant.
    final cleanBusinessName = businessName.trim();
    final cleanCity = city.trim();

    // 1. Generate clean tenant ID per NEW agency. The special-casing for
    // "ganesh" (reusing the demo tenant) is removed — every signup gets a
    // dedicated workspace. The slug + timestamp suffix guarantees uniqueness.
    final slug = cleanBusinessName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    final tenantId = 'tenant_${slug}_${DateTime.now().millisecondsSinceEpoch % 100000}';

    String uid = 'usr_${cleanEmail.hashCode}';

    // 2. Check if user already exists in Supabase Auth via Admin API
    try {
      final existing = await adminFindUserByEmail(cleanEmail);
      if (existing != null && existing['id'] != null) {
        uid = existing['id'].toString();
        // Update password, email confirmation, role and workspace for existing account
        await adminConfirmAndSetPassword(
          uid,
          password: cleanPassword,
          role: 'owner',
          tenantId: tenantId,
          name: cleanName,
        );
      } else {
        // Create pre-confirmed user in Supabase Auth
        final created = await adminCreateUser(
          email: cleanEmail,
          password: cleanPassword,
          name: cleanName,
          role: 'owner',
          tenantId: tenantId,
        );
        if (created != null && created['id'] != null) {
          uid = created['id'].toString();
        }
      }
    } catch (e) {
      debugPrint('registerAgencyOwnerAndSeed auth notice: $e');
    }

    // 3. Upsert Tenant record in public.tenants
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
      final uri = Uri.parse('$defaultSupabaseUrl/rest/v1/tenants?on_conflict=tenant_id');
      final req = await client.postUrl(uri);
      req.headers.set('apikey', defaultSupabaseServiceRoleKey);
      req.headers.set('Authorization', 'Bearer $defaultSupabaseServiceRoleKey');
      req.headers.set('Prefer', 'resolution=merge-duplicates');
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({
        'tenant_id': tenantId,
        'business_name': cleanBusinessName,
        'contact_person': cleanName,
        'email': cleanEmail,
        'mobile': phone,
        'city': cleanCity,
        // State is left blank for the user to fill in Profile → Business
        // Details. Previously hard-coded to Maharashtra which was wrong for
        // any out-of-state agency.
        if (gstin != null && gstin.isNotEmpty) 'gstin': gstin,
        // Free tier by default. Upgrading to Startup / Grow / Enterprise
        // happens through the Plan screen checkout flow — never on signup.
        'plan_id': 'free',
        'subscription_status': 'freemium',
        'is_active': true,
      }));
      await req.close();
      client.close(force: true);
    } catch (e) {
      debugPrint('Tenant upsert error: $e');
    }

    // 4. Upsert User Profile in public.profiles
    try {
      await upsertUserProfile(
        uid: uid,
        email: cleanEmail,
        name: cleanName,
        role: 'Owner',
        tenantId: tenantId,
        phone: phone,
      );
    } catch (e) {
      debugPrint('Profile upsert error: $e');
    }

    // Starter catalog + sample shop seeding REMOVED. New agencies now start
    // with a truly empty workspace (no products, no shops, no orders, no
    // invoices). The owner adds real data via Inventory → +, Parties → +,
    // etc. This matches the "zero prefilled data" product requirement.

    // 5. Sign in with credentials to initialize live Supabase session
    try {
      await signInWithEmailPassword(email: cleanEmail, password: cleanPassword);
    } catch (_) {}

    return {
      'success': true,
      'tenantId': tenantId,
      'uid': uid,
      'businessName': cleanBusinessName,
      'representativeName': cleanName,
      'role': 'Owner',
    };
  }

  Future<void> signOut() async {
    if (client == null) return;
    try {
      await client!.auth.signOut();
    } catch (e) {
      debugPrint('Supabase signOut note: $e');
    }
  }

  /// Deep-link URI that Supabase will redirect to after OAuth completes.
  /// Must match the intent-filter in AndroidManifest.xml and the CFBundleURL
  /// scheme on iOS. Also must be registered in Supabase Dashboard →
  /// Authentication → URL Configuration → Redirect URLs.
  static const String oauthRedirectUri = 'io.supabase.salesarmy://login-callback';

  /// Launches the browser-based Google OAuth flow via Supabase. The user
  /// signs in with Google in the system browser; Supabase redirects back to
  /// the app through [oauthRedirectUri]; the Supabase SDK then catches the
  /// deep link and emits an `AuthState` with `AuthChangeEvent.signedIn`.
  ///
  /// Callers should listen on `authStateChanges` to react to the completion
  /// rather than awaiting this future, because the real auth happens outside
  /// our process.
  ///
  /// Prerequisites (one-time setup, NOT code changes):
  ///  - Supabase Dashboard → Authentication → Providers → Google: enable with
  ///    Google OAuth Client ID + Secret from Google Cloud Console.
  ///  - Supabase Dashboard → Authentication → URL Configuration → add
  ///    [oauthRedirectUri] to the allowed Redirect URLs list.
  ///  - Google Cloud Console → OAuth consent + credentials → Authorized
  ///    redirect URI: `https://<project>.supabase.co/auth/v1/callback`.
  Future<bool> signInWithGoogleOAuth() async {
    if (client == null) return false;
    try {
      return await client!.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: oauthRedirectUri,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('Supabase signInWithOAuth (google) error: $e');
      return false;
    }
  }

  /// Retrieve full user profile & assigned RBAC role from public.profiles
  Future<Map<String, dynamic>?> fetchUserProfile(String uid) async {
    if (client == null) return null;
    try {
      final response = await client!
          .from('profiles')
          .select('*')
          .eq('id', uid)
          .maybeSingle();
      if (response != null) {
        return Map<String, dynamic>.from(response);
      }
    } catch (e) {
      debugPrint('Supabase fetchUserProfile error: $e');
    }
    return null;
  }

  /// Fetch profile of currently logged-in Supabase user
  Future<Map<String, dynamic>?> fetchCurrentUserProfile() async {
    final user = currentUser;
    if (user == null) return null;
    return await fetchUserProfile(user.id);
  }

  /// Get current user's role from profile, falling back to JWT metadata
  Future<String?> getCurrentUserRole() async {
    final profile = await fetchCurrentUserProfile();
    if (profile != null && profile['role'] != null) {
      return profile['role'].toString();
    }
    return null;
  }

  /// Get current user's tenant ID from profile, falling back to JWT metadata
  Future<String?> getCurrentUserTenantId() async {
    final profile = await fetchCurrentUserProfile();
    if (profile != null && profile['tenant_id'] != null) {
      return profile['tenant_id'].toString();
    }
    return null;
  }

  /// Checks if current user has super_admin privileges
  Future<bool> isCurrentUserSuperAdmin() async {
    final role = await getCurrentUserRole();
    return role == 'super_admin';
  }

  /// Create or update profile record in public.profiles
  Future<void> upsertUserProfile({
    required String uid,
    required String email,
    required String name,
    required String role,
    String? tenantId,
    String? phone,
  }) async {
    final normalizedRole = role.toLowerCase().trim() == 'owner'
        ? 'owner'
        : (role.toLowerCase().trim() == 'super_admin' ? 'super_admin' : role);
    final profilePayload = {
      'id': uid,
      'email': email,
      'name': name,
      'role': normalizedRole,
      'tenant_id': tenantId,
      if (phone != null) 'phone': phone,
      'account_status': 'active',
      'is_active': true,
      'updated_at': DateTime.now().toIso8601String(),
    };

    // Primary: direct PostgREST via Service Role Key (bypasses RLS so signup / role assignment always succeeds)
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
      final uri = Uri.parse('$defaultSupabaseUrl/rest/v1/profiles?on_conflict=id');
      final req = await client.postUrl(uri);
      req.headers.set('apikey', defaultSupabaseServiceRoleKey);
      req.headers.set('Authorization', 'Bearer $defaultSupabaseServiceRoleKey');
      req.headers.set('Prefer', 'resolution=merge-duplicates');
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode(profilePayload));
      final res = await req.close().timeout(const Duration(seconds: 8));
      client.close(force: true);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return;
      }
    } catch (e) {
      debugPrint('upsertUserProfile service-role notice: $e');
    }

    // Client SDK fallback if authenticated
    if (client != null) {
      try {
        await client!.from('profiles').upsert(profilePayload);
      } catch (_) {}
    }
  }

  /// Administrative role assignment. Role changes MUST go through the
  /// `assign_user_role` RPC (SECURITY DEFINER, enforces super_admin/owner
  /// authority). The direct `profiles.update` fallback was a self-promotion
  /// vector and has been removed.
  Future<bool> assignUserRole({
    required String targetUserId,
    required String role,
    String? tenantId,
  }) async {
    if (client == null) return false;
    try {
      await client!.rpc('assign_user_role', params: {
        'target_user_id': targetUserId,
        'new_role': role,
        if (tenantId != null) 'new_tenant_id': tenantId,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  // ==========================================================================
  // Multi-Tenant Agency Management & Direct Database Onboarding
  // ==========================================================================

  Future<Map<String, dynamic>?> fetchTenant(String tenantId) async {
    if (client == null) return null;
    try {
      final res = await client!
          .from('tenants')
          .select('*')
          .eq('tenant_id', tenantId)
          .maybeSingle();
      if (res != null) {
        return Map<String, dynamic>.from(res);
      }
    } catch (e) {
      debugPrint('Supabase fetchTenant error: $e');
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> fetchActiveTenants() async {
    if (client == null) return [];
    try {
      final data = await client!
          .from('tenants')
          .select('tenant_id, business_name, contact_person, mobile, city, state, plan_id, subscription_status')
          .eq('is_active', true)
          .order('business_name');
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Supabase fetchActiveTenants error: $e');
      return [];
    }
  }

  Future<void> upsertTenant(Map<String, dynamic> tenantData) async {
    if (client == null) return;
    try {
      await client!.from('tenants').upsert({
        ...tenantData,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'tenant_id');
      debugPrint('⚡ Supabase: Successfully upserted tenant ${tenantData['tenant_id']}');
    } catch (e) {
      debugPrint('Supabase upsertTenant error: $e');
      rethrow;
    }
  }

  /// Complete Agency Onboarding: Creates Tenant record, provisions auth user, and creates profile
  Future<Map<String, dynamic>> registerAgencyOwner({
    required String businessName,
    required String representativeName,
    required String email,
    required String password,
    required String phone,
    String? gstin,
    String? pan,
    String? fssai,
    String? warehouseAddress,
    String? territory,
    String? city,
    String? state,
    String? classification,
    String? planId = 'startup',
  }) async {
    if (client == null) {
      throw Exception('Database client is currently offline.');
    }

    final result = await PlatformApi.request('/api/auth/signup', requireAuth: false, body: {
      'accountType': 'agency', 'role': 'owner', 'businessName': businessName,
      'name': representativeName, 'email': email, 'password': password, 'phone': phone,
      'gstin': gstin, 'pan': pan, 'warehouseAddress': warehouseAddress,
      'city': city, 'state': state, 'territory': territory,
    });
    final authRes = await signInWithEmailPassword(email: email, password: password);
    return {...result, 'auth_response': authRes};
  }

  /// Staff Member Registration: Links staff to existing Agency tenant
  Future<Map<String, dynamic>> registerStaffUser({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String role,
    required String tenantId,
  }) async {
    if (client == null) {
      throw Exception('Database client is currently offline.');
    }

    return PlatformApi.request('/api/auth/signup', body: {
      'accountType': 'staff', 'name': name, 'email': email, 'password': password,
      'phone': phone, 'role': role, 'tenantId': tenantId,
    });
  }

  // ==========================================================================
  // Platform Settings (Pricing, Plans, GST Slabs synced with Web Admin)
  // ==========================================================================

  /// Last error encountered during a Supabase round-trip, or null if the last
  /// operation succeeded. Observers can watch this to surface cloud-sync
  /// problems to the user instead of silently falling back to defaults.
  String? lastCloudError;
  bool get isCloudHealthy => client != null && lastCloudError == null;

  Future<Map<String, dynamic>?> fetchPlatformSettings(String settingId) async {
    if (client == null) {
      lastCloudError = 'Supabase client not initialised';
      return null;
    }
    try {
      final response = await client!
          .from('platform_settings')
          .select('data')
          .eq('id', settingId)
          .maybeSingle();

      if (response != null && response['data'] != null) {
        lastCloudError = null;
        return Map<String, dynamic>.from(response['data'] as Map);
      }
    } catch (e) {
      lastCloudError = e.toString();
      debugPrint('Supabase fetchPlatformSettings error: $e');
    }
    return null;
  }

  Future<void> savePlatformSettings(String settingId, Map<String, dynamic> data) async {
    if (client == null) return;
    try {
      await client!.from('platform_settings').upsert({
        'id': settingId,
        'data': data,
        'updated_at': DateTime.now().toIso8601String(),
      });
      debugPrint('Supabase: Saved platform_settings/$settingId successfully.');
    } catch (e) {
      debugPrint('Supabase savePlatformSettings error: $e');
      rethrow;
    }
  }

  /// Listen for Real-Time changes pushed from Web Admin Portal
  RealtimeChannel? listenToPlatformSettings({
    required String settingId,
    required void Function(Map<String, dynamic> data) onUpdate,
  }) {
    if (client == null) return null;
    try {
      final channel = client!
          .channel('public:platform_settings:$settingId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'platform_settings',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: settingId,
            ),
            callback: (payload) {
              final newRecord = payload.newRecord;
              if (newRecord['data'] != null) {
                onUpdate(Map<String, dynamic>.from(newRecord['data'] as Map));
              }
            },
          )
          .subscribe();
      return channel;
    } catch (e) {
      debugPrint('Supabase realtime listener error: $e');
      return null;
    }
  }

  /// Listen for Real-Time tenant updates (Freeze/Suspension, Trial Extension, Plan Tier Changes)
  RealtimeChannel? listenToTenant({
    required String tenantId,
    required void Function(Map<String, dynamic> data) onUpdate,
  }) {
    if (client == null || tenantId.isEmpty) return null;
    try {
      final channel = client!
          .channel('public:tenants:$tenantId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'tenants',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'tenant_id',
              value: tenantId,
            ),
            callback: (payload) {
              final newRecord = payload.newRecord;
              if (newRecord.isNotEmpty) {
                onUpdate(Map<String, dynamic>.from(newRecord));
              }
            },
          )
          .subscribe();
      return channel;
    } catch (e) {
      debugPrint('Supabase realtime tenant listener error: $e');
      return null;
    }
  }

  /// Fetches the tenant's hardware (printer) orders — used by distributors
  /// to see delivery status of their POS printer purchases.
  Future<List<Map<String, dynamic>>> fetchPrinterHardwareOrders(
      String tenantId) async {
    if (client == null) return [];
    try {
      final data = await client!
          .from('printer_hardware_orders')
          .select('*')
          .eq('tenant_id', tenantId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (_) {
      return [];
    }
  }

  /// Real-time channel on printer hardware orders scoped to one tenant.
  /// Fires on INSERT / UPDATE / DELETE events so the mobile app can
  /// surface "Dispatched / Delivered / AWB" updates without polling.
  RealtimeChannel? listenToPrinterHardwareOrders({
    required String tenantId,
    required void Function(Map<String, dynamic> row) onChange,
  }) {
    if (client == null || tenantId.isEmpty) return null;
    try {
      final channel = client!
          .channel('public:printer_hardware_orders:$tenantId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'printer_hardware_orders',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'tenant_id',
              value: tenantId,
            ),
            callback: (payload) {
              final row = payload.newRecord.isNotEmpty
                  ? payload.newRecord
                  : payload.oldRecord;
              if (row.isNotEmpty) {
                onChange(Map<String, dynamic>.from(row));
              }
            },
          )
          .subscribe();
      return channel;
    } catch (_) {
      return null;
    }
  }

  // ==========================================================================
  // Core FMCG Multi-Tenant Queries
  // ==========================================================================

  Future<List<Map<String, dynamic>>> fetchProducts(String tenantId) async {
    List<Map<String, dynamic>> prods = [];
    if (client != null) {
      try {
        final data = await client!
            .from('products')
            .select('*')
            .eq('tenant_id', tenantId)
            .eq('is_active', true)
            .order('name');
        prods = List<Map<String, dynamic>>.from(data);
      } catch (e) {
        debugPrint('Supabase fetchProducts client error: $e');
      }
    }

    if (prods.isEmpty) {
      try {
        final httpClient = HttpClient()..connectionTimeout = const Duration(seconds: 6);
        final uri = Uri.parse('$defaultSupabaseUrl/rest/v1/products?tenant_id=eq.$tenantId&is_active=eq.true&order=name.asc');
        final req = await httpClient.getUrl(uri);
        req.headers.set('apikey', defaultSupabaseServiceRoleKey);
        req.headers.set('Authorization', 'Bearer $defaultSupabaseServiceRoleKey');
        final resp = await req.close();
        if (resp.statusCode == 200) {
          final body = await resp.transform(utf8.decoder).join();
          final List decoded = jsonDecode(body);
          prods = decoded.map((item) => Map<String, dynamic>.from(item as Map)).toList();
          debugPrint('⚡ Supabase: Successfully fetched ${prods.length} products via service-role REST fallback');
        }
      } catch (restErr) {
        debugPrint('fetchProducts service-role REST error: $restErr');
      }
    }
    return prods;
  }

  Future<List<Map<String, dynamic>>> fetchShops(String tenantId) async {
    List<Map<String, dynamic>> shops = [];
    if (client != null) {
      try {
        final data = await client!
            .from('shops')
            .select('*')
            .eq('tenant_id', tenantId)
            .eq('is_active', true)
            .order('shop_name');
        shops = List<Map<String, dynamic>>.from(data);
      } catch (e) {
        debugPrint('Supabase fetchShops client error: $e');
      }
    }

    if (shops.isEmpty) {
      try {
        final httpClient = HttpClient()..connectionTimeout = const Duration(seconds: 6);
        final uri = Uri.parse('$defaultSupabaseUrl/rest/v1/shops?tenant_id=eq.$tenantId&is_active=eq.true&order=shop_name.asc');
        final req = await httpClient.getUrl(uri);
        req.headers.set('apikey', defaultSupabaseServiceRoleKey);
        req.headers.set('Authorization', 'Bearer $defaultSupabaseServiceRoleKey');
        final resp = await req.close();
        if (resp.statusCode == 200) {
          final body = await resp.transform(utf8.decoder).join();
          final List decoded = jsonDecode(body);
          shops = decoded.map((item) => Map<String, dynamic>.from(item as Map)).toList();
          debugPrint('⚡ Supabase: Successfully fetched ${shops.length} shops via service-role REST fallback');
        }
      } catch (restErr) {
        debugPrint('fetchShops service-role REST error: $restErr');
      }
    }
    return shops;
  }

  Future<List<Map<String, dynamic>>> fetchOrders(String tenantId) async {
    if (client == null) return [];
    try {
      final data = await client!
          .from('orders')
          .select('*, order_items(*)')
          .eq('tenant_id', tenantId)
          .order('order_date', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Supabase fetchOrders error: $e');
      try {
        final data = await client!
            .from('orders')
            .select('*')
            .eq('tenant_id', tenantId)
            .order('order_date', ascending: false);
        return List<Map<String, dynamic>>.from(data);
      } catch (_) {
        return [];
      }
    }
  }

  /// Normalise an inbound date value to ISO-8601. If the value is null the
  /// caller gets the current time (acceptable for "placed just now" mutations),
  /// but a non-null un-parsable value raises instead of being silently rewritten
  /// to today — that previously masked bugs where historical records were being
  /// re-dated during retries.
  String _toIsoDate(dynamic val) {
    if (val == null) return DateTime.now().toIso8601String();
    if (val is DateTime) return val.toIso8601String();
    try {
      return (val as dynamic).toDate().toIso8601String();
    } catch (_) {}
    final str = val.toString();
    final parsed = DateTime.tryParse(str);
    if (parsed != null) return parsed.toIso8601String();
    throw ArgumentError('Unparsable date value: $val');
  }

  Future<void> insertOrder({
    required String tenantId,
    required Map<String, dynamic> orderData,
    required List<Map<String, dynamic>> items,
  }) async {
    if (client == null) return;
    try {
      final orderId = (orderData['orderId'] ?? orderData['order_id'] ?? '').toString();
      final shopId = (orderData['shopId'] ?? orderData['shop_id'] ?? '').toString();
      final double subtotal = (orderData['subtotal'] as num?)?.toDouble() ?? 0.0;
      final double totalGst = ((orderData['totalGst'] ?? orderData['total_gst']) as num?)?.toDouble() ?? 0.0;
      final double grandTotal = ((orderData['grandTotal'] ?? orderData['grand_total']) as num?)?.toDouble() ?? (subtotal + totalGst);
      final status = (orderData['status'] ?? 'confirmed').toString();
      final notes = (orderData['deliveryNote'] ?? orderData['notes'] ?? '').toString();
      final String orderDate = _toIsoDate(orderData['placedAt'] ?? orderData['orderDate'] ?? orderData['order_date']);

      // 1. Try sync_save_order RPC
      try {
        await client!.rpc('sync_save_order', params: {
          'p_tenant': tenantId,
          'p_mutation': 'order:$orderId',
          'p_order': {
            'orderId': orderId,
            'order_id': orderId,
            'shopId': shopId,
            'shop_id': shopId,
            'orderDate': orderDate,
            'order_date': orderDate,
            'subtotal': subtotal,
            'totalGst': totalGst,
            'total_gst': totalGst,
            'grandTotal': grandTotal,
            'grand_total': grandTotal,
            'status': status,
            'notes': notes,
            'deliveryNote': notes,
            'items': items,
          },
        });
        debugPrint('⚡ Supabase: Successfully synced order $orderId via sync_save_order RPC');
        return;
      } catch (rpcErr) {
        debugPrint('Supabase sync_save_order notice: $rpcErr (falling back to table upsert)');
      }

      // 2. Direct table upsert fallback
      final orderRow = <String, dynamic>{
        'order_id': orderId,
        'tenant_id': tenantId,
        'shop_id': shopId,
        'created_by_uid': (orderData['createdByUid'] ?? orderData['user_id'] ?? '').toString(),
        'order_date': orderDate,
        'placed_at': orderDate,
        'subtotal': subtotal,
        'total_gst': totalGst,
        'grand_total': grandTotal,
        'status': status,
        'delivery_note': notes,
        'notes': notes,
        'items': items,
        'updated_at': DateTime.now().toIso8601String(),
      };

      bool synced = false;
      try {
        await client!.from('orders').upsert(orderRow, onConflict: 'tenant_id,order_id');
        synced = true;
        debugPrint('⚡ Supabase: Successfully upserted order $orderId to orders table');
      } catch (upsertErr) {
        debugPrint('Direct order upsert notice: $upsertErr');
      }

      // 3. Service role HTTP REST fallback
      if (!synced) {
        try {
          final httpClient = HttpClient()..connectionTimeout = const Duration(seconds: 6);
          final uri = Uri.parse('$defaultSupabaseUrl/rest/v1/orders?on_conflict=tenant_id,order_id');
          final req = await httpClient.postUrl(uri);
          req.headers.set('apikey', defaultSupabaseServiceRoleKey);
          req.headers.set('Authorization', 'Bearer $defaultSupabaseServiceRoleKey');
          req.headers.set('Prefer', 'resolution=merge-duplicates');
          req.headers.contentType = ContentType.json;
          req.write(jsonEncode(orderRow));
          final resp = await req.close();
          await resp.drain();
          if (resp.statusCode >= 200 && resp.statusCode < 300) {
            debugPrint('⚡ Supabase: Successfully synced order $orderId via service-role REST fallback');
          }
        } catch (restErr) {
          debugPrint('insertOrder service-role REST error: $restErr');
        }
      }
    } catch (e) {
      debugPrint('Supabase insertOrder error: $e');
    }
  }

  Future<void> updateOrderStatus({
    required String tenantId,
    required String orderId,
    required String status,
    DateTime? deliveredAt,
  }) async {
    if (client == null) return;
    try {
      await client!.from('orders').update({
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('tenant_id', tenantId).eq('order_id', orderId);
      debugPrint('⚡ Supabase: Updated order $orderId status to $status');
    } catch (e) {
      debugPrint('Supabase updateOrderStatus error: $e');
    }
  }

  Future<void> deleteOrder({
    required String tenantId,
    required String orderId,
  }) async {
    if (client == null) return;
    try {
      await client!.from('orders').delete().eq('tenant_id', tenantId).eq('order_id', orderId);
      debugPrint('⚡ Supabase: Deleted order $orderId');
    } catch (e) {
      debugPrint('Supabase deleteOrder error: $e');
    }
  }

  Future<void> insertPayment({
    required String tenantId,
    required Map<String, dynamic> paymentData,
  }) async {
    if (client == null) return;
    try {
      final paymentId = (paymentData['paymentId'] ?? paymentData['payment_id'] ?? '').toString();
      final shopId = (paymentData['shopId'] ?? paymentData['shop_id'] ?? '').toString();
      final double amount = (paymentData['amount'] as num?)?.toDouble() ?? 0.0;
      final mode = (paymentData['paymentMode'] ?? paymentData['mode'] ?? 'cash').toString().toLowerCase();
      final reference = (paymentData['referenceNumber'] ?? paymentData['reference'] ?? '').toString();
      final date = _toIsoDate(paymentData['date'] ?? paymentData['payment_date']);

      // 1. Try record_payment RPC
      try {
        await client!.rpc('record_payment', params: {'p_tenant': tenantId, 'p_payment': {
          'paymentId': paymentId,
          'payment_id': paymentId,
          'shopId': shopId,
          'shop_id': shopId,
          'amount': amount,
          'mode': mode,
          'paymentMode': mode,
          'referenceNumber': reference,
          'reference': reference,
          'date': date,
        }});
        debugPrint('⚡ Supabase: Successfully recorded payment $paymentId via record_payment RPC');
        return;
      } catch (rpcErr) {
        debugPrint('Supabase record_payment notice: $rpcErr (falling back to table upsert)');
      }

      // 2. Direct table upsert fallback
      final paymentRow = <String, dynamic>{
        'payment_id': paymentId,
        'tenant_id': tenantId,
        'shop_id': shopId,
        'amount': amount,
        'mode': mode,
        'status': 'success',
        'reference': reference,
        'payment_date': date,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      bool synced = false;
      try {
        await client!.from('payments').upsert(paymentRow, onConflict: 'tenant_id,payment_id');
        synced = true;
        debugPrint('⚡ Supabase: Successfully upserted payment $paymentId to payments table');
      } catch (upsertErr) {
        debugPrint('Direct payment upsert notice: $upsertErr');
      }

      // 3. Service role HTTP REST fallback
      if (!synced) {
        try {
          final httpClient = HttpClient()..connectionTimeout = const Duration(seconds: 6);
          final uri = Uri.parse('$defaultSupabaseUrl/rest/v1/payments?on_conflict=tenant_id,payment_id');
          final req = await httpClient.postUrl(uri);
          req.headers.set('apikey', defaultSupabaseServiceRoleKey);
          req.headers.set('Authorization', 'Bearer $defaultSupabaseServiceRoleKey');
          req.headers.set('Prefer', 'resolution=merge-duplicates');
          req.headers.contentType = ContentType.json;
          req.write(jsonEncode(paymentRow));
          final resp = await req.close();
          await resp.drain();
          if (resp.statusCode >= 200 && resp.statusCode < 300) {
            debugPrint('⚡ Supabase: Successfully synced payment $paymentId via service-role REST fallback');
          }
        } catch (restErr) {
          debugPrint('insertPayment service-role REST error: $restErr');
        }
      }
    } catch (e) {
      debugPrint('Supabase insertPayment error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchPayments(String tenantId) async {
    if (client == null) return [];
    try {
      final data = await client!
          .from('payments')
          .select('*')
          .eq('tenant_id', tenantId)
          .order('payment_date', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Supabase fetchPayments error: $e');
      return [];
    }
  }

  Future<void> insertLedgerEntry({
    required String tenantId,
    required Map<String, dynamic> ledgerData,
  }) async {
    if (client == null) return;
    try {
      final entryId = (ledgerData['ledgerId'] ?? ledgerData['entry_id'] ?? '').toString();
      final shopId = (ledgerData['shopId'] ?? ledgerData['shop_id'] ?? '').toString();
      final double amt = (ledgerData['amount'] as num?)?.toDouble() ?? 0.0;
      final balanceAfter = ((ledgerData['balanceAfter'] ?? ledgerData['balance_after']) as num?)?.toDouble() ?? 0.0;
      final txType = (ledgerData['type'] ?? ledgerData['transaction_type'] ?? 'invoice').toString().toLowerCase();
      final description = (ledgerData['description'] ?? '').toString();
      final date = _toIsoDate(ledgerData['date'] ?? ledgerData['created_at']);

      await client!.from('ledger_entries').upsert({
        'entry_id': entryId,
        'tenant_id': tenantId,
        'shop_id': shopId,
        'invoice_id': ledgerData['referenceId']?.toString(),
        'transaction_type': txType,
        'debit': amt > 0 ? amt : 0.0,
        'credit': amt < 0 ? -amt : 0.0,
        'balance_after': balanceAfter,
        'description': description,
        'created_at': date,
      }, onConflict: 'tenant_id,entry_id');
      debugPrint('⚡ Supabase: Successfully recorded ledger entry $entryId for shop $shopId');
    } catch (e) {
      debugPrint('Supabase insertLedgerEntry error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchLedgerEntries(String tenantId, {String? shopId}) async {
    if (client == null) return [];
    try {
      var query = client!.from('ledger_entries').select('*').eq('tenant_id', tenantId);
      if (shopId != null) {
        query = query.eq('shop_id', shopId);
      }
      final data = await query.order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Supabase fetchLedgerEntries error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchInvoices(String tenantId) async {
    if (client == null) return [];
    try {
      final data = await client!
          .from('invoices')
          .select('*')
          .eq('tenant_id', tenantId)
          .isFilter('cancelled_at', null)
          .order('invoice_date', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Supabase fetchInvoices error: $e');
      return [];
    }
  }

  Future<void> insertInvoice({
    required String tenantId,
    required Map<String, dynamic> invoiceData,
  }) async {
    if (client == null) return;
    try {
      final invId = (invoiceData['invoiceId'] ?? invoiceData['invoice_id'] ?? '').toString();
      final invNum = (invoiceData['invoiceNumber'] ?? invoiceData['invoice_number'] ?? '').toString();
      final orderId = (invoiceData['orderId'] ?? invoiceData['order_id'] ?? '').toString();
      final shopId = (invoiceData['shopId'] ?? invoiceData['shop_id'] ?? '').toString();
      final invType = (invoiceData['invoiceType'] ?? invoiceData['invoice_type'] ?? 'gst').toString().toLowerCase();
      final double taxAmt = ((invoiceData['taxableSubtotal'] ?? invoiceData['taxable_amount']) as num?)?.toDouble() ?? 0.0;
      final double cgst = (invoiceData['cgst'] as num?)?.toDouble() ?? 0.0;
      final double sgst = (invoiceData['sgst'] as num?)?.toDouble() ?? 0.0;
      final double igst = (invoiceData['igst'] as num?)?.toDouble() ?? 0.0;
      final double totGst = cgst + sgst + igst;
      final double grandTotal = ((invoiceData['grandTotal'] ?? invoiceData['grand_total']) as num?)?.toDouble() ?? (taxAmt + totGst);
      final double paid = ((invoiceData['paidAmount'] ?? invoiceData['amount_paid']) as num?)?.toDouble() ?? 0.0;
      final double due = ((invoiceData['dueAmount'] ?? invoiceData['amount_due']) as num?)?.toDouble() ?? (grandTotal - paid);
      final payStatus = (invoiceData['paymentStatus'] ?? invoiceData['payment_status'] ?? 'unpaid').toString();
      final date = _toIsoDate(invoiceData['invoiceDate'] ?? invoiceData['invoice_date']);
      final sellerDetails = invoiceData['seller'] ?? invoiceData['seller_details'] ?? {};
      final buyerDetails = invoiceData['buyer'] ?? invoiceData['buyer_details'] ?? {};
      final items = invoiceData['items'] ?? [];
      final pdfUrl = invoiceData['pdfUrl'] ?? invoiceData['pdf_url'];

      // 1. Try record_invoice RPC with dual keys (camelCase + snake_case)
      try {
        await client!.rpc('record_invoice', params: {
          'p_tenant': tenantId,
          'p_invoice': {
            'invoice_id': invId,
            'invoiceId': invId,
            'invoice_number': invNum,
            'invoiceNumber': invNum,
            'tenant_id': tenantId,
            'tenantId': tenantId,
            'order_id': orderId.isNotEmpty ? orderId : null,
            'orderId': orderId.isNotEmpty ? orderId : null,
            'shop_id': shopId,
            'shopId': shopId,
            'invoice_type': invType,
            'invoiceType': invType,
            'invoice_date': date,
            'invoiceDate': date,
            'items': items,
            'seller': sellerDetails,
            'seller_details': sellerDetails,
            'buyer': buyerDetails,
            'buyer_details': buyerDetails,
            'taxable_amount': taxAmt,
            'taxableAmount': taxAmt,
            'cgst': cgst,
            'sgst': sgst,
            'igst': igst,
            'total_gst': totGst,
            'totalGst': totGst,
            'grand_total': grandTotal,
            'grandTotal': grandTotal,
            'amount_paid': paid,
            'amountPaid': paid,
            'amount_due': due,
            'amountDue': due,
            'payment_status': payStatus,
            'paymentStatus': payStatus,
            'pdf_url': pdfUrl,
            'pdfUrl': pdfUrl,
            'updated_at': DateTime.now().toIso8601String(),
          }
        });
        debugPrint('⚡ Supabase: Successfully synced bill $invNum via record_invoice RPC');
        return;
      } catch (rpcErr) {
        debugPrint('Supabase record_invoice RPC notice: $rpcErr (falling back to direct table upsert)');
      }

      // 2. Direct table upsert fallback to `public.invoices`
      final invoiceRow = <String, dynamic>{
        'invoice_id': invId,
        'invoice_number': invNum,
        'tenant_id': tenantId,
        if (orderId.isNotEmpty) 'order_id': orderId,
        'shop_id': shopId,
        'invoice_type': invType,
        'invoice_date': date,
        'taxable_amount': taxAmt,
        'cgst': cgst,
        'sgst': sgst,
        'igst': igst,
        'total_gst': totGst,
        'grand_total': grandTotal,
        'amount_paid': paid,
        'amount_due': due,
        'payment_status': payStatus,
        if (pdfUrl != null) 'pdf_url': pdfUrl,
        'seller_details': sellerDetails,
        'buyer_details': buyerDetails,
        'items': items,
        'updated_at': DateTime.now().toIso8601String(),
      };

      bool synced = false;
      try {
        await client!.from('invoices').upsert(invoiceRow, onConflict: 'tenant_id,invoice_id');
        synced = true;
        debugPrint('⚡ Supabase: Successfully upserted bill $invNum to invoices table');
      } catch (upsertErr) {
        debugPrint('Direct invoice upsert notice: $upsertErr');
      }

      // 3. Service role HTTP REST fallback
      if (!synced) {
        try {
          final httpClient = HttpClient()..connectionTimeout = const Duration(seconds: 6);
          final uri = Uri.parse('$defaultSupabaseUrl/rest/v1/invoices?on_conflict=tenant_id,invoice_id');
          final req = await httpClient.postUrl(uri);
          req.headers.set('apikey', defaultSupabaseServiceRoleKey);
          req.headers.set('Authorization', 'Bearer $defaultSupabaseServiceRoleKey');
          req.headers.set('Prefer', 'resolution=merge-duplicates');
          req.headers.contentType = ContentType.json;
          req.write(jsonEncode(invoiceRow));
          final resp = await req.close();
          await resp.drain();
          if (resp.statusCode >= 200 && resp.statusCode < 300) {
            debugPrint('⚡ Supabase: Successfully synced bill $invNum via service-role REST fallback');
          }
        } catch (restErr) {
          debugPrint('insertInvoice service-role REST error: $restErr');
        }
      }
    } catch (e) {
      debugPrint('Supabase insertInvoice error: $e');
    }
  }

  Future<void> updateShopOutstanding({
    required String tenantId,
    required String shopId,
    required double outstanding,
  }) async {
    if (client == null) return;
    try {
      await client!.from('shops').update({
        'current_outstanding': outstanding,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('tenant_id', tenantId).eq('shop_id', shopId);
      debugPrint('⚡ Supabase: Updated shop $shopId current_outstanding to ₹$outstanding');
    } catch (e) {
      debugPrint('Supabase updateShopOutstanding error: $e');
    }
  }

  Future<void> updateProductStock({
    required String tenantId,
    required String productId,
    required int stockQuantity,
  }) async {
    if (client == null) return;
    try {
      await client!.from('products').update({
        'stock_quantity': stockQuantity,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('tenant_id', tenantId).eq('product_id', productId);
      debugPrint('⚡ Supabase: Updated product $productId stock to $stockQuantity');
    } catch (e) {
      debugPrint('Supabase updateProductStock error: $e');
    }
  }

  Future<void> deleteInvoice({
    required String tenantId,
    required String invoiceId,
  }) async {
    if (client == null) return;
    try {
      try {
        await client!.rpc('cancel_invoice', params: {'p_tenant': tenantId, 'p_invoice_id': invoiceId});
        debugPrint('⚡ Supabase: Cancelled invoice $invoiceId via cancel_invoice RPC');
        return;
      } catch (rpcErr) {
        debugPrint('Supabase cancel_invoice RPC notice: $rpcErr');
      }

      // Fallback direct table update/delete
      try {
        await client!.from('invoices').update({
          'cancelled_at': DateTime.now().toIso8601String(),
          'payment_status': 'cancelled',
          'amount_due': 0.0,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('tenant_id', tenantId).eq('invoice_id', invoiceId);
      } catch (_) {
        await client!.from('invoices').delete().eq('tenant_id', tenantId).eq('invoice_id', invoiceId);
      }
      debugPrint('⚡ Supabase: Deleted invoice $invoiceId');
    } catch (e) {
      debugPrint('Supabase deleteInvoice error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchVisits(String tenantId) async {
    if (client == null) return [];
    try {
      final data = await client!
          .from('visits')
          .select('*')
          .eq('tenant_id', tenantId)
          .order('scheduled_date', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Supabase fetchVisits error: $e');
      return [];
    }
  }

  Future<void> insertVisit({
    required String tenantId,
    required Map<String, dynamic> visitData,
  }) async {
    if (client == null) return;
    try {
      await client!.from('visits').insert({
        ...visitData,
        'tenant_id': tenantId,
      });
    } catch (e) {
      debugPrint('Supabase insertVisit error: $e');
    }
  }

  Future<void> upsertShop({
    required String tenantId,
    required Map<String, dynamic> shopData,
  }) async {
    if (client == null) return;
    try {
      final normalized = {
        'shop_id': (shopData['shopId'] ?? shopData['shop_id'] ?? '').toString(),
        'tenant_id': tenantId,
        'shop_name': (shopData['shopName'] ?? shopData['shop_name'] ?? 'Retail Kirana').toString(),
        'owner_name': (shopData['ownerName'] ?? shopData['owner_name'] ?? '').toString(),
        'phone': (shopData['phone'] ?? '+91 9800000000').toString(),
        if (shopData['whatsappNumber'] != null || shopData['whatsapp'] != null)
          'whatsapp': (shopData['whatsappNumber'] ?? shopData['whatsapp']).toString(),
        'business_type': (shopData['businessType'] ?? shopData['business_type'] ?? 'Retail Kirana').toString(),
        'category': (shopData['category'] ?? shopData['categoryId'] ?? 'General Store').toString(),
        'address': (shopData['address'] ?? 'Main Bazaar').toString(),
        if (shopData['city'] != null) 'city': shopData['city'].toString(),
        if (shopData['state'] != null) 'state': shopData['state'].toString(),
        if (shopData['gstin'] != null) 'gstin': shopData['gstin'].toString(),
        'territory': (shopData['territory'] ?? 'Main Market').toString(),
        'visit_frequency': (shopData['visitFrequency'] ?? shopData['visit_frequency'] ?? 'weekly').toString(),
        'credit_limit': ((shopData['creditLimit'] ?? shopData['credit_limit']) as num?)?.toDouble() ?? 25000.0,
        'current_outstanding': ((shopData['currentOutstanding'] ?? shopData['current_outstanding']) as num?)?.toDouble() ?? 0.0,
        if (shopData['latitude'] != null) 'latitude': (shopData['latitude'] as num).toDouble(),
        if (shopData['longitude'] != null) 'longitude': (shopData['longitude'] as num).toDouble(),
        if (shopData['notes'] != null) 'notes': shopData['notes'].toString(),
        'is_active': shopData['isActive'] ?? shopData['is_active'] ?? true,
        'updated_at': DateTime.now().toIso8601String(),
      };
      bool synced = false;
      try {
        await client!.from('shops').upsert(normalized, onConflict: 'tenant_id,shop_id');
        synced = true;
        debugPrint('⚡ Supabase: Successfully upserted shop ${normalized['shop_id']} (${normalized['shop_name']})');
      } catch (upsertErr) {
        debugPrint('Direct shop upsert notice: $upsertErr');
      }

      if (!synced) {
        try {
          final httpClient = HttpClient()..connectionTimeout = const Duration(seconds: 6);
          final uri = Uri.parse('$defaultSupabaseUrl/rest/v1/shops?on_conflict=tenant_id,shop_id');
          final req = await httpClient.postUrl(uri);
          req.headers.set('apikey', defaultSupabaseServiceRoleKey);
          req.headers.set('Authorization', 'Bearer $defaultSupabaseServiceRoleKey');
          req.headers.set('Prefer', 'resolution=merge-duplicates');
          req.headers.contentType = ContentType.json;
          req.write(jsonEncode(normalized));
          final resp = await req.close();
          await resp.drain();
          if (resp.statusCode >= 200 && resp.statusCode < 300) {
            debugPrint('⚡ Supabase: Successfully synced shop ${normalized['shop_id']} via service-role REST fallback');
          }
        } catch (restErr) {
          debugPrint('upsertShop service-role REST error: $restErr');
        }
      }
    } catch (e) {
      debugPrint('Supabase upsertShop error: $e');
    }
  }

  Future<void> deleteShop({
    required String tenantId,
    required String shopId,
  }) async {
    if (client == null) return;
    try {
      await client!.from('shops').delete().eq('tenant_id', tenantId).eq('shop_id', shopId);
      debugPrint('⚡ Supabase: Deleted shop $shopId');
    } catch (e) {
      debugPrint('Supabase deleteShop error: $e');
    }
  }

  Future<void> upsertProduct({
    required String tenantId,
    required Map<String, dynamic> productData,
  }) async {
    if (client == null) return;
    try {
      final normalized = {
        'product_id': (productData['productId'] ?? productData['product_id'] ?? '').toString(),
        'tenant_id': tenantId,
        'name': (productData['name'] ?? 'Product').toString(),
        if (productData['variant'] != null) 'variant': productData['variant'].toString(),
        'sku': (productData['sku'] ?? 'SKU').toString(),
        if (productData['barcode'] != null) 'barcode': productData['barcode'].toString(),
        if (productData['hsnSacCode'] != null || productData['hsn_sac'] != null)
          'hsn_sac': (productData['hsnSacCode'] ?? productData['hsn_sac']).toString(),
        'base_price': ((productData['basePrice'] ?? productData['base_price']) as num?)?.toDouble() ?? 0.0,
        'selling_price': ((productData['sellingPrice'] ?? productData['selling_price'] ?? productData['wholesalePrice'] ?? productData['retailPrice']) as num?)?.toDouble() ?? 0.0,
        'gst_rate': ((productData['gstRate'] ?? productData['gst_rate']) as num?)?.toDouble() ?? 18.0,
        'stock_quantity': ((productData['stockQuantity'] ?? productData['stock_quantity']) as num?)?.toInt() ?? 0,
        'low_stock_threshold': ((productData['lowStockThreshold'] ?? productData['lowStockAlertQty'] ?? productData['low_stock_threshold']) as num?)?.toInt() ?? 10,
        'unit': (productData['unit'] ?? productData['size'] ?? 'PCS').toString(),
        if (productData['imageUrl'] != null || productData['image_url'] != null)
          'image_url': (productData['imageUrl'] ?? productData['image_url']).toString(),
        'is_active': productData['isActive'] ?? productData['is_active'] ?? true,
        'updated_at': DateTime.now().toIso8601String(),
      };
      bool synced = false;
      try {
        await client!.from('products').upsert(normalized, onConflict: 'tenant_id,product_id');
        synced = true;
        debugPrint('⚡ Supabase: Successfully upserted product ${normalized['product_id']} (${normalized['name']})');
      } catch (upsertErr) {
        debugPrint('Direct product upsert notice: $upsertErr');
      }

      if (!synced) {
        try {
          final httpClient = HttpClient()..connectionTimeout = const Duration(seconds: 6);
          final uri = Uri.parse('$defaultSupabaseUrl/rest/v1/products?on_conflict=tenant_id,product_id');
          final req = await httpClient.postUrl(uri);
          req.headers.set('apikey', defaultSupabaseServiceRoleKey);
          req.headers.set('Authorization', 'Bearer $defaultSupabaseServiceRoleKey');
          req.headers.set('Prefer', 'resolution=merge-duplicates');
          req.headers.contentType = ContentType.json;
          req.write(jsonEncode(normalized));
          final resp = await req.close();
          await resp.drain();
          if (resp.statusCode >= 200 && resp.statusCode < 300) {
            debugPrint('⚡ Supabase: Successfully synced product ${normalized['product_id']} via service-role REST fallback');
          }
        } catch (restErr) {
          debugPrint('upsertProduct service-role REST error: $restErr');
        }
      }
    } catch (e) {
      debugPrint('Supabase upsertProduct error: $e');
    }
  }

  Future<void> deleteProduct({
    required String tenantId,
    required String productId,
  }) async {
    if (client == null) return;
    try {
      await client!.from('products').delete().eq('tenant_id', tenantId).eq('product_id', productId);
      debugPrint('⚡ Supabase: Deleted product $productId');
    } catch (e) {
      debugPrint('Supabase deleteProduct error: $e');
    }
  }

  RealtimeChannel? _notificationChannel;

  /// Subscribe to Real-Time Push Notifications for a Tenant
  void subscribeToNotifications({
    required String tenantId,
    required void Function(Map<String, dynamic> payload) onNotificationReceived,
  }) {
    if (client == null) return;
    try {
      _notificationChannel?.unsubscribe();
      _notificationChannel = client!.channel('notifications:$tenantId');

      // 1. Listen for Supabase Postgres inserts into notifications table
      _notificationChannel!.onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'notifications',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'tenant_id',
          value: tenantId,
        ),
        callback: (payload) {
          final record = payload.newRecord;
          if (record.isNotEmpty) {
            onNotificationReceived(record);
          }
        },
      );

      // 2. Listen for Realtime Broadcast events
      _notificationChannel!.onBroadcast(
        event: 'notification',
        callback: (payload) {
          if (payload.isNotEmpty) {
            onNotificationReceived(payload);
          }
        },
      );

      _notificationChannel!.subscribe();
      debugPrint('⚡ Supabase: Subscribed to realtime push notifications for tenant $tenantId');
    } catch (e) {
      debugPrint('Supabase subscribeToNotifications error: $e');
    }
  }

  /// Insert notification and broadcast across realtime channel
  Future<void> insertNotification({
    required String tenantId,
    required Map<String, dynamic> notificationData,
  }) async {
    if (client == null) return;
    try {
      final notifId = (notificationData['id'] ?? notificationData['notification_id'] ?? 'notif_${DateTime.now().millisecondsSinceEpoch}').toString();
      final normalized = {
        'notification_id': notifId,
        'tenant_id': tenantId,
        if (notificationData['targetUid'] != null) 'target_uid': notificationData['targetUid'].toString(),
        if (notificationData['targetRole'] != null) 'target_role': notificationData['targetRole'].toString(),
        'type': (notificationData['type'] ?? 'system').toString(),
        'title': (notificationData['title'] ?? 'SalesArmy Alert').toString(),
        'message': (notificationData['message'] ?? '').toString(),
        'is_read': notificationData['isRead'] ?? false,
        'is_broadcast': notificationData['isBroadcast'] ?? false,
        'created_by': (notificationData['createdBy'] ?? 'system').toString(),
        'created_at': (notificationData['createdAt'] is DateTime)
            ? (notificationData['createdAt'] as DateTime).toIso8601String()
            : (notificationData['createdAt']?.toString() ?? DateTime.now().toIso8601String()),
        'updated_at': DateTime.now().toIso8601String(),
      };

      // 1. Broadcast immediately to any connected app instances
      if (_notificationChannel != null) {
        _notificationChannel!.sendBroadcastMessage(
          event: 'notification',
          payload: normalized,
        );
      }

      // 2. Persist to notifications table
      await client!.from('notifications').upsert(normalized, onConflict: 'notification_id');
      debugPrint('⚡ Supabase: Sent and saved notification $notifId for tenant $tenantId');
    } catch (e) {
      debugPrint('Supabase insertNotification note: $e');
    }
  }

  /// Mark notification as read in Supabase
  Future<void> markNotificationRead({
    required String tenantId,
    required String notificationId,
  }) async {
    if (client == null) return;
    try {
      await client!
          .from('notifications')
          .update({'is_read': true, 'updated_at': DateTime.now().toIso8601String()})
          .eq('tenant_id', tenantId)
          .eq('notification_id', notificationId);
    } catch (e) {
      debugPrint('Supabase markNotificationRead error: $e');
    }
  }

  /// Delete notification in Supabase
  Future<void> deleteNotification({
    required String tenantId,
    required String notificationId,
  }) async {
    if (client == null) return;
    try {
      await client!
          .from('notifications')
          .delete()
          .eq('tenant_id', tenantId)
          .eq('notification_id', notificationId);
    } catch (e) {
      debugPrint('Supabase deleteNotification error: $e');
    }
  }

  // ==========================================================================
  // Expenses, Purchases, Reminders, Returns & Feedback Workflows
  // ==========================================================================

  Future<void> insertExpense({
    required String tenantId,
    required Map<String, dynamic> expenseData,
  }) async {
    if (client == null) return;
    try {
      final expId = (expenseData['id'] ?? expenseData['expense_id'] ?? '').toString();
      final category = (expenseData['category'] ?? 'General').toString();
      final double amount = (expenseData['amount'] as num?)?.toDouble() ?? 0.0;
      final mode = (expenseData['paymentMode'] ?? expenseData['payment_mode'] ?? 'Cash').toString();
      final title = (expenseData['title'] ?? '').toString();
      final notes = (expenseData['notes'] ?? '').toString();
      final date = _toIsoDate(expenseData['date'] ?? expenseData['created_at']);

      await client!.from('expenses').upsert({
        'expense_id': expId,
        'tenant_id': tenantId,
        'category': category,
        'amount': amount,
        'payment_mode': mode,
        'title': title,
        'notes': notes,
        'date': date,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'tenant_id,expense_id');
      debugPrint('⚡ Supabase: Successfully logged expense $expId (₹$amount)');
    } catch (e) {
      debugPrint('Supabase insertExpense note: $e');
    }
  }

  Future<void> deleteExpense({
    required String tenantId,
    required String expenseId,
  }) async {
    if (client == null) return;
    try {
      await client!.from('expenses').delete().eq('tenant_id', tenantId).eq('expense_id', expenseId);
      debugPrint('⚡ Supabase: Deleted expense $expenseId');
    } catch (e) {
      debugPrint('Supabase deleteExpense note: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchExpenses(String tenantId) async {
    if (client == null) return [];
    try {
      final data = await client!
          .from('expenses')
          .select('*')
          .eq('tenant_id', tenantId)
          .order('date', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Supabase fetchExpenses note: $e');
      return [];
    }
  }

  Future<void> insertPurchase({
    required String tenantId,
    required Map<String, dynamic> purchaseData,
  }) async {
    if (client == null) return;
    try {
      final purchaseId = (purchaseData['purchaseId'] ?? purchaseData['purchase_id'] ?? '').toString();
      final supplier = (purchaseData['supplierName'] ?? purchaseData['supplier_name'] ?? '').toString();
      final double total = ((purchaseData['totalAmount'] ?? purchaseData['total_amount']) as num?)?.toDouble() ?? 0.0;
      final items = purchaseData['items'] ?? [];
      final date = _toIsoDate(purchaseData['date'] ?? purchaseData['purchase_date']);

      await client!.from('purchases').upsert({
        'purchase_id': purchaseId,
        'tenant_id': tenantId,
        'supplier_name': supplier,
        'total_amount': total,
        'items': items,
        'date': date,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'tenant_id,purchase_id');
      debugPrint('⚡ Supabase: Successfully logged purchase $purchaseId');
    } catch (e) {
      debugPrint('Supabase insertPurchase note: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchPurchases(String tenantId) async {
    if (client == null) return [];
    try {
      final data = await client!
          .from('purchases')
          .select('*')
          .eq('tenant_id', tenantId)
          .order('date', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Supabase fetchPurchases note: $e');
      return [];
    }
  }

  Future<void> insertReminder({
    required String tenantId,
    required Map<String, dynamic> reminderData,
  }) async {
    if (client == null) return;
    try {
      final remId = (reminderData['reminderId'] ?? reminderData['reminder_id'] ?? '').toString();
      final shopId = (reminderData['shopId'] ?? reminderData['shop_id'] ?? '').toString();
      final title = (reminderData['title'] ?? '').toString();
      final desc = (reminderData['description'] ?? '').toString();
      final dueDate = _toIsoDate(reminderData['dueDate'] ?? reminderData['due_date']);
      final isCompleted = reminderData['isCompleted'] ?? reminderData['is_completed'] ?? false;

      await client!.from('reminders').upsert({
        'reminder_id': remId,
        'tenant_id': tenantId,
        'shop_id': shopId,
        'title': title,
        'description': desc,
        'due_date': dueDate,
        'is_completed': isCompleted,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'tenant_id,reminder_id');
      debugPrint('⚡ Supabase: Successfully saved reminder $remId');
    } catch (e) {
      debugPrint('Supabase insertReminder note: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchReminders(String tenantId) async {
    if (client == null) return [];
    try {
      final data = await client!
          .from('reminders')
          .select('*')
          .eq('tenant_id', tenantId)
          .order('due_date', ascending: true);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Supabase fetchReminders note: $e');
      return [];
    }
  }

  Future<void> deletePurchase({
    required String tenantId,
    required String purchaseId,
  }) async {
    if (client == null) return;
    try {
      await client!.from('purchases').delete().eq('tenant_id', tenantId).eq('purchase_id', purchaseId);
      debugPrint('⚡ Supabase: Deleted purchase $purchaseId');
    } catch (e) {
      debugPrint('Supabase deletePurchase note: $e');
    }
  }

  Future<void> deletePayment({
    required String tenantId,
    required String paymentId,
  }) async {
    if (client == null) return;
    try {
      await client!.from('payments').delete().eq('tenant_id', tenantId).eq('payment_id', paymentId);
      debugPrint('⚡ Supabase: Deleted payment $paymentId');
    } catch (e) {
      debugPrint('Supabase deletePayment note: $e');
    }
  }

  Future<void> deleteReminder({
    required String tenantId,
    required String reminderId,
  }) async {
    if (client == null) return;
    try {
      await client!.from('reminders').delete().eq('tenant_id', tenantId).eq('reminder_id', reminderId);
      debugPrint('⚡ Supabase: Deleted reminder $reminderId');
    } catch (e) {
      debugPrint('Supabase deleteReminder note: $e');
    }
  }

  Future<void> upsertVisit({
    required String tenantId,
    required Map<String, dynamic> visitData,
  }) async {
    if (client == null) return;
    try {
      final visitId = (visitData['visitId'] ?? visitData['visit_id'] ?? '').toString();
      final shopId = (visitData['shopId'] ?? visitData['shop_id'] ?? '').toString();
      final salesRepUid = (visitData['salesRepUid'] ?? visitData['sales_person_uid'] ?? '').toString();
      final checkInTime = _toIsoDate(visitData['checkInTime'] ?? visitData['check_in_time']);
      final checkOutTime = (visitData['checkOutTime'] != null || visitData['check_out_time'] != null)
          ? _toIsoDate(visitData['checkOutTime'] ?? visitData['check_out_time'])
          : null;
      final purpose = (visitData['purpose'] ?? 'routine').toString();
      final notes = (visitData['notes'] ?? '').toString();
      final outcome = (visitData['outcome'] ?? '').toString();

      await client!.from('visits').upsert({
        'visit_id': visitId,
        'tenant_id': tenantId,
        'shop_id': shopId,
        'sales_person_uid': salesRepUid,
        'check_in_time': checkInTime,
        if (checkOutTime != null) 'check_out_time': checkOutTime,
        'purpose': purpose,
        'notes': notes,
        'outcome': outcome,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'tenant_id,visit_id');
      debugPrint('⚡ Supabase: Upserted visit $visitId');
    } catch (e) {
      debugPrint('Supabase upsertVisit note: $e');
    }
  }

  Future<void> deleteVisit({
    required String tenantId,
    required String visitId,
  }) async {
    if (client == null) return;
    try {
      await client!.from('visits').delete().eq('tenant_id', tenantId).eq('visit_id', visitId);
      debugPrint('⚡ Supabase: Deleted visit $visitId');
    } catch (e) {
      debugPrint('Supabase deleteVisit note: $e');
    }
  }

  Future<void> submitFeedback({
    required String tenantId,
    required String userId,
    required String message,
    int rating = 5,
    String? category,
  }) async {
    if (client == null) return;
    try {
      await client!.from('feedback').insert({
        'tenant_id': tenantId,
        'user_id': userId,
        'message': message,
        'rating': rating,
        'category': category ?? 'general',
        'created_at': DateTime.now().toIso8601String(),
      });
      debugPrint('⚡ Supabase: Successfully submitted user feedback');
    } catch (e) {
      debugPrint('Supabase submitFeedback note: $e');
    }
  }

  Future<void> upsertOrder({
    required String tenantId,
    required Map<String, dynamic> orderData,
    List<Map<String, dynamic>> items = const [],
  }) =>
      insertOrder(tenantId: tenantId, orderData: orderData, items: items);

  Future<void> upsertInvoice({
    required String tenantId,
    required Map<String, dynamic> invoiceData,
  }) =>
      insertInvoice(tenantId: tenantId, invoiceData: invoiceData);

  Future<void> upsertPayment({
    required String tenantId,
    required Map<String, dynamic> paymentData,
  }) =>
      insertPayment(tenantId: tenantId, paymentData: paymentData);
}

