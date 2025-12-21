// [전체 코드] main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';

// [ App Check 임포트 라인 제거됨 ]

import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ enableNetwork()를 위해 import
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:rundventure/home_Screens/home_screen2.dart';
import 'package:rundventure/Notification/user_notification.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async'; // ✅ [추가] StreamSubscription을 위해 추가
import 'package:rundventure/main_screens/main_screen.dart'; // ✅✅✅ [수정] MainScreen 임포트

// ▼▼▼▼▼ [ ✅ Part 10 신규 임포트 ] ▼▼▼▼▼
// (Part 9에서 생성한 PresenceService 임포트)
import 'package:rundventure/services/presence_service.dart';
// ▲▲▲▲▲ [ ✅ Part 10 신규 임포트 ] ▲▲▲▲▲

// ▼▼▼▼▼ [ ⭐️ 배지 제어 패키지 추가 ] ▼▼▼▼▼
import 'package:app_badge_plus/app_badge_plus.dart';
// ▲▲▲▲▲ [ ⭐️ 배지 제어 패키지 추가 ] ▲▲▲▲▲


final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
Set<String> receivedMessageKeys = {};

String generateUniqueKey(RemoteMessage message) {
  final title = message.notification?.title ?? 'no_title';
  final body = message.notification?.body ?? 'no_body';
  final timestamp = message.sentTime?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch;
  return '$title:$body:$timestamp';
}

Future<void> saveNotificationToFirestore(RemoteMessage message) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null || user.email == null) return;

  final expirySeconds = int.tryParse(message.data['expiry'] ?? '');
  final expiryTime = expirySeconds != null ? DateTime.now().add(Duration(seconds: expirySeconds)) : null;

  final data = {
    "title": message.notification?.title ?? "알림",
    "message": message.notification?.body ?? "내용 없음",
    "timestamp": DateTime.now().toIso8601String(), // 오타 수정됨
    "expiry": expiryTime?.toIso8601String(),
    "isRead": false,
  };

  await FirebaseFirestore.instance
      .collection('notifications')
      .doc(user.email!)
      .collection('items')
      .add(data);
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("📥 백그라운드 알림 수신됨: ${message.notification?.title}");
  final key = generateUniqueKey(message);
  if (receivedMessageKeys.contains(key)) return;
  receivedMessageKeys.add(key);
  await saveNotificationToFirestore(message);
}

