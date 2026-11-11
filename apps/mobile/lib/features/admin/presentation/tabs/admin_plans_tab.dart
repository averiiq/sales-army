import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/features/admin/data/models/printer_option_model.dart';
import 'package:salesarmy/features/admin/data/models/subscription_addon_model.dart';

class AdminPlansTab extends StatelessWidget {
  final double monthlyPlanPrice;
  final double annualPlanPrice;
  final double planGstRate;
  final double printerHardwarePrice;
  final double printerGstRate;
  final bool applyGstOnInvoices;
  final List<Map<String, dynamic>> coupons;
  final VoidCallback onOpenEditPricing;
  final VoidCallback onOpenNewCoupon;
  final Function(int index, bool isPaused) onToggleCoupon;
  final Function(int index)? onDeleteCoupon;

  const AdminPlansTab({
    super.key,
    required this.monthlyPlanPrice,
    required this.annualPlanPrice,
    required this.planGstRate,
    required this.printerHardwarePrice,
    required this.printerGstRate,
    required this.applyGstOnInvoices,
    required this.coupons,
    required this.onOpenEditPricing,
    required this.onOpenNewCoupon,
    required this.onToggleCoupon,
    this.onDeleteCoupon,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ---------------------------------------------------------------
              // CARD 1: SaaS Subscription Plans (Screenshot 2)
              // ---------------------------------------------------------------
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.diamond_outlined, color: Color(0xFF1D4ED8), size: 20),
                            SizedBox(width: 8),
                            Text(
                              'SaaS Subscription Plans',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: onOpenEditPricing,
                          icon: const Icon(Icons.edit_rounded, size: 14, color: Colors.white),
                          label: const Text(
                            'Edit Pricing',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1D4ED8),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Configure Monthly, Half-Yearly, and Annual pricing tiers for distributors and sales agents.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 16),

                    // Plan Options Row/Grid
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 500;
                        final monthlyCard = Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFF1D4ED8), width: 1.5),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Monthly Plan',
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1D4ED8),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'ACTIVE',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '₹${monthlyPlanPrice.toInt()}/mo',
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1D4ED8)),
                              ),
                              const SizedBox(height: 4),
                              const Text('Billed monthly', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                              const SizedBox(height: 8),
                              Text(
                                '+${planGstRate.toInt()}% GST',
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF059669)),
                              ),
                            ],
                          ),
                        );

                        final annualCard = Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Annual Pro (Save 33%)',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '₹${annualPlanPrice.toInt()}/mo',
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1D4ED8)),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '₹${(annualPlanPrice * 12).toInt()} / yr (${annualPlanPrice.toInt()}×12)',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '+${planGstRate.toInt()}% GST',
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF059669)),
                              ),
                            ],
                          ),
                        );

                        if (isWide) {
                          return Row(
                            children: [
                              Expanded(child: monthlyCard),
                              const SizedBox(width: 14),
                              Expanded(child: annualCard),
                            ],
                          );
                        } else {
                          return Column(
                            children: [
                              monthlyCard,
                              const SizedBox(height: 12),
                              annualCard,
                            ],
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // ---------------------------------------------------------------
              // CARD 2: Dynamic Printers & Hardware Add-ons (Admin Controlled)
              // ---------------------------------------------------------------
              _buildHardwareManagementCard(context),
              const SizedBox(height: 18),

              // ---------------------------------------------------------------
              // CARD 3: Promo Coupons & Demo Passes (Screenshot 4)
              // ---------------------------------------------------------------
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.confirmation_number_rounded, color: Color(0xFFEA580C), size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Promo Coupons & Demo Passes',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: onOpenNewCoupon,
                          icon: const Icon(Icons.add_rounded, size: 14, color: Colors.white),
                          label: const Text(
                            'New',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Coupons List
                    ...coupons.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final coupon = entry.value;
                      final isPaused = coupon['isPaused'] == true;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        coupon['code']?.toString() ?? '',
                                        style: const TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF1D4ED8),
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isPaused ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          isPaused ? 'PAUSED' : 'ACTIVE',
                                          style: TextStyle(
                                            color: isPaused ? const Color(0xFFD97706) : const Color(0xFF15803D),
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    coupon['desc']?.toString() ?? '',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                                  ),
                                ],
                              ),
                            ),
                            // Action: Pause / Resume
                            IconButton(
                              icon: Icon(
                                isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                                size: 20,
                                color: const Color(0xFF334155),
                              ),
                              tooltip: isPaused ? 'Resume Coupon' : 'Pause Coupon',
                              onPressed: () {
                                onToggleCoupon(idx, !isPaused);
                                ScaffoldMessenger.of(context).clearSnackBars();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Coupon ${coupon['code']} is now ${!isPaused ? 'paused' : 'active'}.'),
                                  ),
                                );
                              },
                            ),
                            // Action: Delete
                            IconButton(
                              icon: const Icon(Icons.delete_rounded, size: 18, color: Color(0xFFDC2626)),
                              tooltip: 'Delete Coupon',
                              onPressed: () {
                                final code = coupon['code'];
                                onDeleteCoupon?.call(idx);
                                ScaffoldMessenger.of(context).clearSnackBars();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Coupon $code deleted permanently.'),
                                    backgroundColor: const Color(0xFFDC2626),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHardwareManagementCard(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final printers = appState.printerOptions;
    final addons = appState.subscriptionAddons;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.print_rounded, color: Color(0xFF1D4ED8), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Hardware & Printer Management',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'LIVE & DYNAMIC',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF16A34A)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Add or remove dynamic POS thermal printers and accessory hardware packs available in user subscription checkout.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),

          // Header 1: Printer Models
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'THERMAL PRINTER MODELS (${printers.length})',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: Color(0xFF475569)),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: const Color(0xFF1D4ED8),
                ),
                onPressed: () => _showAddPrinterDialog(context, appState),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add Printer', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Printers list
          ...printers.map((printer) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: printer.isAvailable ? const Color(0xFFE2E8F0) : const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: printer.isAvailable ? const Color(0xFFEFF6FF) : const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.print_rounded,
                      color: printer.isAvailable ? const Color(0xFF1D4ED8) : const Color(0xFFDC2626),
                      size: 20,
                    ),
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
                                printer.name,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: Color(0xFF0F172A)),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                printer.paperWidth,
                                style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '₹${printer.price.toInt()} + ${printer.gstRate.toInt()}% GST • ${printer.connectivity}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1D4ED8)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch.adaptive(
                    value: printer.isAvailable,
                    activeTrackColor: const Color(0xFF1D4ED8),
                    onChanged: (val) {
                      appState.updatePrinterOption(id: printer.id, isAvailable: val);
                    },
                  ),
                  if (printers.length > 1) ...[
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                      tooltip: 'Remove Printer Model',
                      onPressed: () {
                        appState.removePrinterOption(printer.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Printer model "${printer.name}" removed.')),
                        );
                      },
                    ),
                  ],
                ],
              ),
            );
          }),

          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 12),

          // Header 2: Hardware Add-on Packs
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'HARDWARE & PACK ADD-ONS (${addons.length})',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: Color(0xFF475569)),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: const Color(0xFF059669),
                ),
                onPressed: () => _showAddAddonDialog(context, appState),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add Hardware Pack', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Add-ons list
          ...addons.map((addon) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: addon.isAvailable ? const Color(0xFFE2E8F0) : const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: addon.isAvailable ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      addon.icon,
                      color: addon.isAvailable ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          addon.title,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '₹${addon.price.toInt()} + 18% GST • ${addon.category.toUpperCase()}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF059669)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch.adaptive(
                    value: addon.isAvailable,
                    activeTrackColor: const Color(0xFF059669),
                    onChanged: (val) {
                      appState.toggleAddonAvailability(addon.id, val);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                    tooltip: 'Remove Hardware Add-on',
                    onPressed: () {
                      appState.removeSubscriptionAddon(addon.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Hardware addon "${addon.title}" removed.')),
                      );
                    },
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  void _showAddPrinterDialog(BuildContext context, AppState appState) {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController(text: '2999');
    final widthCtrl = TextEditingController(text: '58mm (2-inch)');
    final connCtrl = TextEditingController(text: 'Bluetooth 4.0 / USB / Android ESC/POS');
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.print_rounded, color: Color(0xFF1D4ED8)),
              SizedBox(width: 8),
              Text('Add New Printer Model', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Printer Model Name', hintText: 'e.g. POS-80 High Speed Thermal Printer'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Price (₹ Excl. GST)', hintText: '2999'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: widthCtrl,
                  decoration: const InputDecoration(labelText: 'Paper Width', hintText: '58mm or 80mm'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: connCtrl,
                  decoration: const InputDecoration(labelText: 'Connectivity', hintText: 'Bluetooth / USB'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Short Description', hintText: 'High speed receipt printing'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1D4ED8),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final name = nameCtrl.text.trim();
                final price = double.tryParse(priceCtrl.text.trim()) ?? 2499.0;
                if (name.isEmpty) return;
                final id = 'printer_${DateTime.now().millisecondsSinceEpoch}';
                appState.addPrinterOption(
                  PrinterOptionModel(
                    id: id,
                    name: name,
                    price: price,
                    paperWidth: widthCtrl.text.trim(),
                    connectivity: connCtrl.text.trim(),
                    description: descCtrl.text.trim(),
                  ),
                );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Printer model "$name" added successfully!'), backgroundColor: const Color(0xFF059669)),
                );
              },
              child: const Text('Add Printer'),
            ),
          ],
        );
      },
    );
  }

  void _showAddAddonDialog(BuildContext context, AppState appState) {
    final titleCtrl = TextEditingController();
    final priceCtrl = TextEditingController(text: '999');
    final descCtrl = TextEditingController();
    final categoryCtrl = TextEditingController(text: 'hardware');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.devices_rounded, color: Color(0xFF059669)),
              SizedBox(width: 8),
              Text('Add Hardware / Pack Add-on', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Add-on Title', hintText: 'e.g. Wireless Barcode Scanner'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Price (₹ Excl. GST)', hintText: '1799'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: categoryCtrl,
                  decoration: const InputDecoration(labelText: 'Category', hintText: 'hardware or supplies'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Description', hintText: 'Quick product scanning'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final title = titleCtrl.text.trim();
                final price = double.tryParse(priceCtrl.text.trim()) ?? 999.0;
                if (title.isEmpty) return;
                final id = 'addon_${DateTime.now().millisecondsSinceEpoch}';
                appState.addSubscriptionAddon(
                  SubscriptionAddonModel(
                    id: id,
                    title: title,
                    price: price,
                    category: categoryCtrl.text.trim(),
                    description: descCtrl.text.trim(),
                    icon: Icons.devices_other_rounded,
                  ),
                );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Hardware add-on "$title" added successfully!'), backgroundColor: const Color(0xFF059669)),
                );
              },
              child: const Text('Add Pack Option'),
            ),
          ],
        );
      },
    );
  }
}
