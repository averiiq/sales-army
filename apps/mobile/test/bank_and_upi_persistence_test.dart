import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/features/admin/data/models/tenant_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Bank & UPI Details Persistence Tests', () {
    test('TenantModel.fromMap correctly parses bank details and upi from Supabase columns', () {
      final supabaseRow = {
        'tenant_id': 'tenant_123',
        'business_name': 'Super Wholesale Store',
        'contact_person': 'Ramesh Kumar',
        'mobile': '9876543210',
        'bank_name': 'State Bank of India',
        'bank_account_no': '30291823910',
        'bank_ifsc': 'SBIN0001234',
        'upi_id': 'superagency@sbi',
      };

      final tenant = TenantModel.fromMap(supabaseRow, 'tenant_123');

      expect(tenant.tenantId, 'tenant_123');
      expect(tenant.bankAccount, isNotNull);
      expect(tenant.bankAccount!['bankName'], 'State Bank of India');
      expect(tenant.bankAccount!['accountNumber'], '30291823910');
      expect(tenant.bankAccount!['ifsc'], 'SBIN0001234');
      expect(tenant.bankAccount!['accountHolderName'], 'Ramesh Kumar');
      expect(tenant.upiId, 'superagency@sbi');
      expect(tenant.effectiveUpiId, 'superagency@sbi');
    });

    test('Adding bank account updates tenant bankAccount, upiId, and persists to SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final appState = AppState();

      final success = appState.addBankAccount({
        'bankName': 'HDFC Bank',
        'accountHolderName': 'Acme Traders',
        'accountNumber': '50100234567890',
        'ifsc': 'HDFC0000001',
        'accountType': 'Current Account',
        'isPrimary': true,
        'upiId': 'acmetraders@okhdfcbank',
      });

      expect(success, isTrue);
      expect(appState.bankAccounts.length, 1);
      expect(appState.tenant.bankAccount, isNotNull);
      expect(appState.tenant.bankAccount!['bankName'], 'HDFC Bank');
      expect(appState.tenant.bankAccount!['accountNumber'], '50100234567890');
      expect(appState.tenant.upiId, 'acmetraders@okhdfcbank');
      expect(appState.tenant.effectiveUpiId, 'acmetraders@okhdfcbank');

      // Allow async local persistence to complete
      await Future.delayed(const Duration(milliseconds: 100));

      // Verify stored in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final standaloneBank = prefs.getString('salesarmy_pref_bank_account_v2');
      final standaloneUpi = prefs.getString('salesarmy_pref_upi_id_v2');

      expect(standaloneBank, isNotNull);
      final decodedBank = json.decode(standaloneBank!) as Map<String, dynamic>;
      expect(decodedBank['bankName'], 'HDFC Bank');
      expect(decodedBank['accountNumber'], '50100234567890');
      expect(standaloneUpi, 'acmetraders@okhdfcbank');
    });

    test('Simulated app restart hydrates bank and upi details from local storage without wiping out', () async {
      // 1. First app run: User saves bank and UPI
      final initialPrefs = <String, Object>{
        'salesarmy_pref_bank_account_v2': json.encode({
          'bankName': 'Bank of Baroda',
          'accountHolderName': 'Baroda Distribution',
          'accountNumber': '987600112233',
          'ifsc': 'BARB0MAIN',
          'accountType': 'Current Account',
          'upiId': 'baroda@bob',
        }),
        'salesarmy_pref_upi_id_v2': 'baroda@bob',
        'salesarmy_local_bank_accounts_v2': json.encode([
          {
            'id': 'bank_1',
            'bankName': 'Bank of Baroda',
            'accountHolderName': 'Baroda Distribution',
            'accountNumber': '987600112233',
            'ifsc': 'BARB0MAIN',
            'accountType': 'Current Account',
            'isPrimary': true,
            'upiId': 'baroda@bob',
          }
        ]),
      };

      SharedPreferences.setMockInitialValues(initialPrefs);

      // 2. Fresh launch (simulating app close and relaunch)
      final newAppState = AppState();
      // Allow async SharedPreferences loading in constructor to finish
      await Future.delayed(const Duration(milliseconds: 100));

      expect(newAppState.tenant.bankAccount, isNotNull);
      expect(newAppState.tenant.bankAccount!['bankName'], 'Bank of Baroda');
      expect(newAppState.tenant.bankAccount!['accountNumber'], '987600112233');
      expect(newAppState.tenant.upiId, 'baroda@bob');
      expect(newAppState.bankAccounts.length, 1);
      expect(newAppState.bankAccounts.first['accountNumber'], '987600112233');
    });
  });
}
