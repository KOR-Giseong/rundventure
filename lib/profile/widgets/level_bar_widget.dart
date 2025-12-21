// level_bar_widget.dart

import 'package:flutter/material.dart';
import 'package:rundventure/profile/leveling_service.dart';
import 'package:intl/intl.dart'; // NumberFormat import

class LevelBarWidget extends StatelessWidget {
  final LevelData? levelData;
  final bool isLoading;
  // ✅ [추가] 다른 사용자 프로필인지 여부를 나타내는 플래그
  final bool isOtherUserProfile;

  const LevelBarWidget({
    Key? key,
    required this.levelData,
    required this.isLoading,
    this.isOtherUserProfile = false, // 기본값은 false (내 프로필)
  }) : super(key: key);

  // 경험치 획득 정보 팝업 표시 함수 (내 프로필에서만 사용)
  void _showXpInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Row(
            children: [
              Icon(Icons.stars, color: Colors.amber[700]),
              SizedBox(width: 8),
              Text('경험치(XP) 획득 방법'),
            ],
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: const <Widget>[
                Text('XP는 다양한 활동을 통해 얻을 수 있습니다:'),
                SizedBox(height: 15),
                Text('• 자유러닝: 1km당 100 XP'),
                SizedBox(height: 8),
                Text('• 고스트런: 1km당 100 XP'),
                SizedBox(height: 8),
                Text('• 고스트런 승리: 50 XP 보너스'),
                SizedBox(height: 8),
                Text('• 퀘스트 완료: 퀘스트별 보상 XP'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('확인', style: TextStyle(color: Colors.black)),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(
        height: 50,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (levelData == null) {
      return Container(
        height: 50,
        child: Center(child: Text('레벨 정보를 불러오지 못했습니다.')),
      );
    }

    final formatter = NumberFormat('#,###'); // XP 표시에 필요

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 20.0),
      child: Column(
        children: [
          // LV. 텍스트와 XP 텍스트 Row
          Row(
            // ✅ isOtherUserProfile 값에 따라 정렬 방식 변경
            mainAxisAlignment: isOtherUserProfile
                ? MainAxisAlignment.start // 다른 사용자 프로필: 레벨만 왼쪽에 표시
                : MainAxisAlignment.spaceBetween, // 내 프로필: 레벨 왼쪽, XP 오른쪽
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // --- 레벨 표시 (항상 보임) ---
              Row(
                children: [
                  Text(
                    'LV. ${levelData!.level}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                  ),
                  // ✅ 내 프로필에서만 정보 아이콘 표시
                  if (!isOtherUserProfile) ...[
                    SizedBox(width: 4),
                    IconButton(
                      icon: Icon(Icons.info_outline, color: Colors.grey[600], size: 18),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                      onPressed: () => _showXpInfoDialog(context),
                      tooltip: '경험치 획득 방법 보기',
                    ),
                  ]
                ],
              ),

              // --- XP 표시 (내 프로필에서만 보임) ---
              if (!isOtherUserProfile)
                Text(
                  '${formatter.format(levelData!.currentLevelXp)} / ${formatter.format(levelData!.requiredXp)} XP',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
            ],
          ),
          SizedBox(height: 1),
          // XP 프로그레스 바 (항상 보임)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: levelData!.progress,
              minHeight: 6,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green[600]!),
            ),
          ),
        ],
      ),
    );
  }
}