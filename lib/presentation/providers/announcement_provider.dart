import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import '../../core/constants/firestore_paths.dart';

/// 메인 화면 공지사항 팝업을 관리하는 Provider 입니다.
///
/// 기존 [MainScreen]에 직접 구현되어 있던
/// _listenForMainAnnouncements / _hideAnnouncementForToday 로직을 분리했습니다.
class AnnouncementProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore;

  AnnouncementProvider({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // ── State ──────────────────────────────────────────────
  List<DocumentSnapshot> _announcements = [];
  Set<String> _hiddenToday = {};
  bool _dialogShown = false;

  List<DocumentSnapshot> get announcements => _announcements;
  bool get dialogShown => _dialogShown;

  // ── Streams ────────────────────────────────────────────
  StreamSubscription? _announcementSub;

  // ── Public API ─────────────────────────────────────────

  Future<void> initialize() async {
    await _loadHiddenFromPrefs();
    _startListening();
  }

  void markDialogShown() {
    _dialogShown = true;
  }

  void markDialogClosed() {
    _dialogShown = false;
    notifyListeners();
  }

  /// 특정 공지를 "오늘 하루 안 보기" 처리합니다.
  Future<void> hideToday(String announcementId) async {
    final prefs = await SharedPreferences.getInstance();
    final todayKey = _todayKey();
    _hiddenToday.add(announcementId);
    await prefs.setStringList(todayKey, _hiddenToday.toList());

    _announcements.removeWhere((doc) => doc.id == announcementId);
    notifyListeners();
  }

  @override
  void dispose() {
    _announcementSub?.cancel();
    super.dispose();
  }

  // ── Private ────────────────────────────────────────────

  static String _todayKey() =>
      'hiddenAnnouncements_${DateFormat('yyyy-MM-dd').format(DateTime.now())}';

  Future<void> _loadHiddenFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final hiddenIds = prefs.getStringList(_todayKey()) ?? [];
    _hiddenToday = hiddenIds.toSet();
  }

  void _startListening() {
    _announcementSub?.cancel();
    _announcementSub = _firestore
        .collection(FirestorePaths.mainAnnouncements)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      final filtered = snapshot.docs
          .where((doc) => !_hiddenToday.contains(doc.id))
          .toList();

      _announcements = filtered;
      if (filtered.isNotEmpty && !_dialogShown) {
        notifyListeners();
      }
    });
  }
}
