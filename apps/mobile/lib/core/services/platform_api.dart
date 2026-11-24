import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:salesarmy/core/services/supabase_service.dart';

/// Thin HTTP client for the SalesArmy platform API (`apps/web-admin/api`).
/// Used for Razorpay subscription checkout, agency signup, staff
/// provisioning, backups and password resets.
///
/// ## Where the base URL comes from
///
/// 1. **`--dart-define=PLATFORM_API_URL=...`** (highest priority) — e.g. a
///    local `node server.js` or a self-hosted copy of the admin server.
/// 2. **Default: the Supabase Edge Function `platform`** of the app's own
///    Supabase project: `<SUPABASE_URL>/functions/v1/platform`. Deploy it
///    with `npx supabase functions deploy platform --no-verify-jwt`.
///    No separate server (Render, PC tunnel...) is needed.
class PlatformApi {
  static const String _envUrl = String.fromEnvironment('PLATFORM_API_URL');

  /// Resolved base URL (no trailing slash).
  static String get baseUrl {
    if (_envUrl.isNotEmpty) return _envUrl.replaceFirst(RegExp(r'/+$'), '');
    final supabaseUrl = SupabaseService.defaultSupabaseUrl.replaceFirst(RegExp(r'/+$'), '');
    if (supabaseUrl.isEmpty) return '';
    return '$supabaseUrl/functions/v1/platform';
  }

  static bool get isConfigured => baseUrl.isNotEmpty;

  static Future<Map<String, dynamic>> request(
    String path, {
    Map<String, dynamic>? body,
    bool requireAuth = true,
  }) async {
    final url = baseUrl;
    if (url.isEmpty) {
      throw StateError(
        'The platform server URL is not configured. Rebuild the app with '
        '--dart-define=PLATFORM_API_URL=https://your-server.example.com',
      );
    }
    final uri = Uri.parse('$url$path');
    if (kReleaseMode && uri.scheme != 'https') {
      throw StateError('The platform server requires HTTPS in release builds.');
    }
    final token = SupabaseService.instance.currentSession?.accessToken;
    if (requireAuth && token == null) {
      throw StateError('Please sign in again.');
    }
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final req = await client.openUrl(body == null ? 'GET' : 'POST', uri);
      if (token != null) {
        req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      req.headers.contentType = ContentType.json;
      if (body != null) req.write(jsonEncode(body));
      final response =
          await req.close().timeout(const Duration(seconds: 30));
      final raw = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 30));
      final data = raw.isEmpty
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(jsonDecode(raw) as Map);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError(
          data['error']?.toString() ??
              // Supabase gateway errors, e.g. "Requested function was not found"
              data['message']?.toString() ??
              'Server request failed (${response.statusCode}).',
        );
      }
      return data;
    } on SocketException catch (e) {
      // Turn the raw "Connection refused" into something the user can act on.
      throw StateError(
        'Could not reach the platform server at $url. '
        'Is the server running? ($e)',
      );
    } finally {
      client.close(force: true);
    }
  }
}
