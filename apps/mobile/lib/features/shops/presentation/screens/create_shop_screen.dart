import 'package:flutter/material.dart';
import 'package:salesarmy/core/utils/app_error.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/core/services/location_service.dart';
import 'package:salesarmy/core/utils/app_image_helper.dart';
import 'package:salesarmy/features/shops/data/models/shop_model.dart';

class CreateShopScreen extends StatefulWidget {
  final ShopModel? initialShop;
  const CreateShopScreen({super.key, this.initialShop});

  @override
  State<CreateShopScreen> createState() => _CreateShopScreenState();
}

class _CreateShopScreenState extends State<CreateShopScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _ownerCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _gstinCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  final _creditLimitCtrl = TextEditingController();
  final _photoUrlCtrl = TextEditingController();

  String _selectedType = 'Kirana';
  String _selectedSellerCategory = 'Retailer'; // 'Retailer', 'Wholesaler', 'Walk-in Customer'
  String _visitFreq = 'weekly';

  double? _currentLat;
  double? _currentLng;
  String _gpsStatus = 'No GPS location tagged';
  bool _isCapturingGps = false;

  final Map<String, String> _storefrontPresets = {
    'Kirana': 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=500',
    'Supermarket': 'https://images.unsplash.com/photo-1578916171728-46686eac8d58?w=500',
    'Dairy': 'https://images.unsplash.com/photo-1527153857715-3908f2ae5e81?w=500',
    'Pharmacy': 'https://images.unsplash.com/photo-1586015555751-63bb77f4322a?w=500',
    'Wholesale': 'https://images.unsplash.com/photo-1586528116311-ad8dd3c8310d?w=500',
    'Bakery': 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=500',
    'General Store': 'https://images.unsplash.com/photo-1534723452862-4c874018d66d?w=500',
    'Hardware': 'https://images.unsplash.com/photo-1581783342308-f792dbdd27c5?w=500',
  };

  String? _selectedImageUrl;
  bool _showCustomUrlField = false;
  bool _isProcessingPhoto = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialShop != null) {
      final s = widget.initialShop!;
      _nameCtrl.text = s.shopName;
      _ownerCtrl.text = s.ownerName;
      _phoneCtrl.text = s.phone ?? '';
      _gstinCtrl.text = s.gstin ?? '';
      _addressCtrl.text = s.address ?? '';
      _cityCtrl.text = s.city ?? '';
      _stateCtrl.text = s.state ?? '';
      _pincodeCtrl.text = s.pincode ?? '';
      _creditLimitCtrl.text = s.creditLimit > 0 ? s.creditLimit.toStringAsFixed(0) : '';
      _photoUrlCtrl.text = s.imageUrl ?? '';
      _selectedImageUrl = s.imageUrl;
      _selectedType = s.businessType ?? 'Kirana';
      _selectedSellerCategory = s.sellerCategory ?? 'Retailer';
      _visitFreq = s.visitFrequency.isNotEmpty ? s.visitFrequency : 'weekly';
      _currentLat = s.latitude;
      _currentLng = s.longitude;
      _gpsStatus = (_currentLat != null && _currentLng != null)
          ? 'GPS Location Tagged (${_currentLat!.toStringAsFixed(4)} N, ${_currentLng!.toStringAsFixed(4)} E)'
          : 'No GPS location tagged';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ownerCtrl.dispose();
    _phoneCtrl.dispose();
    _gstinCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _pincodeCtrl.dispose();
    _creditLimitCtrl.dispose();
    _photoUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _captureOrPickPhoto({required bool fromCamera}) async {
    HapticFeedback.lightImpact();
    setState(() => _isProcessingPhoto = true);
    try {
      final picked = await AppImageHelper.pickImageAsDataUri(
        fromCamera: fromCamera,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 75,
      );
      if (!mounted) return;
      if (picked != null && picked.isNotEmpty) {
        setState(() {
          _selectedImageUrl = picked;
          _photoUrlCtrl.text = picked;
          _isProcessingPhoto = false;
        });
      } else {
        setState(() => _isProcessingPhoto = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessingPhoto = false);
        showAppError(context, e, action: 'add the shop photo');
      }
    }
  }

  /// Real device GPS: asks for permission, gets the current position and
  /// fills any empty address / city / state / pincode fields from it.
  Future<void> _captureGps() async {
    HapticFeedback.lightImpact();
    setState(() {
      _isCapturingGps = true;
      _gpsStatus = 'Fetching current location…';
    });

    final fix = await LocationService.instance.captureCurrentLocation();
    if (!mounted) return;

    if (!fix.ok) {
      setState(() {
        _isCapturingGps = false;
        _gpsStatus = (_currentLat != null && _currentLng != null)
            ? 'GPS Location Tagged (${_currentLat!.toStringAsFixed(5)}, ${_currentLng!.toStringAsFixed(5)})'
            : 'No GPS location tagged';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(fix.error ?? 'Could not fetch location.'),
          backgroundColor: const Color(0xFFD97706),
          duration: const Duration(seconds: 4),
          action: fix.needsSettings
              ? SnackBarAction(
                  label: 'Settings',
                  textColor: Colors.white,
                  onPressed: () => LocationService.instance.openSettings(),
                )
              : null,
        ),
      );
      return;
    }

    var filled = 0;
    void fillIfEmpty(TextEditingController c, String? v) {
      if (v != null && v.isNotEmpty && c.text.trim().isEmpty) {
        c.text = v;
        filled++;
      }
    }

    setState(() {
      _currentLat = fix.latitude;
      _currentLng = fix.longitude;
      _isCapturingGps = false;
      final acc = fix.accuracyMeters != null ? ' • ±${fix.accuracyMeters!.round()} m' : '';
      _gpsStatus = 'GPS Location Tagged (${_currentLat!.toStringAsFixed(5)}, ${_currentLng!.toStringAsFixed(5)})$acc';
      fillIfEmpty(_addressCtrl, fix.street);
      fillIfEmpty(_cityCtrl, fix.city);
      fillIfEmpty(_stateCtrl, fix.state);
      fillIfEmpty(_pincodeCtrl, fix.pincode);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(filled > 0
            ? 'Location tagged and address details filled from GPS.'
            : 'Location tagged successfully.'),
        backgroundColor: const Color(0xFF059669),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showAddCustomCategoryDialog() {
    final textCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Custom Category', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        content: TextField(
          controller: textCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Category Name',
            hintText: 'e.g. Pharmacy, Hardware, Electronics',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = textCtrl.text.trim();
              if (val.isNotEmpty) {
                context.read<AppState>().addShopCategory(val);
                setState(() => _selectedType = val);
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFCC00),
              foregroundColor: const Color(0xFF0F172A),
            ),
            child: const Text('Add Category'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitShop() async {
    if (_nameCtrl.text.trim().isEmpty) {
      showAppError(context, 'Please enter a party / shop name');
      return;
    }
    final pin = _pincodeCtrl.text.trim();
    if (pin.isNotEmpty && !RegExp(r'^[0-9]{6}$').hasMatch(pin)) {
      showAppError(context, 'Pincode must be 6 digits');
      return;
    }
    String? opt(TextEditingController c) => c.text.trim().isNotEmpty ? c.text.trim() : null;

    final rawImage = _selectedImageUrl?.trim();
    String? finalImageUrl;
    if (rawImage != null && rawImage.isNotEmpty) {
      finalImageUrl = await AppImageHelper.ensurePersistentUri(rawImage);
    }

    if (!mounted) return;
    final appState = Provider.of<AppState>(context, listen: false);

    if (widget.initialShop != null) {
      final updatedShop = widget.initialShop!.copyWith(
        shopName: _nameCtrl.text.trim(),
        ownerName: _ownerCtrl.text.trim().isNotEmpty ? _ownerCtrl.text.trim() : 'Store Manager',
        phone: _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : '',
        address: _addressCtrl.text.trim().isNotEmpty ? _addressCtrl.text.trim() : 'Main Market Road',
        city: opt(_cityCtrl),
        state: opt(_stateCtrl),
        pincode: opt(_pincodeCtrl),
        gstin: _gstinCtrl.text.trim().isNotEmpty ? _gstinCtrl.text.trim().toUpperCase() : null,
        businessType: _selectedType,
        sellerCategory: _selectedSellerCategory,
        creditLimit: double.tryParse(_creditLimitCtrl.text.trim()) ?? 0.0,
        visitFrequency: _visitFreq,
        latitude: _currentLat,
        longitude: _currentLng,
        imageUrl: finalImageUrl,
        updatedAt: DateTime.now(),
      );
      await appState.updateShop(updatedShop);
      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Party "${updatedShop.shopName}" updated successfully!'),
          backgroundColor: const Color(0xFF059669),
        ),
      );
      return;
    }

    final newShop = ShopModel(
      shopId: 'shop_${DateTime.now().millisecondsSinceEpoch}',
      shopName: _nameCtrl.text.trim(),
      ownerName: _ownerCtrl.text.trim().isNotEmpty ? _ownerCtrl.text.trim() : 'Store Manager',
      phone: _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : '',
      address: _addressCtrl.text.trim().isNotEmpty ? _addressCtrl.text.trim() : 'Main Market Road',
      city: opt(_cityCtrl),
      state: opt(_stateCtrl),
      pincode: opt(_pincodeCtrl),
      gstin: _gstinCtrl.text.trim().isNotEmpty ? _gstinCtrl.text.trim().toUpperCase() : null,
      businessType: _selectedType,
      sellerCategory: _selectedSellerCategory,
      creditLimit: double.tryParse(_creditLimitCtrl.text.trim()) ?? 0.0,
      currentOutstanding: 0.0,
      visitFrequency: _visitFreq,
      latitude: _currentLat,
      longitude: _currentLng,
      imageUrl: finalImageUrl,
      createdAt: DateTime.now(),
    );

    await appState.addShop(newShop);
    if (!mounted) return;
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Party "${newShop.shopName}" registered successfully!'),
        backgroundColor: const Color(0xFF059669),
      ),
    );
  }

  Widget _buildSellerCategoryChip(String value, String label, IconData icon, bool isDark) {
    final selected = _selectedSellerCategory == value;
    final fg = selected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF475569));
    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedSellerCategory = value);
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF1E56E2) : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? const Color(0xFF1E56E2) : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
              width: selected ? 1.5 : 1.0,
            ),
          ),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: fg),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: fg,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          widget.initialShop != null ? 'Edit Party' : 'Register New Party',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 90),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Storefront Photo Upload Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: isDark ? Colors.black.withValues(alpha: 0.2) : const Color(0xFF0F172A).withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'STOREFRONT PHOTO',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 0.6),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEFF6FF),
                              border: Border.all(
                                color: _selectedImageUrl != null ? const Color(0xFF10B981) : const Color(0xFF1E56E2),
                                width: 2,
                              ),
                              image: _selectedImageUrl != null
                                  ? DecorationImage(
                                      image: AppImageHelper.getImageProvider(_selectedImageUrl!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: _isProcessingPhoto
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF1E56E2)),
                                  )
                                : (_selectedImageUrl == null
                                    ? const Icon(Icons.storefront_rounded, color: Color(0xFF1E56E2), size: 36)
                                    : null),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: _isProcessingPhoto ? null : () => _captureOrPickPhoto(fromCamera: true),
                                        icon: const Icon(Icons.camera_alt_rounded, size: 16),
                                        label: const Text('Camera', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF1E56E2),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _isProcessingPhoto ? null : () => _captureOrPickPhoto(fromCamera: false),
                                        icon: const Icon(Icons.photo_library_rounded, size: 16),
                                        label: const Text('Gallery', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
                                          side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    InkWell(
                                      onTap: () => setState(() => _showCustomUrlField = !_showCustomUrlField),
                                      child: Text(
                                        _showCustomUrlField ? 'Hide Photo URL' : '+ Paste Image URL',
                                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF1E56E2)),
                                      ),
                                    ),
                                    if (_selectedImageUrl != null && _selectedImageUrl!.isNotEmpty) ...[
                                      const Spacer(),
                                      InkWell(
                                        onTap: () {
                                          setState(() {
                                            _selectedImageUrl = null;
                                            _photoUrlCtrl.clear();
                                          });
                                        },
                                        child: const Text(
                                          'Remove',
                                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFFDC2626)),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (_showCustomUrlField) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: _photoUrlCtrl,
                          onChanged: (val) {
                            if (val.trim().isNotEmpty) {
                              setState(() => _selectedImageUrl = val.trim());
                            }
                          },
                          decoration: InputDecoration(
                            hintText: 'https://example.com/storefront.jpg',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      const Text(
                        'Or Select Category Storefront Preset:',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _storefrontPresets.keys.map((cat) {
                            final isSel = _selectedImageUrl == _storefrontPresets[cat];
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedImageUrl = _storefrontPresets[cat];
                                    _selectedType = cat;
                                    _photoUrlCtrl.text = _storefrontPresets[cat]!;
                                  });
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isSel ? const Color(0xFF1E56E2) : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSel ? const Color(0xFF1E56E2) : (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                                    ),
                                  ),
                                  child: Text(
                                    cat,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: isSel ? Colors.white : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
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
                const SizedBox(height: 16),

                // 2. GPS Location Tagging Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.3) : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? const Color(0xFF047857) : const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF065F46) : const Color(0xFFDCFCE7),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.location_on_rounded, color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF16A34A), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'GPS Location Geo-Tagging',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF166534)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _gpsStatus,
                              style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFFA7F3D0) : const Color(0xFF15803D)),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _isCapturingGps ? null : _captureGps,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        child: _isCapturingGps
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text(
                                _currentLat != null ? 'Re-Tag' : 'Fetch GPS',
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 3. Outlet Information Form
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'RETAIL OUTLET DETAILS',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 0.6),
                      ),
                      const SizedBox(height: 12),

                      // Seller Category Selector (Retailer / Wholesaler / Walk-in Customer)
                      Text(
                        'Seller Category *',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _buildSellerCategoryChip('Retailer', 'Retailer', Icons.storefront_rounded, isDark),
                          const SizedBox(width: 8),
                          _buildSellerCategoryChip('Wholesaler', 'Wholesaler', Icons.warehouse_rounded, isDark),
                          const SizedBox(width: 8),
                          _buildSellerCategoryChip('Walk-in Customer', 'Walk-in Customer', Icons.directions_walk_rounded, isDark),
                        ],
                      ),
                      const SizedBox(height: 14),

                      TextField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Shop / Outlet Name *',
                          hintText: 'e.g. Shree Ganesh Kirana',
                          prefixIcon: Icon(Icons.storefront_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _ownerCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Owner / Contact *',
                                hintText: 'Full name',
                                prefixIcon: Icon(Icons.person_outline_rounded),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _phoneCtrl,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Phone / WhatsApp *',
                                hintText: '9876543210',
                                prefixIcon: Icon(Icons.phone_outlined),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: _gstinCtrl,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'GSTIN Number (Optional)',
                          hintText: '27AAAAA0000A1Z5',
                          prefixIcon: Icon(Icons.receipt_long_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: _addressCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Full Address *',
                          hintText: 'Shop No. 4, Market Road, Near Post Office',
                          prefixIcon: Icon(Icons.map_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _cityCtrl,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                labelText: 'City',
                                hintText: 'e.g. Pune',
                                prefixIcon: Icon(Icons.location_city_outlined),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _stateCtrl,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                labelText: 'State',
                                hintText: 'e.g. Maharashtra',
                                prefixIcon: Icon(Icons.flag_outlined),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _pincodeCtrl,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(
                          labelText: 'Pincode',
                          hintText: '411001',
                          counterText: '',
                          prefixIcon: Icon(Icons.markunread_mailbox_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: Builder(
                              builder: (bCtx) {
                                final appState = Provider.of<AppState>(bCtx);
                                final categories = appState.shopCategories;
                                if (!categories.contains(_selectedType)) {
                                  categories.add(_selectedType);
                                }
                                return DropdownButtonFormField<String>(
                                  initialValue: _selectedType,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Category Type',
                                    prefixIcon: Icon(Icons.category_outlined),
                                  ),
                                  items: [
                                    ...categories.map((t) => DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis))),
                                    const DropdownMenuItem(
                                      value: '__ADD_CUSTOM__',
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.add_circle_outline_rounded, size: 16, color: Color(0xFF1D4ED8)),
                                          SizedBox(width: 6),
                                          Flexible(
                                            child: Text('+ Add Custom Category', style: TextStyle(color: Color(0xFF1D4ED8), fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  onChanged: (v) {
                                    if (v == '__ADD_CUSTOM__') {
                                      _showAddCustomCategoryDialog();
                                    } else if (v != null) {
                                      setState(() {
                                        _selectedType = v;
                                        if (_storefrontPresets.containsKey(v)) {
                                          _selectedImageUrl = _storefrontPresets[v];
                                        }
                                      });
                                    }
                                  },
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _creditLimitCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Credit Limit (₹)',
                                hintText: 'e.g. 20000',
                                prefixIcon: Icon(Icons.credit_card_outlined),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      DropdownButtonFormField<String>(
                        initialValue: _visitFreq,
                        decoration: const InputDecoration(
                          labelText: 'Sales Visit Schedule',
                          prefixIcon: Icon(Icons.calendar_today_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'daily', child: Text('Daily Visit')),
                          DropdownMenuItem(value: 'weekly', child: Text('Weekly (Standard)')),
                          DropdownMenuItem(value: 'biweekly', child: Text('Bi-Weekly (Twice a month)')),
                          DropdownMenuItem(value: 'monthly', child: Text('Monthly Visit')),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _visitFreq = v);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _submitShop,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E56E2),
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_rounded, size: 20),
              const SizedBox(width: 8),
              Text(
                widget.initialShop != null ? 'Save Changes' : 'Register & Save Party',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
