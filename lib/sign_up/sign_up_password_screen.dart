import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'sign_up_password_confirm.dart'; // 비밀번호 확인 페이지 임포트

class SignUpPasswordScreen extends StatefulWidget {
  final String email;

  const SignUpPasswordScreen({Key? key, required this.email}) : super(key: key);

  @override
  _SignUpPasswordScreenState createState() => _SignUpPasswordScreenState();
}

class _SignUpPasswordScreenState extends State<SignUpPasswordScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true; // 비밀번호 가리기 상태

  Future<void> _goToConfirmPasswordScreen() async {
    if (_formKey.currentState!.validate()) {
      Navigator.push(
        context,
        PageRouteBuilder(
          transitionDuration: Duration(milliseconds: 500), // 애니메이션 지속 시간
          pageBuilder: (context, animation, secondaryAnimation) => ConfirmPasswordScreen(
            email: widget.email,
            password: _passwordController.text.trim(),
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // 페이드 애니메이션 적용
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        ),
      );
    }
  }

  void _goBack() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
// 뒤로가기 버튼
                SizedBox(
                  width: 70,
                  height: 70,
                  child: GestureDetector(
                    onTap: () {
                      // 애니메이션 효과 추가
                      Navigator.pop(
                        context,
                        PageRouteBuilder(
                          transitionDuration: Duration(milliseconds: 300), // 애니메이션 지속 시간
                          pageBuilder: (context, animation, secondaryAnimation) => this.widget,
                          transitionsBuilder: (context, animation, secondaryAnimation, child) {
                            // 페이드 애니메이션 적용
                            return FadeTransition(
                              opacity: animation,
                              child: child,
                            );
                          },
                        ),
                      );
                    },
                    child: Image.asset('assets/images/Back-Navs.png', width: 70, height: 70),
                  ),
                ),
                const SizedBox(height: 20),

                // 회원가입 제목
                Text(
                  '회원가입',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600, // 동일한 굵기 설정
                  ),
                ),
                const SizedBox(height: 40),

                // 이메일 입력 필드 (비활성화된 필드, 이메일 아이콘 추가)
                TextFormField(
                  initialValue: widget.email,
                  decoration: InputDecoration(
                    enabled: false, // 비활성화된 필드
                    filled: true,
                    fillColor: Color(0xFFF7F8F8), // 색상 추가
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none, // 테두리 없앰
                    ),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(12), // 아이콘 크기 조정
                      child: Icon(Icons.email, color: Colors.grey), // 이메일 아이콘
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 비밀번호 입력 필드 (라벨 텍스트 제거, 비밀번호 가리기 아이콘 추가)
                Form(
                  key: _formKey,
                  child: TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Color(0xFFF7F8F8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Icon(Icons.lock, color: Colors.grey),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      // 힌트 텍스트를 보안 정책에 맞게 수정
                      hintText: '대문자, 특수문자 포함 8자 이상',
                      hintStyle: TextStyle(
                        color: Colors.grey[500], // 연한 회색으로 설정
                        fontWeight: FontWeight.w400, // 힌트 텍스트의 굵기 조정
                      ),
                    ),
                    obscureText: _obscurePassword,
                    // 유효성 검사 로직 수정
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '비밀번호를 입력하세요';
                      }
                      if (value.length < 8) {
                        return '비밀번호는 8자리 이상이어야 합니다';
                      }
                      if (!RegExp(r'(?=.*[A-Z])').hasMatch(value)) {
                        return '최소 한 개의 대문자를 포함해야 합니다';
                      }
                      if (!RegExp(r'(?=.*[!@#\$%^&*(),.?":{}|<>])').hasMatch(value)) {
                        return '최소 한 개의 특수문자를 포함해야 합니다';
                      }
                      return null;
                    },
                  ),
                ),
                SizedBox(height: 350), // 버튼 하단 간격 맞춤

                // 이전, 다음 버튼
                Row(
                  children: [
                    // 이전 버튼 (흰색 배경, 검정색 테두리)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _goBack,
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 18),
                          backgroundColor: Colors.white, // 흰색 배경
                          side: BorderSide(color: Colors.black, width: 1), // 검정색 테두리
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          '이전',
                          style: TextStyle(
                            color: Colors.black, // 검정색 텍스트
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10), // 버튼 간격 조정

                    // 다음 버튼
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _goToConfirmPasswordScreen,
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 18),
                          backgroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          '다음',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}