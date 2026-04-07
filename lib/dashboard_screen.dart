import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'profile_screen.dart';
import 'health_report_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  // ── Pages for each tab ──
  late final List<Widget> _pages = [
    const _HomeTab(),
    const HealthReportScreen(),
    const _PlaceholderTab('Add', '➕'),
    const _PlaceholderTab('Alerts', '🔔'),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
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
                color: active ? const Color(0xFF4338CA) : const Color(0xFF8E8CA8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navFab() {
    final bool active = _currentIndex == 2;

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = 2),
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
                  Icon(
                    Icons.favorite_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                  Positioned(
                    right: 7,
                    top: 9,
                    child: Icon(
                      Icons.add,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add',
            style: TextStyle(
              fontFamily: 'DM Sans',
              fontWeight: FontWeight.w700,
              fontSize: 10,
              color: active ? const Color(0xFF4338CA) : const Color(0xFF8E8CA8),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Home Tab — Family Health Dashboard (Screen 4) ──
class _HomeTab extends StatelessWidget {
  const _HomeTab({super.key});

  // Dummy family members
  static const _familyMembers = [
    {'name': 'John', 'emoji': '👨', 'color': 0xFF3B82F6},
    {'name': 'Sarah', 'emoji': '👩', 'color': 0xFFEF4444},
    {'name': 'Mom', 'emoji': '👩‍🦰', 'color': 0xFF10B981},
    {'name': 'Riya', 'emoji': '👧', 'color': 0xFFF59E0B},
  ];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data ?? FirebaseAuth.instance.currentUser;
        final displayName = user?.displayName ?? user?.email?.split('@').first ?? 'User';
        final greeting = _getGreeting();

        return Scaffold(
          backgroundColor: const Color(0xFFF5F4FE),
          body: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ──
                  _buildHeader(context, displayName, greeting, user),
                  const SizedBox(height: 20),

                  // ── Family Members ──
                  _buildFamilyAvatars(),
                  const SizedBox(height: 24),

                  // ── Health Alerts ──
                  _buildHealthAlerts(),
                  const SizedBox(height: 24),

                  // ── Upcoming ──
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

  Widget _buildHeader(BuildContext context, String displayName, String greeting, User? user) {
    final now = DateTime.now();
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
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
          // Greeting row
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
                      'Family health overview · $dateStr',
                      style: TextStyle(
                        fontFamily: 'DM Sans',
                        fontSize: 11.5,
                        color: Colors.white.withOpacity(0.55),
                      ),
                    ),
                  ],
                ),
              ),
              // Avatar
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(21),
                  border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
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
                          displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
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

          // Stats row
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Row(
              children: [
                _statItem('5', 'MEMBERS'),
                _statDivider(),
                _statItem('3', 'ACTIVE'),
                _statDivider(),
                _statItem('2', 'ALERTS'),
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

  Widget _buildFamilyAvatars() {
    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _familyMembers.length,
        itemBuilder: (context, index) {
          final member = _familyMembers[index];
          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Column(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Color(member['color'] as int).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: Color(member['color'] as int).withOpacity(0.4),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      member['emoji'] as String,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  member['name'] as String,
                  style: const TextStyle(
                    fontFamily: 'DM Sans',
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    color: Color(0xFF374151),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHealthAlerts() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '⚕ Health Alerts',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w900,
              fontSize: 17,
              color: Color(0xFF1E1B4B),
            ),
          ),
          const SizedBox(height: 14),
          _alertCard(
            color: const Color(0xFFEF4444),
            bgColor: const Color(0xFFFEF2F2),
            borderColor: const Color(0xFFFCA5A5),
            emoji: '🔴',
            title: 'Lucas – Inhaler Low',
            subtitle: 'Less than 10 doses left! Refill before Feb 26.',
          ),
          const SizedBox(height: 10),
          _alertCard(
            color: const Color(0xFFF59E0B),
            bgColor: const Color(0xFFFFFBEB),
            borderColor: const Color(0xFFFCD34D),
            emoji: '🟡',
            title: 'John – BP Check Due',
            subtitle: '14 days since last reading.',
          ),
          const SizedBox(height: 10),
          _alertCard(
            color: const Color(0xFF8B5CF6),
            bgColor: const Color(0xFFF5F3FF),
            borderColor: const Color(0xFFC4B5FD),
            emoji: '🟣',
            title: 'Emma – Vaccine Due',
            subtitle: 'HPV booster due March 2025.',
          ),
        ],
      ),
    );
  }

  Widget _alertCard({
    required Color color,
    required Color bgColor,
    required Color borderColor,
    required String emoji,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: 'DM Sans',
                    fontSize: 11.5,
                    color: color.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
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
                  child: const Center(child: Text('🩺', style: TextStyle(fontSize: 20))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'John – Cardiologist',
                        style: TextStyle(
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
            Text(title,
                style: const TextStyle(
                    fontFamily: 'Nunito', fontWeight: FontWeight.w800, fontSize: 22, color: Color(0xFF1E1B4B))),
            const SizedBox(height: 8),
            Text('Coming soon...', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
          ],
        ),
      ),
    );
  }
}