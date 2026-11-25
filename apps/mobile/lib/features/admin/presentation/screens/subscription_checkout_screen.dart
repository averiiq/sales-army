import 'dart:async';
import 'package:flutter/material.dart';
import 'package:salesarmy/core/utils/app_error.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:salesarmy/core/services/platform_api.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/core/utils/formatters.dart';
import 'package:salesarmy/features/admin/data/models/subscription_plan_model.dart';
import 'package:salesarmy/features/admin/data/models/printer_option_model.dart';
import 'package:salesarmy/features/admin/data/models/subscription_addon_model.dart';
import 'package:salesarmy/features/admin/data/models/tenant_model.dart';

enum CheckoutPaymentMethod { razorpay, upi, card, netBanking, bankTransfer }

class SubscriptionCheckoutScreen extends StatefulWidget {
  final SubscriptionPlanModel initialPlan;
  final bool initialIsYearly;
  final bool initialIncludePrinter;
  final bool? showPrinter;
  final bool? showCoupon;

  const SubscriptionCheckoutScreen({
    super.key,
    required this.initialPlan,
    this.initialIsYearly = false,
    this.initialIncludePrinter = true,
    this.showPrinter,
    this.showCoupon,
  });

  static Future<bool?> show(
    BuildContext context, {
    required SubscriptionPlanModel plan,
    bool isYearly = false,
    bool includePrinter = true,
    bool? showPrinter,
    bool? showCoupon,
  }) {
    return Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SubscriptionCheckoutScreen(
          initialPlan: plan,
          initialIsYearly: isYearly,
          initialIncludePrinter: includePrinter,
          showPrinter: showPrinter,
          showCoupon: showCoupon,
        ),
      ),
    );
  }

  @override
  State<SubscriptionCheckoutScreen> createState() => _SubscriptionCheckoutScreenState();
}

class _SubscriptionCheckoutScreenState extends State<SubscriptionCheckoutScreen> {
  late SubscriptionPlanModel _selectedPlan;
  late bool _isYearly;
  late bool _includePrinter;
  late bool _showPrinter;
  late bool _showCoupon;
  late PrinterOptionModel _selectedPrinter;

  final Set<String> _selectedAddonIds = {};
  int _selectedAddressType = 0; // 0: Shop Address, 1: + Add New Delivery Address
  bool _isProcessingPayment = false;

  final _couponController = TextEditingController();
  bool _applyingCoupon = false;
  final _recipientNameCtrl = TextEditingController();
  final _recipientPhoneCtrl = TextEditingController();
  final _streetCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedPlan = widget.initialPlan;
    _isYearly = widget.initialIsYearly;
    _showPrinter = widget.showPrinter ?? widget.initialIncludePrinter;
    _showCoupon = widget.showCoupon ?? widget.initialIncludePrinter;
    _includePrinter = _showPrinter ? widget.initialIncludePrinter : false;

    final appState = Provider.of<AppState>(context, listen: false);
    _selectedPrinter = appState.defaultPrinterOption;

