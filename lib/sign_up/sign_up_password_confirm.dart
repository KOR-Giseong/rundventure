import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../login_screens/login_screen.dart';
import 'terms_of_Use.dart';
import 'profile_screen.dart';

class ConfirmPasswordScreen extends StatefulWidget {
  final String email;
  final String password;

  const ConfirmPasswordScreen({Key? key, required this.email, required this.password}) : super(key: key);

  @override
  _ConfirmPasswordScreenState createState() => _ConfirmPasswordScreenState();
}

class _ConfirmPasswordScreenState extends State<ConfirmPasswordScreen> {
  final TextEditingController _confirmPasswordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreedToTerms = false;

  void _goBack() {
    Navigator.pop(context);
  }

  Future<void> _navigateToTerms() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TermsAndConditionsScreen(),
      ),
    );

    if (result != null && result) {
      setState(() {
        _agreedToTerms = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        height: MediaQuery.of(context).size.height,
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 90),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 70,
                  height: 70,
                  child: GestureDetector(
                    onTap: _goBack,
                    child: Image.asset('assets/images/Back-Navs.png', width: 70, height: 70),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '회원가입',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 40),
                TextFormField(
                  initialValue: widget.email,
                  decoration: InputDecoration(
                    enabled: false,
                    filled: true,
                    fillColor: Color(0xFFF7F8F8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Icon(Icons.email, color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  initialValue: widget.password,
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
                  ),
                  obscureText: _obscurePassword,
                ),
                const SizedBox(height: 20),
                Form(
                  key: _formKey,
                  child: TextFormField(
                    controller: _confirmPasswordController,
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
                      labelText: '비밀번호 확인',
                      labelStyle: TextStyle(
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w400,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                    ),
                    obscureText: _obscureConfirmPassword,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '비밀번호를 입력하세요';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Checkbox(
                      value: _agreedToTerms,
                      onChanged: (value) {
                        setState(() {
                          _agreedToTerms = value ?? false;
                        });
                      },
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: _navigateToTerms,
                        child: Row(
                          children: [
                            IntrinsicWidth(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '개인정보 보호정책 및 이용약관에 동의합니다.',
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontSize: 14,
                                    ),
                                  ),
                                  Container(
                                    height: 1.0,
                                    color: Colors.grey[700],
                                    margin: const EdgeInsets.only(top: 2.0),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 200),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _goBack,
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 18),
                          backgroundColor: Colors.white,
                          side: BorderSide(color: Colors.black, width: 1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          '이전',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _agreedToTerms
                            ? () async {
                          if (_formKey.currentState!.validate()) {
                            if (widget.password == _confirmPasswordController.text.trim()) {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ProfileScreen(
                                    email: widget.email,
                                    password: widget.password,
                                  ),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("비밀번호가 일치하지 않습니다.")),
                              );
                            }
                          }
                        }
                            : null,
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