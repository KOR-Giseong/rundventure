import 'package:flutter/material.dart';

/// 로그인 직후 메인 화면 상단에 잠깐 나타나는 환영 메시지 오버레이입니다.
///
/// [nickname]이 비어 있거나 null이면 렌더링하지 않습니다.
class WelcomeMessageOverlay extends StatelessWidget {
  final String? nickname;
  final Animation<double> fadeAnimation;

  const WelcomeMessageOverlay({
    Key? key,
    required this.nickname,
    required this.fadeAnimation,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (nickname == null || nickname!.isEmpty) return const SizedBox.shrink();

    return Positioned(
      top: 100,
      left: 80,
      right: 80,
      child: FadeTransition(
        opacity: fadeAnimation,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: Text(
              '$nickname 님, 환영합니다!',
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
