import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'profile_screen.dart';
import 'health_report_screen.dart';
import 'community_intro_screen.dart';
import 'contact_sync_screen.dart';
import 'community_service.dart';
import 'device_connect_screen.dart';
import 'fitbit_metrics.dart';
import 'fitbit_service.dart';
import 'alerts_screen.dart';

class DashboardScreen extends StatefulWidget {
  final List<Map<String, dynamic>> initialFamilyMembers;

  const DashboardScreen({super.key, this.initialFamilyMembers = const []});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  List<Map<String, dynamic>> _familyMembers = [];
  bool _isLoadingMembers = true;

  @override
  void initState() {
    super.initState();
    _loadFamilyMembers();
  }

  Future<void> _loadFamilyMembers() async {
    final prefs = await SharedPreferences.getInstance();

    // If members were passed from contact sync, use those first and save them
    if (widget.initialFamilyMembers.isNotEmpty) {
      _familyMembers = List<Map<String, dynamic>>.from(
        widget.initialFamilyMembers,
      );
      await _saveFamilyMembers(_familyMembers);
    } else {
      // Otherwise load saved members from local storage
      final savedMembersString = prefs.getString('family_members');
      if (savedMembersString != null) {
        final decoded = jsonDecode(savedMembersString) as List<dynamic>;
        _familyMembers = decoded
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      }
    }

    if (mounted) {
      setState(() {
        _isLoadingMembers = false;
      });
    }
  }

