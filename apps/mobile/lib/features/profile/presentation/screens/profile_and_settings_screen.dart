import 'package:flutter/material.dart';
import 'package:salesarmy/core/utils/app_error.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/core/utils/app_image_helper.dart';
import 'package:salesarmy/core/utils/responsive_helper.dart';
import 'package:salesarmy/features/profile/presentation/screens/accounts_screen.dart';
import 'package:salesarmy/features/auth/data/services/auth_service.dart';
import 'package:salesarmy/features/admin/presentation/screens/staff_management_screen.dart';
import 'package:salesarmy/features/inventory/presentation/screens/purchase_screen.dart';
import 'package:salesarmy/features/collections/presentation/screens/expense_screen.dart';
import 'package:salesarmy/features/orders/presentation/screens/orders_tab.dart';
import 'package:salesarmy/features/profile/presentation/screens/gst_configuration_screen.dart';
import 'package:salesarmy/features/settings/presentation/screens/printer_settings_screen.dart';
import 'package:salesarmy/core/services/printer_service.dart';
import 'package:salesarmy/features/settings/presentation/screens/payment_preferences_screen.dart';
import 'package:salesarmy/features/admin/presentation/screens/plan_and_pricing_screen.dart';
import 'package:salesarmy/features/profile/presentation/dialogs/reset_account_dialog.dart';
import 'package:salesarmy/features/billing/presentation/screens/reports_screen.dart';
import 'package:salesarmy/features/settings/presentation/screens/notifications_screen.dart';
import 'package:salesarmy/features/visits/presentation/screens/reminders_screen.dart';
import 'package:salesarmy/core/utils/feature_gate.dart';
import 'package:salesarmy/core/widgets/plan_crown_badge.dart';

class ProfileAndSettingsScreen extends StatefulWidget {
  final int initialTab;
  final VoidCallback? onSignOut;
  final void Function(int tabIndex)? onNavigateToTab;

  const ProfileAndSettingsScreen({
    super.key,
    this.initialTab = 0,
    this.onSignOut,
    this.onNavigateToTab,
  });

  @override
  State<ProfileAndSettingsScreen> createState() => _ProfileAndSettingsScreenState();
}

class _ProfileAndSettingsScreenState extends State<ProfileAndSettingsScreen> {
  // Profile Form Controllers
  late TextEditingController _firmNameController;
  late TextEditingController _ownerNameController;
  late TextEditingController _mobileController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _pincodeController;
  late TextEditingController _gstinController;
  late TextEditingController _panController;
  late TextEditingController _fssaiController;
  late TextEditingController _logoUrlController;
  late TextEditingController _profileImageUrlController;
  bool _isSavingProfile = false;

  bool _isSyncing = false;
  static const String _officialWebsiteUrl = 'https://salesarmy.io';

  @override
  void initState() {
    super.initState();
    final tenant = Provider.of<AppState>(context, listen: false).tenant;
    _firmNameController = TextEditingController(text: tenant.firmName ?? '');
    _ownerNameController = TextEditingController(text: tenant.representativeName ?? '');
    _mobileController = TextEditingController(text: tenant.mobile ?? '');
    _emailController = TextEditingController(text: tenant.email ?? '');
    _addressController = TextEditingController(text: tenant.warehouseAddress ?? '');
    _cityController = TextEditingController(text: tenant.city ?? '');
    _stateController = TextEditingController(text: tenant.state ?? '');
    _pincodeController = TextEditingController(text: tenant.pincode ?? '');
    _gstinController = TextEditingController(text: tenant.gstin ?? '');
    _panController = TextEditingController(text: tenant.pan ?? '');
    _fssaiController = TextEditingController(text: tenant.fssaiLicenseNo ?? '');
    _logoUrlController = TextEditingController(text: tenant.logoUrl ?? '');
    _profileImageUrlController = TextEditingController(text: tenant.profileImageUrl ?? '');
    _loadSavedPreferences();
  }

  Future<void> _loadSavedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedProfile = prefs.getString('salesarmy_pref_profile_image_url_v2');
      final savedLogo = prefs.getString('salesarmy_pref_logo_url_v2');
      if (mounted) {
        if (_profileImageUrlController.text.trim().isEmpty && savedProfile != null && savedProfile.isNotEmpty) {
          setState(() {
            _profileImageUrlController.text = savedProfile;
          });
        }
        if (_logoUrlController.text.trim().isEmpty && savedLogo != null && savedLogo.isNotEmpty) {
          setState(() {
            _logoUrlController.text = savedLogo;
          });
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _firmNameController.dispose();
    _ownerNameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _gstinController.dispose();
    _panController.dispose();
    _fssaiController.dispose();
    _logoUrlController.dispose();
    _profileImageUrlController.dispose();
    super.dispose();
  }

  String _getInitials(String name) {
    if (name.trim().isEmpty) return 'SA';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  /// Checks the business-details form. Returns an error message or null.
  String? _validateProfileForm({bool requireCore = true}) {
    final firm = _firmNameController.text.trim();
    final owner = _ownerNameController.text.trim();
    final mobile = _mobileController.text.replaceAll(RegExp(r'[\s-]'), '');
    final email = _emailController.text.trim();
    final gstin = _gstinController.text.trim().toUpperCase();
    final pan = _panController.text.trim().toUpperCase();
    final pin = _pincodeController.text.trim();
    if (requireCore) {
      if (firm.isEmpty) return 'Please enter your company / firm name.';
      if (owner.isEmpty) return 'Please enter the owner name.';
      if (mobile.isEmpty) return 'Please enter a mobile number.';
    }
    if (mobile.isNotEmpty && !RegExp(r'^(\+91)?[6-9][0-9]{9}$').hasMatch(mobile)) {
      return 'Mobile number must be a valid 10-digit Indian number.';
    }
    if (email.isNotEmpty && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$').hasMatch(email)) {
      return 'Please enter a valid email address.';
    }
    if (gstin.isNotEmpty && !RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$').hasMatch(gstin)) {
      return 'GSTIN must be 15 characters, e.g. 27AAACS1429B1ZB.';
    }
    if (pan.isNotEmpty && !RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(pan)) {
      return 'PAN must be 10 characters, e.g. AAACS1429B.';
    }
    if (pin.isNotEmpty && !RegExp(r'^[1-9][0-9]{5}$').hasMatch(pin)) {
      return 'Pincode must be 6 digits.';
    }
    return null;
  }

  /// Saves the business details. Returns true on success (stays open on error).
  Future<bool> _saveProfile({bool clearLogo = false, bool clearProfile = false, bool requireCore = false}) async {
    HapticFeedback.lightImpact();

    final invalid = _validateProfileForm(requireCore: requireCore);
    if (invalid != null) {
      showAppError(context, invalid);
      return false;
    }

    try {
      final appState = Provider.of<AppState>(context, listen: false);
      final current = appState.tenant;

      // Fill State from the GSTIN state code when it was left empty.
      final gstinUpper = _gstinController.text.trim().toUpperCase();
      if (_stateController.text.trim().isEmpty && gstinUpper.length >= 2) {
        final fromGst = AppState.getStateNameFromCode(AppState.getStateCodeFromGstin(gstinUpper));
        if (fromGst.isNotEmpty && !fromGst.toLowerCase().contains('unknown')) _stateController.text = fromGst;
      }

      final profileText = _profileImageUrlController.text.trim();
      final logoText = _logoUrlController.text.trim();

      final processedProfile = (clearProfile || profileText.isEmpty)
          ? null
          : await AppImageHelper.ensurePersistentUri(profileText);
      final processedLogo = (clearLogo || logoText.isEmpty)
          ? null
          : await AppImageHelper.ensurePersistentUri(logoText);

      final updated = current.copyWith(
        firmName: _firmNameController.text.trim(),
        representativeName: _ownerNameController.text.trim(),
        mobile: _mobileController.text.trim(),
        email: _emailController.text.trim(),
        warehouseAddress: _addressController.text.trim(),
        city: _cityController.text.trim(),
        state: _stateController.text.trim(),
        pincode: _pincodeController.text.trim(),
        gstin: _gstinController.text.trim().toUpperCase(),
        pan: _panController.text.trim().toUpperCase(),
        fssaiLicenseNo: _fssaiController.text.trim(),
        isGstBillingEnabled: appState.isGstBillingEnabled,
        logoUrl: processedLogo,
        profileImageUrl: processedProfile,
        clearLogo: clearLogo || logoText.isEmpty,
        clearProfileImage: clearProfile || profileText.isEmpty,
      );

      final prefs = await SharedPreferences.getInstance();
      if (processedProfile != null && processedProfile.isNotEmpty) {
        await prefs.setString('salesarmy_pref_profile_image_url_v2', processedProfile);
      } else if (clearProfile || profileText.isEmpty) {
        await prefs.remove('salesarmy_pref_profile_image_url_v2');
      }

      if (processedLogo != null && processedLogo.isNotEmpty) {
        await prefs.setString('salesarmy_pref_logo_url_v2', processedLogo);
      } else if (clearLogo || logoText.isEmpty) {
        await prefs.remove('salesarmy_pref_logo_url_v2');
      }

      await appState.updateTenant(
        updated,
        clearProfileImage: clearProfile || profileText.isEmpty,
        clearLogo: clearLogo || logoText.isEmpty,
      );

      if (mounted) {
        final cloudIssue = appState.lastTenantSyncError;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(cloudIssue == null ? Icons.check_circle_rounded : Icons.cloud_off_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(cloudIssue ?? 'Details saved and updated successfully!')),
              ],
            ),
            backgroundColor: cloudIssue == null ? const Color(0xFF059669) : const Color(0xFFD97706),
            duration: Duration(seconds: cloudIssue == null ? 2 : 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        showAppError(context, e, action: 'update your details');
      }
      return false;
    }
  }

  void _confirmSignOut() {
    final isDark = Provider.of<AppState>(context, listen: false).isDarkMode;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 22),
            const SizedBox(width: 8),
            Text('Sign Out?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: isDark ? Colors.white : const Color(0xFF0F172A))),
          ],
        ),
        content: Text(
          'Are you sure you want to sign out from SalesArmy? Unsynced offline queue will sync automatically upon next login.',
          style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final appState = Provider.of<AppState>(context, listen: false);
              AuthService? auth;
              try {
                auth = Provider.of<AuthService>(context, listen: false);
              } catch (_) {}
              Navigator.pop(ctx);
              appState.signOutSession();
              try {
                await auth?.signOut();
              } catch (_) {}
              if (navigator.canPop()) navigator.pop();
              widget.onSignOut?.call();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Future<void> _executeOfflineSync(AppState appState) async {
    setState(() => _isSyncing = true);
    HapticFeedback.lightImpact();
    try {
      final count = await appState.executeBatchSync();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Cloud sync completed! Synced $count pending records.'),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showAppError(context, e, action: 'sync your data');
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  void _showFeedbackModal(BuildContext context) {
    HapticFeedback.lightImpact();
    final appState = Provider.of<AppState>(context, listen: false);
    final isDark = appState.isDarkMode;
    int selectedRating = 5;
    final feedbackCtrl = TextEditingController();
    String selectedCategory = appState.cmsFeedbackCategories.isNotEmpty
        ? appState.cmsFeedbackCategories.first
        : 'General Experience';
    bool requestFollowUp = false;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final categories = appState.cmsFeedbackCategories;
          final cmsPrompt = appState.cmsFeedbackPrompt;

          return Material(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E56E2).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.rate_review_rounded, color: Color(0xFF1E56E2), size: 20),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Feedback for Us',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      cmsPrompt,
                      style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), height: 1.35),
                    ),
                    const SizedBox(height: 14),

