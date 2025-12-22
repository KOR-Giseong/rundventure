import 'package:flutter/material.dart';
// import 'package:rundventure/challenge/challenge_screen.dart'; // ChallengeForm에서 사용하므로 여기선 불필요
// import '../../main_screens/main_screen.dart'; // ChallengeForm에서 사용하므로 여기선 불필요
import '../challenge.dart'; // Challenge() 스크린으로 돌아가기 위해 필요

class Header extends StatelessWidget {
  const Header({Key? key}) : super(key: key);

  void _showRulesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          '챌린지 생성 규칙',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          '''
📌 챌린지 생성 시 아래 내용을 확인해 주세요:

1. **챌린지 이름**: 챌린지의 목표를 잘 나타내는 이름을 입력해 주세요. (예: 100km 함께 완주하기)

2. **기간**: 챌린지를 진행할 기간을 **일(day) 단위 숫자**로만 입력해 주세요. (예: 30)

3. **목표 거리**: 제시된 옵션 중에서 **목표 거리와 최대 참여 인원**을 선택해 주세요. (직접 입력이 아닙니다.)

4. **수정 불가**: 생성된 챌린지는 **수정 및 삭제가 불가능**하니, 신중하게 등록해 주세요.

* 챌린지는 생성 즉시 다른 사용자들에게 공유되며, 목표 달성 시 특별 배지가 지급됩니다.
          ''',
          style: TextStyle(fontSize: 14, height: 1.5, color: Colors.black87), // 가독성을 위한 줄 간격(height) 추가
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인했습니다', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () {
              // ChallengeForm에서 ChallengeScreen으로 이동하므로,
              // 이 뒤로가기 버튼은 이전 화면 (아마도 Challenge 스크린)으로 가는 것이 맞습니다.
              // Navigator.pop(context); // 또는
              Navigator.pushReplacement( // 스택을 정리하며 이동
                context,
                MaterialPageRoute(builder: (context) => const Challenge()),
              );
            },
            child: Padding(
              padding: const EdgeInsets.only(left: 5.0),
              child: Image.asset(
                'assets/images/Back-Navs.png',
                width: 70,
                height: 70,
              ),
            ),
          ),
          const Text(
            '챌린지 등록',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
          TextButton(
            onPressed: () => _showRulesDialog(context),
            child: const Text(
              '규칙',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFFFF845D),
              ),
            ),
          ),
        ],
      ),
    );
  }
}