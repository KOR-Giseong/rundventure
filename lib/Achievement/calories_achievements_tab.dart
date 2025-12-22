import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'exercise_data.dart';
import 'exercise_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CaloriesAchievementsTab extends StatefulWidget {
  final List<ExerciseRecord> allRecords;

  const CaloriesAchievementsTab({Key? key, required this.allRecords}) : super(key: key);

  @override
  _CaloriesAchievementsTabState createState() => _CaloriesAchievementsTabState();
}

class _CaloriesAchievementsTabState extends State<CaloriesAchievementsTab>
    with AutomaticKeepAliveClientMixin {
  final ExerciseService _exerciseService = ExerciseService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  double _totalCalories = 0.0;
  List<AchievementInfo> _achievements = [];
  bool _isCalculating = true;

  final List<double> _targetCalories = [
    100, 500, 1500, 3000, 5000, 8000, 15000, 30000, 50000
  ];

  @override
  void initState() {
    super.initState();
    _calculateAchievements();
  }

  @override
  void didUpdateWidget(covariant CaloriesAchievementsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.allRecords != oldWidget.allRecords) {
      _calculateAchievements();
    }
  }

  Future<void> _sendAchievementNotification(String achievementId, String title, String message) async {
    final userEmail = _auth.currentUser?.email;
    if (userEmail == null) return;

    final prefs = await SharedPreferences.getInstance();
    final String notificationKey = 'achv_notif_${achievementId}';

    // 이미 이 도전과제에 대한 알림을 보냈는지 확인
    if (prefs.getBool(notificationKey) == true) {
      return;
    }

    try {
      final notiRef = _firestore
          .collection('notifications')
          .doc(userEmail)
          .collection('items')
          .doc(); // 자동 ID

      await notiRef.set({
        'id': notiRef.id,
        'type': 'achievement_completed',
        'title': title,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'achievementId': achievementId,
      });

      await prefs.setBool(notificationKey, true);
      print("Achievement notification sent: $achievementId");

    } catch (e) {
      print("Error sending achievement notification: $e");
    }
  }

  void _calculateAchievements() async {
    if (mounted) setState(() => _isCalculating = true);

    // 총 칼로리 계산
    _totalCalories = _exerciseService.calculateTotalCalories(widget.allRecords);

    // 각 목표별 달성 정보 계산
    List<AchievementInfo> achievements = [];
    for (double target in _targetCalories) {
      final achievementInfo = _exerciseService.getAchievementInfo(
        targetValue: target,
        allRecords: widget.allRecords,
        getValueFromRecord: (record) => record.calories, // 칼로리 값 사용
      );

      // 1. 도전과제가 '완료'되었는지 확인
      if (achievementInfo.isCompleted) {
        // 2. 이 도전과제에 대한 알림을 보낸 적이 있는지 확인 (send 함수 내부에서 처리)
        final details = _getChallengeDetails(target);
        final String title = "도전과제 달성: ${details['title']}";
        final String message = "누적 ${target.toStringAsFixed(0)}Kcal 소모를 축하합니다!";
        final String achievementId = 'calories_${target.toInt()}';

        _sendAchievementNotification(achievementId, title, message);
      }

      achievements.add(achievementInfo);
    }

    if (mounted) {
      setState(() {
        _achievements = achievements;
        _isCalculating = false;
      });
    }
  }

  Map<String, dynamic> _getChallengeDetails(double targetValue) {
    String title;
    // 9개 레벨: 100, 500, 1500, 3000, 5000, 8000, 15000, 30000, 50000
    if (targetValue <= 100) title = '첫 땀방울';
    else if (targetValue <= 500) title = '한 끼 식사';
    else if (targetValue <= 1500) title = '지방 연소';
    else if (targetValue <= 3000) title = '대사 촉진';
    else if (targetValue <= 5000) title = '에너지 부스터';
    else if (targetValue <= 8000) title = '한계 돌파';
    else if (targetValue <= 15000) title = '칼로리 분쇄';
    else if (targetValue <= 30000) title = '신진대사 마스터';
    else title = '궁극의 연소';

    final String imagePath = 'assets/badges/${targetValue.toInt()}Kcal.png';

    return {'title': title, 'imagePath': imagePath};
  }

  // 팝업 (단위: Kcal로 변경, Icon -> Image.asset으로 수정)
  void showChallengeCompletionPopup(BuildContext context, AchievementInfo achievement) {
    final details = _getChallengeDetails(achievement.targetValue);
    final String badgeTitle = details['title'];
    final String badgeImagePath = details['imagePath'];
    final DateTime completionDate = achievement.completionDate ?? DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(icon: Icon(Icons.close, color: Colors.black), onPressed: () => Navigator.of(context).pop()),
              ),
              TweenAnimationBuilder(
                tween: Tween<double>(begin: 0.8, end: 1.8),
                duration: Duration(milliseconds: 500),
                curve: Curves.easeOutBack,
                builder: (context, scale, child) {
                  return Transform.scale(scale: scale, child: child);
                },
                child: Image.asset(badgeImagePath, width: 100, height: 100),
              ),
              SizedBox(height: 40),
              Text(badgeTitle, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black)),
              SizedBox(height: 10),
              Text('${achievement.targetValue.toStringAsFixed(0)} Kcal', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.black)),
              SizedBox(height: 10),
              Text('총 ${achievement.targetValue.toStringAsFixed(0)} Kcal 소모', style: TextStyle(fontSize: 16, color: Colors.black), textAlign: TextAlign.center),
              SizedBox(height: 20),
              Container(
                padding: EdgeInsets.symmetric(vertical: 5, horizontal: 15),
                decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(10)),
                child: Text(DateFormat('yyyy.MM.dd').format(completionDate), style: TextStyle(fontSize: 14, color: Colors.black)),
              ),
              SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('닫기', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.black, side: BorderSide(color: Colors.black), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 카드 UI (단위: Kcal로 변경, Icon -> Image.asset으로 수정)
  Widget _buildChallengeCard(AchievementInfo achievement) {
    final details = _getChallengeDetails(achievement.targetValue);
    final String badgeImagePath = details['imagePath'];
    double progress = (_totalCalories / achievement.targetValue).clamp(0.0, 1.0);
    final Color progressColor = achievement.isCompleted ? Colors.red[600]! : Colors.grey;

    return Padding(
      padding: const EdgeInsets.all(6.0),
      child: GestureDetector(
        onTap: () {
          if (achievement.isCompleted) {
            showChallengeCompletionPopup(context, achievement);
          }
        },
        child: AnimatedScale(
          scale: achievement.isCompleted ? 1.05 : 1.0,
          duration: Duration(milliseconds: 500),
          curve: Curves.easeOutBack,
          child: Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      height: 90,
                      width: 90,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 8,
                        valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                        backgroundColor: Colors.grey[200],
                      ),
                    ),
                    Opacity(
                      opacity: achievement.isCompleted ? 1.0 : 0.4,
                      child: Image.asset(badgeImagePath, width: 90, height: 90),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Text('+ ${achievement.targetValue.toStringAsFixed(0)} Kcal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                Text(achievement.isCompleted ? '달성완료!' : '도전중', style: TextStyle(color: achievement.isCompleted ? Colors.red[600] : Colors.grey[600], fontSize: 14)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;

    if (_isCalculating) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: EdgeInsets.all(screenWidth * 0.04),
        child: Column(
          children: [
            // 총 누적 칼로리 카드
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(screenWidth * 0.05),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
              child: Column(
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 50, fontWeight: FontWeight.w900, color: Colors.black),
                        children: [
                          TextSpan(text: '+ ${_totalCalories.toStringAsFixed(0)}'),
                          TextSpan(text: ' Kcal', style: TextStyle(fontWeight: FontWeight.normal, fontSize: 30)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text('누적 소모 칼로리', style: TextStyle(color: Colors.black, fontSize: 16)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // 도전과제 그리드
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: screenHeight * 0.02,
                crossAxisSpacing: screenWidth * 0.02,
                childAspectRatio: 0.8,
              ),
              itemCount: _achievements.length,
              itemBuilder: (context, index) {
                return Container(
                  height: screenHeight * 0.2,
                  child: _buildChallengeCard(_achievements[index]),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}