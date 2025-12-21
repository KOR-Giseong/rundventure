import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rundventure/main_screens/main_screen.dart';
import 'package:rundventure/home_Screens/home_screen2.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../sign_up/TermsAgreementScreen_Social.dart';
import '../sign_up/sign_up_screen.dart';
import '../sign_up/profile_screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isPasswordVisible = false;
  // bool isAutoLogin = false; // 👈 [삭제]
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  String? errorMessage;

  @override
  void initState() {
    super.initState();
    // _loadPreferences(); // 👈 [삭제]
  }

  // void _loadPreferences() async { ... } // 👈 [삭제] 함수 전체

  // void _saveAutoLogin() async { ... } // 👈 [삭제] 함수 전체

  // ▼▼▼▼▼ [신규 추가] 커스텀 스낵바 함수 ▼▼▼▼▼
  void _showCustomSnackBar(String message, {bool isError = false, bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : (isSuccess ? Icons.check_circle_outline : Icons.info_outline),
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
        backgroundColor: isError ? Colors.redAccent.shade400 : (isSuccess ? Color(0xFFFF9F80) : Colors.black87),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(15, 5, 15, 15),
        duration: Duration(seconds: isError ? 4 : (isSuccess ? 2 : 3)),
      ),
    );
  }
  // ▲▲▲▲▲ [신규 추가] 커스텀 스낵바 함수 ▲▲▲▲▲

  Future<void> _sendWelcomeNotification(User user) async {
    final now = DateTime.now();
    final ref = FirebaseFirestore.instance
        .collection('notifications')
        .doc(user.email)
        .collection('items');

    // [수정] 스낵바와 디자인이 다르므로 이 부분은 그대로 둡니다.
    await ref.add({
      'title': '러너가 되신 것을 환영합니다!',
      'message': '다양한 콘텐츠를 지금 바로 즐겨보세요!',
      'timestamp': now.toIso8601String(), // Firestore 타임스탬프 대신 ISO 문자열 사용 (기존 코드 유지)
      'isRead': false,
    });
  }

  void _showAccountNotFoundDialog(User user) {
    // ✅ [수정] mounted 확인
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('계정 정보 없음'),
        content: Text('사용자 계정이 없습니다.\n회원가입 하러 가시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('아니오'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => TermsAgreementScreen(
                    email: user.email ?? '',
                    password: '',
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
            child: Text('예', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context);
        return false;
      },
      child: Scaffold(
        body: Container(
          color: Colors.white,
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 90),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 70,
                    height: 70,
                    child: IconButton(
                      icon: Image.asset('assets/images/Back-Navs.png'),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '러너님!\n환영합니다!',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 40),
                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.mail_outline, color: Colors.grey[600]),
                      hintText: '이메일',
                      hintStyle: TextStyle(fontWeight: FontWeight.w400, color: Colors.grey[600]),
                      filled: true,
                      fillColor: Color(0xFFF7F8F8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: TextStyle(color: Colors.grey[800]),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: passwordController,
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.lock_outline, color: Colors.grey[600]),
                      hintText: '비밀번호',
                      hintStyle: TextStyle(fontWeight: FontWeight.w400, color: Colors.grey[600]),
                      filled: true,
                      fillColor: Color(0xFFF7F8F8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(isPasswordVisible ? Icons.visibility : Icons.visibility_off),
                        onPressed: () {
                          setState(() {
                            isPasswordVisible = !isPasswordVisible;
                          });
                        },
                      ),
                    ),
                    style: TextStyle(color: Colors.grey[800]),
                    obscureText: !isPasswordVisible,
                  ),
                  const SizedBox(height: 15),
                  if (errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      // ▼▼▼▼▼ [수정된 부분] ▼▼▼▼▼
                      // 에러 메시지를 Text 위젯 대신,
                      // 빌드 시점에 즉시 스낵바로 표시하도록 변경
                      // (단, 이 방식은 빌드 시마다 스낵바가 뜰 수 있으므로,
                      // login 함수 내부에서만 호출하는 것이 더 좋습니다.)
                      // 여기서는 기존 로직(errorMessage 상태 변수 사용)을 유지하되,
                      // 텍스트로만 표시합니다.
                      // 스낵바는 _loginWithEmailPassword 함수 내부에서 호출됩니다.
                      child: Text(errorMessage!, style: TextStyle(color: Colors.red)),
                      // ▲▲▲▲▲ [수정된 부분] ▲▲▲▲▲
                    ),
                  // ▼▼▼▼▼ [삭제] '자동 로그인' Row 전체 삭제 ▼▼▼▼▼
                  /*
                  Row(
                    children: [
                      Checkbox(
                        value: isAutoLogin,
                        onChanged: (value) {
                          setState(() {
                            isAutoLogin = value ?? false;
                            _saveAutoLogin();
                          });
                        },
                        activeColor: Colors.grey[600],
                      ),
                      Text('자동 로그인', style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                  */
                  // ▲▲▲▲▲ [삭제] '자동 로그인' Row 전체 삭제 ▲▲▲▲▲
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        setState(() {
                          errorMessage = null;
                        });
                        await _loginWithEmailPassword(context);
                      },
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        backgroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('로그인', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'ⓒ 2025 Rundventure. All rights reserved.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          'support@rundventure.co.kr',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 0),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.grey)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text('Or'),
                      ),
                      Expanded(child: Divider(color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey),
                          color: Color(0xFFFFFFFF),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 1, horizontal: 1),
                        child: IconButton(
                          icon: Image.asset('assets/images/googlelogo.png', width: 30, height: 30),
                          iconSize: 30,
                          onPressed: _loginWithGoogle,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey),
                          color: Colors.white,
                        ),
                        child: IconButton(
                          icon: Icon(Icons.apple, size: 30, color: Colors.black),
                          onPressed: _loginWithApple,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ▼▼▼▼▼ [⭐️⭐️⭐️ 수정된 부분 (비밀번호 찾기 밑줄) ⭐️⭐️⭐️] ▼▼▼▼▼
                  Center(
                    child: GestureDetector(
                      onTap: _showPasswordResetDialog,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start, // 텍스트 상단 정렬
                        children: [
                          IntrinsicWidth(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '비밀번호를 잊어버리셨나요',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                                Container(
                                  height: 1.0, // 밑줄 두께
                                  color: Colors.grey[600], // 밑줄 색상
                                  margin: const EdgeInsets.only(top: 1.0), // 텍스트와의 간격
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '?',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // ▲▲▲▲▲ [⭐️⭐️⭐️ 수정된 부분 (비밀번호 찾기 밑줄) ⭐️⭐️⭐️] ▲▲▲▲▲

                  const SizedBox(height: 10),
                  Center(
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(text: '회원가입이 필요하신가요? ', style: TextStyle(color: Colors.grey)),
                          TextSpan(
                            text: '회원가입',
                            style: TextStyle(color: Color(0xFFFF845C), decoration: TextDecoration.underline),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(builder: (context) => SignUpScreen()),
                                );
                              },
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
      ),
    );
  }

  Future<void> _loginWithEmailPassword(BuildContext context) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      final user = userCredential.user;

      if (user != null) {
        await user.reload();
        final refreshedUser = _auth.currentUser;

        if (refreshedUser != null && !refreshedUser.emailVerified) {
          _showEmailVerificationDialog(refreshedUser);
          final prefs = await SharedPreferences.getInstance();
          final lastSentTime = prefs.getInt('email_verification_sent') ?? 0;
          final now = DateTime.now().millisecondsSinceEpoch;
          if (now - lastSentTime > 1000 * 60) {
            await refreshedUser.sendEmailVerification();
            await prefs.setInt('email_verification_sent', now);
          }
          return;
        }

        final userDoc = await FirebaseFirestore.instance.collection('users').doc(refreshedUser!.email).get();

        if (!userDoc.exists) {
          _showAccountNotFoundDialog(refreshedUser);
          return;
        }

        final data = userDoc.data() as Map<String, dynamic>? ?? {};
        final bool isSuspended = data['isSuspended'] ?? false;

        if (isSuspended) {
          // ▼▼▼▼▼ [수정된 부분] ▼▼▼▼▼
          _showCustomSnackBar('이 계정은 정지되었습니다. 관리자에게 문의하세요.', isError: true);
          // 팝업 대신 스낵바를 띄우고 로그인을 중단합니다.
          // if (mounted) Navigator.pop(context); // 👈 pop 제거
          return;
          // ▲▲▲▲▲ [수정된 부분] ▲▲▲▲▲
        }

        final idTokenResult = await refreshedUser.getIdTokenResult();
        final isAdmin = idTokenResult.claims?['admin'] ?? false;

        // ✅ [수정] mounted 확인
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => MainScreen(showWelcomeMessage: true, isAdmin: isAdmin)),
        );
      }
    } on FirebaseAuthException catch (e) {
      // ✅ [수정] mounted 확인
      if (!mounted) return;

      String displayError; // 👈 표시할 에러 메시지 변수
      switch (e.code) {
        case 'user-not-found':
          displayError = '존재하지 않는 계정입니다.';
          break;
        case 'wrong-password':
          displayError = '비밀번호가 틀렸습니다.';
          break;
        case 'invalid-email':
          displayError = '유효하지 않은 이메일 형식입니다.';
          break;
        case 'user-disabled':
          displayError = '비활성화된 계정입니다.';
          break;
        case 'invalid-credential':
          displayError = '이메일 또는 비밀번호가 올바르지 않습니다.';
          break;
        default:
          displayError = '로그인 중 오류가 발생했습니다. 다시 시도해주세요.';
      }

      // ▼▼▼▼▼ [수정된 부분] ▼▼▼▼▼
      // setState 대신 스낵바 호출
      _showCustomSnackBar(displayError, isError: true);
      /*
      setState(() {
        errorMessage = displayError;
      });
      */
      // ▲▲▲▲▲ [수정된 부분] ▲▲▲▲▲

    } catch (e) {
      // ✅ [수정] mounted 확인
      if (!mounted) return;
      // ▼▼▼▼▼ [수정된 부분] ▼▼▼▼▼
      _showCustomSnackBar('로그인 오류: $e', isError: true);
      /*
      setState(() {
        errorMessage = '로그인 오류: $e';
      });
      */
      // ▲▲▲▲▲ [수정된 부분] ▲▲▲▲▲
    }
  }

  Future<void> _loginWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return;

      final googleAuth = await googleUser.authentication;
      final email = googleUser.email;

      final methods = await _auth.fetchSignInMethodsForEmail(email);

      if (methods.contains('password')) {
        // ▼▼▼▼▼ [수정된 부분] ▼▼▼▼▼
        _showCustomSnackBar('해당 이메일은 이메일/비밀번호 로그인으로 등록되어 있습니다. 소셜 로그인을 사용하려면 비밀번호 재설정을 해주세요.', isError: true);
        /*
        if (!mounted) return;
        setState(() {
          errorMessage = '해당 이메일은 이메일/비밀번호 로그인으로 등록되어 있습니다. 소셜 로그인을 사용하려면 비밀번호 재설정을 해주세요.';
        });
        */
        // ▲▲▲▲▲ [수정된 부분] ▲▲▲▲▲
        return;
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user!.email).get();
      final data = userDoc.data();

      if (userDoc.exists && data != null) {
        final bool isSuspended = data['isSuspended'] ?? false;
        if (isSuspended) {
          // ▼▼▼▼▼ [수정된 부분] ▼▼▼▼▼
          _showCustomSnackBar('이 계정은 정지되었습니다. 관리자에게 문의하세요.', isError: true);
          // if (mounted) Navigator.pop(context); // 👈 pop 제거
          return;
          // ▲▲▲▲▲ [수정된 부분] ▲▲▲▲▲
        }
      }

      if (!userDoc.exists || data == null ||
          data['nickname'] == null || data['birthdate'] == null ||
          data['gender'] == null || data['height'] == null ||
          data['weight'] == null) {
        _showAccountNotFoundDialog(user);
      } else {
        if (userCredential.additionalUserInfo?.isNewUser == true) {
          await _sendWelcomeNotification(user);
        }

        // ✅ [수정] mounted 확인
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => MainScreen(showWelcomeMessage: true)));
        // ▼▼▼▼▼ [삭제] 자동 로그인 관련 prefs 저장 ▼▼▼▼▼
        /*
        if (isAutoLogin) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('loginMethod', 'google');
        }
        */
        // ▲▲▲▲▲ [삭제] 자동 로그인 관련 prefs 저장 ▲▲▲▲▲
      }
    } catch (e) {
      print("❌ 구글 로그인 상세 오류: $e");
      // ▼▼▼▼▼ [수정된 부분] ▼▼▼▼▼
      _showCustomSnackBar('로그인 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.', isError: true);
      /*
      if (!mounted) return;
      setState(() {
        errorMessage = '로그인 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.';
      });
      */
      // ▲▲▲▲▲ [수정된 부분] ▲▲▲▲▲
    }
  }

  Future<void> _loginWithApple() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final email = credential.email;

      if (email != null) {
        final methods = await _auth.fetchSignInMethodsForEmail(email);

        if (methods.contains('password')) {
          // ▼▼▼▼▼ [수정된 부분] ▼▼▼▼▼
          _showCustomSnackBar('해당 이메일은 이메일/비밀번호 로그인으로 등록되어 있습니다. 소셜 로그인을 사용하려면 비밀번호 재설정을 해주세요.', isError: true);
          /*
          if (!mounted) return;
          setState(() {
            errorMessage = '해당 이메일은 이메일/비밀번호 로그인으로 등록되어 있습니다. 소셜 로그인을 사용하려면 비밀번호 재설정을 해주세요.';
          });
          */
          // ▲▲▲▲▲ [수정된 부분] ▲▲▲▲▲
          return;
        }
      }

      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: credential.identityToken,
        accessToken: credential.authorizationCode,
      );

      final userCredential = await _auth.signInWithCredential(oauthCredential);
      final user = userCredential.user;

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user!.email).get();
      final data = userDoc.data();

      if (userDoc.exists && data != null) {
        final bool isSuspended = data['isSuspended'] ?? false;
        if (isSuspended) {
          // ▼▼▼▼▼ [수정된 부분] ▼▼▼▼▼
          _showCustomSnackBar('이 계정은 정지되었습니다. 관리자에게 문의하세요.', isError: true);
          // if (mounted) Navigator.pop(context); // 👈 pop 제거
          return;
          // ▲▲▲▲▲ [수정된 부분] ▲▲▲▲▲
        }
      }

      if (!userDoc.exists || data == null ||
          data['nickname'] == null || data['birthdate'] == null ||
          data['gender'] == null || data['height'] == null ||
          data['weight'] == null) {
        _showAccountNotFoundDialog(user);
      } else {
        if (userCredential.additionalUserInfo?.isNewUser == true) {
          await _sendWelcomeNotification(user);
        }

        // ✅ [수정] mounted 확인
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => MainScreen(showWelcomeMessage: true)));
        // ▼▼▼▼▼ [삭제] 자동 로그인 관련 prefs 저장 ▼▼▼▼▼
        /*
        if (isAutoLogin) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('loginMethod', 'apple');
        }
        */
        // ▲▲▲▲▲ [삭제] 자동 로그인 관련 prefs 저장 ▲▲▲▲▲
      }
    } catch (e) {
      print("❌ 애플 로그인 상세 오류: $e");
      // ✅ [수정] mounted 확인
      if (!mounted) return;
      if (e is SignInWithAppleAuthorizationException &&
          e.code == AuthorizationErrorCode.canceled) {
        // ▼▼▼▼▼ [수정된 부분] ▼▼▼▼▼
        // (취소는 오류가 아니므로 스낵바 표시 안 함)
        /*
        setState(() {
          errorMessage = null;
        });
        */
        // ▲▲▲▲▲ [수정된 부분] ▲▲▲▲▲
      } else {
        // ▼▼▼▼▼ [수정된 부분] ▼▼▼▼▼
        _showCustomSnackBar('로그인 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.', isError: true);
        /*
        setState(() {
          errorMessage = '로그인 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.';
        });
        */
        // ▲▲▲▲▲ [수정된 부분] ▲▲▲▲▲
      }
    }
  }

  void _showPasswordResetDialog() {
    // ✅ [수정] mounted 확인
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) {
        TextEditingController resetEmailController = TextEditingController();
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('비밀번호 재설정', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('가입하신 이메일을 입력하시면\n비밀번호 재설정 메일을 보내드립니다.'),
              const SizedBox(height: 10),
              TextField(
                controller: resetEmailController,
                decoration: InputDecoration(hintText: '이메일 입력'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('취소')),
            ElevatedButton(
              onPressed: () async {
                final localContext = context;
                try {
                  await _auth.sendPasswordResetEmail(email: resetEmailController.text.trim());
                  Navigator.of(localContext).pop();
                  // ▼▼▼▼▼ [수정된 부분] ▼▼▼▼▼
                  _showCustomSnackBar('비밀번호 재설정 메일을 보냈습니다.', isSuccess: true);
                  // ScaffoldMessenger.of(localContext).showSnackBar(SnackBar(content: Text('비밀번호 재설정 메일을 보냈습니다.')));
                  // ▲▲▲▲▲ [수정된 부분] ▲▲▲▲▲
                } catch (e) {
                  Navigator.of(localContext).pop();
                  // ▼▼▼▼▼ [수정된 부분] ▼▼▼▼▼
                  _showCustomSnackBar('이메일 전송 실패: $e', isError: true);
                  // ScaffoldMessenger.of(localContext).showSnackBar(SnackBar(content: Text('이메일 전송 실패: $e')));
                  // ▲▲▲▲▲ [수정된 부분] ▲▲▲▲▲
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
              child: Text('보내기', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showEmailVerificationDialog(User user) {
    // ✅ [수정] mounted 확인
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool isVerified = user.emailVerified;
        Timer? timer;

        return StatefulBuilder(
          builder: (context, setState) {
            timer ??= Timer.periodic(Duration(seconds: 3), (_) async {
              await user.reload();
              final refreshedUser = _auth.currentUser;
              if (refreshedUser != null && refreshedUser.emailVerified) {
                timer?.cancel();
                // ✅ [수정] mounted 확인
                if (mounted) {
                  setState(() => isVerified = true);
                }
              }
            });

            return PopScope( // ✅ [수정] WillPopScope -> PopScope (최신 Flutter)
              canPop: false, // 뒤로가기 버튼으로 닫기 방지
              onPopInvoked: (didPop) {
                if (didPop) return;
                timer?.cancel(); // '취소' 버튼 외의 방식으로 닫힐 때 타이머 취소
                Navigator.of(context).pop();
              },
              child: AlertDialog(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Text('이메일 인증 안내', style: TextStyle(fontWeight: FontWeight.bold)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('인증 메일을 전송했습니다.\n메일을 확인하고 아래 버튼을 눌러주세요.'),
                    SizedBox(height: 10),
                    Text('※ 인증 메일은 10분 내 만료됩니다.', style: TextStyle(color: Colors.black54, fontSize: 12)),
                    Text('(계정 임시 삭제)', style: TextStyle(color: Colors.grey, fontSize: 11)),
                  ],
                ),
                actions: [
                  TextButton(onPressed: () {
                    timer?.cancel();
                    Navigator.of(context).pop();
                  }, child: Text('취소')),
                  ElevatedButton(
                    onPressed: isVerified
                        ? () {
                      timer?.cancel();
                      Navigator.of(context).pop();
                      // ✅ [수정] mounted 확인
                      if (mounted) {
                        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => MainScreen(showWelcomeMessage: true)));
                      }
                    }
                        : null,
                    style: ElevatedButton.styleFrom(backgroundColor: isVerified ? Colors.red : Colors.grey),
                    child: Text('인증 확인', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}