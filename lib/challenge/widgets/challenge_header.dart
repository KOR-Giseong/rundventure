// ChallengeHeader.dart

import 'package:flutter/material.dart';
import 'package:rundventure/challenge/challenge.dart';
import 'package:rundventure/challenge/challenge_screen.dart';
import 'package:rundventure/main_screens/main_screen.dart';

import '../ranking/ranking_screen.dart';

class ChallengeHeader extends StatelessWidget {
  // isChallengeBoardLocked 변수는 삭제된 상태 유지
  const ChallengeHeader({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {

    // 1. SafeArea와 상단 Padding으로 헤더 위치 조정 (아래로 내리기 유지)
    return SafeArea(
      top: true,
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.only(top: 10.0), // 전체를 10.0 내림
        child: Stack(
          alignment: Alignment.center,
          children: [

            // --- 1. 중앙 컨텐츠 (챌린지 / 사담 / 랭킹) ---
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 🔸 챌린지 텍스트 (활성 스타일)
                  GestureDetector(
                    onTap: () {
                      if (ModalRoute.of(context)?.settings.name != 'Challenge') {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const Challenge()));
                      }
                    },
                    child: Text( // 활성 스타일
                      '챌린지',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        fontFamily: 'Inter',
                        color: Colors.black,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 25),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const ChallengeScreen()));
                    },
                    child: Text( // 비활성 스타일
                      '사담',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Pretendard',
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 25),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const RankingScreen()));
                    },
                    child: Text( // 비활성 스타일
                      '랭킹',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Pretendard',
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // --- 2. 양쪽 끝 버튼 (뒤로가기, 오른쪽 빈 공간) ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: const EdgeInsets.all(0.0),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: Image.asset(
                      'assets/images/Back-Navs.png',
                      width: 48, // NavigationBar와 동일한 크기
                      height: 48,
                    ),
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => MainScreen()),
                      );
                    },
                  ),
                ),

                const Padding(
                  padding: EdgeInsets.only(right: 8.0),
                  child: SizedBox(
                    width: 45,
                    height: 45,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}