  Future<void> _saveFamilyMembers(List<Map<String, dynamic>> members) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(members);
    await prefs.setString('family_members', encoded);
  }

  Future<void> _updateFamilyMembers(
    List<Map<String, dynamic>> updatedMembers,
  ) async {
    setState(() {
      _familyMembers = List<Map<String, dynamic>>.from(updatedMembers);
    });

    await _saveFamilyMembers(_familyMembers);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingMembers) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final pages = [
      _HomeTab(
        familyMembers: _familyMembers,
        onMembersUpdated: (updatedMembers) async {
          await _updateFamilyMembers(updatedMembers);
        },
      ),
      const HealthReportScreen(),
      const _PlaceholderTab('Community', '💜'),
      const AlertsScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4338CA).withOpacity(0.10),
              blurRadius: 18,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(0, Icons.home_rounded, 'Home'),
            _navItem(1, Icons.favorite_rounded, 'Health'),
            _navFab(),
            _navItem(3, Icons.notifications_rounded, 'Alerts'),
            _navItem(4, Icons.person_rounded, 'Profile'),
          ],
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final bool active = _currentIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 26,
              color: active ? const Color(0xFF4338CA) : Colors.black87,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'DM Sans',
                fontWeight: FontWeight.w700,
                fontSize: 10,
                color: active
                    ? const Color(0xFF4338CA)
                    : const Color(0xFF8E8CA8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navFab() {
    return GestureDetector(
      onTap: () {
        if (_familyMembers.isEmpty) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CommunityIntroScreen()),
          );
        } else {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  ContactSyncScreen(existingFamilyMembers: _familyMembers),
            ),
          );
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF1D4ED8),
                  Color(0xFF4338CA),
                  Color(0xFF7C3AED),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4338CA).withOpacity(0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.favorite_rounded, color: Colors.white, size: 24),
                  Positioned(
                    right: 7,
                    top: 9,
                    child: Icon(Icons.add, color: Colors.white, size: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Add',
            style: TextStyle(
              fontFamily: 'DM Sans',
              fontWeight: FontWeight.w700,
              fontSize: 10,
              color: Color(0xFF8E8CA8),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Home Tab — Community Dashboard ──
class _HomeTab extends StatefulWidget {
  final List<Map<String, dynamic>> familyMembers;
  final ValueChanged<List<Map<String, dynamic>>> onMembersUpdated;

  const _HomeTab({required this.familyMembers, required this.onMembersUpdated});

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  late List<Map<String, dynamic>> _familyMembers;
  List<FirebaseCommunityMember> _communityMembers = const [];
  bool _communityLoading = true;
  String? _communityError;

  // ── Community member health metrics ─────────────────────────────────────────
  Map<String, Map<String, dynamic>?> _communityMemberMetrics =
      {}; // uid -> metrics
  Map<String, bool> _communityMemberLoading = {}; // uid -> isLoading
  Map<String, String?> _communityMemberError = {}; // uid -> error message
  Map<String, DateTime> _communityMemberUpdated = {}; // uid -> lastUpdated
  String? _expandedCommunityMemberId; // track which member is expanded

  // ── Fitbit connection status ─────────────────────────────────────────────
  bool _fitbitChecking = true;
  bool _fitbitConnected = false;
  Map<String, dynamic>? _liveMetrics; // mini vitals when connected
  Timer? _fitbitStatusTimer;
  Timer? _communityRefreshTimer;

  @override
  void initState() {
    super.initState();
    _familyMembers = List<Map<String, dynamic>>.from(widget.familyMembers);
    _checkFitbitStatus();
    _refreshCommunityMembers();
    // Re-check every 10 minutes (avoiding rate limits)
    _fitbitStatusTimer = Timer.periodic(
      const Duration(minutes: 10),
      (_) => _checkFitbitStatus(),
    );
    _communityRefreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refreshCommunityMembers(),
    );
  }

  @override
  void dispose() {
    _fitbitStatusTimer?.cancel();
    _communityRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkFitbitStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() {
            _fitbitChecking = false;
          });
        }
        return;
      }
      final idToken = await user.getIdToken();
      if (idToken == null) {
        if (mounted) {
          setState(() {
            _fitbitChecking = false;
          });
        }
        return;
      }
      final metrics = await FitbitService.instance.fetchMyMetrics(
        idToken: idToken,
      );
      if (mounted) {
        setState(() {
          _fitbitConnected = true;
          _liveMetrics = metrics;
          _fitbitChecking = false;
        });
      }
    } on FitbitServiceException catch (e) {
      // 404 = no connection; other errors = treat as not connected
      if (mounted) {
        setState(() {
          _fitbitConnected =
              e.message.toLowerCase().contains('connect') == false &&
              !e.message.contains('No Fitbit connection');
          _fitbitChecking = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _fitbitChecking = false;
        });
      }
    }
  }

  Future<void> _refreshCommunityMembers() async {
    try {
      final members = await CommunityService.instance.loadCommunityMembers();
      if (!mounted) return;
      setState(() {
        _communityMembers = members;
        _communityLoading = false;
        _communityError = null;
      });
    } on CommunityServiceException catch (error) {
      if (!mounted) return;
      setState(() {
        _communityMembers = const [];
        _communityLoading = false;
        _communityError = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _communityMembers = const [];
        _communityLoading = false;
        _communityError = 'Could not load community members: $error';
      });
    }
  }

  @override
  void didUpdateWidget(covariant _HomeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.familyMembers != widget.familyMembers) {
      setState(() {
        _familyMembers = List<Map<String, dynamic>>.from(widget.familyMembers);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data ?? FirebaseAuth.instance.currentUser;
        final displayName =
            user?.displayName ?? user?.email?.split('@').first ?? 'User';
        final greeting = _getGreeting();

        return Scaffold(
          backgroundColor: const Color(0xFFF5F4FE),
          body: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context, displayName, greeting, user),
                  const SizedBox(height: 16),
                  _buildFitbitBanner(context),
                  const SizedBox(height: 8),
                  _buildCommunityCards(context),
                  const SizedBox(height: 24),
                  _buildUpcoming(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  // ── Community member health metrics helpers ──────────────────────────────────
  Future<void> _loadCommunityMemberMetrics(
    String memberUid,
    FirebaseCommunityMember member,
  ) async {
    if (!mounted) return;
    setState(() {
      _communityMemberLoading[memberUid] = true;
      _communityMemberError[memberUid] = null;
    });

    try {
      final metrics = await CommunityService.instance
          .fetchCommunityMemberMetrics(memberUid: memberUid);
      if (!mounted) return;
      setState(() {
        _communityMemberMetrics[memberUid] = metrics;
        _communityMemberLoading[memberUid] = false;
        _communityMemberUpdated[memberUid] = DateTime.now();
      });
    } on CommunityServiceException catch (error) {
      if (!mounted) return;
      setState(() {
        _communityMemberError[memberUid] = error.message;
        _communityMemberLoading[memberUid] = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _communityMemberError[memberUid] = 'Unexpected error: $error';
        _communityMemberLoading[memberUid] = false;
      });
    }
  }

  FitbitHeartRateReading _getHeartRateReading(String memberUid) {
    return readFitbitHeartRate(_communityMemberMetrics[memberUid]);
  }

  int? _getHeartRate(String memberUid) {
    return _getHeartRateReading(memberUid).value;
  }

  int? _getSpo2(String memberUid) {
    final metrics = _communityMemberMetrics[memberUid];
    final spo2 = metrics?['oxygenSaturation'];
    final value = (spo2 as Map<String, dynamic>?)?['value'];
    return value is num ? value.round() : null;
  }

  int? _getSleepMinutes(String memberUid) {
    final metrics = _communityMemberMetrics[memberUid];
    final sleep = metrics?['sleep'];
    final summary =
        (sleep as Map<String, dynamic>?)?['summary'] as Map<String, dynamic>?;
    final value = summary?['totalMinutesAsleep'];
    return value is num ? value.toInt() : null;
  }

  int? _getSteps(String memberUid) {
    final metrics = _communityMemberMetrics[memberUid];
    final activities = metrics?['activities'];
    final summary =
        (activities as Map<String, dynamic>?)?['summary']
            as Map<String, dynamic>?;
    final value = summary?['steps'];
    return value is num ? value.toInt() : null;
  }

  int? _getActiveMinutes(String memberUid) {
    final metrics = _communityMemberMetrics[memberUid];
    final activities = metrics?['activities'];
    final summary =
        (activities as Map<String, dynamic>?)?['summary']
            as Map<String, dynamic>?;
    final very = summary?['veryActiveMinutes'] as num? ?? 0;
    final fairly = summary?['fairlyActiveMinutes'] as num? ?? 0;
    final lightly = summary?['lightlyActiveMinutes'] as num? ?? 0;
    return (very + fairly + lightly).toInt();
  }

  int? _getBmr(String memberUid) {
    final metrics = _communityMemberMetrics[memberUid];
    final heartRate = metrics?['heartRate'] as Map<String, dynamic>?;
    final activities = heartRate?['activities-heart'] as List<dynamic>?;
    final today = activities?.isNotEmpty == true
        ? activities!.first as Map<String, dynamic>?
        : null;
    final zones =
        (today?['value'] as Map<String, dynamic>?)?['heartRateZones']
            as List<dynamic>?;
    final total = zones?.fold<double>(
      0,
      (sum, zone) =>
          sum +
          (((zone as Map<String, dynamic>?)?['caloriesOut'] as num?) ?? 0),
    );
    if (total == null || total <= 0) return null;
    return total.toInt();
  }

  int _getHealthScore(String memberUid) {
    var score = 50;
    final hr = _getHeartRate(memberUid);
    final spo2 = _getSpo2(memberUid);
    final sleep = _getSleepMinutes(memberUid);

    if (hr != null) {
      if (hr >= 60 && hr <= 100) {
        score += 20;
      } else if (hr < 60 || hr <= 110) {
        score += 10;
      }
    }
    if (spo2 != null) {
      if (spo2 >= 95) {
        score += 20;
      } else if (spo2 >= 90) {
        score += 10;
      }
    }
    if (sleep != null) {
      if (sleep >= 420) {
        score += 10;
      } else if (sleep >= 300) {
        score += 5;
      }
    }

    return score.clamp(0, 100);
  }

  String _getSleepLabel(String memberUid) {
    final minutes = _getSleepMinutes(memberUid);
    if (minutes == null) return '--';
    final hours = minutes ~/ 60;
    final remainder = minutes % 60;
    return '${hours}h ${remainder}m';
  }

  String _getUpdatedLabel(String memberUid) {
    final updated = _communityMemberUpdated[memberUid];
    if (updated == null) return '';
    final hour = updated.hour % 12 == 0 ? 12 : updated.hour % 12;
    final minute = updated.minute.toString().padLeft(2, '0');
    final period = updated.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  Future<void> _editMemberName(int index) async {
    final controller = TextEditingController(
      text: _familyMembers[index]['name'] as String,
    );

    final newName = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Edit Member Name',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E1B4B),
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Enter member name',
              filled: true,
              fillColor: const Color(0xFFF8F7FE),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE7E7EF)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE7E7EF)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFF4338CA),
                  width: 1.5,
                ),
              ),
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
              onPressed: () {
                Navigator.pop(context, controller.text.trim());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4338CA),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Save',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );

    if (newName != null && newName.isNotEmpty) {
      setState(() {
        _familyMembers[index]['name'] = newName;
      });

      widget.onMembersUpdated(List<Map<String, dynamic>>.from(_familyMembers));
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Member name updated'),
          backgroundColor: Colors.green[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Widget _buildHeader(
    BuildContext context,
    String displayName,
    String greeting,
    User? user,
  ) {
    final totalMembers = _familyMembers.length + _communityMembers.length;
    final activeMembers = _communityMembers.length;
    final now = DateTime.now();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final dateStr = '${months[now.month - 1]} ${now.day}, ${now.year}';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment(-0.7, -1),
          end: Alignment(0.7, 1),
          colors: [Color(0xFF1D4ED8), Color(0xFF4338CA), Color(0xFF7C3AED)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4338CA).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$greeting, $displayName 👋',
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Community health overview · $dateStr',
                      style: TextStyle(
                        fontFamily: 'DM Sans',
                        fontSize: 11.5,
                        color: Colors.white.withOpacity(0.55),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(21),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 2,
                  ),
                  image: user?.photoURL != null
                      ? DecorationImage(
                          image: NetworkImage(user!.photoURL!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: user?.photoURL == null
                    ? Center(
                        child: Text(
                          displayName.isNotEmpty
                              ? displayName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Row(
              children: [
                _statItem(totalMembers.toString(), 'MEMBERS'),
                _statDivider(),
                _statItem(activeMembers.toString(), 'LIVE'),
                _statDivider(),
                _statItem('0', 'ALERTS'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w900,
              fontSize: 20,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'DM Sans',
              fontWeight: FontWeight.w700,
              fontSize: 9,
              letterSpacing: 1,
              color: Colors.white.withOpacity(0.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statDivider() {
    return Container(
      width: 1,
      height: 30,
      color: Colors.white.withOpacity(0.12),
    );
  }

  Widget _buildCommunityCards(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '👥 Community Members',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w900,
              fontSize: 17,
              color: Color(0xFF1E1B4B),
            ),
          ),
          const SizedBox(height: 14),
          _buildRemoteMembersSection(context),
          const SizedBox(height: 18),
          _buildLocalPrototypeSection(context),
        ],
      ),
    );
  }

  Widget _buildRemoteMembersSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Community Group Members',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w900,
            fontSize: 15,
            color: Color(0xFF1E1B4B),
          ),
        ),
        const SizedBox(height: 10),
        if (_communityLoading)
          _messageCard(
            emoji: '⏳',
            title: 'Loading live community members',
            subtitle: 'Checking your Firebase-backed community groups.',
          ),
        if (!_communityLoading && _communityError != null)
          _messageCard(
            emoji: '⚠️',
            title: 'Could not load live community members',
            subtitle: _communityError!,
            trailing: TextButton(
              onPressed: _refreshCommunityMembers,
              child: const Text('Retry'),
            ),
          ),
        if (!_communityLoading &&
            _communityError == null &&
            _communityMembers.isEmpty)
          _messageCard(
            emoji: '🌐',
            title: 'No accepted community members yet',
            subtitle:
                'Accepted email invites will appear here with live Fitbit access.',
          ),
        ..._communityMembers.map((member) {
          final isLoading = _communityMemberLoading[member.uid] ?? false;
          final hasError = _communityMemberError[member.uid] != null;
          final metrics = _communityMemberMetrics[member.uid];

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4338CA).withOpacity(0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  onExpansionChanged: (expanded) {
                    if (expanded) {
                      setState(() {
                        _expandedCommunityMemberId = member.uid;
                      });
                      _loadCommunityMemberMetrics(member.uid, member);
                    } else {
                      setState(() {
                        _expandedCommunityMemberId = null;
                      });
                    }
                  },
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        member.displayName.isNotEmpty
                            ? member.displayName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          color: Color(0xFF4338CA),
                        ),
                      ),
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          member.displayName,
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: Color(0xFF1E1B4B),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Live group member',
                          style: TextStyle(
                            fontFamily: 'DM Sans',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF166534),
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 2),
                      Text(
                        member.groupNames.join(' · '),
                        style: const TextStyle(
                          fontFamily: 'DM Sans',
                          fontSize: 12,
                          color: Color(0xFF4338CA),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        member.email.isEmpty
                            ? 'Tap to view live Fitbit metrics'
                            : '${member.email} · Tap to view live Fitbit metrics',
                        style: const TextStyle(
                          fontFamily: 'DM Sans',
                          fontSize: 11.5,
                          color: Color(0xFF6B7280),
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                  children: [
                    if (isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: CircularProgressIndicator(
                          color: Color(0xFF4338CA),
                        ),
                      ),
                    if (!isLoading && hasError)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1F2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFFCA5A5).withOpacity(0.6),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _communityMemberError[member.uid]!,
                                style: const TextStyle(
                                  fontFamily: 'DM Sans',
                                  fontSize: 12.5,
                                  color: Color(0xFF991B1B),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: () => _loadCommunityMemberMetrics(
                                member.uid,
                                member,
                              ),
                              child: const Icon(
                                Icons.refresh_rounded,
                                color: Color(0xFF991B1B),
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (!isLoading && !hasError && metrics == null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F4FE),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Column(
                          children: [
                            Text('⌚', style: TextStyle(fontSize: 34)),
                            SizedBox(height: 12),
                            Text(
                              'No Fitbit connected yet',
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF1E1B4B),
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'This member has not shared Fitbit data yet.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'DM Sans',
                                fontSize: 12.5,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (!isLoading && !hasError && metrics != null) ...[
                      if (_communityMemberUpdated[member.uid] != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            'Updated ${_getUpdatedLabel(member.uid)}',
                            style: const TextStyle(
                              fontFamily: 'DM Sans',
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ),
                      _buildCommunityMemberVitalsGrid(member.uid),
                      const SizedBox(height: 14),
                      _buildCommunityMemberSummaryCards(member.uid),
                    ],
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildLocalPrototypeSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Family Members',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w900,
            fontSize: 15,
            color: Color(0xFF1E1B4B),
          ),
        ),
        const SizedBox(height: 10),
        if (_familyMembers.isEmpty)
          _messageCard(
            emoji: '👨‍👩‍👧',
            title: 'No local family members added yet',
            subtitle:
                'Tap the Add button below to keep using the local family-member prototype.',
          ),
        ..._familyMembers.asMap().entries.map((entry) {
          final index = entry.key;
          final member = entry.value;
          final memberColor = Color(member['color'] as int);

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4338CA).withOpacity(0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: memberColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: memberColor.withOpacity(0.35),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        member['emoji'] as String,
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          member['name'] as String,
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: Color(0xFF1E1B4B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Local prototype',
                          style: TextStyle(
                            fontFamily: 'DM Sans',
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => _editMemberName(index),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F3FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.edit_rounded,
                            size: 16,
                            color: Color(0xFF4338CA),
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: const Text(
                    'Prototype member metrics stored on this device',
                    style: TextStyle(
                      fontFamily: 'DM Sans',
                      fontSize: 11.5,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  children: [
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 2.4,
                      children: [
                        _metricCard('Battery', member['battery'] as String),
                        _metricCard(
                          'Resting HR',
                          member['restingHr'] as String,
                        ),
                        _metricCard('SpO2', member['spo2'] as String),
                        _metricCard('BMR', member['bmr'] as String),
                        _metricCard('Steps Today', member['steps'] as String),
                        _metricCard('Sleep', member['sleep'] as String),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _messageCard({
    required String emoji,
    required String title,
    required String subtitle,
    Widget? trailing,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4338CA).withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Color(0xFF1E1B4B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: 'DM Sans',
                    fontSize: 12.5,
                    color: Color(0xFF6B7280),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _metricCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F7FE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE9E7F7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'DM Sans',
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w900,
              fontSize: 13,
              color: Color(0xFF1E1B4B),
            ),
          ),
        ],
      ),
    );
  }

  // ── Community member vitals and summary widgets ───────────────────────────────
  Widget _buildCommunityMemberVitalsGrid(String memberUid) {
    final heartRateReading = _getHeartRateReading(memberUid);
    final heartRate = heartRateReading.value;
    final spo2 = _getSpo2(memberUid);
    final steps = _getSteps(memberUid);
    final activeMinutes = _getActiveMinutes(memberUid);

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.08,
      children: [
        _communityVitalCard(
          emoji: '🫀',
          label: heartRateReading.isHistorical
              ? 'Recent Resting HR'
              : heartRateReading.isResting
              ? 'Resting Heart Rate'
              : 'Latest Heart Rate',
          value: heartRate != null ? '$heartRate bpm' : '--',
          background: const Color(0xFFFFF1F2),
        ),
        _communityVitalCard(
          emoji: '🫁',
          label: 'SpO₂',
          value: spo2 != null ? '$spo2%' : '--',
          background: const Color(0xFFECFEFF),
        ),
        _communityVitalCard(
          emoji: '👣',
          label: 'Steps Today',
          value: steps != null ? '$steps' : '--',
          background: const Color(0xFFF5F3FF),
        ),
        _communityVitalCard(
          emoji: '⚡',
          label: 'Active Minutes',
          value: activeMinutes != null ? '$activeMinutes min' : '--',
          background: const Color(0xFFFFFBEB),
        ),
      ],
    );
  }

  Widget _buildCommunityMemberSummaryCards(String memberUid) {
    return Column(
      children: [
        _communitySummaryCard('Sleep', _getSleepLabel(memberUid)),
        const SizedBox(height: 12),
        _communitySummaryCard(
          'Estimated BMR',
          _getBmr(memberUid) != null ? '${_getBmr(memberUid)} kcal' : '--',
        ),
      ],
    );
  }

  Widget _communityVitalCard({
    required String emoji,
    required String label,
    required String value,
    required Color background,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const Spacer(),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'DM Sans',
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1E1B4B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _communitySummaryCard(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4338CA).withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: Color(0xFF1E1B4B),
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'DM Sans',
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: Color(0xFF4338CA),
            ),
          ),
        ],
      ),
    );
  }

  // ── Fitbit connection banner ────────────────────────────────────────────────
  Widget _buildFitbitBanner(BuildContext context) {
    if (_fitbitChecking) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4338CA).withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF4338CA),
                ),
              ),
              SizedBox(width: 12),
              Text(
                'Checking Fitbit status…',
                style: TextStyle(
                  fontFamily: 'DM Sans',
                  fontSize: 13,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!_fitbitConnected) {
      // ── NOT CONNECTED — call-to-action banner ──
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: GestureDetector(
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DeviceConnectScreen()),
            );
            // Re-check status when user comes back
            _checkFitbitStatus();
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFF7ED), Color(0xFFFEF3C7)],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFFF59E0B).withOpacity(0.4),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withOpacity(0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text('⌚', style: TextStyle(fontSize: 24)),
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fitbit not connected',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: Color(0xFF92400E),
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Tap to connect your Fitbit and see real‑time vitals',
                        style: TextStyle(
                          fontFamily: 'DM Sans',
                          fontSize: 12,
                          color: Color(0xFFB45309),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ── CONNECTED — mini live vitals card ──
    int? heartRate;
    int? spo2;
    int? steps;
    try {
      heartRate = readFitbitHeartRate(_liveMetrics).value;
    } catch (_) {}
    try {
      final spo2Raw = _liveMetrics?['oxygenSaturation'];
      final spo2Val = (spo2Raw as Map<String, dynamic>?)?['value'];
      if (spo2Val is num) spo2 = spo2Val.round();
    } catch (_) {}
    try {
      final actStr = _liveMetrics?['activities'];
      final summary =
          (actStr as Map<String, dynamic>?)?['summary']
              as Map<String, dynamic>?;
      final stepsVal = summary?['steps'];
      if (stepsVal is num) steps = stepsVal.toInt();
    } catch (_) {}

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFECFDF5), Color(0xFFD1FAE5)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.35)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withOpacity(0.12),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Green pulse dot
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981),
                borderRadius: BorderRadius.circular(5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withOpacity(0.5),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Text('⌚', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Fitbit Connected · LIVE',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: Color(0xFF065F46),
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (steps != null) 'Steps: $steps',
                      if (heartRate != null) 'HR: $heartRate bpm',
                      if (spo2 != null) 'SpO₂: $spo2%',
                      if (heartRate == null && spo2 == null && steps == null)
                        'Live data synced',
                    ].join('  ·  '),
                    style: const TextStyle(
                      fontFamily: 'DM Sans',
                      fontSize: 12,
                      color: Color(0xFF047857),
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: _checkFitbitStatus,
              child: const Icon(
                Icons.refresh_rounded,
                color: Color(0xFF10B981),
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcoming() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📅 Upcoming',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w900,
              fontSize: 17,
              color: Color(0xFF1E1B4B),
            ),
          ),
          const SizedBox(height: 14),
          if (_familyMembers.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4338CA).withOpacity(0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Text(
                'No upcoming events yet. Add family members to see appointments and reminders.',
                style: TextStyle(
                  fontFamily: 'DM Sans',
                  fontSize: 13,
                  color: Color(0xFF6B7280),
                  height: 1.5,
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4338CA).withOpacity(0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F3FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text('🩺', style: TextStyle(fontSize: 20)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_familyMembers.first['name']} – Cardiologist',
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: Color(0xFF1E1B4B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Dr. Smith · Annual checkup',
                          style: TextStyle(
                            fontFamily: 'DM Sans',
                            fontSize: 11.5,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Soon',
                      style: TextStyle(
                        fontFamily: 'DM Sans',
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                        color: Color(0xFFF59E0B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Health Score Ring Painter ──
class _HealthScoreRingPainter extends CustomPainter {
  const _HealthScoreRingPainter({
    required this.score,
    required this.trackColor,
    required this.progressColor,
  });

  final int score;
  final Color trackColor;
  final Color progressColor;

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = 7.0;
    final center = size.center(Offset.zero);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, -pi / 2, 2 * pi, false, trackPaint);
    canvas.drawArc(rect, -pi / 2, 2 * pi * (score / 100), false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _HealthScoreRingPainter oldDelegate) {
    return oldDelegate.score != score ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.progressColor != progressColor;
  }
}

// ── Placeholder Tab ──
class _PlaceholderTab extends StatelessWidget {
  final String title;
  final String emoji;

  const _PlaceholderTab(this.title, this.emoji);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F4FE),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 60)),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w800,
                fontSize: 22,
                color: Color(0xFF1E1B4B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Coming soon...',
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