/// 토큰을 Firestore에 저장하는 재사용 가능한 함수
Future<void> _saveTokenToFirestore(String? token) async {
  if (token == null) return;

  final user = FirebaseAuth.instance.currentUser;
  // 사용자가 로그인 상태이고, 이메일이 있을 때만 저장 로직 실행
  if (user != null && user.email != null) {
    try {
      print("✅ FCM 토큰 Firestore에 저장 시도: ${user.email}");
      // .update 대신 .set(merge: true)를 사용하여 더 안정적으로 처리
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.email!)
          .set({'fcmToken': token}, SetOptions(merge: true));
      print("✅ FCM 토큰 저장 완료.");
    } catch (e) {
      print("❌ Firestore 토큰 저장 오류: $e");
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky, overlays: [SystemUiOverlay.top]);

  await Firebase.initializeApp();

  // [ ⭐️ App Check 활성화 코드 제거됨 ⭐️ ]

  // ✅✅✅ [핵심 추가] ✅✅✅
  // 앱이 시작될 때 Firestore 네트워크를 항상 활성화합니다.
  // (로그아웃 시 profile_screen.dart에서 terminate()를 사용하기 때문)
  await FirebaseFirestore.instance.enableNetwork();
  // ✅✅✅ [추가 끝] ✅✅✅

  await initializeDateFormatting('ko_KR', null);

  // --- FCM 설정 ---
  final messaging = FirebaseMessaging.instance;

  await messaging.requestPermission();

  // 앱 시작 시 현재 토큰을 가져와서 저장 시도
  final initialToken = await messaging.getToken();
  print("✅ 초기 FCM 토큰: $initialToken");
  await _saveTokenToFirestore(initialToken);

  // 토큰이 갱신될 때마다 새로운 토큰을 Firestore에 저장
  messaging.onTokenRefresh.listen(_saveTokenToFirestore);

  // --- 알림 핸들러 ---
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    if (message.notification != null && navigatorKey.currentContext != null) {
      print('📢 포그라운드 알림: ${message.notification?.title}');
      saveNotificationToFirestore(message);

      showDialog(
        context: navigatorKey.currentContext!,
        builder: (_) => AlertDialog(
          title: Text(message.notification!.title ?? '알림'),
          content: Text(message.notification!.body ?? '내용 없음'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(navigatorKey.currentContext!).pop(),
              child: const Text('확인'),
            ),
          ],
        ),
      );
    }
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print('🔔 알림 클릭됨 (백그라운드): ${message.notification?.title}');
    saveNotificationToFirestore(message);
    if (message.data['screen'] == 'UserNotificationPage') {
      navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => UserNotificationPage()));
    }
  });

  RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null && initialMessage.data['screen'] == 'UserNotificationPage') {
    saveNotificationToFirestore(initialMessage);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => UserNotificationPage()),
      );
    });
  }

  // ▼▼▼▼▼ [ ⭐️⭐️⭐️ 여기가 수정된 부분입니다 ⭐️⭐️⭐️ ] ▼▼▼▼▼
  // [수정] 로그인/로그아웃 상태가 변경될 때마다 토큰 저장 *및 토픽 구독*을 실행
  FirebaseAuth.instance.authStateChanges().listen((User? user) async {
    // 'messaging' 변수는 main() 함수 상단에 이미 정의되어 있습니다.
    if (user != null) {
      // 1. (기존) 1:1 알림을 위한 토큰 저장
      print("🔔 사용자 로그인 상태 확인됨: ${user.email}");
      final token = await messaging.getToken();
      await _saveTokenToFirestore(token);

      // 2. ✅✅✅ [핵심 추가] ✅✅✅
      // 1:N 자동 알림을 위한 'all' 토픽 구독
      try {
        await messaging.subscribeToTopic('all');
        print("✅ 'all' 토픽 구독 성공");
      } catch (e) {
        print("❌ 'all' 토픽 구독 실패: $e");
      }

    } else {
      // 3. (선택 사항) 로그아웃 시 토픽 구독 취소
      try {
        await messaging.unsubscribeFromTopic('all');
        print("✅ 'all' 토픽 구독 취소");
      } catch (e) {
        print("❌ 'all' 토픽 구독 취소 실패: $e");
      }
    }
  });
  // ▲▲▲▲▲ [ ⭐️⭐️⭐️ 수정 끝 ⭐️⭐️⭐️ ] ▲▲▲▲▲

  // ▼▼▼▼▼ [ ⭐️ 앱 시작 시 배지 제거 (추가됨) ] ▼▼▼▼▼
  try {
    // 앱을 완전히 새로 켰을 때 배지를 0으로 초기화
    await AppBadgePlus.updateBadge(0);
  } catch (e) {
    print("배지 초기화 실패 (기기 미지원 등): $e");
  }
  // ▲▲▲▲▲ [ ⭐️ 앱 시작 시 배지 제거 ] ▲▲▲▲▲

  runApp(const MyApp());
}


class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

