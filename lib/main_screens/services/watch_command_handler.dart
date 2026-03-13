import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:watch_connectivity/watch_connectivity.dart';

import '../../free_running/free_running_start.dart';
import '../../ghostrun_screen/FirstGhostRun_Tracking.dart';
import '../../ghostrun_screen/GhostRun_TrackingPage.dart';
import '../../core/constants/firestore_paths.dart';

/// WatchOS 연결을 통해 수신되는 명령을 처리합니다.
///
/// 기존 [MainScreen]의 _initializeWatchConnectivity() 와
/// _getLatestGhostRecord() 로직을 분리했습니다.
class WatchCommandHandler {
  final WatchConnectivity _watch;
  final BuildContext Function() _contextGetter;

  StreamSubscription<Map<String, dynamic>>? _subscription;

  WatchCommandHandler({
    required WatchConnectivity watch,
    required BuildContext Function() contextGetter,
  })  : _watch = watch,
        _contextGetter = contextGetter;

  void start() {
    _subscription?.cancel();
    _subscription = _watch.messageStream.listen(_handleMessage);
  }

  void stop() {
    _subscription?.cancel();
  }

  Future<void> _handleMessage(Map<String, dynamic> message) async {
    if (!message.containsKey('command')) return;

    final command = message['command'] as String;
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      _watch.sendMessage({'error': 'loginRequired'});
      return;
    }

    final ctx = _contextGetter();

    switch (command) {
      case 'startRunningFromWatch':
        Navigator.push(
          ctx,
          MaterialPageRoute(builder: (_) => RunningPage(withWatch: true)),
        );
        break;

      case 'startGhostRunFromWatch':
        final latestGhostRecord = await _getLatestGhostRecord();
        if (!ctx.mounted) return;
        if (latestGhostRecord == null) {
          Navigator.push(
            ctx,
            MaterialPageRoute(
              builder: (_) => FirstGhostRunTrackingPage(withWatch: true),
            ),
          );
        } else {
          Navigator.push(
            ctx,
            MaterialPageRoute(
              builder: (_) => GhostRunTrackingPage(
                ghostRunData: latestGhostRecord,
                withWatch: true,
              ),
            ),
          );
        }
        break;
    }
  }

  Future<Map<String, dynamic>?> _getLatestGhostRecord() async {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null) return null;

    try {
      final userDoc = await FirebaseFirestore.instance
          .doc(FirestorePaths.ghostRunUserDoc(email))
          .get();

      if (!userDoc.exists) return null;

      final latestId = userDoc.data()?['latestRecordId'] as String?;
      if (latestId == null) return null;

      final recordDoc = await FirebaseFirestore.instance
          .collection(FirestorePaths.ghostRunRecords)
          .doc(email)
          .collection('records')
          .doc(latestId)
          .get();

      if (!recordDoc.exists) return null;
      final data = recordDoc.data()!;
      data['id'] = recordDoc.id;
      return data;
    } catch (_) {
      return null;
    }
  }
}
