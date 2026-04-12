import 'package:flutter/material.dart';
import 'dashboard_screen.dart';

// ── Dummy contact model ──
class _Contact {
  final String name;
  final String role;
  final String phone;
  final String emoji;
  bool selected;

  _Contact({
    required this.name,
    required this.role,
    required this.phone,
    required this.emoji,
    this.selected = false,
  });
}

class ContactSyncScreen extends StatefulWidget {
  final List<Map<String, dynamic>> existingFamilyMembers;

  const ContactSyncScreen({
    super.key,
    this.existingFamilyMembers = const [],
  });

  @override
  State<ContactSyncScreen> createState() => _ContactSyncScreenState();
}

class _ContactSyncScreenState extends State<ContactSyncScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final List<_Contact> _contacts = [
    _Contact(
      name: 'Mom',
      role: 'Mother',
      phone: '+1(555) 123-4567',
      emoji: '👩',
    ),
    _Contact(
      name: 'Dad',
      role: 'Father',
      phone: '+1(555) 123-4568',
      emoji: '👨',
    ),
    _Contact(
      name: 'Sarah (Sister)',
      role: 'Sister',
      phone: '+1(555) 123-4569',
      emoji: '👧',
    ),
    _Contact(
      name: 'Grandma',
      role: 'Grandmother',
      phone: '+1(555) 123-4570',
      emoji: '👵',
    ),
  ];

  List<_Contact> get _filteredContacts {
    if (_searchQuery.isEmpty) return _contacts;
    return _contacts
        .where(
          (c) =>
              c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              c.role.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              c.phone.contains(_searchQuery),
        )
        .toList();
  }

  int get _selectedCount => _contacts.where((c) => c.selected).length;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isAlreadyAdded(_Contact contact) {
    final existingNames = widget.existingFamilyMembers
        .map((m) => (m['name'] as String).toLowerCase().trim())
        .toSet();

    return existingNames.contains(contact.name.toLowerCase().trim());
  }

  List<Map<String, dynamic>> _buildSelectedFamilyMembers() {
    final selectedContacts = _contacts
        .where((c) => c.selected && !_isAlreadyAdded(c))
        .toList();

    final colors = [
      0xFF3B82F6,
      0xFFEF4444,
      0xFF10B981,
      0xFFF59E0B,
      0xFF8B5CF6,
      0xFFEC4899,
    ];

    return List.generate(selectedContacts.length, (index) {
      final contact = selectedContacts[index];

      return {
        'name': contact.name,
        'emoji': contact.emoji,
        'color': colors[index % colors.length],
        'battery': '${80 - (index * 5)}%',
        'restingHr': '${68 + index} bpm',
        'spo2': '${98 - (index % 2)}%',
        'bmr': '${1450 + (index * 80)} kcal',
        'steps': '${6500 + (index * 450)}',
        'sleep': '${7 + (index % 2)}h ${10 + (index * 5)}m',
      };
    });
  }

  List<Map<String, dynamic>> _mergeMembersWithoutDuplicates(
    List<Map<String, dynamic>> existing,
    List<Map<String, dynamic>> selected,
  ) {
    final Map<String, Map<String, dynamic>> merged = {};

    // Keep existing members first
    for (final member in existing) {
      final name = (member['name'] as String).toLowerCase().trim();
      merged[name] = Map<String, dynamic>.from(member);
    }

    // Add only new selected members
    for (final member in selected) {
      final name = (member['name'] as String).toLowerCase().trim();
      if (!merged.containsKey(name)) {
        merged[name] = Map<String, dynamic>.from(member);
      }
    }

    return merged.values.toList();
  }

  void _goToDashboardWithMergedMembers() {
    final selectedMembers = _buildSelectedFamilyMembers();

    final mergedMembers = _mergeMembersWithoutDuplicates(
      widget.existingFamilyMembers,
      selectedMembers,
    );

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => DashboardScreen(
          initialFamilyMembers: mergedMembers,
        ),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(-0.5, -1),
            end: Alignment(0.5, 1),
            colors: [
              Color(0xFF0F172A),
              Color(0xFF1E1B4B),
              Color(0xFF312E81),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.15),
                          ),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Text(
                  'STEP 1 OF 2',
                  style: TextStyle(
                    fontFamily: 'DM Sans',
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                    letterSpacing: 2,
                    color: Colors.white.withOpacity(0.4),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 28),
                child: Row(
                  children: [
                    Text(
                      'Sync Your Contacts',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w900,
                        fontSize: 24,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text('📱', style: TextStyle(fontSize: 22)),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Text(
                  'Select family members to add to your group',
                  style: TextStyle(
                    fontFamily: 'DM Sans',
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8F7FF),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(28),
                      topRight: Radius.circular(28),
                    ),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFFE5E7EB),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF4338CA).withOpacity(0.04),
                                blurRadius: 12,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (v) => setState(() => _searchQuery = v),
                            style: const TextStyle(
                              fontFamily: 'DM Sans',
                              fontSize: 14,
                              color: Color(0xFF1E1B4B),
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Search contacts...',
                              hintStyle: TextStyle(
                                fontFamily: 'DM Sans',
                                fontSize: 14,
                                color: Color(0xFF9CA3AF),
                              ),
                              prefixIcon: Icon(
                                Icons.search,
                                color: Color(0xFF9CA3AF),
                                size: 20,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (_selectedCount > 0)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '● $_selectedCount selected',
                                style: const TextStyle(
                                  fontFamily: 'DM Sans',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (_selectedCount > 0) const SizedBox(height: 8),

                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _filteredContacts.length,
                          itemBuilder: (context, index) {
                            final contact = _filteredContacts[index];
                            return _contactTile(contact);
                          },
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                        child: SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _selectedCount > 0
                                ? _goToDashboardWithMergedMembers
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _selectedCount > 0
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFFE5E7EB),
                              foregroundColor: _selectedCount > 0
                                  ? Colors.white
                                  : const Color(0xFF9CA3AF),
                              elevation: 0,
                              disabledBackgroundColor:
                                  const Color(0xFFE5E7EB),
                              disabledForegroundColor:
                                  const Color(0xFF9CA3AF),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              'Continue ($_selectedCount)',
                              style: const TextStyle(
                                fontFamily: 'Nunito',
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
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

  Widget _contactTile(_Contact contact) {
    final alreadyAdded = _isAlreadyAdded(contact);

    return GestureDetector(
      onTap: alreadyAdded
          ? null
          : () => setState(() => contact.selected = !contact.selected),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: alreadyAdded
              ? const Color(0xFFECFDF5)
              : contact.selected
                  ? const Color(0xFF4338CA).withOpacity(0.06)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: alreadyAdded
              ? Border.all(color: const Color(0xFF10B981).withOpacity(0.25))
              : contact.selected
                  ? Border.all(
                      color: const Color(0xFF4338CA).withOpacity(0.15),
                    )
                  : null,
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: alreadyAdded
                    ? const Color(0xFF10B981).withOpacity(0.10)
                    : contact.selected
                        ? const Color(0xFF4338CA).withOpacity(0.12)
                        : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(23),
                border: alreadyAdded
                    ? Border.all(
                        color: const Color(0xFF10B981).withOpacity(0.3),
                        width: 2,
                      )
                    : contact.selected
                        ? Border.all(
                            color: const Color(0xFF4338CA).withOpacity(0.3),
                            width: 2,
                          )
                        : null,
              ),
              child: Center(
                child: Text(
                  contact.emoji,
                  style: const TextStyle(fontSize: 22),
                ),
              ),
            ),
            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.name,
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: alreadyAdded
                          ? const Color(0xFF065F46)
                          : contact.selected
                              ? const Color(0xFF1E1B4B)
                              : const Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    alreadyAdded ? 'Already added' : contact.role,
                    style: TextStyle(
                      fontFamily: 'DM Sans',
                      fontSize: 11.5,
                      color: alreadyAdded
                          ? const Color(0xFF10B981)
                          : Colors.grey[500],
                    ),
                  ),
                  if (!alreadyAdded)
                    Text(
                      contact.phone,
                      style: TextStyle(
                        fontFamily: 'DM Sans',
                        fontSize: 11,
                        color: Colors.grey[400],
                      ),
                    ),
                ],
              ),
            ),

            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: alreadyAdded
                    ? const Color(0xFF10B981)
                    : contact.selected
                        ? const Color(0xFF4338CA)
                        : Colors.transparent,
                border: Border.all(
                  color: alreadyAdded
                      ? const Color(0xFF10B981)
                      : contact.selected
                          ? const Color(0xFF4338CA)
                          : const Color(0xFFD1D5DB),
                  width: 2,
                ),
              ),
              child: alreadyAdded
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : contact.selected
                      ? const Icon(Icons.check, color: Colors.white, size: 16)
                      : null,
            ),
          ],
        ),
      ),
    );
  }
}