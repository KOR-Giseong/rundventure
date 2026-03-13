import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../core/constants/firestore_paths.dart';

/// 관리자 온라인 상태를 Firebase Realtime Database 에 기록하는 서비스입니다.
/// (일반 유저 상태는 [PresenceService] 가 담당합니다.)
class AdminPresenceService {
  AdminPresenceService._();

  static Future<void> update({required bool isOnline}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final idTokenResult = await user.getIdTokenResult(true);
      if (idTokenResult.claims?['isAdmin'] != true) return;

      String nickname = user.email ?? '알 수 없음';
      final userDoc = await FirebaseFirestore.instance
          .collection(FirestorePaths.users)
          .doc(user.email!)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data() ?? {};
        if (data.containsKey('nickname')) {
          nickname = data['nickname'] as String;
        }
      }

      final adminStatusRef = FirebaseDatabase.instance
          .ref('${FirestorePaths.adminStatus}/${user.uid}');

      final presenceData = {
        'isOnline': isOnline,
        'email': user.email,
        'nickname': nickname,
        'lastSeen': ServerValue.timestamp,
      };

      if (isOnline) {
        await adminStatusRef
            .onDisconnect()
            .set({...presenceData, 'isOnline': false});
        await adminStatusRef.set(presenceData);
      } else {
        await adminStatusRef.set(presenceData);
      }
    } catch (e) {
      debugPrint('관리자 상태 업데이트 오류: $e');
    }
  }
}
