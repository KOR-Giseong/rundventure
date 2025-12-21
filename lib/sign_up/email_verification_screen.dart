import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'sign_up_password_screen.dart'; // 비밀번호 입력 화면 import

class EmailVerificationScreen extends StatefulWidget {
  final String email;

  const EmailVerificationScreen({Key? key, required this.email}) : super(key: key);

  @override
  _EmailVerificationScreenState createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final TextEditingController _codeController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 이메일 인증 코드 전송 함수
  Future<void> _sendVerificationEmail() async {
    User? user = _auth.currentUser;
    if (user != null) {
      await user.sendEmailVerification();
    }
  }

  // 인증 코드 검증 함수
  void _verifyCode() async {
    if (_formKey.currentState!.validate()) {
      String enteredCode = _codeController.text;

      // 여기서 실제 인증 코드 검증 로직을 구현해야 합니다.
      // Firebase Auth의 sendEmailVerification()으로 보낸 코드와 비교하여야 함

      User? user = _auth.currentUser;
      await user?.reload(); // 사용자의 정보를 업데이트합니다.
      if (user != null && user.emailVerified) {
        // 인증이 완료되면 다음 페이지로 이동
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SignUpPasswordScreen(email: widget.email),
          ),
        );
      } else {
        // 인증 실패 시 메시지 표시
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('인증 코드가 올바르지 않습니다.')),
        );
      }
    }
  }

  void _goBack() {
    Navigator.pop(context);
  }

  @override
  void initState() {
    super.initState();
    _sendVerificationEmail(); // 이메일 인증 코드 전송
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // 배경을 흰색으로 설정
      body: Container(
        height: MediaQuery.of(context).size.height, // 화면 높이 전체 사용
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 90),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 뒤로가기 버튼 (이미지로 대체)
                SizedBox(
                  width: 70,
                  height: 70,
                  child: GestureDetector(
                    onTap: _goBack,
                    child: Image.asset('assets/images/Back-Navs.png', width: 70, height: 70),
                  ),
                ),
                const SizedBox(height: 20),

                // 이메일 인증 제목
                Text(
                  '이메일 인증',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600, // 굵기 설정
                  ),
                ),
                const SizedBox(height: 40),

                // 이메일 주소 표시
                Text(
                  '입력한 이메일: ${widget.email}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 20),

                // 인증 코드 입력 폼
                Form(
                  key: _formKey,
                  child: TextFormField(
                    controller: _codeController,
                    decoration: InputDecoration(
                      labelText: '인증 코드 입력',
                      filled: true,
                      fillColor: Color(0xFFF7F8F8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: TextStyle(color: Colors.grey[900]), // 텍스트 색상
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '인증 코드를 입력하세요';
                      }
                      // 여기에 인증 코드 검증 로직 추가 (현재는 예시로 비워둠)
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 30),

                // 인증 확인 버튼
                Container(
                  width: double.infinity, // 버튼 박스의 넓이를 화면 가득 채움
                  child: ElevatedButton(
                    onPressed: _verifyCode, // 인증 확인 함수 호출
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      '인증 확인',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