    final tenant = appState.tenant;
    _recipientNameCtrl.text = tenant.representativeName ?? '';
    _recipientPhoneCtrl.text = tenant.mobile ?? '';
  }

  @override
  void dispose() {
    _couponController.dispose();
    _recipientNameCtrl.dispose();
    _recipientPhoneCtrl.dispose();
    _streetCtrl.dispose();
    _cityCtrl.dispose();
    _pincodeCtrl.dispose();
    super.dispose();
  }

  bool get _hasHardwareSelected => _includePrinter || _selectedAddonIds.isNotEmpty;

  double get _planBasePrice {
    return _isYearly ? _selectedPlan.yearlyAnnualTotal : _selectedPlan.monthlyPrice;
  }

  double get _printerPrice => _includePrinter ? _selectedPrinter.price : 0.0;

  double _calculatePlanGst(double netPlanPrice) {
    return netPlanPrice * context.read<AppState>().planGstRate / 100;
  }

  double get _printerGst => _includePrinter ? _selectedPrinter.gstAmount : 0.0;

  String _getDeliveryAddress(TenantModel tenant) {
    if (_selectedAddressType == 0) {
      final addr = tenant.address ?? tenant.warehouseAddress ?? 'Registered Shop Address';
      final contact = '${tenant.firmName ?? "Shop"} (${tenant.representativeName ?? "Owner"})${(tenant.mobile ?? tenant.phone) != null ? " • Ph: ${tenant.mobile ?? tenant.phone}" : ""}';
      return '$contact\n$addr';
    } else {
      final parts = [
        if (_recipientNameCtrl.text.trim().isNotEmpty) '${_recipientNameCtrl.text.trim()} (Ph: ${_recipientPhoneCtrl.text.trim()})',
        if (_streetCtrl.text.trim().isNotEmpty) _streetCtrl.text.trim(),
        if (_cityCtrl.text.trim().isNotEmpty) _cityCtrl.text.trim(),
        if (_pincodeCtrl.text.trim().isNotEmpty) 'PIN: ${_pincodeCtrl.text.trim()}',
      ];
      final combined = parts.join(', ');
      return combined.isNotEmpty ? combined : 'New Custom Delivery Address';
    }
  }

  Future<void> _processPaymentAndActivate(AppState appState) async {
    if (_isProcessingPayment) return;

    if (_hasHardwareSelected && _selectedAddressType == 1) {
      if (_streetCtrl.text.trim().isEmpty || _pincodeCtrl.text.trim().isEmpty) {
        showAppError(context, 'Please enter street address and PIN code for hardware delivery.');
        return;
      }
    }

    setState(() => _isProcessingPayment = true);
    HapticFeedback.heavyImpact();

    final shippingAddress = _hasHardwareSelected ? _getDeliveryAddress(appState.tenant) : null;
    final selectedAddons = appState.subscriptionAddons.where((a) => _selectedAddonIds.contains(a.id)).toList();
    try {
      Map<String, dynamic>? result;
      bool serverHandled = false;

      if (PlatformApi.isConfigured) {
        try {
          // A payment made earlier (app closed before verifying) may already
          // be confirmed — activate that instead of charging again.
          final earlier = await appState.reconcilePendingCheckout();
          if (earlier != null) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Your earlier payment was confirmed and your plan is now active.'),
            ));
            Navigator.of(context).maybePop();
            return;
          }

          // The server re-prices everything (plan, coupon, GST, hardware) and
          // reuses an open link for the same purchase, so repeated taps never
          // create a second payment.
          result = await PlatformApi.request('/api/checkout', body: {
            'planId': _selectedPlan.id,
            'yearly': _isYearly,
            'printerId': _includePrinter ? _selectedPrinter.id : null,
            'addonIds': _selectedAddonIds.toList(),
            'shippingAddress': shippingAddress,
            'couponCode': appState.appliedCoupon?.code,
          });

          if (result['status'] != 'paid') {
            final checkoutId = result['id']?.toString() ?? '';
            final url = result['url']?.toString();
            if (checkoutId.isEmpty || url == null || url.isEmpty) {
              throw StateError('The payment server did not return a payment link. Please try again.');
            }
            await appState.savePendingCheckout(id: checkoutId, planId: _selectedPlan.id);
            if (!await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) {
              throw StateError('Unable to open Razorpay checkout.');
            }
            if (!mounted) return;
            final amountPaise = result['amount'] is num ? (result['amount'] as num).toInt() : null;
            result = await showDialog<Map<String, dynamic>>(
              context: context,
              barrierDismissible: false,
              builder: (_) => _AwaitingPaymentDialog(
                checkoutId: checkoutId,
                paymentUrl: url,
                amountPaise: amountPaise,
                planName: _selectedPlan.name,
              ),
            );
            // "Later": the saved checkout is re-checked on the next launch.
            if (result == null) return;
          }

          if (result['status'] != 'paid') {
            throw StateError('Payment is not confirmed yet. If you paid, it will activate automatically within a few minutes.');
          }
          serverHandled = true;
        } catch (serverErr) {
          // Only when online payment is NOT set up at all (platform function
          // not deployed yet, or no Razorpay keys on it) do we fall through to
          // test activation — which the admin toggle still controls. Any real
          // payment/server error is shown, never silently upgraded for free.
          final msg = serverErr.toString().toLowerCase();
          final paymentsNotSetUp = msg.contains('requested function was not found') ||
              msg.contains('payments are not configured') ||
              msg.contains('razorpay is not configured');
          debugPrint('PlatformApi checkout error: $serverErr');
          if (!paymentsNotSetUp) rethrow;
        }
      }

      await appState.clearPendingCheckout();

      // The plan is ALWAYS activated by the server: either the payment server
      // confirmed a paid checkout above, or (testing, no payment server yet)
      // the database RPC activates it while the admin allows test activation.
      // Never only on this phone — the next cloud sync would undo that.
      final bool testActivation = !serverHandled;
      final DateTime endDate;
      if (serverHandled) {
        endDate = DateTime.tryParse(result?['expiresAt']?.toString() ?? '') ??
            DateTime.now().add(Duration(days: _isYearly ? 365 : 30));
        await appState.applyServerPlanActivation(
          planId: _selectedPlan.id,
          expiresAt: endDate,
          status: appState.appliedCoupon?.type.name == 'trial' ? 'trial' : 'active',
        );
      } else {
        endDate = await appState.activatePlanForTesting(_selectedPlan.id, yearly: _isYearly);
      }

      final updatedTenant = appState.tenant.copyWith(
        hardwareConfig: {
          'hasPrinter': _includePrinter,
          'printerModel': _includePrinter ? _selectedPrinter.name : 'None',
          'printerId': _includePrinter ? _selectedPrinter.id : null,
          'printerPrice': _includePrinter ? _selectedPrinter.price : 0,
          'printerStatus': _includePrinter ? 'PURCHASED (₹${_selectedPrinter.price.toInt()})' : 'Not Ordered',
          'selectedAddonIds': _selectedAddonIds.toList(),
          'selectedAddons': selectedAddons.map((a) => {'id': a.id, 'title': a.title, 'price': a.price}).toList(),
          if (shippingAddress != null) 'shippingAddress': shippingAddress,
          'paymentGateway': 'Razorpay',
          'orderedAt': DateTime.now().toIso8601String(),
          'planName': _selectedPlan.name,
        },
      );

      await appState.updateTenant(updatedTenant);

      if (_hasHardwareSelected) {
        final hardwareItems = <String>[];
        if (_includePrinter) hardwareItems.add(_selectedPrinter.name);
        for (final a in selectedAddons) {
          hardwareItems.add(a.title);
        }

        await appState.postHardwareOrderToBridge({
          'userId': appState.currentUid ?? appState.tenant.tenantId,
          'customerName': appState.tenant.representativeName ?? (appState.tenant.firmName ?? 'Valued Customer'),
          'agencyName': appState.tenant.firmName ?? 'Distributor Agency',
          'phone': appState.tenant.phone ?? '+91 9820000000',
          'plan': '${_selectedPlan.name} (${_isYearly ? "Annual" : "Monthly"})',
          'printerItem': _includePrinter ? _selectedPrinter.name : 'None',
          'hardwareItems': hardwareItems.join(', '),
          'price': (_includePrinter ? _selectedPrinter.price : 0.0) + selectedAddons.fold(0.0, (acc, a) => acc + a.price),
          'shippingAddress': shippingAddress ?? (appState.tenant.address ?? 'Shop Address'),
          'paymentGateway': 'Razorpay',
        });
      }

      await appState.syncAllFromCloud();
      if (!mounted) return;
      final paymentId = (serverHandled && result != null && result['paymentId'] != null)
          ? result['paymentId'].toString()
          : (testActivation ? 'TEST ACTIVATION — no payment taken' : null);
      _showSuccessReceiptDialog(appState, endDate, shippingAddress, selectedAddons, paymentId);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _isProcessingPayment = false);
    }
  }

  void _showSuccessReceiptDialog(
    AppState appState,
    DateTime endDate,
    String? shippingAddress,
    List<SubscriptionAddonModel> selectedAddons,
    String? paymentId,
  ) {
    final isDark = appState.isDarkMode;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment & Plan Activated!',
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      paymentId == null ? 'Promotional activation verified' : 'Razorpay Txn: $paymentId',
                      style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Activated Plan:', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                        Text('${_selectedPlan.name} (${_isYearly ? "Annual" : "Monthly"})', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Plan Valid Till:', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                        Text(AppFormatters.date(endDate), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF059669))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Staff User Seats:', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                        Text('${_selectedPlan.maxUsers} Users Included', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Hardware Items:', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                        Flexible(
                          child: Text(
                            _includePrinter
                                ? '${_selectedPrinter.name}${selectedAddons.isNotEmpty ? " + ${selectedAddons.length} Add-on(s)" : ""}'
                                : (selectedAddons.isNotEmpty ? '${selectedAddons.length} Hardware Add-on(s)' : 'No Hardware Ordered'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: _hasHardwareSelected ? const Color(0xFF1E56E2) : const Color(0xFF64748B),
                            ),
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                    if (_hasHardwareSelected && shippingAddress != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Dispatching to: $shippingAddress',
                        style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E56E2),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context, true);
              },
              child: const Text('Back to Dashboard', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isDark = appState.isDarkMode;
    final plans = appState.subscriptionPlans;
    final tenant = appState.tenant;

    final appliedCoupon = appState.appliedCoupon;
    final isTrial = appliedCoupon?.type.name == 'trial';
    final discount = appliedCoupon?.calculateDiscount(_planBasePrice) ?? 0.0;
    final netPlan = (_planBasePrice - discount).clamp(0.0, double.infinity);
    final planGst = isTrial ? 0.0 : _calculatePlanGst(netPlan);

    // Dynamic Hardware & Add-on Calculations
    final availableAddons = appState.subscriptionAddons.where((a) => a.isAvailable).toList();
    final selectedAddonsList = availableAddons.where((a) => _selectedAddonIds.contains(a.id)).toList();
    final addonsPrice = selectedAddonsList.fold<double>(0.0, (acc, a) => acc + a.price);
    final addonsGst = selectedAddonsList.fold<double>(0.0, (acc, a) => acc + (a.price * a.gstRate / 100));

    final printerTotalWithGst = _printerPrice + _printerGst;
    final hardwareTotalWithGst = (_includePrinter ? printerTotalWithGst : 0.0) + addonsPrice + addonsGst;
    final grandTotal = netPlan + planGst + hardwareTotalWithGst;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text(
              'Express Checkout',
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_rounded, size: 10, color: Color(0xFF16A34A)),
                const SizedBox(width: 4),
                Text(
                  '256-Bit SSL Encrypted • Instant Activation',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A),
                  ),
                ),
              ],
            ),
          ],
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Unified Plan & Billing Capsule Card
            _buildPlanCard(plans, isDark),
            const SizedBox(height: 14),

            // 2. Dynamic Hardware Add-on (POS Thermal Printers & Pack Accessories)
            if (_showPrinter) ...[
              _buildHardwareCard(appState, tenant, isDark, printerTotalWithGst, availableAddons),
              const SizedBox(height: 14),
            ],

            // 3. Coupon Bar (Direct Input & Apply Only)
            if (_showCoupon) ...[
              _buildCouponsCard(appState, isDark, appliedCoupon),
              const SizedBox(height: 14),
            ],

            // 4. Integrated Razorpay Gateway Card (All Options)
            _buildPaymentMethodsCard(isDark),
            const SizedBox(height: 14),

            // 5. Transparent Order & Bill Breakdown
            _buildOrderBreakdownCard(
              isDark,
              discount,
              appliedCoupon,
              planGst,
              grandTotal,
              isTrial,
              selectedAddonsList,
              addonsGst,
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E56E2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 1,
                  ),
                  onPressed: _isProcessingPayment ? null : () => _processPaymentAndActivate(appState),
                  icon: _isProcessingPayment
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.flash_on_rounded, size: 20, color: Colors.white),
                  label: Text(
                    _isProcessingPayment
                        ? 'Processing with Razorpay...'
                        : (isTrial && !_hasHardwareSelected
                            ? 'Start 30-Day Free Trial (₹0)'
                            : 'Pay ₹${grandTotal.toInt()} via Razorpay & Activate'),
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Instant access to all features • Cancel or upgrade anytime',
                style: TextStyle(
                  fontSize: 10.5,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- COMPACT, HIGH-EFFICIENCY WIDGETS ---

  Widget _buildPlanCard(List<SubscriptionPlanModel> plans, bool isDark) {
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E56E2).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.workspace_premium_rounded, color: Color(0xFF1E56E2), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Selected Subscription Plan',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '1-CLICK SELECT',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF16A34A)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Plan Selector Chips
          Row(
            children: plans.map((p) {
              final isSelected = p.id == _selectedPlan.id;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.5),
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedPlan = p);
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF1E56E2)
                            : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF1E56E2) : Colors.transparent,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        children: [
                          Text(
                            p.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: isSelected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            '₹${p.monthlyPrice.toInt()}/mo',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? const Color(0xFFBFDBFE) : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // Billing Cycle Toggle (Monthly vs Annual with 20% off)
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _isYearly = false);
                    },
                    borderRadius: BorderRadius.circular(9),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: !_isYearly ? (isDark ? const Color(0xFF1E293B) : Colors.white) : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: !_isYearly
                            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Monthly (₹${_selectedPlan.monthlyPrice.toInt()}/mo)',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: !_isYearly ? FontWeight.w800 : FontWeight.w600,
                          color: !_isYearly ? (isDark ? Colors.white : const Color(0xFF0F172A)) : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _isYearly = true);
                    },
                    borderRadius: BorderRadius.circular(9),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _isYearly ? (isDark ? const Color(0xFF1E293B) : Colors.white) : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: _isYearly
                            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Annual (Save 20%)',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: _isYearly ? FontWeight.w800 : FontWeight.w600,
                              color: _isYearly ? const Color(0xFF1E56E2) : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('20% OFF', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: Color(0xFF16A34A))),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Features Summary
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Includes ${_selectedPlan.maxUsers} Users • ${_selectedPlan.maxProducts >= 999999 ? "Unlimited" : _selectedPlan.maxProducts} Products',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
              Text(
                _isYearly ? '₹${_selectedPlan.yearlyAnnualTotal.toInt()}/yr' : '₹${_selectedPlan.monthlyPrice.toInt()}/mo',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: Color(0xFF1E56E2)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHardwareCard(
    AppState appState,
    TenantModel tenant,
    bool isDark,
    double printerTotalWithGst,
    List<SubscriptionAddonModel> availableAddons,
  ) {
    final availablePrinters = appState.printerOptions.where((p) => p.isAvailable).toList();
    if (availablePrinters.isEmpty) {
      availablePrinters.add(_selectedPrinter);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _hasHardwareSelected
            ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.2) : const Color(0xFFEFF6FF))
            : (isDark ? const Color(0xFF1E293B) : Colors.white),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _hasHardwareSelected
              ? const Color(0xFF1E56E2)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          width: _hasHardwareSelected ? 1.6 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _includePrinter ? const Color(0xFF1E56E2) : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.print_rounded,
                  color: _includePrinter ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Flexible(
                          child: Text(
                            'Wireless Thermal POS Printer',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('OPTIONAL', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: Color(0xFFB45309))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '₹${_selectedPrinter.price.toInt()} + ${_selectedPrinter.gstRate.toInt()}% GST (${_selectedPrinter.name})',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _includePrinter ? const Color(0xFF1E56E2) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: _includePrinter,
                activeTrackColor: const Color(0xFF1E56E2),
                onChanged: (val) {
                  HapticFeedback.lightImpact();
                  setState(() => _includePrinter = val);
                },
              ),
            ],
          ),

          // Dynamic Printer Model Selector (Admin Controlled)
          if (_includePrinter) ...[
            const SizedBox(height: 12),
            Text(
              'SELECT PRINTER MODEL (ADMIN CONTROLLED):',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 8),
            ...availablePrinters.map((printer) {
              final isChosen = printer.id == _selectedPrinter.id;
              return InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedPrinter = printer);
                },
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isChosen
                        ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF))
                        : (isDark ? const Color(0xFF0F172A) : Colors.white),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isChosen ? const Color(0xFF1E56E2) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      width: isChosen ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isChosen ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                        color: isChosen ? const Color(0xFF1E56E2) : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    printer.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    printer.paperWidth,
                                    style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                  ),
                                ),
                              ],
                            ),
                            if (printer.description.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                printer.description,
                                style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹${printer.price.toInt()}',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF1E56E2)),
                          ),
                          Text(
                            '+${printer.gstRate.toInt()}% GST',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],

          // Dynamic Hardware & Pack Add-ons (Admin Controlled)
          if (availableAddons.isNotEmpty) ...[
            const SizedBox(height: 10),
            Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFDBEAFE)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ADD HARDWARE & PACK ACCESSORIES:',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('ADMIN CONTROLLED', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Color(0xFF16A34A))),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...availableAddons.map((addon) {
              final isSelected = _selectedAddonIds.contains(addon.id);
              return InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    if (isSelected) {
                      _selectedAddonIds.remove(addon.id);
                    } else {
                      _selectedAddonIds.add(addon.id);
                    }
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF))
                        : (isDark ? const Color(0xFF0F172A) : Colors.white),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF1E56E2) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Checkbox(
                        value: isSelected,
                        activeColor: const Color(0xFF1E56E2),
                        onChanged: (val) {
                          HapticFeedback.selectionClick();
                          setState(() {
                            if (val == true) {
                              _selectedAddonIds.add(addon.id);
                            } else {
                              _selectedAddonIds.remove(addon.id);
                            }
                          });
                        },
                      ),
                      const SizedBox(width: 4),
                      Icon(addon.icon, size: 20, color: isSelected ? const Color(0xFF1E56E2) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              addon.title,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            if (addon.description.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                addon.description,
                                style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '+₹${addon.price.toInt()}',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF1E56E2)),
                          ),
                          Text(
                            '+18% GST',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],

          // Delivery Shipping Address (2 Options Only: Shop Address OR Add New)
          if (_hasHardwareSelected) ...[
            const SizedBox(height: 10),
            Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFDBEAFE)),
            const SizedBox(height: 10),
            Text(
              'SELECT DELIVERY SHIPPING ADDRESS:',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 8),

            // Option 0: Shop Address
            _buildAddressOption(
              index: 0,
              title: 'Shop Address',
              subtitle: tenant.address ?? tenant.warehouseAddress ?? 'Registered Commercial Premises / Shop Address',
              isDark: isDark,
            ),
            const SizedBox(height: 6),

            // Option 1: + Add New Delivery Address
            _buildAddressOption(
              index: 1,
              title: '+ Add New Delivery Address',
              subtitle: _selectedAddressType == 1 && _streetCtrl.text.isNotEmpty
                  ? '${_streetCtrl.text.trim()}, PIN: ${_pincodeCtrl.text.trim()}'
                  : 'Specify alternative shipping address for hardware courier dispatch',
              isDark: isDark,
            ),

            if (_selectedAddressType == 1) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF1E56E2).withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'New Delivery Address Details:',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() {
                              _recipientNameCtrl.text = (tenant.representativeName?.isNotEmpty == true
                                  ? tenant.representativeName!
                                  : (tenant.firmName ?? '')).trim();
                              _recipientPhoneCtrl.text = (tenant.mobile ?? '').trim();
                              final bizAddr = (tenant.warehouseAddress ?? tenant.address ?? '').trim();
                              _streetCtrl.text = bizAddr;
                              if (bizAddr.toLowerCase().contains('pune')) {
                                _cityCtrl.text = 'Pune';
                              } else {
                                final parts = bizAddr.split(',');
                                if (parts.length > 1) {
                                  _cityCtrl.text = parts.last.trim();
                                } else {
                                  _cityCtrl.text = 'Pune';
                                }
                              }
                              _pincodeCtrl.text = '411037';
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Pre-filled shipping fields from Business Details! You can edit any field.'),
                                duration: Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF1E56E2).withValues(alpha: 0.3)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.flash_on_rounded, size: 12, color: Color(0xFF1E56E2)),
                                SizedBox(width: 4),
                                Text(
                                  'Auto-fill Business Address',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF1E56E2)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _smallTextField(_recipientNameCtrl, 'Recipient Name', isDark)),
                        const SizedBox(width: 8),
                        Expanded(child: _smallTextField(_recipientPhoneCtrl, 'Contact Phone', isDark, isNumber: true)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _smallTextField(_streetCtrl, 'Street / Area / Flat / Landmark', isDark),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _smallTextField(_cityCtrl, 'City / District', isDark)),
                        const SizedBox(width: 8),
                        SizedBox(width: 100, child: _smallTextField(_pincodeCtrl, 'PIN Code', isDark, isNumber: true)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildAddressOption({
    required int index,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    final isSelected = _selectedAddressType == index;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedAddressType = index;
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF))
              : (isDark ? const Color(0xFF0F172A) : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF1E56E2) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                color: isSelected ? const Color(0xFF1E56E2) : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? (isDark ? Colors.white : const Color(0xFF0F172A)) : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _smallTextField(TextEditingController ctrl, String hint, bool isDark, {bool isNumber = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white : const Color(0xFF0F172A)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
        filled: true,
        fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // Coupon Card: Only input field and apply button (no displayed coupon chips)
  Widget _buildCouponsCard(AppState appState, bool isDark, dynamic appliedCoupon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_offer_rounded, size: 16, color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF059669)),
              const SizedBox(width: 8),
              Text(
                'Offers & Coupons',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Custom Input Field & Apply Button Only
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _couponController,
                  textCapitalization: TextCapitalization.characters,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    hintText: 'Enter coupon or promo code...',
                    hintStyle: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _applyingCoupon ? null : () async {
                  final code = _couponController.text.trim();
                  if (code.isEmpty) return;
                  setState(() => _applyingCoupon = true);
                  final error = await appState.applyCoupon(code, planId: _selectedPlan.id, yearly: _isYearly);
                  if (!mounted) return;
                  setState(() => _applyingCoupon = false);
                  if (error == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Coupon "${code.toUpperCase()}" applied!'), backgroundColor: const Color(0xFF059669)),
                    );
                  } else {
                    showAppError(context, error);
                  }
                },
                child: Text(_applyingCoupon ? 'Checking…' : 'Apply', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              ),
            ],
          ),

          // Applied Banner (shown when coupon is successfully applied)
          if (appliedCoupon != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.3) : const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF059669)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF16A34A)),
                      const SizedBox(width: 6),
                      Text(
                        'Applied: ${appliedCoupon.code} (${appliedCoupon.title})',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF16A34A)),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () {
                      appState.clearAppliedCoupon();
                      _couponController.clear();
                    },
                    child: const Text('Remove', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Integrated Razorpay Payment Gateway Card with all payment methods
  Widget _buildPaymentMethodsCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
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
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0C2340).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.shield_rounded, size: 16, color: Color(0xFF0C2340)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Payment Method',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_rounded, size: 11, color: Color(0xFF1D4ED8)),
                    SizedBox(width: 4),
                    Text(
                      'RAZORPAY INTEGRATED',
                      style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: Color(0xFF1D4ED8)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                    : [const Color(0xFFF0F7FF), Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1E56E2).withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0C2340),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Razorpay',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11.5, letterSpacing: 0.5),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Secure All-in-One Gateway',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 18),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Razorpay includes all payment options with instant activation:',
                  style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
                const SizedBox(height: 10),
                _razorpayMethodItem(Icons.qr_code_2_rounded, 'UPI Express', 'Google Pay, PhonePe, Paytm, BHIM, Any UPI ID / QR', isDark),
                const SizedBox(height: 7),
                _razorpayMethodItem(Icons.credit_card_rounded, 'Cards', 'Visa, MasterCard, RuPay, Maestro (Credit & Debit)', isDark),
                const SizedBox(height: 7),
                _razorpayMethodItem(Icons.account_balance_rounded, 'Net Banking', 'SBI, HDFC, ICICI, Axis & 50+ Banks', isDark),
                const SizedBox(height: 7),
                _razorpayMethodItem(Icons.account_balance_wallet_rounded, 'Wallets & PayLater', 'Amazon Pay, Mobikwik, Airtel Money & more', isDark),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_rounded, size: 12, color: Color(0xFF16A34A)),
              const SizedBox(width: 4),
              Text(
                '100% RBI Compliant • PCI-DSS Level 1 Certified • 256-Bit SSL',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _razorpayMethodItem(IconData icon, String title, String subtitle, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: const Color(0xFF1E56E2)),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 11, color: isDark ? Colors.white : const Color(0xFF0F172A)),
              children: [
                TextSpan(text: '$title: ', style: const TextStyle(fontWeight: FontWeight.w800)),
                TextSpan(
                  text: subtitle,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderBreakdownCard(
    bool isDark,
    double discount,
    dynamic appliedCoupon,
    double planGst,
    double grandTotal,
    bool isTrial,
    List<SubscriptionAddonModel> selectedAddons,
    double addonsGst,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long_rounded, size: 16, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              const SizedBox(width: 8),
              Text(
                'Transparent Bill Breakdown',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _summaryRow('${_selectedPlan.name} Plan (${_isYearly ? "Annual" : "Monthly"})', '₹${_planBasePrice.toInt()}', isDark),
          if (discount > 0)
            _summaryRow('Coupon Discount (${appliedCoupon?.code ?? ""})', '-₹${discount.toInt()}', isDark, isHighlight: true),
          _summaryRow('Plan GST (${context.read<AppState>().planGstRate}%)', '₹${planGst.toInt()}', isDark),
          if (_includePrinter) ...[
            const Divider(height: 12),
            _summaryRow(_selectedPrinter.name, '₹${_selectedPrinter.price.toInt()}', isDark),
            _summaryRow('Printer GST (${_selectedPrinter.gstRate.toInt()}%)', '₹${_printerGst.toInt()}', isDark),
          ],
          if (selectedAddons.isNotEmpty) ...[
            const Divider(height: 12),
            ...selectedAddons.map((addon) => _summaryRow(addon.title, '₹${addon.price.toInt()}', isDark)),
            _summaryRow('Add-ons GST', '₹${addonsGst.toInt()}', isDark),
          ],
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Payable Today:',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              Text(
                isTrial && !_hasHardwareSelected ? '₹0 (Free Trial)' : '₹${grandTotal.toInt()}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E56E2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, bool isDark, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w500,
                color: isHighlight
                    ? const Color(0xFF16A34A)
                    : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B)),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: isHighlight
                  ? const Color(0xFF16A34A)
                  : (isDark ? Colors.white : const Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }
}


/// Shown while the user pays on Razorpay. Checks the payment with the server
/// automatically (on returning to the app and every few seconds), so the plan
/// activates without relying on the user tapping "Verify". Pops with the
/// server result once PAID, or null for "Later".
class _AwaitingPaymentDialog extends StatefulWidget {
  final String checkoutId;
  final String paymentUrl;
  final int? amountPaise;
  final String planName;

  const _AwaitingPaymentDialog({
    required this.checkoutId,
    required this.paymentUrl,
    required this.amountPaise,
    required this.planName,
  });

  @override
  State<_AwaitingPaymentDialog> createState() => _AwaitingPaymentDialogState();
}

class _AwaitingPaymentDialogState extends State<_AwaitingPaymentDialog> with WidgetsBindingObserver {
  Timer? _poll;
  bool _checking = false;
  bool _closed = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _poll = Timer.periodic(const Duration(seconds: 6), (_) => _check());
  }

  @override
  void dispose() {
    _poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check(userAsked: true);
  }

  Future<void> _check({bool userAsked = false}) async {
    if (_checking || _closed || !mounted) return;
    setState(() => _checking = true);
    try {
      final result = await PlatformApi.request(
        '/api/checkout?id=${Uri.encodeQueryComponent(widget.checkoutId)}',
      );
      if (!mounted || _closed) return;
      final status = result['status']?.toString();
      if (status == 'paid') {
        _closed = true;
        _poll?.cancel();
        Navigator.of(context).pop(result);
        return;
      }
      if (status == 'expired' || status == 'cancelled') {
        _poll?.cancel();
        setState(() => _message = 'This payment link has $status. Close this and tap Pay again for a new link.');
      } else if (userAsked) {
        setState(() => _message = 'Payment not received yet. If you just paid, wait a few seconds.');
      }
    } catch (e) {
      if (mounted && userAsked) {
        setState(() => _message = e.toString().replaceFirst('Bad state: ', ''));
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final amount = widget.amountPaise;
    return AlertDialog(
      title: const Text('Complete payment on Razorpay'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.planName, style: const TextStyle(fontWeight: FontWeight.w700)),
          if (amount != null) ...[
            const SizedBox(height: 4),
            Text(
              'Amount to pay: ₹${(amount / 100).toStringAsFixed(2)} (incl. GST)',
              key: const ValueKey('checkout_server_amount'),
            ),
          ],
          const SizedBox(height: 12),
          const Text(
            'Your plan activates automatically as soon as Razorpay confirms the payment. '
            'You can come back to the app after paying.',
          ),
          if (_message != null) ...[
            const SizedBox(height: 12),
            Text(_message!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          if (_checking) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            _closed = true;
            Navigator.of(context).pop();
          },
          child: const Text('Later'),
        ),
        TextButton(
          onPressed: () => launchUrl(Uri.parse(widget.paymentUrl), mode: LaunchMode.externalApplication),
          child: const Text('Open payment page'),
        ),
        FilledButton(
          onPressed: _checking ? null : () => _check(userAsked: true),
          child: const Text("I've paid"),
        ),
      ],
    );
  }
}