// ▼▼▼▼▼ [ ✅ Part 10 수정 (WidgetsBindingObserver는 이미 있음) ] ▼▼▼▼▼
class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // (기존 코드)

    // ▼▼▼▼▼ [ ⭐️ 앱 초기화 시 배지 제거 (추가됨) ] ▼▼▼▼▼
    AppBadgePlus.updateBadge(0);
    // ▲▲▲▲▲ [ ⭐️ 앱 초기화 시 배지 제거 ] ▲▲▲▲▲

    // ▼▼▼▼▼ [ ✅ Part 10 수정 (PresenceService 로직 추가) ] ▼▼▼▼▼
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _updateAdminPresence(true); // (기존) 관리자 상태
        PresenceService.connect();  // (신규) 일반 사용자 '온라인'
      } else {
        // (신규) 로그아웃 시 '오프라인' (관리자/일반 포함)
        PresenceService.disconnect();
      }
    });
    // ▲▲▲▲▲ [ ✅ Part 10 수정 ] ▲▲▲▲▲
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // (기존 코드)

    // ▼▼▼▼▼ [ ✅ Part 10 수정 (PresenceService 로직 추가) ] ▼▼▼▼▼
    // (앱이 완전히 종료될 때 '오프라인'으로 설정)
    PresenceService.disconnect();
    // ▲▲▲▲▲ [ ✅ Part 10 수정 ] ▲▲▲▲▲
    super.dispose();
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // ▼▼▼▼▼ [ ✅ Part 11 수정 (로그아웃 시에도 Presence 업데이트) ] ▼▼▼▼▼
      PresenceService.handleAppLifecycleChange(state); // 👈 로그아웃 상태에서도 disconnect 호출
      // ▲▲▲▲▲ [ ✅ Part 11 수정 ] ▲▲▲▲▲
      return;
    }

    if (state == AppLifecycleState.resumed) {
      // ▼▼▼▼▼ [ ⭐️ 앱으로 돌아왔을 때 배지 제거 (추가됨) ] ▼▼▼▼▼
      AppBadgePlus.updateBadge(0);
      // ▲▲▲▲▲ [ ⭐️ 앱으로 돌아왔을 때 배지 제거 ] ▲▲▲▲▲

      _updateAdminPresence(true); // (기존) 관리자
      // ▼▼▼▼▼ [ ✅ Part 11 수정 (PresenceService 호출) ] ▼▼▼▼▼
      PresenceService.connect(); // (신규) 일반 사용자 '온라인'
      // ▲▲▲▲▲ [ ✅ Part 11 수정 ] ▲▲▲▲▲
    } else {
      _updateAdminPresence(false); // (기존) 관리자
      // ▼▼▼▼▼ [ ✅ Part 11 수정 (PresenceService 호출) ] ▼▼▼▼▼
      PresenceService.disconnect(); // (신규) 일반 사용자 '오프라인'
      // ▲▲▲▲▲ [ ✅ Part 11 수정 ] ▲▲▲▲▲
    }
  }

  Future<void> _updateAdminPresence(bool isOnline) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final idTokenResult = await user.getIdTokenResult(true);
      final bool isAdmin = idTokenResult.claims?['isAdmin'] == true;

      if (!isAdmin) return;

      String nickname = user.email ?? '알 수 없음';
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.email!).get();
      if (userDoc.exists && (userDoc.data() as Map<String, dynamic>).containsKey('nickname')) {
        nickname = (userDoc.data() as Map<String, dynamic>)['nickname'];
      }

      final userEmail = user.email;
      final adminStatusRef = FirebaseDatabase.instance.ref('adminStatus/${user.uid}');

      final presenceData = {
        'isOnline': isOnline,
        'email': userEmail,
        'nickname': nickname,
        'lastSeen': ServerValue.timestamp,
      };

      if (isOnline) {
        await adminStatusRef.onDisconnect().set({
          ...presenceData,
          'isOnline': false,
        });
        await adminStatusRef.set(presenceData);
      } else {
        await adminStatusRef.set(presenceData);
      }
    } catch (e) {
      print("관리자 상태 업데이트 오류: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rundventure',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,

      // ✅ [수정] home을 AuthWrapper로 변경
      home: AuthWrapper(),

      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
          },
        ),
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ko', 'KR'),
      ],
      locale: const Locale('ko', 'KR'),
    );
  }
}

