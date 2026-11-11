import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/core/theme/app_theme.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  final Set<String> _unmaskedAccountIds = {};

  Color _getBankColor(String? bankName) {
    final name = (bankName ?? '').toLowerCase();
    if (name.contains('hdfc')) return const Color(0xFF004C8F);
    if (name.contains('state bank') || name.contains('sbi')) return const Color(0xFF0072BB);
    if (name.contains('icici')) return const Color(0xFFB32025);
    if (name.contains('axis')) return const Color(0xFF97144D);
    if (name.contains('kotak')) return const Color(0xFFED1C24);
    if (name.contains('punjab') || name.contains('pnb')) return const Color(0xFFB91C1C);
    if (name.contains('baroda') || name.contains('bob')) return const Color(0xFFEA580C);
    if (name.contains('canara')) return const Color(0xFF0284C7);
    return const Color(0xFF1D4ED8);
  }

  void _showLimitReachedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.lock_rounded, color: Color(0xFFD97706), size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Account Limit Reached',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'You have reached the maximum allowed limit of 3 bank accounts for your business.',
              style: TextStyle(fontSize: 13.5, color: Color(0xFF334155), height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF64748B)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'To add a new bank account, please delete an existing account first.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1D4ED8),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Understood', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteBankAccount(BuildContext context, Map<String, dynamic> acc) {
    final appState = Provider.of<AppState>(context, listen: false);
    final bankName = acc['bankName'] as String? ?? 'Bank Account';
    final accNum = acc['accountNumber'] as String? ?? '';
    final last4 = accNum.length >= 4 ? accNum.substring(accNum.length - 4) : accNum;
    final isPrimary = acc['isPrimary'] == true;
    final accId = acc['id'] as String? ?? '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_forever_rounded, color: Color(0xFFDC2626), size: 22),
            ),
            const SizedBox(width: 12),
            const Text(
              'Remove Account?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to remove $bankName (A/C ending in $last4)?',
              style: const TextStyle(fontSize: 13.5, color: Color(0xFF334155), height: 1.35),
            ),
            if (isPrimary && appState.bankAccounts.length > 1) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFD97706)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This is your Primary account. Another registered account will automatically become primary.',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF92400E), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              HapticFeedback.mediumImpact();
              appState.removeBankAccount(accId);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$bankName account removed (${appState.bankAccounts.length}/${AppState.maxBankAccounts} slots used)'),
                  backgroundColor: const Color(0xFF0F172A),
                ),
              );
            },
            child: const Text('Remove Account', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  void _showAddBankAccountDialog(BuildContext context, {Map<String, dynamic>? existingAccount}) {
    final appState = Provider.of<AppState>(context, listen: false);

    // Enforce 3 bank accounts limit only when adding new
    if (existingAccount == null && !appState.canAddBankAccount) {
      _showLimitReachedDialog(context);
      return;
    }

    final bankNameCtrl = TextEditingController(text: existingAccount?['bankName'] as String? ?? '');
    final holderCtrl = TextEditingController(
      text: existingAccount?['accountHolderName'] as String? ?? appState.tenant.firmName ?? '',
    );
    final accNumCtrl = TextEditingController(text: existingAccount?['accountNumber'] as String? ?? '');
    final confirmAccNumCtrl = TextEditingController(text: existingAccount?['accountNumber'] as String? ?? '');
    final ifscCtrl = TextEditingController(text: existingAccount?['ifsc'] as String? ?? '');
    final upiCtrl = TextEditingController(text: existingAccount?['upiId'] as String? ?? '');
    String accountType = existingAccount?['accountType'] as String? ?? 'Current Account';
    bool isPrimary = existingAccount != null ? (existingAccount['isPrimary'] == true) : appState.bankAccounts.isEmpty;

    final quickBanks = [
      {'name': 'HDFC Bank', 'ifscPrefix': 'HDFC0', 'color': const Color(0xFF004C8F)},
      {'name': 'ICICI Bank', 'ifscPrefix': 'ICIC0', 'color': const Color(0xFFB32025)},
      {'name': 'State Bank of India', 'ifscPrefix': 'SBIN0', 'color': const Color(0xFF0072BB)},
      {'name': 'Axis Bank', 'ifscPrefix': 'UTIB0', 'color': const Color(0xFF97144D)},
      {'name': 'Kotak Mahindra', 'ifscPrefix': 'KKBK0', 'color': const Color(0xFFED1C24)},
      {'name': 'Punjab National Bank', 'ifscPrefix': 'PUNB0', 'color': const Color(0xFFB91C1C)},
      {'name': 'Bank of Baroda', 'ifscPrefix': 'BARB0', 'color': const Color(0xFFEA580C)},
      {'name': 'Canara Bank', 'ifscPrefix': 'CNRB0', 'color': const Color(0xFF0284C7)},
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final slotNum = appState.bankAccounts.length + 1;
            final activeBankColor = _getBankColor(bankNameCtrl.text.trim());
            final rawAccNum = accNumCtrl.text.trim();
            final confirmNum = confirmAccNumCtrl.text.trim();
            final isAccMatch = rawAccNum.isNotEmpty && confirmNum.isNotEmpty && rawAccNum == confirmNum;
            final isAccMismatch = confirmNum.isNotEmpty && rawAccNum != confirmNum;
            final ifscText = ifscCtrl.text.trim().toUpperCase();
            final isIfscValid = RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(ifscText);

            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              clipBehavior: Clip.antiAlias,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 520),
                decoration: const BoxDecoration(
                  color: Colors.white,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Executive Header
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 18, 14, 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFF8FAFC),
                            const Color(0xFFF1F5F9),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1D4ED8),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF1D4ED8).withValues(alpha: 0.25),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.account_balance_rounded, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    Text(
                                      existingAccount != null ? 'Edit Bank Account' : 'Add Bank Account',
                                      style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: -0.3),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDBEAFE),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFFBFDBFE)),
                                      ),
                                      child: Text(
                                        existingAccount != null ? 'Edit Account' : 'Slot $slotNum of ${AppState.maxBankAccounts}',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF1D4ED8)),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Linked account for customer payments & invoice receipts',
                                  style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 22),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                    ),

                    // Scrollable Body
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. LIVE INTERACTIVE CARD PREVIEW
                            Container(
                              width: double.infinity,
                              height: 155,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                gradient: LinearGradient(
                                  colors: [
                                    activeBankColor,
                                    activeBankColor.withValues(alpha: 0.85),
                                    const Color(0xFF0F172A),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: activeBankColor.withValues(alpha: 0.35),
                                    blurRadius: 16,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Stack(
                                children: [
                                  // Subtle watermarked circles in card background
                                  Positioned(
                                    right: -25,
                                    top: -25,
                                    child: Container(
                                      width: 110,
                                      height: 110,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white.withValues(alpha: 0.08),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    right: 25,
                                    bottom: -35,
                                    child: Container(
                                      width: 100,
                                      height: 100,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white.withValues(alpha: 0.05),
                                      ),
                                    ),
                                  ),

                                  // Card Content
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      // Top Row: Bank Name + Chip/NFC
                                      Row(
                                        children: [
                                          const Icon(Icons.account_balance, color: Colors.white, size: 18),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              bankNameCtrl.text.trim().isEmpty ? 'BANK NAME' : bankNameCtrl.text.trim().toUpperCase(),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 0.8,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          if (isPrimary) ...[
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFEF3C7),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.star_rounded, size: 11, color: Color(0xFFD97706)),
                                                  SizedBox(width: 3),
                                                  Text(
                                                    'PRIMARY',
                                                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: Color(0xFF92400E)),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                          ],
                                          const Icon(Icons.contactless_rounded, color: Colors.white70, size: 18),
                                        ],
                                      ),

                                      // Middle: EMV Chip & Formatted Account Number
                                      Row(
                                        children: [
                                          // Golden EMV Chip Icon
                                          Container(
                                            width: 30,
                                            height: 22,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFDE68A),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: const Color(0xFFF59E0B), width: 1),
                                            ),
                                            child: Center(
                                              child: Container(
                                                width: 14,
                                                height: 10,
                                                decoration: BoxDecoration(
                                                  border: Border.all(color: const Color(0xFFD97706), width: 0.8),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          // Account Number live preview
                                          Expanded(
                                            child: Text(
                                              rawAccNum.isEmpty
                                                  ? '•••• •••• •••• ••••'
                                                  : (rawAccNum.length > 4
                                                      ? '•••• •••• •••• ${rawAccNum.substring(rawAccNum.length - 4)}'
                                                      : rawAccNum),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 2.0,
                                                fontFamily: 'monospace',
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),

                                      // Bottom: Holder Name + Account Type / IFSC
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'ACCOUNT HOLDER',
                                                  style: TextStyle(fontSize: 8.5, color: Colors.white60, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                                                ),
                                                Text(
                                                  holderCtrl.text.trim().isEmpty ? 'COMPANY / FIRM NAME' : holderCtrl.text.trim().toUpperCase(),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w700,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                accountType.toUpperCase(),
                                                style: const TextStyle(fontSize: 9.5, color: Colors.white70, fontWeight: FontWeight.w800),
                                              ),
                                              Text(
                                                ifscText.isEmpty ? 'IFSC: —' : 'IFSC: $ifscText',
                                                style: const TextStyle(fontSize: 9.5, color: Colors.white60, fontFamily: 'monospace'),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // 2. QUICK POPULAR BANK SELECTOR
                            const Text(
                              'Select Popular Bank or Custom *',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 8),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: quickBanks.map((b) {
                                  final bName = b['name'] as String;
                                  final bColor = b['color'] as Color;
                                  final bPrefix = b['ifscPrefix'] as String;
                                  final isSel = bankNameCtrl.text.trim().toLowerCase() == bName.toLowerCase();

                                  return Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: InkWell(
                                      onTap: () {
                                        setDialogState(() {
                                          bankNameCtrl.text = bName;
                                          if (ifscCtrl.text.isEmpty || ifscCtrl.text.length < 5) {
                                            ifscCtrl.text = bPrefix;
                                          }
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: isSel ? const Color(0xFF1D4ED8) : const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: isSel ? const Color(0xFF1D4ED8) : const Color(0xFFCBD5E1),
                                            width: isSel ? 1.5 : 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                color: isSel ? Colors.white : bColor,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              bName,
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                                                color: isSel ? Colors.white : const Color(0xFF334155),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Bank Name Input
                            TextField(
                              controller: bankNameCtrl,
                              onChanged: (_) => setDialogState(() {}),
                              decoration: InputDecoration(
                                labelText: 'Bank Name *',
                                hintText: 'e.g. HDFC Bank, ICICI Bank',
                                prefixIcon: const Icon(Icons.account_balance_outlined),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Account Holder Name
                            TextField(
                              controller: holderCtrl,
                              onChanged: (_) => setDialogState(() {}),
                              decoration: InputDecoration(
                                labelText: 'Account Holder / Firm Name *',
                                hintText: 'Enter legal business or proprietor name',
                                prefixIcon: const Icon(Icons.person_outline_rounded),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Bank Account Number
                            TextField(
                              controller: accNumCtrl,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setDialogState(() {}),
                              decoration: InputDecoration(
                                labelText: 'Bank Account Number *',
                                hintText: 'e.g. 50200088921820',
                                prefixIcon: const Icon(Icons.pin_outlined),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Confirm Account Number with Live Verification
                            TextField(
                              controller: confirmAccNumCtrl,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setDialogState(() {}),
                              decoration: InputDecoration(
                                labelText: 'Confirm Account Number *',
                                hintText: 'Re-enter account number to avoid wire transfer errors',
                                prefixIcon: const Icon(Icons.check_circle_outline_rounded),
                                suffixIcon: isAccMatch
                                    ? const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 20)
                                    : (isAccMismatch ? const Icon(Icons.cancel_rounded, color: Color(0xFFDC2626), size: 20) : null),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: isAccMatch ? const Color(0xFF86EFAC) : (isAccMismatch ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0)),
                                  ),
                                ),
                              ),
                            ),
                            if (isAccMatch) ...[
                              Padding(
                                padding: const EdgeInsets.only(top: 4, left: 4),
                                child: Row(
                                  children: const [
                                    Icon(Icons.check_rounded, size: 13, color: Color(0xFF16A34A)),
                                    SizedBox(width: 4),
                                    Text('Account numbers match perfectly', style: TextStyle(fontSize: 11, color: Color(0xFF16A34A), fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                            ] else if (isAccMismatch) ...[
                              Padding(
                                padding: const EdgeInsets.only(top: 4, left: 4),
                                child: Row(
                                  children: const [
                                    Icon(Icons.error_outline_rounded, size: 13, color: Color(0xFFDC2626)),
                                    SizedBox(width: 4),
                                    Text('Account numbers do not match', style: TextStyle(fontSize: 11, color: Color(0xFFDC2626), fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),

                            // IFSC Code with Validation Indicator
                            TextField(
                              controller: ifscCtrl,
                              textCapitalization: TextCapitalization.characters,
                              onChanged: (_) => setDialogState(() {}),
                              decoration: InputDecoration(
                                labelText: 'IFSC Code *',
                                hintText: 'e.g. HDFC0001042 (11 characters)',
                                prefixIcon: const Icon(Icons.domain_verification_outlined),
                                suffixIcon: ifscText.isNotEmpty
                                    ? (isIfscValid
                                        ? const Tooltip(
                                            message: 'Valid IFSC format',
                                            child: Icon(Icons.verified_rounded, color: Color(0xFF16A34A), size: 20),
                                          )
                                        : const Tooltip(
                                            message: '11 characters required (e.g. HDFC0001042)',
                                            child: Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 20),
                                          ))
                                    : null,
                                helperText: '11-character Indian Financial System Code (5th char is zero)',
                                helperStyle: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Account Type Dropdown
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: accountType,
                              decoration: InputDecoration(
                                labelText: 'Account Type',
                                prefixIcon: const Icon(Icons.category_outlined),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              ),
                              items: ['Current Account', 'Savings Account', 'Cash Credit (CC)', 'Overdraft (OD)'].map((t) {
                                return DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13.5)));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setDialogState(() => accountType = val);
                              },
                            ),
                            const SizedBox(height: 12),

                            // Optional UPI ID / VPA
                            TextField(
                              controller: upiCtrl,
                              decoration: InputDecoration(
                                labelText: 'UPI ID / VPA (Optional)',
                                hintText: 'e.g. company@hdfcbank or 9876543210@upi',
                                prefixIcon: const Icon(Icons.qr_code_2_rounded),
                                helperText: 'Linked for instant UPI QR code on generated invoices',
                                helperStyle: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Primary Settlement Toggle
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isPrimary ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isPrimary ? const Color(0xFF93C5FD) : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isPrimary ? const Color(0xFF1D4ED8) : const Color(0xFFE2E8F0),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.star_rounded, size: 16, color: isPrimary ? Colors.white : const Color(0xFF64748B)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: const [
                                        Text(
                                          'Set as Primary Settlement Account',
                                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          'Printed on tax invoices, bill footers & payment receipts',
                                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch.adaptive(
                                    value: isPrimary,
                                    activeTrackColor: const Color(0xFF1D4ED8),
                                    onChanged: (val) {
                                      setDialogState(() => isPrimary = val);
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Security Assurance Info
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: const [
                                  Icon(Icons.shield_outlined, size: 16, color: Color(0xFF64748B)),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Bank details are 256-bit encrypted and safely synchronized across your authorized devices.',
                                      style: TextStyle(fontSize: 10.5, color: Color(0xFF475569)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Actions
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1D4ED8),
                                foregroundColor: Colors.white,
                                elevation: 2,
                                shadowColor: const Color(0xFF1D4ED8).withValues(alpha: 0.3),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: () {
                                final bName = bankNameCtrl.text.trim();
                                final holder = holderCtrl.text.trim();
                                final num = accNumCtrl.text.trim();
                                final confirm = confirmAccNumCtrl.text.trim();
                                final ifsc = ifscCtrl.text.trim().toUpperCase();
                                final upi = upiCtrl.text.trim();

                                if (bName.isEmpty || num.isEmpty || ifsc.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Please fill mandatory fields: Bank Name, Account Number & IFSC'),
                                      backgroundColor: Color(0xFFDC2626),
                                    ),
                                  );
                                  return;
                                }

                                if (confirm.isNotEmpty && num != confirm) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Account Number and Confirm Account Number do not match!'),
                                      backgroundColor: Color(0xFFDC2626),
                                    ),
                                  );
                                  return;
                                }

                                if (existingAccount != null) {
                                  final updatedAccount = {
                                    ...existingAccount,
                                    'bankName': bName,
                                    'accountHolderName': holder,
                                    'accountNumber': num,
                                    'ifsc': ifsc,
                                    'accountType': accountType,
                                    'isPrimary': isPrimary,
                                    if (upi.isNotEmpty) 'upiId': upi,
                                  };
                                  final success = appState.updateBankAccount(updatedAccount);
                                  Navigator.pop(ctx);
                                  if (success) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('$bName account updated!'),
                                        backgroundColor: const Color(0xFF059669),
                                      ),
                                    );
                                  }
                                } else {
                                  final newAccount = {
                                    'bankName': bName,
                                    'accountHolderName': holder,
                                    'accountNumber': num,
                                    'ifsc': ifsc,
                                    'accountType': accountType,
                                    'isPrimary': isPrimary,
                                    if (upi.isNotEmpty) 'upiId': upi,
                                  };

                                  final success = appState.addBankAccount(newAccount);
                                  Navigator.pop(ctx);

                                  if (success) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('$bName account linked! (${appState.bankAccounts.length}/${AppState.maxBankAccounts} accounts active)'),
                                        backgroundColor: const Color(0xFF059669),
                                      ),
                                    );
                                  } else {
                                    _showLimitReachedDialog(context);
                                  }
                                }
                              },
                              child: Text(
                                existingAccount != null
                                    ? 'Update Account'
                                    : 'Save Account (Slot $slotNum of ${AppState.maxBankAccounts})',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatMaskedAccountNumber(String rawNum, bool isUnmasked) {
    if (isUnmasked || rawNum.length < 6) return rawNum;
    final last4 = rawNum.substring(rawNum.length - 4);
    return '•••• •••• •••• $last4';
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final bankAccounts = appState.bankAccounts;
    final isMaxReached = bankAccounts.length >= AppState.maxBankAccounts;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Column(
          children: [
            Text(
              'Bank Accounts',
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            Text(
              '${bankAccounts.length} of ${AppState.maxBankAccounts} accounts registered',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isMaxReached ? const Color(0xFFD97706) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
            ),
          ],
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Notice banner (Viewing only & 3-account limit)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? const Color(0xFF1E40AF) : const Color(0xFFBFDBFE)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Company Bank Accounts (Maximum 3 Allowed)',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E3A8A),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'You can register up to 3 official company bank accounts. Verified details are displayed on tax invoices, bill receipts, and client settlement statements.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? const Color(0xFFBFDBFE) : const Color(0xFF1E40AF),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Account Slot Capacity Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                boxShadow: AppTheme.softShadow(blur: 8, dy: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isMaxReached ? Icons.lock_outline_rounded : Icons.pie_chart_outline_rounded,
                            size: 16,
                            color: isMaxReached ? const Color(0xFFD97706) : (isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8)),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Account Slots',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isMaxReached
                              ? (isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7))
                              : (isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5)),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isMaxReached
                                ? (isDark ? const Color(0xFF92400E) : const Color(0xFFFDE68A))
                                : (isDark ? const Color(0xFF047857) : const Color(0xFFA7F3D0)),
                          ),
                        ),
                        child: Text(
                          isMaxReached ? '3/3 MAX LIMIT REACHED' : '${AppState.maxBankAccounts - bankAccounts.length} SLOT AVAILABLE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: isMaxReached
                                ? (isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309))
                                : (isDark ? const Color(0xFF6EE7B7) : const Color(0xFF059669)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // 3-Slot Visual Pills
                  Row(
                    children: List.generate(AppState.maxBankAccounts, (index) {
                      final isOccupied = index < bankAccounts.length;
                      final acc = isOccupied ? bankAccounts[index] : null;
                      final bankName = acc?['bankName'] as String? ?? 'Empty Slot';
                      final isPrimary = acc?['isPrimary'] == true;

                      return Expanded(
                        child: Container(
                          margin: EdgeInsets.only(right: index < AppState.maxBankAccounts - 1 ? 8 : 0),
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                          decoration: BoxDecoration(
                            color: isOccupied
                                ? (isPrimary
                                    ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : const Color(0xFFEFF6FF))
                                    : (isDark ? const Color(0xFF0F172A) : Colors.white))
                                : (isDark ? const Color(0xFF0F172A).withValues(alpha: 0.5) : const Color(0xFFF1F5F9)),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isOccupied
                                  ? (isPrimary ? const Color(0xFF3B82F6) : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)))
                                  : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                              width: isPrimary ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    isOccupied ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                    size: 13,
                                    color: isOccupied
                                        ? (isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8))
                                        : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Slot ${index + 1}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: isOccupied
                                          ? (isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8))
                                          : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isOccupied ? bankName : '+ Open',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isOccupied ? FontWeight.w800 : FontWeight.w600,
                                  color: isOccupied
                                      ? (isDark ? Colors.white : const Color(0xFF0F172A))
                                      : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'REGISTERED ACCOUNTS (${bankAccounts.length}/${AppState.maxBankAccounts})',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                if (!isMaxReached) ...[
                  TextButton.icon(
                    onPressed: () => _showAddBankAccountDialog(context),
                    icon: Icon(Icons.add_rounded, size: 18, color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8)),
                    label: Text(
                      '+ Add Bank',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8),
                      ),
                    ),
                  ),
                ] else ...[
                  InkWell(
                    onTap: () => _showLimitReachedDialog(context),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: isDark ? const Color(0xFF92400E) : const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.lock_rounded, size: 13, color: isDark ? const Color(0xFFFCD34D) : const Color(0xFFD97706)),
                          const SizedBox(width: 4),
                          Text(
                            'Limit Reached',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),

            // Bank Accounts List
            if (bankAccounts.isEmpty) ...[
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.account_balance_outlined, size: 36, color: Color(0xFF94A3B8)),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'No Bank Accounts Added Yet',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Add your business bank account details to display on billings and statements (Up to 3 allowed).',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _showAddBankAccountDialog(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E56E2),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add Primary Bank Account', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ] else ...[
              ...bankAccounts.asMap().entries.map((entry) {
                final acc = entry.value;
                final accId = acc['id'] as String? ?? 'acc_${entry.key}';
                final isPrimary = acc['isPrimary'] == true;
                final bankName = acc['bankName'] as String? ?? 'Bank Account';
                final holder = acc['accountHolderName'] as String? ?? 'Agency';
                final accNum = acc['accountNumber'] as String? ?? '—';
                final ifsc = acc['ifsc'] as String? ?? '—';
                final accType = acc['accountType'] as String? ?? 'Current Account';
                final isUnmasked = _unmaskedAccountIds.contains(accId);
                final brandColor = _getBankColor(bankName);

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isPrimary ? const Color(0xFF3B82F6) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      width: isPrimary ? 1.5 : 1.0,
                    ),
                    boxShadow: AppTheme.softShadow(blur: 10, dy: 3),
                  ),
                  child: Column(
                    children: [
                      // Card Top Row
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isPrimary
                              ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF))
                              : (isDark ? const Color(0xFF0F172A).withValues(alpha: 0.4) : const Color(0xFFF8FAFC)),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: brandColor,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.account_balance_rounded, color: Colors.white, size: 18),
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
                                                bankName,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 13.5,
                                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                              decoration: BoxDecoration(
                                                color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                'Slot ${entry.key + 1}',
                                                style: TextStyle(
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          accType,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isPrimary) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.check_circle_rounded, size: 11, color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF15803D)),
                                        const SizedBox(width: 4),
                                        Text(
                                          'PRIMARY',
                                          style: TextStyle(
                                            color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF15803D),
                                            fontWeight: FontWeight.w900,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ] else ...[
                                  InkWell(
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      appState.setPrimaryBankAccount(accId);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('$bankName set as Primary Settlement Account'),
                                          duration: const Duration(seconds: 1),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Make Primary',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(width: 2),
                                IconButton(
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                  padding: const EdgeInsets.all(6),
                                  icon: Icon(Icons.edit_outlined, size: 18, color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8)),
                                  onPressed: () => _showAddBankAccountDialog(context, existingAccount: acc),
                                  tooltip: 'Edit Account',
                                ),
                                const SizedBox(width: 2),
                                IconButton(
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                  padding: const EdgeInsets.all(6),
                                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                                  onPressed: () => _confirmDeleteBankAccount(context, acc),
                                  tooltip: 'Remove Account',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Card Details
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          children: [
                            // Account Holder Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Account Holder:', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                                Text(
                                  holder,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                            Divider(height: 16, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),

                            // Account Number with Mask/Unmask & 1-tap copy
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Account Number:', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                                Row(
                                  children: [
                                    Text(
                                      _formatMaskedAccountNumber(accNum, isUnmasked),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    InkWell(
                                      onTap: () {
                                        setState(() {
                                          if (isUnmasked) {
                                            _unmaskedAccountIds.remove(accId);
                                          } else {
                                            _unmaskedAccountIds.add(accId);
                                          }
                                        });
                                      },
                                      child: Icon(
                                        isUnmasked ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                        size: 16,
                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    InkWell(
                                      onTap: () {
                                        Clipboard.setData(ClipboardData(text: accNum));
                                        HapticFeedback.lightImpact();
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Account number copied!'), duration: Duration(seconds: 1)),
                                        );
                                      },
                                      child: Icon(
                                        Icons.copy_rounded,
                                        size: 15,
                                        color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Divider(height: 16, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),

                            // IFSC Code with 1-tap copy
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('IFSC Code:', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                                Row(
                                  children: [
                                    Text(
                                      ifsc,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    InkWell(
                                      onTap: () {
                                        Clipboard.setData(ClipboardData(text: ifsc));
                                        HapticFeedback.lightImpact();
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('IFSC code copied!'), duration: Duration(seconds: 1)),
                                        );
                                      },
                                      child: Icon(
                                        Icons.copy_rounded,
                                        size: 15,
                                        color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),

              // Open Slot / Limit Reached Card below the list
              if (!isMaxReached) ...[
                InkWell(
                  onTap: () => _showAddBankAccountDialog(context),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? const Color(0xFF1E40AF) : const Color(0xFF93C5FD),
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.5) : const Color(0xFFEFF6FF),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.add_rounded, color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8), size: 20),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '+ Add Bank Account (${AppState.maxBankAccounts - bankAccounts.length} slot${AppState.maxBankAccounts - bankAccounts.length > 1 ? 's' : ''} left)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8),
                              ),
                            ),
                            Text(
                              'Tap to link up to 3 official company accounts',
                              style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF78350F).withValues(alpha: 0.25)
                        : const Color(0xFFFEF3C7).withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isDark ? const Color(0xFF92400E) : const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.shield_outlined, color: isDark ? const Color(0xFFFCD34D) : const Color(0xFFD97706), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Maximum 3 Accounts Registered',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: isDark ? const Color(0xFFFCD34D) : const Color(0xFF92400E),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'You have reached the maximum allowed limit of 3 bank accounts. To link a new account, delete an existing account first.',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
