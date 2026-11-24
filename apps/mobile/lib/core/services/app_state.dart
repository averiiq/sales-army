import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:salesarmy/core/utils/app_error.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salesarmy/features/shops/data/models/shop_model.dart';
import 'package:salesarmy/features/inventory/data/models/product_model.dart';
import 'package:salesarmy/features/orders/data/models/order_model.dart';
import 'package:salesarmy/features/billing/data/models/invoice_model.dart';
import 'package:salesarmy/features/collections/data/models/payment_model.dart';
import 'package:salesarmy/features/collections/data/models/ledger_entry_model.dart';
import 'package:salesarmy/features/visits/data/models/visit_model.dart';
import 'package:salesarmy/features/visits/data/models/reminder_model.dart';
import 'package:salesarmy/features/admin/data/models/tenant_model.dart';
import 'package:salesarmy/features/billing/data/models/transaction_item_snapshot.dart';
import 'package:salesarmy/features/shops/domain/repositories/i_shop_repository.dart';
import 'package:salesarmy/features/orders/domain/repositories/i_order_repository.dart';
import 'package:salesarmy/features/inventory/domain/repositories/i_product_repository.dart';
import 'package:salesarmy/core/sync/repositories/i_sync_repository.dart';
import 'package:salesarmy/features/shops/domain/entities/shop_entity.dart';
import 'package:salesarmy/features/orders/domain/entities/order_entity.dart';
import 'package:salesarmy/features/inventory/domain/entities/product_entity.dart';
import 'package:salesarmy/features/shops/data/repositories/shop_repository_impl.dart';
import 'package:salesarmy/features/orders/data/repositories/order_repository_impl.dart';
import 'package:salesarmy/features/inventory/data/repositories/product_repository_impl.dart';
import 'package:salesarmy/core/sync/repositories/sync_repository_impl.dart';
import 'package:salesarmy/core/sync/outbox_manager.dart';
import 'package:salesarmy/core/services/mock_data.dart';
import 'package:salesarmy/features/admin/data/models/staff_model.dart';
import 'package:salesarmy/features/inventory/data/models/purchase_model.dart';
import 'package:salesarmy/features/collections/data/models/expense_model.dart';
import 'package:salesarmy/features/dashboard/data/models/notification_model.dart';
import 'package:salesarmy/features/orders/data/models/sales_return_model.dart';
import 'package:salesarmy/features/admin/data/models/subscription_plan_model.dart';
import 'package:salesarmy/features/admin/data/models/coupon_model.dart';
import 'package:salesarmy/features/admin/data/models/subscription_addon_model.dart';
import 'package:salesarmy/features/admin/data/models/printer_option_model.dart';
import 'package:salesarmy/features/billing/data/models/gst_slab_model.dart';
import 'package:salesarmy/core/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'package:salesarmy/core/services/notification_service.dart';
import 'package:salesarmy/core/services/platform_api.dart';

class InsufficientStockException implements Exception {
  final String message;
  InsufficientStockException([this.message = 'Insufficient stock for this operation']);

  @override
  String toString() => message;
}

class AppState extends ChangeNotifier {
  String? currentTenantId;
  String? currentUid;

  static const String _savedTenantPrefKey = 'salesarmy_saved_tenant_profile_v1';

  // Initial tenant is TRULY empty — no demo firmName/GSTIN/UPI/bank so new
  // signups land on a blank Profile, Business Details, and Payment
  // Preferences page. The demo tenant was leaking example data into every
  // fresh install and overriding the Supabase row the signup had just
  // created.
  TenantModel _tenant = TenantModel.empty();
  TenantModel get tenant => _tenant;
  set tenant(TenantModel val) {
    _tenant = val;
    _isGstBillingEnabled = val.isGstBillingEnabled ?? true;
    _persistTenantLocally(val);
    notifyListeners();
  }