// ✅ 1. 로그인 상태 확인 (AuthWrapper) - [수정됨]
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // 로딩 중
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasData) {
          final user = snapshot.data;
          // ▼▼▼▼▼ [ ✅✅✅ 수정된 부분: 이메일 미인증 시 로그인 화면으로 이동 ] ▼▼▼▼▼
          if (user != null && !user.emailVerified) {
            // 이메일 인증이 안 된 경우, 자동으로 Home_screen2로 보내서
            // 다시 로그인(또는 인증) 절차를 밟게 함.
            // (로그인 시도 시 LoginScreen에서 인증 안내 다이얼로그가 뜸)
            return Home_screen2();
          }
          // ▲▲▲▲▲ [ ✅✅✅ 수정된 부분 ] ▲▲▲▲▲

          // 로그인이 되었고 인증도 완료된 경우, 정지 상태인지 확인
          return UserStatusWrapper();
        }

        // 로그인이 안 되었다면, 홈 스크린 (로그인 버튼이 있는 화면)으로 보냄
        return Home_screen2();
      },
    );
  }
}

// ✅✅✅ [ 2. UserStatusWrapper (FutureBuilder로 전체 교체) ] ✅✅✅
// 이 클래스 전체를 복사해서 붙여넣으세요.
class UserStatusWrapper extends StatelessWidget {
  const UserStatusWrapper({Key? key}) : super(key: key);

  // ✅ [신규] FutureBuilder가 호출할 함수
  // 캐시를 무시하고 서버에서 직접 데이터를 가져옵니다. (레이스 컨디션 해결)
  Future<DocumentSnapshot> _checkUserStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      // 이 경우는 AuthWrapper 로직 상 거의 발생하지 않지만, 방어 코드
      throw Exception("로그인한 사용자가 없습니다.");
    }

    try {
      // ✅ [핵심] GetOptions(source: Source.server)
      // 이 옵션이 캐시를 무시하고 서버에서 강제로 데이터를 가져오게 하여
      // "로그인 직후"에 발생하는 타이밍 버그를 해결합니다.
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.email!)
          .get(const GetOptions(source: Source.server));

      return doc;

    } on FirebaseException catch (e) {
      // (예: 보안 규칙 권한 없음, 네트워크 오류 등)
      print("❌ Firestore get() 오류: ${e.message}");
      // 오류가 나면 일단 정지된 것으로 처리하여 사용자에게 알림
      throw Exception("계정 상태 확인 중 오류 발생: ${e.code}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: _checkUserStatus(), // ✅ 위에서 만든 함수를 호출
      builder: (context, snapshot) {

        // 1. 데이터 로딩 중... (서버 응답 기다리는 중)
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // 2. 오류 발생 시 (네트워크, 권한 등)
        if (snapshot.hasError) {
          print("❌ UserStatusWrapper FutureBuilder 오류: ${snapshot.error}");
          // 오류가 발생하면, 안전을 위해 정지 화면을 표시합니다.
          // LoginScreen에서 로그인 직후 넘어올 때, 권한 전파가 1초 정도 늦어져서
          // "permission-denied" 오류가 발생할 수 있습니다.
          // 이 경우에도 Home_screen2로 보내는 대신, 정지 화면을 띄웁니다.
          return SuspendedScreen(reason: "계정 상태를 확인하는 중 오류가 발생했습니다. 앱을 다시 시작해주세요.");
        }

        // 3. 서버가 "문서 없음"이라고 응답한 경우 (계정 삭제됨)
        if (!snapshot.hasData || !snapshot.data!.exists) {
          print("❌ UserStatusWrapper: 서버에서 문서를 찾을 수 없습니다. 로그아웃합니다.");
          // 이런 경우는 없어야 하지만, 발생 시 로그아웃 처리
          // (혹시 모를 로그아웃 처리)
          FirebaseAuth.instance.signOut();
          return Home_screen2();
        }

        // 4. 서버가 정상적으로 데이터를 반환한 경우
        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final bool isSuspended = data['isSuspended'] ?? false;
        final String reason = data['suspensionReason'] ?? '관리자에 의해 계정이 정지되었습니다.';

        if (isSuspended) {
          // ✅ 4-1. 정지된 계정
          return SuspendedScreen(reason: reason);
        } else {
          // ✅ 4-2. 정상 계정
          return MainScreen(showWelcomeMessage: false);
        }
      },
    );
  }
}
// ✅✅✅ [ UserStatusWrapper 교체 끝 ] ✅✅✅


