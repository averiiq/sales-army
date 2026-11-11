import 'package:flutter_test/flutter_test.dart';
import 'package:salesarmy/core/services/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Bank Accounts Maximum 3 Limit Tests', () {
    test('Initial bank accounts has 2 accounts and canAddBankAccount is true', () {
      final appState = AppState(loadMockData: true);
      expect(appState.bankAccounts.length, 2);
      expect(appState.canAddBankAccount, isTrue);
      expect(AppState.maxBankAccounts, 3);
    });

    test('Adding 3rd bank account succeeds and fills all slots', () {
      final appState = AppState(loadMockData: true);
      expect(appState.bankAccounts.length, 2);

      final added = appState.addBankAccount({
        'bankName': 'ICICI Bank',
        'accountHolderName': 'SalesArmy Agency',
        'accountNumber': '001105001234',
        'ifsc': 'ICIC0000011',
        'accountType': 'Current Account',
        'isPrimary': false,
      });

      expect(added, isTrue);
      expect(appState.bankAccounts.length, 3);
      expect(appState.canAddBankAccount, isFalse);
    });

    test('Adding 4th bank account is blocked by max 3 limit', () {
      final appState = AppState(loadMockData: true);
      // Add 3rd
      appState.addBankAccount({
        'bankName': 'ICICI Bank',
        'accountHolderName': 'SalesArmy Agency',
        'accountNumber': '001105001234',
        'ifsc': 'ICIC0000011',
        'accountType': 'Current Account',
        'isPrimary': false,
      });

      expect(appState.bankAccounts.length, 3);
      expect(appState.canAddBankAccount, isFalse);

      // Attempt 4th
      final fourthAdded = appState.addBankAccount({
        'bankName': 'Axis Bank',
        'accountHolderName': 'SalesArmy Agency',
        'accountNumber': '912020004567890',
        'ifsc': 'UTIB0000123',
        'accountType': 'Savings Account',
        'isPrimary': false,
      });

      expect(fourthAdded, isFalse);
      expect(appState.bankAccounts.length, 3);
      expect(appState.bankAccounts.any((a) => a['bankName'] == 'Axis Bank'), isFalse);
    });

    test('Removing an account frees a slot and allows adding a new account', () {
      final appState = AppState(loadMockData: true);
      // Add 3rd account
      appState.addBankAccount({
        'bankName': 'ICICI Bank',
        'accountHolderName': 'SalesArmy Agency',
        'accountNumber': '001105001234',
        'ifsc': 'ICIC0000011',
        'accountType': 'Current Account',
        'isPrimary': false,
      });
      expect(appState.bankAccounts.length, 3);
      expect(appState.canAddBankAccount, isFalse);

      // Remove the 3rd account
      final thirdId = appState.bankAccounts.last['id'] as String;
      appState.removeBankAccount(thirdId);

      expect(appState.bankAccounts.length, 2);
      expect(appState.canAddBankAccount, isTrue);

      // Now adding a new account succeeds
      final addedNew = appState.addBankAccount({
        'bankName': 'Kotak Mahindra Bank',
        'accountHolderName': 'SalesArmy Agency',
        'accountNumber': '201100998877',
        'ifsc': 'KKBK0000123',
        'accountType': 'Current Account',
        'isPrimary': false,
      });

      expect(addedNew, isTrue);
      expect(appState.bankAccounts.length, 3);
      expect(appState.canAddBankAccount, isFalse);
      expect(appState.bankAccounts.last['bankName'], 'Kotak Mahindra Bank');
    });

    test('Removing primary account automatically promotes another account to primary', () {
      final appState = AppState(loadMockData: true);
      final primaryAcc = appState.bankAccounts.firstWhere((a) => a['isPrimary'] == true);
      final primaryId = primaryAcc['id'] as String;

      appState.removeBankAccount(primaryId);

      expect(appState.bankAccounts.length, 1);
      expect(appState.bankAccounts.first['isPrimary'], isTrue);
    });
  });
}
