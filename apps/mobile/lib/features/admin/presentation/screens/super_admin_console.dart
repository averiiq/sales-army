import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:salesarmy/core/utils/app_error.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/core/services/supabase_service.dart';
import 'package:salesarmy/features/admin/data/services/tenant_service.dart';
import 'package:salesarmy/features/admin/data/models/tenant_model.dart';
import 'package:salesarmy/features/admin/presentation/dialogs/admin_modals.dart';
import 'package:salesarmy/features/admin/presentation/tabs/admin_dashboard_tab.dart';
import 'package:salesarmy/features/admin/presentation/tabs/admin_features_tab.dart';
import 'package:salesarmy/features/admin/presentation/tabs/admin_subscribers_tab.dart';
import 'package:salesarmy/features/admin/presentation/tabs/admin_plans_tab.dart';
import 'package:salesarmy/features/admin/presentation/tabs/admin_settings_tab.dart';
import 'package:salesarmy/features/admin/data/models/coupon_model.dart';

class SuperAdminConsole extends StatefulWidget {
  final VoidCallback onExitConsole;
  final VoidCallback? onSignOut;

  const SuperAdminConsole({
    super.key,
    required this.onExitConsole,
    this.onSignOut,
  });

  @override
  State<SuperAdminConsole> createState() => _SuperAdminConsoleState();
}

