import 'package:flutter/material.dart';
import 'dart:math';

class HealthReportScreen extends StatelessWidget {
  const HealthReportScreen({super.key});

  // ── Dummy data from the provided JSON ──
  // {
  //   "steps": 0,
  //   "restingHeartRate": null,
  //   "sleepMinutes": 0,
  //   "timestamp": 1773718978091,
  //   "bmr": 1500,
  //   "healthScore": 78,
  //   "oxygenLevel": 97
  // }

  static const int _steps = 0;
  static const int? _restingHeartRate = null;
  static const int _sleepMinutes = 0;
  static const int _bmr = 1500;
  static const int _healthScore = 78;
  static const int _oxygenLevel = 97;

  // Weekly summary values (derived / simulated for the report view)
  static const int _avgHeartRate = 74;
  static const String _avgHeartRateDelta = '↓ -3 from last wk';
  static const String _avgSleep = '7h 18m';
  static const String _avgSleepDelta = '↓ -22m from last wk';
  static const String _totalSteps = '54,720';
  static const String _totalStepsDelta = '↑ +8% from last wk';
  static const String _calsBurned = '12,494';
  static const String _calsBurnedDelta = '↑ +5% from last wk';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F4FE),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroHeader(context),
            const SizedBox(height: 24),
            _buildWeeklySummary(context),
            const SizedBox(height: 24),
            _buildAnomaliesSection(context),
            const SizedBox(height: 24),
            _buildVitalsSection(context),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // ── Hero Header with Health Score
  // ═══════════════════════════════════════════════
  Widget _buildHeroHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment(-0.7, -1),
          end: Alignment(0.7, 1),
          colors: [Color(0xFF1D4ED8), Color(0xFF4338CA), Color(0xFF7C3AED)],
          stops: [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row
              const Row(
                children: [
                  Text(
                    'Health Report',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w900,
                      fontSize: 24,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text('📋', style: TextStyle(fontSize: 22)),
                ],
              ),
              const SizedBox(height: 4),

              // Date subtitle
              Text(
                _getWeekRange(),
                style: TextStyle(
                  fontFamily: 'DM Sans',
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 20),

              // Health Score card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.18)),
                ),
                child: Row(
                  children: [
                    // Circular score indicator
                    SizedBox(
                      width: 68,
                      height: 68,
                      child: CustomPaint(
                        painter: _HealthScoreRingPainter(
                          score: _healthScore,
                          trackColor: Colors.white.withOpacity(0.15),
                          progressColor: Colors.white,
                        ),
                        child: Center(
                          child: Text(
                            '$_healthScore',
                            style: const TextStyle(
                              fontFamily: 'Nunito',
                              fontWeight: FontWeight.w900,
                              fontSize: 22,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Health Score',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '↗ +4 from last week · ${_healthScore >= 80 ? "Great" : _healthScore >= 60 ? "Good" : "Fair"}',
                            style: TextStyle(
                              fontFamily: 'DM Sans',
                              fontSize: 11.5,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Based on heart, sleep, activity',
                            style: TextStyle(
                              fontFamily: 'DM Sans',
                              fontSize: 10.5,
                              color: Colors.white.withOpacity(0.45),
                            ),
                          ),
                        ],
                      ),
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

  // ═══════════════════════════════════════════════
  // ── Weekly Summary (2×2 Grid)
  // ═══════════════════════════════════════════════
  Widget _buildWeeklySummary(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Weekly Summary',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: Color(0xFF1E1B4B),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _summaryCard(
                  label: 'AVG HEART RATE',
                  value: '$_avgHeartRate',
                  unit: ' bpm',
                  delta: _avgHeartRateDelta,
                  deltaPositive: false,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _summaryCard(
                  label: 'AVG SLEEP',
                  value: _avgSleep,
                  unit: '',
                  delta: _avgSleepDelta,
                  deltaPositive: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _summaryCard(
                  label: 'TOTAL STEPS',
                  value: _totalSteps,
                  unit: '',
                  delta: _totalStepsDelta,
                  deltaPositive: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _summaryCard(
                  label: 'CALS BURNED',
                  value: _calsBurned,
                  unit: '',
                  delta: _calsBurnedDelta,
                  deltaPositive: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryCard({
    required String label,
    required String value,
    required String unit,
    required String delta,
    required bool deltaPositive,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4338CA).withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
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
              fontSize: 10,
              color: Color(0xFF6B7280),
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w900,
                  fontSize: 26,
                  color: Color(0xFF1E1B4B),
                ),
              ),
              if (unit.isNotEmpty)
                Text(
                  unit,
                  style: const TextStyle(
                    fontFamily: 'DM Sans',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            delta,
            style: TextStyle(
              fontFamily: 'DM Sans',
              fontWeight: FontWeight.w600,
              fontSize: 11,
              color: deltaPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // ── Anomalies Detected
  // ═══════════════════════════════════════════════
  Widget _buildAnomaliesSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Anomalies Detected',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: Color(0xFF1E1B4B),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F2),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFFCA5A5).withOpacity(0.5)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Center(
                    child: Text('⚠️', style: TextStyle(fontSize: 18)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'High Heart Rate Episode',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: Color(0xFF991B1B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Thu Feb 15, 3:42 PM · 142 bpm for 8 min. Consider consulting your doctor if recurring.',
                        style: TextStyle(
                          fontFamily: 'DM Sans',
                          fontSize: 12,
                          height: 1.4,
                          color: const Color(0xFF991B1B).withOpacity(0.7),
                        ),
                      ),
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

  // ═══════════════════════════════════════════════
  // ── Extra Vitals Section (from the dummy data)
  // ═══════════════════════════════════════════════
  Widget _buildVitalsSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Today\'s Vitals',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: Color(0xFF1E1B4B),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4338CA).withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                _vitalRow(
                  emoji: '🫀',
                  label: 'Resting Heart Rate',
                  value: _restingHeartRate != null ? '$_restingHeartRate bpm' : 'No data',
                  iconBg: const Color(0xFFFFF1F2),
                ),
                _vitalDivider(),
                _vitalRow(
                  emoji: '🫁',
                  label: 'Oxygen Level (SpO₂)',
                  value: '$_oxygenLevel%',
                  iconBg: const Color(0xFFECFDF5),
                ),
                _vitalDivider(),
                _vitalRow(
                  emoji: '🔥',
                  label: 'BMR (Basal Metabolic Rate)',
                  value: '$_bmr kcal',
                  iconBg: const Color(0xFFFFF7ED),
                ),
                _vitalDivider(),
                _vitalRow(
                  emoji: '👟',
                  label: 'Steps Today',
                  value: _steps > 0 ? '$_steps' : 'No steps yet',
                  iconBg: const Color(0xFFF5F4FE),
                ),
                _vitalDivider(),
                _vitalRow(
                  emoji: '😴',
                  label: 'Sleep',
                  value: _sleepMinutes > 0 ? '${_sleepMinutes ~/ 60}h ${_sleepMinutes % 60}m' : 'No data',
                  iconBg: const Color(0xFFEDE9FE),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _vitalRow({
    required String emoji,
    required String label,
    required String value,
    required Color iconBg,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'DM Sans',
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Color(0xFF374151),
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: value == 'No data' || value == 'No steps yet'
                  ? const Color(0xFF9CA3AF)
                  : const Color(0xFF1E1B4B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _vitalDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: const Color(0xFFEEEDF8).withOpacity(0.7),
    );
  }

  // ── Helper: compute the current week range string ──
  String _getWeekRange() {
    final now = DateTime.fromMillisecondsSinceEpoch(1773718978091);
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[weekStart.month - 1]} ${weekStart.day}–${weekEnd.day}, ${weekEnd.year} · Weekly Summary';
  }
}

// ═══════════════════════════════════════════════
// ── Custom Painter for the circular health score ring
// ═══════════════════════════════════════════════
class _HealthScoreRingPainter extends CustomPainter {
  final int score;
  final Color trackColor;
  final Color progressColor;

  _HealthScoreRingPainter({
    required this.score,
    required this.trackColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 5;

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    final sweepAngle = (score / 100) * 2 * pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _HealthScoreRingPainter oldDelegate) {
    return oldDelegate.score != score;
  }
}
