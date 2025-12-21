import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart'; // AppLifecycleState

/// 사용자의 온라인/오프라인 상태를 Firebase Realtime Database(RTDB)에 관리하는 서비스
class PresenceService {

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseDatabase _database = FirebaseDatabase.instance;

  /// 이메일을 RTDB 경로 키로 변환 (Firestore Rules와 동일한 방식)
  static String _emailToKey(String email) {
    return email.replaceAll('.', '_dot_').replaceAll('@', '_at_');
  }

  /// 사용자가 앱에 연결되었을 때 (포그라운드 진입, 로그인 성공)
  static Future<void> connect() async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) return;

    final String userEmailKey = _emailToKey(user.email!);
    final DatabaseReference presenceRef =
    _database.ref('status/$userEmailKey');

    try {
      // 1. (필수) 연결이 끊어지면(앱 강제 종료, 네트워크 단절) 자동으로 'false'로 설정
      await presenceRef.onDisconnect().set(false);

      // 2. 현재 상태를 'true'로 설정
      await presenceRef.set(true);

      print("✅ [Presence] '$userEmailKey' 온라인 상태로 설정 (connect)");
    } catch (e) {
      print("🚨 [Presence] connect 실패: $e");
    }
  }

  /// 사용자가 앱 연결을 해제할 때 (백그라운드, 앱 종료, 로그아웃)
  static Future<void> disconnect() async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) return;

    final String userEmailKey = _emailToKey(user.email!);
    final DatabaseReference presenceRef =
    _database.ref('status/$userEmailKey');

    try {
      // 1. 현재 상태를 'false'로 설정 (onDisconnect보다 빠름)
      await presenceRef.set(false);

      print("⚪️ [Presence] '$userEmailKey' 오프라인 상태로 설정 (disconnect)");
    } catch (e) {
      print("🚨 [Presence] disconnect 실패: $e");
    }
  }

  /// 앱의 생명주기 변경을 처리
  static void handleAppLifecycleChange(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
      // 앱이 다시 활성화됨 (포그라운드)
        connect();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      // 앱이 비활성화됨 (백그라운드, 전화 수신, 앱 종료)
        disconnect();
        break;
      case AppLifecycleState.hidden:
      // (Flutter 3.13 이상) paused와 유사하게 처리
        disconnect();
        break;
    }
  }
}