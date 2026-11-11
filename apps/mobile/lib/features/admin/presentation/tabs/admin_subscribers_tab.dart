import 'package:flutter/material.dart';

class AdminSubscribersTab extends StatefulWidget {
  final List<Map<String, dynamic>> subscribers;
  final Function(Map<String, dynamic>) onSelectSubscriber;

  const AdminSubscribersTab({
    super.key,
    required this.subscribers,
    required this.onSelectSubscriber,
  });

  @override
  State<AdminSubscribersTab> createState() => _AdminSubscribersTabState();
}

class _AdminSubscribersTabState extends State<AdminSubscribersTab> {
  final _searchCtrl = TextEditingController();
  String _selectedStatusFilter = 'ALL';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.subscribers.where((s) {
      if (_selectedStatusFilter != 'ALL' && s['status'] != _selectedStatusFilter) {
        return false;
      }
      final query = _searchCtrl.text.toLowerCase().trim();
      if (query.isEmpty) return true;
      return (s['name'] ?? '').toString().toLowerCase().contains(query) ||
          (s['firm'] ?? '').toString().toLowerCase().contains(query) ||
          (s['phone'] ?? '').toString().toLowerCase().contains(query) ||
          (s['id'] ?? '').toString().toLowerCase().contains(query) ||
          (s['gstin'] ?? '').toString().toLowerCase().contains(query);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Search Input Box (Screenshot 2)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Search by Subscriber ID, Name, Business,',
                    hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                    prefixIcon: Icon(Icons.search, color: Color(0xFF1D4ED8), size: 22),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Horizontal Status Filter Pills (Screenshot 2)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterPill('All', 'ALL'),
                    const SizedBox(width: 8),
                    _filterPill('Active', 'ACTIVE'),
                    const SizedBox(width: 8),
                    _filterPill('Pending', 'PENDING'),
                    const SizedBox(width: 8),
                    _filterPill('Paused', 'PAUSED'),
                    const SizedBox(width: 8),
                    _filterPill('Cancelled', 'CANCELLED'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Subheader Row: Found X Subscribers & Tap user card (Screenshot 2)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Found ${filtered.length} Subscribers',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF0F172A)),
                  ),
                  const Text(
                    'Tap user card for details & actions',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Subscriber List Cards
              if (filtered.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  alignment: Alignment.center,
                  child: const Text('No subscribers match your search filter.', style: TextStyle(color: Color(0xFF94A3B8))),
                )
              else
                ...filtered.map((sub) => _buildSubscriberCard(sub)),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterPill(String label, String value) {
    final isSelected = _selectedStatusFilter == value;
    return InkWell(
      key: ValueKey('filter_pill_${value.toLowerCase()}'),
      onTap: () => setState(() => _selectedStatusFilter = value),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFF475569),
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }

  Widget _buildSubscriberCard(Map<String, dynamic> sub) {
    Color badgeBg;
    Color badgeText;
    switch (sub['status']) {
      case 'ACTIVE':
        badgeBg = const Color(0xFFDCFCE7);
        badgeText = const Color(0xFF15803D);
        break;
      case 'PENDING':
        badgeBg = const Color(0xFFFEF3C7);
        badgeText = const Color(0xFFD97706);
        break;
      case 'CANCELLED':
        badgeBg = const Color(0xFFFEE2E2);
        badgeText = const Color(0xFFDC2626);
        break;
      default:
        badgeBg = const Color(0xFFF1F5F9);
        badgeText = const Color(0xFF64748B);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => widget.onSelectSubscriber(sub),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top line: SUB ID + Name + Status Badge
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        (sub['id'] ?? '').toString(),
                        style: const TextStyle(
                          color: Color(0xFF1D4ED8),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        (sub['name'] ?? '').toString(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        (sub['status'] ?? '').toString(),
                        style: TextStyle(
                          color: badgeText,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Middle line: Firm Trade Name + Phone ... / Amount
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${sub['firm'] ?? ''} • ${sub['phone'] ?? ''}',
                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      (sub['amount'] ?? '').toString(),
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: sub['amount'] == 'Free / Unpaid' ? const Color(0xFF64748B) : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Bottom line: Plan ... / Printer Badge / Days Left
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            (sub['plan'] ?? '').toString(),
                            style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                          ),
                          if (sub['hasPrinter'] == true)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFBBF7D0)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.print_rounded, size: 12, color: Color(0xFF16A34A)),
                                  SizedBox(width: 4),
                                  Text(
                                    'Printer Ordered',
                                    style: TextStyle(
                                      color: Color(0xFF16A34A),
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      (sub['daysLeft'] ?? '').toString(),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
