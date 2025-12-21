import 'package:flutter/material.dart';
import 'package:rundventure/challenge/widgets/challenge_header.dart';
import 'package:rundventure/challenge/widgets/challenge_content.dart';
import 'package:rundventure/challenge/challenge_screen/share_button.dart';

class Challenge extends StatelessWidget {
  const Challenge({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ChallengeHeader(),
                    const SizedBox(height: 34),
                    Text(
                      '다양한 챌린지를!',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Pretendard',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '오늘도 다양한 챌린지를 확인해보세요!\n다양한 챌린지를 다양한 사람들과 함께!',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF7B6F72),
                        fontFamily: 'Pretendard',
                      ),
                    ),
                    const SizedBox(height: 33),
                    const ChallengeContent(),
                    const SizedBox(height: 25),
                    const ShareButton(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}