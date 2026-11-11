import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:salesarmy/core/services/supabase_service.dart';

/// Thin HTTP client that calls the SalesArmy platform server
/// (`apps/web-admin/server.js`). Used for Razorpay-backed subscription
/// checkout, super-admin signup, admin backups and password resets.
///
/// ## Where the base URL comes from
///
/// 1. **Build-time `--dart-define=PLATFORM_API_URL=...`** (highest priority).
///    Set this to your deployed server URL in production builds.
/// 2. **Debug fallback** when no `--dart-define` is given:
///    - Android (device + emulator)  → `http://10.0.2.2:3000`
///      (the magic alias the Android emulator uses for the host's loopback)
///    - iOS simulator / desktop debug → `http://127.0.0.1:3000`
///    These point at a locally-running `node server.js` on port 3000 — the
///    same server the admin portal uses.
/// 3. **Release mode without `--dart-define`** → the getter throws, because
///    shipping a build that silently falls back to localhost would be
///    dangerous. Set `PLATFORM_API_URL` or deploy without this feature.
class PlatformApi {
  static const String _envUrl = String.fromEnvironment('PLATFORM_API_URL');

  /// Resolved base URL. Returns an empty string only in release builds that
  /// did not define `PLATFORM_API_URL`; [request] turns that into a clear
  /// "server not configured" error.
  static String get baseUrl {
    if (_envUrl.isNotEmpty) return _envUrl;
    if (kReleaseMode) return '';
    // Debug default — assumes `node server.js` is running on the dev host.
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:3000';
    return 'http://127.0.0.1:3000';
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
