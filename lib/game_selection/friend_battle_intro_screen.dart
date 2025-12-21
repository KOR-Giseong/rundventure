import 'package:flutter/material.dart';
import '../main_screens/game_running/game_running_section.dart';
import '../main_screens/main_screen.dart';
import 'friend_battle_list_screen.dart'; // 👈 [기존] 실시간 대결 목록

// 신규 추가 (Part 11)
import 'async_battle_create_screen.dart'; // 오프라인 대결 생성 화면
import 'async_battle_list_screen.dart';  // 오프라인 대결 목록 화면


class FriendBattleIntroScreen extends StatelessWidget {
  const FriendBattleIntroScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);

    return WillPopScope(
      onWillPop: () async {
        // 뒤로가기 시 게임 선택 페이지로 이동
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const GameSelectionPage()),
        );
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: Image.asset('assets/images/Back-Navs.png', width: 66, height: 66),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const GameSelectionPage()),
              );
            },
            padding: const EdgeInsets.only(left: 8),
          ),
          title: Text(
            '친구 대결',
            style: TextStyle(
              fontSize: textScaler.scale(16),
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          centerTitle: true,
          // ▼▼▼▼▼ [ ⭐️⭐️⭐️ 여기가 수정된 부분입니다 (홈 버튼 추가) ⭐️⭐️⭐️ ] ▼▼▼▼▼
          actions: [
            IconButton(
              icon: Icon(Icons.home_outlined, color: Colors.black),
              onPressed: () {
                // 홈 화면으로 모든 스택을 비우고 이동
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const MainScreen()), // 👈 HomeScreen()으로 이동
                      (Route<dynamic> route) => false, // 모든 이전 경로 제거
                );
              },
            ),
          ],
          // ▲▲▲▲▲ [ ⭐️⭐️⭐️ 여기가 수정된 부분입니다 (홈 버튼 추가) ⭐️⭐️⭐️ ] ▲▲▲▲▲
        ),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. 메인 이미지 또는 아이콘 (예시)
              Center(
                child: Image.asset(
                  'assets/images/battlelogo.png', // 👈 친구 대결 로고 (새 애셋)
                  width: 200,
                  height: 200,
                  fit: BoxFit.contain,
                ),
              ),
              SizedBox(height: 0),
              // 2. 타이틀
              Text(
                '친구와 러닝 배틀!', // 👈 [수정] 텍스트 변경
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: textScaler.scale(24),
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: 16),
              // 3. 설명
              Text(
                '실시간으로 친구와 경쟁하거나,\n' // 👈 [수정] 텍스트 추가
                    '편한 시간에 오프라인으로 대결하세요.', // 👈 [수정] 텍스트 추가
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: textScaler.scale(15),
                  color: Colors.grey[700],
                  height: 1.5,
                ),
              ),
              SizedBox(height: 32),
              // 4. 주의사항 (옵션)
              _buildInfoBox(
                context,
                icon: Icons.notifications_active_outlined,
                text: '대결 신청 시 상대방에게 푸시 알림이 전송됩니다.',
              ),
              SizedBox(height: 12),
              _buildInfoBox(
                context,
                icon: Icons.timer_outlined,
                text: '실시간 대결은 3초 뒤 동시 출발, 오프라인 대결은 각자 편한 시간에 진행합니다.', // 👈 [수정]
              ),
              Spacer(),

              // ▼▼▼▼▼ [ ⭐️⭐️⭐️ 수정된 부분 (Part 11) ⭐️⭐️⭐️ ] ▼▼▼▼▼

              // 5-1. [기존] 실시간 대결 버튼
              ElevatedButton(
                onPressed: () {
                  // [기존] 실시간 대결 친구 목록 페이지로 이동
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FriendBattleListScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF3E8DFD), // 파란색
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  '[실시간] 대결 상대 선택하기', // 👈 [수정] 텍스트 변경
                  style: TextStyle(
                    fontSize: textScaler.scale(16),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(height: 12), // 버튼 사이 간격

              // 5-2. [신규] 오프라인 대결 생성 버튼
              ElevatedButton(
                onPressed: () {
                  // [신규] 오프라인 대결 생성 화면 (Part 8)으로 이동
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AsyncBattleCreateScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFFF9F80), // 런드벤처 주황색
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  '[오프라인] 대결 생성하기',
                  style: TextStyle(
                    fontSize: textScaler.scale(16),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // 5-3. [신규] 오프라인 대결 목록 버튼
              TextButton(
                onPressed: () {
                  // [신규] 오프라인 대결 목록 화면 (Part 9)으로 이동
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AsyncBattleListScreen(),
                    ),
                  );
                },
                // ▼▼▼▼▼ [ ⭐️⭐️⭐️ 밑줄 수정 (그대로 유지) ⭐️⭐️⭐️ ] ▼▼▼▼▼
                child: IntrinsicWidth( // 1. 텍스트 너비만큼만 영역을 잡습니다.
                  child: Column(
                    mainAxisSize: MainAxisSize.min, // 2. 세로 크기를 최소화합니다.
                    children: [
                      Text(
                        '진행 중인 오프라인 대결 보기',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Container( // 4. 텍스트 아래에 수동으로 밑줄을 그립니다.
                        height: 1.0, // 밑줄 두께
                        color: Colors.grey[700], // 밑줄 색상
                        margin: const EdgeInsets.only(top: 1.0), // 텍스트와의 간격
                      ),
                    ],
                  ),
                ),
                // ▲▲▲▲▲ [ ⭐️⭐️⭐️ 밑줄 수정 (그대로 유지) ⭐️⭐️⭐️ ] ▲▲▲▲▲
              ),
              // ▲▲▲▲▲ [ ⭐️⭐️⭐️ 수정된 부분 (Part 11) ⭐️⭐️⭐️ ] ▲▲▲▲▲

              SizedBox(height: 8), // 하단 여백
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBox(BuildContext context, {required IconData icon, required String text}) {
    final textScaler = MediaQuery.textScalerOf(context);

    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.grey[600], size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: textScaler.scale(13),
                color: Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }
}