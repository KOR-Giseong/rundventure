import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'exercise_data.dart';
import 'exercise_service.dart';
// ▼▼▼▼▼ [ ✨ 추가된 import ✨ ] ▼▼▼▼▼
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ▲▲▲▲▲ [ ✨ 추가된 import ✨ ] ▲▲▲▲▲

class DistanceAchievementsTab extends StatefulWidget {
  final List<ExerciseRecord> allRecords;

  const DistanceAchievementsTab({Key? key, required this.allRecords}) : super(key: key);

  @override
  _DistanceAchievementsTabState createState() => _DistanceAchievementsTabState();
}

class _DistanceAchievementsTabState extends State<DistanceAchievementsTab>
    with AutomaticKeepAliveClientMixin {
  final ExerciseService _exerciseService = ExerciseService();
  // ▼▼▼▼▼ [ ✨ 추가된 인스턴스 ✨ ] ▼▼▼▼▼
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // ▲▲▲▲▲ [ ✨ 추가된 인스턴스 ✨ ] ▲▲▲▲▲
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

  // ▼▼▼▼▼ [ ✨ 추가된 함수 ✨ ] ▼▼▼▼▼
  // 도전과제 완료 알림을 생성하는 함수
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
        'type': 'achievement_completed', // 👈 알림 타입: 도전과제 완료
        'title': title,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'achievementId': achievementId, // (선택 사항)
      });

      // 알림 전송 성공 시 SharedPreferences에 기록
      await prefs.setBool(notificationKey, true);
      print("Achievement notification sent: $achievementId");

    } catch (e) {
      print("Error sending achievement notification: $e");
    }
  }
  // ▲▲▲▲▲ [ ✨ 추가된 함수 ✨ ] ▲▲▲▲▲

  void _calculateAchievements() async { // 👈 async로 변경
    if (mounted) setState(() => _isCalculating = true);

    // 총 거리 계산
    _totalDistance = _exerciseService.calculateTotalKilometers(widget.allRecords);

    // 각 목표별 달성 정보 계산
    List<AchievementInfo> achievements = [];
    for (double target in _targetDistances) {
      final achievementInfo = _exerciseService.getAchievementInfo(
        targetValue: target,
        allRecords: widget.allRecords,
        getValueFromRecord: (record) => record.kilometers, // 거리 값 사용
      );

      // ▼▼▼▼▼ [ ✨ 추가된 로직 ✨ ] ▼▼▼▼▼
      // 1. 도전과제가 '완료'되었는지 확인
      if (achievementInfo.isCompleted) {
        // 2. 이 도전과제에 대한 알림을 보낸 적이 있는지 확인 (send 함수 내부에서 처리)
        final details = _getChallengeDetails(target);
        final String title = "도전과제 달성: ${details['title']}";
        final String message = "누적 ${target.toStringAsFixed(0)}KM 달성을 축하합니다!";
        final String achievementId = 'distance_${target.toInt()}'; // 고유 ID

        // (비동기) 알림 전송 시도
        _sendAchievementNotification(achievementId, title, message);
      }
      // ▲▲▲▲▲ [ ✨ 추가된 로직 ✨ ] ▲▲▲▲▲

      achievements.add(achievementInfo);
    }

    if (mounted) { // 👈 mounted 확인 추가
      setState(() {
        _achievements = achievements;
        _isCalculating = false;
      });
    }
  }

  // ▼▼▼▼▼ [ ✨✨✨ 핵심 수정 부분 (칭호/이미지 경로) ✨✨✨ ] ▼▼▼▼▼
  // ✅✅✅ [이미지/타이틀 수정] 아이콘 대신 이미지 경로 반환 ✅✅✅
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
    else if (targetDistance <= 400) title = '레전드'; // 400
    else title = '히어로'; // 500KM (또는 그 이상)

    // [수정] 'icon' 대신 'imagePath'를 반환
    // (경로는 'assets/badges/'로, 파일명은 '10km.png' 형식으로 가정)
    final String imagePath = 'assets/badges/${targetDistance.toInt()}km.png';

    return {'title': title, 'imagePath': imagePath};
  }
  // ▲▲▲▲▲ [ ✨✨✨ 핵심 수정 부분 (칭호/이미지 경로) ✨✨✨ ] ▲▲▲▲▲

  // 팝업 (Icon -> Image.asset으로 수정)
  void showChallengeCompletionPopup(BuildContext context, AchievementInfo achievement) {
    final details = _getChallengeDetails(achievement.targetValue);
    final String badgeTitle = details['title'];
    // ▼▼▼▼▼ [ ✨ 수정된 부분 ✨ ] ▼▼▼▼▼
    final String badgeImagePath = details['imagePath']; // 👈 'icon' 대신 'imagePath' 사용
    // final IconData badgeIcon = details['icon']; // 👈 삭제
    // ▲▲▲▲▲ [ ✨ 수정된 부분 ✨ ] ▲▲▲▲▲
    final DateTime completionDate = achievement.completionDate ?? DateTime.now();
    // final Color completedColor = Colors.green[600]!; // 👈 팝업 이미지는 원본 색상 사용 (삭제 안 함)

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
                // ▼▼▼▼▼ [ ✨ 수정된 부분 ✨ ] ▼▼▼▼▼
                child: Image.asset(badgeImagePath, width: 100, height: 100), // 👈 Icon을 Image.asset으로 변경
                // child: Icon(badgeIcon, size: 100, color: completedColor), // 👈 삭제
                // ▲▲▲▲▲ [ ✨ 수정된 부분 ✨ ] ▲▲▲▲▲
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
    // ▼▼▼▼▼ [ ✨ 수정된 부분 ✨ ] ▼▼▼▼▼
    final String badgeImagePath = details['imagePath']; // 👈 'icon' 대신 'imagePath' 사용
    // final IconData badgeIcon = details['icon']; // 👈 삭제
    // ▲▲▲▲▲ [ ✨ 수정된 부분 ✨ ] ▲▲▲▲▲
    double progress = (_totalDistance / achievement.targetValue).clamp(0.0, 1.0);
    final Color progressColor = achievement.isCompleted ? Colors.amber[400]! : Colors.grey;
    // ▼▼▼▼▼ [ ✨ 수정된 부분 ✨ ] ▼▼▼▼▼
    // final Color iconColor = achievement.isCompleted ? Colors.green[600]! : Colors.grey[600]!; // 👈 삭제
    // ▲▲▲▲▲ [ ✨ 수정된 부분 ✨ ] ▲▲▲▲▲

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
                    // ▼▼▼▼▼ [ ✨ 수정된 부분 ✨ ] ▼▼▼K▼▼
                    // 👈 Icon을 Opacity와 Image.asset으로 변경
                    Opacity(
                      opacity: achievement.isCompleted ? 1.0 : 0.4, // 👈 미완료 시 40% 투명도
                      child: Image.asset(badgeImagePath, width: 90, height: 90),
                    ),
                    // Icon(badgeIcon, size: 60, color: iconColor), // 👈 삭제
                    // ▲▲▲▲▲ [ ✨ 수정된 부분 ✨ ] ▲▲▲▲▲
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
                  // ▼▼▼▼▼ [ ✨ 수정된 부분 ✨ ] ▼▼▼▼▼
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
                  // ▲▲▲▲▲ [ ✨ 수정된 부분 ✨ ] ▲▲▲▲▲
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