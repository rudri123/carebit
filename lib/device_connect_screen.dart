import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'dashboard_screen.dart';
import 'fitbit_service.dart';

class DeviceConnectScreen extends StatefulWidget {
  const DeviceConnectScreen({super.key});

  @override
  State<DeviceConnectScreen> createState() => _DeviceConnectScreenState();
}

class _DeviceConnectScreenState extends State<DeviceConnectScreen> {
  int? _selectedDevice = 0; // Fitbit selected by default

  // ── Fitbit real-auth state ─────────────────────────────────────────────────
  bool _fitbitConnected = false;
  String _fitbitDeviceName = 'Not connected';
  String _batteryLevel = '';
  bool _isConnecting = false;
  String? _statusMessage;

  /// The OAuth `state` value returned by the backend's /fitbitAuthStart.
  /// Stored so we can poll /fitbitAuthCallbackStatus later.
  String? _oauthState;

  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _deepLinkSub;

  // ── Static device list (Fitbit row is dynamic; others stay static) ─────────
  final List<_Device> _devices = [
    _Device(
      name: 'Fitbit',
      subtitle: 'Tap to connect',
      emoji: '⌚',
      statusColor: const Color(0xFF6B7280),
      connected: false,
    ),
    _Device(
      name: 'Apple Watch',
      subtitle: 'Available to pair',
      emoji: '⌚',
      statusColor: const Color(0xFFF59E0B),
      connected: false,
    ),
    _Device(
      name: 'Garmin',
      subtitle: 'Coming in future update',
      emoji: '⌚',
      statusColor: const Color(0xFF6B7280),
      connected: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initDeepLink();
  }

  Future<void> _initDeepLink() async {
    _appLinks = AppLinks();

    final initialUri = await _appLinks.getInitialLink();
    if (initialUri != null && mounted) {
      _handleDeepLink(initialUri);
    }

    _deepLinkSub = _appLinks.uriLinkStream.listen(
      (uri) {
        if (mounted) _handleDeepLink(uri);
      },
      onError: (_) {},
    );
  }

  Future<void> _handleDeepLink(Uri uri) async {
    if (uri.scheme != kFitbitRedirectScheme) return;

    final code = uri.queryParameters['code'];
    final state = uri.queryParameters['state'];
    final error = uri.queryParameters['error'];

    if (error != null) {
      _setError('Fitbit denied access: $error');
      return;
    }

    if (code == null || code.isEmpty) return;

    setState(() {
      _isConnecting = true;
      _statusMessage = 'Authorising with Fitbit…';
    });

    try {
      final idToken = await _getIdToken();
      if (idToken == null) {
        _setError('Not signed in. Please sign in and try again.');
        return;
      }

      FitbitDevice device;

      try {
        device = await FitbitService.instance.exchangeCallback(
          code: code,
          state: state ?? _oauthState ?? '',
          idToken: idToken,
        );
      } on FitbitServiceException {
        if (_oauthState != null) {
          setState(() => _statusMessage = 'Waiting for Fitbit to confirm…');
          device = await FitbitService.instance.pollCallbackStatus(
            state: _oauthState!,
            idToken: idToken,
          );
        } else {
          rethrow;
        }
      }

      if (!mounted) return;
      setState(() {
        _fitbitConnected = true;
        _fitbitDeviceName = device.deviceName;
        _batteryLevel = device.batteryLevel;
        _isConnecting = false;
        _statusMessage = null;
        _devices[0] = _Device(
          name: 'Fitbit',
          subtitle: device.deviceName,
          emoji: '⌚',
          statusColor: const Color(0xFF10B981),
          connected: true,
        );
      });
    } on FitbitServiceException catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError('Unexpected error: $e');
    }
  }

