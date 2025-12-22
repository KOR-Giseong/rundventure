import 'package:flutter/material.dart';
import '../main_screens/game_running/game_running_section.dart';
import '../main_screens/main_screen.dart';
import 'friend_battle_list_screen.dart';
import 'async_battle_create_screen.dart';
import 'async_battle_list_screen.dart';


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
          actions: [
            IconButton(
              icon: Icon(Icons.home_outlined, color: Colors.black),
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const MainScreen()),
                      (Route<dynamic> route) => false,
                );
              },
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. 메인 이미지 또는 아이콘 (예시)
              Center(
                child: Image.asset(
                  'assets/images/battlelogo.png',
                  width: 200,
                  height: 200,
                  fit: BoxFit.contain,
                ),
              ),
              SizedBox(height: 0),
              Text(
                '친구와 러닝 배틀!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: textScaler.scale(24),
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: 16),
              Text(
                '실시간으로 친구와 경쟁하거나,\n'
                    '편한 시간에 오프라인으로 대결하세요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: textScaler.scale(15),
                  color: Colors.grey[700],
                  height: 1.5,
                ),
              ),
              SizedBox(height: 32),
              _buildInfoBox(
                context,
                icon: Icons.notifications_active_outlined,
                text: '대결 신청 시 상대방에게 푸시 알림이 전송됩니다.',
              ),
              SizedBox(height: 12),
              _buildInfoBox(
                context,
                icon: Icons.timer_outlined,
                text: '실시간 대결은 3초 뒤 동시 출발, 오프라인 대결은 각자 편한 시간에 진행합니다.',
              ),
              Spacer(),

              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FriendBattleListScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF3E8DFD),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  '[실시간] 대결 상대 선택하기',
                  style: TextStyle(
                    fontSize: textScaler.scale(16),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(height: 12),

              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AsyncBattleCreateScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFFF9F80),
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

              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AsyncBattleListScreen(),
                    ),
                  );
                },
                child: IntrinsicWidth(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '진행 중인 오프라인 대결 보기',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Container(
                        height: 1.0,
                        color: Colors.grey[700],
                        margin: const EdgeInsets.only(top: 1.0),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 8),
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