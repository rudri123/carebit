import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';
import 'device_connect_screen.dart';
import 'fitbit_metrics.dart';
import 'fitbit_service.dart';
import 'alerts_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool twoFactorEnabled = true;
  bool biometricEnabled = true;
  bool pushNotificationsEnabled = true;
  bool doNotDisturbEnabled = true;
  bool healthDataEnabled = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data ?? FirebaseAuth.instance.currentUser;

        final displayName =
            user?.displayName ?? user?.email?.split('@').first ?? 'User';
        final email = user?.email ?? 'Not available';
        final phone = (user?.phoneNumber != null && user!.phoneNumber!.isNotEmpty)
            ? user.phoneNumber!
            : 'Not set';
        final memberSince = user?.metadata.creationTime != null
            ? _formatDate(user!.metadata.creationTime!)
            : 'Not available';

        return Scaffold(
          backgroundColor: const Color(0xFFF5F4FE),
          body: SingleChildScrollView(
            child: Column(
              children: [
                _buildHero(user, displayName, email),
                const SizedBox(height: 12),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildConnectDeviceButton(),
                      const SizedBox(height: 20),

                      _sectionLabel('PERSONAL INFORMATION'),
                      const SizedBox(height: 10),
                      _buildInfoCard([
                        _profileRow(
                          emoji: '👤',
                          iconBg: const Color(0xFFFFF1F2),
                          label: 'Full Name',
                          value: displayName,
                          isLast: false,
                          onTap: () => _editFullName(displayName),
                          trailing: Container(
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
                        _profileRow(
                          emoji: '✉️',
                          iconBg: const Color(0xFFECFDF5),
                          label: 'Email',
                          value: email,
                          isLast: false,
                          onTap: () => _showComingSoon('Email editing'),
                        ),
                        _profileRow(
                          emoji: '📱',
                          iconBg: const Color(0xFFFFF1F2),
                          label: 'Phone',
                          value: phone,
                          isLast: false,
                          onTap: () => _showComingSoon('Phone editing'),
                        ),
                        _profileRow(
                          emoji: '📅',
                          iconBg: const Color(0xFFFFF1F2),
                          label: 'Member Since',
                          value: memberSince,
                          isLast: true,
                          onTap: () {},
                          showChevron: false,
                        ),
                      ]),
                      const SizedBox(height: 20),

                      _sectionLabel('HEALTH PROFILE'),
                      const SizedBox(height: 10),
                      _buildHealthGrid(),
                      const SizedBox(height: 20),

                      _sectionLabel('MY GOALS'),
                      const SizedBox(height: 10),
                      _buildInfoCard([
                        _staticRow(
                          emoji: '👣',
                          iconBg: const Color(0xFFFFF1F2),
                          label: 'Daily Steps',
                          value: '10,000 steps',
                          isLast: false,
                        ),
                        _staticRow(
                          emoji: '🔥',
                          iconBg: const Color(0xFFECFDF5),
                          label: 'Calorie Burn',
                          value: '2,000 kcal/day',
                          isLast: false,
                        ),
                        _staticRow(
                          emoji: '🌙',
                          iconBg: const Color(0xFFFFF1F2),
                          label: 'Sleep Goal',
                          value: '8 hrs/night',
                          isLast: true,
                        ),
                      ]),
                      const SizedBox(height: 20),

                      _sectionLabel('SECURITY'),
                      const SizedBox(height: 10),
                      _buildInfoCard([
                        _staticRow(
                          emoji: '🔒',
                          iconBg: const Color(0xFFFFF1F2),
                          label: 'Change Password',
                          value: 'Last changed 30 days ago',
                          isLast: false,
                        ),
                        _toggleRow(
                          '🛡️',
                          const Color(0xFFFFF1F2),
                          'Two-Factor Auth',
                          'Enabled via SMS',
                          twoFactorEnabled,
                          (v) => setState(() => twoFactorEnabled = v),
                        ),
                        _toggleRowLast(
                          '📱',
                          const Color(0xFFECFDF5),
                          'Biometric Login',
                          'Face ID Active',
                          biometricEnabled,
                          (v) => setState(() => biometricEnabled = v),
                        ),
                      ]),
                      const SizedBox(height: 20),

                      _sectionLabel('NOTIFICATIONS'),
                      const SizedBox(height: 10),
                      _buildInfoCard([
                        _toggleRow(
                          '🔔',
                          const Color(0xFFFFF1F2),
                          'Push Notifications',
                          'Enabled',
                          pushNotificationsEnabled,
                          (v) => setState(() => pushNotificationsEnabled = v),
                        ),
                        _toggleRow(
                          '🌙',
                          const Color(0xFFECFDF5),
                          'Do Not Disturb',
                          '10 PM – 7 AM',
                          doNotDisturbEnabled,
                          (v) => setState(() => doNotDisturbEnabled = v),
                        ),
                        _toggleRowLast(
                          '📊',
                          const Color(0xFFF5F4FE),
                          'Health Data Sharing',
                          'Only me',
                          healthDataEnabled,
                          (v) => setState(() => healthDataEnabled = v),
                        ),
                      ]),
                      const SizedBox(height: 20),

                      _buildActionButton(
                        label: 'Delete Account',
                        textColor: const Color(0xFFEF4444),
                        bgColor: const Color(0xFFFFF1F2),
                        borderColor: const Color(0xFFFCA5A5),
                      ),
                      const SizedBox(height: 10),

                      GestureDetector(
                        onTap: () => _handleSignOut(context),
                        child: _buildActionButton(
                          label: 'Log Out',
                          textColor: const Color(0xFF6B7280),
                          bgColor: const Color(0xFFECFDF5),
                          borderColor: const Color(0xFFE5E7EB),
                        ),
                      ),

                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Future<void> _editFullName(String currentName) async {
    final controller = TextEditingController(text: currentName);

    final newName = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Edit Full Name',
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
              hintText: 'Enter full name',
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

    if (newName == null || newName.isEmpty || newName == currentName) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      await user?.updateDisplayName(newName);
      await user?.reload();

      if (!mounted) return;

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Full name updated successfully'),
          backgroundColor: Colors.green[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update name: $e'),
          backgroundColor: Colors.red[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  void _showComingSoon(String featureName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$featureName coming soon'),
        backgroundColor: const Color(0xFF4338CA),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

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
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
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

  Widget _buildHero(User? user, String displayName, String email) {
    return Container(
      height: 360,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment(-0.7, -1),
          end: Alignment(0.7, 1),
          colors: [Color(0xFF1D4ED8), Color(0xFF4338CA), Color(0xFF7C3AED)],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            left: -20,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(60),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 34),
                Stack(
                  children: [
                    Container(
                      width: 108,
                      height: 108,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(54),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.45),
                          width: 4,
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
                                  fontSize: 42,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 4,
                      right: 0,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(17),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.18),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            )
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.camera_alt_rounded,
                            size: 16,
                            color: Color(0xFF1E1B4B),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  displayName,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w900,
                    fontSize: 28,
                    color: Colors.white,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  email,
                  style: TextStyle(
                    fontFamily: 'DM Sans',
                    fontSize: 15,
                    color: Colors.white.withOpacity(0.65),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 28),
                  height: 84,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.white.withOpacity(0.16)),
                  ),
                  child: Row(
                    children: [
                      _statItem('7', 'Day Streak', border: true),
                      _statItem('82%', 'Completion', border: true),
                      _statItem('3', 'Active Alerts'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem(String value, String label, {bool border = false}) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          border: border
              ? Border(
                  right: BorderSide(color: Colors.white.withOpacity(0.12)),
                )
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w900,
                fontSize: 24,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'DM Sans',
                fontSize: 13,
                color: Colors.white.withOpacity(0.58),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectDeviceButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const DeviceConnectScreen(),
            ),
          );
        },
        icon: const Icon(
          Icons.watch_rounded,
          color: Color(0xFF4338CA),
          size: 22,
        ),
        label: const Text(
          'Connect Device',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w800,
            fontSize: 15,
            color: Color(0xFF23235F),
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFFE7E7EF)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontFamily: 'DM Sans',
        fontWeight: FontWeight.w800,
        fontSize: 9.5,
        color: Color(0xFF6B7280),
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> rows) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4338CA).withOpacity(0.1),
            blurRadius: 24,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(children: rows),
    );
  }

  Widget _profileRow({
    required String emoji,
    required Color iconBg,
    required String label,
    required String value,
    required bool isLast,
    required VoidCallback onTap,
    Widget? trailing,
    bool showChevron = true,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: isLast
          ? const BorderRadius.only(
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(18),
            )
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(
                  bottom: BorderSide(color: Color(0xFFECFDF5)),
                ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'DM Sans',
                      fontWeight: FontWeight.w500,
                      fontSize: 11,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    value,
                    style: const TextStyle(
                      fontFamily: 'DM Sans',
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Color(0xFF1E1B4B),
                    ),
                  ),
                ],
              ),
            ),
            trailing ??
                (showChevron
                    ? const Text(
                        '›',
                        style: TextStyle(
                          color: Color(0xFFD1D0E0),
                          fontSize: 20,
                        ),
                      )
                    : const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }

  Widget _staticRow({
    required String emoji,
    required Color iconBg,
    required String label,
    required String value,
    required bool isLast,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: Color(0xFFECFDF5)),
              ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'DM Sans',
                    fontWeight: FontWeight.w500,
                    fontSize: 11,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: const TextStyle(
                    fontFamily: 'DM Sans',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Color(0xFF1E1B4B),
                  ),
                ),
              ],
            ),
          ),
          const Text(
            '›',
            style: TextStyle(
              color: Color(0xFFD1D0E0),
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggleRow(
    String emoji,
    Color iconBg,
    String label,
    String value,
    bool toggled,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFECFDF5))),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'DM Sans',
                    fontWeight: FontWeight.w500,
                    fontSize: 11,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: const TextStyle(
                    fontFamily: 'DM Sans',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Color(0xFF1E1B4B),
                  ),
                ),
              ],
            ),
          ),
          _buildToggle(toggled, onChanged),
        ],
      ),
    );
  }

  Widget _toggleRowLast(
    String emoji,
    Color iconBg,
    String label,
    String value,
    bool toggled,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'DM Sans',
                    fontWeight: FontWeight.w500,
                    fontSize: 11,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: const TextStyle(
                    fontFamily: 'DM Sans',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Color(0xFF1E1B4B),
                  ),
                ),
              ],
            ),
          ),
          _buildToggle(toggled, onChanged),
        ],
      ),
    );
  }

  Widget _buildToggle(bool value, ValueChanged<bool> onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 40,
        height: 23,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          gradient: value
              ? const LinearGradient(
                  colors: [
                    Color(0xFF1D4ED8),
                    Color(0xFF4338CA),
                    Color(0xFF7C3AED),
                  ],
                )
              : null,
          color: value ? null : const Color(0xFFE5E7EB),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              top: 3,
              left: value ? null : 3,
              right: value ? 3 : null,
              child: Container(
                width: 17,
                height: 17,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.2,
      children: [
        _healthCard('HEIGHT', "5'4\"", 'ft'),
        _healthCard('WEIGHT', '58', 'kg'),
        _healthCard('BLOOD TYPE', 'B+', ''),
        _healthCardBmi('BMI', '21.8', 'Normal'),
      ],
    );
  }

  Widget _healthCard(String label, String value, String unit) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4338CA).withOpacity(0.1),
            blurRadius: 24,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'DM Sans',
              fontWeight: FontWeight.w700,
              fontSize: 9.5,
              color: Color(0xFF6B7280),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                  color: Color(0xFF1E1B4B),
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 2),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    unit,
                    style: const TextStyle(
                      fontFamily: 'DM Sans',
                      fontSize: 10,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ),
              ]
            ],
          ),
        ],
      ),
    );
  }

  Widget _healthCardBmi(String label, String value, String status) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4338CA).withOpacity(0.1),
            blurRadius: 24,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'DM Sans',
              fontWeight: FontWeight.w700,
              fontSize: 9.5,
              color: Color(0xFF6B7280),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                  color: Color(0xFF1E1B4B),
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  status,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                    fontSize: 9,
                    color: Color(0xFF10B981),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required Color textColor,
    required Color bgColor,
    required Color borderColor,
  }) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: borderColor),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w800,
            fontSize: 14,
            color: textColor,
          ),
        ),
      ),
    );
  }
}