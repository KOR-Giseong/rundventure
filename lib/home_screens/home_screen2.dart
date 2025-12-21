import 'package:video_player/video_player.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rundventure/main_screens/main_screen.dart';
import '../login_screens/login_screen.dart';
import 'package:rundventure/sign_up/sign_up_screen.dart';

class Home_screen2 extends StatefulWidget {
  @override
  _Home_screen2State createState() => _Home_screen2State();
}

class _Home_screen2State extends State<Home_screen2> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _opacityAnimation;
  late Animation<double> _scaleAnimation;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  VideoPlayerController? _videoController;

  // ✨ 1. 로딩 상태 관리를 위한 변수 추가
  bool _isLoading = true;
  String _loadingMessage = "앱을 실행하고 있습니다...";

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
    _opacityAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Interval(0.0, 0.2)),
    );
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _videoController = VideoPlayerController.asset('assets/videos/running_video_main.mp4');
    _videoController!.initialize().then((_) {
      if (!mounted) return;
      _videoController!.setVolume(0);
      _videoController!.setLooping(true);
      _videoController!.play();
      setState(() {});
    });

    // ✨ 2. UI가 준비되면 모든 초기화 작업을 시작하는 함수 호출
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  /// ✨ 3. 모든 초기화 작업을 순서대로 관리하는 함수
  Future<void> _initializeApp() async {
    // 작업 1: 자동 로그인 시도
    setState(() {
      _loadingMessage = "사용자 정보를 확인 중입니다...";
    });
    bool isLoggedIn = await _performAutoLoginCheck();

    // 로그인에 성공했다면 MainScreen으로 이미 이동했으므로 여기서 함수를 종료합니다.
    if (isLoggedIn) return;

    // 작업 2: (로그인 안된 경우) 필수 리소스 다운로드 (예시)
    setState(() {
      _loadingMessage = "필수 데이터를 준비 중입니다...";
    });
    await _downloadInitialData(); // 실제 다운로드 로직이 들어갈 함수

    // 모든 준비가 끝나면 로딩 상태를 false로 변경하여 버튼들을 보여줍니다.
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 자동 로그인 함수 (로그인 성공 시 true, 실패 시 false 반환하도록 수정)
  Future<bool> _performAutoLoginCheck() async {
    final prefs = await SharedPreferences.getInstance();
    final isAutoLogin = prefs.getBool('autoLogin') ?? false;

    if (!isAutoLogin) {
      return false; // 자동 로그인 설정이 안되어 있으므로 실패
    }

    final email = prefs.getString('email') ?? '';
    final password = prefs.getString('password') ?? '';
    User? user;

    try {
      if (_auth.currentUser != null) {
        user = _auth.currentUser;
      } else if (email.isNotEmpty && password.isNotEmpty) {
        final userCredential = await _auth.signInWithEmailAndPassword(email: email, password: password);
        user = userCredential.user;
      }

      if (user != null) {
        await user.reload();
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.email).get();

        if (userDoc.exists) {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => MainScreen(showWelcomeMessage: false)),
            );
          }
          return true; // 로그인 성공
        } else {
          await _auth.signOut();
          return false; // 사용자 정보가 DB에 없으므로 실패
        }
      } else {
        return false; // 로그인 정보가 없으므로 실패
      }
    } catch (e) {
      print("자동 로그인 실패: $e");
      return false; // 에러 발생 시 실패
    }
  }

  /// 리소스/데이터 다운로드를 시뮬레이션하는 예제 함수
  Future<void> _downloadInitialData() async {
    // 실제로는 여기서 서버와 통신하여 데이터를 다운로드합니다.
    // 예시로 2초간 딜레이를 줍니다.
    await Future.delayed(Duration(seconds: 2));
  }


  @override
  void dispose() {
    _animationController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (_videoController != null && _videoController!.value.isInitialized)
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _videoController!.value.size.width,
                  height: _videoController!.value.size.height,
                  child: VideoPlayer(_videoController!),
                ),
              )
            else
              Container(color: Colors.black),

            Positioned(
              left: screenWidth * 0.4 - screenWidth * 0.35,
              top: screenHeight * 0.3,
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _opacityAnimation.value,
                    child: Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Image.asset(
                        "assets/images/rundventure2.png",
                        width: screenWidth * 0.9,
                        fit: BoxFit.contain,
                      ),
                    ),
                  );
                },
              ),
            ),

            // ✨ 4. _isLoading 값에 따라 UI 분기 처리
            if (_isLoading)
            // 로딩 중일 때 보여줄 UI
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.5),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 20),
                      Text(
                        _loadingMessage,
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),

            // 로딩이 끝났을 때 보여줄 UI
            if (!_isLoading) ...[
              Positioned(
                left: screenWidth * 0.08,
                bottom: screenHeight * 0.09,
                child: Column(
                  children: [
                    // 로그인 버튼
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            transitionDuration: Duration(milliseconds: 500),
                            pageBuilder: (context, animation, secondaryAnimation) => LoginScreen(),
                            transitionsBuilder: (context, animation, secondaryAnimation, child) {
                              return FadeTransition(opacity: animation, child: child);
                            },
                          ),
                        );
                      },
                      child: Container(
                        width: screenWidth * 0.85,
                        height: screenHeight * 0.07,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(1),
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            )
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '로그인',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: screenWidth * 0.045,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 15),
                    // 가입하기 버튼
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            transitionDuration: Duration(milliseconds: 500),
                            pageBuilder: (context, animation, secondaryAnimation) => SignUpScreen(),
                            transitionsBuilder: (context, animation, secondaryAnimation, child) {
                              return FadeTransition(opacity: animation, child: child);
                            },
                          ),
                        );
                      },
                      child: Container(
                        width: screenWidth * 0.85,
                        height: screenHeight * 0.07,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9A825),
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              offset: Offset(0, 5),
                            )
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '가입하기',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: screenWidth * 0.044,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}