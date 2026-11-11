import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/features/billing/data/models/gst_slab_model.dart';
import 'package:salesarmy/core/utils/feature_gate.dart';

class GstConfigurationScreen extends StatefulWidget {
  const GstConfigurationScreen({super.key});

  @override
  State<GstConfigurationScreen> createState() => _GstConfigurationScreenState();
}

class _GstConfigurationScreenState extends State<GstConfigurationScreen> {
  Future<void> _showAddTaxSlabSheet(BuildContext context, AppState appState) async {
    if (!await FeatureGate.requireFeature(context, 'custom_tax_slabs')) return;
    if (!context.mounted) return;
    _showAddTaxSlabSheetGated(context, appState);
  }

  void _showAddTaxSlabSheetGated(BuildContext context, AppState appState) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddGstSlabModal(
        onSave: (newSlab) {
          appState.addGstSlab(newSlab);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('GST Slab "${newSlab.name}" (${newSlab.formattedRate}) Added Successfully!'),
              backgroundColor: const Color(0xFF059669),
              duration: const Duration(seconds: 3),
            ),
          );
        },
      ),
    );
  }

  void _confirmDeleteTaxSlab(BuildContext context, AppState appState, GstSlabModel slab) {
    if (appState.activeGstSlabs.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least one GST tax slab must remain active in the system.')),
      );
      return;
    }

    final isDark = appState.isDarkMode;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Remove GST Slab?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        content: Text(
          'Are you sure you want to remove "${slab.name}" (${slab.formattedRate})?',
          style: TextStyle(
            fontSize: 13.5,
            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              appState.deleteGstSlab(slab.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Removed "${slab.name}"'),
                  backgroundColor: const Color(0xFFDC2626),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isDark = appState.isDarkMode;
    final slabs = appState.gstSlabs;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'GST & Taxes Configuration',
          style: TextStyle(
            fontSize: 16.5,
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
            icon: Icon(Icons.add_circle_outline_rounded, color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669), size: 22),
            tooltip: 'Add GST Slab',
            onPressed: () => _showAddTaxSlabSheet(context, appState),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Master GST Invoicing Toggle Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: const Color(0xFF059669).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF059669), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Enable GST Invoicing',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            appState.isGstBillingEnabled ? 'GST Enabled • Tax Invoices Generated' : 'Disabled • Estimates / Cash Bills',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: appState.isGstBillingEnabled ? const Color(0xFF059669) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Switch(
                    value: appState.isGstBillingEnabled,
                    activeThumbColor: const Color(0xFF059669),
                    onChanged: (val) {
                      HapticFeedback.lightImpact();
                      appState.setGstBillingEnabled(val);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 2. Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'CONFIGURED GST SLABS (${slabs.length})',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _showAddTaxSlabSheet(context, appState),
                  icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                  label: const Text('Add Slab', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 3. Slabs List
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: slabs.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (ctx, idx) {
                final slab = slabs[idx];
                return _buildSlabCard(context, appState, slab, isDark);
              },
            ),

            const SizedBox(height: 20),
            Center(
              child: Text(
                'GST rates automatically calculate CGST, SGST, and IGST on invoices',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlabCard(BuildContext context, AppState appState, GstSlabModel slab, bool isDark) {
    final rateColor = slab.rate == 0
        ? const Color(0xFF64748B)
        : slab.rate <= 5
            ? const Color(0xFF059669)
            : slab.rate <= 12
                ? const Color(0xFF2563EB)
                : slab.rate <= 18
                    ? const Color(0xFF7C3AED)
                    : const Color(0xFFDC2626);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          // Rate Badge
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: rateColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              slab.formattedRate,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 15,
                color: rateColor,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Title & Split Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        slab.name.startsWith('${slab.rate}') || slab.name.startsWith(slab.formattedRate)
                            ? slab.name
                            : '${slab.rate.toStringAsFixed(1)}% ${slab.name}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    if (slab.hsnCodes != null && slab.hsnCodes!.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1D4ED8).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'HSN: ${slab.hsnCodes}',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF1D4ED8)),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Intra-State: CGST ${slab.cgstRate.toStringAsFixed(1)}% + SGST ${slab.sgstRate.toStringAsFixed(1)}%  •  IGST ${slab.igstRate.toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),

          // Edit Action Button
          IconButton(
            icon: Icon(Icons.edit_outlined, color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB), size: 19),
            tooltip: 'Edit Slab',
            onPressed: () => _showEditTaxSlabSheet(context, appState, slab),
          ),

          // Delete Action Button
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 19),
            tooltip: 'Remove Slab',
            onPressed: () => _confirmDeleteTaxSlab(context, appState, slab),
          ),
        ],
      ),
    );
  }

  void _showEditTaxSlabSheet(BuildContext context, AppState appState, GstSlabModel slab) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddGstSlabModal(
        existingSlab: slab,
        onSave: (updatedSlab) {
          appState.updateGstSlab(updatedSlab);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('GST Slab "${updatedSlab.name}" (${updatedSlab.formattedRate}) Updated!'),
              backgroundColor: const Color(0xFF059669),
              duration: const Duration(seconds: 3),
            ),
          );
        },
      ),
    );
  }
}

