// fitbit_service.dart
//
// Wires the FITBIT_PROJECT/fitbit Flutter front-end to the Carebit_ Cloud
// Functions backend.  This file is the ONLY place that knows the backend URL
// and the Fitbit redirect URI — keep them in sync with the backend .env:
//   FITBIT_REDIRECT_URI = carebit://fitbit-callback
//
// ─── Backend endpoints (Cloud Functions) ────────────────────────────────────
//   GET  /fitbitAuthStart?mode=json        → {ok, authUrl, redirectUri, scopes}
//   POST /fitbitAuthCallback               → {ok, reused, device, documentIds}
//   GET  /fitbitAuthCallbackStatus?state=… → {ok, status, device?, error?}
//   GET  /fitbitDevices                    → {ok, devices}
//   GET  /fitbitHealthMetrics              → {ok, metrics}
// ────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'package:http/http.dart' as http;

// Carebit Firebase Functions base URL
// using local emulator because cloud deploy permission was denied.
const _kBaseUrl = 'http://10.0.2.2:5002/fitbit-project-58078/us-central1';
// ────────────────────────────────────────────────────────────────────────────

/// The custom URI scheme that Fitbit redirects back to after OAuth.
/// Must match FITBIT_REDIRECT_URI in the backend .env exactly.
const kFitbitRedirectScheme = 'carebit';
const kFitbitRedirectUri = 'carebit://fitbit-callback';

// ── Data model returned after a successful Fitbit connection ─────────────────

class FitbitDevice {
  const FitbitDevice({
    required this.deviceId,
    required this.deviceName,
    required this.documentId,
    required this.connectedAt,
    required this.manufacturer,
    required this.source,
    this.firmwareVersion,
    this.metadata = const {},
  });

  final String deviceId;
  final String deviceName;
  final String documentId;
  final String connectedAt;
  final String manufacturer;
  final String source;
  final String? firmwareVersion;
  final Map<String, dynamic> metadata;

  factory FitbitDevice.fromJson(Map<String, dynamic> json) {
    return FitbitDevice(
      deviceId: json['deviceId'] as String? ?? '',
      deviceName: json['deviceName'] as String? ?? 'Fitbit Device',
      documentId: json['documentId'] as String? ?? '',
      connectedAt: json['connectedAt'] as String? ?? '',
      manufacturer: json['manufacturer'] as String? ?? 'Fitbit',
      source: json['source'] as String? ?? 'fitbit',
      firmwareVersion: json['firmwareVersion'] as String?,
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
    );
  }

  String get batteryLevel {
    final level = metadata['batteryLevel'];
    if (level is num) return '${level.toInt()}%';
    final battery = metadata['battery'];
    if (battery is String && battery.isNotEmpty) return battery;
    return 'Unknown';
  }
}

// ── FitbitService ─────────────────────────────────────────────────────────────

class FitbitService {
  FitbitService._();
  static final FitbitService instance = FitbitService._();

  // ── 1. Get the OAuth URL from the backend ──────────────────────────────────

