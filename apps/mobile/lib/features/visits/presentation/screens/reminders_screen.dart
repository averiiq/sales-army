import 'package:flutter/material.dart';
import 'package:salesarmy/core/utils/app_error.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/core/theme/app_theme.dart';
import 'package:salesarmy/features/shops/data/models/shop_model.dart';
import 'package:salesarmy/features/visits/data/models/reminder_model.dart';
import 'package:salesarmy/core/utils/feature_gate.dart';

class RemindersScreen extends StatefulWidget {
  final String? initialFilter;
  const RemindersScreen({super.key, this.initialFilter});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  late String _selectedFilter;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.initialFilter ?? 'All';
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // Purpose formatting helpers
  IconData _getPurposeIcon(String purpose) {
    switch (purpose.toLowerCase()) {
      case 'payment':
      case 'dues':
      case 'collection':
        return Icons.payments_outlined;
      case 'visit':
      case 'store_visit':
        return Icons.storefront_outlined;
      case 'reorder':
      case 'stock':
      case 'order':
        return Icons.inventory_2_outlined;
      case 'cheque':
        return Icons.receipt_long_outlined;
      default:
        return Icons.alarm_outlined;
    }
  }

  Color _getPurposeColor(String purpose) {
    switch (purpose.toLowerCase()) {
      case 'payment':
      case 'dues':
      case 'collection':
        return const Color(0xFF059669); // Emerald
      case 'visit':
      case 'store_visit':
        return const Color(0xFF1D4ED8); // Blue
      case 'reorder':
      case 'stock':
      case 'order':
        return const Color(0xFFD97706); // Amber
      case 'cheque':
        return const Color(0xFF7C3AED); // Purple
      default:
        return const Color(0xFF475569); // Slate
    }
  }

  String _formatPurposeName(String purpose) {
    switch (purpose.toLowerCase()) {
      case 'payment':
      case 'dues':
        return 'Payment Due';
      case 'visit':
        return 'Store Visit';
      case 'reorder':
      case 'stock':
        return 'Reorder Stock';
      case 'cheque':
        return 'Cheque Clearance';
      default:
        return 'Task Reminder';
    }
  }

  String _getRelativeDueDate(DateTime dueDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final diffDays = dueDay.difference(today).inDays;

    final hour = dueDate.hour > 12 ? dueDate.hour - 12 : (dueDate.hour == 0 ? 12 : dueDate.hour);
    final period = dueDate.hour >= 12 ? 'PM' : 'AM';
    final minute = dueDate.minute.toString().padLeft(2, '0');
    final timeStr = "$hour:$minute $period";

    if (diffDays < 0) {
      final past = -diffDays;
      return past == 1 ? "Overdue by 1 day" : "Overdue by $past days";
    } else if (diffDays == 0) {
      return "Due Today at $timeStr";
    } else if (diffDays == 1) {
      return "Tomorrow at $timeStr";
    } else {
      return "In $diffDays days ($timeStr)";
    }
  }

