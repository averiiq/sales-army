import 'package:flutter/material.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/core/utils/app_error.dart';
import 'package:salesarmy/features/admin/presentation/screens/plan_and_pricing_screen.dart';

/// Shows why a bill / order could not be created.
///
/// Uses a dialog (not a SnackBar) so the message is visible even when the
/// failure happens inside another dialog or bottom sheet — SnackBars render
/// underneath open dialogs and were never seen by users.
Future<void> showBillingErrorDialog(BuildContext context, Object error, {String action = 'create the bill'}) {
  final isBlocked = error is BillingBlockedException;
  final isStock = error is InsufficientStockException;

  final String title;
  final String message;
  final IconData icon;
  final Color accent;

  if (isBlocked) {
    title = 'Billing not available';
    message = error.message;
    icon = Icons.lock_outline_rounded;
    accent = const Color(0xFFD97706);
  } else if (isStock) {
    title = 'Not enough stock';
    message = error.toString();
    icon = Icons.inventory_2_outlined;
    accent = const Color(0xFFD97706);
  } else {
    title = "Couldn't $action";
    message = friendlyErrorMessage(error);
    icon = Icons.error_outline_rounded;
    accent = const Color(0xFFDC2626);
  }

  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      icon: Icon(icon, color: accent, size: 32),
      title: Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      content: Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13.5, height: 1.4)),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(isBlocked ? 'Not now' : 'OK'),
        ),
        if (isBlocked)
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PlanAndPricingScreen()));
            },
            child: const Text('Upgrade plan'),
          ),
      ],
    ),
  );
}

/// Plain-language error text (delegates to the central [AppError]).
String friendlyErrorMessage(Object error) => AppError.message(error);
