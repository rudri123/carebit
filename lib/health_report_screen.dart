import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'fitbit_metrics.dart';
import 'fitbit_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// HealthReportScreen — Live Fitbit vitals, auto-refreshes every 30 seconds
// ─────────────────────────────────────────────────────────────────────────────
class HealthReportScreen extends StatefulWidget {
  const HealthReportScreen({super.key});

  @override
  State<HealthReportScreen> createState() => _HealthReportScreenState();
}

class _HealthReportScreenState extends State<HealthReportScreen> {
  Map<String, dynamic>? _metrics;
  bool _loading = true;
  String? _error;
  DateTime? _lastUpdated;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchMetrics();
    // Auto-refresh every 5 minutes (150 requests/hour limit for Fitbit API)
    _refreshTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _fetchMetrics(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchMetrics() async {
    if (!mounted) return;
    setState(() {
      _loading = _metrics == null; // full spinner only on first load
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _error = 'Not signed in. Please sign in and try again.';
          _loading = false;
        });
        return;
      }

      final idToken = await user.getIdToken();
      if (idToken == null) {
        setState(() {
          _error = 'Could not get login token. Please restart the app.';
          _loading = false;
        });
        return;
      }

      final metrics = await FitbitService.instance.fetchMyMetrics(
        idToken: idToken,
      );

      if (mounted) {
        setState(() {
          _metrics = metrics;
          _loading = false;
          _lastUpdated = DateTime.now();

          // Check for rate limit
          if (metrics['errors'] != null) {
            final Map<String, dynamic> errors = metrics['errors'];
            if (errors.values.any((e) => e.toString().contains('429'))) {
              _error =
                  'Fitbit API speed limit reached. Fitbit allows 150 syncs per hour. Try again in a few minutes!';
            }
          }
        });
      }
    } on FitbitServiceException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Unexpected error: $e';
          _loading = false;
        });
      }
    }
  }

  // ── Parse helpers ──────────────────────────────────────────────────────────

  FitbitHeartRateReading _heartRateReading() {
    return readFitbitHeartRate(_metrics);
  }

  int? _heartRate() {
    try {
      return _heartRateReading().value;
    } catch (_) {
      return null;
    }
  }

  int? _spo2() {
    try {
      final spo2 = _metrics?['oxygenSaturation'];
      if (spo2 == null) return null;
      final val = (spo2 as Map<String, dynamic>?)?['value'];
      if (val is num) return val.round();
      return null;
    } catch (_) {
      return null;
    }
  }

  int? _sleepMinutes() {
    try {
      final sleep = _metrics?['sleep'];
      if (sleep == null) return null;
      final summary =
          (sleep as Map<String, dynamic>?)?['summary'] as Map<String, dynamic>?;
      final total = summary?['totalMinutesAsleep'];
      if (total is num) return total.toInt();
      return null;
    } catch (_) {
      return null;
    }
  }

  String? _profileName() {
    try {
      final profile = _metrics?['profile'];
      if (profile == null) return null;
      final user =
          (profile as Map<String, dynamic>?)?['user'] as Map<String, dynamic>?;
      return user?['displayName'] as String?;
    } catch (_) {
      return null;
    }
  }

  int? _bmr() {
    try {
      final hr = _metrics?['heartRate'];
      final hrMap = hr as Map<String, dynamic>?;
      final activities = hrMap?['activities-heart'] as List<dynamic>?;
      final today = activities?.firstOrNull as Map<String, dynamic>?;
      final zones =
          (today?['value'] as Map<String, dynamic>?)?['heartRateZones']
              as List<dynamic>?;
      final caloriesOOZ = zones?.fold<double>(
        0,
        (sum, z) =>
            sum + ((z as Map<String, dynamic>?)?['caloriesOut'] as num? ?? 0),
      );
      if (caloriesOOZ != null && caloriesOOZ > 0) return caloriesOOZ.toInt();
      return null;
    } catch (_) {
      return null;
    }
  }

  int? _steps() {
    try {
      final act = _metrics?['activities'];
      if (act == null) return null;
      final summary =
          (act as Map<String, dynamic>?)?['summary'] as Map<String, dynamic>?;
      final steps = summary?['steps'];
      if (steps is num) return steps.toInt();
      return null;
    } catch (_) {
      return null;
    }
  }

  int? _activeMinutes() {
    try {
      final act = _metrics?['activities'];
      if (act == null) return null;
      final summary =
          (act as Map<String, dynamic>?)?['summary'] as Map<String, dynamic>?;
      final very = summary?['veryActiveMinutes'] as num? ?? 0;
      final fairly =
          (summary?['fairlyActiveMinutes'] as num? ?? 0) +
          (summary?['lightlyActiveMinutes'] as num? ?? 0);
      final total = (very + fairly).toInt();
      // Even if 0, it tells the user they have 0 minutes of activity today.
      return total;
    } catch (_) {
      return null;
    }
  }

  int _healthScore() {
    // Compute a simple composite score out of 100
    int score = 50; // baseline
    final hr = _heartRate();
    final spo2 = _spo2();
    final sleep = _sleepMinutes();

    if (hr != null) {
      if (hr >= 60 && hr <= 100)
        score += 20;
      else if (hr < 60 || hr <= 110)
        score += 10;
    }
    if (spo2 != null) {
      if (spo2 >= 95)
        score += 20;
      else if (spo2 >= 90)
        score += 10;
    }
    if (sleep != null) {
      if (sleep >= 420)
        score += 10; // 7+ hours
      else if (sleep >= 300)
        score += 5;
    }

    return score.clamp(0, 100);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F4FE),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF4338CA)),
              SizedBox(height: 16),
              Text(
                'Fetching live vitals…',
                style: TextStyle(
                  fontFamily: 'DM Sans',
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F4FE),
      body: RefreshIndicator(
        color: const Color(0xFF4338CA),
        onRefresh: _fetchMetrics,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeroHeader(context),
              const SizedBox(height: 20),
              if (_error != null) _buildErrorBanner(),
              if (_lastUpdated != null) _buildRefreshBadge(),
              const SizedBox(height: 4),
              _buildVitalsGrid(),
              const SizedBox(height: 24),
              _buildSleepCard(),
              const SizedBox(height: 24),
              _buildHeartZonesCard(),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1F2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFCA5A5).withOpacity(0.6)),
        ),
        child: Row(
          children: [
            const Text('⚠️', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _error!,
                style: const TextStyle(
                  fontFamily: 'DM Sans',
                  fontSize: 12,
                  color: Color(0xFF991B1B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRefreshBadge() {
    final timeStr = _formatTime(_lastUpdated!);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
      child: Row(
        children: [
          const Icon(Icons.sync_rounded, size: 13, color: Color(0xFF10B981)),
          const SizedBox(width: 4),
          Text(
            'Live · updated $timeStr · auto-refreshes every 30s',
            style: const TextStyle(
              fontFamily: 'DM Sans',
              fontSize: 11,
              color: Color(0xFF10B981),
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _fetchMetrics,
            child: const Text(
              'Refresh',
              style: TextStyle(
                fontFamily: 'DM Sans',
                fontSize: 11,
                color: Color(0xFF4338CA),
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero Header ────────────────────────────────────────────────────────────
  Widget _buildHeroHeader(BuildContext context) {
    final score = _healthScore();
    final name = _profileName();

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment(-0.7, -1),
          end: Alignment(0.7, 1),
          colors: [Color(0xFF1D4ED8), Color(0xFF4338CA), Color(0xFF7C3AED)],
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
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Health Report',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w900,
                            fontSize: 24,
                            color: Colors.white,
                          ),
                        ),
                        if (name != null)
                          Text(
                            'Fitbit data for $name',
                            style: TextStyle(
                              fontFamily: 'DM Sans',
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.6),
                            ),
                          ),
                        Text(
                          _getWeekRange(),
                          style: TextStyle(
                            fontFamily: 'DM Sans',
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Text('📋', style: TextStyle(fontSize: 26)),
                ],
              ),
              const SizedBox(height: 20),
              // Health Score card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.18)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 68,
                      height: 68,
                      child: CustomPaint(
                        painter: _HealthScoreRingPainter(
                          score: score,
                          trackColor: Colors.white.withOpacity(0.15),
                          progressColor: Colors.white,
                        ),
                        child: Center(
                          child: Text(
                            '$score',
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
                            '${score >= 80
                                ? "Great"
                                : score >= 60
                                ? "Good"
                                : "Fair"} · Based on heart rate, sleep & SpO₂',
                            style: TextStyle(
                              fontFamily: 'DM Sans',
                              fontSize: 11.5,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _metrics == null
                                ? 'No Fitbit data yet — connect your device'
                                : 'Live data from Fitbit',
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

  // ── Vitals Grid ───────────────────────────────────────────────────────
  Widget _buildVitalsGrid() {
    final heartRateReading = _heartRateReading();
    final hr = heartRateReading.value;
    final spo2 = _spo2();
    final sleep = _sleepMinutes();
    final bmr = _bmr();
    final steps = _steps();
    final activeMins = _activeMinutes();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Today's Vitals",
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
                child: _vitalCard(
                  emoji: '🫀',
                  label: hr == null
                      ? 'Heart Rate'
                      : heartRateReading.isHistorical
                      ? 'Recent Resting HR'
                      : heartRateReading.isResting
                      ? 'Resting Heart Rate'
                      : 'Latest Heart Rate',
                  value: hr != null ? '$hr' : '--',
                  unit: hr != null ? ' bpm' : '',
                  bg: const Color(0xFFFFF1F2),
                  isLive: hr != null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _vitalCard(
                  emoji: '🫁',
                  label: 'SpO₂ (Oxygen)',
                  value: spo2 != null ? '$spo2' : '--',
                  unit: spo2 != null ? '%' : '',
                  bg: const Color(0xFFECFDF5),
                  isLive: spo2 != null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _vitalCard(
                  emoji: '😴',
                  label: 'Sleep Last Night',
                  value: sleep != null
                      ? '${sleep ~/ 60}h ${sleep % 60}m'
                      : '--',
                  unit: '',
                  bg: const Color(0xFFEDE9FE),
                  isLive: sleep != null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _vitalCard(
                  emoji: '🔥',
                  label: 'Calories Burned',
                  value: bmr != null ? '$bmr' : '--',
                  unit: bmr != null ? ' kcal' : '',
                  bg: const Color(0xFFFFF7ED),
                  isLive: bmr != null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _vitalCard(
                  emoji: '👟',
                  label: 'Steps Today',
                  value: steps != null
                      ? steps.toString().replaceAllMapped(
                          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                          (Match m) => '${m[1]},',
                        )
                      : '--',
                  unit: '',
                  bg: const Color(0xFFE0F2FE), // Light sky blue
                  isLive: steps != null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _vitalCard(
                  emoji: '⏱️',
                  label: 'Active Minutes',
                  value: activeMins != null ? '$activeMins' : '--',
                  unit: activeMins != null ? ' min' : '',
                  bg: const Color(0xFFFEF08A).withOpacity(0.4), // Light yellow
                  isLive: activeMins != null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _vitalCard({
    required String emoji,
    required String label,
    required String value,
    required String unit,
    required Color bg,
    required bool isLive,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4338CA).withOpacity(0.07),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 17)),
                ),
              ),
              const Spacer(),
              if (isLive)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'LIVE',
                    style: TextStyle(
                      fontFamily: 'DM Sans',
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF10B981),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w900,
                  fontSize: 26,
                  color: isLive
                      ? const Color(0xFF1E1B4B)
                      : const Color(0xFFD1D5DB),
                ),
              ),
              if (unit.isNotEmpty)
                Text(
                  unit,
                  style: const TextStyle(
                    fontFamily: 'DM Sans',
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'DM Sans',
              fontWeight: FontWeight.w600,
              fontSize: 11,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sleep breakdown card ───────────────────────────────────────────────────
  Widget _buildSleepCard() {
    int? deep, light, rem, awake;
    try {
      final sleep = _metrics?['sleep'] as Map<String, dynamic>?;
      final stages =
          (sleep?['summary'] as Map<String, dynamic>?)?['stages']
              as Map<String, dynamic>?;
      deep = (stages?['deep'] as num?)?.toInt();
      light = (stages?['light'] as num?)?.toInt();
      rem = (stages?['rem'] as num?)?.toInt();
      awake = (stages?['wake'] as num?)?.toInt();
    } catch (_) {}

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sleep Breakdown',
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
                  color: const Color(0xFF4338CA).withOpacity(0.07),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                _sleepRow('😴', 'Deep Sleep', deep, const Color(0xFF4338CA)),
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFFF3F4F6),
                ),
                _sleepRow('💤', 'Light Sleep', light, const Color(0xFF8B5CF6)),
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFFF3F4F6),
                ),
                _sleepRow('🌀', 'REM Sleep', rem, const Color(0xFF06B6D4)),
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFFF3F4F6),
                ),
                _sleepRow('👁️', 'Awake', awake, const Color(0xFFF59E0B)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sleepRow(String emoji, String label, int? minutes, Color color) {
    final text = minutes != null
        ? '${minutes ~/ 60}h ${minutes % 60}m'
        : 'No data';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 17)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'DM Sans',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Color(0xFF374151),
                  ),
                ),
                if (minutes != null)
                  LinearProgressIndicator(
                    value: (minutes / 480).clamp(0.0, 1.0),
                    backgroundColor: color.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 4,
                    borderRadius: BorderRadius.circular(4),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: minutes != null
                  ? const Color(0xFF1E1B4B)
                  : const Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }

  // ── Heart Rate Zones card ─────────────────────────────────────────────────
  Widget _buildHeartZonesCard() {
    List<Map<String, dynamic>> zones = [];
    try {
      final hr = _metrics?['heartRate'] as Map<String, dynamic>?;
      final activities = hr?['activities-heart'] as List<dynamic>?;
      final today = activities?.firstOrNull as Map<String, dynamic>?;
      final rawZones =
          (today?['value'] as Map<String, dynamic>?)?['heartRateZones']
              as List<dynamic>?;
      zones =
          rawZones?.map((z) => Map<String, dynamic>.from(z as Map)).toList() ??
          [];
    } catch (_) {}

    if (zones.isEmpty) return const SizedBox.shrink();

    final zoneColors = [
      const Color(0xFF3B82F6),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Heart Rate Zones',
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
                  color: const Color(0xFF4338CA).withOpacity(0.07),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: zones.asMap().entries.map((entry) {
                final i = entry.key;
                final z = entry.value;
                final name = z['name'] as String? ?? 'Zone ${i + 1}';
                final minutes = (z['minutes'] as num?)?.toInt() ?? 0;
                final min = z['min'] as num?;
                final max = z['max'] as num?;
                final color = zoneColors[i % zoneColors.length];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontFamily: 'DM Sans',
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: Color(0xFF374151),
                              ),
                            ),
                          ),
                          Text(
                            min != null && max != null
                                ? '${min.toInt()}–${max.toInt()} bpm'
                                : '',
                            style: const TextStyle(
                              fontFamily: 'DM Sans',
                              fontSize: 11,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$minutes min',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: minutes > 0
                                  ? const Color(0xFF1E1B4B)
                                  : const Color(0xFFD1D5DB),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (minutes / 60).clamp(0.0, 1.0),
                          backgroundColor: color.withOpacity(0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helper: week range string ──────────────────────────────────────────────
  String _getWeekRange() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));
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
    return '${months[weekStart.month - 1]} ${weekStart.day}–${weekEnd.day}, ${weekEnd.year}';
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }
}

// ── Custom Painter for health score ring ──────────────────────────────────────
class _HealthScoreRingPainter extends CustomPainter {
  final int score;
  final Color trackColor;
  final Color progressColor;

  const _HealthScoreRingPainter({
    required this.score,
    required this.trackColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 5;
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

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
  bool shouldRepaint(covariant _HealthScoreRingPainter oldDelegate) =>
      oldDelegate.score != score;
}
