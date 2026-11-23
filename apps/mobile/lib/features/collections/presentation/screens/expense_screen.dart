import 'package:flutter/material.dart';
import 'package:salesarmy/core/utils/app_error.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/core/theme/app_theme.dart';
import 'package:salesarmy/core/utils/formatters.dart';
import 'package:salesarmy/features/collections/data/models/expense_model.dart';

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  String _categoryFilter = 'All';
  String _searchQuery = '';

  final List<String> _categories = [
    'All',
    'Fuel / Transport',
    'Food & Tea',
    'Warehouse & Rent',
    'Packing & Stationery',
    'Vehicle Maintenance',
    'Staff Advance',
    'Miscellaneous',
  ];

  void _openRecordExpenseSlider(BuildContext context, bool isDark, {ExpenseModel? existingExpense}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RecordExpenseSliderModal(
        isDark: isDark,
        categories: _categories.where((c) => c != 'All').toList(),
        existingExpense: existingExpense,
      ),
    );
  }

  void _confirmDeleteExpense(BuildContext context, AppState appState, ExpenseModel exp) {
    final isDark = appState.isDarkMode;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
            const SizedBox(width: 8),
            Text(
              'Delete Expense?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete "${exp.title}" (${AppFormatters.currency(exp.amount)})?',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${AppFormatters.currency(exp.amount)} will be refunded back to your ${exp.paymentMode == 'Cash' ? 'In-Hand Cash' : 'Bank Account'}.',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF059669)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              appState.deleteExpense(exp.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Expense deleted & ${AppFormatters.currency(exp.amount)} refunded!'),
                    backgroundColor: const Color(0xFFEF4444),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete & Refund', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isDark = appState.isDarkMode;
    final expenses = appState.expenses;

    final filtered = expenses.where((e) {
      if (_categoryFilter != 'All' && e.category != _categoryFilter) {
        return false;
      }
      final q = _searchQuery.toLowerCase().trim();
      if (q.isNotEmpty) {
        return e.title.toLowerCase().contains(q) ||
            e.category.toLowerCase().contains(q) ||
            (e.notes?.toLowerCase().contains(q) ?? false);
      }
      return true;
    }).toList();

    final now = DateTime.now();
    final todayTotal = expenses
        .where((e) => e.date.year == now.year && e.date.month == now.month && e.date.day == now.day)
        .fold<double>(0.0, (s, e) => s + e.amount);

    final monthTotal = expenses
        .where((e) => e.date.year == now.year && e.date.month == now.month)
        .fold<double>(0.0, (s, e) => s + e.amount);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Daily Expenses',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add_circle_outline_rounded, color: isDark ? AppTheme.yellowPrimary : const Color(0xFF0F172A), size: 22),
            onPressed: () => _openRecordExpenseSlider(context, isDark),
            tooltip: 'Add Expense',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
        ),
      ),
      body: Column(
        children: [
          // 1. Metric Summary Cards
          Container(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    label: "TODAY'S SPENT",
                    value: AppFormatters.currency(todayTotal),
                    color: isDark ? const Color(0xFFF87171) : const Color(0xFFE11D48),
                    bgColor: isDark ? const Color(0xFF450A0A) : const Color(0xFFFFF1F2),
                    borderColor: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFFE4E6),
                    labelColor: isDark ? const Color(0xFFFCA5A5) : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricCard(
                    label: 'THIS MONTH',
                    value: AppFormatters.compactCurrency(monthTotal),
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    bgColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                    borderColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    labelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricCard(
                    label: 'TOTAL ENTRIES',
                    value: '${expenses.length}',
                    color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                    bgColor: isDark ? const Color(0xFF082F49) : const Color(0xFFF0F9FF),
                    borderColor: isDark ? const Color(0xFF0369A1) : const Color(0xFFBAE6FD),
                    labelColor: isDark ? const Color(0xFF7DD3FC) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),

          // 2. Search Field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                style: TextStyle(fontSize: 13.5, color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: 'Search title, category, notes...',
                  hintStyle: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF94A3B8)),
                  prefixIcon: Icon(Icons.search_rounded, size: 20, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear_rounded, size: 18, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          onPressed: () => setState(() => _searchQuery = ''),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ),
          ),

          // 3. Category Filter Pills
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              itemCount: _categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (ctx, idx) {
                final cat = _categories[idx];
                final isSel = _categoryFilter == cat;
                return InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _categoryFilter = cat);
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSel
                          ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.35) : const Color(0xFFEFF6FF))
                          : (isDark ? const Color(0xFF1E293B) : Colors.white),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSel
                            ? (isDark ? const Color(0xFF60A5FA) : const Color(0xFF1E56E2))
                            : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        width: isSel ? 1.5 : 1.0,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        cat,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                          color: isSel
                              ? (isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E56E2))
                              : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // 3. Expenses List
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.receipt_outlined, size: 36, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No Expenses Found',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap + to record field fuel, snacks, or warehouse costs.',
                          style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (ctx, idx) {
                      final exp = filtered[idx];

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: _getCategoryBg(exp.category, isDark),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: Icon(_getCategoryIcon(exp.category), color: _getCategoryColor(exp.category, isDark), size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    exp.title,
                                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${exp.category} • ${AppFormatters.date(exp.date)}',
                                    style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                  ),
                                  if (exp.notes != null && exp.notes!.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      exp.notes!,
                                      style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8), fontStyle: FontStyle.italic),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '-${AppFormatters.currency(exp.amount)}',
                                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: isDark ? const Color(0xFFF87171) : const Color(0xFFE11D48)),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        exp.paymentMode,
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    InkWell(
                                      onTap: () => _openRecordExpenseSlider(context, isDark, existingExpense: exp),
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1E56E2).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Icon(
                                          Icons.edit_outlined,
                                          size: 15,
                                          color: Color(0xFF1E56E2),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    InkWell(
                                      onTap: () => _confirmDeleteExpense(context, appState, exp),
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Icon(
                                          Icons.delete_outline_rounded,
                                          size: 15,
                                          color: Color(0xFFEF4444),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openRecordExpenseSlider(context, isDark),
        backgroundColor: const Color(0xFF059669),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded, size: 20, color: Colors.white),
        label: const Text('Add Expense', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.white)),
      ),
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required Color color,
    required Color bgColor,
    required Color borderColor,
    Color? labelColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: labelColor ?? const Color(0xFF64748B), letterSpacing: 0.3)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: color, letterSpacing: -0.2)),
        ],
      ),
    );
  }

  Color _getCategoryColor(String cat, bool isDark) {
    if (cat.contains('Fuel')) return isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
    if (cat.contains('Food')) return isDark ? const Color(0xFF34D399) : const Color(0xFF16A34A);
    if (cat.contains('Warehouse')) return isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);
    if (cat.contains('Packing')) return isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED);
    return isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  }

  Color _getCategoryBg(String cat, bool isDark) {
    if (cat.contains('Fuel')) return isDark ? const Color(0xFF451A03) : const Color(0xFFFFFBEB);
    if (cat.contains('Food')) return isDark ? const Color(0xFF064E3B) : const Color(0xFFF0FDF4);
    if (cat.contains('Warehouse')) return isDark ? const Color(0xFF082F49) : const Color(0xFFF0F9FF);
    if (cat.contains('Packing')) return isDark ? const Color(0xFF2E1065) : const Color(0xFFF5F3FF);
    return isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
  }

  IconData _getCategoryIcon(String cat) {
    if (cat.contains('Fuel')) return Icons.local_gas_station_rounded;
    if (cat.contains('Food')) return Icons.restaurant_rounded;
    if (cat.contains('Warehouse')) return Icons.warehouse_rounded;
    if (cat.contains('Packing')) return Icons.inventory_2_outlined;
    return Icons.payments_outlined;
  }
}

