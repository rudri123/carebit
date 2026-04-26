import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'community_service.dart';
import 'dashboard_screen.dart';

// ── Dummy contact model ──
class _Contact {
  final String name;
  final String role;
  final String phone;
  final String emoji;
  bool selected = false;

  _Contact({
    required this.name,
    required this.role,
    required this.phone,
    required this.emoji,
  });
}

class _InviteFormResult {
  const _InviteFormResult({required this.email, this.groupId});

  final String email;
  final String? groupId;
}

class ContactSyncScreen extends StatefulWidget {
  final List<Map<String, dynamic>> existingFamilyMembers;

  const ContactSyncScreen({super.key, this.existingFamilyMembers = const []});

  @override
  State<ContactSyncScreen> createState() => _ContactSyncScreenState();
}

class _ContactSyncScreenState extends State<ContactSyncScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<CommunityGroupOption> _communityGroups = const [];
  bool _loadingCommunityGroups = true;
  bool _sendingInvite = false;

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
  void initState() {
    super.initState();

    // Pre-select already added members
    final existingNames = widget.existingFamilyMembers
        .map((m) => (m['name'] as String).toLowerCase().trim())
        .toSet();

    for (final contact in _contacts) {
      if (existingNames.contains(contact.name.toLowerCase().trim())) {
        contact.selected = true;
      }
    }

    _loadCommunityGroups();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCommunityGroups() async {
    try {
      final groups = await CommunityService.instance.fetchCurrentUserGroups();
      if (!mounted) return;
      setState(() {
        _communityGroups = groups;
        _loadingCommunityGroups = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _communityGroups = const [];
        _loadingCommunityGroups = false;
      });
    }
  }

  List<Map<String, dynamic>> _buildSelectedFamilyMembers() {
    final selectedContacts = _contacts.where((c) => c.selected).toList();

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

  Future<void> _saveFamilyMembers(List<Map<String, dynamic>> members) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('family_members', jsonEncode(members));
  }

  Future<void> _goToDashboardWithSelectedMembers() async {
    final selectedMembers = _buildSelectedFamilyMembers();

    // Save to SharedPreferences
    await _saveFamilyMembers(selectedMembers);

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => DashboardScreen(initialFamilyMembers: selectedMembers),
      ),
      (route) => false,
    );
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return emailRegex.hasMatch(email);
  }

  Future<void> _showInviteByEmailDialog() async {
    if (_sendingInvite) return;
    if (_loadingCommunityGroups) {
      await _loadCommunityGroups();
    }
    if (!mounted) return;

    final emailController = TextEditingController();
    String? selectedGroupId = _communityGroups.length == 1
        ? _communityGroups.first.id
        : null;

    final result = await showDialog<_InviteFormResult>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final needsGroupSelection = _communityGroups.length > 1;

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'Invite by Email',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E1B4B),
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Enter email address',
                        filled: true,
                        fillColor: const Color(0xFFF8F7FE),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFFE7E7EF),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFFE7E7EF),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFF4338CA),
                            width: 1.5,
                          ),
                        ),
                        prefixIcon: const Icon(
                          Icons.email_outlined,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_loadingCommunityGroups)
                      const Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Loading your community groups…',
                              style: TextStyle(
                                fontFamily: 'DM Sans',
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (!_loadingCommunityGroups && _communityGroups.isEmpty)
                      const Text(
                        'Your first community group will be created automatically when this invite is sent.',
                        style: TextStyle(
                          fontFamily: 'DM Sans',
                          fontSize: 12,
                          height: 1.5,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    if (!_loadingCommunityGroups &&
                        _communityGroups.length == 1)
                      Text(
                        'Invite will be sent to ${_communityGroups.first.name}.',
                        style: const TextStyle(
                          fontFamily: 'DM Sans',
                          fontSize: 12,
                          height: 1.5,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    if (!_loadingCommunityGroups && needsGroupSelection)
                      DropdownButtonFormField<String>(
                        initialValue: selectedGroupId,
                        decoration: InputDecoration(
                          labelText: 'Choose a community group',
                          filled: true,
                          fillColor: const Color(0xFFF8F7FE),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFFE7E7EF),
                            ),
                          ),
                        ),
                        items: _communityGroups
                            .map(
                              (group) => DropdownMenuItem<String>(
                                value: group.id,
                                child: Text(group.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedGroupId = value;
                          });
                        },
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed:
                      _loadingCommunityGroups ||
                          (needsGroupSelection && selectedGroupId == null)
                      ? null
                      : () {
                          Navigator.pop(
                            context,
                            _InviteFormResult(
                              email: emailController.text.trim(),
                              groupId: selectedGroupId,
                            ),
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4338CA),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Send Invite',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    emailController.dispose();

    if (!mounted || result == null || result.email.isEmpty) return;

    if (!_isValidEmail(result.email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a valid email address'),
          backgroundColor: Colors.red[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    setState(() {
      _sendingInvite = true;
    });

    try {
      await CommunityService.instance.createInvite(
        email: result.email,
        groupId: result.groupId,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invitation sent to ${result.email}'),
          backgroundColor: Colors.green[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } on CommunityServiceException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: Colors.red[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _sendingInvite = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasExistingMembers = widget.existingFamilyMembers.isNotEmpty;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(-0.5, -1),
            end: Alignment(0.5, 1),
            colors: [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF312E81)],
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
                  hasExistingMembers ? 'MANAGE FAMILY GROUP' : 'STEP 1 OF 2',
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

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Row(
                  children: [
                    Text(
                      hasExistingMembers
                          ? 'Manage Family Members'
                          : 'Sync Your Contacts',
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w900,
                        fontSize: 24,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('📱', style: TextStyle(fontSize: 22)),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Text(
                  hasExistingMembers
                      ? 'Select or unselect family members to update your group'
                      : 'Select family members to add to your group or invite by email',
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
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF4338CA,
                                ).withOpacity(0.04),
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
                      const SizedBox(height: 14),

                      // ── Invite by Email Card ──
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: GestureDetector(
                          onTap: _showInviteByEmailDialog,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFEEF2FF), Color(0xFFF5F3FF)],
                              ),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: const Color(
                                  0xFF4338CA,
                                ).withOpacity(0.12),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF4338CA,
                                  ).withOpacity(0.05),
                                  blurRadius: 12,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF4338CA,
                                    ).withOpacity(0.10),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(
                                    Icons.email_outlined,
                                    color: Color(0xFF4338CA),
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Invite by Email',
                                        style: TextStyle(
                                          fontFamily: 'Nunito',
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                          color: Color(0xFF1E1B4B),
                                        ),
                                      ),
                                      SizedBox(height: 3),
                                      Text(
                                        'Send an invite link to family members not in contacts',
                                        style: TextStyle(
                                          fontFamily: 'DM Sans',
                                          fontSize: 12,
                                          color: Color(0xFF6B7280),
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 16,
                                  color: Color(0xFF4338CA),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

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
                                color: const Color(
                                  0xFF10B981,
                                ).withOpacity(0.12),
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
                            onPressed: _goToDashboardWithSelectedMembers,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEF4444),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              hasExistingMembers
                                  ? 'Save Changes ($_selectedCount)'
                                  : 'Continue ($_selectedCount)',
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
    return GestureDetector(
      onTap: () => setState(() => contact.selected = !contact.selected),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: contact.selected
              ? const Color(0xFF4338CA).withOpacity(0.06)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: contact.selected
              ? Border.all(color: const Color(0xFF4338CA).withOpacity(0.15))
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: contact.selected
                    ? const Color(0xFF4338CA).withOpacity(0.12)
                    : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(23),
                border: contact.selected
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
                      color: contact.selected
                          ? const Color(0xFF1E1B4B)
                          : const Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    contact.role,
                    style: TextStyle(
                      fontFamily: 'DM Sans',
                      fontSize: 11.5,
                      color: Colors.grey[500],
                    ),
                  ),
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
                color: contact.selected
                    ? const Color(0xFF4338CA)
                    : Colors.transparent,
                border: Border.all(
                  color: contact.selected
                      ? const Color(0xFF4338CA)
                      : const Color(0xFFD1D5DB),
                  width: 2,
                ),
              ),
              child: contact.selected
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
