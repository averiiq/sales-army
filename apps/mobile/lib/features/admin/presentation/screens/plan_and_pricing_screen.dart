import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/core/theme/app_theme.dart';
import 'package:salesarmy/core/utils/formatters.dart';
import 'package:salesarmy/features/admin/data/models/subscription_plan_model.dart';
import 'package:salesarmy/features/admin/presentation/screens/subscription_checkout_screen.dart';

class PlanAndPricingScreen extends StatefulWidget {
  const PlanAndPricingScreen({super.key});

  @override
  State<PlanAndPricingScreen> createState() => _PlanAndPricingScreenState();
}

class _PlanAndPricingScreenState extends State<PlanAndPricingScreen> {
  bool _isYearly = false; // Toggle between Monthly and Yearly (Save 20%)

  void _openCheckout(BuildContext context, SubscriptionPlanModel plan) {
    HapticFeedback.mediumImpact();
    SubscriptionCheckoutScreen.show(
      context,
      plan: plan,
      isYearly: _isYearly,
      includePrinter: true,
      showPrinter: true,
      showCoupon: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final tenant = appState.tenant;
    final plans = appState.subscriptionPlans;
    final isDark = appState.isDarkMode || Theme.of(context).brightness == Brightness.dark;

    final currentPlan = appState.currentPlan;
    final isTrial = appState.isTrial;
    final expiryDate = tenant.subscriptionEndDate != null
        ? (isTrial
            ? '${AppFormatters.date(tenant.subscriptionEndDate!)} (${appState.remainingTrialDays} days remaining)'
            : AppFormatters.date(tenant.subscriptionEndDate!))
        : 'No end date on file';

    final currentPlanTitle = appState.isReadOnlyMode
        ? '${currentPlan.name} — ${isTrial ? "Trial ended" : "Expired"} (read-only)'
        : (isTrial ? '${currentPlan.name} (Free Trial)' : '${currentPlan.name} Plan');

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Plan & Subscription',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.close_rounded,
            size: 22,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: 'Pull latest plans from cloud',
            icon: Icon(
              Icons.refresh_rounded,
              size: 22,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
            onPressed: () async {
              HapticFeedback.selectionClick();
              final messenger = ScaffoldMessenger.of(context);
              messenger.showSnackBar(const SnackBar(
                content: Text('Pulling latest plans...'),
                duration: Duration(seconds: 1),
              ));
              final ok = await appState.refreshPricingFromCloud();
              if (!context.mounted) return;
              messenger.hideCurrentSnackBar();
              messenger.showSnackBar(SnackBar(
                content: Text(ok
                    ? 'Plans synced from cloud.'
                    : 'Could not reach cloud. Showing last-known plans.'),
                backgroundColor: ok ? const Color(0xFF059669) : const Color(0xFFDC2626),
              ));
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ==========================================
            // 1. Current Active Subscription Hero Card
            // ==========================================
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF78350F).withValues(alpha: 0.5) : AppTheme.yellowSurface,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.workspace_premium_rounded,
                              color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF0F172A),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CURRENT ACTIVE PLAN',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  letterSpacing: 0.6,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                currentPlanTitle,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF064E3B) : const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark ? const Color(0xFF059669) : const Color(0xFFBBF7D0),
                          ),
                        ),
                        child: Text(
                          appState.subscriptionBadgeText,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                  const SizedBox(height: 14),

                  // Metadata Key-Value Rows
                  _buildMetricRow('Plan Validity / Renewal', expiryDate, isDark, isHighlighted: true),
                  const SizedBox(height: 8),
                  _buildMetricRow('Authorized Staff Seats', '${appState.maxAllowedUsers} User${appState.maxAllowedUsers == 1 ? "" : "s"} (${appState.staffList.length} active)', isDark),
                  const SizedBox(height: 8),
                  _buildMetricRow('Product Catalog Limit', 'Up to ${appState.maxAllowedProducts} Products (${appState.products.length} listed)', isDark),
                  const SizedBox(height: 8),
                  _buildMetricRow('Retailer Network Scope', 'Up to ${appState.maxAllowedShops} Shops (${appState.shops.length} onboarded)', isDark),

                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final popularPlan = plans.firstWhere((p) => p.isPopular, orElse: () => plans.first);
                        _openCheckout(context, popularPlan);
                      },
                      icon: const Icon(Icons.flash_on_rounded, size: 18, color: Colors.white),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E56E2),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 1,
                      ),
                      label: const Text(
                        'Upgrade Subscription Plan',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ==========================================
            // 2. Monthly vs Yearly Billing Switcher Capsule
            // ==========================================
            Center(
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _billingToggleOption(
                      title: 'Monthly Billing',
                      isSelected: !_isYearly,
                      isDark: isDark,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _isYearly = false);
                      },
                    ),
                    _billingToggleOption(
                      title: 'Yearly (Save 20%)',
                      isSelected: _isYearly,
                      badge: 'SAVE 20%',
                      isDark: isDark,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _isYearly = true);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ==========================================
            // 3. Available Plans List (Startup, Grow, Enterprise)
            // ==========================================
            ...plans.map((plan) => _buildSubscriptionCard(context, plan, _isYearly, isDark)),

            const SizedBox(height: 12),

            // ==========================================
            // 4. VIP Enterprise Assistance & Support
            // ==========================================
            _buildEnterpriseSupportCard(context, isDark),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, bool isDark, {bool isHighlighted = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isHighlighted
                ? (isDark ? const Color(0xFF38BDF8) : const Color(0xFF1E56E2))
                : (isDark ? Colors.white : const Color(0xFF0F172A)),
          ),
        ),
      ],
    );
  }

  Widget _billingToggleOption({
    required String title,
    required bool isSelected,
    String? badge,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0F172A)) : Colors.transparent,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Row(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
            ),
            if (badge != null && !isSelected) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF059669),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionCard(BuildContext context, SubscriptionPlanModel plan, bool isYearly, bool isDark) {
    final effectivePrice = isYearly ? plan.yearlyMonthlyEquivalent : plan.monthlyPrice;
    final isEnterprise = plan.id == 'enterprise';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: plan.isPopular
              ? (isDark ? const Color(0xFFFBBF24) : const Color(0xFF1E56E2))
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          width: plan.isPopular ? 1.8 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: isDark ? 0.2 : (plan.isPopular ? 0.06 : 0.02)),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            plan.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        if (plan.isPopular) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.yellowPrimary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'MOST POPULAR',
                              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      plan.tagline,
                      style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '₹',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        effectivePrice.toInt().toString(),
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 26,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          letterSpacing: -0.5,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '/mo',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (isYearly)
                    Text(
                      '₹${plan.yearlyAnnualTotal.toInt()} billed annually',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF059669),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Limits Pills
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _limitPill(
                icon: Icons.badge_outlined,
                label: plan.maxStaff >= 900
                    ? 'Unlimited Staff Logins'
                    : 'Up to ${plan.maxStaff} Staff Logins',
                isDark: isDark,
              ),
              _limitPill(
                icon: Icons.receipt_long_outlined,
                label: plan.maxOrdersPerMonth >= 900000
                    ? 'Unlimited Orders / Mo'
                    : '${plan.maxOrdersPerMonth} Orders / Mo',
                isDark: isDark,
              ),
              _limitPill(
                icon: Icons.business_outlined,
                label: plan.maxBranches >= 900
                    ? 'Unlimited Branches'
                    : '${plan.maxBranches} Branch Location${plan.maxBranches == 1 ? "" : "s"}',
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
          const SizedBox(height: 14),

          // Features Checklist
          ...plan.features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_rounded, size: 15, color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF059669)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        f,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 14),

          // Choose Button (Express Direct Checkout)
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isEnterprise
                    ? (isDark ? const Color(0xFF334155) : const Color(0xFF0F172A))
                    : (plan.isPopular ? const Color(0xFFFFCC00) : (isDark ? const Color(0xFF1E56E2) : const Color(0xFFEFF6FF))),
                foregroundColor: isEnterprise
                    ? Colors.white
                    : (plan.isPopular ? const Color(0xFF0F172A) : (isDark ? Colors.white : const Color(0xFF1E56E2))),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _openCheckout(context, plan),
              child: Text(
                isEnterprise ? 'Current Active Plan' : 'Select ${plan.name} Plan',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _limitPill({required IconData icon, required String label, required bool isDark}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnterpriseSupportCard(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.headset_mic_rounded, color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF1E56E2), size: 20),
              const SizedBox(width: 8),
              Text(
                'Enterprise Support & Custom Volume',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Need custom multi-warehouse setup, 50+ van sales reps, or tailor-made ERP integrations? Our enterprise desk is ready to help.',
            style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 15, color: Color(0xFF16A34A)),
                  label: const Text('WhatsApp Desk', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF16A34A),
                    side: const BorderSide(color: Color(0xFF86EFAC)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Opening VIP WhatsApp Enterprise Desk...'), backgroundColor: Color(0xFF16A34A)),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.phone_outlined, size: 15, color: Color(0xFF1E56E2)),
                  label: const Text('Direct Call', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1E56E2),
                    side: const BorderSide(color: Color(0xFF93C5FD)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Calling +91 98765 43210 (Mon-Sat)...'), backgroundColor: Color(0xFF1E56E2)),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
