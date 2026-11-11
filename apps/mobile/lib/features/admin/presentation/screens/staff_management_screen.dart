import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/core/theme/app_theme.dart';
import 'package:salesarmy/features/admin/data/models/staff_model.dart';

class StaffManagementScreen extends StatefulWidget {
  const StaffManagementScreen({super.key});

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  void _openAddOrEditStaffDialog({StaffModel? existingStaff}) {
    showDialog(
      context: context,
      builder: (ctx) => _StaffEditDialog(
        existingStaff: existingStaff,
        onSave: (staff) {
          final appState = Provider.of<AppState>(context, listen: false);
          if (existingStaff != null) {
            appState.updateStaff(staff);
          } else {
            appState.addStaff(staff);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final staffList = appState.staffList;
    final activeStaff = appState.activeStaffUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Staff & Role Permissions',
          style: TextStyle(
            fontSize: 17,
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
              Icons.person_add_alt_1_rounded,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              size: 22,
            ),
            onPressed: () => _openAddOrEditStaffDialog(),
            tooltip: 'Add Staff Member',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Active Operating Identity Banner (Simulate role)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: isDark ? 0.2 : 0.03),
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
                      Text(
                        'CURRENT OPERATOR ROLE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          letterSpacing: 0.6,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.yellowPrimary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          appState.activeRole.toUpperCase(),
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    activeStaff != null
                        ? 'Operating as: ${activeStaff.name} (${activeStaff.role})'
                        : 'Operating as Primary Agency Owner (Full Access)',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Staff members operate with role-based module permissions.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  if (activeStaff != null) ...[
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        appState.setActiveStaffUser(null); // Switch back to Owner
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.restart_alt_rounded, size: 14, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                            const SizedBox(width: 4),
                            Text(
                              'Switch Back to Owner Mode',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'STAFF MEMBERS (${staffList.length})',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _openAddOrEditStaffDialog(),
                  icon: Icon(
                    Icons.add_circle_outline_rounded,
                    size: 16,
                    color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                  ),
                  label: Text(
                    'Add Staff',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Staff Cards List
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: staffList.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (ctx, idx) {
                final staff = staffList[idx];
                final isCurrent = activeStaff?.id == staff.id;

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isCurrent
                          ? (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7))
                          : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      width: isCurrent ? 1.5 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: isDark ? 0.2 : 0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: _getRoleBg(staff.role, isDark),
                              shape: BoxShape.circle,
                              border: Border.all(color: _getRoleBorder(staff.role, isDark)),
                            ),
                            alignment: Alignment.center,
                            child: Icon(_getRoleIcon(staff.role), color: _getRoleColor(staff.role, isDark), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      staff.name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _getRoleBg(staff.role, isDark),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        staff.role,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: _getRoleColor(staff.role, isDark),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${staff.mobile} • ${staff.email}',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.edit_outlined,
                              size: 18,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                            tooltip: 'Edit Staff',
                            onPressed: () => _openAddOrEditStaffDialog(existingStaff: staff),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                              color: Color(0xFFDC2626),
                            ),
                            tooltip: 'Delete Staff',
                            onPressed: () => _confirmDeleteStaff(context, staff),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                      const SizedBox(height: 10),

                      // Permissions summary pills
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _permBadge('Billing', staff.permissions.billing, isDark),
                          _permBadge('Orders', staff.permissions.orders, isDark),
                          _permBadge('Inventory', staff.permissions.inventory, isDark),
                          _permBadge('Reports', staff.permissions.reports, isDark),
                          _permBadge('Accounts', staff.permissions.accounts, isDark),
                          _permBadge('Purchase', staff.permissions.purchase, isDark),
                          _permBadge('Expense', staff.permissions.expense, isDark),
                          _permBadge('Staff', staff.permissions.staff, isDark),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteStaff(BuildContext context, StaffModel staff) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Staff Member?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        content: Text('Are you sure you want to delete "${staff.name}" (${staff.role})? Their access credentials will be revoked.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<AppState>().deleteStaff(staff.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Staff member "${staff.name}" deleted.'),
                    backgroundColor: const Color(0xFFDC2626),
                  ),
                );
              }
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

  Widget _permBadge(String label, bool isEnabled, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isEnabled
            ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFF0FDF4))
            : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isEnabled
              ? (isDark ? const Color(0xFF059669) : const Color(0xFFBBF7D0))
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: isEnabled ? FontWeight.w800 : FontWeight.w500,
          color: isEnabled
              ? (isDark ? const Color(0xFF4ADE80) : const Color(0xFF166534))
              : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
        ),
      ),
    );
  }

  Color _getRoleColor(String role, bool isDark) {
    switch (role.toLowerCase()) {
      case 'owner':
        return isDark ? const Color(0xFFFBBF24) : const Color(0xFF0F172A);
      case 'accountant':
        return isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8);
      case 'delivery staff':
        return isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
      case 'field sales':
        return isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A);
      default:
        return isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    }
  }

  Color _getRoleBg(String role, bool isDark) {
    switch (role.toLowerCase()) {
      case 'owner':
        return isDark ? const Color(0xFF78350F).withValues(alpha: 0.4) : const Color(0xFFFFFBEB);
      case 'accountant':
        return isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : const Color(0xFFEFF6FF);
      case 'delivery staff':
        return isDark ? const Color(0xFF78350F).withValues(alpha: 0.4) : const Color(0xFFFFFBEB);
      case 'field sales':
        return isDark ? const Color(0xFF064E3B).withValues(alpha: 0.4) : const Color(0xFFF0FDF4);
      default:
        return isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    }
  }

  Color _getRoleBorder(String role, bool isDark) {
    switch (role.toLowerCase()) {
      case 'owner':
        return isDark ? const Color(0xFFB45309) : const Color(0xFFFEF08A);
      case 'accountant':
        return isDark ? const Color(0xFF3B82F6) : const Color(0xFFBFDBFE);
      case 'delivery staff':
        return isDark ? const Color(0xFFD97706) : const Color(0xFFFDE68A);
      case 'field sales':
        return isDark ? const Color(0xFF059669) : const Color(0xFFBBF7D0);
      default:
        return isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return Icons.shield_rounded;
      case 'accountant':
        return Icons.account_balance_rounded;
      case 'delivery staff':
        return Icons.delivery_dining_rounded;
      case 'field sales':
        return Icons.person_pin_circle_rounded;
      default:
        return Icons.person_rounded;
    }
  }
}

