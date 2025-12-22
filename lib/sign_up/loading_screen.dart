import 'dart:async';
import 'package:flutter/material.dart';
import 'sign_up_complete.dart';

class LoadingScreen extends StatefulWidget {
  final String email;
  final String password;
  final String height;
  final String weight;
  final String birthdate;
  final String gender;
  final String nickname;

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
      backgroundColor: Colors.white,
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
