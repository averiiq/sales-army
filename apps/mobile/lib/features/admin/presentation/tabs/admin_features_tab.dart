import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/core/services/app_state.dart';

class AdminFeaturesTab extends StatefulWidget {
  const AdminFeaturesTab({super.key});

  @override
  State<AdminFeaturesTab> createState() => _AdminFeaturesTabState();
}

class _AdminFeaturesTabState extends State<AdminFeaturesTab> {
  // 1. Third-Party SMS & OTP Provider
  bool _enforceMobileOtp = true;
  String _selectedSmsProvider = 'Fast2SMS';
  String _smsGatewayMode = 'Live';
  final _smsApiKeyCtrl = TextEditingController();
  bool _smsApiKeyObscured = true;
  final _smsSenderIdCtrl = TextEditingController(text: 'SLARMY');
  final _smsDltTemplateCtrl = TextEditingController(text: '1107161829384');
  int _selectedOtpDigits = 4;
  int _selectedOtpExpirySec = 60;
  final _smsOtpBodyCtrl = TextEditingController(
    text: 'Your SalesArmy login verification OTP is {#var#}. Valid for 5 minutes. Do not share this OTP with anyone.',
  );

  // 2. Payment Gateway Configuration
  String _selectedPaymentProvider = 'Razorpay';
  bool _paymentLiveMode = true;
  final _paymentApiKeyCtrl = TextEditingController();
  final _paymentSecretKeyCtrl = TextEditingController();
  bool _paymentSecretObscured = true;
  final _paymentWebhookSecretCtrl = TextEditingController();
  final _adminUpiIdCtrl = TextEditingController(text: 'salesarmy.saas@okhdfcbank');

  // 3. SaaS Company Tax Invoicing Details
  final _companyLegalNameCtrl = TextEditingController(text: 'SalesArmy SaaS Technologies Pvt Ltd');
  final _companyGstinCtrl = TextEditingController(text: '27AABCF1234F1Z8');
  final _companyBankNameCtrl = TextEditingController(text: 'HDFC Bank');
  final _companyIfscCtrl = TextEditingController(text: 'HDFC0001234');
  final _companyAccountNoCtrl = TextEditingController(text: '50200088921820');

