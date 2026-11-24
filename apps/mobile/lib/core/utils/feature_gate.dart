import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/features/admin/data/models/subscription_plan_model.dart';
import 'package:salesarmy/features/admin/presentation/screens/plan_and_pricing_screen.dart';

/// Gates plan capabilities on the mobile client.
///
/// Capability keys match `CAPABILITIES` in apps/web-admin/api/catalog.mjs
/// (and CAPABILITY_CATALOG in app.js): what the super admin ticks for a plan
/// is the source of truth for what unlocks here. The database enforces the
/// same rules, so this is the friendly front door, not the only lock.
class FeatureGate {
  /// Human-readable labels for capability keys.
  static const Map<String, String> capabilityLabels = {
    'order_taking': 'Order Taking & Bill Page',
    'estimate_bills': 'Kaccha / Estimate Bills',
    'invoicing': 'GST Tax Invoicing',
    'sales_returns': 'Sales Returns',
    'collections': 'Payment Collection',
    'khata_ledger': 'Khata Ledgers & PDF Export',
    'dynamic_upi_qr': 'Dynamic UPI QR on Bills',
    'purchases': 'Purchases / Stock Inward',
    'expenses': 'Expense Tracking',
    'visits': 'Visits & Reminders',
    'staff_management': 'Staff Logins & Permissions',
    'thermal_printer': 'Bluetooth Thermal Printing',
    'reports': 'Reports Hub',
    'gst_reports': 'GST Reports & Export',
    'offline_sync': 'Offline Outbox & Cloud Sync',
    'bulk_import': 'Bulk CSV Import',
    'live_tracking': 'Live Beat Tracking (GPS)',
    'van_stock': 'Van Stock & Reconciliation',
    'multi_van': 'Multi-Van Fleet Management',
    'multi_branch': 'Multi-Branch Locations',
    'custom_branding': 'Logo & Brand Customization',
    'custom_tax_slabs': 'Custom Tax Slabs',
    'admin_customization': 'Admin Panel Customization',
    'audit_vault': 'Audit Vault & Compliance',
    'priority_support': 'Priority Phone / WhatsApp',
    'dedicated_manager': 'Dedicated Account Manager',
  };

  /// Pure check — true if [plan] unlocks [featureName] (ignores expiry).
  static bool hasFeature(SubscriptionPlanModel? plan, String featureName) {
    if (plan == null) return false;
    if (!plan.isActive) return false;
    return plan.allowedFeatures.contains(AppState.canonicalFeature(featureName));
  }

  /// Use before USING a capability (opening a gated tool, exporting, …).
  /// Returns true if allowed; otherwise explains why (upgrade / renew) and
  /// returns false. Read-only (expired) agencies may still use view / collect
  /// capabilities — see [AppState.readOnlyFeatures].
  static Future<bool> requireFeature(BuildContext context, String featureKey) async {
    final appState = context.read<AppState>();
    if (appState.hasFeature(featureKey)) return true;
    final reason = appState.isAccountPausedOrCancelled || appState.isReadOnlyMode
        ? appState.writeBlockReason(feature: featureKey)
        : null;
    await _showPlanSheet(
      context,
      title: reason != null ? (appState.isReadOnlyMode ? 'Plan ended' : 'Account paused') : 'Upgrade required',
      message: reason ??
          '${capabilityLabels[AppState.canonicalFeature(featureKey)] ?? featureKey} is not included in your '
              '${appState.currentPlan.name} plan. Upgrade to unlock it for your team.',
      showPlans: !appState.isAccountPausedOrCancelled,
    );
    return false;
  }

  /// Use before CREATING something (order, bill, party, product, staff,
  /// purchase, expense, return, visit). Checks account status, read-only
  /// mode and — when [feature] is given — that the plan includes it.
  static Future<bool> ensureCanWrite(BuildContext context, {String? feature}) async {
    final appState = context.read<AppState>();
    final reason = appState.writeBlockReason(feature: feature);
    if (reason == null) return true;
    await _showPlanSheet(
      context,
      title: appState.isAccountPausedOrCancelled
          ? 'Account paused'
          : (appState.isReadOnlyMode ? 'Plan ended — read-only' : 'Upgrade required'),
      message: reason,
      showPlans: !appState.isAccountPausedOrCancelled,
    );
    return false;
  }

  /// Synchronous guard for button handlers. Returns true if the write may go
  /// ahead; otherwise shows the upgrade / renew sheet and returns false.
  /// [limit] is a plan-limited resource: 'shops', 'products', 'staff', 'orders'.
  static bool allowWrite(BuildContext context, {String? feature, String? limit}) {
    final appState = context.read<AppState>();
    final reason = appState.writeBlockReason(feature: feature);
    if (reason != null) {
      ensureCanWrite(context, feature: feature);
      return false;
    }
    final limitMsg = limit == null ? null : appState.limitReason(limit);
    if (limitMsg != null) {
      _showPlanSheet(context, title: 'Plan limit reached', message: limitMsg);
      return false;
    }
    return true;
  }

  /// Shows the right sheet for an error thrown by AppState (plan limit,
  /// read-only, feature lock). Returns true if [error] was a plan restriction.
  static Future<bool> handleError(BuildContext context, Object error) async {
    if (error is! PlanRestrictionException) return false;
    final appState = context.read<AppState>();
    await _showPlanSheet(
      context,
      title: error.limitReached
          ? 'Plan limit reached'
          : (error.readOnly ? 'Plan ended — read-only' : 'Upgrade required'),
      message: error.message,
      showPlans: !appState.isAccountPausedOrCancelled,
    );
    return true;
  }

  static Future<void> _showPlanSheet(
    BuildContext context, {
    required String title,
    required String message,
    bool showPlans = true,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: 20 + MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF4FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.lock_outline_rounded, color: Color(0xFF2563EB), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(message, style: Theme.of(ctx).textTheme.bodyMedium),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(showPlans ? 'Not now' : 'OK'),
                  ),
                ),
                if (showPlans) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const PlanAndPricingScreen()),
                        );
                      },
                      child: const Text('View plans'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