class _RecordExpenseSliderModal extends StatefulWidget {
  final List<String> categories;
  final bool isDark;
  final ExpenseModel? existingExpense;

  const _RecordExpenseSliderModal({
    required this.categories,
    required this.isDark,
    this.existingExpense,
  });

  @override
  State<_RecordExpenseSliderModal> createState() => _RecordExpenseSliderModalState();
}

class _RecordExpenseSliderModalState extends State<_RecordExpenseSliderModal> {
  final _titleController = TextEditingController();
  final _amountTextController = TextEditingController();
  final _notesController = TextEditingController();

  double _amount = 100.0;
  late String _category;
  String _paymentMode = 'Cash';

  final List<String> _quickTitles = [
    'Fuel / Petrol',
    'Tea & Refreshments',
    'Vehicle Maintenance',
    'Packing & Stationery',
    'Warehouse Cartons',
    'Labor / Daily Wages',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingExpense != null) {
      final e = widget.existingExpense!;
      _titleController.text = e.title;
      _amount = e.amount;
      _category = e.category;
      _paymentMode = e.paymentMode;
      _notesController.text = e.notes ?? '';
    } else {
      _category = widget.categories.isNotEmpty ? widget.categories.first : 'Fuel / Transport';
    }
    _amountTextController.text = _amount.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountTextController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _setAmount(double val) {
    HapticFeedback.selectionClick();
    setState(() {
      _amount = val.clamp(0.0, 50000.0);
      _amountTextController.text = _amount.toStringAsFixed(0);
    });
  }

