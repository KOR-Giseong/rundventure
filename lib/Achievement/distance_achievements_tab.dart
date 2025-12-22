import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'exercise_data.dart';
import 'exercise_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DistanceAchievementsTab extends StatefulWidget {
  final List<ExerciseRecord> allRecords;

  const DistanceAchievementsTab({Key? key, required this.allRecords}) : super(key: key);

  @override
  _DistanceAchievementsTabState createState() => _DistanceAchievementsTabState();
}

class _DistanceAchievementsTabState extends State<DistanceAchievementsTab>
    with AutomaticKeepAliveClientMixin {
  final ExerciseService _exerciseService = ExerciseService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  double _totalDistance = 0.0;
  List<AchievementInfo> _achievements = [];
  bool _isCalculating = true;

  // 9개 목표 거리 (수정됨)
  final List<double> _targetDistances = [
    10, 30, 50, 100, 150, 200, 300, 400, 500
  ];

  @override
  void initState() {
    super.initState();
    _calculateAchievements();
  }

  // 부모 위젯에서 데이터가 변경(새로고침)될 때 호출
  @override
  void didUpdateWidget(covariant DistanceAchievementsTab oldWidget) {
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

    // 총 거리 계산
    _totalDistance = _exerciseService.calculateTotalKilometers(widget.allRecords);

    // 각 목표별 달성 정보 계산
    List<AchievementInfo> achievements = [];
    for (double target in _targetDistances) {
      final achievementInfo = _exerciseService.getAchievementInfo(
        targetValue: target,
        allRecords: widget.allRecords,
        getValueFromRecord: (record) => record.kilometers,
      );

      if (achievementInfo.isCompleted) {
        final details = _getChallengeDetails(target);
        final String title = "도전과제 달성: ${details['title']}";
        final String message = "누적 ${target.toStringAsFixed(0)}KM 달성을 축하합니다!";
        final String achievementId = 'distance_${target.toInt()}';

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

  Map<String, dynamic> _getChallengeDetails(double targetDistance) {
    String title;
    // 9개 레벨: 10, 30, 50, 100, 150, 200, 300, 400, 500
    if (targetDistance <= 10) title = '첫걸음'; // 10
    else if (targetDistance <= 30) title = '마라토너'; // 30
    else if (targetDistance <= 50) title = '꾸준함'; // 50
    else if (targetDistance <= 100) title = '러너'; // 100
    else if (targetDistance <= 150) title = '프로'; // 150
    else if (targetDistance <= 200) title = '엘리트'; // 200
    else if (targetDistance <= 300) title = '마스터'; // 300
    else if (targetDistance <= 400) title = '레전드';
    else title = '히어로';

    final String imagePath = 'assets/badges/${targetDistance.toInt()}km.png';

    return {'title': title, 'imagePath': imagePath};
  }

  // 팝업 (Icon -> Image.asset으로 수정)
  void showChallengeCompletionPopup(BuildContext context, AchievementInfo achievement) {
    final details = _getChallengeDetails(achievement.targetValue);
    final String badgeTitle = details['title'];
    final String badgeImagePath = details['imagePath'];
    final DateTime completionDate = achievement.completionDate ?? DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: Icon(Icons.close, color: Colors.black),
                  onPressed: () => Navigator.of(context).pop(),
                ),
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
              Text('${achievement.targetValue.toStringAsFixed(0)}KM', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.black)),
              SizedBox(height: 10),
              Text('총 ${achievement.targetValue.toStringAsFixed(0)}KM 달성', style: TextStyle(fontSize: 16, color: Colors.black), textAlign: TextAlign.center),
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    side: BorderSide(color: Colors.black),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 카드 UI (Icon -> Image.asset으로 수정)
  Widget _buildChallengeCard(AchievementInfo achievement) {
    final details = _getChallengeDetails(achievement.targetValue);
    final String badgeImagePath = details['imagePath'];
    double progress = (_totalDistance / achievement.targetValue).clamp(0.0, 1.0);
    final Color progressColor = achievement.isCompleted ? Colors.amber[400]! : Colors.grey;

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
                Text('+ ${achievement.targetValue.toStringAsFixed(0)}KM', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                Text(achievement.isCompleted ? '달성완료!' : '도전중', style: TextStyle(color: achievement.isCompleted ? Colors.amber[700] : Colors.grey[600], fontSize: 14)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin 사용
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
            // 총 누적 거리 카드
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
                          TextSpan(text: '+ ${_totalDistance.toStringAsFixed(1)}'),
                          TextSpan(text: 'KM', style: TextStyle(fontWeight: FontWeight.normal)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text('누적 거리', style: TextStyle(color: Colors.black, fontSize: 16)),
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

  // 탭 전환 시 상태 유지를 위해 true 반환
  @override
  bool get wantKeepAlive => true;
}