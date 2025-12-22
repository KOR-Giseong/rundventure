import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:rundventure/home_Screens/home_screen2.dart';
import 'package:rundventure/Notification/user_notification.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import 'package:rundventure/main_screens/main_screen.dart';
import 'package:rundventure/services/presence_service.dart';
import 'package:app_badge_plus/app_badge_plus.dart'; // 배지 제어 패키지


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
    "timestamp": DateTime.now().toIso8601String(),
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
  if (user != null && user.email != null) {
    try {
      print("✅ FCM 토큰 Firestore에 저장 시도: ${user.email}");
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

  await FirebaseFirestore.instance.enableNetwork();
  await initializeDateFormatting('ko_KR', null);

  final messaging = FirebaseMessaging.instance;
  await messaging.requestPermission();

  final initialToken = await messaging.getToken();
  print("✅ 초기 FCM 토큰: $initialToken");
  await _saveTokenToFirestore(initialToken);

  messaging.onTokenRefresh.listen(_saveTokenToFirestore);

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

  FirebaseAuth.instance.authStateChanges().listen((User? user) async {
    if (user != null) {
      print("🔔 사용자 로그인 상태 확인됨: ${user.email}");
      final token = await messaging.getToken();
      await _saveTokenToFirestore(token);

      try {
        await messaging.subscribeToTopic('all');
        print("✅ 'all' 토픽 구독 성공");
      } catch (e) {
        print("❌ 'all' 토픽 구독 실패: $e");
      }

    } else {
      try {
        await messaging.unsubscribeFromTopic('all');
        print("✅ 'all' 토픽 구독 취소");
      } catch (e) {
        print("❌ 'all' 토픽 구독 취소 실패: $e");
      }
    }
  });

  try {
    await AppBadgePlus.updateBadge(0);
  } catch (e) {
    print("배지 초기화 실패 (기기 미지원 등): $e");
  }

  runApp(const MyApp());
}


class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}


class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    AppBadgePlus.updateBadge(0);

    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _updateAdminPresence(true);
        PresenceService.connect();
      } else {
        PresenceService.disconnect();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    PresenceService.disconnect();
    super.dispose();
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      PresenceService.handleAppLifecycleChange(state);
      return;
    }

    if (state == AppLifecycleState.resumed) {
      AppBadgePlus.updateBadge(0);
      _updateAdminPresence(true);
      PresenceService.connect();
    } else {
      _updateAdminPresence(false);
      PresenceService.disconnect();
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
          if (user != null && !user.emailVerified) {
            return Home_screen2();
          }
          return UserStatusWrapper();
        }

        return Home_screen2();
      },
    );
  }
}

class UserStatusWrapper extends StatelessWidget {
  const UserStatusWrapper({Key? key}) : super(key: key);

  Future<DocumentSnapshot> _checkUserStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      throw Exception("로그인한 사용자가 없습니다.");
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.email!)
          .get(const GetOptions(source: Source.server));

      return doc;

    } on FirebaseException catch (e) {
      print("❌ Firestore get() 오류: ${e.message}");
      throw Exception("계정 상태 확인 중 오류 발생: ${e.code}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: _checkUserStatus(),
      builder: (context, snapshot) {

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasError) {
          print("❌ UserStatusWrapper FutureBuilder 오류: ${snapshot.error}");
          return SuspendedScreen(reason: "계정 상태를 확인하는 중 오류가 발생했습니다. 앱을 다시 시작해주세요.");
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          print("❌ UserStatusWrapper: 서버에서 문서를 찾을 수 없습니다. 로그아웃합니다.");
          FirebaseAuth.instance.signOut();
          return Home_screen2();
        }

        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final bool isSuspended = data['isSuspended'] ?? false;
        final String reason = data['suspensionReason'] ?? '관리자에 의해 계정이 정지되었습니다.';

        if (isSuspended) {
          return SuspendedScreen(reason: reason);
        } else {
          return MainScreen(showWelcomeMessage: false);
        }
      },
    );
  }
}


class SuspendedScreen extends StatelessWidget {
  final String reason;
  const SuspendedScreen({Key? key, required this.reason}) : super(key: key);

  final String supportEmail = 'support@rundventure.co.kr';

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
                Icons.block_flipped,
                color: Colors.red.shade700,
                size: 60,
              ),
              SizedBox(height: 20),
              Text(
                "계정이 정지되었습니다.",
                style: TextStyle(
                  fontSize: 24,
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
              SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300)
                ),
                child: Text(
                  reason,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black87),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: 32),
              Text(
                "관련 문의는 아래 이메일로 보내주시기 바랍니다.",
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: supportEmail));
                  _showCustomSnackBar(context, '✅ 이메일 주소가 복사되었습니다.');
                },
                child: Text(
                  supportEmail,
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
                    backgroundColor: Colors.black87,
                    foregroundColor: Colors.white,
                    minimumSize: Size(180, 50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)
                    )
                ),
                onPressed: () async {
                  await PresenceService.disconnect();
                  await FirebaseAuth.instance.signOut();
                  _showCustomSnackBar(context, '로그아웃 되었습니다.');
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