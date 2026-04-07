import 'package:flutter/material.dart';
import 'contact_sync_screen.dart';

class CommunityIntroScreen extends StatelessWidget {
  const CommunityIntroScreen({super.key});

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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),

                // ── CAREBIT label ──
                Text(
                  'CAREBIT',
                  style: TextStyle(
                    fontFamily: 'DM Sans',
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 3,
                    color: Colors.white.withOpacity(0.4),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Heading ──
                const Text(
                  'Connect with\nYour Loved Ones\n💜',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w900,
                    fontSize: 32,
                    height: 1.15,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),

                // ── Subtitle ──
                Text(
                  'Create a family group to share health\nupdates and stay connected',
                  style: TextStyle(
                    fontFamily: 'DM Sans',
                    fontSize: 14,
                    height: 1.5,
                    color: Colors.white.withOpacity(0.55),
                  ),
                ),
                const SizedBox(height: 36),

                // ── Feature Cards ──
                _featureCard(
                  emoji: '👨‍👩‍👧‍👦',
                  title: 'Family Circle',
                  subtitle: 'Add family members to your health network',
                  bgColor: const Color(0xFF1E3A5F),
                ),
                const SizedBox(height: 12),
                _featureCard(
                  emoji: '❤️',
                  title: 'Health Sharing',
                  subtitle: 'Share vital stats and wellness updates',
                  bgColor: const Color(0xFF2D1B4E),
                ),
                const SizedBox(height: 12),
                _featureCard(
                  emoji: '🔒',
                  title: 'Privacy Protected',
                  subtitle: 'Your data is encrypted and secure',
                  bgColor: const Color(0xFF1B3A4B),
                ),

                const Spacer(),

                // ── Create Family Group Button ──
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ContactSyncScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1E1B4B),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Create Family Group',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _featureCard({
    required String emoji,
    required String title,
    required String subtitle,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 20)),
            ),
          ),
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
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: 'DM Sans',
                    fontSize: 11.5,
                    color: Colors.white.withOpacity(0.5),
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