  void _showAddReminderModal(BuildContext context, {ReminderModel? editingReminder}) {
    final appState = Provider.of<AppState>(context, listen: false);
    final shops = appState.shops;

    final titleCtrl = TextEditingController(text: editingReminder?.title ?? editingReminder?.description ?? '');
    final notesCtrl = TextEditingController(text: editingReminder?.note ?? (editingReminder != null && editingReminder.title != null ? editingReminder.description : ''));
    String selectedPurpose = editingReminder?.purpose ?? 'payment';
    String selectedPriority = editingReminder?.priority ?? 'medium';
    String? selectedShopId = editingReminder?.shopId.isNotEmpty == true ? editingReminder!.shopId : null;
    DateTime selectedDate = editingReminder?.dueDate ?? DateTime.now().add(const Duration(hours: 4));

    final presets = [
      {'title': 'Overdue invoice collection', 'purpose': 'payment', 'priority': 'high'},
      {'title': 'Weekly order booking call', 'purpose': 'reorder', 'priority': 'medium'},
      {'title': 'Cheque clearance verification', 'purpose': 'cheque', 'priority': 'high'},
      {'title': 'Store product replenishment', 'purpose': 'visit', 'priority': 'normal'},
      {'title': 'Monthly distributor ledger sign-off', 'purpose': 'general', 'priority': 'normal'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bCtx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Container(
              margin: EdgeInsets.only(
                bottom: MediaQuery.of(bCtx).viewInsets.bottom,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle Bar
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Title Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            editingReminder == null ? Icons.alarm_add_rounded : Icons.edit_calendar_rounded,
                            color: const Color(0xFF1D4ED8),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                editingReminder == null ? 'Set Business Reminder' : 'Edit Reminder',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.3),
                              ),
                              const Text(
                                'Track retail collections, visits, and order deadlines',
                                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                          onPressed: () => Navigator.pop(bCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Quick Template Presets (when adding new)
                    if (editingReminder == null) ...[
                      const Text(
                        'Quick Preset Templates',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF475569)),
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: presets.map((p) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ActionChip(
                                label: Text(p['title']!),
                                labelStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF1E3A8A)),
                                backgroundColor: const Color(0xFFEFF6FF),
                                side: const BorderSide(color: Color(0xFFBFDBFE)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                onPressed: () {
                                  setModalState(() {
                                    titleCtrl.text = p['title']!;
                                    selectedPurpose = p['purpose']!;
                                    selectedPriority = p['priority']!;
                                  });
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Reminder Purpose Chips
                    const Text(
                      'Category / Purpose *',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        {'id': 'payment', 'label': 'Payment Due', 'icon': Icons.payments_outlined},
                        {'id': 'visit', 'label': 'Store Visit', 'icon': Icons.storefront_outlined},
                        {'id': 'reorder', 'label': 'Stock Reorder', 'icon': Icons.inventory_2_outlined},
                        {'id': 'cheque', 'label': 'Cheque Clearance', 'icon': Icons.receipt_long_outlined},
                        {'id': 'general', 'label': 'General Task', 'icon': Icons.notifications_none_rounded},
                      ].map((item) {
                        final isSel = selectedPurpose == item['id'];
                        final color = _getPurposeColor(item['id'] as String);
                        return InkWell(
                          onTap: () => setModalState(() => selectedPurpose = item['id'] as String),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSel ? color.withValues(alpha: 0.12) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSel ? color : const Color(0xFFE2E8F0),
                                width: isSel ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(item['icon'] as IconData, size: 16, color: isSel ? color : const Color(0xFF64748B)),
                                const SizedBox(width: 6),
                                Text(
                                  item['label'] as String,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                                    color: isSel ? color : const Color(0xFF334155),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Associated Retailer Dropdown
                    const Text(
                      'Linked Retailer / Customer (Optional)',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String?>(
                      isExpanded: true,
                      initialValue: selectedShopId,
                      decoration: InputDecoration(
                        hintText: 'Select Retail Store (or General Business)',
                        prefixIcon: const Icon(Icons.store_rounded),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('General Reminder (No Specific Shop)', style: TextStyle(color: Color(0xFF64748B))),
                        ),
                        ...shops.map((s) => DropdownMenuItem<String?>(
                              value: s.shopId,
                              child: Text(s.shopName, overflow: TextOverflow.ellipsis),
                            )),
                      ],
                      onChanged: (val) => setModalState(() => selectedShopId = val),
                    ),
                    const SizedBox(height: 14),

                    // Title Input
                    TextField(
                      controller: titleCtrl,
                      decoration: InputDecoration(
                        labelText: 'Reminder Task / Title *',
                        hintText: 'e.g. Collect ₹14,500 due from Rajesh Kirana',
                        prefixIcon: const Icon(Icons.title_rounded),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Due Date & Time Picker
                    const Text(
                      'Due Date & Time *',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: bCtx,
                          initialDate: selectedDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 7)),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (pickedDate != null && bCtx.mounted) {
                          final pickedTime = await showTimePicker(
                            context: bCtx,
                            initialTime: TimeOfDay.fromDateTime(selectedDate),
                          );
                          if (pickedTime != null) {
                            setModalState(() {
                              selectedDate = DateTime(
                                pickedDate.year,
                                pickedDate.month,
                                pickedDate.day,
                                pickedTime.hour,
                                pickedTime.minute,
                              );
                            });
                          }
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month_rounded, color: Color(0xFF1D4ED8), size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _getRelativeDueDate(selectedDate),
                                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Change',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF1D4ED8)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Priority Selector
                    const Text(
                      'Priority',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        {'id': 'normal', 'label': 'Normal', 'color': const Color(0xFF64748B)},
                        {'id': 'medium', 'label': 'Medium', 'color': const Color(0xFFD97706)},
                        {'id': 'high', 'label': 'High / Urgent', 'color': const Color(0xFFDC2626)},
                      ].map((item) {
                        final isSel = selectedPriority == item['id'];
                        final color = item['color'] as Color;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: InkWell(
                              onTap: () => setModalState(() => selectedPriority = item['id'] as String),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSel ? color.withValues(alpha: 0.12) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSel ? color : const Color(0xFFCBD5E1),
                                    width: isSel ? 1.5 : 1,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  item['label'] as String,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                                    color: isSel ? color : const Color(0xFF475569),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // Notes / Details
                    TextField(
                      controller: notesCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Additional Notes / Remarks',
                        hintText: 'e.g. Promised payment on Tuesday after bank hours',
                        prefixIcon: const Icon(Icons.notes_rounded),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Submit CTA
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1D4ED8),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () {
                          final title = titleCtrl.text.trim();
                          final notes = notesCtrl.text.trim();
                          if (title.isEmpty) {
                            showAppError(context, 'Please enter a reminder title');
                            return;
                          }

                          ShopModel? linkedShop;
                          if (selectedShopId != null) {
                            linkedShop = shops.firstWhere(
                              (s) => s.shopId == selectedShopId,
                              orElse: () => ShopModel(shopId: '', shopName: '', ownerName: '', visitFrequency: ''),
                            );
                          }

                          if (editingReminder != null) {
                            final updated = editingReminder.copyWith(
                              title: title,
                              description: notes.isNotEmpty ? notes : title,
                              note: notes,
                              purpose: selectedPurpose,
                              priority: selectedPriority,
                              shopId: selectedShopId ?? '',
                              shopName: linkedShop?.shopName,
                              dueDate: selectedDate,
                            );
                            appState.updateReminder(updated);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Reminder "$title" updated'),
                                backgroundColor: const Color(0xFF059669),
                              ),
                            );
                          } else {
                            final newRem = ReminderModel(
                              reminderId: 'rem_${DateTime.now().millisecondsSinceEpoch}',
                              shopId: selectedShopId ?? '',
                              shopName: linkedShop?.shopName,
                              assignedToUid: appState.activeStaffUser?.id ?? appState.uniqueUserId,
                              dueDate: selectedDate,
                              title: title,
                              description: notes.isNotEmpty ? notes : title,
                              note: notes,
                              purpose: selectedPurpose,
                              priority: selectedPriority,
                              isCompleted: false,
                              createdAt: DateTime.now(),
                            );
                            if (!FeatureGate.allowWrite(context, feature: 'visits')) return;
                            appState.addReminder(newRem);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Reminder for "$title" scheduled!'),
                                backgroundColor: const Color(0xFF059669),
                              ),
                            );
                          }

                          Navigator.pop(bCtx);
                        },
                        child: Text(
                          editingReminder == null ? 'Schedule Business Reminder' : 'Save Changes',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                        ),
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

  void _showSnoozeDialog(BuildContext context, ReminderModel reminder) {
    final appState = Provider.of<AppState>(context, listen: false);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: const [
                  Icon(Icons.snooze_rounded, color: Color(0xFFD97706), size: 22),
                  SizedBox(width: 10),
                  Text(
                    'Snooze / Reschedule Reminder',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.timer_outlined, color: Color(0xFF1D4ED8), size: 18),
                ),
                title: const Text('Later Today (+3 Hours)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                subtitle: const Text('Postpone task within today business hours', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                onTap: () {
                  Navigator.pop(ctx);
                  appState.rescheduleReminder(reminder.reminderId, DateTime.now().add(const Duration(hours: 3)));
                  HapticFeedback.lightImpact();
                },
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.wb_sunny_outlined, color: Color(0xFFD97706), size: 18),
                ),
                title: const Text('Tomorrow Morning (10:00 AM)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                subtitle: const Text('Follow up tomorrow during market round', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                onTap: () {
                  Navigator.pop(ctx);
                  final tomorrow = DateTime.now().add(const Duration(days: 1));
                  appState.rescheduleReminder(
                    reminder.reminderId,
                    DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 10, 0),
                  );
                  HapticFeedback.lightImpact();
                },
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.next_plan_outlined, color: Color(0xFF475569), size: 18),
                ),
                title: const Text('Next Week (+7 Days)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                subtitle: const Text('Defer to next weekly delivery cycle', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                onTap: () {
                  Navigator.pop(ctx);
                  appState.rescheduleReminder(reminder.reminderId, DateTime.now().add(const Duration(days: 7)));
                  HapticFeedback.lightImpact();
                },
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFFF3E8FF), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.edit_calendar_outlined, color: Color(0xFF7C3AED), size: 18),
                ),
                title: const Text('Pick Specific Date & Time...', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: reminder.dueDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (pickedDate != null && context.mounted) {
                    final pickedTime = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(reminder.dueDate),
                    );
                    if (pickedTime != null) {
                      appState.rescheduleReminder(
                        reminder.reminderId,
                        DateTime(
                          pickedDate.year,
                          pickedDate.month,
                          pickedDate.day,
                          pickedTime.hour,
                          pickedTime.minute,
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDeleteReminder(BuildContext context, ReminderModel rem) {
    final appState = Provider.of<AppState>(context, listen: false);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626)),
            SizedBox(width: 10),
            Text('Delete Reminder?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently remove "${rem.title ?? rem.description}"?',
          style: const TextStyle(fontSize: 13.5, color: Color(0xFF334155)),
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
            ),
            onPressed: () {
              Navigator.pop(ctx);
              appState.deleteReminder(rem.reminderId);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Reminder deleted'),
                  backgroundColor: Color(0xFF0F172A),
                ),
              );
            },
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allReminders = appState.reminders;

    // Filter calculations
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final pendingReminders = allReminders.where((r) => !r.isCompleted).toList();
    final overdueReminders = pendingReminders.where((r) {
      final d = DateTime(r.dueDate.year, r.dueDate.month, r.dueDate.day);
      return d.isBefore(today);
    }).toList();

    final dueTodayReminders = pendingReminders.where((r) {
      final d = DateTime(r.dueDate.year, r.dueDate.month, r.dueDate.day);
      return d.isAtSameMomentAs(today);
    }).toList();

    final paymentDuesReminders = pendingReminders.where((r) => r.purpose == 'payment' || r.purpose == 'dues').toList();
    final completedReminders = allReminders.where((r) => r.isCompleted).toList();

    // Apply active filter
    List<ReminderModel> filteredList;
    switch (_selectedFilter) {
      case 'Overdue':
        filteredList = overdueReminders;
        break;
      case 'Today':
        filteredList = dueTodayReminders;
        break;
      case 'Upcoming':
        filteredList = pendingReminders.where((r) {
          final d = DateTime(r.dueDate.year, r.dueDate.month, r.dueDate.day);
          return d.isAfter(today);
        }).toList();
        break;
      case 'Payment Dues':
        filteredList = paymentDuesReminders;
        break;
      case 'Completed':
        filteredList = completedReminders;
        break;
      case 'All':
      default:
        filteredList = allReminders;
        break;
    }

    // Apply search query
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      filteredList = filteredList.where((r) {
        final title = (r.title ?? r.description).toLowerCase();
        final note = (r.note ?? '').toLowerCase();
        final shop = (r.shopName ?? '').toLowerCase();
        return title.contains(q) || note.contains(q) || shop.contains(q);
      }).toList();
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Material(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
              },
              child: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : const Color(0xFF0F172A), size: 20),
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reminders & Tasks',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
            Text(
              '${pendingReminders.length} pending • ${overdueReminders.length} overdue',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: overdueReminders.isNotEmpty ? const Color(0xFFDC2626) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1D4ED8),
                foregroundColor: Colors.white,
                elevation: 1,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('+ Reminder', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
              onPressed: () => _showAddReminderModal(context),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. KPI Metric Summary Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                _buildKpiCard(
                  title: 'Pending',
                  count: pendingReminders.length,
                  icon: Icons.alarm_rounded,
                  color: const Color(0xFF1D4ED8),
                  isSelected: _selectedFilter == 'All',
                  onTap: () => setState(() => _selectedFilter = 'All'),
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildKpiCard(
                  title: 'Overdue',
                  count: overdueReminders.length,
                  icon: Icons.warning_amber_rounded,
                  color: const Color(0xFFDC2626),
                  isSelected: _selectedFilter == 'Overdue',
                  onTap: () => setState(() => _selectedFilter = 'Overdue'),
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildKpiCard(
                  title: 'Due Today',
                  count: dueTodayReminders.length,
                  icon: Icons.today_rounded,
                  color: const Color(0xFFD97706),
                  isSelected: _selectedFilter == 'Today',
                  onTap: () => setState(() => _selectedFilter = 'Today'),
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildKpiCard(
                  title: 'Collections',
                  count: paymentDuesReminders.length,
                  icon: Icons.payments_rounded,
                  color: const Color(0xFF059669),
                  isSelected: _selectedFilter == 'Payment Dues',
                  onTap: () => setState(() => _selectedFilter = 'Payment Dues'),
                  isDark: isDark,
                ),
              ],
            ),
          ),

          // 2. Search & Filter Bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                // Search Input
                TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Search tasks, retailers, payment dues...',
                    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                  ),
                ),
                const SizedBox(height: 10),

                // Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      'All',
                      'Overdue',
                      'Today',
                      'Upcoming',
                      'Payment Dues',
                      'Completed',
                    ].map((f) {
                      final isSel = _selectedFilter == f;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedFilter = f);
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSel
                                  ? const Color(0xFF1D4ED8)
                                  : (isDark ? const Color(0xFF1E293B) : Colors.white),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSel ? const Color(0xFF1D4ED8) : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                              ),
                            ),
                            child: Text(
                              f,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                                color: isSel ? Colors.white : (isDark ? const Color(0xFFE2E8F0) : const Color(0xFF475569)),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // 3. Reminders List View
          Expanded(
            child: filteredList.isEmpty
                ? _buildEmptyState(isDark)
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 80),
                    itemCount: filteredList.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, idx) {
                      final rem = filteredList[idx];
                      return _buildReminderCard(context, rem, appState, isDark);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF1D4ED8),
        foregroundColor: Colors.white,
        elevation: 3,
        icon: const Icon(Icons.alarm_add_rounded, size: 20),
        label: const Text('Add Reminder', style: TextStyle(fontWeight: FontWeight.w800)),
        onPressed: () => _showAddReminderModal(context),
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.12)
                : (isDark ? const Color(0xFF0F172A) : Colors.white),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? color : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(height: 4),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? color : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReminderCard(BuildContext context, ReminderModel rem, AppState appState, bool isDark) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(rem.dueDate.year, rem.dueDate.month, rem.dueDate.day);
    final isOverdue = !rem.isCompleted && dueDay.isBefore(today);
    final isDueToday = !rem.isCompleted && dueDay.isAtSameMomentAs(today);

    final purposeColor = _getPurposeColor(rem.purpose);
    final purposeIcon = _getPurposeIcon(rem.purpose);
    final purposeName = _formatPurposeName(rem.purpose);

    // Linked shop if present
    ShopModel? shop;
    if (rem.shopId.isNotEmpty) {
      shop = appState.shops.firstWhere(
        (s) => s.shopId == rem.shopId,
        orElse: () => ShopModel(
          shopId: rem.shopId,
          shopName: rem.shopName ?? 'Associated Retailer',
          ownerName: '',
          visitFrequency: '',
        ),
      );
    }

    Color statusAccentColor;
    if (rem.isCompleted) {
      statusAccentColor = const Color(0xFF10B981);
    } else if (isOverdue) {
      statusAccentColor = const Color(0xFFEF4444);
    } else if (isDueToday) {
      statusAccentColor = const Color(0xFFF59E0B);
    } else {
      statusAccentColor = const Color(0xFF3B82F6);
    }

    return Container(
      decoration: BoxDecoration(
        color: rem.isCompleted
            ? (isDark ? const Color(0xFF1E293B).withValues(alpha: 0.6) : const Color(0xFFF8FAFC))
            : (isDark ? const Color(0xFF1E293B) : Colors.white),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: rem.isCompleted
              ? (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))
              : (isOverdue ? const Color(0xFFFCA5A5) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
          width: isOverdue ? 1.5 : 1,
        ),
        boxShadow: AppTheme.softShadow(blur: 8, dy: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Urgency Left Border Strip
              Container(
                width: 5,
                color: statusAccentColor,
              ),

              // Card Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row: Purpose Chip + Urgency/Overdue + Priority
                      Row(
                        children: [
                          // Purpose Pill
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: purposeColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(purposeIcon, size: 12, color: purposeColor),
                                const SizedBox(width: 4),
                                Text(
                                  purposeName,
                                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: purposeColor),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),

                          // Overdue / Due Today Tag
                          if (isOverdue) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: const Text(
                                'OVERDUE',
                                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: Color(0xFFDC2626)),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ] else if (isDueToday) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: const Text(
                                'TODAY',
                                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: Color(0xFFD97706)),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],

                          // Priority tag if high
                          if (rem.priority.toLowerCase() == 'high' || rem.priority.toLowerCase() == 'urgent') ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'URGENT',
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF991B1B)),
                              ),
                            ),
                          ],

                          const Spacer(),

                          // Quick Action Menu
                          PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.more_vert_rounded, size: 18, color: Color(0xFF94A3B8)),
                            onSelected: (val) {
                              if (val == 'snooze') {
                                _showSnoozeDialog(context, rem);
                              } else if (val == 'edit') {
                                _showAddReminderModal(context, editingReminder: rem);
                              } else if (val == 'delete') {
                                _confirmDeleteReminder(context, rem);
                              }
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(
                                value: 'snooze',
                                child: Row(
                                  children: [
                                    Icon(Icons.snooze_rounded, size: 16, color: Color(0xFFD97706)),
                                    SizedBox(width: 8),
                                    Text('Snooze / Reschedule', style: TextStyle(fontSize: 13)),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_outlined, size: 16, color: Color(0xFF1D4ED8)),
                                    SizedBox(width: 8),
                                    Text('Edit Reminder', style: TextStyle(fontSize: 13)),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline, size: 16, color: Color(0xFFDC2626)),
                                    SizedBox(width: 8),
                                    Text('Delete', style: TextStyle(fontSize: 13, color: Color(0xFFDC2626))),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Title & Complete Checkbox Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              appState.toggleReminder(rem.reminderId);
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              margin: const EdgeInsets.only(top: 2, right: 10),
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: rem.isCompleted ? const Color(0xFF10B981) : Colors.transparent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: rem.isCompleted ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
                                  width: 2,
                                ),
                              ),
                              child: rem.isCompleted
                                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                                  : null,
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  rem.title ?? rem.description,
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                    color: rem.isCompleted
                                        ? const Color(0xFF94A3B8)
                                        : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                    decoration: rem.isCompleted ? TextDecoration.lineThrough : null,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                if (rem.note != null && rem.note!.isNotEmpty && rem.note != rem.title) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    rem.note!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Linked Retailer Details + Actions
                      if (shop != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.5) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.storefront_rounded, size: 15, color: Color(0xFF64748B)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  shop.shopName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                                  ),
                                ),
                              ),
                              if (shop.phone != null && shop.phone!.isNotEmpty) ...[
                                InkWell(
                                  onTap: () {
                                    Clipboard.setData(ClipboardData(text: shop?.phone ?? ''));
                                    HapticFeedback.lightImpact();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Phone ${shop?.phone} copied to clipboard'),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDCFCE7),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.phone_rounded, size: 12, color: Color(0xFF16A34A)),
                                        const SizedBox(width: 3),
                                        Text(
                                          shop.phone!,
                                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF16A34A)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],

                      // Footer: Due Date Badge & Quick Snooze
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isOverdue ? Icons.error_outline_rounded : Icons.schedule_rounded,
                                size: 14,
                                color: isOverdue ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _getRelativeDueDate(rem.dueDate),
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: isOverdue ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                          if (!rem.isCompleted) ...[
                            InkWell(
                              onTap: () => _showSnoozeDialog(context, rem),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  children: const [
                                    Icon(Icons.snooze_rounded, size: 13, color: Color(0xFFD97706)),
                                    SizedBox(width: 4),
                                    Text(
                                      'Snooze',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFD97706)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFBFDBFE), width: 1.5),
              ),
              child: const Icon(Icons.check_circle_outline_rounded, size: 40, color: Color(0xFF1D4ED8)),
            ),
            const SizedBox(height: 18),
            Text(
              _searchQuery.isNotEmpty ? 'No Matching Reminders' : 'All Caught Up!',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No task reminders match "$_searchQuery". Try clearing your search.'
                  : 'You have no pending reminders in this category. Schedule a reminder to keep collections on track.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1D4ED8),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Create New Reminder', style: TextStyle(fontWeight: FontWeight.w800)),
              onPressed: () => _showAddReminderModal(context),
            ),
          ],
        ),
      ),
    );
  }
}
