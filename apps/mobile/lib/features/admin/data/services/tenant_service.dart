import 'package:flutter/foundation.dart';
import 'package:salesarmy/features/admin/data/models/tenant_model.dart';
import 'package:salesarmy/core/services/supabase_service.dart';

class TenantService {
  TenantService();

  /// Real-time stream of a single tenant. Falls back to a one-shot fetch
  /// emission when live streaming isn't available.
  Stream<TenantModel?> streamTenant(String tenantId) {
    final client = SupabaseService.instance.client;
    if (client != null) {
      try {
        return client
            .from('tenants')
            .stream(primaryKey: ['tenant_id'])
            .eq('tenant_id', tenantId)
            .map((rows) => rows.isEmpty ? null : TenantModel.fromMap(rows.first, tenantId))
            .handleError((e) {
          debugPrint('Supabase streamTenant note: $e');
          return null;
        });
      } catch (e) {
        debugPrint('streamTenant setup note: $e');
      }
    }
    return Stream.value(null);
  }

  /// Real-time stream of all registered tenants (super-admin view).
  Stream<List<TenantModel>> streamAllTenants() {
    final client = SupabaseService.instance.client;
    if (client != null) {
      try {
        return client
            .from('tenants')
            .stream(primaryKey: ['tenant_id'])
            .map((rows) => rows
                .map((row) => TenantModel.fromMap(row, row['tenant_id'].toString()))
                .toList())
            .handleError((e) {
          debugPrint('Supabase streamAllTenants note: $e');
          return <TenantModel>[];
        });
      } catch (e) {
        debugPrint('streamAllTenants setup note: $e');
      }
    }
    return Stream.value(const <TenantModel>[]);
  }

  /// One-shot fetch of all registered tenants from Supabase Cloud.
  Future<List<TenantModel>> fetchAllTenants() async {
    final client = SupabaseService.instance.client;
    if (client != null) {
      try {
        final data = await client.from('tenants').select('*');
        return data.map((row) {
          final tid = (row['tenant_id'] ?? '').toString();
          return TenantModel.fromMap(Map<String, dynamic>.from(row as Map), tid);
        }).toList();
      } catch (e) {
        debugPrint('fetchAllTenants Supabase note: $e');
      }
    }
    return const <TenantModel>[];
  }

  /// Update tenant account/subscription status via Supabase.
  Future<void> updateTenantStatus(String tenantId, String newStatus) async {
    final client = SupabaseService.instance.client;
    if (client == null) return;
    try {
      final normalized = newStatus.toLowerCase();
      await client.from('tenants').update({
        'subscription_status': normalized == 'active' ? 'active' : normalized,
        'account_status': normalized,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('tenant_id', tenantId);
    } catch (e) {
      debugPrint('Supabase updateTenantStatus note: $e');
      rethrow;
    }
  }

  /// One-shot fetch for a single tenant.
  Future<TenantModel?> getTenant(String tenantId) async {
    try {
      final data = await SupabaseService.instance.fetchTenant(tenantId);
      if (data != null) {
        return TenantModel.fromMap(Map<String, dynamic>.from(data), tenantId);
      }
    } catch (e) {
      debugPrint('getTenant Supabase note: $e');
    }
    return null;
  }
}
