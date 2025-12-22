import 'package:flutter/material.dart';
import 'package:rundventure/challenge/components/header.dart';
import 'package:rundventure/challenge/components/challenge_form.dart';

class ChallengeSetupScreen extends StatelessWidget {
  const ChallengeSetupScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector( // 키보드 닫기용
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: true, // 키보드 올라올 때 화면 재배치 허용
        body: SafeArea(
          child: Column(
            children: [
              const Header(),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: const [
                      ChallengeForm(),
                      SizedBox(height: 40), // 하단 여유
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
