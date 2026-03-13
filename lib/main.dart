import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:app_badge_plus/app_badge_plus.dart';

import 'home_screens/auth_wrapper.dart';
import 'services/presence_service.dart';
import 'services/navigation_service.dart';
import 'services/fcm_service.dart';
import 'services/admin_presence_service.dart';
import 'presentation/providers/notification_badge_provider.dart';
import 'presentation/providers/announcement_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
    overlays: [SystemUiOverlay.top],
  );

  await Firebase.initializeApp();
  await FirebaseFirestore.instance.enableNetwork();
  await initializeDateFormatting('ko_KR', null);

  // FCM 초기화 (토큰 저장, 알림 핸들러 등록)
  await FcmService.initialize();

  // 앱 배지 초기화
  try {
    await AppBadgePlus.updateBadge(0);
  } catch (_) {}

  runApp(const MyApp());
}

// ─────────────────────────────────────────────────────────────────────────────
// MyApp: Provider 등록 + 앱 생명주기 관리
// ─────────────────────────────────────────────────────────────────────────────

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppBadgePlus.updateBadge(0);

    // 로그인/로그아웃 시 Presence & 관리자 상태 갱신
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        AdminPresenceService.update(isOnline: true);
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
    if (state == AppLifecycleState.resumed) {
      AppBadgePlus.updateBadge(0);
      AdminPresenceService.update(isOnline: true);
      PresenceService.connect();
    } else {
      AdminPresenceService.update(isOnline: false);
      PresenceService.disconnect();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NotificationBadgeProvider()),
        ChangeNotifierProvider(create: (_) => AnnouncementProvider()),
      ],
      child: MaterialApp(
        title: 'Rundventure',
        navigatorKey: NavigationService.navigatorKey,
        debugShowCheckedModeBanner: false,
        home: const AuthWrapper(),
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
        supportedLocales: const [Locale('ko', 'KR')],
        locale: const Locale('ko', 'KR'),
      ),
    );
  }
}