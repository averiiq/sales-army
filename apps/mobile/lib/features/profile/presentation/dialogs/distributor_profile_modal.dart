import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/features/auth/data/services/auth_service.dart';

class DistributorProfileModal extends StatefulWidget {
  final VoidCallback onSignOut;
  const DistributorProfileModal({super.key, required this.onSignOut});

  @override
  State<DistributorProfileModal> createState() => _DistributorProfileModalState();
}

class _DistributorProfileModalState extends State<DistributorProfileModal> {
  int _selectedTab = 0; // 0: Agency Details, 1: SalesArmy Plans

  // Agency Details Controllers
  late TextEditingController _agentNameController;
  late TextEditingController _mobileController;
  late TextEditingController _whatsappController;
  late TextEditingController _emailController;
  late TextEditingController _firmNameController;
  late TextEditingController _classificationController;
  late TextEditingController _distributorIdController;
  late TextEditingController _brandsController;
  late TextEditingController _gstinController;
  late TextEditingController _panController;
  late TextEditingController _fssaiController;
  late TextEditingController _gstRateController;
  late TextEditingController _warehouseController;
  late TextEditingController _beatRouteController;
  late TextEditingController _bankNameController;
  late TextEditingController _accountNumberController;
  late TextEditingController _ifscController;

  // SalesArmy Plans Shipping Controllers
  late TextEditingController _recipientController;
  late TextEditingController _deliveryPhoneController;
  late TextEditingController _streetAddressController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _pinCodeController;
  late TextEditingController _landmarkController;
  bool _printerPurchased = false;
  bool _isGstBillingEnabled = true;

  String _formatAmount(num value) {
    if (value == 7188) return '7,188';
    if (value == 2499) return '2,499';
    final str = value.toInt().toString();
    if (str.length > 3) {
      return '${str.substring(0, str.length - 3)},${str.substring(str.length - 3)}';
    }
    return str;
  }

  @override
  void initState() {
    super.initState();
    final appState = context.read<AppState>();
    final tenant = appState.tenant;
    _isGstBillingEnabled = tenant.isGstBillingEnabled ?? appState.isGstBillingEnabled;

    _agentNameController = TextEditingController(text: tenant.representativeName ?? '');
    _mobileController = TextEditingController(text: tenant.mobile ?? '');
    _whatsappController = TextEditingController(text: tenant.whatsappNumber ?? '');
    _emailController = TextEditingController(text: tenant.email ?? '');
    _firmNameController = TextEditingController(text: tenant.firmName ?? '');
    _classificationController = TextEditingController(
      text: tenant.agencyClassification ?? '',
    );
    _distributorIdController = TextEditingController(
      text: tenant.distributorId.isNotEmpty ? tenant.distributorId : '',
    );
    _brandsController = TextEditingController(
      text: (tenant.authorizedBrandsPortfolio != null && tenant.authorizedBrandsPortfolio!.isNotEmpty)
          ? tenant.authorizedBrandsPortfolio!.join(', ')
          : '',
    );
    _gstinController = TextEditingController(text: tenant.gstin ?? '');
    _panController = TextEditingController(text: tenant.pan ?? '');
    _fssaiController = TextEditingController(text: tenant.fssaiLicenseNo ?? '');
    _gstRateController = TextEditingController(
      text: (tenant.defaultGstRate?.toInt() ?? 18).toString(),
    );
    _warehouseController = TextEditingController(
      text: tenant.warehouseAddress ?? '',
    );
    _beatRouteController = TextEditingController(
      text: tenant.beatRoute ?? '',
    );
    _bankNameController = TextEditingController(
      text: tenant.bankAccount?['bankName'] ?? '',
    );
    _accountNumberController = TextEditingController(
      text: tenant.bankAccount?['accountNumber'] ?? '',
    );
    _ifscController = TextEditingController(
      text: tenant.bankAccount?['ifsc'] ?? '',
    );

    // Shipping Address Defaults
    _recipientController = TextEditingController(text: 'Rahul Sharma');
    _deliveryPhoneController = TextEditingController(text: '+91 98765 43210');
    _streetAddressController = TextEditingController(text: 'Shop 14, APMC Market Yard');
    _cityController = TextEditingController(text: 'Pune');
    _stateController = TextEditingController(text: 'Maharashtra');
    _pinCodeController = TextEditingController(text: '411037');
    _landmarkController = TextEditingController(text: 'Near Main Gate');
  }

