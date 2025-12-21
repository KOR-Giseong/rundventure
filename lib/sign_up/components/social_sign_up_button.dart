import 'package:flutter/material.dart';

class SocialSignUpButton extends StatelessWidget {
  final String text;
  final Widget icon;
  final VoidCallback onPressed;
  final double borderWidth; // 박스 두께
  final AlignmentGeometry alignment; // 왼쪽 정렬
  final Color borderColor; // 테두리 색상

  const SocialSignUpButton({
    Key? key,
    required this.text,
    required this.icon,
    required this.onPressed,
    this.borderWidth = 0.0, // 기본값 설정
    this.alignment = Alignment.centerLeft, // 기본값 설정
    this.borderColor = const Color(0xFFDDDDDD), // 기본 테두리 색상 연하게 설정
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.grey, // 테두리 색상
          width: borderWidth, // 테두리 두께
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: InkWell(
        onTap: onPressed,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 10.0), // 패딩 조정
          leading: icon,
          title: Text(text),
          titleAlignment: ListTileTitleAlignment.center, // 타이틀 정렬
        ),

        ),
      );
  }
}