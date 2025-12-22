import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../login_screens/login_screen.dart';

class SignUpCompleteScreen extends StatelessWidget {
  final String email;
  final String password;
  final String height;
  final String weight;
  final String birthdate;
  final String gender;
  final String nickname;
  final String bmi;

  const SignUpCompleteScreen({
    Key? key,
    required this.email,
    required this.password,
    required this.height,
    required this.weight,
    required this.birthdate,
    required this.gender,
    required this.nickname,
    required this.bmi,
  }) : super(key: key);

  Future<void> _processSignUp(BuildContext context) async {
    UserCredential? userCredential;
    User? user;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      if (password.isNotEmpty) {
        userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        user = userCredential.user;
      } else {
        user = FirebaseAuth.instance.currentUser;
      }

      if (user == null) {
        throw Exception("User is null. Auth process failed or user not found.");
      }

      // 닉네임 중복 체크를 위해 소문자 버전 생성
      final String lowercaseNickname = nickname.toLowerCase();

      final batch = FirebaseFirestore.instance.batch();
      final userRef = FirebaseFirestore.instance.collection('users').doc(email);

      batch.set(userRef, {
        // users 컬렉션에는 원본 닉네임 저장 (화면 표시용)
        'nickname': nickname,
        'gender': gender,
        'birthdate': birthdate,
        'weight': weight,
        'height': height,
        'bmi': bmi,
        'email': email,
        'role': 'user',
        'createdAt': FieldValue.serverTimestamp(),
        'joinDate': FieldValue.serverTimestamp(),

        // 초기 가입 시 모든 정보 공개로 설정
        'hideGender': false,
        'hideHeight': false,
        'hideWeight': false,
        'hideBirthdate': false,
        'hideProfile': false,
      });

      // nicknames 컬렉션에는 소문자 닉네임을 문서 ID로 사용 (중복 체크용)
      final nicknameRef = FirebaseFirestore.instance.collection('nicknames').doc(lowercaseNickname);
      batch.set(nicknameRef, {'email': email});

      final notificationRef = FirebaseFirestore.instance.collection('notifications').doc(email).collection('items').doc();
      batch.set(notificationRef, {
        'title': '러너가 되신 것을 환영합니다!',
        'message': '다양한 콘텐츠를 지금 바로 즐겨보세요!',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      await batch.commit();
      print('User info saved to Firestore successfully.');

      if (context.mounted) {
        Navigator.of(context).pop();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LoginScreen()),
        );
      }

    } catch (e) {
      print("Sign up process failed: $e");

      if (password.isNotEmpty && userCredential?.user != null) {
        await userCredential!.user!.delete();
        print("Rolled back (deleted) the created Auth user due to an error.");
      }

      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("회원가입 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요."))
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/signupcom.png',
              fit: BoxFit.contain,
              alignment: Alignment.bottomCenter,
            ),
          ),
          Positioned(
            top: 0,
            left: -50,
            right: 80,
            bottom: screenHeight * 0.0003,
            child: Image.asset(
              'assets/images/man.png',
              fit: BoxFit.contain,
              alignment: Alignment.bottomLeft,
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Container(
                  margin: EdgeInsets.only(
                    top: screenHeight * 0.15,
                    bottom: 0.001,
                    right: screenWidth * 0.3,
                  ),
                  child: const Text(
                    '회원가입 완료!',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                  ),
                ),
                Container(
                  margin: EdgeInsets.only(
                    top: 1.0,
                    bottom: 0.01,
                    left: screenWidth * 0.02,
                    right: screenWidth * 0.34,
                  ),
                  child: const Text(
                    '계정생성이 완료되었습니다.',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w300,
                      color: Colors.black54,
                    ),
                  ),
                ),
                Container(
                  margin: EdgeInsets.only(
                    top: 1,
                    bottom: 13.0,
                    left: screenWidth * 0.023,
                    right: screenWidth * 0.39,
                  ),
                  child: const Text(
                    '이제 힘차게 뛰어볼까요?',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w300,
                      color: Colors.black54,
                    ),
                  ),
                ),
                Container(
                  margin: EdgeInsets.only(
                    top: 0,
                    bottom: 13.0,
                    left: screenWidth * 0.05,
                    right: screenWidth * 0.05,
                  ),
                  child: const Text(
                    '※ 로그인 화면에서 이메일 인증 후 정상 이용 가능합니다.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w300,
                      color: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: screenHeight * 0.07,
            left: 30,
            right: 30,
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  await _processSignUp(context);
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '다음',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}