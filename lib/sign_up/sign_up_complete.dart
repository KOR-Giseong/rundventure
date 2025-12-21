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
  final String nickname; // 예: 사용자가 'Nick' 이라고 입력했다면, 이 값은 'Nick' 입니다.
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

  // 회원가입의 모든 과정을 처리하고 오류 발생 시 롤백하는 함수
  Future<void> _processSignUp(BuildContext context) async {
    UserCredential? userCredential;
    User? user;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // password 변수에 값이 있을 때만 (이메일 가입일 때만) Auth 계정 생성
      if (password.isNotEmpty) {
        userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        user = userCredential.user;
      } else {
        // 소셜 가입일 경우, 이미 Auth 계정이 생성된 상태이므로 현재 유저 정보를 가져옵니다.
        user = FirebaseAuth.instance.currentUser;
      }

      if (user == null) {
        throw Exception("User is null. Auth process failed or user not found.");
      }

      // =========================================================================
      // ✨✨✨ 바로 이 부분이 핵심 수정 사항입니다 ✨✨✨
      // =========================================================================

      // ✨ 1. 원본 닉네임에서 소문자 버전을 만듭니다 (중복 체크용).
      // 예: nickname이 'Nick' 이라면, lowercaseNickname은 'nick'이 됩니다.
      final String lowercaseNickname = nickname.toLowerCase();

      // 2. Firestore에 모든 정보 일괄 저장
      final batch = FirebaseFirestore.instance.batch();
      final userRef = FirebaseFirestore.instance.collection('users').doc(email);

      batch.set(userRef, {
        // ✨ 'users' 컬렉션에는 화면에 보여줄 '원본' 닉네임을 그대로 저장합니다.
        'nickname': nickname,
        'gender': gender,
        'birthdate': birthdate,
        'weight': weight,
        'height': height,
        'bmi': bmi,
        'email': email,
        'role': 'user',
        'createdAt': FieldValue.serverTimestamp(),
        // ✨ [추가] 요청하신 대로 사용자의 가입일을 기록하기 위한 필드를 추가합니다.
        'joinDate': FieldValue.serverTimestamp(),

        // ▼▼▼▼▼ [✅ 수정된 부분] 초기 가입 시 '모두 공개(false)'로 명확하게 저장 ▼▼▼▼▼
        // 이렇게 저장해야 가입 직후에도 정보가 비공개로 뜨지 않습니다.
        'hideGender': false,
        'hideHeight': false,
        'hideWeight': false,
        'hideBirthdate': false,
        'hideProfile': false,
        // ▲▲▲▲▲ [✅ 수정 완료] ▲▲▲▲▲
      });

      // ✨ 3. 'nicknames' 컬렉션에는 '반드시' 소문자 닉네임을 문서 ID로 사용합니다.
      // 이렇게 해야 나중에 ProfileScreen에서 대소문자 구분 없이 중복을 확인할 수 있습니다.
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

      // 4. 모든 과정이 성공하면 로그인 화면으로 이동
      if (context.mounted) {
        Navigator.of(context).pop(); // 로딩 인디케이터 닫기
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LoginScreen()),
        );
      }

    } catch (e) {
      print("Sign up process failed: $e");

      // 롤백(삭제)도 이메일 가입 실패 시에만 실행되도록 수정
      if (password.isNotEmpty && userCredential?.user != null) {
        await userCredential!.user!.delete();
        print("Rolled back (deleted) the created Auth user due to an error.");
      }

      // 사용자에게 오류 알림
      if (context.mounted) {
        Navigator.of(context).pop(); // 로딩 인디케이터 닫기
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
                  // 수정된 함수를 호출합니다.
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