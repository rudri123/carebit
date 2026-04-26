import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProfileService {
  UserProfileService._();

  static final UserProfileService instance = UserProfileService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> syncCurrentUserProfile({User? user}) async {
    final targetUser = user ?? FirebaseAuth.instance.currentUser;
    if (targetUser == null) {
      return;
    }

    final userRef = _firestore.collection('users').doc(targetUser.uid);
    final snapshot = await userRef.get();

    final displayName = (targetUser.displayName ?? '').trim();
    final email = (targetUser.email ?? '').trim();
    final now = FieldValue.serverTimestamp();
    final payload = <String, dynamic>{
      'displayName': displayName.isEmpty ? email.split('@').first : displayName,
      'email': email,
      'emailLower': email.toLowerCase(),
      'photoURL': targetUser.photoURL,
      'updatedAt': now,
    };

    if (!snapshot.exists) {
      payload['createdAt'] = now;
      payload['groupIds'] = <String>[];
    }

    await userRef.set(payload, SetOptions(merge: true));
  }
}
