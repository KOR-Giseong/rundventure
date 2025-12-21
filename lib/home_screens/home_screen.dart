import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // [추가]
import '../login_screens/login_screen.dart';
import 'package:rundventure/sign_up/sign_up_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Home_screen2 extends StatefulWidget {
  @override
  _Home_screen2State createState() => _Home_screen2State();
}

class _Home_screen2State extends State<Home_screen2> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<double> _scaleAnimation;

  double _pageOpacity = 0.0; // [추가] 화면 전체 투명도를 위한 변수

  @override
  void initState() {
    super.initState();

    // [추가] Home_screen의 기능들
    FirebaseMessaging.instance.subscribeToTopic('all');
    _hideSystemUI();
    // 화면 진입 후 100ms 뒤에 전체 화면이 부드럽게 나타나도록 설정
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _pageOpacity = 1.0;
        });
        // 화면이 나타난 후 자동 로그인 체크 시작
        _checkAutoLogin();
      }
    });

    // 기존 Home_screen2의 애니메이션 컨트롤러
    _controller = AnimationController(
      duration: Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _opacityAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Interval(0.0, 0.2)),
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  // [추가] Home_screen에서 가져온 함수
  void _hideSystemUI() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [SystemUiOverlay.top],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _checkAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final isAutoLogin = prefs.getBool('autoLogin') ?? false;
    if (!isAutoLogin) return;

    // 자동 로그인 정보가 있으면 바로 로그인 화면으로 이동 (내부에서 자동 로그인 처리)
    await Future.delayed(Duration(milliseconds: 500)); // 애니메이션을 잠시 보여준 후 이동
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => LoginScreen()),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // [수정] 화면 전체를 GestureDetector와 AnimatedOpacity로 감싸기
    return GestureDetector(
      onTap: _hideSystemUI, // 화면 탭 시에도 UI 숨김 유지
      behavior: HitTestBehavior.opaque,
      child: AnimatedOpacity(
        opacity: _pageOpacity, // 페이지 전체 투명도 적용
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
        child: WillPopScope(
          onWillPop: () async => false,
          child: Scaffold(
            body: Column(
              children: [
                Expanded(
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage("assets/images/running2.png"),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Stack(
                      children: [
                        // 로고 (기존 코드와 동일)
                        Positioned(
                          left: screenWidth * 0.5 - screenWidth * 0.35,
                          top: screenHeight * 0.3,
                          child: AnimatedBuilder(
                            animation: _controller,
                            builder: (context, child) {
                              return Opacity(
                                opacity: _opacityAnimation.value,
                                child: Transform.scale(
                                  scale: _scaleAnimation.value,
                                  child: Image.asset(
                                    "assets/images/rundventure2.png",
                                    width: screenWidth * 0.7,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        // 로그인 버튼 (기존 코드와 동일)
                        Positioned(
                          left: screenWidth * 0.08,
                          bottom: screenHeight * 0.08,
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                PageRouteBuilder(
                                  transitionDuration: Duration(milliseconds: 500),
                                  pageBuilder: (context, animation, secondaryAnimation) => LoginScreen(),
                                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                    return FadeTransition(
                                      opacity: animation,
                                      child: child,
                                    );
                                  },
                                ),
                              );
                            },
                            child: Container(
                              width: screenWidth * 0.4,
                              height: screenHeight * 0.06,
                              decoration: ShapeDecoration(
                                color: Colors.black,
                                shape: RoundedRectangleBorder(
                                  side: BorderSide(width: 1, color: Colors.black),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '로그인',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: screenWidth * 0.045,
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // 가입하기 버튼 (기존 코드와 동일)
                        Positioned(
                          right: screenWidth * 0.08,
                          bottom: screenHeight * 0.08,
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                PageRouteBuilder(
                                  transitionDuration: Duration(milliseconds: 500),
                                  pageBuilder: (context, animation, secondaryAnimation) => SignUpScreen(),
                                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                    return FadeTransition(
                                      opacity: animation,
                                      child: child,
                                    );
                                  },
                                ),
                              );
                            },
                            child: Container(
                              width: screenWidth * 0.4,
                              height: screenHeight * 0.06,
                              decoration: ShapeDecoration(
                                color: Colors.white,
                                shape: RoundedRectangleBorder(
                                  side: BorderSide(width: 1, color: Colors.white),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '가입하기',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: screenWidth * 0.044,
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}