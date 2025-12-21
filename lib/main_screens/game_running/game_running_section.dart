import 'package:flutter/material.dart';
import '../../game_selection/friend_battle_intro_screen.dart';
import '../../ghostrun_screen/ghostrun_ready.dart';
import '../../ghostrun_screen/ghostrun_stretching.dart';
import '../../main_screens/main_screen.dart'; // ← MainScreen import 추가

// ▼▼▼▼▼ [ ✅ 신규 추가 ] ▼▼▼▼▼
// 친구 대결 인트로 페이지 import

// ▲▲▲▲▲ [ ✅ 신규 추가 ] ▲▲▲▲▲


class GameSelectionPage extends StatelessWidget {
  const GameSelectionPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainScreen()), // 홈 화면으로 이동
        );
        return false; // pop 막기
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          title: const Text(
            '게임 선택',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: Image.asset('assets/images/Back-Navs.png', width: 66, height: 66),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const MainScreen()), // ← 여기서도 MainScreen으로
              );
            },
            padding: const EdgeInsets.only(left: 8),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(12.0),
          child: ListView(
            children: [
              _buildGameCard(
                context,
                '고스트 런',
                '나의 과거이력보다 향상된 나!',
                'assets/images/ghostrunpage3-1.png',
                    () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const StretchingPage()),
                  );
                },
              ),

              // ▼▼▼▼▼ [ ✅ 신규 추가된 '친구 대결' 카드 ] ▼▼▼▼▼
              _buildGameCard(
                context,
                '친구 대결', // 👈 타이틀
                '친구와 실시간 러닝 대결!', // 👈 설명
                'assets/images/friendbattle.png', // 👈 배경 이미지 (새 애셋)
                    () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FriendBattleIntroScreen()), // 👈 인트로 화면으로
                  );
                },
              ),
              // ▲▲▲▲▲ [ ✅ 신규 추가 끝 ] ▲▲▲▲▲

              _buildGameCard(
                context,
                'Coming Soon',
                '조금만 기다려주세요. 곧 출시될 거예요!',
                'assets/images/game2.png',
                    () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: const Text(
                        '서비스 준비 중',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      content: const Text(
                        '아직 개발 중인 기능입니다.\n좋은 아이디어가 있으시다면\nsupport@rundventure.co.kr 으로 보내주세요!',
                        style: TextStyle(fontSize: 14, color: Colors.black87),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('확인', style: TextStyle(color: Colors.black)),
                        ),
                      ],
                    ),
                  );
                },
              ),
              _buildGameCard(
                context,
                'Coming Soon',
                '조금만 기다려주세요. 곧 출시될 거예요!',
                'assets/images/game3.png',
                    () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: const Text(
                        '서비스 준비 중',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      content: const Text(
                        '아직 개발 중인 기능입니다.\n좋은 아이디어가 있으시다면\nsupport@rundventure.co.kr 으로 보내주세요!',
                        style: TextStyle(fontSize: 14, color: Colors.black87),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('확인', style: TextStyle(color: Colors.black)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameCard(
      BuildContext context,
      String title,
      String description,
      String imagePath,
      VoidCallback onTap,
      ) {
    // ▼▼▼▼▼ [ ✅ 수정 1 ] ▼▼▼▼▼
    // 아이콘 경로 및 '실제 크기'를 분기 처리합니다.
    final String iconPath;
    double iconWidth = 24; // 기본 너비
    double iconHeight = 24; // 기본 높이

    if (title == '고스트 런') {
      iconPath = 'assets/images/ghostlogo.png';
      // iconWidth, iconHeight는 24 그대로
    } else if (title == '친구 대결') {
      iconPath = 'assets/images/battlelogo.png'; // 👈 새 아이콘 (새 애셋)
      iconWidth = 40; // 👈 실제 아이콘 너비
      iconHeight = 40; // 👈 실제 아이콘 높이
    } else {
      iconPath = 'assets/images/soonlogo.png';
      // iconWidth, iconHeight는 24 그대로
    }
    // ▲▲▲▲▲ [ ✅ 수정 1 끝 ] ▲▲▲▲▲

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 150,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                offset: Offset(0, 2),
                blurRadius: 4,
              ),
            ],
          ),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: imagePath == 'assets/images/friendbattle.png'
                    ? Align( // Align 위젯을 사용하여 위치를 조정합니다.
                  alignment: Alignment.centerRight, // 오른쪽으로 정렬
                  child: Image.asset(
                    imagePath,
                    height: double.infinity, // 높이는 컨테이너에 맞춥니다.
                    fit: BoxFit.fitHeight, // 이미지의 높이를 기준으로 확대/축소
                  ),
                )
                    : Image.asset(
                  imagePath,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover, // 나머지 이미지는 cover 유지
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.white.withOpacity(1),
                        Colors.white.withOpacity(0.6),
                        Colors.white.withOpacity(0.2),
                        Colors.transparent,
                      ],
                      stops: const [0.4, 0.8, 1.0, 1.0],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24.0, 16.0, 16.0, 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // ▼▼▼▼▼ [ ✅ 핵심 수정 2 ] ▼▼▼▼▼
                        // 아이콘을 고정된 크기(32x32)의 '투명 상자' 안에 넣습니다.
                        SizedBox(
                          width: 40,  // 👈 모든 카드의 아이콘 영역 너비를 32로 고정
                          height: 33, // 👈 모든 카드의 아이콘 영역 높이를 32로 고정
                          child: Center( // 👈 32x32 상자 안에서
                            child: Image.asset(
                              iconPath,
                              width: iconWidth,   // 👈 아이콘 '실제 크기' (24 또는 32)
                              height: iconHeight,  // 👈 아이콘 '실제 크기' (24 또는 32)
                            ),
                          ),
                        ),
                        // ▲▲▲▲▲ [ ✅ 핵심 수정 2 끝 ] ▲▲▲▲▲
                        const SizedBox(width: 8),
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: const TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                    const SizedBox(height: 12),
                    Image.asset('assets/images/nextbutton.png', width: 40, height: 40),
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