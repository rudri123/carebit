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
    return Container(
      height: 74,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: const Color(0xFFEEEDF8))),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4338CA).withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(0, '🏠', 'Home'),
          _navItem(1, '❤️', 'Health'),
          _navFab(),
          _navItem(3, '🔔', 'Alerts'),
          _navItem(4, '👤', 'Profile'),
        ],
      ),
    );
  }

  Widget _navItem(int index, String emoji, String label) {
    final bool active = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'DM Sans',
                fontWeight: FontWeight.w700,
                fontSize: 9,
                color: active ? const Color(0xFF4338CA) : const Color(0xFFC4C2D6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navFab() {
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                colors: [Color(0xFF1D4ED8), Color(0xFF4338CA), Color(0xFF7C3AED)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4338CA).withOpacity(0.45),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Center(
              child: Text('＋', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Add',
            style: TextStyle(fontFamily: 'DM Sans', fontWeight: FontWeight.w700, fontSize: 9, color: Color(0xFFC4C2D6)),
          ),
        ],
      ),
    );
  }
}

// ── Home Tab (your existing dashboard content) ──
class _HomeTab extends StatelessWidget {
  const _HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data ?? FirebaseAuth.instance.currentUser;

        return Scaffold(
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
            SliverAppBar(
              expandedHeight: 200,
              floating: false,
              pinned: true,
              backgroundColor: Theme.of(context).colorScheme.primary,
              flexibleSpace: FlexibleSpaceBar(
                title: const Text(
                  'Dashboard',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.primaryContainer,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildListDelegate([
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Welcome Card
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.grey[200]!),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Row(
                            children: [
                              Container(
                                width: 60, height: 60,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primaryContainer,
                                  shape: BoxShape.circle,
                                  image: user?.photoURL != null
                                      ? DecorationImage(
                                          image: NetworkImage(user!.photoURL!),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: user?.photoURL == null
                                    ? Icon(Icons.person, size: 30, color: Theme.of(context).colorScheme.primary)
                                    : null,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Welcome back!',
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey[600])),
                                    const SizedBox(height: 4),
                                    Text(user?.displayName ?? user?.email?.split('@').first ?? 'User',
                                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                            fontWeight: FontWeight.bold, color: Colors.grey[900])),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      Text('Account Information',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold, color: Colors.grey[900])),
                      const SizedBox(height: 16),

                      _InfoTile(icon: Icons.person_outline, title: 'Display Name', subtitle: user?.displayName ?? 'Not set', iconColor: Colors.indigo),
                      const SizedBox(height: 12),
                      _InfoTile(icon: Icons.email_outlined, title: 'Email Address', subtitle: user?.email ?? 'Not available', iconColor: Colors.blue),
                      const SizedBox(height: 12),
                      _InfoTile(icon: Icons.phone_outlined, title: 'Phone Number', subtitle: (user?.phoneNumber != null && user!.phoneNumber!.isNotEmpty) ? user!.phoneNumber! : 'Not set', iconColor: Colors.deepOrange),
                      const SizedBox(height: 12),
                      _InfoTile(icon: Icons.fingerprint, title: 'User ID', subtitle: user?.uid ?? 'Not available', iconColor: Colors.purple),
                      const SizedBox(height: 12),
                      _InfoTile(
                        icon: Icons.verified_user_outlined,
                        title: 'Email Verified',
                        subtitle: user?.emailVerified == true ? 'Yes' : 'No',
                        iconColor: user?.emailVerified == true ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(height: 12),
                      _InfoTile(
                        icon: Icons.calendar_today_outlined,
                        title: 'Member Since',
                        subtitle: user?.metadata.creationTime != null ? _formatDate(user!.metadata.creationTime!) : 'Not available',
                        iconColor: Colors.teal,
                      ),
                      const SizedBox(height: 32),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _handleSignOut(context),
                          icon: const Icon(Icons.logout),
                          label: const Text('Sign Out'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[50],
                            foregroundColor: Colors.red[700],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
      },
    );
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

  Future<void> _handleSignOut(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Signed out successfully'),
            backgroundColor: Colors.green[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: $e'),
            backgroundColor: Colors.red[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
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

// ── Info Tile ──
class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;

  const _InfoTile({required this.icon, required this.title, required this.subtitle, required this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: ListTile(
        leading: Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        title: Text(title, style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle,
            style: TextStyle(fontSize: 16, color: Colors.grey[900], fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis),
      ),
    );
  }
}