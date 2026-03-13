import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../core/constants/firestore_paths.dart';

/// 메인 화면 상단/섹션에 표시되는 알림 배지(빨간 점) 상태를 관리합니다.
///
/// 기존 [MainScreen]에 흩어져 있던 4개의 StreamSubscription과
/// hasNewFriendRequests / hasNewChatMessages / hasNewAchievements /
/// hasUnclaimedQuests 상태를 하나의 Provider로 통합했습니다.
class NotificationBadgeProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  NotificationBadgeProvider({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  // ── State ──────────────────────────────────────────────
  bool _hasNewFriendRequests = false;
  bool _hasNewChatMessages = false;
  bool _hasNewAchievements = false;
  bool _hasUnclaimedQuests = false;

  bool get hasNewFriendRequests => _hasNewFriendRequests;
  bool get hasNewChatMessages => _hasNewChatMessages;
  bool get hasNewAchievements => _hasNewAchievements;
  bool get hasUnclaimedQuests => _hasUnclaimedQuests;

  /// 친구 섹션에 배지가 필요한지 여부
  bool get hasFriendBadge => _hasNewFriendRequests || _hasNewChatMessages;

  /// 업적/퀘스트 섹션에 배지가 필요한지 여부
  bool get hasAchievementBadge => _hasNewAchievements || _hasUnclaimedQuests;

  // ── Streams ────────────────────────────────────────────
  StreamSubscription? _friendRequestSub;
  StreamSubscription? _chatMessageSub;
  StreamSubscription? _achievementSub;
  StreamSubscription? _questSub;

  // ── Public API ─────────────────────────────────────────

  /// 로그인 후 스트림 구독을 시작합니다.
  void startListening() {
    final email = _auth.currentUser?.email;
    if (email == null) return;

    _listenFriendRequests(email);
    _listenChatMessages(email);
    _listenAchievements(email);
    _listenUnclaimedQuests(email);
  }

  /// 로그아웃 또는 dispose 시 호출합니다.
  void stopListening() {
    _friendRequestSub?.cancel();
    _chatMessageSub?.cancel();
    _achievementSub?.cancel();
    _questSub?.cancel();
  }

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }

  // ── Private listeners ──────────────────────────────────

  void _listenFriendRequests(String email) {
    _friendRequestSub?.cancel();
    _friendRequestSub = _firestore
        .collection(FirestorePaths.users)
        .doc(email)
        .collection('friendRequests')
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      _hasNewFriendRequests = snapshot.docs.isNotEmpty;
      notifyListeners();
    });
  }

  void _listenChatMessages(String email) {
    _chatMessageSub?.cancel();
    final myEmailKey =
        email.replaceAll('.', '_dot_').replaceAll('@', '_at_');

    _chatMessageSub = _firestore
        .collection(FirestorePaths.userChats)
        .where('participants', arrayContains: email)
        .where('isReadBy_$myEmailKey', isEqualTo: false)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      _hasNewChatMessages = snapshot.docs.isNotEmpty;
      notifyListeners();
    });
  }

  void _listenAchievements(String email) {
    _achievementSub?.cancel();
    _achievementSub = _firestore
        .collection(FirestorePaths.notifications)
        .doc(email)
        .collection('items')
        .where('isRead', isEqualTo: false)
        .where('type', isEqualTo: 'achievement_completed')
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      _hasNewAchievements = snapshot.docs.isNotEmpty;
      notifyListeners();
    });
  }

  void _listenUnclaimedQuests(String email) {
    _questSub?.cancel();
    _questSub = _firestore
        .collection(FirestorePaths.users)
        .doc(email)
        .collection('activeQuests')
        .where('isCompleted', isEqualTo: true)
        .where('isClaimed', isEqualTo: false)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      _hasUnclaimedQuests = snapshot.docs.isNotEmpty;
      notifyListeners();
    });
  }
}