  Future<void> _loadSavedTenant() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_savedTenantPrefKey);
      if (jsonStr != null && jsonStr.trim().isNotEmpty) {
        final decoded = json.decode(jsonStr);
        if (decoded is Map<String, dynamic>) {
          _tenant = TenantModel.fromMap(decoded, decoded['tenantId']?.toString() ?? _tenant.tenantId);
          _isGstBillingEnabled = _tenant.isGstBillingEnabled ?? true;
        }
      }

      // Restore standalone payment preferences if tenant model fields were empty or missing
      final savedVpa = prefs.getString('salesarmy_pref_upi_id_v2');
      final savedBankStr = prefs.getString('salesarmy_pref_bank_account_v2');
      final savedGwConfigStr = prefs.getString('salesarmy_pref_payment_gateway_config_v2');
      final savedStaticQr = prefs.getString('salesarmy_pref_static_qr_image_v2');
      final savedQrSource = prefs.getString('salesarmy_pref_qr_source_v2');

      Map<String, dynamic>? mergedGw = _tenant.paymentGatewayConfig != null
          ? Map<String, dynamic>.from(_tenant.paymentGatewayConfig!)
          : null;

      if (savedGwConfigStr != null && savedGwConfigStr.isNotEmpty) {
        try {
          final decodedGw = json.decode(savedGwConfigStr);
          if (decodedGw is Map<String, dynamic>) {
            mergedGw = (mergedGw ?? {})..addAll(decodedGw);
          }
        } catch (e) { debugPrint('Decode gateway config JSON: $e'); }
      }

      if (savedStaticQr != null && savedStaticQr.isNotEmpty) {
        mergedGw = (mergedGw ?? {})..['staticQrImage'] = savedStaticQr;
      }
      if (savedQrSource != null && savedQrSource.isNotEmpty) {
        mergedGw = (mergedGw ?? {})..['qrSource'] = savedQrSource;
      }

      Map<String, dynamic>? restoredBank;
      if (savedBankStr != null && savedBankStr.isNotEmpty) {
        try {
          final decoded = json.decode(savedBankStr);
          if (decoded is Map<String, dynamic>) {
            restoredBank = decoded;
          }
        } catch (e) { debugPrint('Decode bank config JSON: $e'); }
      }

      if ((savedVpa != null && savedVpa.isNotEmpty) || mergedGw != null || restoredBank != null) {
        _tenant = _tenant.copyWith(
          upiId: (savedVpa != null && savedVpa.isNotEmpty)
              ? savedVpa
              : (restoredBank?['upiId']?.toString().isNotEmpty == true ? restoredBank!['upiId'].toString() : _tenant.upiId),
          paymentGatewayConfig: mergedGw ?? _tenant.paymentGatewayConfig,
          bankAccount: restoredBank ?? _tenant.bankAccount,
        );
      }

      // Restore standalone profile image and logo if missing in tenant
      final savedProfileImg = prefs.getString('salesarmy_pref_profile_image_url_v2');
      final savedLogoImg = prefs.getString('salesarmy_pref_logo_url_v2');
      if ((savedProfileImg != null && savedProfileImg.isNotEmpty) || (savedLogoImg != null && savedLogoImg.isNotEmpty)) {
        _tenant = _tenant.copyWith(
          profileImageUrl: (savedProfileImg != null && savedProfileImg.isNotEmpty) ? savedProfileImg : _tenant.profileImageUrl,
          logoUrl: (savedLogoImg != null && savedLogoImg.isNotEmpty) ? savedLogoImg : _tenant.logoUrl,
        );
      }

      if (kDebugMode) {
        debugPrint('AppState: Loaded persisted tenant profile.');
      }
      _listenToTenant(_tenant.tenantId);
      notifyListeners();
    } catch (e) {
      debugPrint('AppState: Error loading saved tenant locally: $e');
    }
  }

  Future<void> _persistTenantLocally(TenantModel tenantToSave) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = json.encode(tenantToSave.toJsonMap());
      await prefs.setString(_savedTenantPrefKey, jsonStr);

      if (tenantToSave.profileImageUrl != null && tenantToSave.profileImageUrl!.trim().isNotEmpty) {
        await prefs.setString('salesarmy_pref_profile_image_url_v2', tenantToSave.profileImageUrl!.trim());
      }
      if (tenantToSave.logoUrl != null && tenantToSave.logoUrl!.trim().isNotEmpty) {
        await prefs.setString('salesarmy_pref_logo_url_v2', tenantToSave.logoUrl!.trim());
      }

      if (tenantToSave.upiId != null && tenantToSave.upiId!.trim().isNotEmpty) {
        await prefs.setString('salesarmy_pref_upi_id_v2', tenantToSave.upiId!.trim());
      }
      if (tenantToSave.bankAccount != null && tenantToSave.bankAccount!.isNotEmpty) {
        await prefs.setString('salesarmy_pref_bank_account_v2', json.encode(tenantToSave.bankAccount!));
      }
      if (tenantToSave.paymentGatewayConfig != null && tenantToSave.paymentGatewayConfig!.isNotEmpty) {
        await prefs.setString(
          'salesarmy_pref_payment_gateway_config_v2',
          json.encode(TenantModel.publicGatewayConfig(tenantToSave.paymentGatewayConfig)),
        );
        final staticQr = tenantToSave.paymentGatewayConfig!['staticQrImage']?.toString();
        if (staticQr != null && staticQr.trim().isNotEmpty) {
          await prefs.setString('salesarmy_pref_static_qr_image_v2', staticQr.trim());
        }
        final qrSrc = tenantToSave.paymentGatewayConfig!['qrSource']?.toString();
        if (qrSrc != null && qrSrc.trim().isNotEmpty) {
          await prefs.setString('salesarmy_pref_qr_source_v2', qrSrc.trim());
        }
        final merchName = tenantToSave.paymentGatewayConfig!['merchantName']?.toString();
        if (merchName != null && merchName.trim().isNotEmpty) {
          await prefs.setString('salesarmy_pref_merchant_name_v2', merchName.trim());
        }
      }
      debugPrint('⚡ AppState: Persisted tenant locally: ${tenantToSave.firmName} (${tenantToSave.representativeName})');
    } catch (e) {
      debugPrint('AppState: Error persisting tenant locally: $e');
    }
  }

  // Distributor Setting: Enable/Disable GST Billing
  bool _isGstBillingEnabled = true;
  bool get isGstBillingEnabled => _isGstBillingEnabled;

  // 1. Unique User ID Functionality
  String _uniqueUserId = 'SA-USR-8821';
  String get uniqueUserId => _uniqueUserId;
  void setUniqueUserId(String id) {
    if (id.trim().isNotEmpty) {
      _uniqueUserId = id.trim();
      notifyListeners();
    }
  }

  // 2. Plans & entitlements: there is NO free plan. Every agency is on a real
  //    plan (trial or paid). When it ends (+ trial grace days) the app is
  //    read-only — see isReadOnlyMode / writeBlockReason below.

  // ---------------------------------------------------------------------------
  // Razorpay checkout bookkeeping (server = Supabase Edge Function "platform")
  // ---------------------------------------------------------------------------

  static String pendingCheckoutKey(String tenantId) => 'pending_checkout_$tenantId';

  /// Remembers the open Razorpay checkout so a payment made while the app was
  /// closed (or before tapping "Verify") still activates the plan later.
  Future<void> savePendingCheckout({required String id, required String planId}) async {
    final tid = currentTenantId ?? _tenant.tenantId;
    if (tid.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(pendingCheckoutKey(tid), jsonEncode({
      'id': id,
      'planId': planId,
      'savedAt': DateTime.now().toIso8601String(),
    }));
  }

  Future<Map<String, String>?> readPendingCheckout() async {
    final tid = currentTenantId ?? _tenant.tenantId;
    if (tid.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(pendingCheckoutKey(tid));
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final id = map['id']?.toString() ?? '';
      if (id.isEmpty) return null;
      return {'id': id, 'planId': map['planId']?.toString() ?? ''};
    } catch (_) {
      // Older builds stored only the checkout id.
      return {'id': raw, 'planId': ''};
    }
  }

  Future<void> clearPendingCheckout() async {
    final tid = currentTenantId ?? _tenant.tenantId;
    if (tid.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(pendingCheckoutKey(tid));
  }

  /// Applies a SERVER-confirmed activation on this phone right away (so bills
  /// unlock even if the follow-up cloud sync is slow), then re-syncs.
  Future<void> applyServerPlanActivation({
    required String planId,
    required DateTime expiresAt,
    String status = 'active',
  }) async {
    final plan = planById(planId);
    if (planId.isNotEmpty) {
      _tenant = _tenant.copyWith(
        subscriptionPlanId: plan?.id ?? planId,
        subscriptionStatus: status,
        subscriptionEndDate: expiresAt,
        accountStatus: 'active',
        maxUsers: plan?.maxStaff,
        maxShops: plan?.maxShops,
      );
      await _persistTenantLocally(_tenant);
      notifyListeners();
    }
    try {
      await syncAllFromCloud();
    } catch (e) {
      debugPrint('Post-activation sync failed (will retry on next sync): $e');
    }
  }

  bool _reconcilingCheckout = false;

  /// Checks a saved checkout with the server. Returns the server result when
  /// it was PAID (plan already activated server-side), otherwise null.
  /// Expired / cancelled / unknown checkouts are forgotten.
  Future<Map<String, dynamic>?> reconcilePendingCheckout() async {
    if (_reconcilingCheckout || !PlatformApi.isConfigured) return null;
    final pending = await readPendingCheckout();
    if (pending == null) return null;
    _reconcilingCheckout = true;
    try {
      final result = await PlatformApi.request(
        '/api/checkout?id=${Uri.encodeQueryComponent(pending['id']!)}',
      );
      final status = result['status']?.toString();
      if (status == 'paid') {
        await clearPendingCheckout();
        final expires = DateTime.tryParse(result['expiresAt']?.toString() ?? '');
        if (expires != null) {
          await applyServerPlanActivation(planId: pending['planId'] ?? '', expiresAt: expires);
        } else {
          await syncAllFromCloud();
        }
        return result;
      }
      if (status == 'expired' || status == 'cancelled') await clearPendingCheckout();
      return null;
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('checkout not found') || msg.contains('invalid checkout id')) {
        await clearPendingCheckout();
      }
      debugPrint('Pending checkout check failed: $e');
      return null;
    } finally {
      _reconcilingCheckout = false;
    }
  }

  /// TESTING ONLY: activates [planId] for this agency without payment through
  /// the server RPC `activate_plan_for_testing` (allowed only while the super
  /// admin has "Allow test plan activation" ON). The plan is changed in the
  /// database — never just on this phone — then applied here. Returns the new
  /// end date; throws a readable [StateError] on failure.
  Future<DateTime> activatePlanForTesting(String planId, {bool yearly = false}) async {
    final supa = SupabaseService.instance;
    if (!await supa.ensureInitialized() || supa.client == null) {
      throw StateError(SupabaseService.unreachableMessage);
    }
    final dynamic result;
    try {
      result = await supa.client!.rpc('activate_plan_for_testing', params: {
        'p_plan': planId,
        'p_yearly': yearly,
      });
    } on PostgrestException catch (e) {
      final msg = e.message;
      if (e.code == 'PGRST202' || msg.contains('activate_plan_for_testing')) {
        throw StateError('Plan activation is not set up on the server yet (database update pending). Please contact SalesArmy.');
      }
      throw StateError(msg.replaceFirst(RegExp(r'^[A-Z_]+:\s*'), ''));
    }
    final map = result is Map ? Map<String, dynamic>.from(result) : <String, dynamic>{};
    final expires = DateTime.tryParse(map['expiresAt']?.toString() ?? '') ??
        DateTime.now().add(Duration(days: yearly ? 365 : 30));
    final plan = planById(planId);
    _tenant = _tenant.copyWith(
      subscriptionPlanId: plan?.id ?? planId,
      subscriptionStatus: 'active',
      subscriptionEndDate: expires,
      accountStatus: 'active',
      maxUsers: plan?.maxStaff,
      maxShops: plan?.maxShops,
    );
    await _persistTenantLocally(_tenant);
    notifyListeners();
    return expires;
  }

  /// Applies a plan locally. Plan changes are server-managed (checkout or the
  /// super admin); the database rejects plan writes from agency users, so
  /// only a super admin session writes them through.
  Future<void> setSubscriptionPlan({
    required String planId,
    String status = 'active',
    DateTime? endDate,
  }) async {
    final plan = planById(planId);
    final effectiveEndDate = endDate ??
        (status == 'trial'
            ? DateTime.now().add(Duration(days: _signupTrialDays))
            : DateTime.now().add(const Duration(days: 365)));

    _tenant = _tenant.copyWith(
      subscriptionPlanId: plan?.id ?? planId,
      subscriptionStatus: status,
      subscriptionEndDate: effectiveEndDate,
      maxUsers: plan?.maxStaff,
      maxShops: plan?.maxShops,
    );
    await _persistTenantLocally(_tenant);
    notifyListeners();

    final tid = currentTenantId ?? _tenant.tenantId;
    if (tid.isEmpty || !(isSuperAdminUser || isSuperAdminMode)) return;
    try {
      final supa = SupabaseService.instance;
      if (supa.client != null) {
        await supa.client!.from('tenants').update({
          'plan_id': plan?.id ?? planId,
          'subscription_status': status,
          'subscription_end_date': effectiveEndDate.toIso8601String(),
          if (plan != null) 'max_users': plan.maxStaff,
          if (plan != null) 'max_shops': plan.maxShops,
          'is_active': status != 'suspended',
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('tenant_id', tid);
      }
    } catch (e) {
      debugPrint('Supabase subscription update notice: $e');
    }
    await syncTenantToServerBridge();
  }

  // RBAC Role Helper Getters
  bool get isOwnerRole => activeRole.toLowerCase() == 'owner' || isSuperAdminUser || isSuperAdminMode;
  bool get isAccountantRole => activeRole.toLowerCase().contains('account');
  bool get isFieldSalesRole => activeRole.toLowerCase().contains('sales') || activeRole.toLowerCase().contains('salesman');
  bool get isDeliveryRole => activeRole.toLowerCase().contains('deliver');
  bool get isStoreManagerRole => activeRole.toLowerCase().contains('store') || activeRole.toLowerCase().contains('warehouse');

  /// Legacy / alternate names used around the app for capability keys.
  static const Map<String, String> _featureAliases = {
    'gst_invoicing': 'invoicing',
    'gst_invoice': 'invoicing',
    'tax_invoice': 'invoicing',
    'rough_bills': 'estimate_bills',
    'estimated_bill': 'estimate_bills',
    'kaccha_bill': 'estimate_bills',
    'orders': 'order_taking',
    'sell': 'order_taking',
    'thermal_printing': 'thermal_printer',
    'printer': 'thermal_printer',
    'offline_outbox': 'offline_sync',
    'cloud_sync': 'offline_sync',
    'instant_sync': 'offline_sync',
    'gps_tracking': 'live_tracking',
    'multi_van_fleet': 'multi_van',
    'fleet_multi_van': 'multi_van',
    'dedicated_account_manager': 'dedicated_manager',
    'staff': 'staff_management',
    'purchase': 'purchases',
    'expense': 'expenses',
    'reminders': 'visits',
    'returns': 'sales_returns',
    'khataLedger': 'khata_ledger',
  };

  static String canonicalFeature(String key) => _featureAliases[key] ?? _featureAliases[key.toLowerCase()] ?? key.toLowerCase();

  /// Back-compat name for [hasFeature].
  bool canAccessFeatureBySubscription(String featureKey) => hasFeature(featureKey);

  String getFeaturePlanBadge(String featureKey) {
    if (isReadOnlyMode) return 'RENEW';
    if (!planIncludes(featureKey)) return 'UPGRADE';
    return currentPlan.name.toUpperCase();
  }

  // 2.5 Remote App Governance & Feature Kill Switches (Super Admin Web Control)
  Map<String, bool> _remoteFeatureFlags = {
    'order_taking': true,
    'gst_invoicing': true,
    'collections': true,
    'gps_tracking': true,
    'thermal_printer': true,
    'soundbox_audio': true,
    'staff_management': true,
    'van_stock': true,
    'customer_portal': true,
    'instant_sync': true,
  };
  Map<String, bool> get remoteFeatureFlags => Map.unmodifiable(_remoteFeatureFlags);
  bool isFeatureEnabledRemotely(String key) => _remoteFeatureFlags[key] ?? true;

  void updateRemoteFeatureFlags(Map<String, bool> flags) {
    _remoteFeatureFlags = Map.from(_remoteFeatureFlags)..addAll(flags);
    notifyListeners();
  }

  // Remote Emergency Broadcast Banner (Managed by Super Admin Web Panel)
  Map<String, dynamic>? _emergencyBroadcast;
  Map<String, dynamic>? get emergencyBroadcast => _emergencyBroadcast;
  bool _isAnnouncementDismissed = false;
  bool get isAnnouncementDismissed => _isAnnouncementDismissed;

  void setEmergencyBroadcast(Map<String, dynamic>? broadcast) {
    _emergencyBroadcast = broadcast;
    _isAnnouncementDismissed = false;
    notifyListeners();
  }

  void dismissAnnouncement() {
    _isAnnouncementDismissed = true;
    notifyListeners();
  }

  String _maintenanceMessage = 'SalesArmy is currently undergoing scheduled platform maintenance. Cloud sync is active.';
  String? _maintenanceEta = '30 minutes';
  String get maintenanceMessage => _maintenanceMessage;
  String? get maintenanceEta => _maintenanceEta;

  void setMaintenanceDetails({
    required bool isMaintenance,
    String? message,
    String? eta,
  }) {
    _maintenanceMode = isMaintenance;
    if (message != null && message.trim().isNotEmpty) _maintenanceMessage = message.trim();
    if (eta != null && eta.trim().isNotEmpty) _maintenanceEta = eta.trim();
    notifyListeners();
  }

  // 3. Product categories & packaging units — per account, nothing predefined.
  //    Saved on the phone (per tenant) and in the cloud (platform_settings row
  //    tenant_catalog_<tenantId>). Categories / units already used by the
  //    account's products are always included so old data keeps showing.
  final List<String> _productCategories = [];
  final List<String> _productUnits = [];

  static List<String> _mergeUnique(Iterable<String> a, Iterable<String> b) {
    final seen = <String>{};
    final out = <String>[];
    for (final v in [...a, ...b]) {
      final t = v.trim();
      if (t.isEmpty || t == 'All' || t == 'Custom') continue;
      if (seen.add(t.toLowerCase())) out.add(t);
    }
    return out;
  }

  /// Categories for this account (saved + used by products). Never contains 'All'.
  List<String> get productCategories => List.unmodifiable(
        _mergeUnique(_productCategories, _products.map((p) => p.categoryId ?? '')),
      );

  /// Packaging units for this account (saved + used by product variants).
  List<String> get productUnits => List.unmodifiable(
        _mergeUnique(_productUnits, _products.expand((p) => (p.variants ?? const []).map((v) => v.unit))),
      );

  String get _catalogPrefKey => 'salesarmy_catalog_lists_${currentTenantId ?? _tenant.tenantId}';

  void addProductCategory(String category) {
    final trimmed = category.trim();
    if (trimmed.isEmpty || trimmed == 'All') return;
    if (_productCategories.any((c) => c.toLowerCase() == trimmed.toLowerCase())) return;
    _productCategories.add(trimmed);
    notifyListeners();
    _persistCatalogLists();
  }

  /// How many products use [category] / [unit]. Entries in use cannot be
  /// deleted (they would re-appear from the products and leave them orphaned).
  int productCountForCategory(String category) {
    final key = category.trim().toLowerCase();
    return _products.where((p) => (p.categoryId ?? '').trim().toLowerCase() == key).length;
  }

  int productCountForUnit(String unit) {
    final key = unit.trim().toLowerCase();
    return _products
        .where((p) => (p.variants ?? const []).any((v) => v.unit.trim().toLowerCase() == key))
        .length;
  }

  void removeProductCategory(String category) {
    _productCategories.removeWhere((c) => c.toLowerCase() == category.trim().toLowerCase());
    notifyListeners();
    _persistCatalogLists();
  }

  void addProductUnit(String unit) {
    final trimmed = unit.trim();
    if (trimmed.isEmpty || trimmed == 'Custom') return;
    if (_productUnits.any((u) => u.toLowerCase() == trimmed.toLowerCase())) return;
    _productUnits.add(trimmed);
    notifyListeners();
    _persistCatalogLists();
  }

  void removeProductUnit(String unit) {
    _productUnits.removeWhere((u) => u.toLowerCase() == unit.trim().toLowerCase());
    notifyListeners();
    _persistCatalogLists();
  }

  Future<void> _persistCatalogLists() async {
    final data = {'categories': _productCategories, 'units': _productUnits, 'updatedAt': DateTime.now().toIso8601String()};
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_catalogPrefKey, jsonEncode(data));
    } catch (e) {
      debugPrint('Persist catalog lists: $e');
    }
    final tid = currentTenantId ?? _tenant.tenantId;
    if (tid.isNotEmpty && SupabaseService.instance.client != null) {
      try {
        await SupabaseService.instance.savePlatformSettings('tenant_catalog_$tid', data);
      } catch (e) {
        debugPrint('Cloud catalog lists sync: $e');
      }
    }
  }

  /// Loads this account's categories / units (phone first, then cloud).
  Future<void> _loadCatalogLists() async {
    void apply(Map data) {
      final cats = (data['categories'] as List?)?.map((e) => e.toString()) ?? const <String>[];
      final units = (data['units'] as List?)?.map((e) => e.toString()) ?? const <String>[];
      _productCategories
        ..clear()
        ..addAll(_mergeUnique(cats, const []));
      _productUnits
        ..clear()
        ..addAll(_mergeUnique(units, const []));
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_catalogPrefKey);
      if (raw != null && raw.isNotEmpty) apply(jsonDecode(raw) as Map);
      notifyListeners();
    } catch (e) {
      debugPrint('Load catalog lists: $e');
    }
    final tid = currentTenantId ?? _tenant.tenantId;
    if (tid.isEmpty || SupabaseService.instance.client == null) return;
    try {
      final cloud = await SupabaseService.instance.fetchPlatformSettings('tenant_catalog_$tid');
      if (cloud != null) {
        // Union with anything added offline on this phone, then re-save.
        final localCats = List<String>.from(_productCategories);
        final localUnits = List<String>.from(_productUnits);
        apply(cloud);
        final mergedCats = _mergeUnique(_productCategories, localCats);
        final mergedUnits = _mergeUnique(_productUnits, localUnits);
        final changed = mergedCats.length != _productCategories.length || mergedUnits.length != _productUnits.length;
        _productCategories
          ..clear()
          ..addAll(mergedCats);
        _productUnits
          ..clear()
          ..addAll(mergedUnits);
        notifyListeners();
        if (changed) _persistCatalogLists();
      }
    } catch (e) {
      debugPrint('Cloud catalog lists load: $e');
    }
  }

  final List<String> _shopCategories = [
    'Kirana',
    'Supermarket',
    'Dairy',
    'Wholesale',
    'Bakery',
    'General Store',
  ];
  List<String> get shopCategories => List.unmodifiable(_shopCategories);

  void addShopCategory(String category) {
    final trimmed = category.trim();
    if (trimmed.isNotEmpty && !_shopCategories.contains(trimmed)) {
      _shopCategories.add(trimmed);
      notifyListeners();
    }
  }

  /// Back-compat names for [productUnits] / [addProductUnit].
  List<String> get packagingUnits => productUnits;
  void addPackagingUnit(String unit) => addProductUnit(unit);

  // 4. Coupons Management (Trial & Flat Discount Coupons)
  final List<CouponModel> _coupons = List.from(CouponModel.defaultCoupons);
  List<CouponModel> get coupons => List.unmodifiable(_coupons);
  CouponModel? _appliedCoupon;
  CouponModel? get appliedCoupon => _appliedCoupon;

  void addCoupon(CouponModel coupon) {
    _coupons.removeWhere((c) => c.code == coupon.code);
    _coupons.add(coupon);
    notifyListeners();
    _persistAdminCatalog();
  }

  void removeCoupon(String code) {
    _coupons.removeWhere((c) => c.code == code);
    if (_appliedCoupon?.code == code) {
      _appliedCoupon = null;
    }
    notifyListeners();
    _persistAdminCatalog();
  }

  Future<void> saveCoupon(CouponModel coupon) async {
    final previous = List<CouponModel>.from(_coupons);
    _coupons.removeWhere((c) => c.code.toUpperCase() == coupon.code.toUpperCase());
    _coupons.add(coupon);
    try {
      await updatePlanPricing();
      notifyListeners();
    } catch (_) {
      _coupons..clear()..addAll(previous);
      notifyListeners();
      rethrow;
    }
  }

  void setCouponActive(String code, bool active) {
    final index = _coupons.indexWhere((coupon) => coupon.code == code);
    if (index < 0) return;
    _coupons[index] = CouponModel.fromMap({..._coupons[index].toMap(), 'isActive': active});
    if (!active && _appliedCoupon?.code == code) _appliedCoupon = null;
    notifyListeners();
    _persistAdminCatalog();
  }

  String? adminPersistenceError;
  void _persistAdminCatalog() {
    if (SupabaseService.instance.client == null) return;
    updatePlanPricing().then((_) {
      adminPersistenceError = null;
    }).catchError((Object error) {
      adminPersistenceError = error.toString();
      notifyListeners();
    });
  }

  CouponModel? findCoupon(String code) {
    final clean = code.trim().toUpperCase();
    try {
      return _coupons.firstWhere((c) => c.code == clean && c.isValid);
    } catch (_) {
      return null;
    }
  }

  bool applyCoupon(String code) {
    final coupon = findCoupon(code);
    if (coupon != null) {
      _appliedCoupon = coupon;
      notifyListeners();
      return true;
    }
    return false;
  }

  void clearAppliedCoupon() {
    _appliedCoupon = null;
    notifyListeners();
  }

  // 5. Multiple Bank Accounts for Viewing & Payment Settlement (Max 3 Accounts Limit)
  static const int maxBankAccounts = 3;
  bool get canAddBankAccount => _bankAccounts.length < maxBankAccounts;

  final List<Map<String, dynamic>> _bankAccounts = [];
  List<Map<String, dynamic>> get bankAccounts => List.unmodifiable(_bankAccounts);

  bool addBankAccount(Map<String, dynamic> account) {
    if (_bankAccounts.length >= maxBankAccounts) {
      return false;
    }
    final id = 'bank_${DateTime.now().millisecondsSinceEpoch}';
    final acc = Map<String, dynamic>.from(account);
    acc['id'] = id;
    if (_bankAccounts.isEmpty) {
      acc['isPrimary'] = true;
    } else if (acc['isPrimary'] == true) {
      for (int i = 0; i < _bankAccounts.length; i++) {
        _bankAccounts[i] = Map<String, dynamic>.from(_bankAccounts[i])..['isPrimary'] = false;
      }
    }
    _bankAccounts.add(acc);
    _persistBankAccountsLocally();

    if (acc['isPrimary'] == true || _bankAccounts.length == 1) {
      final newUpi = (acc['upiId'] != null && acc['upiId'].toString().trim().isNotEmpty)
          ? acc['upiId'].toString().trim()
          : _tenant.upiId;
      final updated = _tenant.copyWith(
        bankAccount: acc,
        upiId: newUpi,
      );
      updateTenant(updated);
    }

    final bName = acc['bankName'] ?? 'Bank';
    final rawNum = (acc['accountNumber'] as String? ?? '');
    final last4 = rawNum.length >= 4 ? rawNum.substring(rawNum.length - 4) : rawNum;
    addNotification(
      NotificationModel(
        id: 'notif_bank_add_${DateTime.now().millisecondsSinceEpoch}',
        type: 'system',
        title: 'Bank Account Added',
        message: '$bName (A/C ending in $last4) was linked (${_bankAccounts.length}/$maxBankAccounts registered).',
        createdAt: DateTime.now(),
      ),
    );

    notifyListeners();
    return true;
  }

  bool updateBankAccount(Map<String, dynamic> account) {
    final id = account['id']?.toString();
    if (id == null) return false;
    final idx = _bankAccounts.indexWhere((a) => a['id'] == id);
    if (idx == -1) return false;

    final acc = Map<String, dynamic>.from(account);
    if (acc['isPrimary'] == true) {
      for (int i = 0; i < _bankAccounts.length; i++) {
        _bankAccounts[i] = Map<String, dynamic>.from(_bankAccounts[i])..['isPrimary'] = false;
      }
    }
    _bankAccounts[idx] = acc;
    _persistBankAccountsLocally();

    if (acc['isPrimary'] == true || _bankAccounts.length == 1) {
      final newUpi = (acc['upiId'] != null && acc['upiId'].toString().trim().isNotEmpty)
          ? acc['upiId'].toString().trim()
          : _tenant.upiId;
      final updated = _tenant.copyWith(
        bankAccount: acc,
        upiId: newUpi,
      );
      updateTenant(updated);
    }

    notifyListeners();
    return true;
  }

  void removeBankAccount(String id) {
    final removed = _bankAccounts.where((a) => a['id'] == id).toList();
    _bankAccounts.removeWhere((a) => a['id'] == id);
    if (_bankAccounts.isNotEmpty && !_bankAccounts.any((a) => a['isPrimary'] == true)) {
      _bankAccounts[0] = Map<String, dynamic>.from(_bankAccounts[0])..['isPrimary'] = true;
    }
    _persistBankAccountsLocally();
    if (removed.isNotEmpty) {
      final bName = removed.first['bankName'] ?? 'Bank';
      addNotification(
        NotificationModel(
          id: 'notif_bank_rem_${DateTime.now().millisecondsSinceEpoch}',
          type: 'system',
          title: 'Bank Account Removed',
          message: '$bName account was removed (${_bankAccounts.length}/$maxBankAccounts slots in use).',
          createdAt: DateTime.now(),
        ),
      );
    }
    notifyListeners();
  }

  void setPrimaryBankAccount(String id) {
    String? bankName;
    for (int i = 0; i < _bankAccounts.length; i++) {
      final isCurrent = (_bankAccounts[i]['id'] == id);
      _bankAccounts[i] = Map<String, dynamic>.from(_bankAccounts[i])..['isPrimary'] = isCurrent;
      if (isCurrent) {
        bankName = _bankAccounts[i]['bankName'] as String?;
      }
    }
    _persistBankAccountsLocally();
    if (bankName != null) {
      addNotification(
        NotificationModel(
          id: 'notif_bank_prim_${DateTime.now().millisecondsSinceEpoch}',
          type: 'system',
          title: 'Primary Settlement Account Updated',
          message: '$bankName is now set as the primary settlement account for invoices.',
          createdAt: DateTime.now(),
        ),
      );
    }
    notifyListeners();
  }

  // Real-time Firestore Subscriptions
  StreamSubscription? _pricingSubscription;
  StreamSubscription? _pricingCamelSubscription;
  StreamSubscription? _platformSubscription;
  StreamSubscription? _platformCamelSubscription;
  StreamSubscription? _remoteConfigSubscription;
  StreamSubscription? _remoteConfigCamelSubscription;
  StreamSubscription? _broadcastSubscription;
  StreamSubscription? _broadcastCamelSubscription;
  StreamSubscription? _tenantSubscription;

  StreamSubscription? _shopsSubscription;
  StreamSubscription? _productsSubscription;
  StreamSubscription? _ordersSubscription;
  StreamSubscription? _invoicesSubscription;
  StreamSubscription? _paymentsSubscription;
  StreamSubscription? _visitsSubscription;
  StreamSubscription? _remindersSubscription;
  StreamSubscription? _ledgerSubscription;
  StreamSubscription? _staffSubscription;
  StreamSubscription? _notificationsSubscription;

  // Dynamic Configurable GST Tax Slabs (Used Across Catalog, Orders, Invoices)
  final List<GstSlabModel> _gstSlabs = List.from(GstSlabModel.defaultSlabs);
  List<GstSlabModel> get gstSlabs => List.unmodifiable(_gstSlabs);
  List<GstSlabModel> get activeGstSlabs => _gstSlabs.where((s) => s.isActive).toList();

  // Custom GST Slab Categories (Persistent across app restarts)
  static const String _savedCustomGstCategoriesKey = 'salesarmy_custom_gst_categories_v1';
  final List<String> _customGstCategories = ['Custom'];
  List<String> get customGstCategories => List.unmodifiable(_customGstCategories);

  Future<void> addCustomGstCategory(String cat) async {
    final trimmed = cat.trim();
    if (trimmed.isEmpty) return;
    if (!_customGstCategories.any((c) => c.toLowerCase() == trimmed.toLowerCase())) {
      _customGstCategories.add(trimmed);
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList(_savedCustomGstCategoriesKey, _customGstCategories);
      } catch (e) {
        debugPrint('Error saving custom GST category: $e');
      }
      notifyListeners();
    }
  }

  List<double> get gstRates {
    final rates = _gstSlabs.where((s) => s.isActive).map((s) => s.rate).toSet().toList();
    rates.sort();
    return List.unmodifiable(rates);
  }

  GstSlabModel? getSlabByRate(double rate) {
    try {
      return _gstSlabs.firstWhere((s) => s.rate == rate);
    } catch (_) {
      return null;
    }
  }

  void addGstRate(double rate) {
    if (rate < 0 || rate > 100) return;
    if (!_gstSlabs.any((s) => s.rate == rate)) {
      _gstSlabs.add(
        GstSlabModel(
          id: 'gst_${rate.toString().replaceAll('.', '_')}',
          rate: rate,
          name: 'Standard Goods & Services Tax',
          category: 'Custom Slab',
          details: 'Custom tax rate configured for business billing and products',
          createdAt: DateTime.now(),
        ),
      );
      _gstSlabs.sort((a, b) => a.rate.compareTo(b.rate));
      notifyListeners();
    }
  }

  Future<void> addGstSlab(GstSlabModel slab) async {
    if (slab.category.trim().isNotEmpty) {
      addCustomGstCategory(slab.category.trim());
    }
    final idx = _gstSlabs.indexWhere((s) => s.id == slab.id || s.rate == slab.rate);
    if (idx >= 0) {
      _gstSlabs[idx] = slab;
    } else {
      _gstSlabs.add(slab);
    }
    _gstSlabs.sort((a, b) => a.rate.compareTo(b.rate));

    addNotification(
      NotificationModel(
        id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
        title: 'GST Slab Configured: ${slab.formattedRate}',
        message: 'Configured "${slab.name}" (${slab.category}) with Intra-State CGST ${slab.cgstRate}% + SGST ${slab.sgstRate}%.',
        type: 'system',
        createdAt: DateTime.now(),
        isRead: false,
      ),
    );

    notifyListeners();
  }

  Future<void> updateGstSlab(GstSlabModel slab) async {
    await addGstSlab(slab);
  }

  Future<bool> deleteGstSlab(String slabId) async {
    if (_gstSlabs.length <= 1) return false;
    _gstSlabs.removeWhere((s) => s.id == slabId);
    notifyListeners();
    return true;
  }

  bool removeGstRate(double rate) {
    if (_gstSlabs.length <= 1) return false;
    _gstSlabs.removeWhere((s) => s.rate == rate);
    notifyListeners();
    return true;
  }

  // ==========================================
  // GST State Code Resolvers & Tax Engine
  // ==========================================
  static String getStateCodeFromGstin(String? gstin) {
    if (gstin == null || gstin.trim().length < 2) return '27';
    final code = gstin.trim().substring(0, 2);
    return int.tryParse(code) != null ? code : '27';
  }

  static String getStateNameFromCode(String code) {
    const stateMap = {
      '01': 'Jammu & Kashmir',
      '02': 'Himachal Pradesh',
      '03': 'Punjab',
      '04': 'Chandigarh',
      '05': 'Uttarakhand',
      '06': 'Haryana',
      '07': 'Delhi',
      '08': 'Rajasthan',
      '09': 'Uttar Pradesh',
      '10': 'Bihar',
      '11': 'Sikkim',
      '12': 'Arunachal Pradesh',
      '13': 'Nagaland',
      '14': 'Manipur',
      '15': 'Mizoram',
      '16': 'Tripura',
      '17': 'Meghalaya',
      '18': 'Assam',
      '19': 'West Bengal',
      '20': 'Jharkhand',
      '21': 'Odisha',
      '22': 'Chhattisgarh',
      '23': 'Madhya Pradesh',
      '24': 'Gujarat',
      '27': 'Maharashtra',
      '29': 'Karnataka',
      '30': 'Goa',
      '32': 'Kerala',
      '33': 'Tamil Nadu',
      '36': 'Telangana',
      '37': 'Andhra Pradesh',
    };
    return stateMap[code] ?? 'Maharashtra';
  }

  ({
    String gstType,
    double cgst,
    double sgst,
    double igst,
    double totalGst,
    bool isIntraState,
  }) calculateGstBreakdown({
    required double taxableAmount,
    required double gstRate,
    String? sellerGstin,
    String? buyerGstin,
    bool forceNonGst = false,
  }) {
    if (forceNonGst || !_isGstBillingEnabled || gstRate <= 0) {
      return (
        gstType: 'NON_GST',
        cgst: 0.0,
        sgst: 0.0,
        igst: 0.0,
        totalGst: 0.0,
        isIntraState: true,
      );
    }

    final sellerCode = getStateCodeFromGstin(sellerGstin ?? _tenant.gstin);
    final buyerCode = getStateCodeFromGstin(buyerGstin);
    final isIntra = sellerCode == buyerCode;
    final total = taxableAmount * (gstRate / 100);

    if (isIntra) {
      return (
        gstType: 'INTRA_STATE',
        cgst: total / 2,
        sgst: total / 2,
        igst: 0.0,
        totalGst: total,
        isIntraState: true,
      );
    } else {
      return (
        gstType: 'INTER_STATE',
        cgst: 0.0,
        sgst: 0.0,
        igst: total,
        totalGst: total,
        isIntraState: false,
      );
    }
  }

  // Dynamic Subscription Plans: Startup (399), Grow (599), Enterprise (899)
  final List<SubscriptionPlanModel> _subscriptionPlans = List.from(SubscriptionPlanModel.defaultPlans);
  List<SubscriptionPlanModel> get subscriptionPlans => List.unmodifiable(_subscriptionPlans);

  /// True once we have successfully loaded plans from the admin-synced cloud
  /// source (Supabase platform_settings/pricing_and_plans). While false the
  /// UI is showing hardcoded fallback plans and admin edits have not reached
  /// this device yet.
  bool _plansFromCloud = false;
  bool get plansFromCloud => _plansFromCloud;

  // Dynamic Printer Hardware Options Managed by Super Admin
  final List<PrinterOptionModel> _printerOptions = List.from(PrinterOptionModel.defaultOptions);
  List<PrinterOptionModel> get printerOptions => List.unmodifiable(_printerOptions);

  PrinterOptionModel get defaultPrinterOption {
    final active = _printerOptions.where((p) => p.isAvailable).toList();
    if (active.isEmpty) {
      return _printerOptions.isNotEmpty ? _printerOptions.first : PrinterOptionModel.defaultOptions.first;
    }
    return active.firstWhere((p) => p.isDefault, orElse: () => active.first);
  }

  void updateSubscriptionPlan({
    required String planId,
    double? monthlyPrice,
    double? yearlyMonthlyEquivalent,
    double? yearlyPrice,
    int? maxProducts,
    int? maxUsers,
    int? maxShops,
    String? name,
    String? tagline,
    List<String>? features,
    bool? isPopular,
    bool? isActive,
  }) {
    final idx = _subscriptionPlans.indexWhere((p) => p.id == planId);
    if (idx != -1) {
      _subscriptionPlans[idx] = _subscriptionPlans[idx].copyWith(
        name: name,
        monthlyPrice: monthlyPrice,
        yearlyMonthlyEquivalent: yearlyMonthlyEquivalent,
        yearlyPrice: yearlyPrice,
        maxProducts: maxProducts,
        maxUsers: maxUsers,
        maxShops: maxShops,
        tagline: tagline,
        features: features,
        isPopular: isPopular,
        isActive: isActive,
      );
      if (planId == 'enterprise' && monthlyPrice != null) {
        _monthlyPlanPrice = monthlyPrice;
      }
      if (planId == 'grow' && monthlyPrice != null) {
        _annualPlanPrice = monthlyPrice;
      }
      notifyListeners();
      _persistAdminCatalog();
    }
  }

  void updatePrinterOption({
    required String id,
    String? name,
    double? price,
    double? gstRate,
    String? paperWidth,
    String? connectivity,
    String? description,
    List<String>? features,
    bool? isAvailable,
    bool? isDefault,
  }) {
    final idx = _printerOptions.indexWhere((p) => p.id == id);
    if (idx != -1) {
      if (isDefault == true) {
        for (int i = 0; i < _printerOptions.length; i++) {
          _printerOptions[i] = _printerOptions[i].copyWith(isDefault: false);
        }
      }
      _printerOptions[idx] = _printerOptions[idx].copyWith(
        name: name,
        price: price,
        gstRate: gstRate,
        paperWidth: paperWidth,
        connectivity: connectivity,
        description: description,
        features: features,
        isAvailable: isAvailable,
        isDefault: isDefault,
      );
      if (_printerOptions[idx].isDefault || idx == 0) {
        _printerHardwarePrice = _printerOptions[idx].price;
        _printerGstRate = _printerOptions[idx].gstRate;
      }
      notifyListeners();
      _persistAdminCatalog();
    }
  }

  void addPrinterOption(PrinterOptionModel option) {
    _printerOptions.removeWhere((p) => p.id == option.id);
    _printerOptions.add(option);
    notifyListeners();
    _persistAdminCatalog();
  }

  void removePrinterOption(String id) {
    if (_printerOptions.length <= 1) return;
    _printerOptions.removeWhere((p) => p.id == id);
    notifyListeners();
    _persistAdminCatalog();
  }

  // Batch Sync (12:00 PM & 10:00 PM Windows) & Local Cache Deletion Policy
  DateTime? _lastBatchSyncTime;
  DateTime? get lastBatchSyncTime => _lastBatchSyncTime;

  Future<int> executeBatchSync() async {
    final count = outboxManager.pendingCount;
    await syncRepository?.flushOutbox();
    _lastBatchSyncTime = DateTime.now();
    notifyListeners();
    return count;
  }

  Future<bool> clearSyncedMobileStorage() async {
    if (outboxManager.pendingCount > 0) return false;
    notifyListeners();
    return true;
  }

  // Reset Account Functionality: Complete Transactional & Balance Flush
  Future<bool> resetAccountData({bool resetToDemo = false}) async {
    _orders.clear();
    _invoices.clear();
    _payments.clear();
    _ledgerEntries.clear();
    _visits.clear();
    _reminders.clear();
    _purchases.clear();
    _expenses.clear();
    _salesReturns.clear();

    for (int i = 0; i < _shops.length; i++) {
      _shops[i] = _shops[i].copyWith(currentOutstanding: 0.0);
    }

    for (int i = 0; i < _products.length; i++) {
      _products[i] = _products[i].copyWith(
        stockQuantity: 0,
        updatedAt: DateTime.now(),
      );
    }

    _inHandCash = 0.0;
    _inAccountBalance = 0.0;
    _syncBalancesToFirestore();

    // Persist emptied data across namespaced local storage
    await _persistShopsLocally();
    await _persistProductsLocally();
    await _persistOrdersLocally();
    await _persistInvoicesLocally();
    await _persistPaymentsLocally();
    await _persistLedgerLocally();
    await _persistVisitsLocally();
    await _persistRemindersLocally();
    await _persistPurchasesLocally();
    await _persistExpensesLocally();
    await _persistLiquidBalancesLocally();

    // Transactional database purge if connected to Supabase
    final supaTid = currentTenantId ?? _tenant.tenantId;
    if (supaTid.isNotEmpty && SupabaseService.instance.isInitialized) {
      try {
        await SupabaseService.instance.client?.rpc('admin_purge_tenant_transactions', params: {'p_tenant': supaTid});
      } catch (e) {
        debugPrint('Supabase purge note: $e');
      }
    }

    try {
      await outboxManager.init();
    } catch (e) {
      debugPrint('OutboxManager re-init after reset: $e');
    }

    notifyListeners();
    return true;
  }

  // Plan Pricing & SaaS Tiers (Synchronized in Real-Time with all Subscribers)
  double _monthlyPlanPrice = 899.0;
  double get monthlyPlanPrice => _monthlyPlanPrice;

  double _annualPlanPrice = 599.0;
  double get annualPlanPrice => _annualPlanPrice;
  int get annualPlanYearlyTotal => (_annualPlanPrice * 12).toInt();

  double _planGstRate = 18.0;
  double get planGstRate => _planGstRate;

  double _printerHardwarePrice = 2499.0;
  double get printerHardwarePrice => _printerHardwarePrice;

  double _printerGstRate = 18.0;
  double get printerGstRate => _printerGstRate;

  bool _applyGstOnInvoices = true;
  bool get applyGstOnInvoices => _applyGstOnInvoices;

  double _deliveryFee = 99.0;
  double get deliveryFee => _deliveryFee;

  // Hardware & Supplies Addons Managed by Admin Panel
  final List<SubscriptionAddonModel> _subscriptionAddons = [
    const SubscriptionAddonModel(
      id: 'addon_extra_user',
      title: 'Extra Staff Seat License',
      description: 'Add an additional mobile salesman or delivery van driver to your workspace with live field tracking.',
      price: 149.0,
      gstRate: 18.0,
      category: 'seats',
      period: 'monthly',
      features: ['1 Active Staff Login', 'Live GPS Route Tracking', 'Cash Register'],
      icon: Icons.person_add_alt_1_rounded,
      isAvailable: true,
    ),
    const SubscriptionAddonModel(
      id: 'addon_extra_shops',
      title: '+500 Retail Shop Directory Boost',
      description: 'Expand your retail footprint with 500 extra customer shop accounts, credit ledgers, and visit scheduling.',
      price: 299.0,
      gstRate: 18.0,
      category: 'directory',
      period: 'monthly',
      features: ['+500 Shop Profiles', 'Khata Credit Ledgers', 'Geo-tagged Pinpoints'],
      icon: Icons.storefront_rounded,
      isAvailable: true,
    ),
    const SubscriptionAddonModel(
      id: 'addon_whatsapp_sms',
      title: 'Smart WhatsApp & SMS Notification Pack',
      description: 'Automated WhatsApp PDF invoice dispatch and SMS dispatch alerts to retailers instantly upon order booking.',
      price: 399.0,
      gstRate: 18.0,
      category: 'notifications',
      period: 'monthly',
      features: ['1,000 WhatsApp Slips/mo', 'Instant SMS Alerts', 'Payment Reminders'],
      icon: Icons.chat_bubble_outline_rounded,
      isAvailable: true,
    ),
    const SubscriptionAddonModel(
      id: 'addon_rolls',
      title: 'Thermal Paper Rolls Pack (Box of 24)',
      description: 'Premium BPA-free 58mm direct thermal paper rolls box with 5-year image preservation coating.',
      price: 499.0,
      gstRate: 18.0,
      category: 'supplies',
      period: 'one_time',
      features: ['24 High-Density Rolls', 'BPA-Free Clear Coating', 'Free Doorstep Courier'],
      icon: Icons.receipt_long_rounded,
      isAvailable: true,
    ),
    const SubscriptionAddonModel(
      id: 'addon_scanner',
      title: 'Wireless Barcode & QR Scanner',
      description: 'Handheld Bluetooth 1D/2D scanner for ultra-fast barcode lookup and zero-error inventory tally.',
      price: 1799.0,
      gstRate: 18.0,
      category: 'hardware',
      period: 'one_time',
      features: ['Bluetooth & 2.4G Wireless', 'Fast 1D/2D decode', 'Rugged casing'],
      icon: Icons.qr_code_scanner_rounded,
      isAvailable: true,
    ),
    const SubscriptionAddonModel(
      id: 'addon_weighing_scale',
      title: 'Digital Bluetooth Weighing Scale',
      description: 'Precision digital scale directly paired to POS for auto-filling exact gross weight and billing kg items.',
      price: 3499.0,
      gstRate: 18.0,
      category: 'hardware',
      period: 'one_time',
      features: ['Up to 50kg capacity', 'Bluetooth POS auto-sync', 'Heavy duty steel'],
      icon: Icons.scale_rounded,
      isAvailable: true,
    ),
    const SubscriptionAddonModel(
      id: 'addon_vip_support',
      title: 'VIP Priority Support & Account Manager',
      description: 'Direct phone & WhatsApp hotline with guaranteed 15-minute SLA and priority staff onboarding training.',
      price: 999.0,
      gstRate: 18.0,
      category: 'support',
      period: 'yearly',
      features: ['Dedicated Phone Line', '15-min Guaranteed SLA', 'Quarterly Audit'],
      icon: Icons.verified_user_rounded,
      isAvailable: true,
    ),
  ];
  List<SubscriptionAddonModel> get subscriptionAddons => List.unmodifiable(_subscriptionAddons);

  void toggleAddonAvailability(String id, bool isAvailable) {
    final idx = _subscriptionAddons.indexWhere((a) => a.id == id);
    if (idx != -1) {
      _subscriptionAddons[idx] = _subscriptionAddons[idx].copyWith(isAvailable: isAvailable);
      notifyListeners();
      _persistAdminCatalog();
    }
  }

  void updateAddonPrice(String id, double price) {
    final idx = _subscriptionAddons.indexWhere((a) => a.id == id);
    if (idx != -1) {
      _subscriptionAddons[idx] = _subscriptionAddons[idx].copyWith(price: price);
      if (id == 'addon_printer') {
        _printerHardwarePrice = price;
      }
      notifyListeners();
      _persistAdminCatalog();
    }
  }

  void addSubscriptionAddon(SubscriptionAddonModel addon) {
    _subscriptionAddons.removeWhere((a) => a.id == addon.id);
    _subscriptionAddons.add(addon);
    notifyListeners();
    _persistAdminCatalog();
  }

  void removeSubscriptionAddon(String id) {
    _subscriptionAddons.removeWhere((a) => a.id == id);
    notifyListeners();
    _persistAdminCatalog();
  }

  bool _maintenanceMode = false;
  bool get isMaintenanceMode => _maintenanceMode;

  String _minAppVersion = 'v2.4.1';
  String get minAppVersion => _minAppVersion;

  String _adminPasscode = '';
  String get adminPasscode => _adminPasscode;

  // Dark Theme Mode
  static const String _themeModePrefKey = 'app_theme_mode';
  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  Future<void> _loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_themeModePrefKey);
      if (saved == 'dark') {
        _themeMode = ThemeMode.dark;
        notifyListeners();
      } else if (saved == 'light') {
        _themeMode = ThemeMode.light;
        notifyListeners();
      } else if (saved == 'system') {
        _themeMode = ThemeMode.system;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Note: Error loading theme preference: $e');
    }
  }

  Future<void> _saveThemePreference(ThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String val = 'light';
      if (mode == ThemeMode.dark) {
        val = 'dark';
      } else if (mode == ThemeMode.system) {
        val = 'system';
      }
      await prefs.setString(_themeModePrefKey, val);
    } catch (e) {
      debugPrint('Note: Error saving theme preference: $e');
    }
  }

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    _saveThemePreference(_themeMode);
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    _saveThemePreference(_themeMode);
    notifyListeners();
  }

  // Storage keys for persistent local storage
  static const String _prefsKeyShops = 'salesarmy_local_shops_v2';
  static const String _prefsKeyProducts = 'salesarmy_local_products_v2';
  static const String _prefsKeyOrders = 'salesarmy_local_orders_v2';
  static const String _prefsKeyInvoices = 'salesarmy_local_invoices_v2';
  static const String _prefsKeyPayments = 'salesarmy_local_payments_v2';
  static const String _prefsKeyLedger = 'salesarmy_local_ledger_v2';
  static const String _prefsKeyVisits = 'salesarmy_local_visits_v2';
  static const String _prefsKeyReminders = 'salesarmy_local_reminders_v2';
  static const String _prefsKeyStaff = 'salesarmy_local_staff_v2';
  static const String _prefsKeyPurchases = 'salesarmy_local_purchases_v2';
  static const String _prefsKeyExpenses = 'salesarmy_local_expenses_v2';
  static const String _prefsKeyBankAccounts = 'salesarmy_local_bank_accounts_v2';
  static const String _prefsKeyNotifications = 'salesarmy_local_notifications_v2';
  static const String _prefsKeyLiquidBalances = 'salesarmy_local_liquid_balances_v2';

  String _tenantStorageKey(String baseKey) {
    final tid = currentTenantId ?? _tenant.tenantId;
    if (tid.isNotEmpty) {
      return '${tid}_$baseKey';
    }
    return baseKey;
  }

  String? _getTenantPrefString(SharedPreferences prefs, String baseKey) {
    return prefs.getString(_tenantStorageKey(baseKey)) ?? prefs.getString(baseKey);
  }

  Future<void> clearTenantCache(String tenantId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = [
        _prefsKeyShops,
        _prefsKeyProducts,
        _prefsKeyOrders,
        _prefsKeyInvoices,
        _prefsKeyPayments,
        _prefsKeyLedger,
        _prefsKeyVisits,
        _prefsKeyReminders,
        _prefsKeyStaff,
        _prefsKeyPurchases,
        _prefsKeyExpenses,
        _prefsKeyBankAccounts,
        _prefsKeyNotifications,
        _prefsKeyLiquidBalances,
      ];
      for (final k in keys) {
        await prefs.remove('${tenantId}_$k');
      }
    } catch (e) {
      debugPrint('Error clearing tenant cache for $tenantId: $e');
    }
  }

  // In-Hand & In-Account Liquid Balances
  double _inHandCash = 0.0;
  double get inHandCash => _inHandCash;

  double _inAccountBalance = 0.0;
  double get inAccountBalance => _inAccountBalance;

  double get totalLiquidBalance => _inHandCash + _inAccountBalance;

  Future<void> updateInHandAndAccountBalances({
    required double inHandCash,
    required double inAccountBalance,
  }) async {
    _inHandCash = inHandCash;
    _inAccountBalance = inAccountBalance;
    _persistLiquidBalancesLocally();
    notifyListeners();

  }

  final List<ShopModel> _shops = [];
  final List<ProductModel> _products = [];
  final List<OrderModel> _orders = [];
  final List<InvoiceModel> _invoices = [];
  final List<PaymentModel> _payments = [];
  final List<LedgerEntryModel> _ledgerEntries = [];
  final List<VisitModel> _visits = [];
  final List<ReminderModel> _reminders = [];
  final List<StaffModel> _staffList = [];
  StaffModel? _activeStaffUser;
  final List<PurchaseModel> _purchases = [];
  final List<ExpenseModel> _expenses = [];
  final List<SalesReturnModel> _salesReturns = [];
  List<SalesReturnModel> get salesReturns => List.unmodifiable(_salesReturns);
  final List<NotificationModel> _notifications = [];

  void _seedMockData() {
    if (_shops.isEmpty) _shops.addAll(MockData.sampleShops);
    if (_products.isEmpty) _products.addAll(MockData.sampleProducts);
    if (_orders.isEmpty) _orders.addAll(MockData.sampleOrders);
    if (_invoices.isEmpty) _invoices.addAll(MockData.sampleInvoices);
    if (_payments.isEmpty) _payments.addAll(MockData.samplePayments);
    if (_ledgerEntries.isEmpty) _ledgerEntries.addAll(MockData.sampleLedgerEntries);
    if (_visits.isEmpty) _visits.addAll(MockData.sampleVisits);
    if (_reminders.isEmpty) _reminders.addAll(MockData.sampleReminders);
    if (_staffList.isEmpty) _staffList.addAll(MockData.sampleStaffList);
    if (_purchases.isEmpty) _purchases.addAll(MockData.samplePurchases);
    if (_expenses.isEmpty) _expenses.addAll(MockData.sampleExpenses);
    if (_bankAccounts.isEmpty) _bankAccounts.addAll(MockData.sampleBankAccounts);
    _inHandCash = 18450.0;
    _inAccountBalance = 142500.0;
  }

  // Safe JSON converters for local disk persistence
  Map<String, dynamic> _shopToJson(ShopModel s) => {
    'shopId': s.shopId,
    'shopName': s.shopName,
    'ownerName': s.ownerName,
    'phone': s.phone,
    'whatsappNumber': s.whatsappNumber,
    'businessType': s.businessType,
    'categoryId': s.categoryId,
    'gstin': s.gstin,
    'address': s.address,
    'visitFrequency': s.visitFrequency,
    'creditLimit': s.creditLimit,
    'currentOutstanding': s.currentOutstanding,
    'latitude': s.latitude,
    'longitude': s.longitude,
    'imageUrl': s.imageUrl,
    'notes': s.notes,
    'isActive': s.isActive,
    'createdAt': s.createdAt?.toIso8601String(),
    'updatedAt': s.updatedAt?.toIso8601String(),
    'createdByUid': s.createdByUid,
    'updatedByUid': s.updatedByUid,
  };

  Map<String, dynamic> _productToJson(ProductModel p) => {
    'productId': p.productId,
    'name': p.name,
    'variant': p.variant,
    'size': p.size,
    'categoryId': p.categoryId,
    if (p.variants != null) 'variants': p.variants!.map((v) => v.toMap()).toList(),
    'sku': p.sku,
    'barcode': p.barcode,
    'hsnSacCode': p.hsnSacCode,
    'basePrice': p.basePrice,
    'wholesalePrice': p.wholesalePrice,
    'retailPrice': p.retailPrice,
    'customerPrice': p.customerPrice,
    'gstRate': p.gstRate,
    'stockQuantity': p.stockQuantity,
    'lowStockAlertQty': p.lowStockAlertQty,
    'imageUrl': p.imageUrl,
    'isActive': p.isActive,
    'createdAt': p.createdAt?.toIso8601String(),
    'updatedAt': p.updatedAt?.toIso8601String(),
    'createdByUid': p.createdByUid,
    'updatedByUid': p.updatedByUid,
  };

  Map<String, dynamic> _orderToJson(OrderModel o) => {
    'orderId': o.orderId,
    'shopId': o.shopId,
    'createdByUid': o.createdByUid,
    'status': o.status,
    'items': o.items.map((i) => i.toMap()).toList(),
    'subtotal': o.subtotal,
    'totalGst': o.totalGst,
    'grandTotal': o.grandTotal,
    'deliveryNote': o.deliveryNote,
    'placedAt': o.placedAt?.toIso8601String(),
    'deliveredAt': o.deliveredAt?.toIso8601String(),
    'createdAt': o.createdAt?.toIso8601String(),
    'updatedAt': o.updatedAt?.toIso8601String(),
  };

  Map<String, dynamic> _invoiceToJson(InvoiceModel inv) => {
    'invoiceId': inv.invoiceId,
    'invoiceNumber': inv.invoiceNumber,
    'orderId': inv.orderId,
    'shopId': inv.shopId,
    'invoiceType': inv.invoiceType,
    'invoiceDate': inv.invoiceDate.toIso8601String(),
    'seller': inv.seller,
    'buyer': inv.buyer,
    'placeOfSupply': inv.placeOfSupply,
    'items': inv.items.map((i) => i.toMap()).toList(),
    'taxableSubtotal': inv.taxableSubtotal,
    'cgst': inv.cgst,
    'sgst': inv.sgst,
    'igst': inv.igst,
    'totalGst': inv.totalGst,
    'grandTotal': inv.grandTotal,
    'paidAmount': inv.paidAmount,
    'dueAmount': inv.dueAmount,
    'paymentStatus': inv.paymentStatus,
    'pdfUrl': inv.pdfUrl,
    'whatsappSent': inv.whatsappSent,
    'createdAt': inv.createdAt?.toIso8601String(),
    'updatedAt': inv.updatedAt?.toIso8601String(),
  };

  Map<String, dynamic> _paymentToJson(PaymentModel pay) => {
    'paymentId': pay.paymentId,
    'shopId': pay.shopId,
    'createdByUid': pay.createdByUid,
    'amount': pay.amount,
    'paymentMode': pay.paymentMode,
    'referenceNumber': pay.referenceNumber,
    'date': pay.date.toIso8601String(),
    'notes': pay.notes,
    'createdAt': pay.createdAt?.toIso8601String(),
  };

  Map<String, dynamic> _ledgerToJson(LedgerEntryModel l) => {
    'ledgerId': l.ledgerId,
    'shopId': l.shopId,
    'createdByUid': l.createdByUid,
    'type': l.type,
    'referenceId': l.referenceId,
    'amount': l.amount,
    'balanceAfter': l.balanceAfter,
    'description': l.description,
    'date': l.date.toIso8601String(),
    'createdAt': l.createdAt?.toIso8601String(),
  };

  Map<String, dynamic> _visitToJson(VisitModel v) => {
    'visitId': v.visitId,
    'shopId': v.shopId,
    'distributorUid': v.distributorUid,
    'checkInTime': v.checkInTime.toIso8601String(),
    'checkOutTime': v.checkOutTime?.toIso8601String(),
    'latitude': v.latitude,
    'longitude': v.longitude,
    'notes': v.notes,
    'photoUrl': v.photoUrl,
    'orderPlaced': v.orderPlaced,
  };

  Map<String, dynamic> _reminderToJson(ReminderModel r) => {
    'reminderId': r.reminderId,
    'shopId': r.shopId,
    'shopName': r.shopName,
    'assignedToUid': r.assignedToUid,
    'dueDate': r.dueDate.toIso8601String(),
    'description': r.description,
    'title': r.title,
    'purpose': r.purpose,
    'priority': r.priority,
    'note': r.note,
    'isCompleted': r.isCompleted,
    'createdAt': r.createdAt?.toIso8601String(),
  };

  Map<String, dynamic> _staffToJson(StaffModel s) => {
    'id': s.id,
    'name': s.name,
    'email': s.email,
    'mobile': s.mobile,
    'role': s.role,
    'isActive': s.isActive,
    'permissions': s.permissions.toMap(),
    'createdAt': s.createdAt.toIso8601String(),
  };

  Future<void> _persistShopsLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tenantStorageKey(_prefsKeyShops), json.encode(_shops.map(_shopToJson).toList()));
    } catch (e) {
      debugPrint('Error persisting shops locally: $e');
    }
  }

  Future<void> _persistProductsLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tenantStorageKey(_prefsKeyProducts), json.encode(_products.map(_productToJson).toList()));
    } catch (e) {
      debugPrint('Error persisting products locally: $e');
    }
  }

  Future<void> _persistOrdersLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tenantStorageKey(_prefsKeyOrders), json.encode(_orders.map(_orderToJson).toList()));
    } catch (e) {
      debugPrint('Error persisting orders locally: $e');
    }
  }

  Future<void> _persistInvoicesLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tenantStorageKey(_prefsKeyInvoices), json.encode(_invoices.map(_invoiceToJson).toList()));
    } catch (e) {
      debugPrint('Error persisting invoices locally: $e');
    }
  }

  Future<void> _persistPaymentsLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tenantStorageKey(_prefsKeyPayments), json.encode(_payments.map(_paymentToJson).toList()));
    } catch (e) {
      debugPrint('Error persisting payments locally: $e');
    }
  }

  Future<void> _persistLedgerLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tenantStorageKey(_prefsKeyLedger), json.encode(_ledgerEntries.map(_ledgerToJson).toList()));
    } catch (e) {
      debugPrint('Error persisting ledger locally: $e');
    }
  }

  Future<void> _persistVisitsLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tenantStorageKey(_prefsKeyVisits), json.encode(_visits.map(_visitToJson).toList()));
    } catch (e) {
      debugPrint('Error persisting visits locally: $e');
    }
  }

  Future<void> _persistRemindersLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tenantStorageKey(_prefsKeyReminders), json.encode(_reminders.map(_reminderToJson).toList()));
    } catch (e) {
      debugPrint('Error persisting reminders locally: $e');
    }
  }

  Future<void> _persistStaffLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tenantStorageKey(_prefsKeyStaff), json.encode(_staffList.map(_staffToJson).toList()));
    } catch (e) {
      debugPrint('Error persisting staff locally: $e');
    }
  }

  Future<void> _persistPurchasesLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tenantStorageKey(_prefsKeyPurchases), json.encode(_purchases.map((p) => p.toMap()).toList()));
    } catch (e) {
      debugPrint('Error persisting purchases locally: $e');
    }
  }

  Future<void> _persistExpensesLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tenantStorageKey(_prefsKeyExpenses), json.encode(_expenses.map((e) => e.toMap()).toList()));
    } catch (e) {
      debugPrint('Error persisting expenses locally: $e');
    }
  }

  Future<void> _persistBankAccountsLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tenantStorageKey(_prefsKeyBankAccounts), json.encode(_bankAccounts));
      final primary = _bankAccounts.firstWhere(
        (a) => a['isPrimary'] == true,
        orElse: () => _bankAccounts.isNotEmpty ? _bankAccounts.first : <String, dynamic>{},
      );
      if (primary.isNotEmpty) {
        await prefs.setString('salesarmy_pref_bank_account_v2', json.encode(primary));
        if (primary['upiId'] != null && primary['upiId'].toString().trim().isNotEmpty) {
          await prefs.setString('salesarmy_pref_upi_id_v2', primary['upiId'].toString().trim());
        }
      }
    } catch (e) {
      debugPrint('Error persisting bank accounts locally: $e');
    }
  }

  Future<void> _persistNotificationsLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tenantStorageKey(_prefsKeyNotifications), json.encode(_notifications.map((n) => n.toMap()).toList()));
    } catch (e) {
      debugPrint('Error persisting notifications locally: $e');
    }
  }

  Future<void> _persistLiquidBalancesLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'inHandCash': _inHandCash,
        'inAccountBalance': _inAccountBalance,
      };
      await prefs.setString(_tenantStorageKey(_prefsKeyLiquidBalances), json.encode(data));
    } catch (e) {
      debugPrint('Error persisting liquid balances locally: $e');
    }
  }

  Future<void> _loadAllLocalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final shopsJson = _getTenantPrefString(prefs, _prefsKeyShops);
      if (shopsJson != null && shopsJson.trim().isNotEmpty) {
        final List decoded = json.decode(shopsJson);
        final loaded = decoded.whereType<Map<String, dynamic>>().map((m) => ShopModel.fromMap(m, m['shopId']?.toString() ?? '')).toList();
        _shops.clear();
        _shops.addAll(loaded);
        _shopRepository?.replaceWith(loaded);
      }

      final prodsJson = _getTenantPrefString(prefs, _prefsKeyProducts);
      if (prodsJson != null && prodsJson.trim().isNotEmpty) {
        final List decoded = json.decode(prodsJson);
        final loaded = decoded.whereType<Map<String, dynamic>>().map((m) => ProductModel.fromMap(m, m['productId']?.toString() ?? '')).toList();
        _products.clear();
        _products.addAll(loaded);
        _productRepository?.replaceWith(loaded);
      }

      final ordersJson = _getTenantPrefString(prefs, _prefsKeyOrders);
      if (ordersJson != null && ordersJson.trim().isNotEmpty) {
        final List decoded = json.decode(ordersJson);
        final loaded = decoded.whereType<Map<String, dynamic>>().map((m) => OrderModel.fromMap(m, m['orderId']?.toString() ?? '')).toList();
        _orders.clear();
        _orders.addAll(loaded);
        _orderRepository?.replaceWith(loaded);
      }

      final invoicesJson = _getTenantPrefString(prefs, _prefsKeyInvoices);
      if (invoicesJson != null && invoicesJson.trim().isNotEmpty) {
        final List decoded = json.decode(invoicesJson);
        final loaded = decoded.whereType<Map<String, dynamic>>().map((m) => InvoiceModel.fromMap(m, m['invoiceId']?.toString() ?? '')).toList();
        _invoices.clear();
        _invoices.addAll(loaded);
      }

      final paymentsJson = _getTenantPrefString(prefs, _prefsKeyPayments);
      if (paymentsJson != null && paymentsJson.trim().isNotEmpty) {
        final List decoded = json.decode(paymentsJson);
        final loaded = decoded.whereType<Map<String, dynamic>>().map((m) => PaymentModel.fromMap(m, m['paymentId']?.toString() ?? '')).toList();
        _payments.clear();
        _payments.addAll(loaded);
      }

      final ledgerJson = _getTenantPrefString(prefs, _prefsKeyLedger);
      if (ledgerJson != null && ledgerJson.trim().isNotEmpty) {
        final List decoded = json.decode(ledgerJson);
        final loaded = decoded.whereType<Map<String, dynamic>>().map((m) => LedgerEntryModel.fromMap(m, m['ledgerId']?.toString() ?? '')).toList();
        _ledgerEntries.clear();
        _ledgerEntries.addAll(loaded);
      }

      final visitsJson = _getTenantPrefString(prefs, _prefsKeyVisits);
      if (visitsJson != null && visitsJson.trim().isNotEmpty) {
        final List decoded = json.decode(visitsJson);
        final loaded = decoded.whereType<Map<String, dynamic>>().map((m) => VisitModel.fromMap(m, m['visitId']?.toString() ?? '')).toList();
        _visits.clear();
        _visits.addAll(loaded);
      }

      final remJson = _getTenantPrefString(prefs, _prefsKeyReminders);
      if (remJson != null && remJson.trim().isNotEmpty) {
        final List decoded = json.decode(remJson);
        final loaded = decoded.whereType<Map<String, dynamic>>().map((m) => ReminderModel.fromMap(m, m['reminderId']?.toString() ?? '')).toList();
        _reminders.clear();
        _reminders.addAll(loaded);
      }

      final staffJson = _getTenantPrefString(prefs, _prefsKeyStaff);
      if (staffJson != null && staffJson.trim().isNotEmpty) {
        final List decoded = json.decode(staffJson);
        final loaded = decoded.whereType<Map<String, dynamic>>().map((m) => StaffModel.fromMap(m, m['id']?.toString() ?? '')).toList();
        _staffList.clear();
        _staffList.addAll(loaded);
      }

      final purJson = _getTenantPrefString(prefs, _prefsKeyPurchases);
      if (purJson != null && purJson.trim().isNotEmpty) {
        final List decoded = json.decode(purJson);
        final loaded = decoded.whereType<Map<String, dynamic>>().map((m) => PurchaseModel.fromMap(m, m['id']?.toString() ?? '')).toList();
        _purchases.clear();
        _purchases.addAll(loaded);
      }

      final expJson = _getTenantPrefString(prefs, _prefsKeyExpenses);
      if (expJson != null && expJson.trim().isNotEmpty) {
        final List decoded = json.decode(expJson);
        final loaded = decoded.whereType<Map<String, dynamic>>().map((m) => ExpenseModel.fromMap(m, m['id']?.toString() ?? '')).toList();
        _expenses.clear();
        _expenses.addAll(loaded);
      }

      final bankJson = _getTenantPrefString(prefs, _prefsKeyBankAccounts);
      if (bankJson != null && bankJson.trim().isNotEmpty) {
        final List decoded = json.decode(bankJson);
        _bankAccounts.clear();
        _bankAccounts.addAll(decoded.whereType<Map<String, dynamic>>());
      }
      if (_tenant.bankAccount == null && _bankAccounts.isNotEmpty) {
        final primary = _bankAccounts.firstWhere(
          (a) => a['isPrimary'] == true,
          orElse: () => _bankAccounts.first,
        );
        _tenant = _tenant.copyWith(
          bankAccount: primary,
          upiId: (primary['upiId'] != null && primary['upiId'].toString().trim().isNotEmpty)
              ? primary['upiId'].toString().trim()
              : _tenant.upiId,
        );
      }

      final notifJson = _getTenantPrefString(prefs, _prefsKeyNotifications);
      if (notifJson != null && notifJson.trim().isNotEmpty) {
        final List decoded = json.decode(notifJson);
        final loaded = decoded.whereType<Map<String, dynamic>>().map((m) => NotificationModel.fromMap(m, m['id']?.toString() ?? '')).toList();
        _notifications.clear();
        _notifications.addAll(loaded);
      }

      final liquidJson = _getTenantPrefString(prefs, _prefsKeyLiquidBalances);
      if (liquidJson != null && liquidJson.trim().isNotEmpty) {
        final decoded = json.decode(liquidJson);
        if (decoded is Map<String, dynamic>) {
          _inHandCash = (decoded['inHandCash'] as num?)?.toDouble() ?? 0.0;
          _inAccountBalance = (decoded['inAccountBalance'] as num?)?.toDouble() ?? 0.0;
        }
      }

      final savedGstCats = prefs.getStringList(_savedCustomGstCategoriesKey);
      if (savedGstCats != null && savedGstCats.isNotEmpty) {
        for (final c in savedGstCats) {
          final trimmed = c.trim();
          if (trimmed.isNotEmpty && !_customGstCategories.any((cat) => cat.toLowerCase() == trimmed.toLowerCase())) {
            _customGstCategories.add(trimmed);
          }
        }
      }

      final savedGstBilling = prefs.getBool('salesarmy_pref_gst_billing_enabled_v1');
      if (savedGstBilling != null) {
        _isGstBillingEnabled = savedGstBilling;
        _tenant = _tenant.copyWith(isGstBillingEnabled: savedGstBilling);
      }

      if (_shouldLoadMocks && _shops.isEmpty && _products.isEmpty) {
        _seedMockData();
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading local data: $e');
    }
  }

  Future<void> clearAllDummyData() async {
    _shops.clear();
    _products.clear();
    _orders.clear();
    _invoices.clear();
    _payments.clear();
    _ledgerEntries.clear();
    _visits.clear();
    _reminders.clear();
    _staffList.clear();
    _purchases.clear();
    _expenses.clear();
    _bankAccounts.clear();
    _notifications.clear();
    _salesReturns.clear();
    _inHandCash = 0.0;
    _inAccountBalance = 0.0;

    _shopRepository?.replaceWith([]);
    _productRepository?.replaceWith([]);
    _orderRepository?.replaceWith([]);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKeyShops);
      await prefs.remove(_prefsKeyProducts);
      await prefs.remove(_prefsKeyOrders);
      await prefs.remove(_prefsKeyInvoices);
      await prefs.remove(_prefsKeyPayments);
      await prefs.remove(_prefsKeyLedger);
      await prefs.remove(_prefsKeyVisits);
      await prefs.remove(_prefsKeyReminders);
      await prefs.remove(_prefsKeyStaff);
      await prefs.remove(_prefsKeyPurchases);
      await prefs.remove(_prefsKeyExpenses);
      await prefs.remove(_prefsKeyBankAccounts);
      await prefs.remove(_prefsKeyNotifications);
      await prefs.remove(_prefsKeyLiquidBalances);
    } catch (e) { debugPrint('Clear local prefs on reset: $e'); }

    notifyListeners();
  }

  Future<void> seedSampleData() async {
    _seedMockData();
    await _persistShopsLocally();
    await _persistProductsLocally();
    await _persistOrdersLocally();
    await _persistInvoicesLocally();
    await _persistPaymentsLocally();
    await _persistLedgerLocally();
    await _persistVisitsLocally();
    await _persistRemindersLocally();
    await _persistStaffLocally();
    await _persistPurchasesLocally();
    await _persistExpensesLocally();
    await _persistBankAccountsLocally();
    await _persistLiquidBalancesLocally();
    notifyListeners();
  }
  static const String _dailyDismissalsPrefKey = 'daily_dismissed_notices_v1';
  final Map<String, String> _dailyDismissedDates = {};
  final Set<String> _dismissedNoticeIds = {};

  String? currentUserRole;
  bool get isSuperAdminUser => currentUserRole == 'super_admin';

  bool _isSuperAdminMode = false;
  bool get isSuperAdminMode => _isSuperAdminMode;

  // Enterprise Architecture: Repositories & Outbox Engine
  final OutboxManager _outboxManager = OutboxManager();
  OutboxManager get outboxManager => _outboxManager;

  ShopRepositoryImpl? _shopRepository;
  IShopRepository? get shopRepository => _shopRepository;

  OrderRepositoryImpl? _orderRepository;
  IOrderRepository? get orderRepository => _orderRepository;

  ProductRepositoryImpl? _productRepository;
  IProductRepository? get productRepository => _productRepository;

  SyncRepositoryImpl? _syncRepository;
  ISyncRepository? get syncRepository => _syncRepository;

  int _pendingMutationsCount = 0;
  int get pendingMutationsCount => _pendingMutationsCount;
  int get outboxPendingCount => _pendingMutationsCount;
  StreamSubscription<int>? _outboxSubscription;

  Future<void> flushOutbox() async {
    if (_syncRepository != null) {
      await _syncRepository!.flushOutbox();
      _pendingMutationsCount = _outboxManager.pendingCount;
      notifyListeners();
    }
  }

  final bool _shouldLoadMocks;

  AppState({bool? loadMockData}) : _shouldLoadMocks = loadMockData ?? false {
    if (_shouldLoadMocks) {
      _seedMockData();
    }
    _loadSavedTenant();
    _loadAllLocalData();
    _initBridgeSync();
    _initRealtimeListeners();
    _initOutbox();
    _loadThemePreference();
    _loadDailyDismissals();
  }

  Future<void> _initOutbox() async {
    // Subscribe first so the initial count notification from init() is
    // observed; then await persistence hydration so no local writes race the
    // hydrated queue.
    _outboxSubscription =
        _outboxManager.pendingCountStream.listen((pendingCountVal) {
      _pendingMutationsCount = pendingCountVal;
      notifyListeners();
    });
    await _outboxManager.init();
  }

  void _initRealtimeListeners() {

    void processPricingData(Map<String, dynamic> data) {
      if (data['coupons'] is List) {
        _coupons..clear()..addAll((data['coupons'] as List).whereType<Map>().map((c) => CouponModel.fromMap(Map<String, dynamic>.from(c))));
        if (_appliedCoupon != null && findCoupon(_appliedCoupon!.code) == null) _appliedCoupon = null;
      }
      if (data['subscriptionAddons'] is List) {
        _subscriptionAddons..clear()..addAll((data['subscriptionAddons'] as List).whereType<Map>().map((a) => SubscriptionAddonModel.fromMap(Map<String, dynamic>.from(a), a['id'].toString())));
      }
      // Fields the admin stores inside `data.plans.*` (new path from the
      // web-admin bridge) take precedence over the legacy top-level mirrors.
      // Without this, Plan GST, Printer GST and the default monthly/annual
      // prices never propagated — admin edits looked silent.
      final Map<String, dynamic> plansMap = data['plans'] is Map
          ? Map<String, dynamic>.from(data['plans'] as Map)
          : const <String, dynamic>{};

      _monthlyPlanPrice = (data['monthlyPlanPrice'] as num?)?.toDouble()
          ?? (plansMap['monthlyPlanPrice'] as num?)?.toDouble()
          ?? (plansMap['silverPrice'] as num?)?.toDouble()
          ?? _monthlyPlanPrice;
      _annualPlanPrice = (data['annualPlanPrice'] as num?)?.toDouble()
          ?? (plansMap['annualPlanPrice'] as num?)?.toDouble()
          ?? (plansMap['goldPrice'] as num?)?.toDouble()
          ?? _annualPlanPrice;
      _planGstRate = (data['planGstRate'] as num?)?.toDouble()
          ?? (plansMap['planGst'] as num?)?.toDouble()
          ?? (plansMap['planGstRate'] as num?)?.toDouble()
          ?? _planGstRate;
      _printerHardwarePrice = (data['printerHardwarePrice'] as num?)?.toDouble()
          ?? (plansMap['printerHardwarePrice'] as num?)?.toDouble()
          ?? _printerHardwarePrice;
      _printerGstRate = (data['printerGstRate'] as num?)?.toDouble()
          ?? (plansMap['printerGst'] as num?)?.toDouble()
          ?? (plansMap['printerGstRate'] as num?)?.toDouble()
          ?? _printerGstRate;
      _applyGstOnInvoices = data['applyGstOnInvoices'] as bool? ?? _applyGstOnInvoices;
      _deliveryFee = (data['deliveryFee'] as num?)?.toDouble() ?? _deliveryFee;

      // Dynamic Plans Parsing (List or Map)
      if (data['plans'] != null) {
        try {
          var rawPlans = data['plans'];
          if (rawPlans is Map && rawPlans.containsKey('tiers')) {
            rawPlans = rawPlans['tiers'];
          }
          final List<SubscriptionPlanModel> parsedPlans = [];
          if (rawPlans is List) {
            for (final item in rawPlans) {
              if (item is Map<String, dynamic>) {
                parsedPlans.add(SubscriptionPlanModel.fromMap(item, item['id'] ?? item['planId'] ?? 'plan'));
              } else if (item is Map) {
                parsedPlans.add(SubscriptionPlanModel.fromMap(Map<String, dynamic>.from(item), item['id']?.toString() ?? 'plan'));
              }
            }
          } else if (rawPlans is Map) {
            rawPlans.forEach((k, v) {
              if (v is Map) {
                final map = Map<String, dynamic>.from(v);
                parsedPlans.add(SubscriptionPlanModel.fromMap(map, k.toString()));
              }
            });
          }
          if (parsedPlans.isNotEmpty) {
            _subscriptionPlans.clear();
            _subscriptionPlans.addAll(parsedPlans);
            _plansFromCloud = true;
            debugPrint('⚡ Plans loaded from cloud: ${parsedPlans.length} tiers');
          } else {
            debugPrint('⚠️ Cloud returned empty plans — keeping local defaults');
          }
        } catch (e) {
          debugPrint('Error parsing dynamic plans — keeping local defaults: $e');
        }
      }

      // Dynamic Individual Tier Pricing fallbacks
      if (data['startupMonthlyPrice'] != null) {
        final val = (data['startupMonthlyPrice'] as num).toDouble();
        final idx = _subscriptionPlans.indexWhere((p) => p.id == 'startup');
        if (idx != -1) {
          _subscriptionPlans[idx] = _subscriptionPlans[idx].copyWith(
            monthlyPrice: val,
            yearlyMonthlyEquivalent: (val * 0.8).roundToDouble(),
          );
        }
      }
      if (data['growMonthlyPrice'] != null) {
        final val = (data['growMonthlyPrice'] as num).toDouble();
        final idx = _subscriptionPlans.indexWhere((p) => p.id == 'grow');
        if (idx != -1) {
          _subscriptionPlans[idx] = _subscriptionPlans[idx].copyWith(
            monthlyPrice: val,
            yearlyMonthlyEquivalent: (val * 0.8).roundToDouble(),
          );
        }
      }
      if (data['enterpriseMonthlyPrice'] != null) {
        final val = (data['enterpriseMonthlyPrice'] as num).toDouble();
        final idx = _subscriptionPlans.indexWhere((p) => p.id == 'enterprise');
        if (idx != -1) {
          _subscriptionPlans[idx] = _subscriptionPlans[idx].copyWith(
            monthlyPrice: val,
            yearlyMonthlyEquivalent: (val * 0.8).roundToDouble(),
          );
        }
      }

      // Dynamic Printer Hardware Options Parsing (List or Map)
      if (data['printerOptions'] != null) {
        try {
          final rawPrinters = data['printerOptions'];
          final List<PrinterOptionModel> parsedPrinters = [];
          if (rawPrinters is List) {
            for (final item in rawPrinters) {
              if (item is Map<String, dynamic>) {
                parsedPrinters.add(PrinterOptionModel.fromMap(item, item['id']));
              } else if (item is Map) {
                parsedPrinters.add(PrinterOptionModel.fromMap(Map<String, dynamic>.from(item), item['id']?.toString()));
              }
            }
          } else if (rawPrinters is Map) {
            rawPrinters.forEach((k, v) {
              if (v is Map) {
                final map = Map<String, dynamic>.from(v);
                parsedPrinters.add(PrinterOptionModel.fromMap(map, k.toString()));
              }
            });
          }
          if (rawPrinters is List || parsedPrinters.isNotEmpty) {
            _printerOptions.clear();
            _printerOptions.addAll(parsedPrinters);
            if (_printerOptions.isNotEmpty) {
              final def = defaultPrinterOption;
              _printerHardwarePrice = def.price;
              _printerGstRate = def.gstRate;
            }
          }
        } catch (e) {
          debugPrint('Error parsing dynamic printerOptions: $e');
        }
      }

      debugPrint('Real-Time Plan Pricing Synced: Plans=${_subscriptionPlans.length}, Printers=${_printerOptions.length}');
      notifyListeners();
    }

    void processGeneralData(Map<String, dynamic> data) {
      _enforceMobileOtp = data['enforceMobileOtp'] as bool? ?? _enforceMobileOtp;
      _smsProvider = data['smsProvider'] as String? ?? _smsProvider;
      _smsGatewayMode = data['smsGatewayMode'] as String? ?? _smsGatewayMode;
      _otpDigits = (data['otpDigits'] as num?)?.toInt() ?? _otpDigits;
      _maintenanceMode = data['maintenanceMode'] as bool? ?? _maintenanceMode;
      _minAppVersion = data['minAppVersion'] as String? ?? _minAppVersion;
      _applyPlanSettings(data);
      debugPrint('Real-Time Platform Settings Synced: EnforceOTP=$_enforceMobileOtp, Maintenance=$_maintenanceMode');
      notifyListeners();
    }

    void processRemoteConfigData(Map<String, dynamic> data) {
      if (data['featureFlags'] is Map) {
        final rf = (data['featureFlags'] as Map).map(
          (k, v) => MapEntry(k.toString(), v == true),
        );
        updateRemoteFeatureFlags(rf);
      }
      if (data['maintenance'] is Map) {
        final m = data['maintenance'] as Map<String, dynamic>;
        setMaintenanceDetails(
          isMaintenance: m['active'] == true,
          message: m['message']?.toString(),
          eta: m['eta']?.toString(),
        );
      }
      if (data['minAppVersion'] != null) {
        _minAppVersion = data['minAppVersion'].toString();
      }
      if (data['smsProvider'] != null) {
        _smsProvider = data['smsProvider'].toString();
      }
      if (data['otpDigits'] is num) {
        _otpDigits = (data['otpDigits'] as num).toInt();
      }
      if (data['smsMode'] != null) {
        _smsGatewayMode = data['smsMode'].toString();
      }
      if (data['enforceOtp'] is bool) {
        _enforceMobileOtp = data['enforceOtp'] as bool;
      }
      debugPrint('⚡ Real-Time Remote Config Synced from Admin Panel.');
      notifyListeners();
    }

    void processBroadcastData(Map<String, dynamic> data) {
      if (data['active'] == true) {
        setEmergencyBroadcast(Map<String, dynamic>.from(data));
      } else {
        setEmergencyBroadcast(null);
      }
      debugPrint('⚡ Real-Time In-App Emergency Broadcast Synced from Admin Panel: active=${data['active']}');
      notifyListeners();
    }

    // 0. Connect Supabase Real-Time Settings Listeners (Immediate Cloud Sync from Web Admin)
    try {
      // 0a. Pricing, Plans & Coupons
      SupabaseService.instance.listenToPlatformSettings(
        settingId: 'pricing_and_plans',
        onUpdate: (data) => processPricingData(data),
      );
      SupabaseService.instance.fetchPlatformSettings('pricing_and_plans').then((data) {
        if (data != null) processPricingData(data);
      });

      // 0b. Remote Feature Flags & Kill Switches (Controls Entire Mobile App)
      SupabaseService.instance.listenToPlatformSettings(
        settingId: 'remote_config',
        onUpdate: (data) => processRemoteConfigData(data),
      );
      SupabaseService.instance.fetchPlatformSettings('remote_config').then((data) {
        if (data != null) processRemoteConfigData(data);
      });

      // 0c. In-App Emergency Broadcast Announcements
      SupabaseService.instance.listenToPlatformSettings(
        settingId: 'broadcast',
        onUpdate: (data) => processBroadcastData(data),
      );
      SupabaseService.instance.fetchPlatformSettings('broadcast').then((data) {
        if (data != null) processBroadcastData(data);
      });

      // 0d. General Platform Settings & Maintenance
      SupabaseService.instance.listenToPlatformSettings(
        settingId: 'general_settings',
        onUpdate: (data) => processGeneralData(data),
      );
      SupabaseService.instance.fetchPlatformSettings('general_settings').then((data) {
        if (data != null) processGeneralData(data);
      });
    } catch (e) {
      debugPrint('Supabase initial platform settings sync note: $e');
    }

    // Firestore remote-config / broadcast listeners removed; Supabase handlers above are authoritative.

    // Expose the local processor via a field so public refresh methods below
    // can trigger it on demand (manual "pull latest plans" button in UI).
    _processPricingDataFn = processPricingData;
  }

  // Reference to the local processPricingData closure captured in
  // _initRealtimeListeners. Used by refreshPricingFromCloud() for pull-to-sync.
  void Function(Map<String, dynamic>)? _processPricingDataFn;

  /// Pulls the latest `platform_settings/pricing_and_plans` row from Supabase
  /// and applies it to _subscriptionPlans. Used by the Plans screen's manual
  /// refresh button so admins/testers don't have to wait for realtime to
  /// re-deliver the payload. Returns true on success.
  Future<bool> refreshPricingFromCloud() async {
    try {
      final data = await SupabaseService.instance.fetchPlatformSettings('pricing_and_plans');
      if (data != null && _processPricingDataFn != null) {
        _processPricingDataFn!(data);
        return true;
      }
    } catch (e) {
      debugPrint('refreshPricingFromCloud note: $e');
    }
    return false;
  }

  // =========================================================================
  // LOCAL REAL-TIME PLATFORM SYNC BRIDGE (Port 3000 Interoperability)
  // Syncs dynamically with Web Admin portal for plans, printers, coupons,
  // maintenance toggles, broadcasts, and hardware orders.
  // =========================================================================
  Timer? _bridgeSyncTimer;
  String _activeBridgeHost = '10.0.2.2';

  void _initBridgeSync() {
    // Developer-only plaintext HTTP bridge to the local admin portal. Never
    // active in release builds — avoids leaking credentials or state on-wire.
    if (kReleaseMode || kIsWeb) return;
    try {
      if (Platform.environment.containsKey('FLUTTER_TEST')) return;
    } catch (e) { debugPrint('Check FLUTTER_TEST env: $e'); }
    syncWithPlatformBridge();
    _bridgeSyncTimer?.cancel();
    _bridgeSyncTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      syncWithPlatformBridge();
    });
  }

  Future<void> syncWithPlatformBridge() async {
    if (kReleaseMode || kIsWeb) return;
    final hosts = ['10.0.2.2', '127.0.0.1', 'localhost'];
    for (final host in hosts) {
      try {
        final client = HttpClient()..connectionTimeout = const Duration(milliseconds: 1000);
        final request = await client.getUrl(Uri.parse('http://$host:3000/api/platform/public'));
        final response = await request.close().timeout(const Duration(milliseconds: 1500));
        if (response.statusCode == 200) {
          _activeBridgeHost = host;
          final body = await response.transform(utf8.decoder).join();
          final json = jsonDecode(body) as Map<String, dynamic>;
          client.close();
          if (json['success'] == true && json['data'] is Map<String, dynamic>) {
            _processBridgePlatformData(json['data'] as Map<String, dynamic>);
          }
          return;
        }
        client.close();
      } catch (e) { debugPrint('Platform bridge sync: $e'); }
    }
  }

  void _processBridgePlatformData(Map<String, dynamic> data) {
    bool hasChanges = false;
    if (data['subscriptionAddons'] is List) {
      _subscriptionAddons..clear()..addAll((data['subscriptionAddons'] as List).whereType<Map>().map((a) => SubscriptionAddonModel.fromMap(Map<String, dynamic>.from(a), a['id'].toString())));
      hasChanges = true;
    }

    // 1. Dynamic Plans & Pricing Sync
    if (data['plans'] is Map) {
      final pMap = Map<String, dynamic>.from(data['plans'] as Map);
      if (pMap['tiers'] is List) {
        final List<SubscriptionPlanModel> parsedPlans = [];
        for (final item in pMap['tiers'] as List) {
          if (item is Map) {
            parsedPlans.add(SubscriptionPlanModel.fromMap(Map<String, dynamic>.from(item), item['id']?.toString() ?? 'plan'));
          }
        }
        if (parsedPlans.isNotEmpty) {
          _subscriptionPlans.clear();
          _subscriptionPlans.addAll(parsedPlans);
          hasChanges = true;
        }
      }
      if (pMap['planGst'] is num) _planGstRate = (pMap['planGst'] as num).toDouble();
      if (pMap['printerGst'] is num) _printerGstRate = (pMap['printerGst'] as num).toDouble();
      if (pMap['printerPrice'] is num) _printerHardwarePrice = (pMap['printerPrice'] as num).toDouble();
    }

    // 2. Dynamic Printer Options Sync
    if (data['printerOptions'] is List) {
      final List<PrinterOptionModel> parsedPrinters = [];
      for (final item in data['printerOptions'] as List) {
        if (item is Map) {
          parsedPrinters.add(PrinterOptionModel.fromMap(Map<String, dynamic>.from(item), item['id']?.toString()));
        }
      }
      if (parsedPrinters.isNotEmpty) {
        _printerOptions.clear();
        _printerOptions.addAll(parsedPrinters);
        final def = defaultPrinterOption;
        _printerHardwarePrice = def.price;
        _printerGstRate = def.gstRate;
        hasChanges = true;
      }
    }

    // 3. Dynamic Promo Coupons Sync
    if (data['coupons'] is List) {
      final List<CouponModel> parsedCoupons = [];
      for (final item in data['coupons'] as List) {
        if (item is Map) {
          parsedCoupons.add(CouponModel.fromMap(Map<String, dynamic>.from(item)));
        }
      }
      if (parsedCoupons.isNotEmpty) {
        _coupons.clear();
        _coupons.addAll(parsedCoupons);
        hasChanges = true;
      }
    }

    // 4. Remote App Governance & Maintenance Mode
    if (data['remoteConfig'] is Map) {
      final rc = Map<String, dynamic>.from(data['remoteConfig'] as Map);
      if (rc['featureFlags'] is Map) {
        final rf = (rc['featureFlags'] as Map).map(
          (k, v) => MapEntry(k.toString(), v == true),
        );
        updateRemoteFeatureFlags(rf);
        hasChanges = true;
      }
      if (rc['maintenance'] is Map) {
        final m = Map<String, dynamic>.from(rc['maintenance'] as Map);
        final isActive = m['active'] == true;
        final msg = m['message']?.toString();
        final eta = m['eta']?.toString();
        if (_maintenanceMode != isActive ||
            (msg != null && _maintenanceMessage != msg) ||
            (eta != null && _maintenanceEta != eta)) {
          setMaintenanceDetails(
            isMaintenance: isActive,
            message: msg,
            eta: eta,
          );
          hasChanges = true;
        }
      }
      if (rc['minAppVersion'] != null) _minAppVersion = rc['minAppVersion'].toString();
      if (rc['smsProvider'] != null) _smsProvider = rc['smsProvider'].toString();
      if (rc['enforceOtp'] is bool) _enforceMobileOtp = rc['enforceOtp'] as bool;
      if (rc['smsMode'] != null) _smsGatewayMode = rc['smsMode'].toString();
      if (rc['otpDigits'] is num) _otpDigits = (rc['otpDigits'] as num).toInt();
    }
    if (data['settings'] is Map) {
      _applyPlanSettings(Map<String, dynamic>.from(data['settings'] as Map));
    }

    if (data['remoteFeatureFlags'] is Map) {
      final rf = (data['remoteFeatureFlags'] as Map).map(
        (k, v) => MapEntry(k.toString(), v == true),
      );
      updateRemoteFeatureFlags(rf);
      hasChanges = true;
    }

    // 5. In-App Emergency Broadcast Sync
    if (data['broadcast'] is Map) {
      final b = Map<String, dynamic>.from(data['broadcast'] as Map);
      if (b['active'] == true) {
        final targetTenant = b['targetTenant']?.toString() ?? 'all';
        final targetPlan = (b['targetPlan'] ?? b['targetRole'] ?? 'all').toString().toLowerCase();

        final tenantMatches = targetTenant == 'all' || targetTenant == currentTenantId || targetTenant == _tenant.tenantId;
        final currentPlan = ((_tenant.subscriptionPlanId != null && _tenant.subscriptionPlanId!.isNotEmpty)
                ? _tenant.subscriptionPlanId!
                : (_tenant.subscriptionStatus ?? ''))
            .toLowerCase();
        final planMatches = targetPlan == 'all' ||
            currentPlan.contains(targetPlan) ||
            ((targetPlan == 'expired' || targetPlan == 'freemium') && isSubscriptionExpired) ||
            (targetPlan == 'trial' && isTrial);

        if (tenantMatches && planMatches) {
          setEmergencyBroadcast(b);
        } else if (_emergencyBroadcast != null) {
          setEmergencyBroadcast(null);
        }
      } else if (_emergencyBroadcast != null) {
        setEmergencyBroadcast(null);
      }
    }

    // 6. Current Tenant Status Sync
    if (data['tenants'] is List) {
      for (final t in data['tenants'] as List) {
        if (t is Map) {
          final tMap = Map<String, dynamic>.from(t);
          final tid = tMap['id'] ?? tMap['tenantId'];
          if (tid == currentTenantId || tid == _tenant.tenantId) {
            final newSubStatus = tMap['subscriptionStatus']?.toString();
            final newPlanId = tMap['subscriptionPlanId']?.toString();
            if (newSubStatus != null && newSubStatus != _tenant.subscriptionStatus) {
              _tenant = _tenant.copyWith(
                subscriptionStatus: newSubStatus,
                subscriptionPlanId: newPlanId ?? _tenant.subscriptionPlanId,
              );
              hasChanges = true;
            }
          }
        }
      }
    }

    if (hasChanges) {
      notifyListeners();
    }
  }

  Future<void> postHardwareOrderToBridge(Map<String, dynamic> orderData) async {
    // Developer-only plaintext HTTP bridge. Disabled in release builds.
    if (kReleaseMode || kIsWeb) return;
    final hosts = {_activeBridgeHost, '10.0.2.2', '127.0.0.1', 'localhost'}.where((h) => h.trim().isNotEmpty).toList();
    for (final host in hosts) {
      try {
        final client = HttpClient()..connectionTimeout = const Duration(milliseconds: 600);
        final request = await client.postUrl(Uri.parse('http://$host:3000/api/platform/order-hardware'));
        request.headers.set('content-type', 'application/json');
        request.write(jsonEncode(orderData));
        final response = await request.close().timeout(const Duration(milliseconds: 1000));
        client.close();
        if (response.statusCode == 200) {
          debugPrint('Successfully posted hardware order to admin bridge at $host:3000');
          return;
        }
      } catch (e) { debugPrint('Post hardware order to bridge: $e'); }
    }
  }

  Future<void> syncTenantToServerBridge() async {
    // Developer-only plaintext HTTP bridge. Disabled in release builds.
    if (kReleaseMode || kIsWeb) return;
    final tid = currentTenantId ?? _tenant.tenantId;
    if (tid.isEmpty) return;

    final tenantData = {
      'id': tid,
      'tenantId': tid,
      'firmName': _tenant.firmName,
      'ownerName': _tenant.representativeName,
      'phone': _tenant.mobile,
      'email': _tenant.email,
      'city': _tenant.city ?? _tenant.territory ?? '',
      'state': _tenant.state ?? '',
      'pincode': _tenant.pincode ?? '',
      'gstin': _tenant.gstin,
      'pan': _tenant.pan,
      'warehouseAddress': _tenant.warehouseAddress,
      'subscriptionStatus': _tenant.subscriptionStatus,
      'planName': _tenant.subscriptionPlanId,
      'subscriptionPlanId': _tenant.subscriptionPlanId,
      'expiryDate': _tenant.subscriptionEndDate?.toIso8601String().split('T')[0],
      'isGstBillingEnabled': _isGstBillingEnabled,
    };

    final hosts = {_activeBridgeHost, '10.0.2.2', '127.0.0.1', 'localhost'}.where((h) => h.trim().isNotEmpty).toList();
    for (final host in hosts) {
      try {
        final client = HttpClient()..connectionTimeout = const Duration(milliseconds: 600);
        final request = await client.postUrl(Uri.parse('http://$host:3000/api/platform/sync-tenant'));
        request.headers.set('content-type', 'application/json');
        request.write(jsonEncode(tenantData));
        final response = await request.close().timeout(const Duration(milliseconds: 1000));
        client.close();
        if (response.statusCode == 200) {
          debugPrint('⚡ AppState: Synced tenant $tid to bridge server ($host:3000)');
          return;
        }
      } catch (e) { debugPrint('Sync tenant to bridge: $e'); }
    }
  }

  Future<void> syncOrderToServerBridge(OrderModel order) async {
    if (kReleaseMode || kIsWeb) return;
    final tid = currentTenantId ?? _tenant.tenantId;
    String matchedShopName = 'Retail Party';
    try {
      matchedShopName = _shops.firstWhere((s) => s.shopId == order.shopId).shopName;
    } catch (e) { debugPrint('Lookup shop name for order: $e'); }

    final orderMap = {
      'orderId': order.orderId,
      'id': order.orderId,
      'tenantId': tid,
      'shopId': order.shopId,
      'shopName': matchedShopName,
      'subtotal': order.subtotal,
      'totalGst': order.totalGst,
      'grandTotal': order.grandTotal,
      'total': order.grandTotal,
      'status': order.status,
      'placedAt': order.placedAt?.toIso8601String(),
      'deliveryNote': order.deliveryNote,
      'itemCount': order.items.length,
      'items': order.items.map((i) => i.toMap()).toList(),
    };

    final hosts = {_activeBridgeHost, '10.0.2.2', '127.0.0.1', 'localhost'}.where((h) => h.trim().isNotEmpty).toList();
    for (final host in hosts) {
      try {
        final client = HttpClient()..connectionTimeout = const Duration(milliseconds: 600);
        final request = await client.postUrl(Uri.parse('http://$host:3000/api/platform/sync-order'));
        request.headers.set('content-type', 'application/json');
        request.write(jsonEncode(orderMap));
        final response = await request.close().timeout(const Duration(milliseconds: 1000));
        client.close();
        if (response.statusCode == 200) {
          debugPrint('⚡ AppState: Synced order ${order.orderId} to bridge server ($host:3000)');
          return;
        }
      } catch (e) { debugPrint('Sync order to bridge: $e'); }
    }
  }

  Future<void> syncShopToServerBridge(ShopModel shop) async {
    if (kReleaseMode || kIsWeb) return;
    final tid = currentTenantId ?? _tenant.tenantId;
    final map = _shopToJson(shop);
    map['tenantId'] = tid;

    final hosts = {_activeBridgeHost, '10.0.2.2', '127.0.0.1', 'localhost'}.where((h) => h.trim().isNotEmpty).toList();
    for (final host in hosts) {
      try {
        final client = HttpClient()..connectionTimeout = const Duration(milliseconds: 600);
        final request = await client.postUrl(Uri.parse('http://$host:3000/api/platform/sync-shop'));
        request.headers.set('content-type', 'application/json');
        request.write(jsonEncode(map));
        final response = await request.close().timeout(const Duration(milliseconds: 1000));
        client.close();
        if (response.statusCode == 200) {
          debugPrint('⚡ AppState: Synced shop ${shop.shopId} to bridge server ($host:3000)');
          return;
        }
      } catch (e) { debugPrint('Sync shop to bridge: $e'); }
    }
  }

  Future<void> syncProductToServerBridge(ProductModel product) async {
    if (kReleaseMode || kIsWeb) return;
    final tid = currentTenantId ?? _tenant.tenantId;
    final map = _productToJson(product);
    map['tenantId'] = tid;

    final hosts = {_activeBridgeHost, '10.0.2.2', '127.0.0.1', 'localhost'}.where((h) => h.trim().isNotEmpty).toList();
    for (final host in hosts) {
      try {
        final client = HttpClient()..connectionTimeout = const Duration(milliseconds: 600);
        final request = await client.postUrl(Uri.parse('http://$host:3000/api/platform/sync-product'));
        request.headers.set('content-type', 'application/json');
        request.write(jsonEncode(map));
        final response = await request.close().timeout(const Duration(milliseconds: 1000));
        client.close();
        if (response.statusCode == 200) {
          debugPrint('⚡ AppState: Synced product ${product.productId} to bridge server ($host:3000)');
          return;
        }
      } catch (e) { debugPrint('Sync product to bridge: $e'); }
    }
  }

  Future<void> syncUserToServerBridge() async {
    if (kReleaseMode || kIsWeb) return;
    final uid = currentUid ?? 'admin_uid';
    final tid = currentTenantId ?? _tenant.tenantId;
    final userData = {
      'id': uid,
      'uid': uid,
      'name': _tenant.representativeName ?? 'Distributor Admin',
      'email': _tenant.email ?? 'admin@distributor.in',
      'phone': _tenant.mobile ?? '+91 9800000000',
      'role': activeRole,
      'tenantId': tid,
      'tenantName': _tenant.firmName ?? 'Distributor Agency',
      'status': _tenant.subscriptionStatus ?? 'active',
    };

    final hosts = {_activeBridgeHost, '10.0.2.2', '127.0.0.1', 'localhost'}.where((h) => h.trim().isNotEmpty).toList();
    for (final host in hosts) {
      try {
        final client = HttpClient()..connectionTimeout = const Duration(milliseconds: 600);
        final request = await client.postUrl(Uri.parse('http://$host:3000/api/platform/sync-user'));
        request.headers.set('content-type', 'application/json');
        request.write(jsonEncode(userData));
        final response = await request.close().timeout(const Duration(milliseconds: 1000));
        client.close();
        if (response.statusCode == 200) {
          debugPrint('⚡ AppState: Synced user $uid to bridge server ($host:3000)');
          return;
        }
      } catch (e) { debugPrint('Sync user to bridge: $e'); }
    }
  }

  dynamic _supabaseTenantChannel;

  /// Hardware (printer) orders this tenant has placed, as returned by
  /// Supabase. Populated by [_listenToPrinterHardwareOrders] which is
  /// invoked on tenant switch.
  final List<Map<String, dynamic>> _myPrinterOrders = [];
  List<Map<String, dynamic>> get myPrinterOrders =>
      List.unmodifiable(_myPrinterOrders);
  dynamic _supabasePrinterOrdersChannel;

  Future<void> _listenToPrinterHardwareOrders(String tenantId) async {
    if (tenantId.isEmpty) return;
    try {
      _supabasePrinterOrdersChannel?.unsubscribe();
    } catch (e) { debugPrint('Unsubscribe printer orders channel: $e'); }
    _supabasePrinterOrdersChannel = null;

    // Initial hydrate so UI has data before realtime fires.
    try {
      final rows = await SupabaseService.instance
          .fetchPrinterHardwareOrders(tenantId);
      _myPrinterOrders
        ..clear()
        ..addAll(rows);
      notifyListeners();
    } catch (e) { debugPrint('Fetch printer hardware orders: $e'); }

    _supabasePrinterOrdersChannel =
        SupabaseService.instance.listenToPrinterHardwareOrders(
      tenantId: tenantId,
      onChange: (row) {
        final id =
            (row['id'] ?? row['order_id'] ?? row['orderId'])?.toString();
        if (id == null) return;
        final idx = _myPrinterOrders.indexWhere((o) =>
            (o['id'] ?? o['order_id'] ?? o['orderId'])?.toString() == id);
        if (idx >= 0) {
          _myPrinterOrders[idx] = row;
        } else {
          _myPrinterOrders.insert(0, row);
        }
        notifyListeners();
      },
    );
  }

  void _listenToTenant(String tenantId) {
    if (tenantId.isEmpty) return;

    // 1. Supabase Real-Time Tenant Listener (Immediate Web Admin SaaS Sync)
    try {
      _supabaseTenantChannel?.unsubscribe();
      _supabaseTenantChannel = SupabaseService.instance.listenToTenant(
        tenantId: tenantId,
        onUpdate: (data) {
          debugPrint('⚡ Supabase Real-Time Tenant update received: $data');
          final incoming = TenantModel.fromMap(data, tenantId);
          _tenant = incoming.copyWith(
            upiId: (incoming.upiId != null && incoming.upiId!.isNotEmpty) ? incoming.upiId : _tenant.upiId,
            paymentGatewayConfig: (incoming.paymentGatewayConfig != null && incoming.paymentGatewayConfig!.isNotEmpty)
                ? incoming.paymentGatewayConfig
                : _tenant.paymentGatewayConfig,
            hardwareConfig: incoming.hardwareConfig ?? _tenant.hardwareConfig,
            bankAccount: incoming.bankAccount ?? _tenant.bankAccount,
            profileImageUrl: (incoming.profileImageUrl != null && incoming.profileImageUrl!.isNotEmpty)
                ? incoming.profileImageUrl
                : _tenant.profileImageUrl,
            logoUrl: (incoming.logoUrl != null && incoming.logoUrl!.isNotEmpty)
                ? incoming.logoUrl
                : _tenant.logoUrl,
          );
          _isGstBillingEnabled = _tenant.isGstBillingEnabled ?? true;
          _persistTenantLocally(_tenant);
          if (kDebugMode) {
            debugPrint('AppState: tenant realtime update applied.');
          }
          notifyListeners();
        },
      );
    } catch (e) {
      debugPrint('Supabase listenToTenant notice: $e');
    }

    // 2. Firestore Fallback Listener
    // Firestore sync removed; Supabase path above is authoritative.
}

  void _listenToTenantSubcollections(String tenantId) {
    // Firestore sync removed; Supabase path above is authoritative.
}

  void _cancelSubcollectionSubscriptions() {
    _shopsSubscription?.cancel();
    _shopsSubscription = null;
    _productsSubscription?.cancel();
    _productsSubscription = null;
    _ordersSubscription?.cancel();
    _ordersSubscription = null;
    _invoicesSubscription?.cancel();
    _invoicesSubscription = null;
    _paymentsSubscription?.cancel();
    _paymentsSubscription = null;
    _visitsSubscription?.cancel();
    _visitsSubscription = null;
    _remindersSubscription?.cancel();
    _remindersSubscription = null;
    _ledgerSubscription?.cancel();
    _ledgerSubscription = null;
    _staffSubscription?.cancel();
    _staffSubscription = null;
    _notificationsSubscription?.cancel();
    _notificationsSubscription = null;
  }

  /// Enterprise Session Management: Cleans up listeners, resets active role & staff,
  /// and restores a sanitized baseline upon user logout.
  void signOutSession() {
    _productCategories.clear();
    _productUnits.clear();
    _tenantSubscription?.cancel();
    _tenantSubscription = null;
    try {
      _supabaseTenantChannel?.unsubscribe();
      _supabaseTenantChannel = null;
    } catch (e) { debugPrint('Unsubscribe tenant channel on sign-out: $e'); }
    // Also kill the top-level (non-subcollection) listeners so a new login
    // doesn't stack a second generation of them on top of the old one.
    _pricingSubscription?.cancel();
    _pricingSubscription = null;
    _pricingCamelSubscription?.cancel();
    _pricingCamelSubscription = null;
    _platformSubscription?.cancel();
    _platformSubscription = null;
    _platformCamelSubscription?.cancel();
    _platformCamelSubscription = null;
    _remoteConfigSubscription?.cancel();
    _remoteConfigSubscription = null;
    _remoteConfigCamelSubscription?.cancel();
    _remoteConfigCamelSubscription = null;
    _broadcastSubscription?.cancel();
    _broadcastSubscription = null;
    _broadcastCamelSubscription?.cancel();
    _broadcastCamelSubscription = null;
    _bridgeSyncTimer?.cancel();
    _bridgeSyncTimer = null;
    _cancelSubcollectionSubscriptions();
    _isSuperAdminMode = false;
    currentUserRole = null;
    _activeStaffUser = null;
    currentTenantId = null;
    currentUid = null;
    _tenant = TenantModel.empty();
    _shops.clear();
    _products.clear();
    _orders.clear();
    _invoices.clear();
    _payments.clear();
    _ledgerEntries.clear();
    _visits.clear();
    _reminders.clear();
    _staffList.clear();
    _purchases.clear();
    _expenses.clear();
    _salesReturns.clear();
    _notifications.clear();
    _clearSessionLocally();
    notifyListeners();
  }

  Future<void> _clearSessionLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('salesarmy_session_logged_in_v1', false);
      await prefs.remove('salesarmy_session_role_v1');
      await prefs.remove('salesarmy_session_is_admin_v1');
      await prefs.remove('salesarmy_session_tenant_id_v1');
      await prefs.remove('salesarmy_session_uid_v1');
    } catch (e) { debugPrint('Clear session prefs on sign-out: $e'); }
  }

  void toggleSuperAdminMode(bool enable) {
    if (enable && !isSuperAdminUser) {
      debugPrint('Security Warning: Unauthorized attempt to enable Super Admin Console by role: $currentUserRole');
      throw StateError('Unauthorized: Only Super Admin users can enter Super Admin Console.');
    }
    _isSuperAdminMode = enable;
    notifyListeners();
  }

  void initForTenant(String tenantId, String uid, {TenantModel? loadedTenant, String? role}) {
    // Hard guard against empty IDs. A blank tenantId used to resolve to the
    // demo tenant through various fallbacks and leaked data across workspaces.
    // Now: if the caller can't supply a real tenant/uid, we refuse to init
    // and sign the user out so RLS cannot be bypassed accidentally.
    if (tenantId.trim().isEmpty || uid.trim().isEmpty) {
      debugPrint('⚠️ initForTenant refused: tenantId or uid is empty. Session aborted.');
      signOutSession();
      return;
    }
    // Cancel any realtime listeners from the previous session so a rapid
    // tenant switch does not stack a second generation of Firestore / Supabase
    // subscribers on top of the previous one (double writes + leaked streams).
    _tenantSubscription?.cancel();
    _tenantSubscription = null;
    try {
      _supabaseTenantChannel?.unsubscribe();
    } catch (e) { debugPrint('Unsubscribe tenant channel on switch: $e'); }
    _supabaseTenantChannel = null;
    try {
      _supabasePrinterOrdersChannel?.unsubscribe();
    } catch (e) { debugPrint('Unsubscribe printer orders on switch: $e'); }
    _supabasePrinterOrdersChannel = null;
    _cancelSubcollectionSubscriptions();

    currentTenantId = tenantId;
    currentUid = uid;
    if (role != null) {
      currentUserRole = role;
    }
    if (loadedTenant != null) {
      _tenant = loadedTenant.copyWith(
        upiId: (loadedTenant.upiId != null && loadedTenant.upiId!.isNotEmpty) ? loadedTenant.upiId : _tenant.upiId,
        paymentGatewayConfig: (loadedTenant.paymentGatewayConfig != null && loadedTenant.paymentGatewayConfig!.isNotEmpty)
            ? loadedTenant.paymentGatewayConfig
            : _tenant.paymentGatewayConfig,
        hardwareConfig: loadedTenant.hardwareConfig ?? _tenant.hardwareConfig,
        bankAccount: loadedTenant.bankAccount ?? _tenant.bankAccount,
        profileImageUrl: (loadedTenant.profileImageUrl != null && loadedTenant.profileImageUrl!.isNotEmpty)
            ? loadedTenant.profileImageUrl
            : _tenant.profileImageUrl,
        logoUrl: (loadedTenant.logoUrl != null && loadedTenant.logoUrl!.isNotEmpty)
            ? loadedTenant.logoUrl
            : _tenant.logoUrl,
      );
      _persistTenantLocally(_tenant);
    }
    // Tenant switch: wipe in-memory lists so the previous tenant's data
    // doesn't bleed into this tenant. Then hydrate from SharedPreferences
    // under THIS tenant's key. NO mock seeding on either path — new signups
    // land in a truly empty workspace (zero shops, products, orders, bills,
    // etc.). Mock data is only ever loaded when AppState(loadMockData: true)
    // is explicitly constructed, which only test harnesses do.
    final previousTenantId = _tenant.tenantId;
    final tenantChanged = previousTenantId.isNotEmpty && previousTenantId != tenantId;
    if (tenantChanged) {
      _shops.clear();
      _products.clear();
      _orders.clear();
      _invoices.clear();
      _payments.clear();
      _ledgerEntries.clear();
      _visits.clear();
      _reminders.clear();
      _staffList.clear();
      _purchases.clear();
      _expenses.clear();
      _salesReturns.clear();
      _notifications.clear();
    }

    _loadAllLocalData().then((_) {
      notifyListeners();
    });

    _initRepositories(tenantId);
    _listenToTenant(tenantId);
    _listenToTenantSubcollections(tenantId);
    _listenToPrinterHardwareOrders(tenantId);
    _loadCatalogLists();
    // A Razorpay payment finished while the app was closed still activates.
    reconcilePendingCheckout();
    // Anti-Data-Loss Multi-Device Hydration: Immediately trigger full fetch from central cloud database
    syncAllFromCloud();
    notifyListeners();
  }

  Future<void> syncAllFromCloud() async {
    final tenantId = currentTenantId ?? _tenant.tenantId;
    if (tenantId.isEmpty) return;

    Object? syncError;
    _isCloudSyncing = true;
    notifyListeners();
    try {
      // 1. Supabase Cloud Sync (PostgreSQL tables)
      final sb = SupabaseService.instance;
      if (sb.client != null) {
        try {
          // 0. Fetch latest Tenant details & Subscription from Supabase public.tenants
          final tenantData = await sb.fetchTenant(tenantId);
          if (tenantData != null) {
            final cloudTenant = TenantModel.fromMap(tenantData, tenantId);

            // Fetch durable JSON config if available
            Map<String, dynamic>? durableSettings;
            try {
              durableSettings = await sb.fetchPlatformSettings('tenant_profile_$tenantId');
            } catch (e) { debugPrint('Fetch durable platform settings: $e'); }

            final preservedUpiId = (cloudTenant.upiId != null && cloudTenant.upiId!.isNotEmpty)
                ? cloudTenant.upiId
                : (durableSettings?['upiId']?.toString().isNotEmpty == true
                    ? durableSettings!['upiId'].toString()
                    : _tenant.upiId);

            final preservedGwConfig = (cloudTenant.paymentGatewayConfig != null && cloudTenant.paymentGatewayConfig!.isNotEmpty)
                ? cloudTenant.paymentGatewayConfig
                : (durableSettings?['paymentGatewayConfig'] is Map
                    ? Map<String, dynamic>.from(durableSettings!['paymentGatewayConfig'] as Map)
                    : _tenant.paymentGatewayConfig);

            final preservedHardware = cloudTenant.hardwareConfig ??
                (durableSettings?['hardwareConfig'] is Map
                    ? Map<String, dynamic>.from(durableSettings!['hardwareConfig'] as Map)
                    : _tenant.hardwareConfig);

            final preservedBank = cloudTenant.bankAccount ??
                (durableSettings?['bankAccount'] is Map
                    ? Map<String, dynamic>.from(durableSettings!['bankAccount'] as Map)
                    : _tenant.bankAccount);

            final preservedProfileImage = (cloudTenant.profileImageUrl != null && cloudTenant.profileImageUrl!.isNotEmpty)
                ? cloudTenant.profileImageUrl
                : (durableSettings?['profileImageUrl']?.toString().isNotEmpty == true
                    ? durableSettings!['profileImageUrl'].toString()
                    : _tenant.profileImageUrl);

            final preservedLogo = (cloudTenant.logoUrl != null && cloudTenant.logoUrl!.isNotEmpty)
                ? cloudTenant.logoUrl
                : (durableSettings?['logoUrl']?.toString().isNotEmpty == true
                    ? durableSettings!['logoUrl'].toString()
                    : _tenant.logoUrl);

            _tenant = cloudTenant.copyWith(
              upiId: preservedUpiId,
              paymentGatewayConfig: preservedGwConfig,
              hardwareConfig: preservedHardware,
              bankAccount: preservedBank,
              profileImageUrl: preservedProfileImage,
              logoUrl: preservedLogo,
            );

            _isGstBillingEnabled = _tenant.isGstBillingEnabled ?? true;
            await _persistTenantLocally(_tenant);
            if (kDebugMode) {
              debugPrint('AppState: tenant hydrated from Supabase.');
            }
          }

          // Hydrate user profile if currentUid is present
          if (currentUid != null && currentUid!.isNotEmpty) {
            final profileData = await sb.fetchUserProfile(currentUid!);
            if (profileData != null) {
              if (profileData['name'] != null && profileData['name'].toString().isNotEmpty) {
                _tenant = _tenant.copyWith(representativeName: profileData['name'].toString());
              }
              if (profileData['photo_url'] != null && profileData['photo_url'].toString().trim().isNotEmpty) {
                final photo = profileData['photo_url'].toString().trim();
                _tenant = _tenant.copyWith(profileImageUrl: photo);
              }
              if (profileData['role'] != null) {
                final r = profileData['role'].toString();
                currentUserRole = r;
                setActiveRole(r);
              }
            }
          }

          final shopsData = await sb.fetchShops(tenantId);
          if (shopsData.isNotEmpty) {
            final loadedShops = shopsData.map((m) => ShopModel.fromMap(m, m['shop_id']?.toString() ?? '')).toList();
            _shops.clear();
            _shops.addAll(loadedShops);
            _shopRepository?.replaceWith(loadedShops);
            await _persistShopsLocally();
          }
          // Previously: fell back to _seedMockData() if cloud shops empty.
          // Removed — empty cloud now means empty on mobile too.

          final prodsData = await sb.fetchProducts(tenantId);
          if (prodsData.isNotEmpty) {
            final loadedProds = prodsData.map((m) => ProductModel.fromMap(m, m['product_id']?.toString() ?? '')).toList();
            _products.clear();
            _products.addAll(loadedProds);
            _productRepository?.replaceWith(loadedProds);
            await _persistProductsLocally();
          }
          // Same note as shops above — no demo-product fallback for new tenants.

          final ordersData = await sb.fetchOrders(tenantId);
          if (ordersData.isNotEmpty) {
            final loadedOrders = ordersData.map((m) => OrderModel.fromMap(m, m['order_id']?.toString() ?? '')).toList();
            _orders.clear();
            _orders.addAll(loadedOrders);
            _orderRepository?.replaceWith(loadedOrders);
            await _persistOrdersLocally();
          }

          final invsData = await sb.fetchInvoices(tenantId);
          if (invsData.isNotEmpty) {
            final loadedInvoices = invsData.map((m) => InvoiceModel.fromMap(m, m['invoice_id']?.toString() ?? '')).toList();
            _invoices.clear();
            _invoices.addAll(loadedInvoices);
            await _persistInvoicesLocally();
          }

          final paymentsData = await sb.fetchPayments(tenantId);
          if (paymentsData.isNotEmpty) {
            final loadedPayments = paymentsData.map((m) => PaymentModel.fromMap(m, m['payment_id']?.toString() ?? '')).toList();
            _payments.clear();
            _payments.addAll(loadedPayments);
            await _persistPaymentsLocally();
          }

          final ledgerData = await sb.fetchLedgerEntries(tenantId);
          if (ledgerData.isNotEmpty) {
            final loadedLedger = ledgerData.map((m) => LedgerEntryModel.fromMap(m, m['entry_id']?.toString() ?? '')).toList();
            _ledgerEntries.clear();
            _ledgerEntries.addAll(loadedLedger);
            await _persistLedgerLocally();
          }

          final visitsData = await sb.fetchVisits(tenantId);
          if (visitsData.isNotEmpty) {
            final loadedVisits = visitsData.map((m) => VisitModel.fromMap(m, m['visit_id']?.toString() ?? '')).toList();
            _visits.clear();
            _visits.addAll(loadedVisits);
            await _persistVisitsLocally();
          }

          final expData = await sb.fetchExpenses(tenantId);
          if (expData.isNotEmpty) {
            final loaded = expData.map((m) => ExpenseModel.fromMap(m, m['expense_id']?.toString() ?? '')).toList();
            _expenses.clear();
            _expenses.addAll(loaded);
            await _persistExpensesLocally();
          }

          final purData = await sb.fetchPurchases(tenantId);
          if (purData.isNotEmpty) {
            final loaded = purData.map((m) => PurchaseModel.fromMap(m, m['purchase_id']?.toString() ?? '')).toList();
            _purchases.clear();
            _purchases.addAll(loaded);
            await _persistPurchasesLocally();
          }

          final remData = await sb.fetchReminders(tenantId);
          if (remData.isNotEmpty) {
            final loaded = remData.map((m) => ReminderModel.fromMap(m, m['reminder_id']?.toString() ?? '')).toList();
            _reminders.clear();
            _reminders.addAll(loaded);
            await _persistRemindersLocally();
          }
        } catch (e) {
          debugPrint('Supabase cloud fetch note: $e');
          syncError = e;
        }
      }

      // 2. Firebase Firestore Central Sync (if initialized)

      // Flush any pending mutations
      await flushOutbox();

      debugPrint('Cloud-First Sync Complete: All data fetched from central database for tenant $tenantId');
    } catch (e) {
      debugPrint('Cloud-First Sync notice: $e');
      syncError ??= e;
    } finally {
      _isCloudSyncing = false;
      _cloudSyncError = syncError == null ? null : AppError.message(syncError, action: 'refresh your data from the cloud');
      notifyListeners();
    }
  }

  // ── Cloud sync status (shown on Home with a Retry button) ──
  bool _isCloudSyncing = false;
  bool get isCloudSyncing => _isCloudSyncing;
  String? _cloudSyncError;
  /// Readable message when the last cloud refresh failed; null when it worked.
  String? get cloudSyncError => _cloudSyncError;
  void dismissCloudSyncError() {
    _cloudSyncError = null;
    notifyListeners();
  }

  Future<void> syncWithCloudNow() async {
    await syncAllFromCloud();
    await flushOutbox();
    notifyListeners();
  }

  void _initRepositories(String tenantId) {
    _shopRepository = ShopRepositoryImpl(tenantId: tenantId)..seedInitial(_shops);
    _orderRepository = OrderRepositoryImpl(tenantId: tenantId)..seedInitial(_orders);
    _productRepository = ProductRepositoryImpl(tenantId: tenantId)..seedInitial(_products);
    _syncRepository = SyncRepositoryImpl(tenantId: tenantId, outboxManager: _outboxManager);
  }

  // Enterprise Pagination & Delta Sync Methods
  Future<void> loadMoreOrders() async {
    if (_orderRepository == null || _orders.isEmpty) return;
    final lastId = _orders.last.orderId;
    final nextOrders = await _orderRepository!.getOrdersPaginated(limit: 50, startAfterId: lastId);
    if (nextOrders.isNotEmpty) {
      for (final o in nextOrders) {
        if (!_orders.any((existing) => existing.orderId == o.orderId)) {
          _orders.add(OrderModel(
            orderId: o.orderId,
            shopId: o.shopId,
            createdByUid: o.createdByUid,
            status: o.status,
            items: o.items.map((i) => TransactionItemSnapshot(
              productId: i.productId,
              productName: i.productName,
              quantity: i.quantity,
              unitPrice: i.unitPrice,
              gstRate: i.gstRate,
              itemSubtotal: i.itemSubtotal,
              itemGst: i.itemGst,
              itemGrandTotal: i.itemGrandTotal,
            )).toList(),
            subtotal: o.subtotal,
            totalGst: o.totalGst,
            grandTotal: o.grandTotal,
            deliveryNote: o.deliveryNote,
            placedAt: o.placedAt,
            deliveredAt: o.deliveredAt,
            createdAt: o.createdAt,
            updatedAt: o.updatedAt,
          ));
        }
      }
      notifyListeners();
    }
  }

  Future<void> loadMoreShops() async {
    if (_shopRepository == null || _shops.isEmpty) return;
    final lastId = _shops.last.shopId;
    final nextShops = await _shopRepository!.getShopsPaginated(limit: 50, startAfterId: lastId);
    if (nextShops.isNotEmpty) {
      for (final s in nextShops) {
        if (!_shops.any((existing) => existing.shopId == s.shopId)) {
          _shops.add(ShopModel(
            shopId: s.shopId,
            shopName: s.shopName,
            ownerName: s.ownerName,
            phone: s.phone,
            whatsappNumber: s.whatsappNumber,
            businessType: s.businessType,
            categoryId: s.categoryId,
            gstin: s.gstin,
            address: s.address,
            visitFrequency: s.visitFrequency,
            creditLimit: s.creditLimit,
            currentOutstanding: s.currentOutstanding,
            latitude: s.latitude,
            longitude: s.longitude,
            notes: s.notes,
            isActive: s.isActive,
            createdAt: s.createdAt,
            updatedAt: s.updatedAt,
            createdByUid: s.createdByUid,
            updatedByUid: s.updatedByUid,
          ));
        }
      }
      notifyListeners();
    }
  }

  Future<void> triggerDeltaSync() async {
    if (_syncRepository != null) {
      await _syncRepository!.flushOutbox();
      await _syncRepository!.pullDeltas('orders');
      await _syncRepository!.pullDeltas('shops');
      await _syncRepository!.pullDeltas('products');
    }
  }

  // ==========================================================================
  // PLANS & ENTITLEMENTS — single source of truth
  //
  //   plan (admin catalog)  -> which capabilities + limits
  //   tenant status / dates -> trial, active, expired (read-only), suspended
  //   remote kill switches  -> platform-wide off switch (isModuleRemotelyDisabled)
  //   staff permissions     -> per-user RBAC (canAccessModule)
  //
  // The database enforces the same rules (enforce_plan_entitlements trigger),
  // so a modified client cannot bypass them.
  // ==========================================================================

  // Signup trial rules from Web Admin → Settings (general_settings).
  String _signupPlanId = 'startup';
  int _signupTrialDays = 14;
  int _trialGraceDays = 3;
  String get signupPlanId => _signupPlanId;
  int get signupTrialDays => _signupTrialDays;
  int get trialGraceDays => _trialGraceDays;

  void _applyPlanSettings(Map<String, dynamic> data) {
    final plan = data['defaultPlanId']?.toString();
    if (plan != null && plan.isNotEmpty && plan != 'free') _signupPlanId = plan;
    final days = (data['defaultTrialDays'] as num?)?.toInt();
    if (days != null && days > 0) _signupTrialDays = days;
    final grace = (data['trialGracePeriodDays'] as num?)?.toInt();
    if (grace != null && grace >= 0) _trialGraceDays = grace;
  }

  @visibleForTesting
  void applyPlanSettingsForTest(Map<String, dynamic> data) {
    _applyPlanSettings(data);
    notifyListeners();
  }

  @visibleForTesting
  void setSubscriptionPlansForTest(List<SubscriptionPlanModel> plans) {
    _subscriptionPlans
      ..clear()
      ..addAll(plans);
    notifyListeners();
  }

  static const Map<String, String> _legacyPlanIds = {
    'silver': 'startup', 'starter': 'startup', 'basic': 'startup',
    'gold': 'grow', 'growth': 'grow', 'pro': 'grow',
    'platinum': 'enterprise', 'annual_pro': 'enterprise',
  };

  /// Plan with this id from the admin catalog (case-insensitive, legacy aliases).
  SubscriptionPlanModel? planById(String? planId) {
    final raw = (planId ?? '').trim().toLowerCase();
    if (raw.isEmpty) return null;
    for (final id in [raw, _legacyPlanIds[raw]]) {
      if (id == null) continue;
      for (final p in _subscriptionPlans) {
        if (p.id.toLowerCase() == id) return p;
      }
    }
    return null;
  }

  /// The plan this agency is on. Falls back to the signup trial plan, then the
  /// first plan, if the tenant row names a plan the admin has removed.
  SubscriptionPlanModel get currentPlan =>
      planById(_tenant.subscriptionPlanId) ??
      planById(_signupPlanId) ??
      (_subscriptionPlans.isNotEmpty ? _subscriptionPlans.first : SubscriptionPlanModel.defaultPlans.first);

  bool get _isPlatformAdmin => isSuperAdminUser || isSuperAdminMode;

  /// True if the current plan includes [featureKey] (ignores expiry). Use this
  /// to decide what to SHOW; use [hasFeature] / [writeBlockReason] to decide
  /// what may be DONE.
  bool planIncludes(String featureKey) {
    if (_isPlatformAdmin) return true;
    final key = canonicalFeature(featureKey);
    return currentPlan.allowedFeatures.contains(key);
  }

  /// Capabilities that stay usable while the agency is read-only (expired):
  /// viewing / exporting data and collecting money already owed.
  static const Set<String> readOnlyFeatures = {
    'collections', 'khata_ledger', 'reports', 'gst_reports', 'thermal_printer', 'offline_sync', 'dynamic_upi_qr',
  };

  /// True if the agency may use [featureKey] right now (plan + status).
  bool hasFeature(String featureKey) {
    if (_isPlatformAdmin) return true;
    if (isAccountPausedOrCancelled) return false;
    final key = canonicalFeature(featureKey);
    if (!currentPlan.isActive && !isReadOnlyMode) return false;
    if (!currentPlan.allowedFeatures.contains(key)) return false;
    if (isReadOnlyMode) return readOnlyFeatures.contains(key);
    return true;
  }

  /// List of all capability keys the current plan unlocks (for display).
  List<String> get currentAllowedFeatures => List.unmodifiable(currentPlan.allowedFeatures);

  bool get isTrial => (_tenant.subscriptionStatus ?? '').toLowerCase() == 'trial';

  /// When access actually stops: the end date, plus grace days for trials.
  DateTime? get accessEndsAt {
    final end = _tenant.subscriptionEndDate;
    if (end == null) return null;
    return isTrial ? end.add(Duration(days: _trialGraceDays)) : end;
  }

  int get remainingTrialDays {
    if (_tenant.subscriptionEndDate == null) return 0;
    final diff = _tenant.subscriptionEndDate!.difference(DateTime.now()).inDays;
    return diff > 0 ? diff : 0;
  }

  /// Days until the active subscription or trial ends. Negative if already
  /// expired; `null` if there's no end date on file.
  int? get daysUntilSubscriptionEnds {
    if (_tenant.subscriptionEndDate == null) return null;
    return _tenant.subscriptionEndDate!.difference(DateTime.now()).inDays;
  }

  /// Trial end date has passed but the grace period is still running.
  bool get isInTrialGracePeriod {
    final end = _tenant.subscriptionEndDate;
    final access = accessEndsAt;
    if (!isTrial || end == null || access == null) return false;
    final now = DateTime.now();
    return now.isAfter(end) && !now.isAfter(access);
  }

  /// Days of grace left (0 when not in grace).
  int get trialGraceDaysLeft {
    if (!isInTrialGracePeriod) return 0;
    final left = accessEndsAt!.difference(DateTime.now()).inDays;
    return left < 0 ? 0 : left;
  }

  /// True when the current trial OR paid plan will lapse within 5 days.
  /// Drives the amber "subscription expiring soon" nudge on the dashboard.
  bool get isSubscriptionExpiringSoon {
    final days = daysUntilSubscriptionEnds;
    if (days == null) return false;
    if (days < 0) return false; // already expired — different alert fires
    if (isAccountPausedOrCancelled) return false;
    final status = (_tenant.subscriptionStatus ?? '').toLowerCase();
    if (status != 'active' && status != 'trial') return false;
    return days <= 5;
  }

  /// Alias for the trial-specific countdown — useful for banners that only
  /// want to pester trial users (not paying customers nearing renewal).
  bool get isTrialExpiringSoon => isTrial && isSubscriptionExpiringSoon;

  // Plan limits. 0 = unlimited (see SubscriptionPlanModel.isUnlimited).
  int get maxAllowedProducts => currentPlan.maxProducts;
  int get maxAllowedUsers => currentPlan.maxStaff;
  int get maxAllowedShops => currentPlan.maxShops;
  int get maxAllowedOrdersPerMonth => currentPlan.maxOrdersPerMonth;

  int get ordersThisMonth {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month);
    return _orders.where((o) {
      final at = o.placedAt ?? o.createdAt;
      return at != null && !at.isBefore(monthStart) && o.status.toLowerCase() != 'cancelled';
    }).length;
  }

  bool get isSubscriptionActive {
    final accStatus = _tenant.accountStatus?.toLowerCase() ?? 'active';
    if (accStatus != 'active') return false;
    if (isAccountPausedOrCancelled || isSubscriptionExpired) return false;
    final status = _tenant.subscriptionStatus?.toLowerCase() ?? 'trial';
    return status == 'active' || status == 'trial';
  }

  /// The plan / trial has ended (after any trial grace days).
  bool get isSubscriptionExpired {
    final status = (_tenant.subscriptionStatus ?? '').toLowerCase();
    // 'free' / 'freemium' only exist on stale local data: treat as ended.
    if (status == 'expired' || status == 'free' || status == 'freemium') return true;
    final access = accessEndsAt;
    return access != null && DateTime.now().isAfter(access);
  }

  /// Expired agencies can sign in, view data, collect dues and renew — but
  /// cannot create anything new.
  bool get isReadOnlyMode => !_isPlatformAdmin && !isAccountPausedOrCancelled && isSubscriptionExpired;

  bool get isAccountPausedOrCancelled {
    final accStatus = _tenant.accountStatus?.toLowerCase();
    final subStatus = _tenant.subscriptionStatus?.toLowerCase();
    return accStatus == 'paused' || accStatus == 'cancelled' || accStatus == 'suspended' ||
           subStatus == 'paused' || subStatus == 'cancelled' || subStatus == 'suspended';
  }

  String get subscriptionBadgeText {
    if (isAccountPausedOrCancelled) {
      final acc = (_tenant.accountStatus ?? '').toUpperCase();
      if (acc == 'CANCELLED' || (_tenant.subscriptionStatus ?? '').toUpperCase() == 'CANCELLED') return 'ACCOUNT CANCELLED';
      return 'ACCOUNT PAUSED';
    }
    if (_tenant.accountStatus?.toUpperCase() == 'PENDING') return 'ACCOUNT PENDING';
    if (isSubscriptionExpired) return isTrial ? 'TRIAL ENDED · READ-ONLY' : 'PLAN EXPIRED · READ-ONLY';
    if (isInTrialGracePeriod) return 'TRIAL ENDED (${trialGraceDaysLeft}d GRACE)';
    if (isTrial) return 'TRIAL ACTIVE (${remainingTrialDays}d)';
    return 'ACCOUNT ACTIVE';
  }

  /// Why creating something is blocked right now, or null if it is allowed.
  /// [feature] is a capability key (see FeatureGate.capabilityLabels).
  String? writeBlockReason({String? feature}) {
    if (_isPlatformAdmin) return null;
    if (isAccountPausedOrCancelled) {
      return 'Your agency account is paused or suspended. Please contact SalesArmy support to reactivate it.';
    }
    if (isReadOnlyMode) {
      return isTrial
          ? 'Your free trial has ended. The app is read-only — choose a plan in Plan & Pricing to continue.'
          : 'Your ${currentPlan.name} plan has expired. The app is read-only — renew in Plan & Pricing to continue.';
    }
    if (feature != null && !planIncludes(feature)) {
      return '${planFeatureLabel(feature)} is not included in your ${currentPlan.name} plan. Upgrade in Plan & Pricing to use it.';
    }
    return null;
  }

  /// Throws [PlanRestrictionException] when [feature] may not be used now.
  void ensureCanWrite({String? feature}) {
    final reason = writeBlockReason(feature: feature);
    if (reason != null) throw PlanRestrictionException(reason, feature: feature, readOnly: isReadOnlyMode);
  }

  /// Human label for a capability key (kept in sync with FeatureGate).
  static String planFeatureLabel(String key) {
    const labels = {
      'order_taking': 'Order taking',
      'estimate_bills': 'Kaccha / estimate billing',
      'invoicing': 'GST tax invoicing',
      'sales_returns': 'Sales returns',
      'collections': 'Payment collection',
      'khata_ledger': 'Khata ledger',
      'dynamic_upi_qr': 'Dynamic UPI QR',
      'purchases': 'Purchases',
      'expenses': 'Expense tracking',
      'visits': 'Visits & reminders',
      'staff_management': 'Staff logins',
      'thermal_printer': 'Thermal printing',
      'reports': 'Reports',
      'gst_reports': 'GST reports',
      'custom_tax_slabs': 'Custom tax slabs',
      'bulk_import': 'Bulk import',
    };
    final k = canonicalFeature(key);
    return labels[k] ?? k.replaceAll('_', ' ');
  }

  /// Why adding one more [resource] ('shops' | 'products' | 'staff' |
  /// 'orders') would exceed the plan, or null if there is room.
  String? limitReason(String resource) {
    if (_isPlatformAdmin) return null;
    late final int used;
    late final int limit;
    late final String what;
    switch (resource) {
      case 'shops':
        used = _shops.length;
        limit = maxAllowedShops;
        what = 'parties';
        break;
      case 'products':
        used = _products.length;
        limit = maxAllowedProducts;
        what = 'products';
        break;
      case 'staff':
        used = _staffList.length;
        limit = maxAllowedUsers;
        what = 'staff logins';
        break;
      case 'orders':
        used = ordersThisMonth;
        limit = maxAllowedOrdersPerMonth;
        what = 'orders this month';
        break;
      default:
        return null;
    }
    if (SubscriptionPlanModel.isUnlimited(limit) || used < limit) return null;
    return 'Your ${currentPlan.name} plan allows $limit $what and you have reached it. Upgrade in Plan & Pricing to add more.';
  }

  void _ensureUnderLimit({required int used, required int limit, required String message}) {
    if (_isPlatformAdmin || SubscriptionPlanModel.isUnlimited(limit)) return;
    if (used >= limit) throw PlanRestrictionException(message, limitReached: true);
  }

  // Getters
  List<ShopModel> get shops => List.unmodifiable(_shops);
  List<ProductModel> get products => List.unmodifiable(_products);
  List<OrderModel> get orders => List.unmodifiable(_orders);
  List<InvoiceModel> get invoices => List.unmodifiable(_invoices);
  List<PaymentModel> get payments => List.unmodifiable(_payments);
  List<LedgerEntryModel> get ledgerEntries => List.unmodifiable(_ledgerEntries);
  List<VisitModel> get visits => List.unmodifiable(_visits);
  List<ReminderModel> get reminders => List.unmodifiable(_reminders);
  List<StaffModel> get staffList => List.unmodifiable(_staffList);
  StaffModel? get activeStaffUser => _activeStaffUser;
  String get activeRole => _activeStaffUser?.role ?? currentUserRole ?? 'Owner';
  StaffPermissions get activePermissions => _activeStaffUser?.permissions ?? StaffPermissions.owner();
  List<PurchaseModel> get purchases => List.unmodifiable(_purchases);
  List<ExpenseModel> get expenses => List.unmodifiable(_expenses);

  @visibleForTesting
  set testProducts(List<ProductModel> list) {
    _products.clear();
    _products.addAll(list);
  }
  @visibleForTesting
  set testShops(List<ShopModel> list) {
    _shops.clear();
    _shops.addAll(list);
  }
  @visibleForTesting
  set testStaffList(List<StaffModel> list) {
    _staffList.clear();
    _staffList.addAll(list);
  }

  String getTodayDateString() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  bool isDailyNoticeDismissed(String id, {String? forDate}) {
    final targetDate = forDate ?? getTodayDateString();
    return _dailyDismissedDates[id] == targetDate || (forDate == null && _dismissedNoticeIds.contains(id));
  }

  void dismissDailyNotice(String id) {
    final today = getTodayDateString();
    _dailyDismissedDates[id] = today;
    _dismissedNoticeIds.add(id);
    _saveDailyDismissals();
    notifyListeners();
  }

  void restoreDailyNotice(String id) {
    final today = getTodayDateString();
    if (_dailyDismissedDates[id] == today) {
      _dailyDismissedDates.remove(id);
    }
    _dismissedNoticeIds.remove(id);
    _saveDailyDismissals();
    notifyListeners();
  }

  bool isNoticeDismissed(String id) => isDailyNoticeDismissed(id);
  void dismissNotice(String id) => dismissDailyNotice(id);

  Future<void> _loadDailyDismissals() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_dailyDismissalsPrefKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(jsonStr);
        final today = getTodayDateString();
        decoded.forEach((key, val) {
          if (val == today) {
            _dailyDismissedDates[key] = today;
            _dismissedNoticeIds.add(key);
          }
        });
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Note: Error loading daily dismissals: $e');
    }
  }

  Future<void> _saveDailyDismissals() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_dailyDismissalsPrefKey, jsonEncode(_dailyDismissedDates));
    } catch (e) {
      debugPrint('Note: Error saving daily dismissals: $e');
    }
  }

  bool isModuleRemotelyDisabled(String moduleKey) {
    if (isSuperAdminUser || isSuperAdminMode) return false;
    final lowerKey = moduleKey.toLowerCase();
    if ((lowerKey == 'orders' || lowerKey == 'sell') && !isFeatureEnabledRemotely('order_taking')) return true;
    if (lowerKey == 'billing' && !isFeatureEnabledRemotely('order_taking') && !isFeatureEnabledRemotely('gst_invoicing')) return true;
    if ((lowerKey == 'accounts' || lowerKey == 'collections' || lowerKey == 'collection' || lowerKey == 'payments') &&
        (!isFeatureEnabledRemotely('collections') || !isFeatureEnabledRemotely('khataLedger'))) {
      return true;
    }
    if ((lowerKey == 'visits' || lowerKey == 'gps' || lowerKey == 'reminders') &&
        (!isFeatureEnabledRemotely('gps_tracking') || !isFeatureEnabledRemotely('vanDeliveryTracking'))) {
      return true;
    }
    if ((lowerKey == 'staff' || lowerKey == 'utilities') && !isFeatureEnabledRemotely('staff_management')) return true;
    if ((lowerKey == 'printer' || lowerKey == 'printing' || lowerKey == 'thermal_printer') &&
        (!isFeatureEnabledRemotely('thermal_printer') || !isFeatureEnabledRemotely('thermalPrinting'))) {
      return true;
    }
    if ((lowerKey == 'soundbox' || lowerKey == 'soundbox_audio' || lowerKey == 'audio_alerts') && !isFeatureEnabledRemotely('soundbox_audio')) return true;
    if ((lowerKey == 'van_stock' || lowerKey == 'warehouses' || lowerKey == 'godowns') && !isFeatureEnabledRemotely('van_stock')) return true;
    if ((lowerKey == 'customer_portal' || lowerKey == 'store_link') && !isFeatureEnabledRemotely('customer_portal')) return true;
    if ((lowerKey == 'instant_sync' || lowerKey == 'cloud_sync') &&
        (!isFeatureEnabledRemotely('instant_sync') || !isFeatureEnabledRemotely('offlineOutbox'))) {
      return true;
    }
    if ((lowerKey == 'purchase' || lowerKey == 'purchases') && !isFeatureEnabledRemotely('purchases')) return true;
    if ((lowerKey == 'expense' || lowerKey == 'expenses') && !isFeatureEnabledRemotely('expenses')) return true;
    if (lowerKey == 'reports' && !isFeatureEnabledRemotely('reports')) return true;
    return false;
  }

  bool canAccessModule(String moduleKey) {
    if (isSuperAdminUser || isSuperAdminMode) return true;

    // Check Remote Platform Kill Switches (Managed by Super Admin Web Panel)
    if (isModuleRemotelyDisabled(moduleKey)) return false;

    // Plan capabilities (admin-managed). Read-only agencies still SEE modules
    // their plan includes; creating inside them is blocked by writeBlockReason.
    if (!_planAllowsModule(moduleKey)) return false;

    final perms = activePermissions;
    switch (moduleKey.toLowerCase()) {
      case 'billing':
        return perms.billing;
      case 'products':
        return perms.products;
      case 'profile':
        return perms.profile;
      case 'orders':
        return perms.orders;
      case 'inventory':
      case 'stock':
        return perms.inventory;
      case 'reports':
        return perms.reports;
      case 'accounts':
      case 'collections':
      case 'collection':
        return perms.accounts || perms.billing;
      case 'staff':
      case 'utilities':
        return perms.staff;
      case 'purchase':
      case 'purchases':
        return perms.purchase;
      case 'expense':
      case 'expenses':
        return perms.expense;
      case 'settings':
        return perms.settings;
      case 'shops':
      case 'parties':
      case 'sell':
        return perms.products || perms.orders || perms.billing;
      case 'visits':
      case 'reminders':
        return perms.orders || perms.billing;
      default:
        return true;
    }
  }

  bool _planAllowsModule(String moduleKey) {
    switch (moduleKey.toLowerCase()) {
      case 'billing':
        return planIncludes('order_taking') || planIncludes('invoicing') || planIncludes('estimate_bills');
      case 'orders':
      case 'sell':
        return planIncludes('order_taking');
      case 'accounts':
      case 'collections':
      case 'collection':
        return planIncludes('collections');
      case 'staff':
      case 'utilities':
        return planIncludes('staff_management');
      case 'purchase':
      case 'purchases':
        return planIncludes('purchases');
      case 'expense':
      case 'expenses':
        return planIncludes('expenses');
      case 'reports':
        return planIncludes('reports');
      case 'visits':
      case 'reminders':
        return planIncludes('visits');
      default:
        return true;
    }
  }

  List<NotificationModel> get notifications => List.unmodifiable(_notifications);
  int get unreadNotificationsCount => _notifications.where((n) => !n.isRead).length;

  Future<void> markNotificationAsRead(String notificationId) async {
    final idx = _notifications.indexWhere((n) => n.id == notificationId);
    if (idx != -1) {
      _notifications[idx] = _notifications[idx].copyWith(isRead: true);
      notifyListeners();
      _persistNotificationsLocally();

      final supaTid = currentTenantId ?? _tenant.tenantId;
      if (supaTid.isNotEmpty) {
        SupabaseService.instance.markNotificationRead(
          tenantId: supaTid,
          notificationId: notificationId,
        );
      }

    }
  }

  Future<void> markAllNotificationsAsRead() async {
    for (int i = 0; i < _notifications.length; i++) {
      _notifications[i] = _notifications[i].copyWith(isRead: true);
    }
    notifyListeners();
    _persistNotificationsLocally();

    final supaTid = currentTenantId ?? _tenant.tenantId;
    if (supaTid.isNotEmpty) {
      for (final n in _notifications) {
        SupabaseService.instance.markNotificationRead(
          tenantId: supaTid,
          notificationId: n.id,
        );
      }
    }

  }

  void addNotification(NotificationModel notification, {bool showPopup = true}) {
    _notifications.removeWhere((n) => n.id == notification.id);
    _notifications.insert(0, notification);
    notifyListeners();
    _persistNotificationsLocally();

    if (showPopup) {
      NotificationService.instance.showInAppPopup(notification);
    }

    final supaTid = currentTenantId ?? _tenant.tenantId;
    if (supaTid.isNotEmpty) {
      SupabaseService.instance.insertNotification(
        tenantId: supaTid,
        notificationData: notification.toMap(),
      );
    }

  }

  void receiveRemoteNotification(NotificationModel notification) {
    if (!_notifications.any((n) => n.id == notification.id)) {
      _notifications.insert(0, notification);
      notifyListeners();
      _persistNotificationsLocally();
      NotificationService.instance.showInAppPopup(notification);
    }
  }

  Future<void> sendAdminBroadcast({
    required String title,
    required String message,
    String type = 'broadcast',
    String? targetRole,
  }) async {
    final notif = NotificationModel(
      id: 'broadcast_${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      title: title,
      message: message,
      createdAt: DateTime.now(),
      isRead: false,
    );

    addNotification(notif, showPopup: true);

    // Sync to Server bridge (developer-only; disabled in release builds).
    if (!kReleaseMode && !kIsWeb) {
      final hosts = {_activeBridgeHost, '10.0.2.2', '127.0.0.1', 'localhost'}.where((h) => h.trim().isNotEmpty).toList();
      for (final host in hosts) {
        try {
          final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
          final req = await client.postUrl(Uri.parse('http://$host:3000/api/platform/broadcast'));
          req.headers.set('Content-Type', 'application/json');
          req.write(jsonEncode({
            'title': title,
            'message': message,
            'type': type,
            'targetRole': targetRole,
            'sender': activeStaffUser?.name ?? _tenant.representativeName ?? _tenant.firmName ?? 'Admin',
            'active': true,
          }));
          final res = await req.close();
          await res.drain();
          client.close();
          if (res.statusCode == 200) break;
        } catch (e) { debugPrint('Post broadcast to bridge: $e'); }
      }
    }
  }

  void deleteNotification(String id) {
    _notifications.removeWhere((n) => n.id == id);
    notifyListeners();
    _persistNotificationsLocally();

    final supaTid = currentTenantId ?? _tenant.tenantId;
    if (supaTid.isNotEmpty) {
      SupabaseService.instance.deleteNotification(
        tenantId: supaTid,
        notificationId: id,
      );
    }

  }

  void clearAllNotifications() {
    _notifications.clear();
    notifyListeners();
    _persistNotificationsLocally();
  }

  Future<void> addStaff(StaffModel staff) async {
    final isNew = !_staffList.any((s) => s.id == staff.id);
    if (isNew) {
      ensureCanWrite(feature: 'staff_management');
      _ensureUnderLimit(
        used: _staffList.length,
        limit: maxAllowedUsers,
        message: 'Staff Seats Limit Reached: Your current ${currentPlan.name} plan permits up to $maxAllowedUsers staff seat(s). '
            'Upgrade your plan in Plan & Pricing to add additional staff.',
      );
    }
    _staffList.removeWhere((s) => s.id == staff.id);
    _staffList.add(staff);
    notifyListeners();
    _persistStaffLocally();

  }

  Future<void> updateStaff(StaffModel staff) async {
    final idx = _staffList.indexWhere((s) => s.id == staff.id);
    if (idx != -1) {
      _staffList[idx] = staff;
      if (_activeStaffUser?.id == staff.id) {
        _activeStaffUser = staff;
      }
      notifyListeners();
      _persistStaffLocally();

    }
  }

  Future<void> deleteStaff(String staffId) async {
    _staffList.removeWhere((s) => s.id == staffId);
    if (_activeStaffUser?.id == staffId) {
      _activeStaffUser = null;
    }
    notifyListeners();
    _persistStaffLocally();

  }

  void setActiveStaffUser(StaffModel? staff) {
    _activeStaffUser = staff;
    notifyListeners();
  }

  Future<void> _persistRoleSession(String role) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('salesarmy_session_logged_in_v1', true);
      await prefs.setString('salesarmy_session_role_v1', role);
      if (currentTenantId != null) {
        await prefs.setString('salesarmy_session_tenant_id_v1', currentTenantId!);
      }
      if (currentUid != null) {
        await prefs.setString('salesarmy_session_uid_v1', currentUid!);
      }
    } catch (e) { debugPrint('Persist role session: $e'); }
  }

  void setActiveRole(String role) {
    currentUserRole = role;
    _persistRoleSession(role);
    final normalized = role.toLowerCase().trim();
    if (normalized == 'owner' || normalized == 'distributor') {
      currentUserRole = 'Owner';
      _activeStaffUser = null;
      notifyListeners();
      return;
    }
    if (normalized == 'super_admin' || normalized == 'super admin') {
      currentUserRole = 'super_admin';
      _activeStaffUser = null;
      notifyListeners();
      return;
    }
    StaffModel? matched;
    for (final s in _staffList) {
      if (s.role.toLowerCase().trim() == normalized) {
        matched = s;
        break;
      }
    }
    if (matched != null) {
      _activeStaffUser = matched;
    } else {
      StaffPermissions perms;
      switch (normalized) {
        case 'accountant':
        case 'billing clerk':
          perms = StaffPermissions.accountant();
          break;
        case 'delivery staff':
        case 'delivery boy':
        case 'delivery':
          perms = StaffPermissions.delivery();
          break;
        case 'field sales':
        case 'salesman':
        case 'order taker':
        case 'sales officer':
          perms = StaffPermissions.fieldSales();
          break;
        case 'store manager':
        case 'warehouse manager':
        case 'warehouse':
          perms = const StaffPermissions(
            billing: false,
            products: true,
            profile: false,
            orders: false,
            inventory: true,
            reports: false,
            accounts: false,
            staff: false,
            purchase: true,
            expense: false,
            settings: false,
          );
          break;
        default:
          perms = StaffPermissions.owner();
      }
      _activeStaffUser = StaffModel(
        id: 'staff_${normalized.replaceAll(' ', '_')}',
        name: '$role Operator',
        email: '${normalized.replaceAll(' ', '')}@agency.com',
        mobile: '9876543210',
        role: role,
        permissions: perms,
        createdAt: DateTime.now(),
      );
    }
    notifyListeners();
  }

  void addPurchase(PurchaseModel purchase) {
    if (!_purchases.any((p) => p.id == purchase.id)) ensureCanWrite(feature: 'purchases');
    _purchases.insert(0, purchase);

    // 1. Add purchased goods to inventory stock
    final supaTid = currentTenantId ?? _tenant.tenantId;
    if (purchase.items.isNotEmpty) {
      for (final item in purchase.items) {
        final prodIdx = _products.indexWhere(
          (p) => p.productId == item.productId || (item.productName.isNotEmpty && p.name.toLowerCase().trim() == item.productName.toLowerCase().trim()),
        );
        if (prodIdx != -1) {
          final currentProd = _products[prodIdx];
          final updatedQty = currentProd.stockQuantity + item.quantity;
          _products[prodIdx] = currentProd.copyWith(
            stockQuantity: updatedQty,
            updatedAt: DateTime.now(),
          );
          if (supaTid.isNotEmpty) {
            SupabaseService.instance.updateProductStock(
              tenantId: supaTid,
              productId: currentProd.productId,
              stockQuantity: updatedQty,
            );
          }
        } else if (item.productName.trim().isNotEmpty) {
          final newProd = ProductModel(
            productId: item.productId.isNotEmpty ? item.productId : 'prod_${DateTime.now().millisecondsSinceEpoch}_${_products.length + 1}',
            name: item.productName.trim(),
            variant: 'Standard',
            size: 'Pack',
            categoryId: 'General',
            basePrice: item.unitPrice > 0 ? item.unitPrice : 100.0,
            wholesalePrice: (item.unitPrice > 0 ? item.unitPrice : 100.0) * 1.1,
            retailPrice: (item.unitPrice > 0 ? item.unitPrice : 100.0) * 1.25,
            customerPrice: (item.unitPrice > 0 ? item.unitPrice : 100.0) * 1.3,
            gstRate: 0.0,
            stockQuantity: item.quantity,
            lowStockAlertQty: 10,
            isActive: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          _products.add(newProd);
          if (supaTid.isNotEmpty) {
            SupabaseService.instance.upsertProduct(
              tenantId: supaTid,
              productData: _productToJson(newProd),
            );
          }
          syncProductToServerBridge(newProd);
        }
      }
    }

    // 2. Financial price deduction: deduct from In-Hand Cash or Bank Account if paid
    if (purchase.paymentStatus.toLowerCase() == 'paid') {
      if (purchase.paymentMode.toLowerCase().contains('cash')) {
        _inHandCash = (_inHandCash - purchase.totalAmount).clamp(0.0, double.infinity);
      } else {
        _inAccountBalance = (_inAccountBalance - purchase.totalAmount).clamp(0.0, double.infinity);
      }
      _syncBalancesToFirestore();
    }

    // 3. Notification
    addNotification(
      NotificationModel(
        id: 'notif_pur_${DateTime.now().millisecondsSinceEpoch}',
        type: 'inventory',
        title: 'Goods In: ${purchase.billNumber}',
        message: 'Purchased ${purchase.totalUnits} units for ₹${purchase.totalAmount.toStringAsFixed(0)} from ${purchase.supplierName}. Stock added.',
        createdAt: DateTime.now(),
      ),
    );

    notifyListeners();
    _persistPurchasesLocally();
    _persistProductsLocally();
    if (supaTid.isNotEmpty && SupabaseService.instance.isInitialized) {
      SupabaseService.instance.insertPurchase(
        tenantId: supaTid,
        purchaseData: purchase.toMap(),
      );
    }
  }

  void deletePurchase(String purchaseId) {
    final idx = _purchases.indexWhere((p) => p.id == purchaseId);
    if (idx != -1) {
      final purchase = _purchases[idx];

      // 1. Revert inventory: deduct purchased goods from inventory stock
      if (purchase.items.isNotEmpty) {
        final supaTid = currentTenantId ?? _tenant.tenantId;
        for (final item in purchase.items) {
          final prodIdx = _products.indexWhere(
            (p) => p.productId == item.productId || (item.productName.isNotEmpty && p.name.toLowerCase().trim() == item.productName.toLowerCase().trim()),
          );
          if (prodIdx != -1) {
            final currentProd = _products[prodIdx];
            final updatedQty = (currentProd.stockQuantity - item.quantity).clamp(0, 999999);
            _products[prodIdx] = currentProd.copyWith(
              stockQuantity: updatedQty,
              updatedAt: DateTime.now(),
            );
            if (supaTid.isNotEmpty) {
              SupabaseService.instance.updateProductStock(
                tenantId: supaTid,
                productId: currentProd.productId,
                stockQuantity: updatedQty,
              );
            }
          }
        }
      }

      // 2. Financial price refund: restore deducted funds back to balance if was paid
      if (purchase.paymentStatus.toLowerCase() == 'paid') {
        if (purchase.paymentMode.toLowerCase().contains('cash')) {
          _inHandCash += purchase.totalAmount;
        } else {
          _inAccountBalance += purchase.totalAmount;
        }
        _syncBalancesToFirestore();
      }

      _purchases.removeAt(idx);

      // Notification
      addNotification(
        NotificationModel(
          id: 'notif_pur_del_${DateTime.now().millisecondsSinceEpoch}',
          type: 'inventory',
          title: 'Purchase Deleted: ${purchase.billNumber}',
          message: 'Purchase goods reverted and funds restored to ${purchase.paymentMode}.',
          createdAt: DateTime.now(),
        ),
      );

      notifyListeners();
      _persistPurchasesLocally();
      _persistProductsLocally();
      final supaTid = currentTenantId ?? _tenant.tenantId;
      if (supaTid.isNotEmpty && SupabaseService.instance.isInitialized) {
        SupabaseService.instance.deletePurchase(tenantId: supaTid, purchaseId: purchaseId);
      }
    }
  }

  void updatePurchase(PurchaseModel updated) {
    final idx = _purchases.indexWhere((p) => p.id == updated.id);
    if (idx != -1) {
      final old = _purchases[idx];
      final supaTid = currentTenantId ?? _tenant.tenantId;

      // 1. Revert old stock additions
      for (final item in old.items) {
        final prodIdx = _products.indexWhere(
          (p) => p.productId == item.productId || (item.productName.isNotEmpty && p.name.toLowerCase().trim() == item.productName.toLowerCase().trim()),
        );
        if (prodIdx != -1) {
          final currentProd = _products[prodIdx];
          final revertedQty = (currentProd.stockQuantity - item.quantity).clamp(0, 999999);
          _products[prodIdx] = currentProd.copyWith(
            stockQuantity: revertedQty,
            updatedAt: DateTime.now(),
          );
        }
      }

      // 2. Apply new stock additions
      for (final item in updated.items) {
        final prodIdx = _products.indexWhere(
          (p) => p.productId == item.productId || (item.productName.isNotEmpty && p.name.toLowerCase().trim() == item.productName.toLowerCase().trim()),
        );
        if (prodIdx != -1) {
          final currentProd = _products[prodIdx];
          final newQty = (currentProd.stockQuantity + item.quantity).clamp(0, 999999);
          _products[prodIdx] = currentProd.copyWith(
            stockQuantity: newQty,
            updatedAt: DateTime.now(),
          );
          if (supaTid.isNotEmpty) {
            SupabaseService.instance.updateProductStock(
              tenantId: supaTid,
              productId: currentProd.productId,
              stockQuantity: newQty,
            );
          }
        }
      }

      // 3. Revert old funds & deduct updated funds
      if (old.paymentStatus.toLowerCase() == 'paid') {
        if (old.paymentMode.toLowerCase().contains('cash')) {
          _inHandCash += old.totalAmount;
        } else {
          _inAccountBalance += old.totalAmount;
        }
      }
      if (updated.paymentStatus.toLowerCase() == 'paid') {
        if (updated.paymentMode.toLowerCase().contains('cash')) {
          _inHandCash = (_inHandCash - updated.totalAmount).clamp(0.0, double.infinity);
        } else {
          _inAccountBalance = (_inAccountBalance - updated.totalAmount).clamp(0.0, double.infinity);
        }
      }
      _syncBalancesToFirestore();

      _purchases[idx] = updated;
      notifyListeners();
      _persistPurchasesLocally();
      _persistProductsLocally();

      if (supaTid.isNotEmpty && SupabaseService.instance.isInitialized) {
        SupabaseService.instance.insertPurchase(
          tenantId: supaTid,
          purchaseData: updated.toMap(),
        );
      }
    }
  }

  void addExpense(ExpenseModel expense) {
    if (!_expenses.any((e) => e.id == expense.id)) ensureCanWrite(feature: 'expenses');
    _expenses.insert(0, expense);

    // Price deduction: deduct from In-Hand Cash or In-Account balance
    if (expense.paymentMode.toLowerCase().contains('cash')) {
      _inHandCash = (_inHandCash - expense.amount).clamp(0.0, double.infinity);
    } else {
      _inAccountBalance = (_inAccountBalance - expense.amount).clamp(0.0, double.infinity);
    }
    _syncBalancesToFirestore();

    final supaTid = currentTenantId ?? _tenant.tenantId;
    if (supaTid.isNotEmpty && SupabaseService.instance.isInitialized) {
      SupabaseService.instance.insertExpense(
        tenantId: supaTid,
        expenseData: expense.toMap(),
      );
    }

    addNotification(
      NotificationModel(
        id: 'notif_exp_${DateTime.now().millisecondsSinceEpoch}',
        type: 'payment',
        title: 'Expense Recorded: ₹${expense.amount.toStringAsFixed(0)}',
        message: '${expense.title} (${expense.category}) deducted from ${expense.paymentMode}.',
        createdAt: DateTime.now(),
      ),
    );

    notifyListeners();
    _persistExpensesLocally();
  }

  void deleteExpense(String expenseId) {
    final idx = _expenses.indexWhere((e) => e.id == expenseId);
    if (idx != -1) {
      final expense = _expenses[idx];
      final supaTid = currentTenantId ?? _tenant.tenantId;
      if (supaTid.isNotEmpty && SupabaseService.instance.isInitialized) {
        SupabaseService.instance.deleteExpense(
          tenantId: supaTid,
          expenseId: expense.id,
        );
      }

      // Price restore: refund deducted funds back
      if (expense.paymentMode.toLowerCase().contains('cash')) {
        _inHandCash += expense.amount;
      } else {
        _inAccountBalance += expense.amount;
      }
      _syncBalancesToFirestore();

      _expenses.removeAt(idx);

      addNotification(
        NotificationModel(
          id: 'notif_exp_del_${DateTime.now().millisecondsSinceEpoch}',
          type: 'payment',
          title: 'Expense Deleted: ₹${expense.amount.toStringAsFixed(0)}',
          message: '${expense.title} deleted and ₹${expense.amount.toStringAsFixed(0)} refunded to ${expense.paymentMode}.',
          createdAt: DateTime.now(),
        ),
      );

      notifyListeners();
      _persistExpensesLocally();
    }
  }

  void updateExpense(ExpenseModel updated) {
    final idx = _expenses.indexWhere((e) => e.id == updated.id);
    if (idx != -1) {
      final old = _expenses[idx];

      // Revert old funds
      if (old.paymentMode.toLowerCase().contains('cash')) {
        _inHandCash += old.amount;
      } else {
        _inAccountBalance += old.amount;
      }

      // Deduct new funds
      if (updated.paymentMode.toLowerCase().contains('cash')) {
        _inHandCash = (_inHandCash - updated.amount).clamp(0.0, double.infinity);
      } else {
        _inAccountBalance = (_inAccountBalance - updated.amount).clamp(0.0, double.infinity);
      }
      _syncBalancesToFirestore();

      _expenses[idx] = updated;
      notifyListeners();
      _persistExpensesLocally();

      final supaTid = currentTenantId ?? _tenant.tenantId;
      if (supaTid.isNotEmpty && SupabaseService.instance.isInitialized) {
        SupabaseService.instance.insertExpense(
          tenantId: supaTid,
          expenseData: updated.toMap(),
        );
      }
    }
  }

  void _syncBalancesToFirestore() {
    _persistLiquidBalancesLocally();
  }

  // Computed Business Metrics
  double get todaySales {
    final now = DateTime.now();
    return _invoices
        .where((inv) =>
            inv.invoiceDate.year == now.year &&
            inv.invoiceDate.month == now.month &&
            inv.invoiceDate.day == now.day)
        .fold<double>(0.0, (total, inv) => total + inv.grandTotal);
  }

  double get monthlySales {
    final now = DateTime.now();
    return _invoices
        .where((inv) =>
            inv.invoiceDate.year == now.year &&
            inv.invoiceDate.month == now.month)
        .fold<double>(0.0, (total, inv) => total + inv.grandTotal);
  }

  double get todayCollections {
    final now = DateTime.now();
    return _payments
        .where((p) =>
            p.date.year == now.year &&
            p.date.month == now.month &&
            p.date.day == now.day)
        .fold<double>(0.0, (total, p) => total + p.amount);
  }

  /// Remaining due on a single bill.
  static double invoiceDue(InvoiceModel i) {
    if (i.paymentStatus.toLowerCase() == 'paid') return 0.0;
    final due = i.dueAmount > 0 ? i.dueAmount : (i.grandTotal - i.paidAmount);
    return due > 0.009 ? due : 0.0;
  }

  bool _isUnbilledOpenOrder(OrderModel o) =>
      (o.status.toLowerCase() == 'pending' || o.status.toLowerCase() == 'confirmed') &&
      !_invoices.any((i) => i.orderId == o.orderId);

  /// Unbilled pending/confirmed orders for a shop, oldest first.
  List<OrderModel> _unbilledOpenOrders(String shopId) {
    final list = _orders.where((o) => o.shopId == shopId && _isUnbilledOpenOrder(o)).toList();
    list.sort((a, b) => (a.placedAt ?? a.createdAt ?? DateTime(2000))
        .compareTo(b.placedAt ?? b.createdAt ?? DateTime(2000)));
    return list;
  }

  /// Money received from a shop that is not yet absorbed by any bill — i.e.
  /// payments made against unbilled orders (partial or full) or advances.
  /// = all payments for the shop − amount already marked paid on its bills.
  double getShopUnallocatedCredit(String shopId) {
    final paymentsTotal = _payments
        .where((p) => p.shopId == shopId)
        .fold<double>(0.0, (acc, p) => acc + p.amount);
    final billedPaid = _invoices
        .where((i) => i.shopId == shopId)
        .fold<double>(0.0, (acc, i) => acc + i.paidAmount);
    final credit = paymentsTotal - billedPaid;
    return credit > 0.009 ? credit : 0.0;
  }

  /// How much of each unbilled order has been paid. Payments that name an
  /// order (in notes / reference) go to that order first; any remaining credit
  /// is applied oldest order first.
  Map<String, double> getUnbilledOrderPaidAmounts(String shopId) {
    final orders = _unbilledOpenOrders(shopId);
    final paid = <String, double>{for (final o in orders) o.orderId: 0.0};
    if (orders.isEmpty) return paid;
    double credit = getShopUnallocatedCredit(shopId);
    if (credit <= 0) return paid;

    for (final p in _payments.where((p) => p.shopId == shopId)) {
      if (credit <= 0) break;
      for (final o in orders) {
        final tagged = (p.notes?.contains(o.orderId) ?? false) ||
            (p.referenceNumber?.contains(o.orderId) ?? false);
        if (!tagged) continue;
        final room = o.grandTotal - paid[o.orderId]!;
        final take = math.min(math.min(p.amount, room), credit);
        if (take > 0) {
          paid[o.orderId] = paid[o.orderId]! + take;
          credit -= take;
        }
        break;
      }
    }
    for (final o in orders) {
      if (credit <= 0) break;
      final room = o.grandTotal - paid[o.orderId]!;
      final take = math.min(room, credit);
      if (take > 0) {
        paid[o.orderId] = paid[o.orderId]! + take;
        credit -= take;
      }
    }
    return paid;
  }

  /// Amount paid so far against an order (from its bill if billed).
  double getOrderPaidAmount(OrderModel order) {
    final inv = _invoices.where((i) => i.orderId == order.orderId);
    if (inv.isNotEmpty) return inv.first.paidAmount;
    return getUnbilledOrderPaidAmounts(order.shopId)[order.orderId] ?? 0.0;
  }

  /// Amount still to be collected for an order.
  double getOrderDueAmount(OrderModel order) {
    final inv = _invoices.where((i) => i.orderId == order.orderId);
    if (inv.isNotEmpty) return invoiceDue(inv.first);
    final s = order.status.toLowerCase();
    if (s == 'cancelled') return 0.0;
    final due = order.grandTotal - getOrderPaidAmount(order);
    return due > 0.009 ? due : 0.0;
  }

  double getShopOutstandingDue(ShopModel s) {
    final pendingOrdersTotal = _unbilledOpenOrders(s.shopId)
        .fold<double>(0.0, (acc, o) => acc + o.grandTotal);
    final unpaidInvoicesTotal = _invoices
        .where((i) => i.shopId == s.shopId)
        .fold<double>(0.0, (acc, i) => acc + invoiceDue(i));
    // Payments against unbilled orders must reduce the derived due too,
    // otherwise a partial (or even full) payment on an order never shows.
    final derived = math.max(0.0, pendingOrdersTotal + unpaidInvoicesTotal - getShopUnallocatedCredit(s.shopId));
    return math.max(s.currentOutstanding, derived);
  }

  double get totalOutstanding {
    double total = 0.0;
    for (final s in _shops) {
      total += getShopOutstandingDue(s);
    }
    return total;
  }

  int get lowStockCount {
    return _products.where((p) => p.stockQuantity <= p.lowStockAlertQty).length;
  }

  int get pendingVisitsCount {
    return _visits.where((v) => v.checkOutTime == null).length;
  }

  // Actions: Shops
  Future<void> addShop(ShopModel shop) async {
    if (!_shops.any((s) => s.shopId == shop.shopId)) {
      ensureCanWrite();
      _ensureUnderLimit(
        used: _shops.length,
        limit: maxAllowedShops,
        message: 'SaaS Plan Limit Exceeded: Your plan allows a maximum of $maxAllowedShops retail shops. '
            'Upgrade your plan in Plan & Pricing to add more parties.',
      );
    }

    _shops.insert(0, shop);
    await _persistShopsLocally();
    notifyListeners();

    // Supabase Cloud Sync
    final supaTid = currentTenantId ?? _tenant.tenantId;
    if (supaTid.isNotEmpty) {
      SupabaseService.instance.upsertShop(
        tenantId: supaTid,
        shopData: _shopToJson(shop),
      );
    }
    syncShopToServerBridge(shop);

    // Clean Architecture Domain Repository
    if (_shopRepository != null) {
      final entity = ShopEntity(
        shopId: shop.shopId,
        shopName: shop.shopName,
        ownerName: shop.ownerName,
        phone: shop.phone,
        whatsappNumber: shop.whatsappNumber,
        businessType: shop.businessType,
        categoryId: shop.categoryId,
        gstin: shop.gstin,
        address: shop.address,
        visitFrequency: shop.visitFrequency,
        creditLimit: shop.creditLimit,
        currentOutstanding: shop.currentOutstanding,
        latitude: shop.latitude,
        longitude: shop.longitude,
        notes: shop.notes,
        isActive: shop.isActive,
        createdAt: shop.createdAt,
        updatedAt: shop.updatedAt,
        createdByUid: shop.createdByUid,
        updatedByUid: shop.updatedByUid,
      );
      await _shopRepository!.saveShop(entity, uid: currentUid ?? 'user');
    } else {
    }
  }

  Future<void> updateShop(ShopModel updated) async {
    final index = _shops.indexWhere((s) => s.shopId == updated.shopId);
    if (index != -1) {
      _shops[index] = updated;
      await _persistShopsLocally();
      notifyListeners();
    }

    // Supabase Cloud Sync
    final supaTid = currentTenantId ?? _tenant.tenantId;
    if (supaTid.isNotEmpty) {
      SupabaseService.instance.upsertShop(
        tenantId: supaTid,
        shopData: _shopToJson(updated),
      );
    }
    syncShopToServerBridge(updated);

    if (_shopRepository != null) {
      final entity = ShopEntity(
        shopId: updated.shopId,
        shopName: updated.shopName,
        ownerName: updated.ownerName,
        phone: updated.phone,
        whatsappNumber: updated.whatsappNumber,
        businessType: updated.businessType,
        categoryId: updated.categoryId,
        gstin: updated.gstin,
        address: updated.address,
        visitFrequency: updated.visitFrequency,
        creditLimit: updated.creditLimit,
        currentOutstanding: updated.currentOutstanding,
        latitude: updated.latitude,
        longitude: updated.longitude,
        notes: updated.notes,
        isActive: updated.isActive,
        createdAt: updated.createdAt,
        updatedAt: updated.updatedAt,
        createdByUid: updated.createdByUid,
        updatedByUid: updated.updatedByUid,
      );
      await _shopRepository!.saveShop(entity, uid: currentUid ?? 'user');
    } else {
    }
  }

  Future<void> deleteShop(String shopId) async {
    _shops.removeWhere((s) => s.shopId == shopId);
    await _persistShopsLocally();
    notifyListeners();

    final supaTid = currentTenantId ?? _tenant.tenantId;
    if (supaTid.isNotEmpty) {
      SupabaseService.instance.deleteShop(tenantId: supaTid, shopId: shopId);
    }

  }

  // Actions: Products
  Future<void> addProduct(ProductModel product) async {
    if (!_products.any((p) => p.productId == product.productId)) {
      ensureCanWrite();
      _ensureUnderLimit(
        used: _products.length,
        limit: maxAllowedProducts,
        message: 'Catalog Product Limit Exceeded: Your ${currentPlan.name} plan permits up to $maxAllowedProducts products. '
            'Upgrade your plan in Plan & Pricing to add more products.',
      );
    }

    _products.insert(0, product);
    await _persistProductsLocally();
    notifyListeners();

    // Supabase Cloud Sync
    final supaTid = currentTenantId ?? _tenant.tenantId;
    if (supaTid.isNotEmpty) {
      SupabaseService.instance.upsertProduct(
        tenantId: supaTid,
        productData: _productToJson(product),
      );
    }
    syncProductToServerBridge(product);

    if (_productRepository != null) {
      final entity = ProductEntity(
        productId: product.productId,
        name: product.name,
        variant: product.variant,
        size: product.size,
        categoryId: product.categoryId,
        sku: product.sku,
        barcode: product.barcode,
        hsnSacCode: product.hsnSacCode,
        basePrice: product.basePrice,
        wholesalePrice: product.wholesalePrice,
        retailPrice: product.retailPrice,
        customerPrice: product.customerPrice,
        gstRate: product.gstRate,
        stockQuantity: product.stockQuantity,
        lowStockAlertQty: product.lowStockAlertQty,
        imageUrl: product.imageUrl,
        isActive: product.isActive,
        createdAt: product.createdAt,
        updatedAt: product.updatedAt,
        createdByUid: product.createdByUid,
        updatedByUid: product.updatedByUid,
      );
      await _productRepository!.saveProduct(entity, uid: currentUid ?? 'user');
    } else {
    }
  }

  Future<void> updateProduct(ProductModel product) async {
    final idx = _products.indexWhere((p) => p.productId == product.productId);
    if (idx != -1) {
      _products[idx] = product;
      await _persistProductsLocally();
      notifyListeners();
    }

    // Supabase Cloud Sync
    final supaTid = currentTenantId ?? _tenant.tenantId;
    if (supaTid.isNotEmpty) {
      SupabaseService.instance.upsertProduct(
        tenantId: supaTid,
        productData: _productToJson(product),
      );
    }
    syncProductToServerBridge(product);

    if (_productRepository != null) {
      final entity = ProductEntity(
        productId: product.productId,
        name: product.name,
        variant: product.variant,
        size: product.size,
        categoryId: product.categoryId,
        sku: product.sku,
        barcode: product.barcode,
        hsnSacCode: product.hsnSacCode,
        basePrice: product.basePrice,
        wholesalePrice: product.wholesalePrice,
        retailPrice: product.retailPrice,
        customerPrice: product.customerPrice,
        gstRate: product.gstRate,
        stockQuantity: product.stockQuantity,
        lowStockAlertQty: product.lowStockAlertQty,
        imageUrl: product.imageUrl,
        isActive: product.isActive,
        createdAt: product.createdAt,
        updatedAt: product.updatedAt,
        createdByUid: product.createdByUid,
        updatedByUid: product.updatedByUid,
      );
      await _productRepository!.saveProduct(entity, uid: currentUid ?? 'user');
    } else {
    }
  }

  Future<void> deleteProduct(String productId) async {
    _products.removeWhere((p) => p.productId == productId);
    await _persistProductsLocally();
    notifyListeners();

    final supaTid = currentTenantId ?? _tenant.tenantId;
    if (supaTid.isNotEmpty) {
      SupabaseService.instance.deleteProduct(tenantId: supaTid, productId: productId);
    }

  }

  // Actions: Orders & Invoices
  Future<void> createOrder(OrderModel order) async {
    if (!_orders.any((o) => o.orderId == order.orderId)) {
      ensureCanWrite(feature: 'order_taking');
      _ensureUnderLimit(
        used: ordersThisMonth,
        limit: maxAllowedOrdersPerMonth,
        message: 'Monthly Order Limit Reached: Your ${currentPlan.name} plan allows $maxAllowedOrdersPerMonth orders per month. '
            'Upgrade your plan in Plan & Pricing to take more orders.',
      );
    }

    if (SupabaseService.instance.client != null) {
      await SupabaseService.instance.insertOrder(tenantId: currentTenantId ?? _tenant.tenantId,
        orderData: order.toMap(), items: order.items.map((item) => item.toMap()).toList());
    }
    _orders.insert(0, order);
    await _persistOrdersLocally();
    notifyListeners();

    if (SupabaseService.instance.client != null) return;
    syncOrderToServerBridge(order);

    if (_orderRepository != null) {
      final entity = OrderEntity(
        orderId: order.orderId,
        shopId: order.shopId,
        createdByUid: order.createdByUid,
        status: order.status,
        items: order.items
            .map((item) => OrderItemEntity(
                  productId: item.productId,
                  productName: item.productName,
                  quantity: item.quantity,
                  unitPrice: item.unitPrice,
                  gstRate: item.gstRate,
                  itemSubtotal: item.itemSubtotal,
                  itemGst: item.itemGst,
                  itemGrandTotal: item.itemGrandTotal,
                ))
            .toList(),
        subtotal: order.subtotal,
        totalGst: order.totalGst,
        grandTotal: order.grandTotal,
        deliveryNote: order.deliveryNote,
        placedAt: order.placedAt,
        deliveredAt: order.deliveredAt,
        createdAt: order.createdAt,
        updatedAt: order.updatedAt,
      );
      await _orderRepository!.createOrder(entity);
    } else {
    }
  }

  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    final idx = _orders.indexWhere((o) => o.orderId == orderId);
    if (idx != -1) {
      final existing = _orders[idx];
      final now = DateTime.now();
      final updated = OrderModel(
        orderId: existing.orderId,
        shopId: existing.shopId,
        createdByUid: existing.createdByUid,
        status: newStatus,
        items: existing.items,
        subtotal: existing.subtotal,
        totalGst: existing.totalGst,
        grandTotal: existing.grandTotal,
        deliveryNote: existing.deliveryNote,
        placedAt: existing.placedAt,
        deliveredAt: (newStatus == 'delivered' || newStatus == 'completed')
            ? (existing.deliveredAt ?? now)
            : (newStatus == 'pending' ? null : existing.deliveredAt),
        createdAt: existing.createdAt,
        updatedAt: now,
      );
      _orders[idx] = updated;
      notifyListeners();
      _persistOrdersLocally();

      // Supabase Cloud Sync
      final supaTid = currentTenantId ?? _tenant.tenantId;
      if (supaTid.isNotEmpty) {
        SupabaseService.instance.updateOrderStatus(
          tenantId: supaTid,
          orderId: orderId,
          status: newStatus,
          deliveredAt: updated.deliveredAt,
        );
      }

    }
  }

  Future<void> updateOrder(OrderModel updated) async {
    final idx = _orders.indexWhere((o) => o.orderId == updated.orderId);
    if (idx != -1) {
      final existing = _orders[idx];
      _orders[idx] = updated;

      // If grandTotal changed and no separate invoice, adjust shop outstanding difference
      final hasInvoice = _invoices.any((i) => i.orderId == updated.orderId);
      if (!hasInvoice && (updated.grandTotal - existing.grandTotal).abs() > 0.001) {
        final diff = updated.grandTotal - existing.grandTotal;
        final shopIdx = _shops.indexWhere((s) => s.shopId == updated.shopId);
        if (shopIdx != -1) {
          final oldShop = _shops[shopIdx];
          final newOutstanding = (oldShop.currentOutstanding + diff).clamp(0.0, 99999999.0);
          _shops[shopIdx] = oldShop.copyWith(currentOutstanding: newOutstanding);
          _persistShopsLocally();
          final supaTid = currentTenantId ?? _tenant.tenantId;
          if (supaTid.isNotEmpty) {
            SupabaseService.instance.updateShopOutstanding(
              tenantId: supaTid,
              shopId: updated.shopId,
              outstanding: newOutstanding,
            );
          }
        }
      }

      notifyListeners();
      _persistOrdersLocally();

      if (_orderRepository != null) {
        final entity = OrderEntity(
          orderId: updated.orderId,
          shopId: updated.shopId,
          createdByUid: updated.createdByUid,
          status: updated.status,
          items: updated.items.map((it) => OrderItemEntity(
            productId: it.productId,
            productName: it.productName,
            quantity: it.quantity,
            unitPrice: it.unitPrice,
            gstRate: it.gstRate,
            itemSubtotal: it.itemSubtotal,
            itemGst: it.itemGst,
            itemGrandTotal: it.itemGrandTotal,
          )).toList(),
          subtotal: updated.subtotal,
          totalGst: updated.totalGst,
          grandTotal: updated.grandTotal,
          deliveryNote: updated.deliveryNote,
          placedAt: updated.placedAt,
          deliveredAt: updated.deliveredAt,
          createdAt: updated.createdAt,
          updatedAt: updated.updatedAt,
        );
        await _orderRepository!.createOrder(entity);
      } else {
        final supaTid = currentTenantId ?? _tenant.tenantId;
        if (supaTid.isNotEmpty) {
          SupabaseService.instance.upsertOrder(
            tenantId: supaTid,
            orderData: updated.toMap(),
            items: updated.items.map((it) => it.toMap()).toList(),
          );
        }
      }
    }
  }

  Future<void> deleteOrder(String orderId) async {
    final idx = _orders.indexWhere((o) => o.orderId == orderId);
    if (idx != -1) {
      final removed = _orders[idx];
      _orders.removeWhere((o) => o.orderId == orderId);

      // Revert shop outstanding if there wasn't a separate invoice deleted
      final hasInvoice = _invoices.any((i) => i.orderId == orderId);
      if (!hasInvoice) {
        final shopIdx = _shops.indexWhere((s) => s.shopId == removed.shopId);
        if (shopIdx != -1) {
          final old = _shops[shopIdx];
          final newOutstanding = (old.currentOutstanding - removed.grandTotal).clamp(0.0, 99999999.0);
          _shops[shopIdx] = old.copyWith(currentOutstanding: newOutstanding);
          final revLedger = LedgerEntryModel(
            ledgerId: 'LED-ORD-REV-${DateTime.now().millisecondsSinceEpoch}',
            shopId: removed.shopId,
            createdByUid: currentUid ?? 'user',
            type: 'ORDER_CANCELLED',
            referenceId: removed.orderId,
            amount: -removed.grandTotal,
            balanceAfter: newOutstanding,
            description: 'Reversal: Order #${removed.orderId} deleted',
            date: DateTime.now(),
          );
          _ledgerEntries.insert(0, revLedger);
          _persistShopsLocally();
          _persistLedgerLocally();
          final supaTid = currentTenantId ?? _tenant.tenantId;
          if (supaTid.isNotEmpty) {
            SupabaseService.instance.updateShopOutstanding(
              tenantId: supaTid,
              shopId: removed.shopId,
              outstanding: newOutstanding,
            );
            SupabaseService.instance.insertLedgerEntry(
              tenantId: supaTid,
              ledgerData: revLedger.toMap(),
            );
          }
        }
      }

      notifyListeners();
      _persistOrdersLocally();

      if (_orderRepository != null) {
        await _orderRepository!.deleteOrder(orderId);
      } else {
        // Supabase Cloud Sync
        final supaTid = currentTenantId ?? _tenant.tenantId;
        if (supaTid.isNotEmpty) {
          SupabaseService.instance.deleteOrder(
            tenantId: supaTid,
            orderId: orderId,
          );
        }

      }

      addNotification(
        NotificationModel(
          id: 'notif_ord_del_${DateTime.now().millisecondsSinceEpoch}',
          type: 'order',
          title: 'Order Deleted: #${removed.orderId}',
          message: 'Order #${removed.orderId} totaling ₹${removed.grandTotal.toStringAsFixed(0)} was removed.',
          createdAt: DateTime.now(),
        ),
      );
    }
  }

  Future<void> createInvoice(InvoiceModel invoice) async {
    if (!_invoices.any((i) => i.invoiceId == invoice.invoiceId)) {
      ensureCanWrite(feature: isEstimateInvoiceType(invoice.invoiceType) ? 'estimate_bills' : 'invoicing');
    }
    if (SupabaseService.instance.client != null) {
      await SupabaseService.instance.insertInvoice(tenantId: currentTenantId ?? _tenant.tenantId, invoiceData: invoice.toMap());
    }
    _invoices.insert(0, invoice);

    // Check if this invoice is fulfilling an existing order whose dues and stock were already recorded
    final hasExistingOrder = invoice.orderId.isNotEmpty &&
        _orders.any((o) => o.orderId == invoice.orderId);

    // 1. Update shop outstanding locally
    final shopIdx = _shops.indexWhere((s) => s.shopId == invoice.shopId);
    double newOutstanding = invoice.grandTotal;
    LedgerEntryModel? invoiceLedgerEntry;

    if (shopIdx != -1) {
      final old = _shops[shopIdx];
      // For an existing order the order total is already in the balance; only
      // the difference matters (e.g. it was billed at a different price tier).
      final orderTotal = hasExistingOrder
          ? _orders.firstWhere((o) => o.orderId == invoice.orderId).grandTotal
          : 0.0;
      newOutstanding = hasExistingOrder
          ? (old.currentOutstanding + (invoice.grandTotal - orderTotal)).clamp(0.0, double.infinity)
          : old.currentOutstanding + invoice.grandTotal;
      _shops[shopIdx] = old.copyWith(currentOutstanding: newOutstanding);

      // Add corresponding ledger entry locally
      invoiceLedgerEntry = LedgerEntryModel(
        ledgerId: 'LED-${DateTime.now().millisecondsSinceEpoch}',
        shopId: invoice.shopId,
        createdByUid: currentUid ?? 'user',
        type: 'INVOICE',
        referenceId: invoice.invoiceId,
        amount: invoice.grandTotal,
        balanceAfter: newOutstanding,
        description: 'Tax Invoice ${invoice.invoiceNumber} generated${hasExistingOrder ? " for Order #${invoice.orderId}" : ""}',
        date: invoice.invoiceDate,
      );
      _ledgerEntries.insert(0, invoiceLedgerEntry);
    }

    // 2. Decrement inventory stock locally only if not already decremented during addOrder
    if (!hasExistingOrder) {
      for (final item in invoice.items) {
        final prodIdx = _products.indexWhere((p) => p.productId == item.productId);
        if (prodIdx != -1) {
          final currentProd = _products[prodIdx];
          final updatedQty = (currentProd.stockQuantity - item.quantity).clamp(0, 999999);
          _products[prodIdx] = currentProd.copyWith(
            stockQuantity: updatedQty,
            updatedAt: DateTime.now(),
          );
        }
      }
    }

    notifyListeners();
    _persistInvoicesLocally();
    _persistShopsLocally();
    _persistLedgerLocally();
    _persistProductsLocally();

    if (SupabaseService.instance.client != null) return;

    // 4. Persist to Firestore: Invoice + Shop Balance + Ledger Entry + Stock Decrement
  }

  /// Process a Sales Return: automatically restocks items in inventory and credits the shop balance
  Future<void> processSalesReturn(SalesReturnModel salesReturn) async {
    if (_salesReturns.any((r) => r.returnId == salesReturn.returnId)) return;
    ensureCanWrite(feature: 'sales_returns');
    _salesReturns.insert(0, salesReturn);

    // 1. Automatically restore returned item quantities back into inventory stock
    int totalUnitsRestocked = 0;
    for (final item in salesReturn.items) {
      final prodIdx = _products.indexWhere((p) => p.productId == item.productId);
      if (prodIdx != -1) {
        final currentProd = _products[prodIdx];
        final updatedQty = currentProd.stockQuantity + item.quantity;
        totalUnitsRestocked += item.quantity;
        _products[prodIdx] = currentProd.copyWith(
          stockQuantity: updatedQty,
          updatedAt: DateTime.now(),
        );
      }
    }

    // 2. Adjust shop outstanding balance and record credit ledger entry
    final shopIdx = _shops.indexWhere((s) => s.shopId == salesReturn.shopId);
    double newOutstanding = 0.0;
    LedgerEntryModel? creditNoteLedgerEntry;

    if (shopIdx != -1) {
      final old = _shops[shopIdx];
      newOutstanding = (old.currentOutstanding - salesReturn.totalAmount).clamp(0.0, double.infinity);
      _shops[shopIdx] = old.copyWith(currentOutstanding: newOutstanding);

      creditNoteLedgerEntry = LedgerEntryModel(
        ledgerId: 'LED-RET-${DateTime.now().millisecondsSinceEpoch}',
        shopId: salesReturn.shopId,
        createdByUid: currentUid ?? 'user',
        type: 'CREDIT_NOTE',
        referenceId: salesReturn.returnId,
        amount: -salesReturn.totalAmount,
        balanceAfter: newOutstanding,
        description: 'Sales Return ${salesReturn.returnNumber} (${salesReturn.reason}) - $totalUnitsRestocked items restocked',
        date: salesReturn.date,
      );
      _ledgerEntries.insert(0, creditNoteLedgerEntry);
    }

    // 3. Emit notification
    _notifications.insert(
      0,
      NotificationModel(
        id: 'notif_ret_${DateTime.now().millisecondsSinceEpoch}',
        type: 'inventory',
        title: 'Sales Return Processed: ${salesReturn.returnNumber}',
        message: 'Restocked $totalUnitsRestocked items into inventory from ${salesReturn.shopName}. Credit of ₹${salesReturn.totalAmount.toStringAsFixed(2)} applied. Reason: ${salesReturn.reason}.',
        isRead: false,
        createdAt: DateTime.now(),
      ),
    );

    notifyListeners();
    _persistProductsLocally();
    _persistShopsLocally();
    _persistLedgerLocally();
    _persistNotificationsLocally();

    // 4. Persist to Firestore in atomic batch if online
  }

  Future<void> updateInvoice(InvoiceModel updated) async {
    final idx = _invoices.indexWhere((i) => i.invoiceId == updated.invoiceId);
    if (idx != -1) {
      final old = _invoices[idx];
      _invoices[idx] = updated;

      if ((updated.grandTotal - old.grandTotal).abs() > 0.001) {
        final diff = updated.grandTotal - old.grandTotal;
        final shopIdx = _shops.indexWhere((s) => s.shopId == updated.shopId);
        if (shopIdx != -1) {
          final oldShop = _shops[shopIdx];
          final newOutstanding = (oldShop.currentOutstanding + diff).clamp(0.0, 99999999.0);
          _shops[shopIdx] = oldShop.copyWith(currentOutstanding: newOutstanding);
          _persistShopsLocally();
          final supaTid = currentTenantId ?? _tenant.tenantId;
          if (supaTid.isNotEmpty) {
            SupabaseService.instance.updateShopOutstanding(
              tenantId: supaTid,
              shopId: updated.shopId,
              outstanding: newOutstanding,
            );
          }
        }
      }

      notifyListeners();
      _persistInvoicesLocally();

      final supaTid = currentTenantId ?? _tenant.tenantId;
      if (supaTid.isNotEmpty) {
        SupabaseService.instance.upsertInvoice(
          tenantId: supaTid,
          invoiceData: updated.toMap(),
        );
      }
    }
  }

  /// Deletes a bill / invoice with option to restore inventory stock and reverse customer balance
  Future<bool> deleteInvoice(String invoiceId, {bool restoreStock = true, bool reverseLedger = true}) async {
    final invIdx = _invoices.indexWhere((i) => i.invoiceId == invoiceId);
    if (invIdx == -1) return false;

    final invoice = _invoices[invIdx];
    if (SupabaseService.instance.client != null) {
      if (!restoreStock || !reverseLedger) throw StateError('Cloud invoice cancellation must reverse stock and ledger together.');
      await SupabaseService.instance.deleteInvoice(tenantId: currentTenantId ?? _tenant.tenantId, invoiceId: invoiceId);
    }
    _invoices.removeAt(invIdx);

    // 1. Revert shop outstanding balance locally
    final shopIdx = _shops.indexWhere((s) => s.shopId == invoice.shopId);
    double newOutstanding = 0.0;
    LedgerEntryModel? reversalLedgerEntry;

    if (shopIdx != -1 && reverseLedger) {
      final old = _shops[shopIdx];
      newOutstanding = (old.currentOutstanding - invoice.grandTotal).clamp(0.0, double.infinity);
      _shops[shopIdx] = old.copyWith(currentOutstanding: newOutstanding);

      reversalLedgerEntry = LedgerEntryModel(
        ledgerId: 'LED-REV-${DateTime.now().millisecondsSinceEpoch}',
        shopId: invoice.shopId,
        createdByUid: currentUid ?? 'user',
        type: 'INVOICE_CANCELLED',
        referenceId: invoice.invoiceId,
        amount: -invoice.grandTotal,
        balanceAfter: newOutstanding,
        description: 'Reversal: Bill ${invoice.invoiceNumber} deleted',
        date: DateTime.now(),
      );
      _ledgerEntries.insert(0, reversalLedgerEntry);
    }

    // 2. Restore inventory stock locally
    if (restoreStock) {
      for (final item in invoice.items) {
        final prodIdx = _products.indexWhere((p) => p.productId == item.productId);
        if (prodIdx != -1) {
          final currentProd = _products[prodIdx];
          final updatedQty = (currentProd.stockQuantity + item.quantity).clamp(0, 999999);
          _products[prodIdx] = currentProd.copyWith(
            stockQuantity: updatedQty,
            updatedAt: DateTime.now(),
          );
        }
      }
    }

    // Cancel associated order if present
    final ordIdx = _orders.indexWhere((o) => o.orderId == invoice.orderId);
    if (ordIdx != -1) {
      final ord = _orders[ordIdx];
      _orders[ordIdx] = ord.copyWith(status: 'cancelled', updatedAt: DateTime.now());
    }

    notifyListeners();
    _persistInvoicesLocally();
    _persistShopsLocally();
    _persistLedgerLocally();
    _persistProductsLocally();
    _persistOrdersLocally();

    if (SupabaseService.instance.client != null) return true;

    // 4. Persist deletion to Firestore

    return true;
  }

  Future<void> addOrder(OrderModel order, [InvoiceModel? invoice]) async {
    // Check up front so a blocked attempt never saves the bill without its order.
    if (!_orders.any((o) => o.orderId == order.orderId)) {
      ensureCanWrite(feature: 'order_taking');
      _ensureUnderLimit(
        used: ordersThisMonth,
        limit: maxAllowedOrdersPerMonth,
        message: 'Monthly Order Limit Reached: Your ${currentPlan.name} plan allows $maxAllowedOrdersPerMonth orders per month. '
            'Upgrade your plan in Plan & Pricing to take more orders.',
      );
    }
    if (invoice != null) {
      ensureCanWrite(feature: isEstimateInvoiceType(invoice.invoiceType) ? 'estimate_bills' : 'invoicing');
    }
    if (invoice != null) {
      await createInvoice(invoice);
      await createOrder(order);
    } else {
      await createOrder(order);
      // 1. Update shop outstanding balance locally so retailer dues reflect this receivable!
      final shopIdx = _shops.indexWhere((s) => s.shopId == order.shopId);
      double newOutstanding = order.grandTotal;
      LedgerEntryModel? orderLedgerEntry;

      if (shopIdx != -1) {
        final old = _shops[shopIdx];
        newOutstanding = old.currentOutstanding + order.grandTotal;
        _shops[shopIdx] = old.copyWith(currentOutstanding: newOutstanding);

        orderLedgerEntry = LedgerEntryModel(
          ledgerId: 'LED-ORD-${DateTime.now().millisecondsSinceEpoch}',
          shopId: order.shopId,
          createdByUid: order.createdByUid,
          type: 'ORDER',
          referenceId: order.orderId,
          amount: order.grandTotal,
          balanceAfter: newOutstanding,
          description: 'Order #${order.orderId} booked (${order.items.length} items)',
          date: order.placedAt ?? DateTime.now(),
        );
        _ledgerEntries.insert(0, orderLedgerEntry);
      }

      // 2. Deduct inventory stock locally for standalone orders without invoice
      final supaTid = currentTenantId ?? _tenant.tenantId;
      for (final item in order.items) {
        final prodIdx = _products.indexWhere((p) => p.productId == item.productId);
        if (prodIdx != -1) {
          final currentProd = _products[prodIdx];
          final updatedQty = (currentProd.stockQuantity - item.quantity).clamp(0, 999999);
          _products[prodIdx] = currentProd.copyWith(
            stockQuantity: updatedQty,
            updatedAt: DateTime.now(),
          );
          if (supaTid.isNotEmpty) {
            SupabaseService.instance.updateProductStock(
              tenantId: supaTid,
              productId: item.productId,
              stockQuantity: updatedQty,
            );
          }
        }
      }

      notifyListeners();
      _persistShopsLocally();
      _persistLedgerLocally();
      _persistProductsLocally();

      // 3. Supabase Cloud Sync: Shop Balance + Ledger
      if (supaTid.isNotEmpty && shopIdx != -1) {
        SupabaseService.instance.updateShopOutstanding(
          tenantId: supaTid,
          shopId: order.shopId,
          outstanding: newOutstanding,
        );
        if (orderLedgerEntry != null) {
          SupabaseService.instance.insertLedgerEntry(
            tenantId: supaTid,
            ledgerData: orderLedgerEntry.toMap(),
          );
        }
      }

      // 4. Firestore Cloud Sync
    }
  }

  bool _invoiceMatchesRef(InvoiceModel inv, String? ref) =>
      ref != null && ref.isNotEmpty && (inv.invoiceNumber == ref || inv.invoiceId == ref || inv.orderId == ref);

  /// Applies [amount] to a shop's open bills: the bill matching [targetRef]
  /// first, then oldest bill first. Returns the amount left over.
  double _allocateToInvoices(String shopId, double amount, {String? targetRef}) {
    double left = amount;
    final indices = <int>[
      for (int i = 0; i < _invoices.length; i++)
        if (_invoices[i].shopId == shopId && invoiceDue(_invoices[i]) > 0) i,
    ];
    indices.sort((a, b) {
      final ta = _invoiceMatchesRef(_invoices[a], targetRef) ? 0 : 1;
      final tb = _invoiceMatchesRef(_invoices[b], targetRef) ? 0 : 1;
      if (ta != tb) return ta.compareTo(tb);
      return _invoices[a].invoiceDate.compareTo(_invoices[b].invoiceDate);
    });
    for (final i in indices) {
      if (left <= 0.009) break;
      final inv = _invoices[i];
      final take = math.min(left, invoiceDue(inv));
      final newPaid = inv.paidAmount + take;
      final newDue = (inv.grandTotal - newPaid).clamp(0.0, double.infinity);
      _invoices[i] = inv.copyWith(
        paidAmount: newPaid,
        dueAmount: newDue,
        paymentStatus: newDue <= 0.01 ? 'paid' : 'partial',
        updatedAt: DateTime.now(),
      );
      _syncInvoiceToCloud(_invoices[i]);
      left -= take;
    }
    return left;
  }

  /// Reverses [amount] of bill payments for a shop (used when a payment is
  /// deleted or reduced): the bill matching [targetRef] first, then newest first.
  void _unallocateFromInvoices(String shopId, double amount, {String? targetRef}) {
    double left = amount;
    final indices = <int>[
      for (int i = 0; i < _invoices.length; i++)
        if (_invoices[i].shopId == shopId && _invoices[i].paidAmount > 0) i,
    ];
    indices.sort((a, b) {
      final ta = _invoiceMatchesRef(_invoices[a], targetRef) ? 0 : 1;
      final tb = _invoiceMatchesRef(_invoices[b], targetRef) ? 0 : 1;
      if (ta != tb) return ta.compareTo(tb);
      return _invoices[b].invoiceDate.compareTo(_invoices[a].invoiceDate);
    });
    for (final i in indices) {
      if (left <= 0.009) break;
      final inv = _invoices[i];
      final take = math.min(left, inv.paidAmount);
      final newPaid = inv.paidAmount - take;
      final newDue = (inv.grandTotal - newPaid).clamp(0.0, double.infinity);
      _invoices[i] = inv.copyWith(
        paidAmount: newPaid,
        dueAmount: newDue,
        paymentStatus: newDue <= 0.01 ? 'paid' : (newPaid > 0.009 ? 'partial' : 'unpaid'),
        updatedAt: DateTime.now(),
      );
      _syncInvoiceToCloud(_invoices[i]);
      left -= take;
    }
  }

  /// Best-effort reference a payment was collected against (invoice no. or order id).
  String? _paymentTargetRef(PaymentModel p) {
    for (final inv in _invoices.where((i) => i.shopId == p.shopId)) {
      if ((p.referenceNumber != null && p.referenceNumber == inv.invoiceNumber) ||
          (p.notes?.contains(inv.invoiceNumber) ?? false) ||
          (inv.orderId.isNotEmpty && (p.notes?.contains(inv.orderId) ?? false))) {
        return inv.invoiceNumber;
      }
    }
    return null;
  }

  void _syncInvoiceToCloud(InvoiceModel inv) {
    final supaTid = currentTenantId ?? _tenant.tenantId;
    if (supaTid.isNotEmpty && SupabaseService.instance.isInitialized) {
      SupabaseService.instance.upsertInvoice(tenantId: supaTid, invoiceData: inv.toMap());
    }
  }

  // Actions: Payments
  /// Records a payment. [targetRef] (invoice number or order id the payment was
  /// collected for) is paid off first. Pass [allocateToInvoices] = false when
  /// the bill was already created with this payment in its paidAmount (billing
  /// flow) — otherwise the same money would be applied twice.
  Future<void> recordPayment(
    PaymentModel payment, {
    String? targetRef,
    bool allocateToInvoices = true,
  }) async {
    if (!payment.amount.isFinite || payment.amount <= 0) throw ArgumentError('Payment must be a positive amount');
    if (_payments.any((p) => p.paymentId == payment.paymentId)) return;
    if (SupabaseService.instance.client != null) {
      await SupabaseService.instance.insertPayment(tenantId: currentTenantId ?? _tenant.tenantId, paymentData: payment.toMap());
    }
    _payments.insert(0, payment);

    // 1. Reduce shop outstanding locally
    final shopIdx = _shops.indexWhere((s) => s.shopId == payment.shopId);
    double newOutstanding = 0.0;
    LedgerEntryModel? paymentLedgerEntry;

    if (shopIdx != -1) {
      final old = _shops[shopIdx];
      newOutstanding = (old.currentOutstanding - payment.amount).clamp(0.0, double.infinity);
      _shops[shopIdx] = old.copyWith(currentOutstanding: newOutstanding);

      // Add payment ledger entry locally
      paymentLedgerEntry = LedgerEntryModel(
        ledgerId: 'LED-${DateTime.now().millisecondsSinceEpoch}',
        shopId: payment.shopId,
        createdByUid: payment.createdByUid,
        type: 'PAYMENT',
        referenceId: payment.paymentId,
        amount: -payment.amount,
        balanceAfter: newOutstanding,
        description: 'Payment collected via ${payment.paymentMode}${payment.referenceNumber != null ? " (${payment.referenceNumber})" : ""}',
        date: payment.date,
      );
      _ledgerEntries.insert(0, paymentLedgerEntry);
    }

    // 2. Liquid balance sync: update In-Hand Cash for cash collections, In-Account for UPI / online
    if (payment.paymentMode.toLowerCase().contains('cash')) {
      _inHandCash += payment.amount;
    } else {
      _inAccountBalance += payment.amount;
    }
    _syncBalancesToFirestore();

    // 3. Reconcile unpaid / partial invoices for this customer. A payment
    //    collected for a specific unbilled order stays with that order (it is
    //    tracked as order credit, see getUnbilledOrderPaidAmounts).
    final targetsUnbilledOrder = targetRef != null &&
        _orders.any((o) => o.orderId == targetRef && o.shopId == payment.shopId && _isUnbilledOpenOrder(o));
    if (allocateToInvoices) {
      if (!targetsUnbilledOrder) {
        _allocateToInvoices(payment.shopId, payment.amount, targetRef: targetRef);
      } else {
        // Anything beyond what the shop's unbilled orders can absorb pays bills.
        final absorbedByOrders = getUnbilledOrderPaidAmounts(payment.shopId)
            .values
            .fold<double>(0.0, (a, b) => a + b);
        final overflow = getShopUnallocatedCredit(payment.shopId) - absorbedByOrders;
        if (overflow > 0.009) _allocateToInvoices(payment.shopId, overflow);
      }
    }

    // 3b. Reconcile matching order if specified in notes or reference
    bool orderUpdated = false;
    for (int i = 0; i < _orders.length; i++) {
      final ord = _orders[i];
      if (ord.shopId == payment.shopId && ord.status == 'pending') {
        final matchesNote = payment.notes != null && payment.notes!.contains(ord.orderId);
        final matchesRef = payment.referenceNumber != null && payment.referenceNumber!.contains(ord.orderId);
        if (matchesNote || matchesRef) {
          _orders[i] = ord.copyWith(
            status: 'confirmed',
            updatedAt: DateTime.now(),
          );
          orderUpdated = true;
          final supaTid = currentTenantId ?? _tenant.tenantId;
          if (supaTid.isNotEmpty) {
            SupabaseService.instance.updateOrderStatus(
              tenantId: supaTid,
              orderId: ord.orderId,
              status: 'confirmed',
            );
          }
          break;
        }
      }
    }
    if (orderUpdated) {
      _persistOrdersLocally();
    }

    notifyListeners();
    _persistPaymentsLocally();
    _persistShopsLocally();
    _persistLedgerLocally();
    _persistInvoicesLocally();

    if (SupabaseService.instance.client != null) return;

    // 5. Persist to Firestore: Payment + Shop Balance + Ledger Entry

    // Sync balance in repository cache
    if (_shopRepository != null) {
      await _shopRepository!.updateOutstandingBalance(payment.shopId, -payment.amount);
    }
  }

  /// Reverses an accidental payment, restoring customer dues and liquid balances
  Future<bool> deletePayment(String paymentId) async {
    final idx = _payments.indexWhere((p) => p.paymentId == paymentId);
    if (idx == -1) return false;

    final payment = _payments[idx];
    // Whatever part of this payment was absorbed by bills must be taken back
    // off those bills (unabsorbed credit simply disappears with the payment).
    final creditBefore = getShopUnallocatedCredit(payment.shopId);
    final targetRef = _paymentTargetRef(payment);
    _payments.removeAt(idx);
    final toUnapply = payment.amount - creditBefore;
    if (toUnapply > 0.009) {
      _unallocateFromInvoices(payment.shopId, toUnapply, targetRef: targetRef);
    }

    // 1. Revert shop balance (increase outstanding)
    final shopIdx = _shops.indexWhere((s) => s.shopId == payment.shopId);
    double newOutstanding = 0.0;
    if (shopIdx != -1) {
      final old = _shops[shopIdx];
      newOutstanding = (old.currentOutstanding + payment.amount).clamp(0.0, double.infinity);
      _shops[shopIdx] = old.copyWith(currentOutstanding: newOutstanding);

      // Reversal ledger entry
      final reversalLedger = LedgerEntryModel(
        ledgerId: 'LED-PAY-REV-${DateTime.now().millisecondsSinceEpoch}',
        shopId: payment.shopId,
        createdByUid: currentUid ?? 'user',
        type: 'PAYMENT_CANCELLED',
        referenceId: payment.paymentId,
        amount: payment.amount,
        balanceAfter: newOutstanding,
        description: 'Reversal: Payment of ₹${payment.amount.toStringAsFixed(0)} cancelled',
        date: DateTime.now(),
      );
      _ledgerEntries.insert(0, reversalLedger);
    }

    // 2. Revert liquid balance
    if (payment.paymentMode.toLowerCase().contains('cash')) {
      _inHandCash = (_inHandCash - payment.amount).clamp(0.0, double.infinity);
    } else {
      _inAccountBalance = (_inAccountBalance - payment.amount).clamp(0.0, double.infinity);
    }
    _syncBalancesToFirestore();

    notifyListeners();
    _persistPaymentsLocally();
    _persistShopsLocally();
    _persistLedgerLocally();
    _persistInvoicesLocally();

    final supaTid = currentTenantId ?? _tenant.tenantId;
    if (supaTid.isNotEmpty && SupabaseService.instance.isInitialized) {
      SupabaseService.instance.deletePayment(
        tenantId: supaTid,
        paymentId: paymentId,
      );
    }

    return true;
  }

  Future<bool> updatePayment(PaymentModel updated) async {
    final idx = _payments.indexWhere((p) => p.paymentId == updated.paymentId);
    if (idx == -1) return false;

    final old = _payments[idx];
    final creditBefore = getShopUnallocatedCredit(old.shopId);
    final targetRef = _paymentTargetRef(old);
    _payments[idx] = updated;

    // 1. Balance difference: more paid => less outstanding
    final diff = updated.amount - old.amount;

    // 1a. Keep bill paid/due figures in step with the edited amount.
    if (diff > 0.009) {
      _allocateToInvoices(updated.shopId, diff, targetRef: targetRef);
    } else if (diff < -0.009) {
      final toUnapply = -diff - creditBefore;
      if (toUnapply > 0.009) {
        _unallocateFromInvoices(updated.shopId, toUnapply, targetRef: targetRef);
      }
    }
    final shopIdx = _shops.indexWhere((s) => s.shopId == updated.shopId);
    if (shopIdx != -1) {
      final oldShop = _shops[shopIdx];
      final newOutstanding = (oldShop.currentOutstanding - diff).clamp(0.0, 99999999.0);
      _shops[shopIdx] = oldShop.copyWith(currentOutstanding: newOutstanding);
      final supaTid = currentTenantId ?? _tenant.tenantId;
      if (supaTid.isNotEmpty) {
        SupabaseService.instance.updateShopOutstanding(
          tenantId: supaTid,
          shopId: updated.shopId,
          outstanding: newOutstanding,
        );
      }
    }

    // 2. Liquid balances
    if (old.paymentMode.toLowerCase().contains('cash')) {
      _inHandCash = (_inHandCash - old.amount).clamp(0.0, double.infinity);
    } else {
      _inAccountBalance = (_inAccountBalance - old.amount).clamp(0.0, double.infinity);
    }
    if (updated.paymentMode.toLowerCase().contains('cash')) {
      _inHandCash += updated.amount;
    } else {
      _inAccountBalance += updated.amount;
    }
    _syncBalancesToFirestore();

    notifyListeners();
    _persistPaymentsLocally();
    _persistShopsLocally();
    _persistInvoicesLocally();

    final supaTid = currentTenantId ?? _tenant.tenantId;
    if (supaTid.isNotEmpty && SupabaseService.instance.isInitialized) {
      SupabaseService.instance.upsertPayment(
        tenantId: supaTid,
        paymentData: updated.toMap(),
      );
    }
    return true;
  }

  // Actions: Visits
  Future<void> addVisit(VisitModel visit) async {
    ensureCanWrite(feature: 'visits');
    _visits.insert(0, visit);
    notifyListeners();
    _persistVisitsLocally();

    final supaTid = currentTenantId ?? _tenant.tenantId;
    if (supaTid.isNotEmpty && SupabaseService.instance.isInitialized) {
      SupabaseService.instance.upsertVisit(
        tenantId: supaTid,
        visitData: visit.toMap(),
      );
    }
  }

  Future<void> updateVisit(VisitModel updated) async {
    final idx = _visits.indexWhere((v) => v.visitId == updated.visitId);
    if (idx != -1) {
      _visits[idx] = updated;
      notifyListeners();
      _persistVisitsLocally();

      final supaTid = currentTenantId ?? _tenant.tenantId;
      if (supaTid.isNotEmpty && SupabaseService.instance.isInitialized) {
        SupabaseService.instance.upsertVisit(
          tenantId: supaTid,
          visitData: updated.toMap(),
        );
      }
    }
  }

  Future<void> deleteVisit(String visitId) async {
    _visits.removeWhere((v) => v.visitId == visitId);
    notifyListeners();
    _persistVisitsLocally();

    final supaTid = currentTenantId ?? _tenant.tenantId;
    if (supaTid.isNotEmpty && SupabaseService.instance.isInitialized) {
      SupabaseService.instance.deleteVisit(
        tenantId: supaTid,
        visitId: visitId,
      );
    }
  }

  Future<void> completeVisit(String visitId) async {
    final idx = _visits.indexWhere((v) => v.visitId == visitId);
    if (idx != -1) {
      final old = _visits[idx];
      _visits[idx] = VisitModel(
        visitId: old.visitId,
        shopId: old.shopId,
        distributorUid: old.distributorUid,
        checkInTime: old.checkInTime,
        checkOutTime: DateTime.now(),
        latitude: old.latitude,
        longitude: old.longitude,
        notes: old.notes,
        photoUrl: old.photoUrl,
        orderPlaced: old.orderPlaced,
      );
      notifyListeners();
      _persistVisitsLocally();
    }

  }

  // Actions: Reminders
  Future<void> addReminder(ReminderModel reminder) async {
    ensureCanWrite(feature: 'visits');
    _reminders.insert(0, reminder);
    notifyListeners();
    _persistRemindersLocally();
    final supaTid = currentTenantId ?? _tenant.tenantId;
    if (supaTid.isNotEmpty && SupabaseService.instance.isInitialized) {
      SupabaseService.instance.insertReminder(
        tenantId: supaTid,
        reminderData: reminder.toMap(),
      );
    }

  }

  Future<void> completeReminder(String reminderId) async {
    final idx = _reminders.indexWhere((r) => r.reminderId == reminderId);
    if (idx != -1) {
      final old = _reminders[idx];
      _reminders[idx] = old.copyWith(isCompleted: true);
      notifyListeners();
      _persistRemindersLocally();
    }

  }

  Future<void> toggleReminder(String reminderId) async {
    final idx = _reminders.indexWhere((r) => r.reminderId == reminderId);
    if (idx != -1) {
      final newStatus = !_reminders[idx].isCompleted;
      _reminders[idx] = _reminders[idx].copyWith(isCompleted: newStatus);
      notifyListeners();
      _persistRemindersLocally();

    }
  }

  Future<void> rescheduleReminder(String reminderId, DateTime newDueDate) async {
    final idx = _reminders.indexWhere((r) => r.reminderId == reminderId);
    if (idx != -1) {
      _reminders[idx] = _reminders[idx].copyWith(dueDate: newDueDate, isCompleted: false);
      notifyListeners();
      _persistRemindersLocally();

    }
  }

  Future<void> updateReminder(ReminderModel updated) async {
    final idx = _reminders.indexWhere((r) => r.reminderId == updated.reminderId);
    if (idx != -1) {
      _reminders[idx] = updated;
      notifyListeners();
      _persistRemindersLocally();

    }
  }

  Future<void> deleteReminder(String reminderId) async {
    _reminders.removeWhere((r) => r.reminderId == reminderId);
    notifyListeners();
    _persistRemindersLocally();

  }

  // Actions: Tenant Update
  /// Set when the last profile / business-details save reached this phone
  /// but not the cloud (shown to the user; cleared on the next good save).
  String? lastTenantSyncError;

  Future<void> updateTenant(TenantModel updated, {bool clearProfileImage = false, bool clearLogo = false}) async {
    lastTenantSyncError = null;
    final resolvedProfileImage = (updated.profileImageUrl != null && updated.profileImageUrl!.trim().isNotEmpty)
        ? updated.profileImageUrl
        : (clearProfileImage ? null : _tenant.profileImageUrl);
    final resolvedLogo = (updated.logoUrl != null && updated.logoUrl!.trim().isNotEmpty)
        ? updated.logoUrl
        : (clearLogo ? null : _tenant.logoUrl);

    final mergedWithExisting = updated.copyWith(
      upiId: (updated.upiId != null && updated.upiId!.trim().isNotEmpty)
          ? updated.upiId
          : _tenant.upiId,
      paymentGatewayConfig: (updated.paymentGatewayConfig != null && updated.paymentGatewayConfig!.isNotEmpty)
          ? updated.paymentGatewayConfig
          : _tenant.paymentGatewayConfig,
      hardwareConfig: updated.hardwareConfig ?? _tenant.hardwareConfig,
      bankAccount: updated.bankAccount ?? _tenant.bankAccount,
      profileImageUrl: resolvedProfileImage,
      logoUrl: resolvedLogo,
      clearProfileImage: clearProfileImage,
      clearLogo: clearLogo,
    );
    _tenant = mergedWithExisting;
    if (mergedWithExisting.isGstBillingEnabled != null) {
      _isGstBillingEnabled = mergedWithExisting.isGstBillingEnabled!;
    }
    if (clearProfileImage) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('salesarmy_pref_profile_image_url_v2');
      } catch (e) { debugPrint('Clear profile image pref: $e'); }
    }
    if (clearLogo) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('salesarmy_pref_logo_url_v2');
      } catch (e) { debugPrint('Clear logo pref: $e'); }
    }

    await _persistTenantLocally(mergedWithExisting);
    notifyListeners();

    final tid = currentTenantId ?? updated.tenantId;

    // 1. Dual Cloud Sync: Supabase Platform & Database
    try {
      final supa = SupabaseService.instance;
      if (supa.client != null && tid.isNotEmpty) {
        // Sync public.tenants
        try {
          await supa.client!.from('tenants').update({
            if (updated.firmName != null) 'business_name': updated.firmName,
            if (updated.representativeName != null) 'contact_person': updated.representativeName,
            if (updated.mobile != null) 'mobile': updated.mobile,
            if (updated.email != null) 'email': updated.email,
            if (updated.gstin != null) 'gstin': updated.gstin,
            if (updated.pan != null) 'pan': updated.pan,
            if (updated.fssaiLicenseNo != null) 'fssai': updated.fssaiLicenseNo,
            if (updated.warehouseAddress != null) 'warehouse_address': updated.warehouseAddress,
            if (updated.warehouseAddress != null) 'address': updated.warehouseAddress,
            if (updated.city != null) 'city': updated.city,
            if (updated.state != null) 'state': updated.state,
            if (updated.pincode != null) 'pincode': updated.pincode,
            if (updated.territory != null) 'territory': updated.territory,
            // Plan / status / dates / is_active are server-managed (checkout or
            // super admin). Only a super admin session may write them.
            if ((isSuperAdminUser || isSuperAdminMode) && updated.subscriptionPlanId != null) 'plan_id': updated.subscriptionPlanId,
            if ((isSuperAdminUser || isSuperAdminMode) && updated.subscriptionStatus != null) 'subscription_status': updated.subscriptionStatus,
            if ((isSuperAdminUser || isSuperAdminMode) && updated.subscriptionEndDate != null) 'subscription_end_date': updated.subscriptionEndDate!.toIso8601String(),
            if (isSuperAdminUser || isSuperAdminMode) 'is_active': updated.subscriptionStatus != 'suspended',
            'logo_url': updated.logoUrl,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('tenant_id', tid);
        } catch (e) {
          debugPrint('Supabase tenants update notice: $e');
          lastTenantSyncError = 'Saved on this phone, but the cloud update failed. It will retry when you save again.';
        }

        // Sync durable JSON config to platform_settings
        try {
          await supa.savePlatformSettings('tenant_profile_$tid', updated.toJsonMap());
        } catch (e) {
          debugPrint('Supabase platform_settings update notice: $e');
        }

        // Sync public.profiles for user name & avatar
        final uid = currentUid ?? supa.currentUser?.id;
        if (uid != null && uid.isNotEmpty) {
          try {
            await supa.client!.from('profiles').update({
              if (updated.representativeName != null) 'name': updated.representativeName,
              if (updated.mobile != null) 'phone': updated.mobile,
              if (updated.email != null) 'email': updated.email,
              'photo_url': updated.profileImageUrl ?? updated.logoUrl,
              'updated_at': DateTime.now().toIso8601String(),
            }).eq('id', uid);
          } catch (e) {
            debugPrint('Supabase profiles update notice: $e');
          }
        }
      }
    } catch (supaErr) {
      debugPrint('Supabase overall updateTenant notice: $supaErr');
    }

    // 2. Dual Cloud Sync: Firestore (Selective map avoiding restricted governance fields)

    // 3. Sync to Admin Bridge Server
    await syncTenantToServerBridge();
    await syncUserToServerBridge();
  }

  // Action: Distributor Setting - Toggle GST Billing (On/Off)
  Future<void> setGstBillingEnabled(bool enabled) async {
    _isGstBillingEnabled = enabled;
    _tenant = _tenant.copyWith(isGstBillingEnabled: enabled);
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('salesarmy_pref_gst_billing_enabled_v1', enabled);
    } catch (e) { debugPrint('Persist GST billing pref: $e'); }

    final tid = currentTenantId ?? _tenant.tenantId;
    if (tid.isNotEmpty) {
      try {
        await SupabaseService.instance.savePlatformSettings('gst_billing_$tid', {
          'is_gst_billing_enabled': enabled,
          'tenant_id': tid,
          'updated_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        debugPrint('Supabase setGstBillingEnabled sync note: $e');
      }
    }

  }

  // ==========================================
  // CMS Feedback Ingest & Data Source Pipeline
  // ==========================================
  final List<String> _cmsFeedbackCategories = [
    'General Experience',
    'Billing & Invoicing',
    'Catalog & Stock',
    'Thermal Printing',
    'Performance & Speed',
    'Feature Request',
  ];
  List<String> get cmsFeedbackCategories => List.unmodifiable(_cmsFeedbackCategories);

  String _cmsFeedbackPrompt =
      'Help shape the next update! Share what you love or what needs improvement in your daily distribution workflow.';
  String get cmsFeedbackPrompt => _cmsFeedbackPrompt;

  void updateCmsFeedbackConfig({List<String>? categories, String? prompt}) {
    if (categories != null && categories.isNotEmpty) {
      _cmsFeedbackCategories.clear();
      _cmsFeedbackCategories.addAll(categories);
    }
    if (prompt != null && prompt.trim().isNotEmpty) {
      _cmsFeedbackPrompt = prompt.trim();
    }
    notifyListeners();
  }

  final List<Map<String, dynamic>> _submittedFeedbackList = [];
  List<Map<String, dynamic>> get submittedFeedbackList => List.unmodifiable(_submittedFeedbackList);

  Future<bool> submitFeedbackToCms({
    required int rating,
    required String category,
    required String comments,
    bool requestFollowUp = false,
  }) async {
    final entry = {
      'feedbackId': 'FDB-${DateTime.now().millisecondsSinceEpoch}',
      'tenantId': currentTenantId ?? _tenant.tenantId,
      'userId': _uniqueUserId,
      'userPhone': _tenant.mobile ?? '',
      'firmName': _tenant.firmName ?? '',
      'rating': rating,
      'category': category,
      'comments': comments.trim(),
      'requestFollowUp': requestFollowUp,
      'submittedAt': DateTime.now().toIso8601String(),
      'appVersion': minAppVersion,
      'source': 'mobile_app_cms',
    };
    _submittedFeedbackList.insert(0, entry);
    notifyListeners();

    return true;
  }

  // Super Admin Synchronization: Update Current Tenant Account Status
  Future<void> updateTenantStatus(String newStatus) async {
    final tid = currentTenantId ?? _tenant.tenantId;
    await updateAnyTenantStatus(tid, newStatus);
  }

  // Super Admin Synchronization: Update Any Tenant Account Status
  Future<void> updateAnyTenantStatus(String tenantId, String newStatus) async {
    final client = SupabaseService.instance.client;
    if (client != null) {
      final rows = await client.from('tenants').update({
        'subscription_status': newStatus.toLowerCase(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('tenant_id', tenantId).select('tenant_id');
      if (rows.isEmpty) throw StateError('Tenant was not found or access was denied.');
    }
    if (tenantId == currentTenantId || tenantId == _tenant.tenantId) {
      _tenant = _tenant.copyWith(
        accountStatus: newStatus.toLowerCase(),
        subscriptionStatus: newStatus.toLowerCase() == 'active' ? 'active' : newStatus.toLowerCase(),
        updatedAt: DateTime.now(),
      );
      notifyListeners();
    }

  }

  // Super Admin Synchronization: Purge Cash History
  Future<void> purgeCashHistoryForTenant(String tenantId) async {
    _orders.removeWhere((o) => (o.deliveryNote?.toLowerCase().contains('cash') ?? false));
    _payments.removeWhere((p) => p.paymentMode.toLowerCase() == 'cash');
    _ledgerEntries.removeWhere((l) => l.description.toLowerCase().contains('cash'));
    notifyListeners();

  }

  // Super Admin Synchronization: Full Account Reset
  Future<void> resetUserAccountForTenant(String tenantId) async {
    _orders.clear();
    _invoices.clear();
    _payments.clear();
    _ledgerEntries.clear();
    _visits.clear();
    _reminders.clear();
    for (int i = 0; i < _shops.length; i++) {
      final s = _shops[i];
      _shops[i] = s.copyWith(currentOutstanding: 0.0);
    }
    notifyListeners();

  }

  /// Kaccha / estimate bill types (vs GST tax invoices).
  static bool isEstimateInvoiceType(String? type) {
    final t = (type ?? '').toLowerCase();
    return t == 'non_gst' || t == 'estimate' || t == 'estimated' || t == 'kaccha';
  }

  /// Why bills / orders cannot be created right now (null = allowed). Checked
  /// BEFORE anything is saved so a blocked attempt never leaves half-created
  /// bills behind.
  String? get billingBlockReason {
    final reason = writeBlockReason();
    if (reason != null) return reason;
    if (!planIncludes('order_taking') && !planIncludes('invoicing') && !planIncludes('estimate_bills')) {
      return 'Billing is not included in your ${currentPlan.name} plan. Upgrade in Plan & Pricing to create bills.';
    }
    return null;
  }

  /// Throws [BillingBlockedException] when billing is not allowed.
  void ensureCanCreateBills() {
    final reason = billingBlockReason;
    if (reason != null) throw PlanRestrictionException(reason, readOnly: isReadOnlyMode);
  }

  // Platform Security & SMS Gateway Configuration (FR-AUTH-3, FR-AUTH-4)
  bool _enforceMobileOtp = false;
  bool get enforceMobileOtp => _enforceMobileOtp;
  void setEnforceMobileOtp(bool val) {
    _enforceMobileOtp = val;
    notifyListeners();
    updatePlatformGeneralSettings(enforceMobileOtp: val);
  }

  String _smsProvider = 'Fast2SMS';
  String get smsProvider => _smsProvider;

  String _smsGatewayMode = 'Live';
  String get smsGatewayMode => _smsGatewayMode;

  int _otpDigits = 6;
  int get otpDigits => _otpDigits;

  Future<void> updateSmsGatewayConfig({
    String? provider,
    String? mode,
    bool? enforceOtp,
    int? digits,
  }) async {
    if (provider != null) _smsProvider = provider;
    if (mode != null) _smsGatewayMode = mode;
    if (enforceOtp != null) _enforceMobileOtp = enforceOtp;
    if (digits != null) _otpDigits = digits;
    notifyListeners();

    await updatePlatformGeneralSettings(
      smsProvider: _smsProvider,
      smsGatewayMode: _smsGatewayMode,
      enforceMobileOtp: _enforceMobileOtp,
      otpDigits: _otpDigits,
    );
  }

  // Real-Time Plan Pricing & Printer Options Synchronization (Super Admin -> All Subscribers)
  Future<void> updatePlanPricing({
    double? monthlyPlanPrice,
    double? annualPlanPrice,
    double? planGstRate,
    double? printerHardwarePrice,
    double? printerGstRate,
    bool? applyGstOnInvoices,
    double? deliveryFee,
    List<SubscriptionPlanModel>? plans,
    List<PrinterOptionModel>? printerOptions,
  }) async {
    if (monthlyPlanPrice != null) _monthlyPlanPrice = monthlyPlanPrice;
    if (annualPlanPrice != null) _annualPlanPrice = annualPlanPrice;
    if (planGstRate != null) _planGstRate = planGstRate;
    if (printerHardwarePrice != null) _printerHardwarePrice = printerHardwarePrice;
    if (printerGstRate != null) _printerGstRate = printerGstRate;
    if (applyGstOnInvoices != null) _applyGstOnInvoices = applyGstOnInvoices;
    if (deliveryFee != null) _deliveryFee = deliveryFee;
    if (plans != null) {
      _subscriptionPlans.clear();
      _subscriptionPlans.addAll(plans);
    }
    if (printerOptions != null) {
      _printerOptions.clear();
      _printerOptions.addAll(printerOptions);
    }
    notifyListeners();

    // Supabase platform_settings persistence
    try {
      final pricingData = {
        'monthlyPlanPrice': _monthlyPlanPrice,
        'annualPlanPrice': _annualPlanPrice,
        'planGstRate': _planGstRate,
        'printerHardwarePrice': _printerHardwarePrice,
        'printerGstRate': _printerGstRate,
        'applyGstOnInvoices': _applyGstOnInvoices,
        'deliveryFee': _deliveryFee,
        'plans': {'tiers': _subscriptionPlans.map((p) => p.toMap()).toList(), 'planGst': _planGstRate, 'printerGst': _printerGstRate, 'printerPrice': _printerHardwarePrice},
        'printerOptions': _printerOptions.map((pr) => pr.toMap()).toList(),
        'coupons': _coupons.map((c) => c.toMap()).toList(),
        'subscriptionAddons': _subscriptionAddons.map((a) => a.toMap()).toList(),
        'updatedAt': DateTime.now().toIso8601String(),
      };
      await SupabaseService.instance.savePlatformSettings('pricing_and_plans', pricingData);
    } catch (e) {
      debugPrint('Supabase updatePlanPricing note: $e');
      rethrow;
    }

  }

  // Maintenance Mode (Super Admin -> All Subscribers)
  Future<void> setMaintenanceMode(bool enable) async {
    _maintenanceMode = enable;
    notifyListeners();

    await updatePlatformGeneralSettings(maintenanceMode: enable);
  }

  Future<void> updatePlatformGeneralSettings({
    bool? enforceMobileOtp,
    String? smsProvider,
    String? smsGatewayMode,
    int? otpDigits,
    bool? maintenanceMode,
    String? minAppVersion,
  }) async {
    if (enforceMobileOtp != null) _enforceMobileOtp = enforceMobileOtp;
    if (smsProvider != null) _smsProvider = smsProvider;
    if (smsGatewayMode != null) _smsGatewayMode = smsGatewayMode;
    if (otpDigits != null) _otpDigits = otpDigits;
    if (maintenanceMode != null) _maintenanceMode = maintenanceMode;
    if (minAppVersion != null) _minAppVersion = minAppVersion;
    notifyListeners();

    await SupabaseService.instance.savePlatformSettings('general_settings', {
      ...?await SupabaseService.instance.fetchPlatformSettings('general_settings'),
      'enforceMobileOtp': _enforceMobileOtp, 'smsProvider': _smsProvider,
      'smsGatewayMode': _smsGatewayMode, 'otpDigits': _otpDigits,
      'maintenanceMode': _maintenanceMode, 'minAppVersion': _minAppVersion,
    });
  }

  // Payment Gateway Configuration
  Future<void> updatePaymentGatewayConfig({
    String? provider,
    String? mode,
    bool? enabled,
    String? apiKey,
    String? upiId,
    String? companyName,
    String? gstin,
  }) async {
    await SupabaseService.instance.savePlatformSettings('paymentGateway', {
      ...?await SupabaseService.instance.fetchPlatformSettings('paymentGateway'),
      if (provider != null) 'provider': provider,
      if (mode != null) 'mode': mode,
      if (enabled != null) 'enabled': enabled,
      if (apiKey != null) 'apiKey': apiKey,
      if (upiId != null) 'adminUpiId': upiId,
    });
    if (companyName != null || gstin != null) {
      await SupabaseService.instance.savePlatformSettings('company', {
        ...?await SupabaseService.instance.fetchPlatformSettings('company'),
        if (companyName != null) 'companyName': companyName,
        if (gstin != null) 'gstin': gstin,
      });
    }
  }

  // Trigger Instant Database Backup
  Future<void> triggerInstantBackup() async {
    final result = await PlatformApi.request('/api/platform/backup', body: {});
    if (result['success'] != true || result['sha256'] == null) throw StateError('Backup was not verified');
    _lastBackupDate = DateTime.now();
    notifyListeners();
  }

  // Super Admin Sync Bundle - Cross-Platform Data Bridge (Web Admin <-> Mobile App)
  Map<String, dynamic> exportAdminSyncBundle() {
    return {
      'exportTimestamp': DateTime.now().toIso8601String(),
      'platform': 'SalesArmy Mobile Flutter App Sync Engine',
      'coupons': _coupons.map((c) => c.toMap()).toList(),
      'plans': {
        'monthlyPlanPrice': _monthlyPlanPrice,
        'annualPlanPrice': _annualPlanPrice,
        'planGstRate': _planGstRate,
        'printerHardwarePrice': _printerHardwarePrice,
        'printerGstRate': _printerGstRate,
        'applyGstOnInvoices': _applyGstOnInvoices,
        'deliveryFee': _deliveryFee,
      },
      'remoteFeatureFlags': _remoteFeatureFlags,
      'emergencyBroadcast': _emergencyBroadcast,
      'tenants': [_tenant.toMap()],
      'uniqueUserId': _uniqueUserId,
      'maintenance': {
        'active': _maintenanceMode,
        'message': _maintenanceMessage,
        'eta': _maintenanceEta,
      },
      'settings': {
        'maintenanceMode': _maintenanceMode,
        'enforceMobileOtp': _enforceMobileOtp,
        'smsProvider': _smsProvider,
        'smsGatewayMode': _smsGatewayMode,
        'otpDigits': _otpDigits,
        'minAppVersion': _minAppVersion,
      },
    };
  }

  Future<void> pushRemoteConfigToPlatform({
    Map<String, bool>? featureFlags,
    Map<String, dynamic>? maintenance,
    String? minAppVersion,
    String? smsProvider,
    int? otpDigits,
    String? smsMode,
    bool? enforceOtp,
  }) async {
    if (featureFlags != null) updateRemoteFeatureFlags(featureFlags);
    if (maintenance != null) {
      setMaintenanceDetails(
        isMaintenance: maintenance['active'] == true,
        message: maintenance['message']?.toString(),
        eta: maintenance['eta']?.toString(),
      );
    }
    if (minAppVersion != null) _minAppVersion = minAppVersion;
    if (smsProvider != null) _smsProvider = smsProvider;
    if (otpDigits != null) _otpDigits = otpDigits;
    if (smsMode != null) _smsGatewayMode = smsMode;
    if (enforceOtp != null) _enforceMobileOtp = enforceOtp;
    notifyListeners();

    await SupabaseService.instance.savePlatformSettings('remote_config', {
      'featureFlags': _remoteFeatureFlags,
      'maintenance': {'active': _maintenanceMode, 'message': _maintenanceMessage, 'eta': _maintenanceEta},
      'minAppVersion': _minAppVersion, 'smsProvider': _smsProvider,
      'otpDigits': _otpDigits, 'smsMode': _smsGatewayMode, 'enforceOtp': _enforceMobileOtp,
    });
  }

  Future<void> pushBroadcastToPlatform(Map<String, dynamic>? broadcastData) async {
    await SupabaseService.instance.savePlatformSettings('broadcast', broadcastData ?? {'active': false});
    setEmergencyBroadcast(broadcastData);
  }

  void importAdminSyncBundle(Map<String, dynamic> bundle) {
    if (bundle['coupons'] is List) {
      _coupons.clear();
      for (final item in bundle['coupons']) {
        if (item is Map<String, dynamic>) {
          _coupons.add(CouponModel.fromMap(item));
        }
      }
    }
    if (bundle['plans'] is Map) {
      final p = bundle['plans'] as Map<String, dynamic>;
      final m = (p['monthlyPlanPrice'] as num?)?.toDouble() ??
                (p['silverPrice'] as num?)?.toDouble();
      final a = (p['annualPlanPrice'] as num?)?.toDouble() ??
                ((p['platinumPrice'] as num?) != null ? ((p['platinumPrice'] as num).toDouble() / 12) : null);
      final g = (p['planGstRate'] as num?)?.toDouble() ?? (p['planGst'] as num?)?.toDouble();
      final pr = (p['printerHardwarePrice'] as num?)?.toDouble() ?? (p['printerPrice'] as num?)?.toDouble();
      final prg = (p['printerGstRate'] as num?)?.toDouble() ?? (p['printerGst'] as num?)?.toDouble();
      final apply = p['applyGstOnInvoices'] as bool?;
      if (m != null) _monthlyPlanPrice = m;
      if (a != null) _annualPlanPrice = a;
      if (g != null) _planGstRate = g;
      if (pr != null) _printerHardwarePrice = pr;
      if (prg != null) _printerGstRate = prg;
      if (apply != null) _applyGstOnInvoices = apply;
      if (p['tiers'] is List) {
        _subscriptionPlans..clear()..addAll((p['tiers'] as List).whereType<Map>().map((v) => SubscriptionPlanModel.fromMap(Map<String, dynamic>.from(v), v['id'].toString())));
      }
    }
    if (bundle['remoteFeatureFlags'] is Map) {
      final rf = (bundle['remoteFeatureFlags'] as Map).map(
        (k, v) => MapEntry(k.toString(), v == true),
      );
      updateRemoteFeatureFlags(rf);
    }
    if (bundle['remoteConfig'] is Map) {
      final rc = bundle['remoteConfig'] as Map<String, dynamic>;
      if (rc['featureFlags'] is Map) {
        final rf = (rc['featureFlags'] as Map).map(
          (k, v) => MapEntry(k.toString(), v == true),
        );
        updateRemoteFeatureFlags(rf);
      }
      if (rc['maintenance'] is Map) {
        final m = rc['maintenance'] as Map<String, dynamic>;
        setMaintenanceDetails(
          isMaintenance: m['active'] == true,
          message: m['message']?.toString(),
          eta: m['eta']?.toString(),
        );
      }
      if (rc['minAppVersion'] != null) _minAppVersion = rc['minAppVersion'].toString();
      if (rc['smsProvider'] != null) _smsProvider = rc['smsProvider'].toString();
      if (rc['otpDigits'] is num) _otpDigits = (rc['otpDigits'] as num).toInt();
      if (rc['smsMode'] != null) _smsGatewayMode = rc['smsMode'].toString();
      if (rc['enforceOtp'] is bool) _enforceMobileOtp = rc['enforceOtp'] as bool;
    }
    if (bundle.containsKey('emergencyBroadcast')) {
      if (bundle['emergencyBroadcast'] is Map) {
        setEmergencyBroadcast(Map<String, dynamic>.from(bundle['emergencyBroadcast']));
      } else if (bundle['emergencyBroadcast'] == null) {
        setEmergencyBroadcast(null);
      }
    } else if (bundle['broadcast'] is Map) {
      setEmergencyBroadcast(Map<String, dynamic>.from(bundle['broadcast']));
    }
    if (bundle['maintenance'] is Map) {
      final m = bundle['maintenance'] as Map<String, dynamic>;
      setMaintenanceDetails(
        isMaintenance: m['active'] == true,
        message: m['message']?.toString(),
        eta: m['eta']?.toString(),
      );
    } else if (bundle['settings'] is Map) {
      final s = bundle['settings'] as Map<String, dynamic>;
      if (s['maintenanceMode'] is bool) {
        _maintenanceMode = s['maintenanceMode'] as bool;
      }
      if (s['minAppVersion'] != null) _minAppVersion = s['minAppVersion'].toString();
      if (s['smsProvider'] != null) _smsProvider = s['smsProvider'].toString();
      if (s['smsGatewayMode'] != null) _smsGatewayMode = s['smsGatewayMode'].toString();
      if (s['otpDigits'] is num) _otpDigits = (s['otpDigits'] as num).toInt();
      if (s['enforceMobileOtp'] is bool) _enforceMobileOtp = s['enforceMobileOtp'] as bool;
    }
    if (bundle['tenants'] is List) {
      for (final t in bundle['tenants']) {
        if (t is Map<String, dynamic> && ((t['id'] ?? t['tenantId']) == (currentTenantId ?? _tenant.tenantId) || t['userId'] == _uniqueUserId)) {
          _tenant = _tenant.copyWith(
            subscriptionStatus: t['subscriptionStatus']?.toString(),
            subscriptionPlanId: t['subscriptionPlanId']?.toString(),
            subscriptionEndDate: DateTime.tryParse((t['expiryDate'] ?? t['subscriptionEndDate'] ?? '').toString()),
          );
        }
      }
    }
    notifyListeners();
  }

  // Complete Business Data Backup & Schedule State
  String _backupFrequency = 'weekly'; // 'weekly', 'monthly', 'off'
  bool _autoSaveToDevice = true;
  DateTime? _lastBackupDate = DateTime.now().subtract(const Duration(days: 2));

  String get backupFrequency => _backupFrequency;
  bool get autoSaveToDevice => _autoSaveToDevice;
  DateTime? get lastBackupDate => _lastBackupDate;

  bool get isBackupDue {
    if (_backupFrequency == 'off') return false;
    if (_lastBackupDate == null) return true;
    final diffDays = DateTime.now().difference(_lastBackupDate!).inDays;
    if (_backupFrequency == 'weekly') return diffDays >= 7;
    if (_backupFrequency == 'monthly') return diffDays >= 30;
    return false;
  }

  void setBackupFrequency(String frequency) {
    _backupFrequency = frequency;
    notifyListeners();
  }

  void setAutoSaveToDevice(bool enabled) {
    _autoSaveToDevice = enabled;
    notifyListeners();
  }

  /// Exports comprehensive business backup: Sell Orders, Bills, Khata Ledger, Customer Accounts, Products
  Map<String, dynamic> exportCompleteBackupData() {
    final now = DateTime.now();
    return {
      'metadata': {
        'appName': 'SalesArmy Enterprise',
        'version': '1.0.0',
        'exportedAt': now.toIso8601String(),
        'tenantId': currentTenantId ?? 'default_tenant',
        'exportedBy': currentUid ?? 'admin',
      },
      'summary': {
        'totalSellOrders': _orders.length,
        'totalBills': _invoices.length,
        'totalLedgerEntries': _ledgerEntries.length,
        'totalPayments': _payments.length,
        'totalCustomerAccounts': _shops.length,
        'totalProducts': _products.length,
        'totalMarketOutstandingDues': _shops.fold<double>(0.0, (acc, s) => acc + s.currentOutstanding),
        'totalRevenueBilled': _invoices.fold<double>(0.0, (acc, i) => acc + i.grandTotal),
      },
      'sellOrders': _orders.map((o) => o.toMap()).toList(),
      'bills': _invoices.map((i) => i.toMap()).toList(),
      'completeLedger': _ledgerEntries.map((l) => l.toMap()).toList(),
      'payments': _payments.map((p) => p.toMap()).toList(),
      'customerAccounts': _shops.map((s) => s.toMap()).toList(),
      'inventoryProducts': _products.map((p) => p.toMap()).toList(),
    };
  }

  /// Triggers backup download & refreshes last backup timestamp
  String triggerCompleteDataBackup() {
    final data = exportCompleteBackupData();
    _lastBackupDate = DateTime.now();
    notifyListeners();
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  // Admin Security Settings
  Future<void> updateAdminSecuritySettings({
    String? passcode,
    String? minAppVersion,
  }) async {
    if (passcode != null && passcode.isNotEmpty) {
      await PlatformApi.request('/api/platform/user/reset-password', body: {
        'userId': SupabaseService.instance.currentUser?.id, 'newPassword': passcode,
      });
    }
    if (minAppVersion != null) await pushRemoteConfigToPlatform(minAppVersion: minAppVersion);
    _adminPasscode = '';
    notifyListeners();
  }

  @override
  void dispose() {
    _bridgeSyncTimer?.cancel();
    _bridgeSyncTimer = null;

    _pricingSubscription?.cancel();
    _pricingCamelSubscription?.cancel();
    _platformSubscription?.cancel();
    _platformCamelSubscription?.cancel();
    _remoteConfigSubscription?.cancel();
    _remoteConfigCamelSubscription?.cancel();
    _broadcastSubscription?.cancel();
    _broadcastCamelSubscription?.cancel();
    _tenantSubscription?.cancel();

    try {
      _supabaseTenantChannel?.unsubscribe();
    } catch (e) { debugPrint('Unsubscribe tenant channel on dispose: $e'); }
    _supabaseTenantChannel = null;
    try {
      _supabasePrinterOrdersChannel?.unsubscribe();
    } catch (e) { debugPrint('Unsubscribe printer orders on dispose: $e'); }
    _supabasePrinterOrdersChannel = null;

    _cancelSubcollectionSubscriptions();

    _outboxSubscription?.cancel();
    _outboxSubscription = null;
    _outboxManager.dispose();

    super.dispose();
  }
}

/// Thrown when the agency is not allowed to create bills/orders right now
/// (account paused, or free/expired plan while the admin has disabled
/// free-user billing). [message] is safe to show to the user as-is.
/// Raised when the plan / subscription status does not allow an action.
/// Extends [BillingBlockedException] so existing billing dialogs show it.
class PlanRestrictionException extends BillingBlockedException {
  final String? feature;
  final bool readOnly;
  final bool limitReached;
  const PlanRestrictionException(super.message, {this.feature, this.readOnly = false, this.limitReached = false});
}

class BillingBlockedException implements Exception {
  final String message;
  const BillingBlockedException(this.message);
  @override
  String toString() => message;
}
