import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'sign_up_password_screen.dart';

class SignUpEmailScreen extends StatefulWidget {
  const SignUpEmailScreen({Key? key}) : super(key: key);

  @override
  _SignUpEmailScreenState createState() => _SignUpEmailScreenState();
}

class _SignUpEmailScreenState extends State<SignUpEmailScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool _isEmailChecked = false;
  String? _emailStatusMessage;
  bool _showStatus = false;

  void _goBack() => Navigator.pop(context);

  bool _isValidEmailFormat(String email) {
    return RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$").hasMatch(email);
  }

  Future<void> _checkEmailDuplicate() async {
    final email = _emailController.text.trim().toLowerCase();

    if (email.isEmpty) {
      setState(() {
        _emailStatusMessage = '이메일을 입력하세요';
        _isEmailChecked = false;
        _showStatus = true;
      });
      return;
    }

    if (!_isValidEmailFormat(email)) {
      setState(() {
        _emailStatusMessage = '유효한 이메일 주소를 입력하세요';
        _isEmailChecked = false;
        _showStatus = true;
      });
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(email).get();
      if (doc.exists) {
        setState(() {
          _emailStatusMessage = '이미 가입된 이메일입니다.';
          _isEmailChecked = false;
          _showStatus = true;
        });
      } else {
        setState(() {
          _emailStatusMessage = '사용 가능한 이메일입니다.';
          _isEmailChecked = true;
          _showStatus = true;
        });
      }
    } catch (e) {
      print('❌ Firestore 오류: $e');
      setState(() {
        _emailStatusMessage = '이메일 확인 중 오류가 발생했습니다.';
        _isEmailChecked = false;
        _showStatus = true;
      });
    }
  }

  void _navigateToPasswordScreen() {
    if (_isEmailChecked) {
      final email = _emailController.text.trim().toLowerCase();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SignUpPasswordScreen(email: email),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 90),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 뒤로가기
            SizedBox(
              width: 70,
              height: 70,
              child: GestureDetector(
                onTap: _goBack,
                child: Image.asset('assets/images/Back-Navs.png', width: 70, height: 70),
              ),
            ),
            const SizedBox(height: 20),
            Text('회원가입', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 40),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: TextField(
                        controller: _emailController,
                        onChanged: (_) {
                          setState(() {
                            _isEmailChecked = false;
                            _emailStatusMessage = null;
                            _showStatus = false;
                          });
                        },
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.email, color: Colors.grey),
                          hintText: '이메일 입력',
                          hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
                          filled: true,
                          fillColor: Color(0xFFF7F8F8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        style: TextStyle(color: Colors.black, fontSize: 15),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 69,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _checkEmailDuplicate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text('확인', style: TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 18,
                  child: AnimatedOpacity(
                    opacity: _showStatus ? 1.0 : 0.0,
                    duration: Duration(milliseconds: 300),
                    child: _emailStatusMessage == null
                        ? SizedBox.shrink()
                        : Text(
                      _emailStatusMessage!,
                      style: TextStyle(
                        fontSize: 13,
                        color: _isEmailChecked ? Colors.blue : Colors.red,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 430),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isEmailChecked ? _navigateToPasswordScreen : null,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  backgroundColor: _isEmailChecked ? Colors.black : Colors.grey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  '다음',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
