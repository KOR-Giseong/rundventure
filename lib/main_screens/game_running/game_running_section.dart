import 'package:flutter/material.dart';
import '../../game_selection/friend_battle_intro_screen.dart';
import '../../ghostrun_screen/ghostrun_ready.dart';
import '../../ghostrun_screen/ghostrun_stretching.dart';
import '../../main_screens/main_screen.dart';


class GameSelectionPage extends StatelessWidget {
  const GameSelectionPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
        return false;
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
                MaterialPageRoute(builder: (_) => const MainScreen()),
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

              _buildGameCard(
                context,
                '친구 대결',
                '친구와 실시간 러닝 대결!',
                'assets/images/friendbattle.png',
                    () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FriendBattleIntroScreen()),
                  );
                },
              ),

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
    final String iconPath;
    double iconWidth = 24;
    double iconHeight = 24;

    if (title == '고스트 런') {
      iconPath = 'assets/images/ghostlogo.png';
    } else if (title == '친구 대결') {
      iconPath = 'assets/images/battlelogo.png';
      iconWidth = 40;
      iconHeight = 40;
    } else {
      iconPath = 'assets/images/soonlogo.png';
    }

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
                    ? Align(
                  alignment: Alignment.centerRight,
                  child: Image.asset(
                    imagePath,
                    height: double.infinity,
                    fit: BoxFit.fitHeight,
                  ),
                )
                    : Image.asset(
                  imagePath,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
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
                        SizedBox(
                          width: 40,
                          height: 33,
                          child: Center(
                            child: Image.asset(
                              iconPath,
                              width: iconWidth,
                              height: iconHeight,
                            ),
                          ),
                        ),
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