// ✅ 3. 정지 안내 화면 (SuspendedScreen) - (수정 없음)
class SuspendedScreen extends StatelessWidget {
  final String reason;
  const SuspendedScreen({Key? key, required this.reason}) : super(key: key);

  final String supportEmail = 'support@rundventure.co.kr'; // 👈 [수정] 이메일 주소 확인

  // ✅ [신규] 커스텀 스낵바 헬퍼 (StatelessWidget 내에서 Context 사용)
  void _showCustomSnackBar(BuildContext context, String message, {bool isError = false}) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.redAccent.shade400 : Colors.blueGrey.shade800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(15, 5, 15, 15),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.block_flipped, // 정지 아이콘
                color: Colors.red.shade700,
                size: 60, // ✅ [디자인] 아이콘 크기 살짝 줄임
              ),
              SizedBox(height: 20),
              Text(
                "계정이 정지되었습니다.",
                style: TextStyle(
                  fontSize: 24, // ✅ [디자인] 타이틀 크기 키움
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12),
              Text(
                "다음 사유로 인해 서비스 이용이 제한되었습니다:",
                style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16), // ✅ [디자인] 간격 추가
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16), // ✅ [디자인] 패딩 늘림
                decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12), // ✅ [디자인] 모서리 둥글게
                    border: Border.all(color: Colors.grey.shade300) // ✅ [디자인] 테두리 추가
                ),
                child: Text(
                  reason, // 👈 관리자가 입력한 정지 사유
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black87), // ✅ [디자인] 텍스트 색상
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: 32), // ✅ [디자인] 간격 늘림
              Text(
                "관련 문의는 아래 이메일로 보내주시기 바랍니다.",
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: supportEmail));
                  // ✅ [수정] 이메일 복사 시 커스텀 스낵바 사용
                  _showCustomSnackBar(context, '✅ 이메일 주소가 복사되었습니다.');
                },
                child: Text(
                  supportEmail, // 👈 문의 이메일
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              SizedBox(height: 40),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black87, // ✅ [디자인] 버튼 색상 변경
                    foregroundColor: Colors.white, // ✅ [디자인] 글자 색상 변경
                    minimumSize: Size(180, 50), // ✅ [디자인] 버튼 크기 키움
                    shape: RoundedRectangleBorder( // ✅ [디자인] 모서리 둥글게
                        borderRadius: BorderRadius.circular(12)
                    )
                ),
                // ✅ [수정] 로그아웃 시 커스텀 스낵바 표시
                onPressed: () async {
                  // ▼▼▼▼▼ [ ✅ Part 11 수정 (로그아웃 시 disconnect) ] ▼▼▼▼▼
                  // 1. '오프라인' 상태로 즉시 변경
                  await PresenceService.disconnect();
                  // 2. 로그아웃 실행
                  await FirebaseAuth.instance.signOut();
                  // 3. 스낵바 표시 (AuthWrapper가 화면 전환을 처리할 시간을 줌)
                  _showCustomSnackBar(context, '로그아웃 되었습니다.');
                  // ▲▲▲▲▲ [ ✅ Part 11 수정 ] ▲▲▲▲▲
                },
                child: Text('로그아웃', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}