// NavigationBar.dart

import 'package:flutter/material.dart';
// 사용하시는 경로에 맞게 import 문을 확인해주세요.
import 'package:rundventure/challenge/challenge.dart';
import 'package:rundventure/challenge/challenge_screen.dart';
import 'package:rundventure/main_screens/main_screen.dart';
import 'package:rundventure/challenge/challenge_setup_screen.dart';
import 'package:rundventure/challenge/admin/event_challenge_form.dart';
import '../ranking/ranking_screen.dart';

class NavigationBar extends StatelessWidget {
  final List<Widget>? actions;
  final bool isChallengeBoardLocked;
  final bool isAdmin;

  const NavigationBar({
    Key? key,
    this.actions,
    this.isChallengeBoardLocked = false,
    this.isAdmin = false,
  }) : super(key: key);

  void _showCreateChallengeChoice(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext bc) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.all(20.0),
            child: Wrap(
              spacing: 12.0,
              runSpacing: 12.0,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                  child: Text(
                    '어떤 챌린지를 만드시겠습니까?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.grey[200],
                    child: Icon(Icons.directions_run, color: Colors.grey[800]),
                  ),
                  title: Text('일반 챌린지', style: TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text('사용자가 자율적으로 생성하고 참여하는 챌린지입니다.'),
                  onTap: () {
                    Navigator.pop(context); // Close bottom sheet
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => ChallengeSetupScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue[50],
                    child: Icon(Icons.emoji_events, color: Colors.blueAccent),
                  ),
                  title: Text('관리자 이벤트 챌린지', style: TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text('선착순, 참여도 집계 등 특수 기능이 포함된 챌린지입니다.'),
                  onTap: () {
                    Navigator.pop(context); // Close bottom sheet
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              EventChallengeForm()),
                    );
                  },
                ),
                SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center, // 텍스트를 중앙에 배치
      children: [
        // --- 1. 중앙 컨텐츠 (챌린지 / 사담 / 랭킹) ---
        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center, // 중앙 정렬
            children: [
              GestureDetector(
                onTap: () {
                  // '챌린지' 페이지로 이동
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const Challenge()),
                  );
                },
                child: Text(
                  '챌린지',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Pretendard',
                    color: Colors.grey[600], // '사담'이 활성이므로 비활성 색상
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 25),
              GestureDetector(
                onTap: () {
                  // '사담' 페이지로 이동 (이미 '사담' 페이지라면 아무것도 안함)
                  // 현재 페이지가 ChallengeScreen이 아닐 경우에만 푸시
                  if (ModalRoute.of(context)?.settings.name !=
                      'ChallengeScreen') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ChallengeScreen(),
                        // ChallengeScreen에 고유한 이름을 부여했다면 사용
                        // settings: RouteSettings(name: 'ChallengeScreen'),
                      ),
                    );
                  }
                },
                child: Text(
                  '사담', // '사담' 페이지라고 가정하고 활성 스타일 적용
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
                  Navigator.push(context,
                      MaterialPageRoute(builder: (context) => const RankingScreen()));
                },
                child: Text(
                  // 비활성 스타일
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

        // --- 2. 양쪽 끝 버튼 (뒤로가기, 설정/만들기) ---
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween, // 양쪽 끝으로 배치
          children: [
            // 뒤로 가기 버튼
            Padding(
              // OtherUserProfileScreen과 동일하게 8.0 패딩
              padding: const EdgeInsets.all(8.0),
              child: IconButton(
                icon: Image.asset(
                  'assets/images/Back-Navs.png',
                  // OtherUserProfileScreen과 크기 통일 (45x45)
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

            // 오른쪽 버튼들 (설정 + 만들기)
            Row(
              mainAxisSize: MainAxisSize.min, // Row 크기를 최소화
              children: [
                // '설정 아이콘' (actions를 통해 전달받음)
                if (actions != null) ...actions!,

                // '만들기 아이콘' (menu.png)
                Padding(
                  // OtherUserProfileScreen과 동일하게 8.0 패딩
                  padding: const EdgeInsets.only(right: 8.0),
                  child: IconButton(
                    icon: Image.asset(
                      'assets/images/menu.png',
                      // OtherUserProfileScreen과 크기 통일 (45x45)
                      width: 45,
                      height: 45,
                    ),
                    onPressed: () {
                      if (isChallengeBoardLocked) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                '⛔ 챌린지 게시판이 잠겨 있어 새 챌린지를 만들 수 없습니다.'),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      } else {
                        // 4. 관리자 여부에 따라 분기
                        if (isAdmin) {
                          // 관리자면 선택창 띄우기
                          _showCreateChallengeChoice(context);
                        } else {
                          // 일반 유저면 기존 챌린지 생성으로 바로 이동
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => ChallengeSetupScreen()),
                          );
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}