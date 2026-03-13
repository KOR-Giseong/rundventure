import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/constants/firestore_paths.dart';
import 'navigation_service.dart';
import '../Notification/user_notification.dart';

/// FCM(Firebase Cloud Messaging) 관련 초기화, 토큰 저장, 알림 핸들러를
/// 한 곳에서 관리하는 서비스입니다.
///
/// main.dart 에서 직접 FCM 코드를 작성하던 것을 이 클래스로 캡슐화했습니다.
class FcmService {
  FcmService._();

  // ── Public API ───────────────────────────────────────────

  /// 앱 시작 시 한 번 호출하세요.
  static Future<void> initialize() async {
    final messaging = FirebaseMessaging.instance;

    await messaging.requestPermission();

    // 초기 토큰 저장
    final token = await messaging.getToken();
    await _saveTokenToFirestore(token);

    // 토큰 갱신 시 자동 저장
    messaging.onTokenRefresh.listen(_saveTokenToFirestore);

    // 백그라운드 핸들러 등록
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 포그라운드 알림
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // 알림 클릭 (백그라운드 → 앱 열기)
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

    // 앱이 완전히 종료된 상태에서 알림 클릭
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      await _saveNotificationToFirestore(initialMessage);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (initialMessage.data['screen'] == 'UserNotificationPage') {
          NavigationService.navigatorKey.currentState?.push(
            MaterialPageRoute(builder: (_) => UserNotificationPage()),
          );
        }
      });
    }

    // Auth 상태 변경 시 토픽 구독/해제
    FirebaseAuth.instance.authStateChanges().listen(_onAuthStateChanged);
  }

  // ── Private helpers ───────────────────────────────────────

  /// FCM 토큰을 Firestore users/{email} 문서에 저장합니다.
  static Future<void> _saveTokenToFirestore(String? token) async {
    if (token == null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;

    try {
      await FirebaseFirestore.instance
          .collection(FirestorePaths.users)
          .doc(user.email!)
          .set({'fcmToken': token}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('❌ FCM 토큰 저장 오류: $e');
    }
  }

  /// Firestore notifications/{email}/items 에 알림 문서를 저장합니다.
  static Future<void> _saveNotificationToFirestore(
      RemoteMessage message) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;

    final expirySeconds =
        int.tryParse(message.data['expiry'] ?? '');
    final expiryTime = expirySeconds != null
        ? DateTime.now().add(Duration(seconds: expirySeconds))
        : null;

    final data = {
      'title': message.notification?.title ?? '알림',
      'message': message.notification?.body ?? '내용 없음',
      'timestamp': DateTime.now().toIso8601String(),
      'expiry': expiryTime?.toIso8601String(),
      'isRead': false,
    };

    await FirebaseFirestore.instance
        .collection(FirestorePaths.notifications)
        .doc(user.email!)
        .collection('items')
        .add(data);
  }

  /// 포그라운드 알림 처리 (다이얼로그 표시)
  static void _onForegroundMessage(RemoteMessage message) {
    if (message.notification == null) return;

    _saveNotificationToFirestore(message);

    final ctx = NavigationService.navigatorKey.currentContext;
    if (ctx == null) return;

    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: Text(message.notification!.title ?? '알림'),
        content: Text(message.notification!.body ?? '내용 없음'),
        actions: [
          TextButton(
            onPressed: () =>
                NavigationService.navigatorKey.currentState?.pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  /// 백그라운드에서 알림을 클릭하여 앱을 열었을 때 처리
  static void _onMessageOpenedApp(RemoteMessage message) {
    _saveNotificationToFirestore(message);
    if (message.data['screen'] == 'UserNotificationPage') {
      NavigationService.navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => UserNotificationPage()),
      );
    }
  }

  /// Auth 변경 시 FCM 토픽 구독/해제
  static Future<void> _onAuthStateChanged(User? user) async {
    final messaging = FirebaseMessaging.instance;
    if (user != null) {
      final token = await messaging.getToken();
      await _saveTokenToFirestore(token);
      try {
        await messaging.subscribeToTopic('all');
      } catch (e) {
        debugPrint('❌ FCM 토픽 구독 실패: $e');
      }
    } else {
      try {
        await messaging.unsubscribeFromTopic('all');
      } catch (e) {
        debugPrint('❌ FCM 토픽 구독 취소 실패: $e');
      }
    }
  }
}

/// 백그라운드 메시지 핸들러 (top-level 함수여야 함)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('📥 백그라운드 알림: ${message.notification?.title}');

  // 중복 방지는 앱 재시작 시 초기화되므로 실용적인 방어만 진행
  final user = FirebaseAuth.instance.currentUser;
  if (user == null || user.email == null) return;

  final expirySeconds = int.tryParse(message.data['expiry'] ?? '');
  final expiryTime = expirySeconds != null
      ? DateTime.now().add(Duration(seconds: expirySeconds))
      : null;

  await FirebaseFirestore.instance
      .collection(FirestorePaths.notifications)
      .doc(user.email!)
      .collection('items')
      .add({
    'title': message.notification?.title ?? '알림',
    'message': message.notification?.body ?? '내용 없음',
    'timestamp': DateTime.now().toIso8601String(),
    'expiry': expiryTime?.toIso8601String(),
    'isRead': false,
  });
}
