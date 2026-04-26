import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'community_service.dart';
import 'invite_to_group_screen.dart';

class CommunityInviteCoordinator {
  CommunityInviteCoordinator(this.navigatorKey);

  final GlobalKey<NavigatorState> navigatorKey;

  AppLinks? _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  StreamSubscription<User?>? _authSubscription;
  bool _isPresentingInvite = false;

  Future<void> start() async {
    _appLinks = AppLinks();

    final initialUri = await _appLinks!.getInitialLink();
    if (initialUri != null) {
      await _handleUri(initialUri);
    }

    _linkSubscription = _appLinks!.uriLinkStream.listen((uri) {
      _handleUri(uri);
    }, onError: (_) {});

    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _presentPendingInviteIfNeeded();
      }
    });

    await _presentPendingInviteIfNeeded();
  }

  Future<void> dispose() async {
    await _linkSubscription?.cancel();
    await _authSubscription?.cancel();
  }

  Future<void> _handleUri(Uri uri) async {
    if (!CommunityService.instance.isCommunityInviteUri(uri)) {
      return;
    }

    await CommunityService.instance.persistPendingInviteFromUri(uri);
    await _presentPendingInviteIfNeeded();
  }

  Future<void> _presentPendingInviteIfNeeded() async {
    if (_isPresentingInvite || FirebaseAuth.instance.currentUser == null) {
      return;
    }

    final pendingInvite = await CommunityService.instance.readPendingInvite();
    if (pendingInvite == null) {
      return;
    }

    final navigator = navigatorKey.currentState;
    if (navigator == null || !navigator.mounted) {
      return;
    }

    _isPresentingInvite = true;
    try {
      await navigator.push(
        MaterialPageRoute(
          builder: (_) => InviteToGroupScreen(
            inviteId: pendingInvite.inviteId,
            inviteToken: pendingInvite.token,
          ),
        ),
      );
    } finally {
      _isPresentingInvite = false;
    }
  }
}
