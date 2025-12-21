import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class SocialLoginButtons extends StatelessWidget {
  const SocialLoginButtons({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center, // 세로 정렬
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center, // 가로 정렬
          children: [
            GestureDetector(
              onTap: () {
                // 구글 로그인 처리
              },
              child: Image.asset(
                'assets/images/googlelogo.png', // 구글 버튼 이미지 파일 이름 입력
                width: 130,
                height: 50,
              ),
            ),
            const SizedBox(width: 10), // 버튼 사이 여백
            SizedBox(
              width: 130,
              height: 50,
              child: SignInWithAppleButton(
                onPressed: () {
                  // 애플 로그인 처리
                },
                borderRadius: BorderRadius.circular(8),
                style: SignInWithAppleButtonStyle.black, // 기본 스타일
              ),
            ),
          ],
        ),
      ],
    );
  }
}