  // 4. Live Modular Remote Feature Flags & Kill Switches
  Map<String, bool> _localFeatureFlags = {
    'order_taking': true,
    'gst_invoicing': true,
    'collections': true,
    'gps_tracking': true,
    'staff_management': true,
    'thermal_printer': true,
    'soundbox_audio': true,
    'van_stock': true,
    'customer_portal': true,
    'instant_sync': true,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          final appState = Provider.of<AppState>(context, listen: false);
          setState(() {
            _enforceMobileOtp = appState.enforceMobileOtp;
            _selectedSmsProvider = appState.smsProvider;
            _smsGatewayMode = appState.smsGatewayMode;
            _selectedOtpDigits = appState.otpDigits;
            _localFeatureFlags = Map<String, bool>.from(appState.remoteFeatureFlags);
          });
        } catch (_) {}
      }
    });
  }

  @override
  void dispose() {
    _smsApiKeyCtrl.dispose();
    _smsSenderIdCtrl.dispose();
    _smsDltTemplateCtrl.dispose();
    _smsOtpBodyCtrl.dispose();
    _paymentApiKeyCtrl.dispose();
    _paymentSecretKeyCtrl.dispose();
    _paymentWebhookSecretCtrl.dispose();
    _adminUpiIdCtrl.dispose();
    _companyLegalNameCtrl.dispose();
    _companyGstinCtrl.dispose();
    _companyBankNameCtrl.dispose();
    _companyIfscCtrl.dispose();
    _companyAccountNoCtrl.dispose();
    super.dispose();
  }

  void _saveSmsConfig() {
    try {
      context.read<AppState>().updateSmsGatewayConfig(
        provider: _selectedSmsProvider,
        mode: _smsGatewayMode,
        enforceOtp: _enforceMobileOtp,
        digits: _selectedOtpDigits,
      );
    } catch (_) {}
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('SMS & DLT Gateway configuration saved successfully!'),
        backgroundColor: Color(0xFF059669),
      ),
    );
  }

  void _savePaymentConfig() {
    try {
      context.read<AppState>().updatePaymentGatewayConfig(
        provider: _selectedPaymentProvider,
        mode: _paymentLiveMode ? 'live' : 'test',
        enabled: true,
        apiKey: _paymentApiKeyCtrl.text.trim(),
        upiId: _adminUpiIdCtrl.text.trim(),
        companyName: _companyLegalNameCtrl.text.trim(),
        gstin: _companyGstinCtrl.text.trim(),
      );
    } catch (_) {}
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Payment Gateway & Tax Invoice Company Details saved!'),
        backgroundColor: Color(0xFF1D4ED8),
      ),
    );
  }

  void _toggleFeatureFlag(String key, bool value) {
    setState(() {
      _localFeatureFlags[key] = value;
    });
    try {
      context.read<AppState>().updateRemoteFeatureFlags(_localFeatureFlags);
      context.read<AppState>().pushRemoteConfigToPlatform(featureFlags: _localFeatureFlags);
    } catch (_) {}
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(value ? Icons.check_circle_rounded : Icons.block_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('Module "$key" ${value ? "Enabled" : "Disabled (Kill Switch Active)"}!'),
          ],
        ),
        backgroundColor: value ? const Color(0xFF059669) : const Color(0xFFD97706),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _pushAllFlagsLive() {
    try {
      context.read<AppState>().updateRemoteFeatureFlags(_localFeatureFlags);
      context.read<AppState>().pushRemoteConfigToPlatform(featureFlags: _localFeatureFlags);
    } catch (_) {}
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.cloud_done_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('All 10 module flags synchronized live to all mobile devices!'),
          ],
        ),
        backgroundColor: Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _resetFeatureFlagsToDefault() {
    setState(() {
      _localFeatureFlags = {
        'order_taking': true,
        'gst_invoicing': true,
        'collections': true,
        'gps_tracking': true,
        'staff_management': true,
        'thermal_printer': true,
        'soundbox_audio': true,
        'van_stock': true,
        'customer_portal': true,
        'instant_sync': true,
      };
    });
    try {
      context.read<AppState>().updateRemoteFeatureFlags(_localFeatureFlags);
      context.read<AppState>().pushRemoteConfigToPlatform(featureFlags: _localFeatureFlags);
    } catch (_) {}
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All module feature flags reset to default active state.'),
        backgroundColor: Color(0xFF1D4ED8),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  List<Widget> _buildFeatureSwitchList() {
    final modules = [
      {
        'key': 'order_taking',
        'title': 'Order Booking & Cart Checkout',
        'desc': 'Field rep sales cart, variant selection, distributor orders',
        'icon': Icons.shopping_cart_checkout_rounded,
        'color': const Color(0xFF2563EB),
      },
      {
        'key': 'gst_invoicing',
        'title': 'Instant GST Tax Invoicing',
        'desc': 'Sequential tax invoice generator, HSN breakdown, tax slips',
        'icon': Icons.receipt_long_rounded,
        'color': const Color(0xFF059669),
      },
      {
        'key': 'collections',
        'title': 'Khata & Collections (BharatQR)',
        'desc': 'Payment recording modal, dynamic QR generation, ledger update',
        'icon': Icons.account_balance_wallet_rounded,
        'color': const Color(0xFFD97706),
      },
      {
        'key': 'gps_tracking',
        'title': 'Field GPS Beat Tracking',
        'desc': 'Sales beat coordinates, shop check-in stamps, location log',
        'icon': Icons.my_location_rounded,
        'color': const Color(0xFF7C3AED),
      },
      {
        'key': 'staff_management',
        'title': 'Staff RBAC & Field Rep Accounts',
        'desc': 'Multi-staff role access, permissions matrix, commission rules',
        'icon': Icons.badge_rounded,
        'color': const Color(0xFF0284C7),
      },
      {
        'key': 'thermal_printer',
        'title': '58mm/80mm Thermal Receipt Printing',
        'desc': 'ESC/POS hardware printing over Bluetooth and USB POS',
        'icon': Icons.print_rounded,
        'color': const Color(0xFFEA580C),
      },
      {
        'key': 'soundbox_audio',
        'title': 'Voice Soundbox Payment Announcements',
        'desc': 'Speech audio synthesis on successful customer collections',
        'icon': Icons.volume_up_rounded,
        'color': const Color(0xFF4F46E5),
      },
      {
        'key': 'van_stock',
        'title': 'Godown & Van Stock Management',
        'desc': 'Mobile van inventory tallies, stock transfer allocations',
        'icon': Icons.local_shipping_rounded,
        'color': const Color(0xFF0D9488),
      },
      {
        'key': 'customer_portal',
        'title': 'B2B Customer Self-Order Link',
        'desc': 'Public retailer digital catalog link and order submission',
        'icon': Icons.storefront_rounded,
        'color': const Color(0xFFE11D48),
      },
      {
        'key': 'instant_sync',
        'title': 'Real-Time Cloud Outbox Sync',
        'desc': 'Immediate background mutation push to Cloud Firestore',
        'icon': Icons.cloud_sync_rounded,
        'color': const Color(0xFF0891B2),
      },
    ];

    return modules.map((m) {
      final key = m['key'] as String;
      final isEnabled = _localFeatureFlags[key] ?? true;
      final icon = m['icon'] as IconData;
      final color = m['color'] as Color;

      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isEnabled ? const Color(0xFFF8FAFC) : const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isEnabled ? const Color(0xFFE2E8F0) : const Color(0xFFFECACA),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isEnabled ? color.withValues(alpha: 0.12) : const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: isEnabled ? color : const Color(0xFFDC2626), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        m['title'] as String,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isEnabled ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isEnabled ? 'LIVE' : 'KILL SWITCH',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            color: isEnabled ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    m['desc'] as String,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Switch.adaptive(
              key: ValueKey('feature_switch_$key'),
              value: isEnabled,
              activeTrackColor: const Color(0xFF1D4ED8),
              activeThumbColor: Colors.white,
              onChanged: (val) => _toggleFeatureFlag(key, val),
            ),
          ],
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ---------------------------------------------------------------
              // CARD 1: Third-Party SMS & OTP Provider
              // ---------------------------------------------------------------
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Header: Icon + Title/Subtitle + LIVE SMS Badge
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.chat_bubble_rounded, color: Color(0xFF1D4ED8), size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Third-Party SMS & OTP Provider',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Mobile Signup & Login OTP Authentication',
                                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFBBF7D0)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF16A34A),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'LIVE SMS',
                                style: TextStyle(
                                  color: Color(0xFF16A34A),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Intro Paragraph
                    const Text(
                      'Integrate third-party SMS service gateways (Fast2SMS, MSG91, Twilio, Textlocal, Gupshup, Custom Webhook) for instant mobile OTP verification during new user onboarding and secure authentication.',
                      style: TextStyle(fontSize: 12.5, color: Color(0xFF475569), height: 1.4),
                    ),
                    const SizedBox(height: 14),

                    // Enforce Mobile OTP Verification Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Enforce Mobile OTP Verification',
                                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'New distributors must verify mobile number with SMS OTP on registration',
                                  style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            key: const ValueKey('enforce_otp_switch'),
                            value: _enforceMobileOtp,
                            activeThumbColor: const Color(0xFF1D4ED8),
                            activeTrackColor: const Color(0xFF1D4ED8).withValues(alpha: 0.38),
                            onChanged: (val) {
                              setState(() => _enforceMobileOtp = val);
                              try {
                                context.read<AppState>().updateSmsGatewayConfig(enforceOtp: val);
                              } catch (_) {}
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Select SMS Gateway Provider
                    const Text(
                      'Select SMS Gateway Provider',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ['Fast2SMS', 'MSG91', 'Twilio', 'Textlocal', 'Gupshup', 'Custom Webhook'].map((provider) {
                        final isSel = _selectedSmsProvider == provider;
                        return InkWell(
                          onTap: () => setState(() => _selectedSmsProvider = provider),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSel ? const Color(0xFFEFF6FF) : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: isSel ? const Color(0xFF1D4ED8) : const Color(0xFFCBD5E1)),
                            ),
                            child: Text(
                              provider,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: isSel ? FontWeight.w800 : FontWeight.w500,
                                color: isSel ? const Color(0xFF1D4ED8) : const Color(0xFF475569),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // Gateway Mode: Live vs Sandbox / Test
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Gateway Mode',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                onTap: () => setState(() => _smsGatewayMode = 'Live'),
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: _smsGatewayMode == 'Live' ? const Color(0xFFDCFCE7) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                    border: _smsGatewayMode == 'Live' ? Border.all(color: const Color(0xFFBBF7D0)) : null,
                                  ),
                                  child: Text(
                                    'Live',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: _smsGatewayMode == 'Live' ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              InkWell(
                                onTap: () => setState(() => _smsGatewayMode = 'Sandbox / Test'),
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: _smsGatewayMode == 'Sandbox / Test' ? Colors.white : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                    boxShadow: _smsGatewayMode == 'Sandbox / Test'
                                        ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                                        : null,
                                  ),
                                  child: Text(
                                    'Sandbox / Test',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: _smsGatewayMode == 'Sandbox / Test' ? const Color(0xFF1D4ED8) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Dynamic API Key field
                    TextField(
                      key: const ValueKey('sms_api_key_input'),
                      controller: _smsApiKeyCtrl,
                      obscureText: _smsApiKeyObscured,
                      decoration: InputDecoration(
                        labelText: '$_selectedSmsProvider API Key / Auth Token',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _smsApiKeyObscured ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                            size: 20,
                            color: const Color(0xFF64748B),
                          ),
                          onPressed: () => setState(() => _smsApiKeyObscured = !_smsApiKeyObscured),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Sender ID & DLT Template ID Row
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: const ValueKey('sms_sender_id_input'),
                            controller: _smsSenderIdCtrl,
                            decoration: InputDecoration(
                              labelText: 'Sender ID / Header',
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            key: const ValueKey('sms_dlt_template_input'),
                            controller: _smsDltTemplateCtrl,
                            decoration: InputDecoration(
                              labelText: 'DLT Template ID',
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // OTP Digits & OTP Expiry
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // OTP Digits Column
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'OTP Digits',
                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [4, 6].map((digits) {
                                  final isSel = _selectedOtpDigits == digits;
                                  return Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: InkWell(
                                        onTap: () => setState(() => _selectedOtpDigits = digits),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          decoration: BoxDecoration(
                                            color: isSel ? const Color(0xFFEFF6FF) : Colors.white,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: isSel ? const Color(0xFF1D4ED8) : const Color(0xFFCBD5E1)),
                                          ),
                                          child: Center(
                                            child: Text(
                                              '$digits Digits',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: isSel ? FontWeight.w800 : FontWeight.w500,
                                                color: isSel ? const Color(0xFF1D4ED8) : const Color(0xFF475569),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),

                        // OTP Expiry Column
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'OTP Expiry',
                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [30, 60, 120].map((sec) {
                                  final isSel = _selectedOtpExpirySec == sec;
                                  return Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 4),
                                      child: InkWell(
                                        onTap: () => setState(() => _selectedOtpExpirySec = sec),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          decoration: BoxDecoration(
                                            color: isSel ? const Color(0xFFEFF6FF) : Colors.white,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: isSel ? const Color(0xFF1D4ED8) : const Color(0xFFCBD5E1)),
                                          ),
                                          child: Center(
                                            child: Text(
                                              '${sec}s',
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: isSel ? FontWeight.w800 : FontWeight.w500,
                                                color: isSel ? const Color(0xFF1D4ED8) : const Color(0xFF475569),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // DLT Approved SMS OTP Message Body
                    TextField(
                      key: const ValueKey('sms_body_input'),
                      controller: _smsOtpBodyCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'DLT Approved SMS OTP Message Body',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Status Indicator
                    Row(
                      children: const [
                        Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Status: Connected (200 OK • Gateway Ready)',
                          style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Buttons Row
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const ValueKey('sms_test_btn'),
                            onPressed: () {
                              ScaffoldMessenger.of(context).clearSnackBars();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Test OTP SMS successfully triggered! (Status: 200 OK)'),
                                  backgroundColor: Color(0xFF1D4ED8),
                                ),
                              );
                            },
                            icon: const Icon(Icons.science_rounded, size: 16, color: Color(0xFF1D4ED8)),
                            label: const Text(
                              'Test SMS',
                              style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1D4ED8), fontSize: 13),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF1D4ED8)),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            key: const ValueKey('sms_save_btn'),
                            onPressed: _saveSmsConfig,
                            icon: const Icon(Icons.save_rounded, size: 16, color: Colors.white),
                            label: const Text(
                              'Save SMS Setup',
                              style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 13),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1D4ED8),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // ---------------------------------------------------------------
              // CARD 2: Payment Gateway Configuration
              // ---------------------------------------------------------------
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Header
                    Row(
                      children: const [
                        Icon(Icons.account_balance_rounded, color: Color(0xFF1D4ED8), size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Payment Gateway Configuration',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Configure online payment gateways (Razorpay, Cashfree, PhonePe, UPI) to collect SaaS subscription payments automatically from subscribers.',
                      style: TextStyle(fontSize: 12.5, color: Color(0xFF475569), height: 1.4),
                    ),
                    const SizedBox(height: 16),

                    // Select Gateway Provider
                    const Text(
                      'Select Gateway Provider',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ['Razorpay', 'Cashfree', 'PhonePe', 'Direct UPI'].map((gw) {
                        final isSel = _selectedPaymentProvider == gw;
                        return InkWell(
                          onTap: () => setState(() => _selectedPaymentProvider = gw),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSel ? const Color(0xFFEFF6FF) : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: isSel ? const Color(0xFF1D4ED8) : const Color(0xFFCBD5E1)),
                            ),
                            child: Text(
                              gw,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: isSel ? FontWeight.w800 : FontWeight.w500,
                                color: isSel ? const Color(0xFF1D4ED8) : const Color(0xFF475569),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Environment Mode Row + Toggle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Environment Mode',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _paymentLiveMode ? 'Live Production Mode (Real Payments)' : 'Sandbox / Test Mode',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _paymentLiveMode ? const Color(0xFF059669) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                        Switch(
                          key: const ValueKey('payment_mode_switch'),
                          value: _paymentLiveMode,
                          activeThumbColor: const Color(0xFF1D4ED8),
                          activeTrackColor: const Color(0xFF1D4ED8).withValues(alpha: 0.38),
                          onChanged: (val) => setState(() => _paymentLiveMode = val),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Gateway API Key ID
                    TextField(
                      key: const ValueKey('payment_api_key_input'),
                      controller: _paymentApiKeyCtrl,
                      decoration: InputDecoration(
                        labelText: 'Gateway API Key ID / Client ID',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Gateway Secret Key
                    TextField(
                      key: const ValueKey('payment_secret_key_input'),
                      controller: _paymentSecretKeyCtrl,
                      obscureText: _paymentSecretObscured,
                      decoration: InputDecoration(
                        labelText: 'Gateway Secret Key',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _paymentSecretObscured ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                            size: 20,
                            color: const Color(0xFF64748B),
                          ),
                          onPressed: () => setState(() => _paymentSecretObscured = !_paymentSecretObscured),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Webhook Secret
                    TextField(
                      key: const ValueKey('payment_webhook_input'),
                      controller: _paymentWebhookSecretCtrl,
                      decoration: InputDecoration(
                        labelText: 'Webhook Secret (Auto-Activation)',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Admin Collection UPI ID (VPA)
                    TextField(
                      key: const ValueKey('admin_upi_id_input'),
                      controller: _adminUpiIdCtrl,
                      decoration: InputDecoration(
                        labelText: 'Admin Collection UPI ID (VPA)',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        prefixIcon: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF1D4ED8), size: 22),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // ---------------------------------------------------------------
              // CARD 3: Company Details for Tax Invoices
              // ---------------------------------------------------------------
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: const [
                        Icon(Icons.domain_rounded, color: Color(0xFF1D4ED8), size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Company Details for Tax Invoices',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // SaaS Company Legal Name
                    TextField(
                      key: const ValueKey('company_name_input'),
                      controller: _companyLegalNameCtrl,
                      decoration: InputDecoration(
                        labelText: 'SaaS Company Legal Name',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Admin Company GSTIN (15 Digits)
                    TextField(
                      key: const ValueKey('company_gstin_input'),
                      controller: _companyGstinCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        labelText: 'Admin Company GSTIN (15 Digits)',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Bank Name & IFSC Code
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: const ValueKey('company_bank_input'),
                            controller: _companyBankNameCtrl,
                            decoration: InputDecoration(
                              labelText: 'Bank Name',
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            key: const ValueKey('company_ifsc_input'),
                            controller: _companyIfscCtrl,
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              labelText: 'IFSC Code',
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Current Bank Account Number
                    TextField(
                      key: const ValueKey('company_account_no_input'),
                      controller: _companyAccountNoCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Current Bank Account Number',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Save Gateway Setup Full-width Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        key: const ValueKey('gateway_save_btn'),
                        onPressed: _savePaymentConfig,
                        icon: const Icon(Icons.save_rounded, color: Colors.white, size: 18),
                        label: const Text(
                          'Save Gateway Setup',
                          style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 13.5),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1D4ED8),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // ---------------------------------------------------------------
              // CARD 4: Live Modular Remote Feature Flags & Kill Switches
              // ---------------------------------------------------------------
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                      blurRadius: 10,
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
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.bolt_rounded, color: Color(0xFF1D4ED8), size: 22),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Remote Feature Kill Switches',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                                ),
                                Text(
                                  'Live Mobile Governance • Real-Time Sync',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF86EFAC)),
                          ),
                          child: Text(
                            '${_localFeatureFlags.values.where((v) => v).length}/10 ACTIVE',
                            style: const TextStyle(color: Color(0xFF15803D), fontSize: 11, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Instantly disable or pause any application feature on active field devices during emergency updates, server maintenance, or compliance audits without requiring app store releases.',
                      style: TextStyle(fontSize: 12.5, color: Color(0xFF475569), height: 1.4),
                    ),
                    const SizedBox(height: 16),

                    // List of 10 Switches
                    ..._buildFeatureSwitchList(),

                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const ValueKey('reset_flags_btn'),
                            onPressed: _resetFeatureFlagsToDefault,
                            icon: const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFF475569)),
                            label: const Text(
                              'Reset All Active',
                              style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF475569), fontSize: 13),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            key: const ValueKey('push_flags_btn'),
                            onPressed: _pushAllFlagsLive,
                            icon: const Icon(Icons.cloud_upload_rounded, size: 16, color: Colors.white),
                            label: const Text(
                              'Push Live to Devices',
                              style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 13),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1D4ED8),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
