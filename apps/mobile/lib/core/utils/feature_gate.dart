import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/features/admin/data/models/tenant_model.dart';
import 'package:salesarmy/features/admin/data/models/subscription_plan_model.dart';
import 'package:salesarmy/features/admin/presentation/screens/plan_and_pricing_screen.dart';

/// Gates premium features on the mobile client. Capability keys match the
/// CAPABILITY_CATALOG defined in the admin panel so what you tick there
/// becomes the source of truth for what unlocks here.
class FeatureGate {
  /// Human-readable labels for capability keys. Keep in sync with the admin
  /// panel's CAPABILITY_CATALOG in apps/web-admin/app.js.
  static const Map<String, String> capabilityLabels = {
    'invoicing': 'GST Tax Invoicing',
    'gst_reports': 'GST Reports & Export',
    'khata_ledger': 'Khata Ledgers & PDF Export',
    'dynamic_upi_qr': 'Dynamic UPI QR on Bills',
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

  /// Determines if the tenant is allowed to add another shop based on their limits.
  static bool canAddShop(TenantModel? tenant, int currentShopCount) {
    if (tenant == null) return false;
    if (tenant.accountStatus != 'active') return false;
    final maxShops = tenant.maxShops ?? 50;
    return currentShopCount < maxShops;
  }

  /// Determines if the tenant is allowed to add another user.
  static bool canAddUser(TenantModel? tenant, int currentUserCount) {
    if (tenant == null) return false;
    if (tenant.accountStatus != 'active') return false;
    final maxUsers = tenant.maxUsers ?? 1;
    return currentUserCount < maxUsers;
  }

  /// Pure check — true if plan unlocks [featureName].
  static bool hasFeature(SubscriptionPlanModel? plan, String featureName) {
    if (plan == null) return false;
    if (!plan.isActive) return false;
    return plan.allowedFeatures.contains(featureName);
  }

  /// Checks a feature against the current AppState and, when gated, shows an
  /// upgrade sheet pointing to the Plans screen. Returns true if the user may
  /// proceed, false if blocked.
  static Future<bool> requireFeature(BuildContext context, String featureKey) async {
    final appState = context.read<AppState>();
    if (appState.hasFeature(featureKey)) return true;
    await _showUpgradeSheet(context, featureKey);
    return false;
  }

  static Future<void> _showUpgradeSheet(BuildContext context, String featureKey) {
    final label = capabilityLabels[featureKey] ?? featureKey;
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
                  child: const Icon(Icons.lock_outline_rounded,
                      color: Color(0xFF2563EB), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Upgrade required',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              '$label is not included in your current plan. Upgrade to unlock this capability for your team.',
              style: Theme.of(ctx).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Not now'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const PlanAndPricingScreen(),
                        ),
                      );
                    },
                    child: const Text('View plans'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