                    // CMS Topic Selector Chips
                    Text(
                      'Select Topic / Category:',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: categories.map((cat) {
                          final isCatSelected = cat == selectedCategory;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setSheetState(() => selectedCategory = cat);
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isCatSelected
                                      ? const Color(0xFF1E56E2)
                                      : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isCatSelected
                                        ? const Color(0xFF1E56E2)
                                        : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                  ),
                                ),
                                child: Text(
                                  cat,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isCatSelected ? FontWeight.w800 : FontWeight.w600,
                                    color: isCatSelected
                                        ? Colors.white
                                        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Star Rating
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final starValue = index + 1;
                        return IconButton(
                          iconSize: 32,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          icon: Icon(
                            starValue <= selectedRating ? Icons.star_rounded : Icons.star_border_rounded,
                            color: const Color(0xFFF59E0B),
                          ),
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            setSheetState(() => selectedRating = starValue);
                          },
                        );
                      }),
                    ),
                    Center(
                      child: Text(
                        selectedRating == 5
                            ? '5 Stars • Excellent! Super smooth experience'
                            : selectedRating == 4
                                ? '4 Stars • Very good! Minor improvements needed'
                                : selectedRating == 3
                                    ? '3 Stars • Average • Work in progress'
                                    : selectedRating == 2
                                        ? '2 Stars • Having friction or slow response'
                                        : '1 Star • Critical issues encountered',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Feedback Comments Input
                    TextField(
                      controller: feedbackCtrl,
                      maxLines: 4,
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        hintText: 'Share your thoughts, pain points, or suggestions...',
                        hintStyle: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                        contentPadding: const EdgeInsets.all(12),
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
                          borderSide: const BorderSide(color: Color(0xFF1E56E2), width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Follow-up Checkbox
                    Row(
                      children: [
                        Checkbox(
                          value: requestFollowUp,
                          activeColor: const Color(0xFF1E56E2),
                          checkColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          side: BorderSide(color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8), width: 1.5),
                          onChanged: (val) {
                            HapticFeedback.selectionClick();
                            setSheetState(() => requestFollowUp = val ?? false);
                          },
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setSheetState(() => requestFollowUp = !requestFollowUp);
                            },
                            child: Text(
                              'Request follow-up call from product support team',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Submit Button wired to CMS
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E56E2),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final comment = feedbackCtrl.text.trim();
                              setSheetState(() => isSubmitting = true);
                              HapticFeedback.mediumImpact();

                              await appState.submitFeedbackToCms(
                                rating: selectedRating,
                                category: selectedCategory,
                                comments: comment.isNotEmpty ? comment : 'Rating provided: $selectedRating stars',
                                requestFollowUp: requestFollowUp,
                              );

                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                              }

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Row(
                                      children: [
                                        Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text('Thank you! Your feedback has been submitted to our product team.'),
                                        ),
                                      ],
                                    ),
                                    backgroundColor: Color(0xFF059669),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                      child: isSubmitting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text('Submit Feedback', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showLegalModal(BuildContext context) {
    HapticFeedback.lightImpact();
    final appState = Provider.of<AppState>(context, listen: false);
    final isDark = appState.isDarkMode;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DefaultTabController(
          length: 5,
          child: Material(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: Container(
              height: MediaQuery.of(ctx).size.height * 0.85,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E3A8A).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.gavel_rounded, color: Color(0xFF1E3A8A), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Legal & Compliance Center',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'SalesArmy Technologies Pvt Ltd • CIN: U72900MH2024PTC412345',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1E3A8A),
                    unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    indicatorColor: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1E3A8A),
                    indicatorWeight: 3,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                    tabs: const [
                      Tab(text: 'Terms of Service'),
                      Tab(text: 'Privacy (DPDPA)'),
                      Tab(text: 'Refund & Returns'),
                      Tab(text: 'Shipping & POS'),
                      Tab(text: 'Grievance Officer'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildPolicyScrollView(
                          title: 'Commercial Terms of Service',
                          tag: 'SAC 998314 • 18% GST Compliance',
                          paragraphs: [
                            '1. B2B Enterprise Eligibility: SalesArmy SaaS is provided solely for authorized commercial FMCG distributors and retail agency staff. By activating an account, you confirm commercial authorization.',
                            '2. Input Tax Credit (ITC): B2B invoices generated carry the Company GSTIN (27AABCS1429B1Z1) and your registered 15-digit GSTIN for valid ITC claims under the CGST/SGST Act.',
                            '3. Subscription Continuity: Cloud syncing, field telemetry, and order routing renew on chosen monthly or annual billing terms. Unpaid accounts receive a 72-hour grace period.',
                            '4. Data Sovereignty: All retail ledger entries, khata balances, and order records remain the sole intellectual property of the tenant distributor agency.',
                          ],
                          isDark: isDark,
                        ),
                        _buildPolicyScrollView(
                          title: 'Privacy Policy & DPDPA 2023',
                          tag: 'MeitY & Digital Personal Data Protection Act',
                          paragraphs: [
                            '1. Indian Data Residency: All database records, transactional ledgers, and authentication data are stored on secure cloud servers situated within India (ap-south-1 Mumbai).',
                            '2. Field GPS Tracking: Sales agent location data is recorded strictly during active beat punch-in shifts for route auditing and retailer check-ins.',
                            '3. Zero Card Storage: Financial card credentials and UPI MPINs are never stored on SalesArmy servers; payments are processed securely via RBI-licensed aggregators.',
                            '4. Data Principal Rights: Tenants can request automated data exports, rectifications, or account deletion via app Settings or support.',
                          ],
                          isDark: isDark,
                        ),
                        _buildPolicyScrollView(
                          title: 'Refund & Cancellation Policy',
                          tag: 'Consumer Protection (E-Commerce) Rules 2020',
                          paragraphs: [
                            '1. SaaS Cancellation: Tenants can cancel upcoming renewals at any time from subscription settings. Active pre-paid billing cycles run until expiry without penalty.',
                            '2. Billing Error Adjustments: In the event of inadvertent double-debits or technical payment glitches, 100% refund is initiated within 48 hours to original payment source.',
                            '3. POS Printer 7-Day DOA Replacement: Thermal printers received in damaged or non-functional condition qualify for immediate free doorstep replacement when reported within 7 days.',
                            '4. 12-Month Hardware Warranty: All printers include a 1-year manufacturer warranty covering print mechanisms and Bluetooth connectivity modules.',
                          ],
                          isDark: isDark,
                        ),
                        _buildPolicyScrollView(
                          title: 'Shipping & Hardware Delivery',
                          tag: 'All-India Logistics via DTDC / BlueDart',
                          paragraphs: [
                            '1. Dispatch Window: Verified printer hardware orders are packed and dispatched within 24 to 48 hours from our central Maharashtra hub.',
                            '2. Courier Network: Delivery is fulfilled across all serviceable pin codes in India via DTDC, BlueDart, Delhivery, or Speed Post.',
                            '3. Transit Timelines: Metro cities: 2 to 4 business days. Regional & interior districts: 4 to 7 business days.',
                            '4. Tracking: Real-time tracking numbers (AWB) are dispatched via SMS and updated automatically in your order dashboard.',
                          ],
                          isDark: isDark,
                        ),
                        _buildPolicyScrollView(
                          title: 'Statutory Grievance Redressal Officer',
                          tag: 'Rule 3(2) IT Rules 2021 & Consumer Protection Act',
                          paragraphs: [
                            'Designated Grievance Redressal Officer:\nShri Vikramaditya Sharma\nHead of Legal & Regulatory Compliance\nSalesArmy Technologies Private Limited\nPlot 42, Sector 18, Vashi Infotech Park, Navi Mumbai, MH - 400703\nEmail: grievance@salesarmy.saas\nPhone: +91 98200 54321 (Mon-Fri 10:00 AM - 6:00 PM IST)',
                            'Turnaround SLA:\n• Written acknowledgment within 24-48 hours\n• Complete complaint investigation and resolution within 15 calendar days',
                          ],
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                    label: const Text('Acknowledged & Close', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPolicyScrollView({
    required String title,
    required String tag,
    required List<String> paragraphs,
    required bool isDark,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: isDark ? const Color(0xFF3B82F6).withValues(alpha: 0.3) : const Color(0xFFBFDBFE)),
            ),
            child: Text(
              tag,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),
          ...paragraphs.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    p,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.5,
                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                    ),
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Future<void> _launchVisitorsUrl(BuildContext context) async {
    HapticFeedback.lightImpact();
    final uri = Uri.parse(_officialWebsiteUrl);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        Clipboard.setData(const ClipboardData(text: _officialWebsiteUrl));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Website link copied: https://salesarmy.io'),
            backgroundColor: Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        Clipboard.setData(const ClipboardData(text: _officialWebsiteUrl));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Website link copied: https://salesarmy.io'),
            backgroundColor: Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showDeleteAccountDialog(BuildContext context) {
    HapticFeedback.heavyImpact();
    final isDark = Provider.of<AppState>(context, listen: false).isDarkMode;
    final confirmCtrl = TextEditingController();
    bool isProcessing = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final isConfirmed = confirmCtrl.text.trim().toUpperCase() == 'DELETE';

          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.delete_forever_rounded, color: Color(0xFFDC2626), size: 24),
                SizedBox(width: 8),
                Text('Delete Account Forever', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFFDC2626))),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This action is irreversible. All distributor registrations, cloud database records, staff logins, and GST catalogs associated with this agency will be permanently destroyed.',
                    style: TextStyle(fontSize: 12.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.25) : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? const Color(0xFF991B1B) : const Color(0xFFFECDD3)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'To proceed, type DELETE in capital letters to confirm deliberate account deletion.',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFFF87171)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: confirmCtrl,
                    onChanged: (_) => setDlgState(() {}),
                    style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, color: Color(0xFFDC2626)),
                    decoration: InputDecoration(
                      hintText: 'TYPE DELETE',
                      hintStyle: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 1, color: Color(0xFF94A3B8), fontSize: 13),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFFFF1F2),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECDD3))),
                      focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)), borderSide: BorderSide(color: Color(0xFFDC2626), width: 1.5)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isProcessing ? null : () => Navigator.pop(ctx),
                child: Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFFCA5A5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: (!isConfirmed || isProcessing)
                    ? null
                    : () async {
                        final dialogNavigator = Navigator.of(ctx);
                        final navigator = Navigator.of(context);
                        final messenger = ScaffoldMessenger.of(context);
                        final appState = Provider.of<AppState>(context, listen: false);
                        AuthService? auth;
                        try {
                          auth = Provider.of<AuthService>(context, listen: false);
                        } catch (_) {}
                        setDlgState(() => isProcessing = true);
                        await appState.resetAccountData();
                        appState.signOutSession();
                        try {
                          await auth?.signOut();
                        } catch (_) {}
                        dialogNavigator.pop();
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Account deletion completed. Signing out...'),
                            backgroundColor: Color(0xFFDC2626),
                          ),
                        );
                        if (navigator.canPop()) navigator.pop();
                        widget.onSignOut?.call();
                      },
                child: isProcessing
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Delete Account', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _navigateToSale() {
    HapticFeedback.lightImpact();
    final appState = Provider.of<AppState>(context, listen: false);
    if (!appState.canAccessModule('billing') && !appState.canAccessModule('orders')) {
      showAppError(context, 'Access Restricted: Role (${appState.activeRole}) cannot access Sales & Invoicing.');
      return;
    }
    if (widget.onNavigateToTab != null) {
      if (Navigator.canPop(context)) Navigator.pop(context);
      widget.onNavigateToTab!(2);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (scaffoldCtx) => Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              scrolledUnderElevation: 0,
              title: const Text(
                'Sales & Orders',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              centerTitle: true,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF0F172A)),
                onPressed: () => Navigator.pop(scaffoldCtx),
              ),
              bottom: const PreferredSize(
                preferredSize: Size.fromHeight(1),
                child: Divider(height: 1, color: Color(0xFFF1F5F9)),
              ),
            ),
            body: const OrdersTab(),
          ),
        ),
      );
    }
  }

  Widget _buildAvatarFallback(String firmName, bool isDark) {
    return Center(
      child: Text(
        _getInitials(firmName),
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w900,
          color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1E56E2),
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  void _showUnifiedProfileModal(BuildContext context) {
    final appState = Provider.of<AppState>(context, listen: false);
    final isDark = appState.isDarkMode;
    final tenant = appState.tenant;
    final uniqueUserId = appState.uniqueUserId;

    _ownerNameController.text = tenant.representativeName ?? '';
    _mobileController.text = tenant.mobile ?? '';
    _emailController.text = tenant.email ?? '';
    _profileImageUrlController.text = tenant.profileImageUrl ?? '';
    _firmNameController.text = tenant.firmName ?? '';
    _addressController.text = tenant.warehouseAddress ?? '';
    _cityController.text = tenant.city ?? '';
    _stateController.text = tenant.state ?? '';
    _pincodeController.text = tenant.pincode ?? '';
    _gstinController.text = tenant.gstin ?? '';
    _panController.text = tenant.pan ?? '';
    _fssaiController.text = tenant.fssaiLicenseNo ?? '';
    _logoUrlController.text = tenant.logoUrl ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final logo = _logoUrlController.text.trim();

          return Material(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            clipBehavior: Clip.antiAlias,
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.90,
              ),
              padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Title Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.badge_outlined, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E56E2), size: 20),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Profile & Business Details',
                              style: TextStyle(
                                fontSize: 17.5,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 1. UNIQUE USER ID BANNER
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [const Color(0xFF1E3A8A).withValues(alpha: 0.35), const Color(0xFF172554)]
                              : [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? const Color(0xFF2563EB).withValues(alpha: 0.5) : const Color(0xFF93C5FD),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E56E2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.fingerprint_rounded, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'UNIQUE USER ID / CUSTOMER ID',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  uniqueUserId,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: uniqueUserId));
                                HapticFeedback.selectionClick();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                        const SizedBox(width: 8),
                                        Text('Copied User ID: $uniqueUserId'),
                                      ],
                                    ),
                                    backgroundColor: const Color(0xFF1E293B),
                                    duration: const Duration(seconds: 2),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF334155) : const Color(0xFFBFDBFE),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.copy_rounded, size: 13, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E56E2)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Copy',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E56E2),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // SECTION 1: Personal Details
                    Row(
                      children: [
                        Text(
                          'Personal Details',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E56E2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Divider(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                      ],
                    ),
                    const SizedBox(height: 12),

                    _buildField('Representative / Owner Name', _ownerNameController, Icons.person_outline_rounded, isDark: isDark),
                    const SizedBox(height: 12),
                    _buildField('Personal Mobile Number', _mobileController, Icons.phone_android_rounded, keyboard: TextInputType.phone, isDark: isDark),
                    const SizedBox(height: 12),
                    _buildField('Contact Email', _emailController, Icons.email_outlined, keyboard: TextInputType.emailAddress, isDark: isDark),
                    const SizedBox(height: 20),

                    // SECTION 2: Company & Business Details
                    Row(
                      children: [
                        Text(
                          'Company & Business Details',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E56E2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Divider(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Brand Logo Row (Direct Inline Picker)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () async {
                              final picked = await AppImageHelper.pickImageAsDataUri(fromCamera: false);
                              if (picked != null) {
                                _logoUrlController.text = picked;
                                setModalState(() {});
                              }
                            },
                            child: Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF1E56E2)),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: logo.isNotEmpty
                                  ? AppImageHelper.buildImage(
                                      logo,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(Icons.storefront_rounded, size: 26, color: Color(0xFF1E56E2)),
                                    )
                                  : const Icon(Icons.storefront_rounded, size: 26, color: Color(0xFF1E56E2)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Business / Brand Logo',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              final picked = await AppImageHelper.pickImageAsDataUri(fromCamera: false);
                              if (picked != null) {
                                _logoUrlController.text = picked;
                                setModalState(() {});
                              }
                            },
                            icon: const Icon(Icons.upload_outlined, size: 14),
                            label: Text(logo.isNotEmpty ? 'Change' : 'Upload', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                          ),
                          if (logo.isNotEmpty) ...[
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 16, color: Colors.red),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                _logoUrlController.clear();
                                setModalState(() {});
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildField('Company / Firm Name', _firmNameController, Icons.business_rounded, isDark: isDark),
                    const SizedBox(height: 12),
                    _buildField('Business Address', _addressController, Icons.location_on_outlined, maxLines: 2, isDark: isDark, hint: 'Shop / building, street, area'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildField('City', _cityController, Icons.location_city_outlined, isDark: isDark)),
                        const SizedBox(width: 10),
                        Expanded(child: _buildField('State', _stateController, Icons.flag_outlined, isDark: isDark)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildField('Pincode', _pincodeController, Icons.markunread_mailbox_outlined, keyboard: TextInputType.number, isDark: isDark),
                    const SizedBox(height: 12),
                    _buildField('GSTIN (Optional)', _gstinController, Icons.receipt_long_outlined, isDark: isDark, hint: 'e.g. 27AAACS1429B1ZB'),
                    const SizedBox(height: 12),
                    _buildField('PAN Number (Optional)', _panController, Icons.credit_card_outlined, isDark: isDark, hint: 'e.g. AAACS1429B'),
                    const SizedBox(height: 12),
                    _buildField('FSSAI License No. (Optional)', _fssaiController, Icons.verified_outlined, isDark: isDark),
                    const SizedBox(height: 22),

                    // Save Button
                    ElevatedButton(
                      onPressed: _isSavingProfile
                          ? null
                          : () async {
                              setModalState(() => _isSavingProfile = true);
                              final ok = await _saveProfile(requireCore: true);
                              if (!ctx.mounted) return;
                              setModalState(() => _isSavingProfile = false);
                              if (ok) Navigator.pop(ctx);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E56E2),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 2,
                      ),
                      child: _isSavingProfile
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Save Profile & Business Details', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }


  void _showEditGstModal(BuildContext context) {
    final appState = Provider.of<AppState>(context, listen: false);
    final isDark = appState.isDarkMode;
    final tenant = appState.tenant;
    _gstinController.text = tenant.gstin ?? '';
    _panController.text = tenant.pan ?? '';
    _fssaiController.text = tenant.fssaiLicenseNo ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Material(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            clipBehavior: Clip.antiAlias,
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.88,
              ),
              padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'GST & Registration Compliance',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    Divider(height: 16, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    const SizedBox(height: 8),
                    _buildField('GSTIN (Optional)', _gstinController, Icons.receipt_long_rounded, isDark: isDark),
                    const SizedBox(height: 12),
                    _buildField('PAN Number (Optional)', _panController, Icons.badge_outlined, isDark: isDark),
                    const SizedBox(height: 12),
                    _buildField('FSSAI License No. (Optional)', _fssaiController, Icons.verified_outlined, isDark: isDark),
                    const SizedBox(height: 14),

                    // GST Invoicing Toggle inside compliance
                    Material(
                      color: isDark ? const Color(0xFF0F172A) : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Enable GST Tax Invoicing',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                          ),
                          subtitle: Text(
                            'Generates B2B/B2C GST tax breakdown bills',
                            style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                          value: appState.isGstBillingEnabled,
                          activeThumbColor: const Color(0xFF059669),
                          onChanged: (val) {
                            appState.setGstBillingEnabled(val);
                            setModalState(() {});
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // FMCG GST Tax Rates Summary
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.3) : const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? const Color(0xFF065F46) : const Color(0xFFBBF7D0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Standard FMCG Tax Slabs:', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: isDark ? const Color(0xFF34D399) : const Color(0xFF166534))),
                          const SizedBox(height: 6),
                          Text('• 5% : Grains, pulses, edible oils, dairy products', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFFA7F3D0) : const Color(0xFF15803D))),
                          Text('• 12% : Packaged foods, butter, ghee, fruit juices', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFFA7F3D0) : const Color(0xFF15803D))),
                          Text('• 18% : Biscuits, confectionery, soaps, detergents', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFFA7F3D0) : const Color(0xFF15803D))),
                          Text('• 28% : Aerated soft drinks, energy drinks, tobacco', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFFA7F3D0) : const Color(0xFF15803D))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.tune_rounded, size: 18),
                      label: const Text('Manage GST Tax Slabs (Add / Remove)'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const GstConfigurationScreen()),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF059669),
                        side: const BorderSide(color: Color(0xFF10B981)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton(
                      onPressed: () async {
                        final ok = await _saveProfile();
                        if (ok && ctx.mounted) Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E56E2),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Save Compliance Details', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Role switching has been removed in production to enforce strict RBAC

  void _showPlanDetailsModal(BuildContext context) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PlanAndPricingScreen()),
    );
  }

  void _showUserGuideModal(BuildContext context) {
    final isDark = Provider.of<AppState>(context, listen: false).isDarkMode;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Material(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('User Guide & Tutorials', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              Divider(height: 16, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              Expanded(
                child: ListView(
                  children: [
                    _buildGuideItem(
                      '1. Quick Sales & Invoicing',
                      'Tap "Sale" from the quick card or menu. Add items to cart from the catalog, select the retailer shop, choose payment (Cash/Credit/UPI), and click Generate Bill. You can instantly share the PDF via WhatsApp or print via Bluetooth.',
                      Icons.shopping_basket_outlined,
                      isDark: isDark,
                    ),
                    _buildGuideItem(
                      '2. Thermal Printer Setup',
                      'Tap "Printer" under Settings & Hardware. Turn on your ESC/POS Bluetooth printer (58mm or 80mm). Select your device from the scanned list, choose paper size, and tap "Print Test Receipt" to verify pairing.',
                      Icons.print_outlined,
                      isDark: isDark,
                    ),
                    _buildGuideItem(
                      '3. Recording Purchases (Goods In)',
                      'Tap "Purchase" to record new stock received from FMCG brands or super-stockists. Enter supplier name, invoice number, items summary, amount, and payment status (Paid or Pending dues).',
                      Icons.inventory_2_outlined,
                      isDark: isDark,
                    ),
                    _buildGuideItem(
                      '4. Daily Expenses Management',
                      'Tap "Expense" to log daily operational costs such as fuel/petrol, vehicle maintenance, staff tea/food, or rent. Filter by category and track monthly expense metrics.',
                      Icons.account_balance_wallet_outlined,
                      isDark: isDark,
                    ),
                    _buildGuideItem(
                      '5. Staff RBAC & Delivery Dispatch',
                      'Go to "Staff" to add sales executives or delivery staff. Assign roles (Salesman, Delivery Boy, Billing Operator) with specific module restrictions to ensure secure operation.',
                      Icons.group_outlined,
                      isDark: isDark,
                    ),
                    _buildGuideItem(
                      '6. Business Reminders & Follow-ups',
                      'Use "Reminder" to schedule daily, weekly, or monthly collection follow-ups with retailers. When marked complete, recurring reminders automatically schedule the next occurrence.',
                      Icons.alarm_rounded,
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuideItem(String title, String body, IconData icon, {bool isDark = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : const Color(0xFFEFF6FF),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: const Color(0xFF3B82F6)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                const SizedBox(height: 4),
                Text(body, style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569), height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showHelpSupportModal(BuildContext context) {
    HapticFeedback.lightImpact();
    final isDark = Provider.of<AppState>(context, listen: false).isDarkMode;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Material(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Help & Support Desk', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                      const SizedBox(height: 2),
                      Text('24/7 dedicated support for FMCG distributors', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    onPressed: () {
                      if (Navigator.canPop(ctx)) Navigator.pop(ctx);
                    },
                  ),
                ],
              ),
              Divider(height: 16, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              _buildSupportTile(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'WhatsApp Support',
                subtitle: '+91 98220 11223 (Instant response)',
                badge: 'RECOMMENDED',
                isDark: isDark,
                onTap: () {
                  if (Navigator.canPop(ctx)) Navigator.pop(ctx);
                  Clipboard.setData(const ClipboardData(text: '+919822011223'));
                  HapticFeedback.lightImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('WhatsApp number +91 98220 11223 copied to clipboard!'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: Color(0xFF16A34A),
                    ),
                  );
                },
              ),
              Divider(height: 1, indent: 52, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              _buildSupportTile(
                icon: Icons.phone_in_talk_outlined,
                title: 'Toll-Free Helpline',
                subtitle: '1800 200 4567 (Mon-Sat, 9AM - 8PM)',
                isDark: isDark,
                onTap: () {
                  if (Navigator.canPop(ctx)) Navigator.pop(ctx);
                  Clipboard.setData(const ClipboardData(text: '18002004567'));
                  HapticFeedback.lightImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Helpline 1800 200 4567 copied to clipboard!'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: Color(0xFF1E56E2),
                    ),
                  );
                },
              ),
              Divider(height: 1, indent: 52, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              _buildSupportTile(
                icon: Icons.email_outlined,
                title: 'Email Support Desk',
                subtitle: 'help@salesarmy.app',
                isDark: isDark,
                onTap: () {
                  if (Navigator.canPop(ctx)) Navigator.pop(ctx);
                  Clipboard.setData(const ClipboardData(text: 'help@salesarmy.app'));
                  HapticFeedback.lightImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Email help@salesarmy.app copied to clipboard!'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              Divider(height: 1, indent: 52, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              _buildSupportTile(
                icon: Icons.menu_book_outlined,
                title: 'User Guide & Video Tutorials',
                subtitle: 'Learn billing, stock entry, and printer setup',
                isDark: isDark,
                onTap: () {
                  if (Navigator.canPop(ctx)) Navigator.pop(ctx);
                  _showUserGuideModal(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSupportTile({
    required IconData icon,
    required String title,
    required String subtitle,
    String? badge,
    required VoidCallback onTap,
    bool isDark = false,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : const Color(0xFFEFF6FF),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: const Color(0xFF3B82F6)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                      if (badge != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(6)),
                          child: Text(badge, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFF16A34A))),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, IconData icon, {TextInputType? keyboard, int maxLines = 1, bool isDark = false, String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboard,
          maxLines: maxLines,
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          decoration: InputDecoration(
            hintText: hint ?? 'Enter $label',
            hintStyle: TextStyle(fontSize: 12.5, fontWeight: FontWeight.normal, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
            prefixIcon: Icon(icon, size: 18, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            filled: true,
            fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1E56E2), width: 1.5)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isDark = appState.isDarkMode;
    final tenant = appState.tenant;
    final firmName = tenant.firmName?.trim().isNotEmpty == true ? tenant.firmName! : 'Business Profile';

    final bgColor = isDark ? const Color(0xFF0F172A) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFFFCC00),
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Material(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFF0F172A).withValues(alpha: 0.1),
            shape: const CircleBorder(),
            elevation: 0,
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                if (Navigator.canPop(context)) Navigator.pop(context);
              },
              customBorder: const CircleBorder(),
              child: Icon(Icons.arrow_back_rounded, size: 18, color: isDark ? Colors.white : const Color(0xFF0F172A)),
            ),
          ),
        ),
        title: Text(
          'My Business',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            letterSpacing: -0.2,
          ),
        ),
        centerTitle: true,
      ),
        body: SingleChildScrollView(
          child: ResponsiveContainer(
            maxWidth: 760,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              // ==========================================
              // 1. TOP REDUCED YELLOW HEADER (Above Profile Section)
              // ==========================================
              Container(
                height: 20,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFFCC00),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? Colors.black.withValues(alpha: 0.25) : const Color(0x2BF59E0B),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ==========================================
              // 2. PROFILE PHOTO / LOGO AVATAR
              // ==========================================
              Center(
                child: GestureDetector(
                  onTap: () => _showUnifiedProfileModal(context),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            width: 3.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: (tenant.logoUrl?.trim().isNotEmpty == true)
                              ? AppImageHelper.buildImage(
                                  tenant.logoUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => (tenant.profileImageUrl?.trim().isNotEmpty == true)
                                      ? AppImageHelper.buildImage(
                                          tenant.profileImageUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => _buildAvatarFallback(firmName, isDark),
                                        )
                                      : _buildAvatarFallback(firmName, isDark),
                                )
                              : (tenant.profileImageUrl?.trim().isNotEmpty == true)
                                  ? AppImageHelper.buildImage(
                                      tenant.profileImageUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => _buildAvatarFallback(firmName, isDark),
                                    )
                                  : _buildAvatarFallback(firmName, isDark),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ==========================================
              // 3. FIRM IDENTITY & BADGES (On clean ambient canvas)
              // ==========================================
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: Column(
                  children: [
                    // Headline: Firm Name
                    Text(
                      firmName,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: appState.uniqueUserId));
                        HapticFeedback.lightImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('User ID ${appState.uniqueUserId} copied to clipboard!'),
                            backgroundColor: const Color(0xFF0F172A),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4.5),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.badge_outlined, size: 14, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            const SizedBox(width: 5),
                            Text(
                              'User ID: ${appState.uniqueUserId}',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.copy_rounded, size: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Plan & Quick Action Cards on Clean Canvas
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                          // ==========================================
                          // 4. SALESARMY PLAN & SUBSCRIPTION CARD
                          // ==========================================
                          if (appState.isOwnerRole) ...[
                            InkWell(
                              onTap: () => _showPlanDetailsModal(context),
                              borderRadius: BorderRadius.circular(18),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                    width: 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.08),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF1E3A8A) : const Color(0xFF1E56E2),
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 22),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  'SalesArmy Plan & Subscription',
                                                  style: TextStyle(
                                                    fontSize: 13.5,
                                                    fontWeight: FontWeight.w800,
                                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                                decoration: BoxDecoration(
                                                  color: isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  appState.subscriptionBadgeText,
                                                  style: TextStyle(
                                                    fontSize: 9.5,
                                                    fontWeight: FontWeight.w900,
                                                    color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            'Plan: ${appState.currentPlan.name}${appState.isReadOnlyMode ? " (expired · read-only)" : (appState.isTrial ? " (free trial)" : "")} • Tap to view & upgrade',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF2563EB),
                                              fontWeight: FontWeight.w600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(Icons.arrow_forward_ios_rounded, size: 14, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF1E56E2)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                          ]
                          else if (!appState.isOwnerRole && appState.activeRole.toLowerCase() != 'owner') ...[
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                      shape: BoxShape.circle,
                                    ),
                                    alignment: Alignment.center,
                                    child: Icon(Icons.badge_rounded, color: isDark ? Colors.white70 : const Color(0xFF475569), size: 22),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Operating as ${appState.activeRole}',
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w800,
                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          'Distributor Agency: $firmName',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],

                          // ==========================================
                          // 3. THREE QUICK ACTION CARDS ROW (Home, Sales, Orders)
                          // ==========================================
                          Builder(
                            builder: (ctx) {
                              final quickCards = <Widget>[
                                // Card 1: Home (Universal)
                                Expanded(
                                  child: _buildBlinkitQuickCard(
                                    icon: Icons.home_rounded,
                                    label: 'Home',
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      if (widget.onNavigateToTab != null) {
                                        if (Navigator.canPop(context)) Navigator.pop(context);
                                        widget.onNavigateToTab!(0);
                                      } else {
                                        if (Navigator.canPop(context)) Navigator.pop(context);
                                      }
                                    },
                                    isDark: isDark,
                                  ),
                                ),
                              ];

                              // Card 2: Sales (Owner, Field Sales, or billing/orders access)
                              final canAccessSales = (appState.canAccessModule('billing') || appState.canAccessModule('orders') || appState.isOwnerRole) &&
                                  !appState.isDeliveryRole &&
                                  !appState.isStoreManagerRole;

                              if (canAccessSales) {
                                quickCards.add(const SizedBox(width: 10));
                                quickCards.add(
                                  Expanded(
                                    child: _buildBlinkitQuickCard(
                                      icon: Icons.point_of_sale_rounded,
                                      label: 'Sales',
                                      onTap: _navigateToSale,
                                      isDark: isDark,
                                    ),
                                  ),
                                );
                              }

                              // Card 3: Role-Tailored action (Deliveries for Delivery, Dispatches for Store Manager, Bills for Accountant, Orders for Owner/Sales)
                              if (appState.isDeliveryRole) {
                                quickCards.add(const SizedBox(width: 10));
                                quickCards.add(
                                  Expanded(
                                    child: _buildBlinkitQuickCard(
                                      icon: Icons.local_shipping_rounded,
                                      label: 'Deliveries',
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        if (widget.onNavigateToTab != null) {
                                          if (Navigator.canPop(context)) Navigator.pop(context);
                                          widget.onNavigateToTab!(2);
                                        } else {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => Scaffold(
                                                backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                                                appBar: AppBar(title: const Text('Deliveries')),
                                                body: const OrdersTab(initialTabIndex: 0),
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                      isDark: isDark,
                                    ),
                                  ),
                                );
                              } else if (appState.isStoreManagerRole) {
                                quickCards.add(const SizedBox(width: 10));
                                quickCards.add(
                                  Expanded(
                                    child: _buildBlinkitQuickCard(
                                      icon: Icons.warehouse_rounded,
                                      label: 'Dispatches',
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        if (widget.onNavigateToTab != null) {
                                          if (Navigator.canPop(context)) Navigator.pop(context);
                                          widget.onNavigateToTab!(2);
                                        } else {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => Scaffold(
                                                backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                                                appBar: AppBar(title: const Text('Dispatches')),
                                                body: const OrdersTab(initialTabIndex: 0),
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                      isDark: isDark,
                                    ),
                                  ),
                                );
                              } else if (appState.isAccountantRole) {
                                quickCards.add(const SizedBox(width: 10));
                                quickCards.add(
                                  Expanded(
                                    child: _buildBlinkitQuickCard(
                                      icon: Icons.receipt_long_rounded,
                                      label: 'Bills',
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        if (widget.onNavigateToTab != null) {
                                          if (Navigator.canPop(context)) Navigator.pop(context);
                                          widget.onNavigateToTab!(2);
                                        }
                                      },
                                      isDark: isDark,
                                    ),
                                  ),
                                );
                              } else if (appState.canAccessModule('orders') || appState.isOwnerRole) {
                                quickCards.add(const SizedBox(width: 10));
                                quickCards.add(
                                  Expanded(
                                    child: _buildBlinkitQuickCard(
                                      icon: Icons.inventory_2_outlined,
                                      label: 'Orders',
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        if (widget.onNavigateToTab != null) {
                                          if (Navigator.canPop(context)) Navigator.pop(context);
                                          widget.onNavigateToTab!(3);
                                        } else {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => Scaffold(
                                                backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                                                appBar: AppBar(title: const Text('Orders')),
                                                body: const OrdersTab(initialTabIndex: 1),
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                      isDark: isDark,
                                    ),
                                  ),
                                );
                              }

                              return Row(children: quickCards);
                            },
                          ),
                          const SizedBox(height: 18),
                        ],
                      ),
                    ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ==========================================
                    // 4. SECTION: "My Business" (On clean ambient canvas)
                    // ==========================================
                    Text(
                      'My Business',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A), letterSpacing: -0.2),
                    ),
                  const SizedBox(height: 10),
                  Material(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        // Profile & Business Details (Unified)
                        _buildSettingsRow(
                          icon: Icons.badge_outlined,
                          title: 'Profile',
                          subtitle: '${tenant.representativeName ?? "Distributor Owner"} • $firmName',
                          onTap: () => _showUnifiedProfileModal(context),
                          isDark: isDark,
                        ),

                        // Sale
                        if (appState.canAccessModule('billing') || appState.canAccessModule('orders') || appState.isOwnerRole) ...[
                          Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9), indent: 52),
                          _buildSettingsRow(
                            icon: Icons.shopping_basket_outlined,
                            title: 'Sale',
                            planFeature: 'order_taking',
                            subtitle: 'Orders, dispatch & sales ledger',
                            onTap: _navigateToSale,
                            isDark: isDark,
                          ),
                        ],

                        // Purchase
                        if (appState.canAccessModule('purchase') || appState.isOwnerRole) ...[
                          Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9), indent: 52),
                          _buildSettingsRow(
                            icon: Icons.inventory_2_outlined,
                            title: 'Purchase',
                            planFeature: 'purchases',
                            subtitle: 'Goods in, purchase bills & supplier dues',
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const PurchaseScreen()));
                            },
                            isDark: isDark,
                          ),
                        ],

                        // Expense
                        if (appState.canAccessModule('expense') || appState.canAccessModule('accounts') || appState.isOwnerRole) ...[
                          Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9), indent: 52),
                          _buildSettingsRow(
                            icon: Icons.account_balance_wallet_outlined,
                            title: 'Expense',
                            planFeature: 'expenses',
                            subtitle: 'Daily operational expenses & receipts',
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpenseScreen()));
                            },
                            isDark: isDark,
                          ),
                        ],

                        // Export Reports & Statements
                        if (appState.canAccessModule('reports') || appState.isOwnerRole) ...[
                          Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9), indent: 52),
                          _buildSettingsRow(
                            icon: Icons.share_outlined,
                            title: 'Export Reports & Statements',
                            planFeature: 'reports',
                            subtitle: appState.hasFeature('reports')
                                ? 'Download Half-Year & Annual CSV/PDF'
                                : 'Half-Year & Annual Statements • Upgrade to unlock',
                            onTap: () async {
                              if (!await FeatureGate.requireFeature(context, 'reports')) return;
                              if (!context.mounted) return;
                              {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ReportsScreen(),
                                  ),
                                );
                              }
                            },
                            isDark: isDark,
                          ),
                        ],

                        // Have a Sales Advisor Plan and Subscription (Owner Only)
                        if (appState.isOwnerRole) ...[
                          Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9), indent: 52),
                          _buildSettingsRow(
                            icon: Icons.workspace_premium_rounded,
                            title: 'Have a Sales Advisor Plan and Subscription',
                            subtitle: 'View active plan, limits & renewal details',
                            onTap: () => _showPlanDetailsModal(context),
                            isDark: isDark,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ==========================================
                  // 5. SECTION: "Banking and GST"
                  // ==========================================
                  if (appState.canAccessModule('accounts') || appState.isOwnerRole) ...[
                    Text(
                      'Banking and GST',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A), letterSpacing: -0.2),
                    ),
                    const SizedBox(height: 10),
                    Material(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          // Bank Details
                          _buildSettingsRow(
                            icon: Icons.account_balance_rounded,
                            title: 'Bank Details',
                            subtitle: '${appState.bankAccounts.length} of ${AppState.maxBankAccounts} accounts linked',
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountsScreen()));
                            },
                            isDark: isDark,
                          ),
                          Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9), indent: 52),

                          // Payment & Preferences (UPI QR & Payment Gateways)
                          _buildSettingsRow(
                            icon: Icons.qr_code_2_rounded,
                            title: 'Payment & Preferences',
                            planFeature: 'dynamic_upi_qr',
                            subtitle: 'UPI QR code & payment gateways',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const PaymentPreferencesScreen()),
                              );
                            },
                            isDark: isDark,
                          ),
                          Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9), indent: 52),

                          // GST Details (Kept as single unified entry point as requested)
                          _buildSettingsRow(
                            icon: Icons.receipt_long_rounded,
                            title: 'GST Details',
                            subtitle: 'GSTIN: ${tenant.gstin ?? "Not Set"} • PAN: ${tenant.pan ?? "Not Set"}${appState.isGstBillingEnabled ? " • Active" : " • Off"}',
                            onTap: () {
                              // Basic GST details are part of every plan; custom
                              // slabs are gated inside GstConfigurationScreen.
                              _showEditGstModal(context);
                            },
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ==========================================
                  // 6. SECTION: "Hardware" (Distinct Module)
                  // ==========================================
                  if (appState.canAccessModule('billing') || appState.canAccessModule('orders') || appState.isOwnerRole) ...[
                    Text(
                      'Hardware',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A), letterSpacing: -0.2),
                    ),
                    const SizedBox(height: 10),
                    Material(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          _buildSettingsRow(
                            icon: Icons.print_rounded,
                            title: 'Printer',
                            planFeature: 'thermal_printer',
                            subtitle: !appState.isFeatureEnabledRemotely('thermal_printer')
                                ? 'Thermal printer is currently unavailable'
                                : 'ESC/POS 58mm & 80mm wireless receipt printing',
                            iconBgColor: isDark
                                ? (!appState.isFeatureEnabledRemotely('thermal_printer')
                                    ? const Color(0xFF78350F).withValues(alpha: 0.35)
                                    : (PrinterService.instance.settings.isConnected ? const Color(0xFF064E3B).withValues(alpha: 0.35) : const Color(0xFF334155)))
                                : (!appState.isFeatureEnabledRemotely('thermal_printer')
                                    ? const Color(0xFFFEF3C7)
                                    : (PrinterService.instance.settings.isConnected ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9))),
                            iconColor: !appState.isFeatureEnabledRemotely('thermal_printer')
                                ? const Color(0xFFD97706)
                                : (PrinterService.instance.settings.isConnected ? const Color(0xFF059669) : const Color(0xFF64748B)),
                            onTap: () {
                              if (!appState.isFeatureEnabledRemotely('thermal_printer')) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Thermal printing is currently unavailable.'),
                                    backgroundColor: Color(0xFFD97706),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                                return;
                              }
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const PrinterSettingsScreen()),
                              ).then((_) {
                                if (mounted) setState(() {});
                              });
                            },
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ==========================================
                  // 7. SECTION: "Staff & Team"
                  // ==========================================
                  if (appState.canAccessModule('staff') || appState.isOwnerRole) ...[
                    Text(
                      'Staff & Team',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A), letterSpacing: -0.2),
                    ),
                    const SizedBox(height: 10),
                    Material(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          // Staff -> Add User (Define Role)
                          _buildSettingsRow(
                            icon: Icons.group_outlined,
                            title: 'Staff',
                            planFeature: 'staff_management',
                            subtitle: appState.planIncludes('staff_management')
                                ? 'Add user & define role permissions (RBAC)'
                                : 'Multi-user roles • Upgrade to unlock',
                            onTap: () async {
                              if (!appState.planIncludes('staff_management') &&
                                  !await FeatureGate.requireFeature(context, 'staff_management')) {
                                return;
                              }
                              if (!context.mounted) return;
                              {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const StaffManagementScreen()),
                                );
                              }
                            },
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ==========================================
                  // 8. SECTION: "App Preferences" (Strictly Notification, Reminder, and Backup)
                  // ==========================================
                  Text(
                    'App Preferences',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A), letterSpacing: -0.2),
                  ),
                  const SizedBox(height: 10),
                  Material(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        // 1. Notification
                        _buildSettingsRow(
                          icon: Icons.notifications_active_outlined,
                          title: 'Notification',
                          subtitle: appState.unreadNotificationsCount > 0
                              ? '${appState.unreadNotificationsCount} unread alerts • Tap to manage'
                              : 'Real-time order, inventory & payment alerts',
                          trailingBadge: appState.unreadNotificationsCount > 0
                              ? '${appState.unreadNotificationsCount} NEW'
                              : 'ACTIVE',
                          iconBgColor: isDark
                              ? (appState.unreadNotificationsCount > 0 ? const Color(0xFF7F1D1D).withValues(alpha: 0.3) : const Color(0xFF1E3A8A).withValues(alpha: 0.3))
                              : (appState.unreadNotificationsCount > 0 ? const Color(0xFFFEF2F2) : const Color(0xFFEFF6FF)),
                          iconColor: appState.unreadNotificationsCount > 0 ? const Color(0xFFEF4444) : const Color(0xFF1E56E2),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                            );
                          },
                          isDark: isDark,
                        ),
                        Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9), indent: 52),

                        // 2. Reminder
                        _buildSettingsRow(
                          icon: Icons.alarm_rounded,
                          title: 'Reminders',
                            planFeature: 'visits',
                          subtitle: '${appState.reminders.where((r) => !r.isCompleted).length} pending • Customer dues & market tasks',
                          trailingBadge: appState.reminders.where((r) => !r.isCompleted).isNotEmpty
                              ? '${appState.reminders.where((r) => !r.isCompleted).length} PENDING'
                              : null,
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const RemindersScreen()));
                          },
                          isDark: isDark,
                        ),
                        Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9), indent: 52),

                        // 3. Backup (Offline Storage & Cloud Sync)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.cloud_sync_rounded, color: Color(0xFF1E56E2), size: 20),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Backup & Cloud Sync',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      appState.outboxManager.pendingCount > 0
                                          ? '${appState.outboxManager.pendingCount} pending records waiting'
                                          : 'Offline storage & cloud sync active',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E56E2),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: _isSyncing ? null : () => _executeOfflineSync(appState),
                                child: _isSyncing
                                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Text('Sync Now', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ==========================================
                  // 9. SECTION: "Appearance" (Dark Theme Mode)
                  // ==========================================
                  Text(
                    'Appearance',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A), letterSpacing: -0.2),
                  ),
                  const SizedBox(height: 10),
                  Material(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        secondary: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                            color: isDark ? const Color(0xFFFBBF24) : const Color(0xFF1E56E2),
                            size: 20,
                          ),
                        ),
                        title: Text(
                          'Dark Theme Mode',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        ),
                        subtitle: Text(
                          isDark ? 'Dark theme active (Sleek slate mode)' : 'Light theme active (Crisp daylight mode)',
                          style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                        value: isDark,
                        activeThumbColor: const Color(0xFF1E56E2),
                        onChanged: (val) {
                          HapticFeedback.lightImpact();
                          appState.toggleTheme();
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ==========================================
                  // 10. SECTION: "Support & Account"
                  // ==========================================
                  Text(
                    'Support & Account',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A), letterSpacing: -0.2),
                  ),
                  const SizedBox(height: 10),
                  Material(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        // Super Admin Console Switch
                        if (appState.isSuperAdminUser) ...[
                          _buildSettingsRow(
                            icon: Icons.admin_panel_settings_rounded,
                            title: 'Switch to Super Admin Console',
                            subtitle: 'Manage SaaS tenants, subscriptions & global analytics',
                            iconColor: const Color(0xFF6366F1),
                            iconBgColor: isDark ? const Color(0xFF312E81).withValues(alpha: 0.3) : const Color(0xFFEEF2FF),
                            titleColor: const Color(0xFF6366F1),
                            onTap: () {
                              appState.toggleSuperAdminMode(true);
                              Navigator.of(context).pop();
                            },
                            isDark: isDark,
                          ),
                          Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9), indent: 52),
                        ],

                        // Help & Support
                        _buildSettingsRow(
                          icon: Icons.headset_mic_outlined,
                          title: 'Help & Support',
                          subtitle: '24/7 WhatsApp, Helpline & User Guides',
                          onTap: () => _showHelpSupportModal(context),
                          isDark: isDark,
                        ),
                        Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9), indent: 52),

                        // Visitors / Visit Us (Requirement 13)
                        _buildSettingsRow(
                          icon: Icons.language_rounded,
                          title: 'Visitors',
                          subtitle: '$_officialWebsiteUrl • Official Portal & Guides',
                          onTap: () => _launchVisitorsUrl(context),
                          isDark: isDark,
                        ),
                        Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9), indent: 52),

                        // Reset Account Data (Requirement 14 - Owner Only)
                        if (appState.isOwnerRole) ...[
                          _buildSettingsRow(
                            icon: Icons.restart_alt_rounded,
                            title: 'Reset Account Data',
                            subtitle: 'Clear orders, bills, collections & reset stock with security confirmation',
                            iconColor: const Color(0xFFDC2626),
                            iconBgColor: isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.3) : const Color(0xFFFEF2F2),
                            titleColor: const Color(0xFFDC2626),
                            onTap: () {
                              if (!appState.isOwnerRole) {
                                showAppError(context, 'Access Restricted: Role (${appState.activeRole}) cannot reset account data.');
                                return;
                              }
                              ResetAccountDialog.show(context);
                            },
                            isDark: isDark,
                          ),
                          Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9), indent: 52),

                          // Delete Account (Requirement 13 - Owner Only)
                          _buildSettingsRow(
                            icon: Icons.delete_forever_rounded,
                            title: 'Delete Account',
                            subtitle: 'Permanently wipe company profile & registration',
                            iconColor: const Color(0xFFDC2626),
                            iconBgColor: isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.3) : const Color(0xFFFEF2F2),
                            titleColor: const Color(0xFFDC2626),
                            onTap: () {
                              if (!appState.isOwnerRole) {
                                showAppError(context, 'Access Restricted: Role (${appState.activeRole}) cannot delete account.');
                                return;
                              }
                              _showDeleteAccountDialog(context);
                            },
                            isDark: isDark,
                          ),
                          Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9), indent: 52),
                        ],

                        // Log out
                        _buildSettingsRow(
                          icon: Icons.logout_rounded,
                          title: 'Log out',
                          subtitle: 'Sign out from this device',
                          iconColor: const Color(0xFFDC2626),
                          iconBgColor: isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.3) : const Color(0xFFFEF2F2),
                          titleColor: const Color(0xFFDC2626),
                          onTap: _confirmSignOut,
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ==========================================
                  // 9. NATIVE FEEDBACK SECTION (CMS Wired)
                  // ==========================================
                  Container(
                    margin: const EdgeInsets.only(top: 8, bottom: 20),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                            : [const Color(0xFFEFF6FF), Colors.white],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFDBEAFE)),
                      boxShadow: [
                        BoxShadow(
                          color: isDark ? Colors.black.withValues(alpha: 0.25) : const Color(0xFF1E56E2).withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E56E2).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.rate_review_rounded, color: Color(0xFF1E56E2), size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Feedback for Us',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    appState.cmsFeedbackPrompt,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                      height: 1.3,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Dynamic CMS category chips preview
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: appState.cmsFeedbackCategories.take(4).map((c) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                              ),
                              child: Text(
                                c,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _showFeedbackModal(context),
                            icon: const Icon(Icons.send_rounded, size: 15),
                            label: const Text('Share Your Feedback', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E56E2),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                          ),
                        ),
                        if (appState.submittedFeedbackList.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_circle_outline_rounded, size: 13, color: Color(0xFF10B981)),
                                const SizedBox(width: 4),
                                Text(
                                  'Feedback sent to product team (${appState.submittedFeedbackList.length} submitted)',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF059669),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ==========================================
                  // 10. FOOTER
                  // ==========================================
                  Center(
                    child: Column(
                      children: [
                        TextButton.icon(
                          onPressed: () => _showLegalModal(context),
                          icon: Icon(Icons.gavel_rounded, size: 14, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          label: Text(
                            'Legal & Compliance Center',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'salesarmy',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          appState.minAppVersion,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ],
        ),
          ),
      ),
    );
  }

  // Quick Action Card (Blinkit style: white box, centered icon, label)
  Widget _buildBlinkitQuickCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDark = false,
  }) {
    return Material(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black.withValues(alpha: 0.2) : const Color(0xFF0F172A).withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 26, color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF0F172A)),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Settings Row item with leading icon, title, subtitle, and trailing chevron
  Widget _buildSettingsRow({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? iconColor,
    Color? iconBgColor,
    Color? titleColor,
    String? trailingBadge,
    String? planFeature,
    required VoidCallback onTap,
    bool isDark = false,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBgColor ?? (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 18, color: iconColor ?? (isDark ? const Color(0xFF60A5FA) : const Color(0xFF0F172A))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: titleColor ?? (isDark ? Colors.white : const Color(0xFF0F172A)),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (planFeature != null) ...[
                        const SizedBox(width: 6),
                        PlanCrownBadge(feature: planFeature, size: 12),
                      ],
                    ],
                  ),
                  if (subtitle != null && subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (trailingBadge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF14532D).withValues(alpha: 0.4) : const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: isDark ? const Color(0xFF15803D) : const Color(0xFFBBF7D0)),
                ),
                child: Text(
                  trailingBadge,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A),
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }
}