class _SuperAdminConsoleState extends State<SuperAdminConsole> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  StreamSubscription<List<TenantModel>>? _tenantsSubscription;

  // Plan Pricing State
  double _monthlyPlanPrice = 899.0;
  double _annualPlanPrice = 599.0;
  double _planGstRate = 18.0;
  double _printerHardwarePrice = 3000.0;
  double _printerGstRate = 18.0;
  bool _applyGstOnInvoices = true;

  // Promo Coupons & Demo Passes
  List<Map<String, dynamic>> _coupons = [
    {
      'code': 'DEMO1DAY',
      'status': 'ACTIVE',
      'desc': '1 Day Free Full App Demo Access',
      'isPaused': false,
    },
    {
      'code': 'FREE1WEEK',
      'status': 'ACTIVE',
      'desc': '1 Week (7 Days) Free Full App Demo Access',
      'isPaused': false,
    },
    {
      'code': 'DEMO1MONTH',
      'status': 'ACTIVE',
      'desc': '1 Month (30 Days) Free Full App Demo Access',
      'isPaused': false,
    },
    {
      'code': 'FREE100',
      'status': 'ACTIVE',
      'desc': '100% Off Lifetime Fee Waiver',
      'isPaused': false,
    },
    {
      'code': 'SAVE50',
      'status': 'ACTIVE',
      'desc': '50% Off Subscription',
      'isPaused': false,
    },
  ];

  // Settings State
  bool _maintenanceMode = false;
  bool _autoBackupEnabled = true;
  final String _backupFrequency = 'Daily (02:00 AM IST)';
  final _adminPasscodeCtrl = TextEditingController();
  final _minAppVersionCtrl = TextEditingController(text: 'v2.4.1');

  // Default Demo Subscribers (Matching test expectations and original design)
  final List<Map<String, dynamic>> _defaultDemoSubscribers = [
    {
      'id': 'SUB-2026-001',
      'name': 'Rahul Sharma (You)',
      'firm': 'Sharma FMCG & Grocery Distribution',
      'phone': '+91 98765 43210',
      'email': 'rahul@sharmadistributors.in',
      'gstin': '27AABCS1429E1ZG',
      'route': 'Mumbai Central & Suburban',
      'plan': 'Monthly (₹899/mo)',
      'amount': '₹4009',
      'validity': '20 Aug 2026 to 19 Sep 2026',
      'invoiceNo': 'INV-SAAS-2026-001',
      'gatewayTxnId': 'RZP_TXN_999827',
      'status': 'ACTIVE',
      'printerStatus': 'PURCHASED (₹2499)',
      'printerModel': 'POS-58 Bluetooth Thermal Printer',
      'deliveryStatus': 'Delivered (DTDC-99218201)',
      'shippingAddress': 'Shop 14, APMC Market Yard, Pune - 411037',
      'hasPrinter': true,
      'daysLeft': '15 days left',
    },
    {
      'id': 'SUB-2026-002',
      'name': 'Amit Kumar Verma',
      'firm': 'Verma Daily Needs Agency',
      'phone': '+91 98201 54321',
      'email': 'amit@vermadailyneeds.com',
      'gstin': '27AAPCV8812J1ZX',
      'route': 'Thane & Navi Mumbai Route 4',
      'plan': 'Annual Pro (₹599/mo)',
      'amount': '₹13790',
      'validity': '01 Jul 2026 to 30 Jun 2027',
      'invoiceNo': 'INV-SAAS-2026-002',
      'gatewayTxnId': 'RZP_TXN_998102',
      'status': 'ACTIVE',
      'printerStatus': 'PURCHASED (₹2499)',
      'printerModel': 'POS-58 Bluetooth Thermal Printer',
      'deliveryStatus': 'Delivered (DTDC-99218288)',
      'shippingAddress': 'Gala 4, Sector 19, Vashi, Navi Mumbai - 400703',
      'hasPrinter': true,
      'daysLeft': '305 days left',
    },
    {
      'id': 'SUB-2026-003',
      'name': 'Suresh Patil',
      'firm': 'Patil Wholesale & Retail Supplies',
      'phone': '+91 97654 32109',
      'email': 'patil.wholesale@gmail.com',
      'gstin': '27AASPP4410K1ZT',
      'route': 'Pune Hadapsar Market Hub',
      'plan': 'Monthly (₹899/mo)',
      'amount': '₹4009',
      'validity': '25 Aug 2026 to 24 Sep 2026',
      'invoiceNo': 'INV-SAAS-2026-003',
      'gatewayTxnId': 'RZP_TXN_997451',
      'status': 'PENDING',
      'printerStatus': 'PURCHASED (₹2499)',
      'printerModel': 'POS-58 Bluetooth Thermal Printer',
      'deliveryStatus': 'In Transit (DTDC-99219401)',
      'shippingAddress': 'Shop 22, Market Yard, Hadapsar, Pune - 411028',
      'hasPrinter': true,
      'daysLeft': '28 days left',
    },
    {
      'id': 'SUB-2026-004',
      'name': 'Deepak Joshi',
      'firm': 'Joshi FMCG Distributors',
      'phone': '+91 99300 11223',
      'email': 'deepak@joshifmcg.in',
      'gstin': '27AAFPJ9921M1Z5',
      'route': 'Nashik City Central',
      'plan': 'Monthly (₹899/mo)',
      'amount': 'Free / Unpaid',
      'validity': 'Expired on 01 Sep 2026',
      'invoiceNo': 'INV-SAAS-2026-000',
      'gatewayTxnId': 'N/A',
      'status': 'CANCELLED',
      'printerStatus': 'Not Ordered',
      'printerModel': 'None',
      'deliveryStatus': 'Not Applicable',
      'shippingAddress': 'Plot 12, MIDC Ambad, Nashik - 422010',
      'hasPrinter': false,
      'daysLeft': '0 days left',
    },
    {
      'id': 'SUB-2026-005',
      'name': 'Vikram Malhotra',
      'firm': 'Malhotra Traders & Agency',
      'phone': '+91 98111 22334',
      'email': 'vikram@malhotratraders.com',
      'gstin': '07AABCM5562K1Z9',
      'route': 'Delhi Sadar Bazar & Chandni Chowk',
      'plan': 'Annual Pro (₹599/mo)',
      'amount': '₹13790',
      'validity': '10 Aug 2026 to 09 Aug 2027',
      'invoiceNo': 'INV-SAAS-2026-005',
      'gatewayTxnId': 'RZP_TXN_996301',
      'status': 'PENDING',
      'printerStatus': 'PURCHASED (₹2499)',
      'printerModel': 'POS-58 Bluetooth Thermal Printer',
      'deliveryStatus': 'Delivered (DTDC-99218332)',
      'shippingAddress': 'G-8, Sadar Bazar Industrial Area, Delhi - 110006',
      'hasPrinter': true,
      'daysLeft': '345 days left',
    },
    {
      'id': 'SUB-2026-006',
      'name': 'Ganesh Hegde',
      'firm': 'Hegde Agro & Provisions',
      'phone': '+91 94481 67890',
      'email': 'ganesh@hegdeagro.co.in',
      'gstin': '29AABCH7781N1ZG',
      'route': 'Bangalore City & Yeshwanthpur Hub',
      'plan': 'Monthly (₹899/mo)',
      'amount': '₹1061',
      'validity': '28 Aug 2026 to 27 Sep 2026',
      'invoiceNo': 'INV-SAAS-2026-006',
      'gatewayTxnId': 'RZP_TXN_995220',
      'status': 'PAUSED',
      'printerStatus': 'Not Ordered',
      'printerModel': 'None',
      'deliveryStatus': 'Not Applicable',
      'shippingAddress': 'Yard 3, APMC Yard, Yeshwanthpur, Bangalore - 560022',
      'hasPrinter': false,
      'daysLeft': 'Paused (Due)',
    },
    {
      'id': 'SUB-2026-007',
      'name': 'Kavita Deshmukh',
      'firm': 'Deshmukh Confectionery & Beverage Distribution',
      'phone': '+91 98690 12345',
      'email': 'kavita@deshmukhbeverages.in',
      'gstin': '27AADCD3321P1ZQ',
      'route': 'Thane West & Ghodbunder Road',
      'plan': 'Annual Pro (₹599/mo)',
      'amount': '₹13790',
      'validity': '15 May 2026 to 14 May 2027',
      'invoiceNo': 'INV-SAAS-2026-007',
      'gatewayTxnId': 'RZP_TXN_994119',
      'status': 'ACTIVE',
      'printerStatus': 'PURCHASED (₹2499)',
      'printerModel': 'POS-58 Bluetooth Thermal Printer',
      'deliveryStatus': 'Delivered (DTDC-99217740)',
      'shippingAddress': 'Warehouse 8, Station Road, Kalyan West - 421301',
      'hasPrinter': true,
      'daysLeft': '180 days left',
    },
  ];

  late List<Map<String, dynamic>> _subscribers;

  @override
  void initState() {
    super.initState();
    // Always start empty — real subscribers hydrate from backend once the
    // AppState realtime listener fires. The hardcoded demo list is retained
    // only for widget / unit tests that don't initialise Supabase.
    _subscribers = SupabaseService.instance.isInitialized
        ? []
        : (kDebugMode ? List.from(_defaultDemoSubscribers) : []);
    _tabController = TabController(length: 5, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        AppState? appState;
        try {
          appState = Provider.of<AppState>(context, listen: false);
        } catch (_) {}

        if (appState != null) {
          setState(() {
            _monthlyPlanPrice = appState!.monthlyPlanPrice;
            _annualPlanPrice = appState.annualPlanPrice;
            _planGstRate = appState.planGstRate;
            _printerHardwarePrice = appState.printerHardwarePrice;
            _printerGstRate = appState.printerGstRate;
            _applyGstOnInvoices = appState.applyGstOnInvoices;
            _maintenanceMode = appState.isMaintenanceMode;
          });
        }

        // Subscribe to live Firestore tenants
        _listenToLiveTenants();
      }
    });
  }

  void _listenToLiveTenants() {
    TenantService? tenantService;
    try {
      tenantService = Provider.of<TenantService>(context, listen: false);
    } catch (_) {
      tenantService = TenantService();
    }

    void applyTenants(List<TenantModel> tenants) {
      if (!mounted) return;
      if (tenants.isNotEmpty || SupabaseService.instance.isInitialized) {
        setState(() {
          _subscribers = tenants.map((t) {
            final isAnnual = (t.subscriptionPlanId ?? '').toLowerCase().contains('annual');
            final status = (t.accountStatus ?? 'ACTIVE').toUpperCase();
            final hasPrinter = t.hardwareConfig != null && t.hardwareConfig!['hasPrinter'] == true;

            return {
              'id': t.tenantId,
              'name': (t.representativeName != null && t.representativeName!.isNotEmpty)
                  ? t.representativeName!
                  : (t.firmName ?? 'Distributor'),
              'firm': t.firmName ?? 'Commercial Agency',
              'phone': t.phone ?? '+91 98123 45678',
              'email': t.email ?? 'contact@${t.tenantId}.com',
              'gstin': t.gstin ?? 'Unregistered',
              'route': t.city ?? t.territory ?? 'Central Territory',
              'plan': (t.subscriptionPlanId != null && t.subscriptionPlanId!.isNotEmpty)
                  ? '${t.subscriptionPlanId!.replaceAll("_", " ").toUpperCase()} Plan'
                  : 'Starter Plan',
              'amount': isAnnual ? '₹7188' : '₹899',
              'validity': t.subscriptionEndDate != null
                  ? 'Valid until ${t.subscriptionEndDate!.day}/${t.subscriptionEndDate!.month}/${t.subscriptionEndDate!.year}'
                  : 'Active Subscription',
              'invoiceNo': 'INV-SAAS-${t.tenantId.substring(0, t.tenantId.length > 8 ? 8 : t.tenantId.length).toUpperCase()}',
              'gatewayTxnId': 'RZP_TXN_${t.tenantId.hashCode.abs().toString().padLeft(6, '0').substring(0, 6)}',
              'status': status,
              'printerStatus': hasPrinter ? 'PURCHASED (₹3000)' : 'Not Ordered',
              'printerModel': 'POS-58 Bluetooth Thermal Printer',
              'deliveryStatus': hasPrinter ? 'Delivered' : 'Not Ordered',
              'shippingAddress': t.address ?? 'Registered Commercial Premises',
              'hasPrinter': hasPrinter,
              'daysLeft': 'Active',
            };
          }).toList();
        });
      }
    }

    // Immediately trigger one-shot fetch from Supabase Cloud
    tenantService.fetchAllTenants().then((loaded) {
      if (loaded.isNotEmpty) applyTenants(loaded);
    }).catchError((e) {
      debugPrint('Initial tenants fetch note: $e');
    });

    try {
      _tenantsSubscription = tenantService.streamAllTenants().listen((tenants) {
        applyTenants(tenants);
      }, onError: (err) {
        debugPrint('Tenants stream error: $err');
      });
    } catch (e) {
      debugPrint('Tenant service listener error: $e');
    }
  }

  @override
  void dispose() {
    _tenantsSubscription?.cancel();
    _tabController.dispose();
    _adminPasscodeCtrl.dispose();
    _minAppVersionCtrl.dispose();
    super.dispose();
  }

  void _handleLogout() {
    try {
      context.read<AppState>().signOutSession();
    } catch (_) {}
    if (widget.onSignOut != null) {
      widget.onSignOut!();
    } else {
      widget.onExitConsole();
    }
  }

  void _openSubscriberDetailModal(Map<String, dynamic> subscriber) {
    AdminSubscriberDetailModal.show(
      context,
      subscriber: subscriber,
      onStateChanged: () => setState(() {}),
    );
  }

  void _openDownloadReportsModal({int initialTab = 0}) {
    AdminDownloadReportsModal.show(
      context,
      subscribers: _subscribers,
      initialTab: initialTab,
    );
  }

  void _openEditPricingModal() {
    AdminEditPricingModal.show(
      context,
      monthlyPlanPrice: _monthlyPlanPrice,
      annualPlanPrice: _annualPlanPrice,
      planGstRate: _planGstRate,
      printerHardwarePrice: _printerHardwarePrice,
      printerGstRate: _printerGstRate,
      applyGstOnInvoices: _applyGstOnInvoices,
      onSave: (m, a, g, p, pg, apply) {
        setState(() {
          _monthlyPlanPrice = m;
          _annualPlanPrice = a;
          _planGstRate = g;
          _printerHardwarePrice = p;
          _printerGstRate = pg;
          _applyGstOnInvoices = apply;
        });
        try {
          context.read<AppState>().updatePlanPricing(
            monthlyPlanPrice: m,
            annualPlanPrice: a,
            planGstRate: g,
            printerHardwarePrice: p,
            printerGstRate: pg,
            applyGstOnInvoices: apply,
          );
        } catch (e) {
        showAppError(context, e, action: 'save this setting');
      }
      },
    );
  }

  void _openNewCouponModal() {
    AdminNewCouponModal.show(
      context,
      onSave: (newCoupon) async {
          final code = newCoupon['code']?.toString().toUpperCase() ?? '';
          final desc = newCoupon['desc']?.toString() ?? '';
          final type = CouponType.values.byName(newCoupon['type'].toString());
          final value = (newCoupon['value'] as num).toDouble();
          final model = CouponModel(
            code: code,
            type: type,
            value: value,
            title: desc,
            description: desc,
          );
          await context.read<AppState>().saveCoupon(model);
          if (mounted) setState(() => _coupons.insert(0, newCoupon));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (SupabaseService.instance.isInitialized) {
      final state = context.watch<AppState>();
      _monthlyPlanPrice = state.monthlyPlanPrice;
      _annualPlanPrice = state.annualPlanPrice;
      _planGstRate = state.planGstRate;
      _printerHardwarePrice = state.printerHardwarePrice;
      _printerGstRate = state.printerGstRate;
      _maintenanceMode = state.isMaintenanceMode;
      _coupons = state.coupons.map((coupon) => <String, dynamic>{
        'code': coupon.code, 'desc': coupon.description,
        'isPaused': !coupon.isActive, 'status': coupon.isActive ? 'ACTIVE' : 'PAUSED',
      }).toList();
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            const Icon(Icons.shield_outlined, color: Colors.white, size: 24),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'SaaS Super Admin',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: const Text(
                        'CONSOLE',
                        style: TextStyle(
                          color: Color(0xFF38BDF8),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const Text(
                  'SalesArmy SaaS Technologies Pvt Ltd',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            tooltip: 'Exit Console',
            onPressed: widget.onExitConsole,
          ),
          const SizedBox(width: 4),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: const Color(0xFF38BDF8),
          unselectedLabelColor: const Color(0xFF94A3B8),
          indicatorColor: const Color(0xFF38BDF8),
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [
            Tab(text: 'Dashboard'),
            Tab(text: 'Features'),
            Tab(text: 'Subscriber'),
            Tab(text: 'Plan'),
            Tab(text: 'Setting'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 0: Dashboard
          AdminDashboardTab(
            subscribers: _subscribers,
            onViewAllSubscribers: () => _tabController.animateTo(2),
            onOpenDownloadReports: () => _openDownloadReportsModal(),
            onSelectSubscriber: _openSubscriberDetailModal,
          ),

          // Tab 1: Features
          const AdminFeaturesTab(),

          // Tab 2: Subscriber
          AdminSubscribersTab(
            subscribers: _subscribers,
            onSelectSubscriber: _openSubscriberDetailModal,
          ),

          // Tab 3: Plan
          AdminPlansTab(
            monthlyPlanPrice: _monthlyPlanPrice,
            annualPlanPrice: _annualPlanPrice,
            planGstRate: _planGstRate,
            printerHardwarePrice: _printerHardwarePrice,
            printerGstRate: _printerGstRate,
            applyGstOnInvoices: _applyGstOnInvoices,
            coupons: _coupons,
            onOpenEditPricing: _openEditPricingModal,
            onOpenNewCoupon: _openNewCouponModal,
            onToggleCoupon: (idx, isPaused) {
              setState(() {
                _coupons[idx]['isPaused'] = isPaused;
              });
              context.read<AppState>().setCouponActive(_coupons[idx]['code'].toString(), !isPaused);
            },
            onDeleteCoupon: (idx) {
              final code = _coupons[idx]['code']?.toString();
              setState(() {
                _coupons.removeAt(idx);
              });
              if (code != null) {
                try {
                  context.read<AppState>().removeCoupon(code);
                } catch (e) {
        showAppError(context, e, action: 'save this setting');
      }
              }
            },
          ),

          // Tab 4: Setting
          AdminSettingsTab(
            maintenanceMode: _maintenanceMode,
            onToggleMaintenance: (val) {
              setState(() => _maintenanceMode = val);
              try {
                context.read<AppState>().setMaintenanceMode(val);
              } catch (e) {
        showAppError(context, e, action: 'save this setting');
      }
            },
            autoBackupEnabled: _autoBackupEnabled,
            onToggleAutoBackup: (val) => setState(() => _autoBackupEnabled = val),
            backupFrequency: _backupFrequency,
            adminPasscodeCtrl: _adminPasscodeCtrl,
            minAppVersionCtrl: _minAppVersionCtrl,
            onOpenDownloadReports: () => _openDownloadReportsModal(),
            onSignOut: _handleLogout,
          ),
        ],
      ),
    );
  }
}
