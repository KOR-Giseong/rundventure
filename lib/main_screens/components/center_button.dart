import 'package:flutter/material.dart';
import '../../free_running/free_running_start.dart';
import '../constants/main_screen_constants.dart';

class CenterButton extends StatelessWidget {
  final Animation<double> animation;
  final double deviceWidth;
  final MainScreenConstants constants;
  final VoidCallback onTap; // ✅ 1. onTap 콜백을 받을 변수 추가

  const CenterButton({
    Key? key,
    required this.animation,
    required this.deviceWidth,
    required this.constants,
    required this.onTap, // ✅ 2. 생성자에 onTap 추가
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildMainButton(context),
        _buildCoverButton(context),
      ],
    );
  }

  Widget _buildMainButton(BuildContext context) {
    return Positioned(
      bottom: constants.centerButtonHeight / 3,
      left: (deviceWidth - constants.centerButtonWidth) / 2,
      child: GestureDetector(
        onTap: onTap, // ✅ 3. 기존의 직접 이동 로직을 onTap 콜백으로 변경
        child: Stack(
          alignment: Alignment.center,
          children: [
            Image.asset(
              'assets/images/centerbutton.png',
              width: constants.centerButtonWidth,
              height: constants.centerButtonHeight,
            ),
            _buildAnimatedArrow(),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedArrow() {
    return Positioned(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return Transform.scale(
            scale: animation.value,
            child: Image.asset(
              'assets/images/buttonurrow.png',
              width: constants.centerButtonWidth * 0.3,
              height: constants.centerButtonHeight * 0.3,
            ),
          );
        },
      ),
    );
  }

  Widget _buildCoverButton(BuildContext context) {
    return Positioned(
      left: (deviceWidth - constants.buttonCoverWidth) / 2,
      bottom: constants.buttonCoverBottom - 15,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return Transform.scale(
            scale: animation.value,
            child: GestureDetector(
              onTap: onTap, // ✅ 4. 커버 버튼도 onTap 콜백으로 변경
              child: Container(
                width: constants.buttonCoverWidth,
                height: constants.buttonCoverHeight,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Image.asset(
                  'assets/images/buttoncover.png',
                  fit: BoxFit.fill,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

// ✅ 5. 버튼 자체의 페이지 이동 함수는 이제 불필요하므로 삭제합니다.
// void _navigateToRunningPage(BuildContext context) { ... }
}