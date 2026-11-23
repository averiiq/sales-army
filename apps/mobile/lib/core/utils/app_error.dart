import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/core/services/notification_service.dart' show rootNavigatorKey;

/// Central error handling for the whole app.
///
/// * [AppError.message] turns any exception into a short sentence a shop
///   owner can understand (no "PostgrestException(...)" or stack noise).
/// * [showAppError] displays it as a toast on the ROOT overlay, so it is
///   visible above open dialogs and bottom sheets (SnackBars are not).
/// * [AppError.guard] wraps a button action: runs it, and on failure shows
///   the error instead of failing silently.
class AppError {
  AppError._();

  /// Plain-language description of [error]. [action] completes the sentence
  /// "Couldn't …", e.g. `action: 'save the shop'`.
  static String message(Object error, {String? action}) {
    final prefix = action == null ? '' : "Couldn't $action. ";

    if (error is BillingBlockedException) return error.message;
    if (error is InsufficientStockException) return 'Not enough stock: ${error.message}';

    if (_isNetwork(error)) {
      return '${prefix}No internet connection or the server is not responding. '
          'Check your connection and try again.';
    }

    if (error is AuthException) {
      final m = error.message.toLowerCase();
      if (m.contains('invalid login') || m.contains('invalid credentials')) {
        return 'Incorrect email or password.';
      }
      if (m.contains('email not confirmed')) {
        return 'Please confirm your email using the link we sent, then sign in.';
      }
      if (m.contains('already registered') || m.contains('already exists')) {
        return 'This email is already registered. Please sign in instead.';
      }
      if (m.contains('rate limit') || error.statusCode == '429') {
        return 'Too many attempts. Please wait a minute and try again.';
      }
      if (m.contains('jwt') || m.contains('expired') || m.contains('session')) {
        return 'Your session has expired. Please sign in again.';
      }
      return '$prefix${error.message}';
    }

    if (error is PostgrestException) {
      switch (error.code) {
        case '23505':
          return '${prefix}This record already exists (duplicate number or name).';
        case '23503':
          return '${prefix}It is linked to other records that are missing or still in use.';
        case '23502':
        case '23514':
          return '${prefix}Some required details are missing or invalid.';
        case '42501':
          return "${prefix}You don't have permission to do this. Ask your agency owner.";
        case 'PGRST301':
        case 'PGRST303':
          return 'Your session has expired. Please sign in again.';
        case 'PGRST202':
          return '${prefix}This feature is not available on the server yet. Please contact support.';
        case 'P0001':
          // Message raised deliberately by our database functions — already readable.
          return '$prefix${_readable(error.message)}';
      }
      if (error.message.toLowerCase().contains('row-level security')) {
        return "${prefix}You don't have permission to do this. Ask your agency owner.";
      }
      return '${prefix}The server rejected the request. Please try again.';
    }

    if (error is FormatException) {
      return '${prefix}Some of the entered values are not in the right format.';
    }

    final text = _readable(error.toString());
    if (text.isEmpty || text.length > 220 || text.contains('Instance of')) {
      return '${prefix}Something went wrong. Please try again.';
    }
    return '$prefix$text';
  }

  static bool _isNetwork(Object e) =>
      e is SocketException ||
      e is TimeoutException ||
      e is HttpException ||
      e is HandshakeException ||
      e.toString().contains('ClientException') ||
      e.toString().contains('Failed host lookup') ||
      e.toString().contains('Connection refused');

  static String _readable(String raw) {
    var text = raw.trim();
    for (final p in ['Bad state: ', 'Exception: ', 'Invalid argument(s): ', 'Invalid argument: ', 'Error: ']) {
      if (text.startsWith(p)) text = text.substring(p.length);
    }
    return text;
  }

  /// Runs [task]; on failure shows the error and returns false. Use for
  /// button handlers so nothing ever fails silently.
  static Future<bool> guard(BuildContext? context, Future<void> Function() task, {String? action}) async {
    try {
      await task();
      return true;
    } catch (e, st) {
      debugPrint('AppError.guard${action == null ? '' : ' ($action)'}: $e\n$st');
      showAppError(context, e, action: action);
      return false;
    }
  }
}

/// Shows [error] as a dismissible toast above everything (dialogs included).
void showAppError(BuildContext? context, Object error, {String? action}) {
  _AppToast.show(AppError.message(error, action: action), isError: true);
}

/// Shows a short confirmation toast above everything.
void showAppSuccess(String message) => _AppToast.show(message, isError: false);

class _AppToast {
  static OverlayEntry? _current;
  static Timer? _timer;
  static String? _lastMessage;
  static DateTime _lastShown = DateTime.fromMillisecondsSinceEpoch(0);

  static void show(String message, {required bool isError}) {
    // Collapse identical errors fired in a burst (e.g. a failing list sync).
    final now = DateTime.now();
    if (message == _lastMessage && now.difference(_lastShown).inSeconds < 3) return;
    _lastMessage = message;
    _lastShown = now;

    final overlay = rootNavigatorKey.currentState?.overlay;
    if (overlay == null) {
      debugPrint('App toast (no overlay yet): $message');
      return;
    }
    _dismiss();
    final entry = OverlayEntry(builder: (_) => _ToastView(message: message, isError: isError, onClose: _dismiss));
    _current = entry;
    overlay.insert(entry);
    _timer = Timer(Duration(seconds: isError ? 6 : 3), _dismiss);
  }

  static void _dismiss() {
    _timer?.cancel();
    _timer = null;
    _current?.remove();
    _current = null;
  }
}

class _ToastView extends StatelessWidget {
  final String message;
  final bool isError;
  final VoidCallback onClose;
  const _ToastView({required this.message, required this.isError, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final bg = isError ? const Color(0xFFB91C1C) : const Color(0xFF047857);
    return Positioned(
      left: 12,
      right: 12,
      bottom: 24 + MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom,
      child: SafeArea(
        top: false,
        child: Material(
          color: Colors.transparent,
          child: Semantics(
            liveRegion: true,
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 14, offset: Offset(0, 6))],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(message,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600, height: 1.35)),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Dismiss',
                    icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
                    onPressed: onClose,
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

/// Friendly replacement for the grey/red error box when a widget fails to
/// build in release mode.
Widget appErrorWidgetBuilder(FlutterErrorDetails details) {
  if (kDebugMode) return ErrorWidget(details.exception);
  return const Material(
    color: Colors.transparent,
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
          SizedBox(width: 8),
          Flexible(
            child: Text('This section could not be displayed.',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
          ),
        ],
      ),
    ),
  );
}
