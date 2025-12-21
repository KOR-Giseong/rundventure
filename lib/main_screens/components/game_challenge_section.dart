import 'package:flutter/material.dart';
import 'package:rundventure/challenge/challenge.dart';
import '../../Achievement/achivement_screen.dart';

class GameChallengeSection extends StatelessWidget {
  final double gameRunTitleSpacing;
  final double gameRunDescriptionSpacing;
  final double challengeTitleSpacing;
  final double challengeDescriptionSpacing;

  // 텍스트 크기 조절용 파라미터 추가
  final double titleFontSize;
  final double descriptionFontSize;

  // ▼▼▼▼▼ [ ✨ 추가된 부분 ✨ ] ▼▼▼▼▼
  final bool hasNewNotification; // ✅ 퀘스트/도전과제 알림 상태
  // ▲▲▲▲▲ [ ✨ 추가된 부분 ✨ ] ▲▲▲▲▲

  const GameChallengeSection({
    Key? key,
    this.gameRunTitleSpacing = 3.0,
    this.gameRunDescriptionSpacing = 100.0,
    this.challengeTitleSpacing = 3.0,
    this.challengeDescriptionSpacing = 120.0,
    this.titleFontSize = 22.0,
    this.descriptionFontSize = 14.0,
    this.hasNewNotification = false, // ✅ 생성자 기본값
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final double deviceWidth = MediaQuery.of(context).size.width;
    final double cardHeight = deviceWidth * 0.54;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: deviceWidth * 0.03),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: deviceWidth * 0.015),
              child: _buildGameRunCard(context, cardHeight),
            ),
          ),
          // ▼▼▼▼▼ [ ✨ 수정된 부분 ✨ ] ▼▼▼▼▼
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: deviceWidth * 0.015),
              // ✅ Stack으로 감싸서 배지 추가
              child: Stack(
                clipBehavior: Clip.none, // 카드를 벗어나도 배지가 보이도록
                children: [
                  _buildChallengeCard(context, cardHeight),
                  // ✅ '도전과제' 카드에 대한 알림 배지
                  if (hasNewNotification)
                    Positioned(
                      top: -4,  // 카드 상단에서 Y위치
                      right: 6, // 카드 우측에서 X위치
                      child: Container(
                        padding: const EdgeInsets.all(4.5), // 점 크기
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // ▲▲▲▲▲ [ ✨ 수정된 부분 ✨ ] ▲▲▲▲▲
        ],
      ),
    );
  }

  Widget _buildGameRunCard(BuildContext context, double cardHeight) {
    return _buildCard(
      context: context,
      imagePath: 'assets/images/runningimage2.png',
      title: '커뮤니티',
      description: '많은 정보들을\n확인해 보세요!',
      cardHeight: cardHeight,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => Challenge()),
        );
      },
    );
  }

  Widget _buildChallengeCard(BuildContext context, double cardHeight) {
    return _buildCard(
      context: context,
      imagePath: 'assets/images/runningimage3.png',
      title: '도전과제',
      description: '도전과제를 통해\n성장해요!',
      cardHeight: cardHeight,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => AchievementScreen()),
        );
      },
    );
  }

  Widget _buildCard({
    required BuildContext context,
    required String imagePath,
    required String title,
    required String description,
    required double cardHeight,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: cardHeight,
        margin: const EdgeInsets.only(bottom: 5.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black45,
              offset: const Offset(0, 3),
              blurRadius: 6,
            ),
          ],
        ),
        child: Stack(
          children: [
            _buildCardImage(imagePath, cardHeight),
            _buildCardGradient(),
            _buildCardContent(context, title, description),
          ],
        ),
      ),
    );
  }

  Widget _buildCardImage(String imagePath, double cardHeight) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Image.asset(
        imagePath,
        width: double.infinity,
        height: cardHeight,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildCardGradient() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.bottomRight,
            end: Alignment.topLeft,
            colors: [
              Colors.white.withOpacity(0.6),
              Colors.white,
            ],
            stops: [0.1, 0.5],
          ),
        ),
      ),
    );
  }

  Widget _buildCardContent(BuildContext context, String title, String description) {
    // 카드별 이미지 설정
    final String topImagePath = title == '커뮤니티'
        ? 'assets/images/graph.png'
        : 'assets/images/trophy.png';
    const String bottomImagePath = 'assets/images/nextbutton.png';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start, // 왼쪽 정렬
        children: [
          Image.asset(
            topImagePath,
            width: 24,
            height: 24,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: titleFontSize,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontSize: descriptionFontSize,
              color: Colors.black45,
            ),
          ),
          const SizedBox(height: 8),
          Image.asset(
            bottomImagePath,
            width: 40,
            height: 40,
          ),
        ],
      ),
    );
  }

}