  /// Returns the Fitbit OAuth URL to open in a browser, along with the
  /// `state` parameter that must be forwarded back in [exchangeCallback].
  Future<({String authUrl, String state})> getAuthUrl() async {
    // Generate a unique state for this login session
    final generatedState = DateTime.now().millisecondsSinceEpoch.toString();
    
    final uri = Uri.parse('$_kBaseUrl/fitbitAuthStart').replace(
      queryParameters: {'mode': 'json', 'state': generatedState},
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    final body = _parseBody(response);

    if (body['ok'] != true) {
      throw FitbitServiceException(
        body['error'] as String? ?? 'Could not start Fitbit authorisation.',
      );
    }

    final authUrl = body['authUrl'] as String?;
    if (authUrl == null || authUrl.isEmpty) {
      throw const FitbitServiceException('Backend returned no auth URL.');
    }

    // Return the generated state alongside the url
    return (authUrl: authUrl, state: generatedState);
  }

  // ── 2. Exchange the OAuth callback code for tokens ─────────────────────────

  /// Called after the Fitbit OAuth redirect arrives. Sends the [code] and
  /// [state] to the backend and gets a [FitbitDevice] back on success.
  ///
  /// [idToken] is the Firebase ID token of the currently signed-in user.
  Future<FitbitDevice> exchangeCallback({
    required String code,
    required String state,
    required String idToken,
  }) async {
    final uri = Uri.parse('$_kBaseUrl/fitbitAuthCallback');
    final response = await http
        .post(
          uri,
          headers: {
            'Authorization': 'Bearer $idToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'code': code, 'state': state}),
        )
        .timeout(const Duration(seconds: 30));

    final body = _parseBody(response);

    if (body['ok'] != true) {
      throw FitbitServiceException(
        body['error'] as String? ?? 'Fitbit token exchange failed.',
      );
    }

    final deviceJson = body['device'] as Map<String, dynamic>?;
    if (deviceJson == null) {
      throw const FitbitServiceException('Backend returned no device data.');
    }

    return FitbitDevice.fromJson(deviceJson);
  }

  // ── 3. Poll the callback status ────────────────────────────────────────────

  /// Polls until the backend reports `succeeded` or `failed`.
  /// Useful when there is a race between the redirect arriving and the backend
  /// finishing persistence.
  ///
  /// [idToken] is the Firebase ID token of the currently signed-in user.
  Future<FitbitDevice> pollCallbackStatus({
    required String state,
    required String idToken,
    int maxAttempts = 12,
    Duration interval = const Duration(seconds: 2),
  }) async {
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final uri = Uri.parse('$_kBaseUrl/fitbitAuthCallbackStatus').replace(
        queryParameters: {'state': state},
      );
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $idToken'},
      ).timeout(const Duration(seconds: 15));

      final body = _parseBody(response);

      if (body['ok'] != true) {
        throw FitbitServiceException(
          body['error'] as String? ?? 'Could not read callback status.',
        );
      }

      final status = body['status'] as String?;

      if (status == 'succeeded') {
        final deviceJson = body['device'] as Map<String, dynamic>?;
        if (deviceJson != null) return FitbitDevice.fromJson(deviceJson);
      }

      if (status == 'failed') {
        throw FitbitServiceException(
          body['error'] as String? ?? 'Fitbit connection failed.',
        );
      }

      // status == 'processing' or 'not_found': wait and retry
      if (attempt < maxAttempts - 1) {
        await Future.delayed(interval);
      }
    }

    throw const FitbitServiceException(
      'Fitbit connection timed out. Try connecting again.',
    );
  }

  // ── 4. Fetch raw device list (optional / debug) ───────────────────────────

  /// Fetches the list of Fitbit devices using a Fitbit [accessToken].
  Future<List<dynamic>> fetchDevices(String accessToken) async {
    final uri = Uri.parse('$_kBaseUrl/fitbitDevices');
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    ).timeout(const Duration(seconds: 15));

    final body = _parseBody(response);
    if (body['ok'] != true) {
      throw FitbitServiceException(
        body['error'] as String? ?? 'Could not fetch Fitbit devices.',
      );
    }

    return body['devices'] as List<dynamic>? ?? [];
  }

  // ── 5. Fetch health metrics ───────────────────────────────────────────────

  /// Fetches today's health metrics (heart rate, sleep, SpO2, profile).
  /// Requires a valid Fitbit [accessToken].
  Future<Map<String, dynamic>> fetchHealthMetrics(String accessToken) async {
    final uri = Uri.parse('$_kBaseUrl/fitbitHealthMetrics');
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    ).timeout(const Duration(seconds: 20));

    final body = _parseBody(response);
    if (body['ok'] != true) {
      throw FitbitServiceException(
        body['error'] as String? ?? 'Could not fetch health metrics.',
      );
    }

    return (body['metrics'] as Map<String, dynamic>?) ?? {};
  }

  // ── Internal helpers ──────────────────────────────────────────────────────

  Map<String, dynamic> _parseBody(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}

    // If the server returned a non-JSON error (e.g. 502 from the proxy):
    throw FitbitServiceException(
      'Unexpected server response (${response.statusCode}). '
      'Check the backend URL in fitbit_service.dart.',
    );
  }
}

// ── Exception type ────────────────────────────────────────────────────────────

class FitbitServiceException implements Exception {
  const FitbitServiceException(this.message);
  final String message;

  @override
  String toString() => 'FitbitServiceException: $message';
}
