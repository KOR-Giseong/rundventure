import 'dart:async';
import 'package:flutter/material.dart';
import 'sign_up_complete.dart'; // sign_up_complete 페이지 import

class LoadingScreen extends StatefulWidget {
  final String email; // 이전 입력한 이메일
  final String password; // 이전 입력한 비밀번호
  final String height; // 이전 입력한 키
  final String weight; // 이전 입력한 몸무게
  final String birthdate; // 이전 입력한 생년월일
  final String gender; // 이전 입력한 성별
  final String nickname; // 이전 입력한 닉네임

  const LoadingScreen({
    Key? key,
    required this.email,
    required this.password,
    required this.height,
    required this.weight,
    required this.birthdate,
    required this.gender,
    required this.nickname,
  }) : super(key: key);

  @override
  _LoadingScreenState createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();

    // BMI 계산
    double heightInMeters = double.parse(widget.height) / 100;
    double weightInKg = double.parse(widget.weight);
    double bmi = weightInKg / (heightInMeters * heightInMeters);

    Timer(const Duration(seconds: 4), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => SignUpCompleteScreen(
            email: widget.email,
            password: widget.password,
            height: widget.height,
            weight: widget.weight,
            birthdate: widget.birthdate,
            gender: widget.gender,
            nickname: widget.nickname,
            bmi: bmi.toStringAsFixed(2),
          ),
        ),
      );
    });

    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // ✅ 배경 흰색
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 90),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(),
            Center(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _controller.value * 6.28,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        CircleAvatar(radius: 4, backgroundColor: Colors.grey),
                        SizedBox(width: 10),
                        CircleAvatar(radius: 4, backgroundColor: Colors.grey),
                      ],
                    ),
                  );
                },
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
