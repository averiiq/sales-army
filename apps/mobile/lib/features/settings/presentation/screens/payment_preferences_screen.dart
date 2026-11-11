import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/core/services/printer_service.dart';
import 'package:salesarmy/core/utils/app_image_helper.dart';
import 'package:salesarmy/core/utils/feature_gate.dart';

class PaymentPreferencesScreen extends StatefulWidget {
  final int initialTab;
  const PaymentPreferencesScreen({super.key, this.initialTab = 0});

  @override
  State<PaymentPreferencesScreen> createState() => _PaymentPreferencesScreenState();
}

class _PaymentPreferencesScreenState extends State<PaymentPreferencesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Persistence keys
  static const String _prefKeyUpiId = 'salesarmy_pref_upi_id_v2';
  static const String _prefKeyMerchantName = 'salesarmy_pref_merchant_name_v2';
  static const String _prefKeyQrSource = 'salesarmy_pref_qr_source_v2';
  static const String _prefKeyStaticQr = 'salesarmy_pref_static_qr_image_v2';
  static const String _prefKeyGwConfig = 'salesarmy_pref_payment_gateway_config_v2';

  // Controllers for UPI
  late TextEditingController _vpaController;
  late TextEditingController _merchantNameController;
  String _qrSource = 'dynamic'; // 'dynamic' or 'static'
  String? _staticQrImagePath;

  // Controllers for Gateway
  late TextEditingController _apiKeyController;
  late TextEditingController _keySecretController;
  late TextEditingController _webhookSecretController;
  late TextEditingController _checkoutDisplayNameController;
  String _selectedProvider = 'Razorpay';
  bool _isLiveProduction = true;
  bool _showKeySecret = false;
  bool _autoVerifyInvoices = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTab.clamp(0, 1));

    final appState = Provider.of<AppState>(context, listen: false);
    final tenant = appState.tenant;
    final gw = tenant.paymentGatewayConfig ?? {};

    _vpaController = TextEditingController(text: tenant.upiId ?? (tenant.bankAccount?['upiId'] as String? ?? ''));
    _merchantNameController = TextEditingController(text: tenant.firmName ?? '');
    _qrSource = (gw['qrSource'] == 'static' || gw['qrSource'] == 'standee') ? 'static' : 'dynamic';
    _staticQrImagePath = gw['staticQrImage'] as String?;

    _apiKeyController = TextEditingController(text: gw['apiKey'] as String? ?? '');
    _keySecretController = TextEditingController(text: gw['keySecret'] as String? ?? '');
    _webhookSecretController = TextEditingController(text: gw['webhookSecret'] as String? ?? '');
    _checkoutDisplayNameController = TextEditingController(text: gw['displayName'] as String? ?? (tenant.firmName ?? ''));

    if (gw.containsKey('provider')) _selectedProvider = gw['provider'] as String;
    if (gw.containsKey('isLive')) _isLiveProduction = gw['isLive'] as bool;
    if (gw.containsKey('autoVerify')) _autoVerifyInvoices = gw['autoVerify'] as bool;

    _loadPersistentPreferences();
  }

  Future<void> _loadPersistentPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedVpa = prefs.getString(_prefKeyUpiId);
      final savedMerchant = prefs.getString(_prefKeyMerchantName);
      final savedQrSource = prefs.getString(_prefKeyQrSource);
      final savedStaticQr = prefs.getString(_prefKeyStaticQr);
      final savedGwConfigStr = prefs.getString(_prefKeyGwConfig);

      if (mounted) {
        setState(() {
          if (savedVpa != null && savedVpa.isNotEmpty && _vpaController.text.isEmpty) {
            _vpaController.text = savedVpa;
          }
          if (savedMerchant != null && savedMerchant.isNotEmpty && _merchantNameController.text.isEmpty) {
            _merchantNameController.text = savedMerchant;
          }
          if (savedQrSource != null && savedQrSource.isNotEmpty) {
            _qrSource = savedQrSource;
          }
          if (savedStaticQr != null && savedStaticQr.isNotEmpty && (_staticQrImagePath == null || _staticQrImagePath!.isEmpty)) {
            _staticQrImagePath = savedStaticQr;
          }
          if (savedGwConfigStr != null && savedGwConfigStr.isNotEmpty) {
            try {
              final gw = jsonDecode(savedGwConfigStr) as Map<String, dynamic>;
              if (gw['apiKey'] != null && _apiKeyController.text.isEmpty) _apiKeyController.text = gw['apiKey'].toString();
              if (gw['keySecret'] != null && _keySecretController.text.isEmpty) _keySecretController.text = gw['keySecret'].toString();
              if (gw['webhookSecret'] != null && _webhookSecretController.text.isEmpty) _webhookSecretController.text = gw['webhookSecret'].toString();
              if (gw['displayName'] != null && _checkoutDisplayNameController.text.isEmpty) _checkoutDisplayNameController.text = gw['displayName'].toString();
              if (gw['provider'] != null) _selectedProvider = gw['provider'].toString();
              if (gw['isLive'] is bool) _isLiveProduction = gw['isLive'] as bool;
              if (gw['autoVerify'] is bool) _autoVerifyInvoices = gw['autoVerify'] as bool;
            } catch (_) {}
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading persistent payment preferences: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _vpaController.dispose();
    _merchantNameController.dispose();
    _apiKeyController.dispose();
    _keySecretController.dispose();
    _webhookSecretController.dispose();
    _checkoutDisplayNameController.dispose();
    super.dispose();
  }

  String _buildUpiDeepLink() {
    final vpa = _vpaController.text.trim();
    final merchant = _merchantNameController.text.trim();
    if (vpa.isEmpty) return '';

    final buffer = StringBuffer('upi://pay?pa=$vpa');
    if (merchant.isNotEmpty) {
      buffer.write('&pn=${Uri.encodeComponent(merchant)}');
    }
    buffer.write('&cu=INR');
    return buffer.toString();
  }

  Future<void> _pickStaticQrImage() async {
    final path = await AppImageHelper.pickImage(fromCamera: false);
    if (path != null && path.isNotEmpty) {
      String durableImage = path;
      try {
        if (!kIsWeb) {
          final file = File(path);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            final ext = path.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
            durableImage = 'data:image/$ext;base64,${base64Encode(bytes)}';
          }
        }
      } catch (e) {
        debugPrint('Error converting picked QR to data URI: $e');
      }

      setState(() {
        _staticQrImagePath = durableImage;
      });
    }
  }

  Future<void> _saveAllSettings() async {
    HapticFeedback.mediumImpact();
    final appState = context.read<AppState>();
    final currentTenant = appState.tenant;
    final gw = Map<String, dynamic>.from(currentTenant.paymentGatewayConfig ?? {});

    final vpa = _vpaController.text.trim();
    final merchant = _merchantNameController.text.trim();

    gw['provider'] = _selectedProvider;
    gw['apiKey'] = _apiKeyController.text.trim();
    gw['keySecret'] = _keySecretController.text.trim();
    gw['webhookSecret'] = _webhookSecretController.text.trim();
    gw['displayName'] = _checkoutDisplayNameController.text.trim();
    gw['isLive'] = _isLiveProduction;
    gw['autoVerify'] = _autoVerifyInvoices;
    gw['qrSource'] = _qrSource;
    if (_staticQrImagePath != null && _staticQrImagePath!.isNotEmpty) {
      gw['staticQrImage'] = _staticQrImagePath;
    } else {
      gw.remove('staticQrImage');
    }

    final updated = currentTenant.copyWith(
      upiId: vpa,
      firmName: merchant.isNotEmpty ? merchant : currentTenant.firmName,
      paymentGatewayConfig: gw,
    );

    // 1. Direct Persistent Storage in SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyUpiId, vpa);
      await prefs.setString(_prefKeyMerchantName, merchant);
      await prefs.setString(_prefKeyQrSource, _qrSource);
      if (_staticQrImagePath != null && _staticQrImagePath!.isNotEmpty) {
        await prefs.setString(_prefKeyStaticQr, _staticQrImagePath!);
      } else {
        await prefs.remove(_prefKeyStaticQr);
      }
      await prefs.setString(_prefKeyGwConfig, jsonEncode(gw));
    } catch (e) {
      debugPrint('Error saving payment preferences to SharedPreferences: $e');
    }

    // 2. Update AppState and cloud sync
    await appState.updateTenant(updated);

    // 3. Sync printer settings
    PrinterService.instance.saveSettings(
      PrinterService.instance.settings.copyWith(
        upiVpa: vpa,
      ),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Payment preferences saved successfully!'),
            ],
          ),
          backgroundColor: Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isDark = appState.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment & Preferences',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            Text(
              'UPI QR & Payment Gateways',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _isLiveProduction
                  ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7))
                  : (isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7)),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isLiveProduction ? const Color(0xFF059669) : const Color(0xFFD97706),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: _isLiveProduction ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  _isLiveProduction ? 'LIVE GATEWAY' : 'SANDBOX MODE',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: _isLiveProduction ? const Color(0xFF059669) : const Color(0xFFB45309),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, size: 22, color: isDark ? Colors.white : const Color(0xFF0F172A)),
            onPressed: () => Navigator.pop(context),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            height: 44,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: const Color(0xFF1D4ED8),
                borderRadius: BorderRadius.circular(10),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              tabs: const [
                Tab(text: 'UPI QR'),
                Tab(text: 'Gateway'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUpiTab(isDark),
          _buildGatewayTab(isDark),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
        ),
        child: SafeArea(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1D4ED8),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.check_rounded, size: 20),
            label: const Text('Save Payment Preferences', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            onPressed: _saveAllSettings,
          ),
        ),
      ),
    );
  }

  // ==========================================
  // TAB 1: UPI & INSTANT PAYMENTS
  // ==========================================
  Widget _buildUpiTab(bool isDark) {
    final vpa = _vpaController.text.trim();
    final merchant = _merchantNameController.text.trim();
    final upiUri = _buildUpiDeepLink();
    final isStatic = _qrSource == 'static';
    final hasStaticImage = isStatic && _staticQrImagePath != null && _staticQrImagePath!.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Live UPI Card Preview (Tappable for full screen standee)
          InkWell(
            onTap: () => _showFullScreenQrStandee(context, isDark),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E3A8A).withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Center(
                      child: isStatic
                          ? (hasStaticImage
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: AppImageHelper.buildImage(
                                    _staticQrImagePath!,
                                    width: 92,
                                    height: 92,
                                    fit: BoxFit.contain,
                                  ),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.upload_file_rounded, size: 28, color: Color(0xFF64748B)),
                                    SizedBox(height: 4),
                                    Text('Upload QR', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                                  ],
                                ))
                          : (upiUri.isNotEmpty
                              ? QrImageView(
                                  data: upiUri,
                                  version: QrVersions.auto,
                                  size: 92.0,
                                  gapless: true,
                                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                                  backgroundColor: Colors.white,
                                  padding: const EdgeInsets.all(4),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.qr_code_2_rounded, size: 28, color: Color(0xFF64748B)),
                                    SizedBox(height: 4),
                                    Text('Enter UPI ID', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                                  ],
                                )),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF22C55E).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF22C55E)),
                              ),
                              child: Text(
                                isStatic ? 'STATIC QR' : 'DYNAMIC BILL QR',
                                style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: Color(0xFF4ADE80)),
                              ),
                            ),
                            const Spacer(),
                            const Icon(Icons.open_in_full_rounded, color: Colors.white70, size: 14),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          merchant.isNotEmpty ? merchant : 'Enter Legal Display Name',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: merchant.isNotEmpty ? Colors.white : Colors.white60,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          vpa.isNotEmpty ? vpa : 'No UPI ID configured',
                          style: TextStyle(
                            fontSize: 12,
                            color: vpa.isNotEmpty ? Colors.white70 : Colors.white54,
                            fontFamily: 'monospace',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isStatic
                              ? (hasStaticImage ? 'Static QR active' : 'Upload static QR image below')
                              : (vpa.isNotEmpty ? 'Dynamic UPI QR Ready' : 'UPI ID required for dynamic QR'),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF93C5FD)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // VPA & Merchant Configuration Card
          Container(
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
                    Text(
                      'UPI ID (VPA) & Merchant Details',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('INSTANT SETTLE', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: Color(0xFF10B981))),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: _vpaController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Merchant VPA / UPI ID *',
                    hintText: 'e.g. merchant@upi',
                    prefixIcon: const Icon(Icons.alternate_email_rounded, color: Color(0xFF1D4ED8)),
                    suffixIcon: vpa.contains('@')
                        ? const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 20)
                        : null,
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                  ),
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: _merchantNameController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Merchant Legal Display Name',
                    hintText: 'e.g. Agency / Firm Name',
                    prefixIcon: const Icon(Icons.storefront_outlined, color: Color(0xFF1D4ED8)),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // QR Code Invoicing Mode (2 options: Dynamic and Static)
          Material(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'QR Code Invoicing Mode',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 10),
                  // ignore: deprecated_member_use
                  RadioListTile<String>(
                    title: const Text('Dynamic', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    subtitle: const Text('Generates dynamic QR using your UPI ID. Embeds bill amount on invoices.', style: TextStyle(fontSize: 11.5)),
                    value: 'dynamic',
                    // ignore: deprecated_member_use
                    groupValue: _qrSource,
                    activeColor: const Color(0xFF1D4ED8),
                    contentPadding: EdgeInsets.zero,
                    // ignore: deprecated_member_use
                    onChanged: (v) async {
                      if (v != 'dynamic') { setState(() => _qrSource = v!); return; }
                      if (!await FeatureGate.requireFeature(context, 'dynamic_upi_qr')) return;
                      setState(() => _qrSource = v!);
                    },
                  ),
                  Divider(color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                  // ignore: deprecated_member_use
                  RadioListTile<String>(
                    title: const Text('Static', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    subtitle: const Text('Upload static counter standee QR code image.', style: TextStyle(fontSize: 11.5)),
                    value: 'static',
                    // ignore: deprecated_member_use
                    groupValue: _qrSource,
                    activeColor: const Color(0xFF1D4ED8),
                    contentPadding: EdgeInsets.zero,
                    // ignore: deprecated_member_use
                    onChanged: (v) => setState(() => _qrSource = v!),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Conditional Section: Dynamic QR vs Static QR
          if (_qrSource == 'dynamic') ...[
            if (vpa.isEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFF59E0B)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'UPI ID Required',
                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF92400E)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Please enter your Merchant UPI ID above to generate and use dynamic QR.',
                            style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFFB45309)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              _buildDynamicQrSection(isDark, upiUri),
            ],
          ] else ...[
            _buildStaticQrSection(isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildDynamicQrSection(bool isDark, String upiUri) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF1D4ED8).withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF1D4ED8), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Dynamic QR Generator',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
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
                  'REAL-TIME',
                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: Color(0xFF16A34A)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Clean Center QR Code
          Center(
            child: Container(
              width: 170,
              height: 170,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: QrImageView(
                  data: upiUri,
                  version: QrVersions.auto,
                  size: 154.0,
                  gapless: true,
                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.all(4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Live Payload Deep Link Display
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'UPI PAYLOAD STRING',
                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 0.6),
                    ),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: upiUri));
                        HapticFeedback.selectionClick();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('UPI payload copied to clipboard!'),
                            duration: Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      child: Row(
                        children: const [
                          Icon(Icons.copy_rounded, size: 12, color: Color(0xFF1D4ED8)),
                          SizedBox(width: 4),
                          Text('Copy URI', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF1D4ED8))),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  upiUri,
                  style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace', color: Color(0xFF2563EB)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Interactive Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D4ED8),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 1,
                  ),
                  icon: const Icon(Icons.fullscreen_rounded, size: 18),
                  label: const Text('Show Counter QR', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                  onPressed: () => _showFullScreenQrStandee(context, isDark),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: const BorderSide(color: Color(0xFF10B981)),
                  ),
                  icon: const Icon(Icons.verified_rounded, size: 18, color: Color(0xFF10B981)),
                  label: const Text('Simulate Scan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF10B981))),
                  onPressed: () => _showSimulatedPaymentDialog(context, isDark),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStaticQrSection(bool isDark) {
    final hasImage = _staticQrImagePath != null && _staticQrImagePath!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF1D4ED8).withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.qr_code_2_rounded, color: Color(0xFF1D4ED8), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Static QR Code',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              if (hasImage)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'UPLOADED',
                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: Color(0xFF16A34A)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          if (!hasImage) ...[
            // Initial upload box
            InkWell(
              onTap: _pickStaticQrImage,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF1D4ED8),
                    style: BorderStyle.solid,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1D4ED8).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.cloud_upload_rounded, color: Color(0xFF1D4ED8), size: 30),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Upload Static QR Code Image',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap to choose image from photo gallery',
                      style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            // Uploaded: Show QR when we press the static QR or have option to change the QR
            Center(
              child: InkWell(
                onTap: _pickStaticQrImage,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 190,
                  height: 190,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: AppImageHelper.buildImage(
                      _staticQrImagePath!,
                      width: 174,
                      height: 174,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: const BorderSide(color: Color(0xFF1D4ED8)),
                    ),
                    icon: const Icon(Icons.photo_library_rounded, size: 18, color: Color(0xFF1D4ED8)),
                    label: const Text('Change QR Code', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF1D4ED8))),
                    onPressed: _pickStaticQrImage,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Remove QR',
                  icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626)),
                  onPressed: () => setState(() => _staticQrImagePath = null),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: PAYMENT GATEWAY (RAZORPAY/CASHFREE)
  // ==========================================
  Widget _buildGatewayTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Provider Selection
          Container(
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
                    Text(
                      'Payment Gateway Provider',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('AUTO RECONCILE', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: Color(0xFF1D4ED8))),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: ['Razorpay', 'Cashfree', 'PayU', 'PhonePe PG'].map((p) {
                    final isSel = _selectedProvider == p;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedProvider = p);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isSel
                                  ? const Color(0xFF1D4ED8)
                                  : (isDark ? const Color(0xFF0F172A) : Colors.white),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSel ? const Color(0xFF1D4ED8) : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                width: isSel ? 1.5 : 1,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              p,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                                color: isSel ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF334155)),
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
          const SizedBox(height: 16),

          // Environment Switch Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _isLiveProduction ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isLiveProduction ? Icons.verified_user_rounded : Icons.science_rounded,
                    color: _isLiveProduction ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isLiveProduction ? 'Live Production Mode' : 'Sandbox / Test Mode',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      ),
                      Text(
                        _isLiveProduction ? 'Settles actual payments into registered current bank account' : 'Simulates transactions without debiting retailer accounts',
                        style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: _isLiveProduction,
                  activeTrackColor: const Color(0xFF16A34A),
                  onChanged: (val) => setState(() => _isLiveProduction = val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // API Credentials Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'API & Webhook Keys',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                ),
                const SizedBox(height: 12),

                // API Key ID
                TextField(
                  controller: _apiKeyController,
                  decoration: InputDecoration(
                    labelText: 'API Key ID *',
                    hintText: 'rzp_live_...',
                    prefixIcon: const Icon(Icons.key_rounded),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                  ),
                ),
                const SizedBox(height: 12),

                // Key Secret
                TextField(
                  controller: _keySecretController,
                  obscureText: !_showKeySecret,
                  decoration: InputDecoration(
                    labelText: 'Key Secret *',
                    hintText: '••••••••••••••••••••',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(_showKeySecret ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20),
                      onPressed: () => setState(() => _showKeySecret = !_showKeySecret),
                    ),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                  ),
                ),
                const SizedBox(height: 12),

                // Webhook Secret
                TextField(
                  controller: _webhookSecretController,
                  decoration: InputDecoration(
                    labelText: 'Webhook Secret',
                    hintText: 'whsec_...',
                    prefixIcon: const Icon(Icons.webhook_rounded),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                  ),
                ),
                const SizedBox(height: 12),

                // Brand Name on Checkout
                TextField(
                  controller: _checkoutDisplayNameController,
                  decoration: InputDecoration(
                    labelText: 'Brand Display Name on Checkout',
                    hintText: 'Shown on payment gateway screen',
                    prefixIcon: const Icon(Icons.badge_outlined),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Auto verify switch
          Material(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Auto-Mark Invoices Paid on Webhook', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                subtitle: const Text('Automatically updates invoice ledger upon successful gateway callback', style: TextStyle(fontSize: 11)),
                value: _autoVerifyInvoices,
                activeTrackColor: const Color(0xFF1D4ED8),
                onChanged: (val) => setState(() => _autoVerifyInvoices = val),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // ==========================================
  // FULL SCREEN COUNTER STANDEE MODAL
  // ==========================================
  void _showFullScreenQrStandee(BuildContext context, bool isDark) {
    final vpa = _vpaController.text.trim();
    final merchant = _merchantNameController.text.trim();
    final upiUri = _buildUpiDeepLink();
    final isStatic = _qrSource == 'static';
    final hasStaticImage = isStatic && _staticQrImagePath != null && _staticQrImagePath!.isNotEmpty;

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Standee Header Bar
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF1E3A8A), Color(0xFF1D4ED8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF1D4ED8), size: 20),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isStatic ? 'BHIM UPI STATIC STANDEE' : 'BHIM UPI DYNAMIC STANDEE',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
                                ),
                                const Text('UPI 2.0 • Zero Commission', style: TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Merchant Name & Verified Tag
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                merchant.isNotEmpty ? merchant : 'Merchant Store',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.verified_rounded, color: Color(0xFF2563EB), size: 18),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          vpa.isNotEmpty ? vpa : (isStatic ? 'Static Standee QR' : 'No UPI ID set'),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'monospace',
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // QR Frame
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: isStatic
                                ? (hasStaticImage
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: AppImageHelper.buildImage(
                                          _staticQrImagePath!,
                                          width: 210,
                                          height: 210,
                                          fit: BoxFit.contain,
                                        ),
                                      )
                                    : const SizedBox(
                                        width: 210,
                                        height: 210,
                                        child: Center(child: Text('No static QR image uploaded')),
                                      ))
                                : (upiUri.isNotEmpty
                                    ? QrImageView(
                                        data: upiUri,
                                        version: QrVersions.auto,
                                        size: 210.0,
                                        gapless: true,
                                        errorCorrectionLevel: QrErrorCorrectLevel.M,
                                        backgroundColor: Colors.white,
                                        padding: const EdgeInsets.all(8),
                                      )
                                    : const SizedBox(
                                        width: 210,
                                        height: 210,
                                        child: Center(child: Text('Enter UPI ID')),
                                      )),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Accepted UPI Apps
                        Text(
                          'ACCEPTED APPS',
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 1.1,
                            fontWeight: FontWeight.w900,
                            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          alignment: WrapAlignment.center,
                          children: [
                            _buildUpiAppBadge('Google Pay', const Color(0xFF4285F4)),
                            _buildUpiAppBadge('PhonePe', const Color(0xFF5F259F)),
                            _buildUpiAppBadge('Paytm', const Color(0xFF00BAF2)),
                            _buildUpiAppBadge('BHIM', const Color(0xFF00796B)),
                            _buildUpiAppBadge('Cred', const Color(0xFF1F2937)),
                            _buildUpiAppBadge('All UPI Apps', const Color(0xFF10B981)),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Action Buttons
                        Row(
                          children: [
                            if (upiUri.isNotEmpty) ...[
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  icon: const Icon(Icons.copy_rounded, size: 16),
                                  label: const Text('Copy UPI Link', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: upiUri));
                                    HapticFeedback.selectionClick();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('UPI payment link copied to clipboard!'),
                                        duration: Duration(seconds: 2),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                            ],
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1D4ED8),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: const Icon(Icons.check_rounded, size: 16),
                                label: const Text('Done', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                                onPressed: () => Navigator.pop(ctx),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // SIMULATE CUSTOMER SCAN & PAYMENT DIALOG
  // ==========================================
  void _showSimulatedPaymentDialog(BuildContext context, bool isDark) {
    HapticFeedback.heavyImpact();
    final merchant = _merchantNameController.text.trim();
    const displayAmount = '500.00';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 40),
              ),
              const SizedBox(height: 14),
              const Text(
                'UPI Payment Successful!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                'Simulated Instant Settlement to ${merchant.isNotEmpty ? merchant : "Merchant"}',
                style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('Amount Transferred', style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                        Text('₹$displayAmount', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF16A34A))),
                      ],
                    ),
                    const Divider(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('Payer UPI App', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        Text('Google Pay UPI', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('UPI Ref / UTR', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        Text('UTR${DateTime.now().millisecondsSinceEpoch.toString().substring(3)}', style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D4ED8),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('🔊 Soundbox Chime: "SalesArmy par ₹$displayAmount prapt hue!"'),
                        backgroundColor: const Color(0xFF0F172A),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: const Text('Dismiss & Confirm Order', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static Widget _buildUpiAppBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }
}

