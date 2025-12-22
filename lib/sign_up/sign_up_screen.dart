import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:rundventure/home_Screens/home_screen2.dart';
import '../login_screens/login_screen.dart';
import '../sign_up/sign_up_email.dart';
import 'TermsAgreementScreen_Social.dart';
import 'profile_screen.dart';
import 'package:rundventure/sign_up/components/social_sign_up_button.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({Key? key}) : super(key: key);

  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _signUpWithEmail() async {
  }

  Future<void> _signUpWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await _auth.signInWithCredential(credential);

      if (userCredential.additionalUserInfo?.isNewUser ?? false) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => TermsAgreementScreen(
              email: googleUser.email,
              password: '',
            ),
          ),
        );
      } else {
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('이미 가입된 계정', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Text('해당 구글 계정으로 가입된 정보가 있습니다.\n로그인하시겠습니까?'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _auth.signOut();
                    googleSignIn.signOut();
                  },
                  child: Text('취소'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => Home_screen2()),
                          (Route<dynamic> route) => false,
                    );
                  },
                  child: Text('로그인'),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      print("구글 연동 실패: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("구글 연동 중 오류가 발생했습니다."),
          backgroundColor: Colors.redAccent.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(15, 5, 15, 15),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _signUpWithApple() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: credential.identityToken,
        accessToken: credential.authorizationCode,
      );

      final userCredential = await _auth.signInWithCredential(oauthCredential);
      final user = userCredential.user;

      if (user == null) throw Exception("유저 정보 없음");

      if (userCredential.additionalUserInfo?.isNewUser ?? false) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => TermsAgreementScreen(
              email: user.email ?? '',
              password: '',
            ),
          ),
        );
      } else {
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('이미 가입된 계정', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Text('해당 Apple ID로 가입된 정보가 있습니다.\n로그인하시겠습니까?'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _auth.signOut();
                  },
                  child: Text('취소'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => Home_screen2()),
                          (Route<dynamic> route) => false,
                    );
                  },
                  child: Text('로그인'),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      print("애플 연동 실패: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("애플 연동 중 오류가 발생했습니다."),
          backgroundColor: Colors.redAccent.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(15, 5, 15, 15),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 85),
            SizedBox(
              width: 70,
              height: 70,
              child: IconButton(
                icon: Image.asset('assets/images/Back-Navs.png', width: 70, height: 70),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '회원가입',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 40),
            Row(
              children: [
                Expanded(
                  child: SocialSignUpButton(
                    text: '이메일로 회원가입',
                    icon: Icon(Icons.email, color: Colors.grey),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => SignUpEmailScreen()),
                      );
                    },
                    borderWidth: 1.0,
                    borderColor: Colors.grey.withOpacity(0.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: SocialSignUpButton(
                    text: '구글로 회원가입',
                    icon: Image.asset('assets/images/googlelogo.png', width: 24, height: 24),
                    onPressed: _signUpWithGoogle,
                    borderWidth: 1.0,
                    borderColor: Colors.grey.withOpacity(0.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.grey.withOpacity(0.5),
                        width: 1.0,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: SignInWithAppleButton(
                      onPressed: _signUpWithApple,
                      borderRadius: BorderRadius.circular(10),
                      style: SignInWithAppleButtonStyle.black,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            Spacer(),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('계정이 있으신가요? ', style: TextStyle(color: Color(0xFFADA4A5))),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => LoginScreen()),
                      );
                    },
                    child: Text(
                      '로그인',
                      style: TextStyle(
                        fontWeight: FontWeight.normal,
                        color: Color(0xFFFF845C),
                        decoration: TextDecoration.underline,
                        decorationColor: Color(0xFFFF845C),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}