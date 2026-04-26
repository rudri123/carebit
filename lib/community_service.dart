import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Keep this aligned with the Firebase Functions emulator / deployed backend.
const _kCommunityBaseUrl =
    'http://10.0.2.2:5002/fitbit-project-58078/us-central1';
const _kPendingInviteIdKey = 'pending_community_invite_id';
const _kPendingInviteTokenKey = 'pending_community_invite_token';

class CommunityGroupOption {
  const CommunityGroupOption({required this.id, required this.name});

  final String id;
  final String name;
}

class FirebaseCommunityMember {
  const FirebaseCommunityMember({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.groupIds,
    required this.groupNames,
    this.photoUrl,
  });

  final String uid;
  final String displayName;
  final String email;
  final List<String> groupIds;
  final List<String> groupNames;
  final String? photoUrl;
}

class CommunityInviteDetails {
  const CommunityInviteDetails({
    required this.groupName,
    required this.invitedEmail,
    required this.inviterName,
    required this.expiresAt,
  });

  final String groupName;
  final String invitedEmail;
  final String inviterName;
  final DateTime expiresAt;
}

class PendingCommunityInvite {
  const PendingCommunityInvite({required this.inviteId, required this.token});

  final String inviteId;
  final String token;
}

class CommunityServiceException implements Exception {
  const CommunityServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CommunityService {
  CommunityService._();

  static final CommunityService instance = CommunityService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool isCommunityInviteUri(Uri uri) {
    return uri.scheme == 'carebit' && uri.host == 'community-invite';
  }

  Future<void> persistPendingInviteFromUri(Uri uri) async {
    if (!isCommunityInviteUri(uri)) return;

    final inviteId = uri.queryParameters['inviteId']?.trim();
    final token = uri.queryParameters['token']?.trim();
    if (inviteId == null ||
        inviteId.isEmpty ||
        token == null ||
        token.isEmpty) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPendingInviteIdKey, inviteId);
    await prefs.setString(_kPendingInviteTokenKey, token);
  }

  Future<PendingCommunityInvite?> readPendingInvite() async {
    final prefs = await SharedPreferences.getInstance();
    final inviteId = prefs.getString(_kPendingInviteIdKey)?.trim();
    final token = prefs.getString(_kPendingInviteTokenKey)?.trim();
    if (inviteId == null ||
        inviteId.isEmpty ||
        token == null ||
        token.isEmpty) {
      return null;
    }

    return PendingCommunityInvite(inviteId: inviteId, token: token);
  }