  @override
  void dispose() {
    _agentNameController.dispose();
    _mobileController.dispose();
    _whatsappController.dispose();
    _emailController.dispose();
    _firmNameController.dispose();
    _classificationController.dispose();
    _distributorIdController.dispose();
    _brandsController.dispose();
    _gstinController.dispose();
    _panController.dispose();
    _fssaiController.dispose();
    _gstRateController.dispose();
    _warehouseController.dispose();
    _beatRouteController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _ifscController.dispose();

    _recipientController.dispose();
    _deliveryPhoneController.dispose();
    _streetAddressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pinCodeController.dispose();
    _landmarkController.dispose();
    super.dispose();
  }

  void _showClassificationPicker() {
    const classifications = [
      'Super Stockist & Wholesale Agency',
      'Authorized C&F Agency',
      'Direct Distributor',
      'Sub-Stockist & Dealer',
      'FMCG Wholesale Merchant',
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Select Agency Classification',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(height: 1),
            ...classifications.map((c) => ListTile(
                  title: Text(c),
                  trailing: _classificationController.text == c
                      ? const Icon(Icons.check, color: Color(0xFF1D4ED8))
                      : null,
                  onTap: () {
                    setState(() => _classificationController.text = c);
                    Navigator.pop(ctx);
                  },
                )),
          ],
        ),
      ),
    );
  }

  void _saveAgencyDetails() {
    final appState = context.read<AppState>();
    final currentTenant = appState.tenant;

    final updatedTenant = currentTenant.copyWith(
      representativeName: _agentNameController.text.trim(),
      mobile: _mobileController.text.trim(),
      whatsappNumber: _whatsappController.text.trim(),
      email: _emailController.text.trim(),
      firmName: _firmNameController.text.trim(),
      agencyClassification: _classificationController.text.trim(),
      distributorId: _distributorIdController.text.trim(),
      authorizedBrandsPortfolio: _brandsController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
      gstin: _gstinController.text.trim(),
      pan: _panController.text.trim(),
      fssaiLicenseNo: _fssaiController.text.trim(),
      defaultGstRate: double.tryParse(_gstRateController.text.trim()) ?? 18.0,
      warehouseAddress: _warehouseController.text.trim(),
      beatRoute: _beatRouteController.text.trim(),
      bankAccount: (_bankNameController.text.trim().isNotEmpty || _accountNumberController.text.trim().isNotEmpty)
          ? {
              'bankName': _bankNameController.text.trim(),
              'accountNumber': _accountNumberController.text.trim(),
              'ifsc': _ifscController.text.trim().toUpperCase(),
              'accountHolderName': _firmNameController.text.trim().isNotEmpty
                  ? _firmNameController.text.trim()
                  : (_agentNameController.text.trim().isNotEmpty
                      ? _agentNameController.text.trim()
                      : (currentTenant.firmName ?? '')),
              if (currentTenant.effectiveUpiId.isNotEmpty) 'upiId': currentTenant.effectiveUpiId,
            }
          : currentTenant.bankAccount,
      isGstBillingEnabled: _isGstBillingEnabled,
    );

    appState.updateTenant(updatedTenant);
    appState.setGstBillingEnabled(_isGstBillingEnabled);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.check_circle_rounded, color: Colors.white),
            SizedBox(width: 8),
            Text('Agency details saved successfully!'),
          ],
        ),
        backgroundColor: const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
      ),
    );

    Navigator.pop(context);
  }

  void _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log Out of Account?'),
        content: const Text(
          'Are you sure you want to log out of this distributor profile on this device?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (shouldLogout == true && mounted) {
      Navigator.pop(context);
      await context.read<AuthService>().signOut();
      widget.onSignOut();
    }
  }

  void _showOrderPrinterDialog() {
    final appState = context.read<AppState>();
    final price = appState.printerHardwarePrice.toInt();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Order 58mm POS Printer'),
        content: Text(
          'Order 58mm Thermal Bluetooth POS Printer for ₹$price with delivery to your registered shipping address.\n\nCourier dispatched via BlueDart with live tracking.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1D4ED8),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _printerPurchased = true);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Printer order placed! Tracking details will be shared on WhatsApp.'),
                  backgroundColor: Color(0xFF059669),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: Text('Confirm Order (₹$price)', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showUpgradeDialog(String planName, String price) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Subscribe to $planName'),
        content: Text(
          'Confirm upgrading to $planName at $price.\n\nEnjoy unlimited shops, GST invoices, and priority telephone support.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1D4ED8),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              final appState = context.read<AppState>();
              final isAnnual = planName.toLowerCase().contains('annual');
              final updatedTenant = appState.tenant.copyWith(
                subscriptionPlanId: isAnnual ? 'annual_pro' : 'monthly_flex',
                subscriptionStatus: 'active',
                accountStatus: 'active',
              );
              appState.updateTenant(updatedTenant);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Subscribed to $planName successfully!'),
                  backgroundColor: const Color(0xFF059669),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Proceed to Pay', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showManagePlansSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.receipt_long_rounded, color: Color(0xFF1D4ED8)),
                title: const Text('View Subscription Invoices', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Download tax invoices for plan renewals'),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Invoices downloaded to device downloads.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.payment_rounded, color: Color(0xFF1D4ED8)),
                title: const Text('Manage Payment Methods', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('UPI AutoPay, Cards & NetBanking'),
                onTap: () => Navigator.pop(ctx),
              ),
              ListTile(
                leading: const Icon(Icons.help_outline_rounded, color: Color(0xFF1D4ED8)),
                title: const Text('Contact SalesArmy Support', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('WhatsApp & Phone billing support'),
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      backgroundColor: Colors.white,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 780),
        child: Column(
          children: [
            // Header
            _buildHeader(),

            // Segmented Sub-Tabs Bar
            _buildSubTabs(),

            const SizedBox(height: 12),

            // Tab Content
            Expanded(
              child: _selectedTab == 0 ? _buildAgencyDetailsTab() : _buildSalesArmyPlansTab(appState),
            ),

            // Sticky Bottom Action Bar
            _buildBottomActionBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 12),
      child: Row(
        children: [
          // Circular Avatar
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Color(0xFFEFF6FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person,
              color: Color(0xFF1D4ED8),
              size: 25,
            ),
          ),
          const SizedBox(width: 14),
          // Title & Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Distributor Profile',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Agency Details & SalesArmy Plans',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          // Log Out Icon
          IconButton(
            icon: const Icon(Icons.exit_to_app_rounded, color: Color(0xFFDC2626), size: 24),
            tooltip: 'Log Out',
            onPressed: _handleLogout,
          ),
          // Close Icon
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Color(0xFF0F172A), size: 24),
            tooltip: 'Close',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSubTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            // Tab 1: Agency Details
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _selectedTab = 0),
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(15)),
                child: Container(
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: _selectedTab == 0 ? const Color(0xFFEFF6FF) : Colors.white,
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(15)),
                    border: _selectedTab == 0
                        ? Border.all(color: const Color(0xFFDBEAFE), width: 1.2)
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.storefront_outlined,
                        size: 19,
                        color: _selectedTab == 0 ? const Color(0xFF1D4ED8) : const Color(0xFF475569),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Agency Details',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: _selectedTab == 0 ? FontWeight.w700 : FontWeight.w600,
                          color: _selectedTab == 0 ? const Color(0xFF1D4ED8) : const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Divider
            Container(width: 1, height: double.infinity, color: const Color(0xFFE2E8F0)),
            // Tab 2: SalesArmy Plans
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _selectedTab = 1),
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(15)),
                child: Container(
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: _selectedTab == 1 ? const Color(0xFFEFF6FF) : Colors.white,
                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(15)),
                    border: _selectedTab == 1
                        ? Border.all(color: const Color(0xFFDBEAFE), width: 1.2)
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.military_tech_outlined,
                        size: 19,
                        color: _selectedTab == 1 ? const Color(0xFF1D4ED8) : const Color(0xFF475569),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'SalesArmy Plans',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: _selectedTab == 1 ? FontWeight.w700 : FontWeight.w600,
                          color: _selectedTab == 1 ? const Color(0xFF1D4ED8) : const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgencyDetailsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        children: [
          // Card 1: Representative & Contact
          _buildRepresentativeCard(),
          const SizedBox(height: 16),

          // Card 2: Agency & Enterprise Profile
          _buildEnterpriseProfileCard(),
          const SizedBox(height: 16),

          // Card 3: Legal, GST & Regulatory Licenses
          _buildLegalGstCard(),
          const SizedBox(height: 16),

          // Card 4: Warehouse & Route Logistics
          _buildWarehouseLogisticsCard(),
          const SizedBox(height: 16),

          // Card 5: Agency Bank Settlement Account
          _buildBankSettlementCard(),
          const SizedBox(height: 16),

          // Card 6: Account & Active Session (Logout)
          _buildAccountSessionCard(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildRepresentativeCard() {
    return _buildSectionContainer(
      icon: Icons.badge_outlined,
      iconColor: const Color(0xFF1D4ED8),
      title: 'Representative & Contact',
      children: [
        _buildFormField(
          label: 'Distributor / Agent Name *',
          controller: _agentNameController,
          prefixIcon: const Icon(Icons.person, color: Color(0xFF334155), size: 22),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildFormField(
                label: 'Mobile Number *',
                controller: _mobileController,
                prefixIcon: const Icon(Icons.phone, color: Color(0xFF334155), size: 20),
                keyboardType: TextInputType.phone,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildFormField(
                label: 'WhatsApp Number',
                controller: _whatsappController,
                prefixIcon: const Icon(Icons.chat_bubble_rounded, color: Color(0xFF10B981), size: 20),
                keyboardType: TextInputType.phone,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildFormField(
          label: 'Email Address',
          controller: _emailController,
          prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF334155), size: 20),
          keyboardType: TextInputType.emailAddress,
        ),
      ],
    );
  }

  Widget _buildEnterpriseProfileCard() {
    return _buildSectionContainer(
      icon: Icons.apartment_rounded,
      iconColor: const Color(0xFF1D4ED8),
      title: 'Agency & Enterprise Profile',
      children: [
        _buildFormField(
          label: 'Agency / Firm Name *',
          controller: _firmNameController,
          prefixIcon: const Icon(Icons.storefront_rounded, color: Color(0xFF334155), size: 22),
        ),
        const SizedBox(height: 12),
        _buildFormField(
          label: 'Agency Classification',
          controller: _classificationController,
          prefixIcon: const Icon(Icons.interests_rounded, color: Color(0xFF334155), size: 22),
          suffixIcon: const Icon(Icons.arrow_drop_down, color: Color(0xFF334155), size: 24),
          readOnly: true,
          onTap: _showClassificationPicker,
        ),
        const SizedBox(height: 12),
        _buildFormField(
          label: 'Unique Distributor / Agency ID Code',
          controller: _distributorIdController,
          prefixIcon: const Icon(Icons.grid_view_rounded, color: Color(0xFF334155), size: 22),
        ),
        const SizedBox(height: 12),
        _buildFormField(
          label: 'Authorized FMCG Brands Portfolio',
          controller: _brandsController,
          prefixIcon: const Icon(Icons.archive_outlined, color: Color(0xFF334155), size: 22),
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildLegalGstCard() {
    return _buildSectionContainer(
      icon: Icons.verified_user_rounded,
      iconColor: const Color(0xFF059669),
      title: 'Legal, GST & Regulatory Licenses',
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildFormField(
                label: 'Agency GSTIN',
                controller: _gstinController,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildFormField(
                label: 'PAN Number',
                controller: _panController,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: _buildFormField(
                label: 'FSSAI License No.',
                controller: _fssaiController,
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: _buildFormField(
                label: 'Default GST %',
                controller: _gstRateController,
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Enable GST Bill Option',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isGstBillingEnabled
                          ? 'ON (Distributor can generate & view GST bills)'
                          : 'OFF (GST bill options hidden in distributor app)',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: _isGstBillingEnabled ? const Color(0xFF059669) : const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _isGstBillingEnabled,
                activeThumbColor: const Color(0xFF059669),
                onChanged: (val) {
                  setState(() => _isGstBillingEnabled = val);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWarehouseLogisticsCard() {
    return _buildSectionContainer(
      icon: Icons.location_on_rounded,
      iconColor: const Color(0xFF1D4ED8),
      title: 'Warehouse & Route Logistics',
      children: [
        _buildFormField(
          label: 'Agency Registered Godown / Warehouse Address',
          controller: _warehouseController,
          prefixIcon: const Icon(Icons.home_work_rounded, color: Color(0xFF334155), size: 22),
          maxLines: 3,
        ),
        const SizedBox(height: 12),
        _buildFormField(
          label: 'Assigned Territory & Beat Route',
          controller: _beatRouteController,
          prefixIcon: const Icon(Icons.alt_route_rounded, color: Color(0xFF334155), size: 22),
        ),
      ],
    );
  }

  Widget _buildBankSettlementCard() {
    return _buildSectionContainer(
      icon: Icons.account_balance_rounded,
      iconColor: const Color(0xFF1D4ED8),
      title: 'Agency Bank Settlement Account',
      children: [
        _buildFormField(
          label: 'Settlement Bank Name',
          controller: _bankNameController,
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildFormField(
                label: 'Account Number',
                controller: _accountNumberController,
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildFormField(
                label: 'IFSC Code',
                controller: _ifscController,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAccountSessionCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.exit_to_app_rounded, color: Color(0xFFDC2626), size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Account & Active Session',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Log out of this distributor profile on this device',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton(
              onPressed: _handleLogout,
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFFDC2626),
                side: const BorderSide(color: Color(0xFFDC2626), width: 1.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.exit_to_app_rounded, color: Color(0xFFDC2626), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Log Out of Account',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionContainer({
    required IconData icon,
    required Color iconColor,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    Widget? prefixIcon,
    Widget? suffixIcon,
    int maxLines = 1,
    TextInputType? keyboardType,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      readOnly: readOnly,
      onTap: onTap,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: Color(0xFF0F172A),
        height: 1.3,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: Color(0xFF64748B),
        ),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        filled: true,
        fillColor: Colors.white,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
        ),
      ),
    );
  }

  // --- SalesArmy Plans Tab (Screenshots 1 to 5) ---

  Widget _buildSalesArmyPlansTab(AppState appState) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Active SalesArmy Subscription Card (Screenshot 1)
          _buildActiveSubscriptionCard(appState),
          const SizedBox(height: 18),

          // Section Title
          const Text(
            'Available SalesArmy Plans',
            style: TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),

          // 2. Monthly Flexible Plan (Screenshot 1 & 2)
          _buildMonthlyFlexiblePlanCard(appState),
          const SizedBox(height: 16),

          // 3. Annual Plan (Screenshot 2 & 3)
          _buildAnnualPlanCard(appState),
          const SizedBox(height: 16),

          // 4. 58mm Thermal Bluetooth POS Printer (Screenshot 3)
          _buildPrinterHardwareCard(appState),
          const SizedBox(height: 16),

          // 5. Printer Delivery Shipping Address (Screenshot 4 & 5)
          _buildPrinterShippingCard(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildActiveSubscriptionCard(AppState appState) {
    final isAnnual = appState.tenant.subscriptionPlanId?.contains('annual') == true;
    final planName = isAnnual ? 'Annual Pro' : 'Monthly';
    final planRate = isAnnual
        ? '₹${appState.annualPlanPrice.toInt()}/mo (₹${appState.annualPlanYearlyTotal}/yr)'
        : '₹${appState.monthlyPlanPrice.toInt()}/mo';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Active SalesArmy Subscription',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF059669),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Plan: $planName ($planRate) • Txn:',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'RZP_TXN_999482',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF334155),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyFlexiblePlanCard(AppState appState) {
    final isAnnual = appState.tenant.subscriptionPlanId?.contains('annual') == true;
    final isMonthlyActive = !isAnnual;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMonthlyActive ? const Color(0xFF93C5FD) : const Color(0xFFCBD5E1),
          width: isMonthlyActive ? 1.5 : 1.0,
        ),
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
                  children: const [
                    Text(
                      'Monthly Flexible Plan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Pay as you go monthly',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${appState.monthlyPlanPrice.toInt()}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1D4ED8),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '/ month + ${appState.planGstRate.toInt()}% GST',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text('• Unlimited retail shops & product catalog', style: TextStyle(fontSize: 12.5, color: Color(0xFF334155), height: 1.5)),
          const SizedBox(height: 4),
          const Text('• WhatsApp PDF billing & dynamic UPI payments', style: TextStyle(fontSize: 12.5, color: Color(0xFF334155), height: 1.5)),
          const SizedBox(height: 4),
          const Text('• Full inventory batch tracking & daily reports', style: TextStyle(fontSize: 12.5, color: Color(0xFF334155), height: 1.5)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: isMonthlyActive
                ? ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Monthly Flexible Plan is your currently active subscription.'),
                          backgroundColor: Color(0xFF059669),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text(
                      'Active Plan',
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                    ),
                  )
                : ElevatedButton(
                    onPressed: () {
                      _showUpgradeDialog('Monthly Flexible Plan', '₹${appState.monthlyPlanPrice.toInt()} / mo');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1D4ED8),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      'Switch to Monthly (₹${appState.monthlyPlanPrice.toInt()}/mo)',
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnualPlanCard(AppState appState) {
    final isAnnualActive = appState.tenant.subscriptionPlanId?.contains('annual') == true;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAnnualActive ? const Color(0xFF059669) : const Color(0xFFCBD5E1),
          width: isAnnualActive ? 1.5 : 1.0,
        ),
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
                        const Text(
                          'Annual Plan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'SAVE 33%',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF92400E),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Billed annually at ₹${_formatAmount(appState.annualPlanYearlyTotal)} / yr',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${appState.annualPlanPrice.toInt()}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1D4ED8),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '/ mo (₹${_formatAmount(appState.annualPlanYearlyTotal)}/yr)',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text('• Priority WhatsApp & Phone Support', style: TextStyle(fontSize: 12.5, color: Color(0xFF334155), height: 1.5)),
          const SizedBox(height: 4),
          const Text('• Full SalesArmy features, e-Invoicing & GST reports', style: TextStyle(fontSize: 12.5, color: Color(0xFF334155), height: 1.5)),
          const SizedBox(height: 4),
          Text(
            '• Saves ₹${((appState.monthlyPlanPrice * 12) - appState.annualPlanYearlyTotal).toInt().clamp(0, 999999)} compared to monthly billing',
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155), height: 1.5),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: isAnnualActive
                ? ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Annual Pro Plan is your currently active subscription.'),
                          backgroundColor: Color(0xFF059669),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text(
                      'Active Plan',
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                    ),
                  )
                : ElevatedButton(
                    onPressed: () {
                      _showUpgradeDialog('Annual Plan', '₹${appState.annualPlanYearlyTotal} / yr');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1D4ED8),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      'Subscribe for ₹${appState.annualPlanPrice.toInt()} / mo (₹${_formatAmount(appState.annualPlanYearlyTotal)}/yr)',
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrinterHardwareCard(AppState appState) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.print_rounded, color: Color(0xFF1D4ED8), size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      '58mm Thermal Bluetooth POS Printer',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Wireless Bluetooth Billing Printer with battery',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '₹${_formatAmount(appState.printerHardwarePrice)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1D4ED8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _printerPurchased ? 'Status: Ordered' : 'Status: Not Purchased',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: _printerPurchased ? const Color(0xFF059669) : const Color(0xFF334155),
                ),
              ),
              OutlinedButton(
                onPressed: () {
                  _showOrderPrinterDialog();
                },
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1D4ED8),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                  _printerPurchased ? 'Track Order' : 'Order Printer',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPrinterShippingCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_shipping_rounded, color: Color(0xFF059669), size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Printer Delivery Shipping Address',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Used for thermal printer courier dispatch',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildFormField(
                  label: 'Recipient Name',
                  controller: _recipientController,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFormField(
                  label: 'Delivery Phone',
                  controller: _deliveryPhoneController,
                  keyboardType: TextInputType.phone,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildFormField(
            label: 'Shop No. / Building / Street Address',
            controller: _streetAddressController,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildFormField(
                  label: 'City / Town',
                  controller: _cityController,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFormField(
                  label: 'State',
                  controller: _stateController,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildFormField(
                  label: 'PIN Code',
                  controller: _pinCodeController,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFormField(
                  label: 'Nearby Landmark',
                  controller: _landmarkController,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.check_circle_rounded, color: Colors.white),
                        SizedBox(width: 8),
                        Text('Shipping details saved successfully!'),
                      ],
                    ),
                    backgroundColor: Color(0xFF059669),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.save_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Save Shipping Details',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF1F5F9), width: 1.5)),
      ),
      child: Row(
        children: [
          // Close button
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1D4ED8),
                  side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Action button: Save Agency Details (Tab 0) OR Manage SalesArmy Plans (Tab 1)
          Expanded(
            flex: 3,
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _selectedTab == 0 ? _saveAgencyDetails : _showManagePlansSheet,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D4ED8),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _selectedTab == 0 ? Icons.save_rounded : Icons.military_tech_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _selectedTab == 0 ? 'Save Agency Details' : 'Manage SalesArmy Plans',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