class _StaffEditDialog extends StatefulWidget {
  final StaffModel? existingStaff;
  final Function(StaffModel) onSave;

  const _StaffEditDialog({this.existingStaff, required this.onSave});

  @override
  State<_StaffEditDialog> createState() => _StaffEditDialogState();
}

class _StaffEditDialogState extends State<_StaffEditDialog> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _mobileController;
  late String _role;
  late StaffPermissions _perms;

  final roles = ['Owner', 'Accountant', 'Delivery Staff', 'Field Sales', 'Store Manager'];

  @override
  void initState() {
    super.initState();
    final s = widget.existingStaff;
    _nameController = TextEditingController(text: s?.name ?? '');
    _emailController = TextEditingController(text: s?.email ?? '');
    _mobileController = TextEditingController(text: s?.mobile ?? '');
    _role = s?.role ?? 'Field Sales';
    _perms = s?.permissions ?? StaffPermissions.fieldSales();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  void _applyRolePreset(String role) {
    setState(() {
      _role = role;
      switch (role.toLowerCase()) {
        case 'owner':
          _perms = StaffPermissions.owner();
          break;
        case 'accountant':
          _perms = StaffPermissions.accountant();
          break;
        case 'delivery staff':
          _perms = StaffPermissions.delivery();
          break;
        case 'field sales':
          _perms = StaffPermissions.fieldSales();
          break;
        default:
          _perms = const StaffPermissions();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    InputDecoration inputDec(String label) {
      return InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        filled: true,
        fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0F172A), width: 1.5),
        ),
      );
    }

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        widget.existingStaff != null ? 'Edit Staff Member' : 'Add Staff Member',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 16,
          color: isDark ? Colors.white : const Color(0xFF0F172A),
        ),
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                decoration: inputDec('Staff Name *'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _emailController,
                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                decoration: inputDec('Email Address'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _mobileController,
                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                decoration: inputDec('Mobile Number'),
              ),
              const SizedBox(height: 14),

              // Role selector
              Text(
                'Assigned Role',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _role,
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                items: roles
                    .map((r) => DropdownMenuItem(
                          value: r,
                          child: Text(r, style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A))),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) _applyRolePreset(val);
                },
                decoration: inputDec('Role'),
              ),
              const SizedBox(height: 14),

              // Module Permissions
              Text(
                'Module-Level Permissions',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              _buildPermSwitch('Billing & Invoicing', _perms.billing, (v) => setState(() => _perms = _perms.copyWith(billing: v)), isDark),
              _buildPermSwitch('Orders & Sales', _perms.orders, (v) => setState(() => _perms = _perms.copyWith(orders: v)), isDark),
              _buildPermSwitch('Products & Inventory', _perms.inventory, (v) => setState(() => _perms = _perms.copyWith(inventory: v)), isDark),
              _buildPermSwitch('Reports & Downloads', _perms.reports, (v) => setState(() => _perms = _perms.copyWith(reports: v)), isDark),
              _buildPermSwitch('Accounts & Banking', _perms.accounts, (v) => setState(() => _perms = _perms.copyWith(accounts: v)), isDark),
              _buildPermSwitch('Purchases (Goods In)', _perms.purchase, (v) => setState(() => _perms = _perms.copyWith(purchase: v)), isDark),
              _buildPermSwitch('Expenses (Cash Out)', _perms.expense, (v) => setState(() => _perms = _perms.copyWith(expense: v)), isDark),
              _buildPermSwitch('Staff Management', _perms.staff, (v) => setState(() => _perms = _perms.copyWith(staff: v)), isDark),
              _buildPermSwitch('Settings & Printer', _perms.settings, (v) => setState(() => _perms = _perms.copyWith(settings: v)), isDark),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
        ),
        ElevatedButton(
          onPressed: () {
            if (_nameController.text.trim().isEmpty) return;
            final staff = StaffModel(
              id: widget.existingStaff?.id ?? 'staff_${DateTime.now().millisecondsSinceEpoch}',
              name: _nameController.text.trim(),
              email: _emailController.text.trim(),
              mobile: _mobileController.text.trim(),
              role: _role,
              permissions: _perms,
              createdAt: widget.existingStaff?.createdAt ?? DateTime.now(),
            );
            widget.onSave(staff);
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Save Staff', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
        ),
      ],
    );
  }

  Widget _buildPermSwitch(String title, bool val, Function(bool) onChanged, bool isDark) {
    return SwitchListTile(
      value: val,
      onChanged: onChanged,
      title: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : const Color(0xFF0F172A),
        ),
      ),
      dense: true,
      contentPadding: EdgeInsets.zero,
      activeThumbColor: AppTheme.yellowPrimary,
    );
  }
}