  Future<void> clearPendingInvite() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPendingInviteIdKey);
    await prefs.remove(_kPendingInviteTokenKey);
  }

  Future<List<CommunityGroupOption>> fetchCurrentUserGroups() async {
    final user = _auth.currentUser;
    if (user == null) {
      return const [];
    }

    final snapshot = await _firestore.collection('users').doc(user.uid).get();
    final groupIds = _stringList(snapshot.data()?['groupIds']);
    if (groupIds.isEmpty) {
      return const [];
    }

    final groups = await Future.wait(
      groupIds.map(
        (groupId) =>
            _firestore.collection('community_groups').doc(groupId).get(),
      ),
    );

    return groups
        .where((doc) => doc.exists)
        .map(
          (doc) => CommunityGroupOption(
            id: doc.id,
            name: (doc.data()?['name'] as String?)?.trim().isNotEmpty == true
                ? (doc.data()!['name'] as String).trim()
                : 'Care Circle',
          ),
        )
        .toList()
      ..sort(
        (left, right) =>
            left.name.toLowerCase().compareTo(right.name.toLowerCase()),
      );
  }

  Future<List<FirebaseCommunityMember>> loadCommunityMembers() async {
    final user = _auth.currentUser;
    if (user == null) {
      return const [];
    }

    final userSnapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .get();
    final groupIds = _stringList(userSnapshot.data()?['groupIds']);
    if (groupIds.isEmpty) {
      return const [];
    }

    final groupDocs = await Future.wait(
      groupIds.map(
        (groupId) =>
            _firestore.collection('community_groups').doc(groupId).get(),
      ),
    );
    final groupNamesById = <String, String>{};
    for (final doc in groupDocs) {
      if (!doc.exists) continue;
      final name = (doc.data()?['name'] as String?)?.trim();
      groupNamesById[doc.id] = name == null || name.isEmpty
          ? 'Care Circle'
          : name;
    }

    final memberMap = <String, FirebaseCommunityMember>{};

    for (final groupId in groupIds) {
      final memberships = await _firestore
          .collection('community_memberships')
          .where('groupId', isEqualTo: groupId)
          .get();

      for (final membership in memberships.docs) {
        final data = membership.data();
        final memberUid = (data['uid'] as String?)?.trim();
        if (memberUid == null || memberUid.isEmpty || memberUid == user.uid) {
          continue;
        }

        final displayName =
            (data['displayNameSnapshot'] as String?)?.trim().isNotEmpty == true
            ? (data['displayNameSnapshot'] as String).trim()
            : 'Community Member';
        final email = ((data['emailLower'] as String?) ?? '').trim();
        final groupName = groupNamesById[groupId] ?? 'Care Circle';
        final existing = memberMap[memberUid];

        if (existing == null) {
          memberMap[memberUid] = FirebaseCommunityMember(
            uid: memberUid,
            displayName: displayName,
            email: email,
            groupIds: [groupId],
            groupNames: [groupName],
          );
          continue;
        }

        final nextGroupIds = List<String>.from(existing.groupIds);
        if (!nextGroupIds.contains(groupId)) {
          nextGroupIds.add(groupId);
        }

        final nextGroupNames = List<String>.from(existing.groupNames);
        if (!nextGroupNames.contains(groupName)) {
          nextGroupNames.add(groupName);
        }

        memberMap[memberUid] = FirebaseCommunityMember(
          uid: existing.uid,
          displayName: existing.displayName,
          email: existing.email,
          groupIds: nextGroupIds,
          groupNames: nextGroupNames,
          photoUrl: existing.photoUrl,
        );
      }
    }

    final members = memberMap.values.toList()
      ..sort(
        (left, right) => left.displayName.toLowerCase().compareTo(
          right.displayName.toLowerCase(),
        ),
      );
    return members;
  }

  Future<void> createInvite({required String email, String? groupId}) async {
    final idToken = await _requireIdToken();
    final uri = Uri.parse('$_kCommunityBaseUrl/createCommunityInvite');
    final response = await http
        .post(
          uri,
          headers: {
            'Authorization': 'Bearer $idToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'email': email.trim(),
            if (groupId != null && groupId.trim().isNotEmpty)
              'groupId': groupId.trim(),
          }),
        )
        .timeout(const Duration(seconds: 20));

    final body = _parseBody(response);
    if (body['ok'] != true) {
      throw CommunityServiceException(
        body['error'] as String? ?? 'Could not send the invitation.',
      );
    }
  }

  Future<CommunityInviteDetails> fetchInviteDetails({
    required String inviteId,
    required String token,
  }) async {
    final uri = Uri.parse(
      '$_kCommunityBaseUrl/communityInviteDetails',
    ).replace(queryParameters: {'inviteId': inviteId, 'token': token});
    final response = await http.get(uri).timeout(const Duration(seconds: 20));
    final body = _parseBody(response);
    if (body['ok'] != true) {
      throw CommunityServiceException(
        body['error'] as String? ?? 'Could not read the invitation details.',
      );
    }

    final expiresAtValue = body['expiresAt'] as String?;
    final expiresAt = expiresAtValue == null
        ? DateTime.now().add(const Duration(days: 7))
        : DateTime.tryParse(expiresAtValue) ??
              DateTime.now().add(const Duration(days: 7));

    return CommunityInviteDetails(
      groupName: (body['groupName'] as String?)?.trim().isNotEmpty == true
          ? (body['groupName'] as String).trim()
          : 'Care Circle',
      invitedEmail: (body['invitedEmail'] as String?)?.trim() ?? '',
      inviterName: (body['inviterName'] as String?)?.trim().isNotEmpty == true
          ? (body['inviterName'] as String).trim()
          : 'A Carebit member',
      expiresAt: expiresAt,
    );
  }

  Future<void> acceptInvite({
    required String inviteId,
    required String token,
  }) async {
    final idToken = await _requireIdToken();
    final uri = Uri.parse('$_kCommunityBaseUrl/acceptCommunityInvite');
    final response = await http
        .post(
          uri,
          headers: {
            'Authorization': 'Bearer $idToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'inviteId': inviteId, 'token': token}),
        )
        .timeout(const Duration(seconds: 20));

    final body = _parseBody(response);
    if (body['ok'] != true) {
      throw CommunityServiceException(
        body['error'] as String? ?? 'Could not accept the invitation.',
      );
    }

    await clearPendingInvite();
  }

  Future<Map<String, dynamic>?> fetchCommunityMemberMetrics({
    required String memberUid,
  }) async {
    final idToken = await _requireIdToken();
    final uri = Uri.parse(
      '$_kCommunityBaseUrl/communityMemberMetrics',
    ).replace(queryParameters: {'memberUid': memberUid});
    final response = await http
        .get(uri, headers: {'Authorization': 'Bearer $idToken'})
        .timeout(const Duration(seconds: 20));

    final body = _parseBody(response);
    if (body['ok'] != true) {
      throw CommunityServiceException(
        body['error'] as String? ??
            'Could not fetch the member health metrics.',
      );
    }

    if (body['hasConnection'] == false) {
      return null;
    }

    return (body['metrics'] as Map<String, dynamic>?) ?? {};
  }

  Future<String> _requireIdToken() async {
    final idToken = await _auth.currentUser?.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw const CommunityServiceException(
        'Please sign in before using community features.',
      );
    }

    return idToken;
  }

  Map<String, dynamic> _parseBody(http.Response response) {
    if (response.body.isEmpty) {
      return const {};
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      return const {};
    }

    return const {};
  }

  List<String> _stringList(dynamic value) {
    if (value is! List) {
      return const [];
    }

    return value
        .whereType<String>()
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList();
  }
}
