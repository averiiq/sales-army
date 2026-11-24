import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/features/visits/data/models/visit_model.dart';
import 'package:salesarmy/features/visits/data/models/reminder_model.dart';
import 'package:salesarmy/features/shops/data/models/shop_model.dart';
import 'package:salesarmy/core/theme/app_theme.dart';
import 'package:salesarmy/core/utils/formatters.dart';
import 'package:salesarmy/core/utils/feature_gate.dart';

class VisitsTab extends StatefulWidget {
  final VoidCallback? onBack;
  const VisitsTab({super.key, this.onBack});

  @override
  State<VisitsTab> createState() => _VisitsTabState();
}

class _VisitsTabState extends State<VisitsTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _confirmDeleteReminder(BuildContext context, ReminderModel reminder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Reminder', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        content: Text('Are you sure you want to delete "${reminder.title ?? reminder.description}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<AppState>().deleteReminder(reminder.reminderId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reminder deleted')),
      );
    }
  }

  Future<void> _confirmDeleteVisit(BuildContext context, VisitModel visit, String shopName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Beat Visit', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        content: Text('Are you sure you want to delete this visit to $shopName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<AppState>().deleteVisit(visit.visitId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Visit deleted')),
      );
    }
  }

  void _showAddReminderModal(BuildContext context, List<ShopModel> shops, {ReminderModel? existingReminder}) {
    ShopModel? selectedShop = existingReminder != null
        ? shops.cast<ShopModel?>().firstWhere(
            (s) => s?.shopId == existingReminder.shopId,
            orElse: () => shops.isNotEmpty ? shops.first : null,
          )
        : (shops.isNotEmpty ? shops.first : null);
    DateTime selectedDate = existingReminder?.dueDate ?? DateTime.now().add(const Duration(hours: 2));
    String selectedPurpose = existingReminder?.purpose ?? 'Payment';
    String selectedPriority = existingReminder?.priority ?? 'High';
    String selectedDatePreset = 'Today';
    String alertLeadTime = '15 mins before';
    String repeatFreq = 'Does not repeat';
    bool showAdvanceOptions = false;
    final titleCtrl = TextEditingController(text: existingReminder?.title ?? existingReminder?.description ?? '');
    final noteCtrl = TextEditingController(text: existingReminder?.note ?? '');

    String formatTime(DateTime dt) {
      final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final m = dt.minute.toString().padLeft(2, '0');
      final p = dt.hour >= 12 ? 'PM' : 'AM';
      return '$h:$m $p';
    }

    final purposes = [
      {'key': 'Payment', 'label': 'Payment Collection', 'icon': '💰', 'color': 0xFF059669},
      {'key': 'Order', 'label': 'Order Booking', 'icon': '📦', 'color': 0xFF1D4ED8},
      {'key': 'Stock', 'label': 'Stock Dispatch', 'icon': '🏷️', 'color': 0xFF7C3AED},
      {'key': 'Visit', 'label': 'Beat Store Visit', 'icon': '🚶', 'color': 0xFFD97706},
      {'key': 'Call', 'label': 'Phone Call', 'icon': '📞', 'color': 0xFF0284C7},
      {'key': 'Cheque', 'label': 'Cheque / DD Collect', 'icon': '🏦', 'color': 0xFF0D9488},
      {'key': 'Overdue', 'label': 'Overdue Bill Followup', 'icon': '⚠️', 'color': 0xFFDC2626},
      {'key': 'Audit', 'label': 'Stock Tally & Audit', 'icon': '🔍', 'color': 0xFF4F46E5},
      {'key': 'Sample', 'label': 'Samples & Schemes', 'icon': '🎁', 'color': 0xFFDB2777},
      {'key': 'General', 'label': 'General Business Task', 'icon': '📝', 'color': 0xFF475569},
    ];

    final isDark = context.read<AppState>().isDarkMode;
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void setPresetDate(String preset) {
              HapticFeedback.selectionClick();
              final now = DateTime.now();
              DateTime target;
              switch (preset) {
                case 'Today':
                  target = DateTime(now.year, now.month, now.day, selectedDate.hour, selectedDate.minute);
                  break;
                case 'Tomorrow':
                  final d = now.add(const Duration(days: 1));
                  target = DateTime(d.year, d.month, d.day, selectedDate.hour, selectedDate.minute);
                  break;
                case 'In 2 Days':
                  final d = now.add(const Duration(days: 2));
                  target = DateTime(d.year, d.month, d.day, selectedDate.hour, selectedDate.minute);
                  break;
                case 'This Weekend':
                  final daysUntilSat = (DateTime.saturday - now.weekday + 7) % 7;
                  final d = now.add(Duration(days: daysUntilSat == 0 ? 7 : daysUntilSat));
                  target = DateTime(d.year, d.month, d.day, 10, 0);
                  break;
                case 'Next Monday':
                  final daysUntilMon = (DateTime.monday - now.weekday + 7) % 7;
                  final d = now.add(Duration(days: daysUntilMon == 0 ? 7 : daysUntilMon));
                  target = DateTime(d.year, d.month, d.day, 10, 0);
                  break;
                case 'Month End':
                  final lastDay = DateTime(now.year, now.month + 1, 0);
                  target = DateTime(lastDay.year, lastDay.month, lastDay.day, 17, 0);
                  break;
                default:
                  target = selectedDate;
              }
              setDialogState(() {
                selectedDatePreset = preset;
                selectedDate = target;
              });
            }

            void setQuickTime(int hour, int minute) {
              HapticFeedback.selectionClick();
              setDialogState(() {
                selectedDate = DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day,
                  hour,
                  minute,
                );
              });
            }

            return Dialog(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              clipBehavior: Clip.antiAlias,
              child: Container(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                constraints: const BoxConstraints(maxWidth: 540, maxHeight: 760),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF78350F).withValues(alpha: 0.35) : const Color(0xFFFEF3C7),
                        border: Border(bottom: BorderSide(color: isDark ? const Color(0xFFB45309).withValues(alpha: 0.4) : const Color(0xFFFDE68A))),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD97706),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.alarm_add_rounded, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  existingReminder != null ? 'Edit Business Reminder' : 'Set Rich Business Reminder',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E)),
                                ),
                                Text(
                                  existingReminder != null ? 'Update task alert details, notes & schedule' : 'Schedule automated task alerts with priority & notes',
                                  style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309)),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E), size: 20),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                    ),

                    // Scrollable Form Body
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Purpose Selector Pills
                            const Text(
                              'Reminder Purpose / Type *',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: purposes.map((p) {
                                final isSel = selectedPurpose == p['key'];
                                final color = Color(p['color'] as int);
                                return InkWell(
                                  onTap: () {
                                    setDialogState(() {
                                      selectedPurpose = p['key'] as String;
                                      if (p['key'] == 'Payment') {
                                        titleCtrl.text = 'Collect outstanding payment / balance';
                                      } else if (p['key'] == 'Order') {
                                        titleCtrl.text = 'Book new replenishment stock order';
                                      } else if (p['key'] == 'Stock') {
                                        titleCtrl.text = 'Deliver pending product cartons';
                                      } else if (p['key'] == 'Visit') {
                                        titleCtrl.text = 'Routine retailer store visit';
                                      } else if (p['key'] == 'Call') {
                                        titleCtrl.text = 'Follow-up phone call with owner';
                                      } else if (p['key'] == 'Cheque') {
                                        titleCtrl.text = 'Collect signed cheque / DD from shop';
                                      } else if (p['key'] == 'Overdue') {
                                        titleCtrl.text = 'Urgent reminder: Overdue invoice pending 30+ days';
                                      } else if (p['key'] == 'Audit') {
                                        titleCtrl.text = 'Conduct retailer shelf stock count & audit';
                                      } else if (p['key'] == 'Sample') {
                                        titleCtrl.text = 'Show new product samples & trade scheme catalogue';
                                      } else if (p['key'] == 'General') {
                                        titleCtrl.text = 'Follow-up on pending agency business';
                                      }
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isSel ? color.withValues(alpha: 0.12) : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isSel ? color : const Color(0xFFE2E8F0),
                                        width: isSel ? 1.5 : 1.0,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(p['icon'] as String, style: const TextStyle(fontSize: 13)),
                                        const SizedBox(width: 5),
                                        Text(
                                          p['label'] as String,
                                          style: TextStyle(
                                            color: isSel ? color : const Color(0xFF334155),
                                            fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 16),

                            // 2. Priority Selector
                            const Text(
                              'Priority Level *',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                for (final pr in ['High', 'Medium', 'Low'])
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 3),
                                      child: InkWell(
                                        onTap: () => setDialogState(() => selectedPriority = pr),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          decoration: BoxDecoration(
                                            color: selectedPriority == pr
                                                ? (pr == 'High'
                                                    ? const Color(0xFFFEF2F2)
                                                    : pr == 'Medium'
                                                        ? const Color(0xFFFFFBEB)
                                                        : const Color(0xFFF0FDF4))
                                                : const Color(0xFFF8FAFC),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: selectedPriority == pr
                                                  ? (pr == 'High'
                                                      ? const Color(0xFFDC2626)
                                                      : pr == 'Medium'
                                                          ? const Color(0xFFD97706)
                                                          : const Color(0xFF16A34A))
                                                  : const Color(0xFFE2E8F0),
                                              width: selectedPriority == pr ? 1.5 : 1.0,
                                            ),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            pr == 'High' ? '🔴 High' : pr == 'Medium' ? '🟡 Medium' : '🟢 Low',
                                            style: TextStyle(
                                              fontWeight: selectedPriority == pr ? FontWeight.w800 : FontWeight.w600,
                                              fontSize: 12,
                                              color: selectedPriority == pr ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // 3. ADVANCED DATE & TIME CONTROLS
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Schedule Date & Time *',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Tap either card to adjust',
                                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Dual High-Contrast Interactive Date & Time Cards
                            Row(
                              children: [
                                // Prominent Date Card Button
                                Expanded(
                                  child: InkWell(
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: selectedDate,
                                        firstDate: DateTime.now().subtract(const Duration(days: 1)),
                                        lastDate: DateTime.now().add(const Duration(days: 365)),
                                      );
                                      if (picked != null) {
                                        setDialogState(() {
                                          selectedDate = DateTime(
                                            picked.year,
                                            picked.month,
                                            picked.day,
                                            selectedDate.hour,
                                            selectedDate.minute,
                                          );
                                          selectedDatePreset = 'Custom';
                                        });
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF0FDF4),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: const Color(0xFF16A34A), width: 1.8),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                                            blurRadius: 10,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.all(5),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFF16A34A),
                                                      borderRadius: BorderRadius.circular(7),
                                                    ),
                                                    child: const Icon(Icons.calendar_today_rounded, size: 14, color: Colors.white),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  const Text(
                                                    'DATE',
                                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF15803D), letterSpacing: 0.5),
                                                  ),
                                                ],
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFDCFCE7),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: const Text('Pick 🗓️', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFF166534))),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            AppFormatters.date(selectedDate),
                                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.2),
                                          ),
                                          const SizedBox(height: 3),
                                          const Text(
                                            'Tap to select calendar',
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF15803D)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Prominent Time Card Button
                                Expanded(
                                  child: InkWell(
                                    onTap: () async {
                                      final picked = await showTimePicker(
                                        context: context,
                                        initialTime: TimeOfDay.fromDateTime(selectedDate),
                                      );
                                      if (picked != null) {
                                        setDialogState(() {
                                          selectedDate = DateTime(
                                            selectedDate.year,
                                            selectedDate.month,
                                            selectedDate.day,
                                            picked.hour,
                                            picked.minute,
                                          );
                                        });
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: const Color(0xFF2563EB), width: 1.8),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                                            blurRadius: 10,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.all(5),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFF2563EB),
                                                      borderRadius: BorderRadius.circular(7),
                                                    ),
                                                    child: const Icon(Icons.access_time_filled_rounded, size: 14, color: Colors.white),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  const Text(
                                                    'TIME',
                                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF1D4ED8), letterSpacing: 0.5),
                                                  ),
                                                ],
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFDBEAFE),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: const Text('Pick ⏰', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFF1E40AF))),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            formatTime(selectedDate),
                                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.2),
                                          ),
                                          const SizedBox(height: 3),
                                          const Text(
                                            'Tap to select time',
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // Active Schedule Highlight Banner
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFFDE68A)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.alarm_on_rounded, size: 16, color: Color(0xFFB45309)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Alarm scheduled: ${AppFormatters.date(selectedDate)} at ${formatTime(selectedDate)}',
                                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF92400E)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Quick Date Presets
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: ['Today', 'Tomorrow', 'In 2 Days', 'This Weekend', 'Next Monday', 'Month End'].map((preset) {
                                  final isSel = selectedDatePreset == preset;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: InkWell(
                                      onTap: () => setPresetDate(preset),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: isSel ? const Color(0xFFDCFCE7) : const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: isSel ? const Color(0xFF16A34A) : const Color(0xFFCBD5E1),
                                          ),
                                        ),
                                        child: Text(
                                          preset,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                                            color: isSel ? const Color(0xFF166534) : const Color(0xFF334155),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Quick Time Slots
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  {'label': '09:30 AM', 'h': 9, 'm': 30},
                                  {'label': '11:00 AM', 'h': 11, 'm': 0},
                                  {'label': '02:00 PM', 'h': 14, 'm': 0},
                                  {'label': '04:30 PM', 'h': 16, 'm': 30},
                                  {'label': '07:30 PM', 'h': 19, 'm': 30},
                                  {'label': '09:00 PM', 'h': 21, 'm': 0},
                                ].map((slot) {
                                  final isCurrentTime = selectedDate.hour == slot['h'] && selectedDate.minute == slot['m'];
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: InkWell(
                                      onTap: () => setQuickTime(slot['h'] as int, slot['m'] as int),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isCurrentTime ? const Color(0xFFDBEAFE) : Colors.white,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: isCurrentTime ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.alarm,
                                              size: 11,
                                              color: isCurrentTime ? const Color(0xFF1D4ED8) : const Color(0xFF64748B),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              slot['label'] as String,
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: isCurrentTime ? FontWeight.w800 : FontWeight.w500,
                                                color: isCurrentTime ? const Color(0xFF1D4ED8) : const Color(0xFF475569),
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
                            const SizedBox(height: 12),

                            // Expandable Advance Options Section
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  InkWell(
                                    onTap: () => setDialogState(() => showAdvanceOptions = !showAdvanceOptions),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.tune_rounded, size: 16, color: Color(0xFF475569)),
                                          const SizedBox(width: 8),
                                          const Expanded(
                                            child: Text(
                                              'Advance Reminder Options',
                                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFE2E8F0),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              showAdvanceOptions ? 'Hide' : 'Configure',
                                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Icon(
                                            showAdvanceOptions ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                            size: 18,
                                            color: const Color(0xFF64748B),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (showAdvanceOptions) ...[
                                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                                    Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Alert Lead-time Notification',
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                                          ),
                                          const SizedBox(height: 6),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 6,
                                            children: ['At event time', '15 mins before', '30 mins before', '1 hour before', '1 day before'].map((lead) {
                                              final isSel = alertLeadTime == lead;
                                              return InkWell(
                                                onTap: () => setDialogState(() => alertLeadTime = lead),
                                                borderRadius: BorderRadius.circular(6),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: isSel ? const Color(0xFFFEF3C7) : Colors.white,
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(
                                                      color: isSel ? const Color(0xFFD97706) : const Color(0xFFCBD5E1),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    lead,
                                                    style: TextStyle(
                                                      fontSize: 10.5,
                                                      fontWeight: isSel ? FontWeight.w800 : FontWeight.w500,
                                                      color: isSel ? const Color(0xFF92400E) : const Color(0xFF475569),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                          const SizedBox(height: 12),
                                          const Text(
                                            'Repeat / Recurrence',
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                                          ),
                                          const SizedBox(height: 6),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 6,
                                            children: ['Does not repeat', 'Daily', 'Weekly', 'Monthly'].map((rep) {
                                              final isSel = repeatFreq == rep;
                                              return InkWell(
                                                onTap: () => setDialogState(() => repeatFreq = rep),
                                                borderRadius: BorderRadius.circular(6),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: isSel ? const Color(0xFFEDE9FE) : Colors.white,
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(
                                                      color: isSel ? const Color(0xFF7C3AED) : const Color(0xFFCBD5E1),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    rep,
                                                    style: TextStyle(
                                                      fontSize: 10.5,
                                                      fontWeight: isSel ? FontWeight.w800 : FontWeight.w500,
                                                      color: isSel ? const Color(0xFF5B21B6) : const Color(0xFF475569),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // 4. Associated Shop Picker
                            if (shops.isNotEmpty) ...[
                              DropdownButtonFormField<ShopModel?>(
                                initialValue: selectedShop,
                                decoration: const InputDecoration(
                                  labelText: 'Associated Retailer Store (Optional)',
                                  prefixIcon: Icon(Icons.storefront_outlined),
                                ),
                                items: [
                                  const DropdownMenuItem<ShopModel?>(
                                    value: null,
                                    child: Text('General Reminder (No Specific Shop)'),
                                  ),
                                  ...shops.map((s) => DropdownMenuItem<ShopModel?>(
                                        value: s,
                                        child: Text(s.shopName, maxLines: 1, overflow: TextOverflow.ellipsis),
                                      )),
                                ],
                                onChanged: (val) => setDialogState(() => selectedShop = val),
                              ),
                              const SizedBox(height: 14),
                            ],

                            // 5. Task Description / Title
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Reminder Title & Purpose *',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text('Required', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF1D4ED8))),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: titleCtrl,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                                  decoration: InputDecoration(
                                    labelText: 'Reminder Task / Title *',
                                    hintText: 'e.g. Collect ₹12,500 pending invoice payment',
                                    prefixIcon: const Icon(Icons.task_alt_rounded, color: Color(0xFF1E56E2)),
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.clear_rounded, size: 18),
                                      onPressed: () => titleCtrl.clear(),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Quick Title Presets (tap to fill):',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                                ),
                                const SizedBox(height: 6),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      '💰 Collect ₹ Balance',
                                      '📦 Book Stock Order',
                                      '🏷️ Deliver Cartons',
                                      '🏦 Collect Cheque / DD',
                                      '⚠️ Overdue Invoice',
                                      '🚶 Routine Beat Visit',
                                      '📞 Owner Follow-up Call',
                                      '🔍 Stock Tally & Count',
                                      '🎁 New Scheme Presentation',
                                    ].map((preset) => Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: InkWell(
                                        onTap: () {
                                          HapticFeedback.lightImpact();
                                          setDialogState(() {
                                            titleCtrl.text = preset.substring(3).trim();
                                          });
                                        },
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: const Color(0xFFCBD5E1)),
                                          ),
                                          child: Text(
                                            preset,
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                                          ),
                                        ),
                                      ),
                                    )).toList(),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // 6. Detailed Notes / Instructions
                            TextField(
                              controller: noteCtrl,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText: 'Additional Notes / Instructions (Optional)',
                                hintText: 'e.g. Owner available only in evening. Carry delivery challan.',
                                prefixIcon: Icon(Icons.notes_rounded),
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
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E56E2),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: () {
                                final title = titleCtrl.text.trim();
                                if (title.isEmpty) return;

                                final advanceInfo = <String>[];
                                if (alertLeadTime != 'At event time') advanceInfo.add('Alert: $alertLeadTime');
                                if (repeatFreq != 'Does not repeat') advanceInfo.add('Repeat: $repeatFreq');

                                final noteContent = [
                                  if (noteCtrl.text.trim().isNotEmpty) noteCtrl.text.trim(),
                                  if (advanceInfo.isNotEmpty) 'Schedule Info: ${advanceInfo.join(', ')}',
                                ].join('\n\n');

                                final appState = context.read<AppState>();
                                if (existingReminder != null) {
                                  final updated = existingReminder.copyWith(
                                    shopId: selectedShop?.shopId ?? '',
                                    shopName: selectedShop?.shopName,
                                    dueDate: selectedDate,
                                    title: title,
                                    purpose: selectedPurpose,
                                    priority: selectedPriority,
                                    note: noteContent.isNotEmpty ? noteContent : null,
                                    description: '[$selectedPurpose] $title',
                                  );
                                  appState.updateReminder(updated);
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Reminder for "$title" updated successfully!'),
                                      backgroundColor: AppTheme.success,
                                    ),
                                  );
                                } else {
                                  final reminder = ReminderModel(
                                    reminderId: 'rem_${DateTime.now().millisecondsSinceEpoch}',
                                    shopId: selectedShop?.shopId ?? '',
                                    shopName: selectedShop?.shopName,
                                    assignedToUid: appState.currentUid ?? 'user',
                                    dueDate: selectedDate,
                                    title: title,
                                    purpose: selectedPurpose,
                                    priority: selectedPriority,
                                    note: noteContent.isNotEmpty ? noteContent : null,
                                    description: '[$selectedPurpose] $title',
                                    isCompleted: false,
                                  );
                                  if (!FeatureGate.allowWrite(context, feature: 'visits')) return;
                                  appState.addReminder(reminder);
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Reminder for "$title" scheduled successfully!'),
                                      backgroundColor: AppTheme.success,
                                    ),
                                  );
                                }
                              },
                              child: Text(existingReminder != null ? 'Update Business Reminder' : 'Save Business Reminder', style: const TextStyle(fontWeight: FontWeight.w800)),
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

  void _showScheduleVisitModal(BuildContext context, List<ShopModel> shops, {VisitModel? existingVisit}) {
    if (shops.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please register a retail outlet first before scheduling a beat visit.'),
          backgroundColor: Color(0xFF1E293B),
        ),
      );
      return;
    }
    ShopModel selectedShop = existingVisit != null
        ? shops.firstWhere(
            (s) => s.shopId == existingVisit.shopId,
            orElse: () => shops.first,
          )
        : shops.first;
    DateTime selectedDate = existingVisit?.checkInTime ?? DateTime.now().add(const Duration(hours: 3));
    final noteCtrl = TextEditingController(text: existingVisit?.notes ?? '');

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              insetPadding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 480),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(existingVisit != null ? 'Edit Scheduled Visit' : 'Schedule Beat Visit', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const Divider(height: 20),
                    DropdownButtonFormField<ShopModel>(
                      initialValue: selectedShop,
                      decoration: const InputDecoration(labelText: 'Select Retail Outlet'),
                      items: shops.map((s) => DropdownMenuItem(value: s, child: Text(s.shopName))).toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedShop = val);
                      },
                    ),
                    const SizedBox(height: 14),
                    ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: AppTheme.border)),
                      leading: const Icon(Icons.calendar_month, color: AppTheme.accent),
                      title: Text(AppFormatters.dateTime(selectedDate)),
                      subtitle: const Text('Tap to pick scheduled date & time'),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 30)),
                          lastDate: DateTime.now().add(const Duration(days: 90)),
                        );
                        if (date != null && context.mounted) {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(selectedDate),
                          );
                          if (time != null) {
                            setDialogState(() {
                              selectedDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                            });
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: noteCtrl,
                      decoration: const InputDecoration(labelText: 'Purpose / Field Notes'),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        final appState = context.read<AppState>();
                        if (existingVisit != null) {
                          final updated = existingVisit.copyWith(
                            shopId: selectedShop.shopId,
                            checkInTime: selectedDate,
                            notes: noteCtrl.text.trim(),
                          );
                          appState.updateVisit(updated);
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Field visit updated!'), backgroundColor: AppTheme.success),
                          );
                        } else {
                          final visit = VisitModel(
                            visitId: 'vis_${DateTime.now().millisecondsSinceEpoch}',
                            shopId: selectedShop.shopId,
                            distributorUid: appState.currentUid ?? 'user',
                            checkInTime: selectedDate,
                            notes: noteCtrl.text.trim(),
                          );
                          if (!FeatureGate.allowWrite(context, feature: 'visits')) return;
                          appState.addVisit(visit);
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Field visit scheduled!'), backgroundColor: AppTheme.success),
                          );
                        }
                      },
                      child: Text(existingVisit != null ? 'Update Visit' : 'Schedule Visit'),
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

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final upcomingVisits = appState.visits.where((v) => v.checkOutTime == null).toList();
    final completedVisits = appState.visits.where((v) => v.checkOutTime != null).toList();
    final isDark = appState.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.getVisitsGradient(isDark),
        ),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                    width: 1.0,
                  ),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (widget.onBack != null) ...[
                      Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            widget.onBack?.call();
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Icon(Icons.arrow_back_rounded, size: 20, color: isDark ? Colors.white : const Color(0xFF334155)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      'Reminders & Field Visits',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => _showAddReminderModal(context, appState.shops),
                      icon: const Icon(Icons.alarm_add_rounded, size: 18, color: Color(0xFFD97706)),
                      label: const Text(
                        '+ Reminder',
                        style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFD97706)),
                      ),
                    ),
                    const SizedBox(width: 4),
                    TextButton.icon(
                      onPressed: () => _showScheduleVisitModal(context, appState.shops),
                      icon: const Icon(Icons.add_rounded, size: 18, color: Color(0xFF1D4ED8)),
                      label: const Text(
                        'Schedule',
                        style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1D4ED8)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: const Color(0xFF1E56E2),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1E56E2).withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: const Color(0xFF64748B),
                labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                tabs: [
                  Tab(text: 'Upcoming (${upcomingVisits.length})'),
                  Tab(text: 'Completed (${completedVisits.length})'),
                  Tab(text: 'Reminders (${appState.reminders.length})'),
                ],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Upcoming Visits
                upcomingVisits.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(Icons.route_rounded, size: 32, color: Color(0xFF1D4ED8)),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'No Upcoming Beat Visits',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Schedule your daily route stops to track retailer check-ins.',
                              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: upcomingVisits.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, idx) {
                          final visit = upcomingVisits[idx];
                          final shopMatches = appState.shops.where((s) => s.shopId == visit.shopId);
                          final shop = shopMatches.isNotEmpty ? shopMatches.first : (appState.shops.isNotEmpty ? appState.shops.first : ShopModel(
                            shopId: visit.shopId,
                            shopName: 'Shop #${visit.shopId}',
                            ownerName: 'Retailer',
                            phone: '-',
                            address: 'Field Beat',
                          ));

                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: AppTheme.softShadow(blur: 14, dy: 4),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(Icons.location_on_rounded, color: Color(0xFF1D4ED8), size: 22),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            shop.shopName,
                                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: Color(0xFF0F172A)),
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              const Icon(Icons.access_time_rounded, size: 13, color: Color(0xFF1D4ED8)),
                                              const SizedBox(width: 4),
                                              Text(
                                                AppFormatters.dateTime(visit.checkInTime),
                                                style: const TextStyle(color: Color(0xFF1D4ED8), fontWeight: FontWeight.w700, fontSize: 12),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF3C7),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFFDE68A)),
                                      ),
                                      child: Text(
                                        shop.visitFrequency.toUpperCase(),
                                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFFB45309)),
                                      ),
                                    ),
                                  ],
                                ),
                                if (visit.notes != null && visit.notes!.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Text(
                                      'Note: ${visit.notes}',
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Khata Dues', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                                        Text(
                                          AppFormatters.currency(shop.currentOutstanding),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 14,
                                            color: shop.currentOutstanding > 0 ? const Color(0xFFDC2626) : const Color(0xFF059669),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF1D4ED8)),
                                          tooltip: 'Edit Visit',
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () => _showScheduleVisitModal(context, appState.shops, existingVisit: visit),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Color(0xFFDC2626)),
                                          tooltip: 'Delete Visit',
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () => _confirmDeleteVisit(context, visit, shop.shopName),
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF059669),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            elevation: 0,
                                          ),
                                          onPressed: () {
                                            HapticFeedback.lightImpact();
                                            appState.completeVisit(visit.visitId);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Marked visit to ${shop.shopName} as completed!'),
                                                backgroundColor: const Color(0xFF059669),
                                              ),
                                            );
                                          },
                                          icon: const Icon(Icons.check_circle_rounded, size: 16, color: Colors.white),
                                          label: const Text('Mark Complete', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
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

                // Completed Visits
                completedVisits.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(Icons.verified_rounded, size: 32, color: Color(0xFF16A34A)),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'No Completed Visits Yet',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Completed retailer visits and order placements will appear here.',
                              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: completedVisits.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, idx) {
                          final visit = completedVisits[idx];
                          final shopMatches = appState.shops.where((s) => s.shopId == visit.shopId);
                          final shop = shopMatches.isNotEmpty ? shopMatches.first : (appState.shops.isNotEmpty ? appState.shops.first : ShopModel(
                            shopId: visit.shopId,
                            shopName: 'Shop #${visit.shopId}',
                            ownerName: 'Retailer',
                            phone: '-',
                            address: 'Field Beat',
                          ));

                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: AppTheme.softShadow(blur: 14, dy: 4),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0FDF4),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.verified_rounded, color: Color(0xFF16A34A), size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        shop.shopName,
                                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A)),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Completed: ${AppFormatters.dateTime(visit.checkOutTime)}',
                                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 11.5, fontWeight: FontWeight.w500),
                                      ),
                                      if (visit.orderPlaced) ...[
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFDCFCE7),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            '✓ Order Placed',
                                            style: TextStyle(color: Color(0xFF15803D), fontSize: 10.5, fontWeight: FontWeight.w800),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 19, color: Color(0xFF1D4ED8)),
                                      tooltip: 'Edit Visit',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => _showScheduleVisitModal(context, appState.shops, existingVisit: visit),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, size: 19, color: Color(0xFFDC2626)),
                                      tooltip: 'Delete Visit',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => _confirmDeleteVisit(context, visit, shop.shopName),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                // Reminders & Tasks Tab
                appState.reminders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(Icons.alarm_on_rounded, size: 32, color: Color(0xFFD97706)),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'No Active Reminders',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Tap + Reminder to track follow-ups and dues collections.',
                              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: appState.reminders.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, idx) {
                          final rem = appState.reminders[idx];
                          final shop = rem.shopId.isNotEmpty
                              ? appState.shops.firstWhere(
                                  (s) => s.shopId == rem.shopId,
                                  orElse: () => ShopModel(
                                    shopId: rem.shopId,
                                    shopName: 'Associated Retailer',
                                    ownerName: '',
                                    visitFrequency: '',
                                  ),
                                )
                              : null;
                          final isOverdue = !rem.isCompleted && rem.dueDate.isBefore(DateTime.now());

                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: rem.isCompleted ? const Color(0xFFF8FAFC) : Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: rem.isCompleted
                                    ? const Color(0xFFE2E8F0)
                                    : (isOverdue ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0)),
                              ),
                              boxShadow: AppTheme.softShadow(blur: 10, dy: 3),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                InkWell(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    if (!rem.isCompleted) {
                                      appState.completeReminder(rem.reminderId);
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    margin: const EdgeInsets.only(top: 2),
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: rem.isCompleted ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: rem.isCompleted ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                                      ),
                                    ),
                                    child: Icon(
                                      rem.isCompleted ? Icons.check_rounded : Icons.circle_outlined,
                                      size: 16,
                                      color: rem.isCompleted ? const Color(0xFF16A34A) : Colors.transparent,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          // Purpose Badge
                                          if (rem.purpose.isNotEmpty) ...[
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: rem.purpose == 'Payment'
                                                    ? const Color(0xFFDCFCE7)
                                                    : rem.purpose == 'Order'
                                                        ? const Color(0xFFEFF6FF)
                                                        : rem.purpose == 'Stock'
                                                            ? const Color(0xFFF3E8FF)
                                                            : const Color(0xFFFEF3C7),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                rem.purpose == 'Payment'
                                                    ? '💰 Payment'
                                                    : rem.purpose == 'Order'
                                                        ? '📦 Order'
                                                        : rem.purpose == 'Stock'
                                                            ? '🏷️ Stock'
                                                            : rem.purpose == 'Visit'
                                                                ? '🚶 Visit'
                                                                : '📞 Call',
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: rem.purpose == 'Payment'
                                                      ? const Color(0xFF15803D)
                                                      : rem.purpose == 'Order'
                                                          ? const Color(0xFF1D4ED8)
                                                          : rem.purpose == 'Stock'
                                                              ? const Color(0xFF7C3AED)
                                                              : const Color(0xFFB45309),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                          ],

                                          // Priority Badge
                                          if (rem.priority.isNotEmpty) ...[
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: rem.priority == 'High'
                                                    ? const Color(0xFFFEF2F2)
                                                    : rem.priority == 'Medium'
                                                        ? const Color(0xFFFFFBEB)
                                                        : const Color(0xFFF0FDF4),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                rem.priority == 'High' ? '🔴 High' : rem.priority == 'Medium' ? '🟡 Med' : '🟢 Low',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w800,
                                                  color: rem.priority == 'High'
                                                      ? const Color(0xFFDC2626)
                                                      : rem.priority == 'Medium'
                                                          ? const Color(0xFFD97706)
                                                          : const Color(0xFF16A34A),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                          ],

                                          // Shop or General
                                          if (shop != null)
                                            Expanded(
                                              child: Text(
                                                shop.shopName,
                                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),

                                          if (isOverdue)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFEF2F2),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: const Text(
                                                'OVERDUE',
                                                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: Color(0xFFDC2626)),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        rem.title ?? rem.description,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: rem.isCompleted ? FontWeight.w500 : FontWeight.w800,
                                          color: rem.isCompleted ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                                          decoration: rem.isCompleted ? TextDecoration.lineThrough : null,
                                        ),
                                      ),
                                      if (rem.note != null && rem.note!.isNotEmpty) ...[
                                        const SizedBox(height: 5),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF8FAFC),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: const Color(0xFFE2E8F0)),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.notes_rounded, size: 13, color: Color(0xFF64748B)),
                                              const SizedBox(width: 5),
                                              Expanded(
                                                child: Text(
                                                  rem.note!,
                                                  style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontStyle: FontStyle.italic),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Icon(Icons.access_time_rounded, size: 12, color: isOverdue ? const Color(0xFFDC2626) : const Color(0xFF64748B)),
                                          const SizedBox(width: 4),
                                          Text(
                                            AppFormatters.dateTime(rem.dueDate),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: isOverdue ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF1D4ED8)),
                                      onPressed: () => _showAddReminderModal(context, appState.shops, existingReminder: rem),
                                      tooltip: 'Edit Reminder',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                                      onPressed: () => _confirmDeleteReminder(context, rem),
                                      tooltip: 'Dismiss Reminder',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ],
            ),
          ),
        ],
      ),
    ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_visits',
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location_alt),
        label: const Text('Schedule Visit'),
        onPressed: () => _showScheduleVisitModal(context, appState.shops),
      ),
    );
  }
}