class _AddGstSlabModal extends StatefulWidget {
  final GstSlabModel? existingSlab;
  final Function(GstSlabModel) onSave;

  const _AddGstSlabModal({this.existingSlab, required this.onSave});

  @override
  State<_AddGstSlabModal> createState() => _AddGstSlabModalState();
}

class _AddGstSlabModalState extends State<_AddGstSlabModal> {
  late final TextEditingController _rateController;
  late final TextEditingController _nameController;
  late final TextEditingController _hsnController;

  late double _rate;

  @override
  void initState() {
    super.initState();
    final ex = widget.existingSlab;
    _rate = ex?.rate ?? 18.0;
    _rateController = TextEditingController(text: ex != null ? '${_rate % 1 == 0 ? _rate.toInt() : _rate}' : '18');
    _nameController = TextEditingController(text: ex?.name ?? '18% GST');
    _hsnController = TextEditingController(text: ex?.hsnCodes ?? '');
  }

  @override
  void dispose() {
    _rateController.dispose();
    _nameController.dispose();
    _hsnController.dispose();
    super.dispose();
  }

  void _onRateChanged(String val) {
    final parsed = double.tryParse(val.trim());
    if (parsed != null) {
      setState(() {
        _rate = parsed;
        if (_nameController.text.isEmpty || _nameController.text.endsWith('% GST') || _nameController.text.endsWith('% Tax')) {
          _nameController.text = '${_rate % 1 == 0 ? _rate.toInt() : _rate.toStringAsFixed(1)}% GST';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textHeading = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSub = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final inputBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Material(
          color: cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.of(context).viewInsets.bottom + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
            // Drag handle
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF059669).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.percent_rounded, color: Color(0xFF059669), size: 20),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      widget.existingSlab != null ? 'Edit GST Tax Slab' : 'Add Custom GST Tax Slab',
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: textHeading,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: textSub, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 1. GST Rate Input
            Text(
              'GST Tax Percentage (%) *',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: textHeading,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _rateController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: _onRateChanged,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: textHeading,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: inputBg,
                hintText: 'e.g. 18 or 5.5',
                hintStyle: TextStyle(fontSize: 13, color: textSub),
                suffixText: '%',
                suffixStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF059669),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: borderCol),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: borderCol),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF059669), width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // 2. Slab Name Input
            Text(
              'Slab Name / Title *',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: textHeading,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _nameController,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textHeading,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: inputBg,
                hintText: 'e.g. 18% GST or FMCG Goods',
                hintStyle: TextStyle(fontSize: 13, color: textSub),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: borderCol),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: borderCol),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF059669), width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // 3. Optional HSN Code
            Text(
              'HSN / SAC Code (Optional)',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: textHeading,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _hsnController,
              style: TextStyle(fontSize: 14, color: textHeading),
              decoration: InputDecoration(
                filled: true,
                fillColor: inputBg,
                hintText: 'e.g. 1905, 2106',
                hintStyle: TextStyle(fontSize: 13, color: textSub),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: borderCol),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: borderCol),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF059669), width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Submit Button
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  final parsedRate = double.tryParse(_rateController.text.trim()) ?? _rate;
                  final name = _nameController.text.trim().isNotEmpty
                      ? _nameController.text.trim()
                      : '${parsedRate % 1 == 0 ? parsedRate.toInt() : parsedRate.toStringAsFixed(1)}% GST';
                  final hsn = _hsnController.text.trim().isNotEmpty ? _hsnController.text.trim() : null;

                  final slab = (widget.existingSlab != null)
                      ? widget.existingSlab!.copyWith(
                          rate: parsedRate,
                          name: name,
                          hsnCodes: hsn,
                        )
                      : GstSlabModel(
                          id: 'gst_${DateTime.now().millisecondsSinceEpoch}',
                          rate: parsedRate,
                          name: name,
                          category: 'Custom',
                          details: 'Custom tax slab configured for business orders and billing',
                          hsnCodes: hsn,
                          isDefault: false,
                          isActive: true,
                          createdAt: DateTime.now(),
                        );

                  widget.onSave(slab);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  widget.existingSlab != null
                      ? 'Update GST Tax Slab'
                      : 'Add ${_rate % 1 == 0 ? _rate.toInt() : _rate.toStringAsFixed(1)}% GST Tax Slab',
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    ),
    );
  }
}