  Future<void> _connectFitbit() async {
    if (_fitbitConnected || _isConnecting) return;

    setState(() {
      _isConnecting = true;
      _statusMessage = 'Opening Fitbit login…';
    });

    try {
      final result = await FitbitService.instance.getAuthUrl();
      _oauthState = result.state;

      final uri = Uri.parse(result.authUrl);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        _setError('Could not open browser. Please try again.');
        return;
      }

      setState(() => _statusMessage = 'Waiting for Fitbit authorisation…');
    } on FitbitServiceException catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError('Could not reach backend: $e');
    }
  }

  Future<String?> _getIdToken() async {
    try {
      return await FirebaseAuth.instance.currentUser?.getIdToken();
    } catch (_) {
      return null;
    }
  }

  void _setError(String msg) {
    if (!mounted) return;
    setState(() {
      _isConnecting = false;
      _statusMessage = msg;
    });
  }

  @override
  void dispose() {
    _deepLinkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FF),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // ── Back button ──
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDE9FE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new,
                    size: 16,
                    color: Color(0xFF4338CA),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Step label ──
              Text(
                'STEP 2 OF 4',
                style: TextStyle(
                  fontFamily: 'DM Sans',
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                  letterSpacing: 2,
                  color: const Color(0xFF6B7280).withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 8),

              // ── Title ──
              const Text(
                'Connect Your Device',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w900,
                  fontSize: 26,
                  color: Color(0xFF1E1B4B),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Health data',
                style: TextStyle(
                  fontFamily: 'DM Sans',
                  fontSize: 13,
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(height: 28),

              // ── Device list ──
              ..._devices.asMap().entries.map((entry) {
                final index = entry.key;
                final device = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _deviceTile(device, index),
                );
              }),

              // ── Status / error message ──
              if (_statusMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    _statusMessage!,
                    style: TextStyle(
                      fontFamily: 'DM Sans',
                      fontSize: 12,
                      color: _isConnecting
                          ? const Color(0xFF4338CA)
                          : Colors.red[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

              // ── Connect Fitbit button ──
              if (_selectedDevice == 0 && !_fitbitConnected)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: _isConnecting ? null : _connectFitbit,
                      icon: _isConnecting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('⌚'),
                      label: Text(
                        _isConnecting ? 'Connecting…' : 'Connect Fitbit',
                        style: const TextStyle(
                          fontFamily: 'DM Sans',
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4338CA),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ),

              const Spacer(),

              // ── Status card ──
              if (_selectedDevice == 0 && _fitbitConnected)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF059669), Color(0xFF047857)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF059669).withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: const Color(0xFF6EE7B7),
                          borderRadius: BorderRadius.circular(5),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6EE7B7).withOpacity(0.6),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$_fitbitDeviceName connected',
                              style: const TextStyle(
                                fontFamily: 'DM Sans',
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              _batteryLevel.isNotEmpty
                                  ? 'Battery: $_batteryLevel · syncing data…'
                                  : 'syncing data now…',
                              style: TextStyle(
                                fontFamily: 'DM Sans',
                                fontSize: 11,
                                color: Colors.white.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white70,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // ── CONTINUE button (device flow only) ──
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _fitbitConnected
                      ? () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => const DashboardScreen(),
                            ),
                          );
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.transparent,
                    disabledForegroundColor: Colors.white70,
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: _fitbitConnected
                          ? const LinearGradient(
                              colors: [Color(0xFF4338CA), Color(0xFF7C3AED)],
                            )
                          : const LinearGradient(
                              colors: [Color(0xFFBDB8E8), Color(0xFFD6D2F5)],
                            ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: _fitbitConnected
                          ? [
                              BoxShadow(
                                color: const Color(0xFF4338CA).withOpacity(0.35),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ]
                          : [],
                    ),
                    child: Container(
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _fitbitConnected
                                ? 'CONTINUE'
                                : 'CONNECT FITBIT TO CONTINUE',
                            style: const TextStyle(
                              fontFamily: 'DM Sans',
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              letterSpacing: 1,
                              color: Colors.white,
                            ),
                          ),
                          if (_fitbitConnected) ...[
                            const SizedBox(width: 8),
                            const Text(
                              '→',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _deviceTile(_Device device, int index) {
    final bool selected = _selectedDevice == index;

    return GestureDetector(
      onTap: () => setState(() => _selectedDevice = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF4338CA).withOpacity(0.06)
              : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? const Color(0xFF4338CA).withOpacity(0.3)
                : const Color(0xFFE5E7EB),
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFF4338CA).withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: device.statusColor,
                borderRadius: BorderRadius.circular(5),
                boxShadow: device.connected
                    ? [
                        BoxShadow(
                          color: device.statusColor.withOpacity(0.5),
                          blurRadius: 6,
                        ),
                      ]
                    : null,
              ),
            ),
            const SizedBox(width: 14),

            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF4338CA).withOpacity(0.1)
                    : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(device.emoji, style: const TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.name,
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: selected
                          ? const Color(0xFF1E1B4B)
                          : const Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    index == 0
                        ? (_fitbitConnected
                            ? _fitbitDeviceName
                            : (_isConnecting
                                ? 'Connecting…'
                                : 'Tap to connect'))
                        : device.subtitle,
                    style: TextStyle(
                      fontFamily: 'DM Sans',
                      fontSize: 11.5,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),

            if (selected)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4338CA), Color(0xFF7C3AED)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 14),
              )
            else
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFD1D5DB),
                    width: 2,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Device {
  final String name;
  final String subtitle;
  final String emoji;
  final Color statusColor;
  final bool connected;

  _Device({
    required this.name,
    required this.subtitle,
    required this.emoji,
    required this.statusColor,
    required this.connected,
  });
}