import 'package:flutter/material.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context), // 뒤로가기 기능 추가
                child: Image.asset('assets/images/Back-Navs.png', width: 70, height: 70),
              ),
              const SizedBox(width: 75),
              const Text(
                '프로필',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Pretendard',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F3F3),
            borderRadius: BorderRadius.circular(16),
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/images/user.png',
              fit: BoxFit.cover, // 이미지를 상자에 맞게 조정
              width: 84,
              height: 84,
            ),
          ),
        ),
      ],
    );
  }
}
