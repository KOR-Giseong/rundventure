import 'package:flutter/material.dart';
import 'package:rundventure/challenge/challenge.dart';
import 'package:rundventure/challenge/challenge_screen.dart';
import 'package:rundventure/main_screens/main_screen.dart';
import 'ranking_info_popup.dart';
import 'ranking_history_popup.dart';


class RankingHeader extends StatelessWidget {
  const RankingHeader({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: true,
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.only(top: 10.0), // ChallengeHeader와 동일
        child: Stack(
          alignment: Alignment.center,
          children: [
            // --- 1. 중앙 컨텐츠 (챌린지 / 사담 / 랭킹) ---
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 🔸 챌린지 텍스트 (비활성)
                  GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(context, MaterialPageRoute(
                          builder: (context) => const Challenge()
                      ));
                    },
                    child: _buildInactiveTab(context, '챌린지'),
                  ),
                  const SizedBox(width: 25),
                  // 🔸 사담 텍스트 (비활성)
                  GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(context, MaterialPageRoute(
                          builder: (context) => const ChallengeScreen()
                      ));
                    },
                    child: _buildInactiveTab(context, '사담'),
                  ),
                  const SizedBox(width: 25),
                  // 🔸 랭킹 텍스트 (활성)
                  GestureDetector(
                    onTap: () {
                      // 이미 랭킹 페이지임
                    },
                    child: _buildActiveTab(context, '랭킹'),
                  ),
                ],
              ),
            ),

            // --- 2. 양쪽 끝 버튼 (뒤로가기, 오른쪽 버튼 2개) ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  // 왼쪽 패딩을 늘려 오른쪽으로 이동
                  padding: const EdgeInsets.only(left: 15.0),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(), // IconButton 자체 패딩 최소화
                    icon: Image.asset(
                      'assets/images/Back-Navs.png',
                      width: 48,
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

                Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: Row(
                    children: [
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                        icon: Icon(
                          Icons.military_tech_outlined, // 명예/메달 아이콘
                          color: Colors.grey[600],
                          size: 28,
                        ),
                        tooltip: '명예의 전당',
                        onPressed: () {
                          // 명예의 전당 팝업 띄우기
                          showDialog(
                            context: context,
                            builder: (context) => const RankingHistoryPopup(),
                          );
                        },
                      ),
                      const SizedBox(width: 1),

                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                        icon: Icon(
                          Icons.info_outline_rounded, // 정보 아이콘
                          color: Colors.grey[600], // 아이콘 색상
                          size: 28, // 아이콘 크기
                        ),
                        tooltip: '랭킹 안내',
                        onPressed: () {
                          // 랭킹 설명 팝업 띄우기
                          showDialog(
                            context: context,
                            builder: (context) => const RankingInfoPopup(), // 기존 팝업
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 비활성 탭 스타일 헬퍼 (수정 없음)
  Widget _buildInactiveTab(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w500,
        fontFamily: 'Pretendard',
        color: Colors.grey[600],
        fontSize: 16,
      ),
    );
  }

  // 활성 탭 스타일 헬퍼 (수정 없음)
  Widget _buildActiveTab(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w800,
        fontSize: 18,
        fontFamily: 'Inter',
        color: Colors.black,
        letterSpacing: 1.2,
      ),
    );
  }
}