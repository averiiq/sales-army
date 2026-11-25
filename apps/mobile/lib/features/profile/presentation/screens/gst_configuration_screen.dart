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
  Future<void> _showAddTaxSlabSheet(
    BuildContext context,
    AppState appState,
  ) async {
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
              content: Text(
                'GST Slab "${newSlab.name}" (${newSlab.formattedRate}) Added Successfully!',
              ),
              backgroundColor: const Color(0xFF059669),
              duration: const Duration(seconds: 3),
            ),
          );
        },
      ),
    );
  }

  void _confirmDeleteTaxSlab(
    BuildContext context,
    AppState appState,
    GstSlabModel slab,
  ) {
    if (appState.activeGstSlabs.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'At least one GST tax slab must remain active in the system.',
          ),
        ),
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
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF64748B),
              ),
            ),
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
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
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
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.add_circle_outline_rounded,
              color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
              size: 22,
            ),
            tooltip: 'Add GST Slab',
            onPressed: () => _showAddTaxSlabSheet(context, appState),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            // Readable width on tablets / landscape; full width on phones.
            constraints: const BoxConstraints(maxWidth: 640),
            // Few slabs: build them all (keeps every slab findable/accessible).
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Master GST invoicing toggle
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: const Color(0xFF059669)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.receipt_long_rounded,
                            color: Color(0xFF059669),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Enable GST Invoicing',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                appState.isGstBillingEnabled
                                    ? 'On • Tax invoices with GST'
                                    : 'Off • Estimates / cash bills only',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: appState.isGstBillingEnabled
                                      ? const Color(0xFF059669)
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
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

                  // 2. Section header (wraps on narrow screens)
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Text(
                        'GST SLABS (${slabs.length})',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                          letterSpacing: 0.5,
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () =>
                            _showAddTaxSlabSheet(context, appState),
                        icon: const Icon(
                          Icons.add_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Add Slab',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // 3. Slabs
                  for (final slab in slabs) ...[
                    _buildSlabCard(context, appState, slab, isDark),
                    const SizedBox(height: 8),
                  ],

                  const SizedBox(height: 12),
                  Text(
                    'CGST + SGST apply within your state, IGST for other states — calculated automatically on every bill.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? const Color(0xFF64748B)
                          : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSlabCard(
    BuildContext context,
    AppState appState,
    GstSlabModel slab,
    bool isDark,
  ) {
    final rateColor = slab.rate == 0
        ? const Color(0xFF64748B)
        : slab.rate <= 5
        ? const Color(0xFF059669)
        : slab.rate <= 12
        ? const Color(0xFF2563EB)
        : slab.rate <= 18
        ? const Color(0xFF7C3AED)
        : const Color(0xFFDC2626);

    String pct(double v) =>
        v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);
    final title =
        slab.name.startsWith('${slab.rate}') ||
            slab.name.startsWith(slab.formattedRate) ||
            slab.name.startsWith('${pct(slab.rate)}%')
        ? slab.name
        : '${pct(slab.rate)}% ${slab.name}';
    final hasHsn = slab.hsnCodes != null && slab.hsnCodes!.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rate badge
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: rateColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${pct(slab.rate)}%',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: rateColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Name, tax split, HSN — all allowed to wrap
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _splitChip('CGST ${pct(slab.cgstRate)}%', isDark),
                    _splitChip('SGST ${pct(slab.sgstRate)}%', isDark),
                    _splitChip('IGST ${pct(slab.igstRate)}%', isDark),
                  ],
                ),
                if (hasHsn) ...[
                  const SizedBox(height: 6),
                  Text(
                    'HSN: ${slab.hsnCodes!.trim()}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? const Color(0xFF93C5FD)
                          : const Color(0xFF1D4ED8),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Compact actions
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints.tightFor(
                  width: 36,
                  height: 36,
                ),
                padding: EdgeInsets.zero,
                icon: Icon(
                  Icons.edit_outlined,
                  color: isDark
                      ? const Color(0xFF60A5FA)
                      : const Color(0xFF2563EB),
                  size: 19,
                ),
                tooltip: 'Edit Slab',
                onPressed: () => _showEditTaxSlabSheet(context, appState, slab),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints.tightFor(
                  width: 36,
                  height: 36,
                ),
                padding: EdgeInsets.zero,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFFEF4444),
                  size: 19,
                ),
                tooltip: 'Remove Slab',
                onPressed: () => _confirmDeleteTaxSlab(context, appState, slab),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _splitChip(String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
        ),
      ),
    );
  }

  void _showEditTaxSlabSheet(
    BuildContext context,
    AppState appState,
    GstSlabModel slab,
  ) {
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
              content: Text(
                'GST Slab "${updatedSlab.name}" (${updatedSlab.formattedRate}) Updated!',
              ),
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
  String? _error;

  @override
  void initState() {
    super.initState();
    final ex = widget.existingSlab;
    _rate = ex?.rate ?? 18.0;
    _rateController = TextEditingController(
      text: ex != null ? '${_rate % 1 == 0 ? _rate.toInt() : _rate}' : '18',
    );
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
        _error = null;
        if (_nameController.text.isEmpty ||
            _nameController.text.endsWith('% GST') ||
            _nameController.text.endsWith('% Tax')) {
          _nameController.text =
              '${_rate % 1 == 0 ? _rate.toInt() : _rate.toStringAsFixed(1)}% GST';
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
    final borderCol = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Material(
          color: cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: SingleChildScrollView(
            // Scrolls above the keyboard on small phones.
            padding: EdgeInsets.fromLTRB(
              20,
              14,
              20,
              MediaQuery.of(context).viewInsets.bottom + 20,
            ),
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
                      color: isDark
                          ? const Color(0xFF475569)
                          : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF059669).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.percent_rounded,
                        color: Color(0xFF059669),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.existingSlab != null
                            ? 'Edit GST Slab'
                            : 'Add GST Slab',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          color: textHeading,
                        ),
                      ),
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
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
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
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
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
                      borderSide: const BorderSide(
                        color: Color(0xFF059669),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ],
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
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
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
                      borderSide: const BorderSide(
                        color: Color(0xFF059669),
                        width: 1.5,
                      ),
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
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
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
                      borderSide: const BorderSide(
                        color: Color(0xFF059669),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Submit Button
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      final parsedRate = double.tryParse(
                        _rateController.text.trim(),
                      );
                      if (parsedRate == null ||
                          parsedRate < 0 ||
                          parsedRate > 100) {
                        setState(
                          () => _error = 'Enter a GST rate between 0 and 100%.',
                        );
                        return;
                      }
                      final name = _nameController.text.trim().isNotEmpty
                          ? _nameController.text.trim()
                          : '${parsedRate % 1 == 0 ? parsedRate.toInt() : parsedRate.toStringAsFixed(1)}% GST';
                      final hsn = _hsnController.text.trim().isNotEmpty
                          ? _hsnController.text.trim()
                          : null;

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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      widget.existingSlab != null
                          ? 'Update GST Tax Slab'
                          : 'Add ${_rate % 1 == 0 ? _rate.toInt() : _rate.toStringAsFixed(1)}% GST Tax Slab',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
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