  void _addQuickAmount(double delta) {
    HapticFeedback.lightImpact();
    _setAmount(_amount + delta);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final appState = context.watch<AppState>();
    final currentCash = appState.inHandCash;
    final currentBank = appState.inAccountBalance;
    final balanceToDeductFrom = _paymentMode == 'Cash' ? currentCash : currentBank;
    final targetBalanceLabel = _paymentMode == 'Cash' ? 'In-Hand Cash' : 'Bank Account';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 12,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.tune_rounded, color: Color(0xFF059669), size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Record Daily Expense',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Deducts automatically from cash or bank balance',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Amount Display Card with Slider
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                      : [const Color(0xFFF0FDF4), const Color(0xFFDCFCE7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFBBF7D0),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'EXPENSE AMOUNT',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF047857),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        '₹',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IntrinsicWidth(
                        child: TextField(
                          controller: _amountTextController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (val) {
                            final parsed = double.tryParse(val);
                            if (parsed != null) {
                              setState(() => _amount = parsed.clamp(0.0, 50000.0));
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Interactive Amount Slider
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: const Color(0xFF059669),
                      inactiveTrackColor: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      thumbColor: const Color(0xFF059669),
                      overlayColor: const Color(0xFF059669).withValues(alpha: 0.2),
                      trackHeight: 6,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                      valueIndicatorColor: const Color(0xFF059669),
                      valueIndicatorTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                    ),
                    child: Slider(
                      value: _amount.clamp(0.0, 10000.0),
                      min: 0.0,
                      max: 10000.0,
                      divisions: 200,
                      label: '₹${_amount.toStringAsFixed(0)}',
                      onChanged: (val) {
                        _setAmount(val);
                      },
                    ),
                  ),

                  // Quick Increment Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildQuickChip('+₹50', 50, isDark),
                        const SizedBox(width: 6),
                        _buildQuickChip('+₹100', 100, isDark),
                        const SizedBox(width: 6),
                        _buildQuickChip('+₹500', 500, isDark),
                        const SizedBox(width: 6),
                        _buildQuickChip('+₹1,000', 1000, isDark),
                        const SizedBox(width: 6),
                        _buildQuickChip('+₹2,000', 2000, isDark),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Expense Title / Description
            Text(
              'Expense Description *',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _titleController,
              style: TextStyle(fontSize: 14, color: isDark ? Colors.white : const Color(0xFF0F172A)),
              decoration: InputDecoration(
                hintText: 'e.g., Fuel for Delivery Van',
                hintStyle: TextStyle(color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8), fontSize: 13),
                filled: true,
                fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF059669), width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 8),

            // Quick Preset Titles
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _quickTitles.map((t) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      label: Text(t, style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569))),
                      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        setState(() => _titleController.text = t);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),

            // Category Chips
            Text(
              'Category',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.categories.map((c) {
                final isSel = _category == c;
                return ChoiceChip(
                  label: Text(
                    c,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                      color: isSel ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                    ),
                  ),
                  selected: isSel,
                  selectedColor: const Color(0xFF059669),
                  backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  side: BorderSide(
                    color: isSel ? const Color(0xFF059669) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  onSelected: (sel) {
                    if (sel) setState(() => _category = c);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Payment Mode & Live Balance Deduction
            Text(
              'Paid From',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: ['Cash', 'UPI', 'Bank Transfer'].map((m) {
                final isSel = _paymentMode == m;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _paymentMode = m);
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isSel
                              ? const Color(0xFF059669).withValues(alpha: 0.15)
                              : (isDark ? const Color(0xFF0F172A) : Colors.white),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSel ? const Color(0xFF059669) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            width: isSel ? 1.5 : 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          m,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                            color: isSel ? const Color(0xFF059669) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),

            // Balance deduction notification preview
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet_outlined, size: 16, color: Color(0xFF059669)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Deducts from $targetBalanceLabel: ${AppFormatters.currency(balanceToDeductFrom)} ➔ ${AppFormatters.currency(balanceToDeductFrom - _amount)}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Optional Notes
            TextField(
              controller: _notesController,
              style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
              decoration: InputDecoration(
                hintText: 'Notes / Voucher / Bill # (Optional)',
                hintStyle: TextStyle(color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8), fontSize: 12),
                filled: true,
                fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 20),

            // Save Button with White Text!
            ElevatedButton(
              onPressed: () {
                final title = _titleController.text.trim();
                if (title.isEmpty) {
                  showAppError(context, 'Please enter an expense description');
                  return;
                }
                if (_amount <= 0) {
                  showAppError(context, 'Please specify an amount greater than ₹0');
                  return;
                }

                if (widget.existingExpense != null) {
                  final updated = widget.existingExpense!.copyWith(
                    title: title,
                    category: _category,
                    amount: _amount,
                    paymentMode: _paymentMode,
                    notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
                  );
                  appState.updateExpense(updated);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Updated expense to ${AppFormatters.currency(_amount)}!'),
                      backgroundColor: const Color(0xFF059669),
                    ),
                  );
                  return;
                }

                final exp = ExpenseModel(
                  id: 'exp_${DateTime.now().millisecondsSinceEpoch}',
                  title: title,
                  category: _category,
                  amount: _amount,
                  paymentMode: _paymentMode,
                  date: DateTime.now(),
                  notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
                  createdAt: DateTime.now(),
                );

                appState.addExpense(exp);
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Recorded expense of ${AppFormatters.currency(_amount)} & deducted from $targetBalanceLabel!'),
                    backgroundColor: const Color(0xFF059669),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 2,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    widget.existingExpense != null ? 'Save Changes' : 'Record & Deduct ${AppFormatters.currency(_amount)}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickChip(String label, double delta, bool isDark) {
    return InkWell(
      onTap: () => _addQuickAmount(delta),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
      ),
    );
  }
}
