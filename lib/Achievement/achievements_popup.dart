import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rundventure/Achievement/exercise_service.dart';
import 'package:rundventure/Achievement/exercise_data.dart';

class AchievementsPopup extends StatefulWidget {
  const AchievementsPopup({Key? key}) : super(key: key);

  @override
  _AchievementsPopupState createState() => _AchievementsPopupState();
}

class _AchievementsPopupState extends State<AchievementsPopup> {
  final ExerciseService _exerciseService = ExerciseService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NumberFormat _formatter = NumberFormat('#,###');

  bool _isLoadingAchievements = true;
  bool _isLoadingHallOfFame = true; // 내 랭킹 기록 로딩 상태
  String? _errorMessage;

  // 도전과제 데이터
  List<AchievementInfo> _distanceAchievements = [];
  List<AchievementInfo> _calorieAchievements = [];
  List<AchievementInfo> _stepAchievements = [];

  // 내 랭킹 히스토리 데이터 (남의 랭킹 변수는 삭제함)
  List<Map<String, dynamic>> _myHallOfFame = []; // 내 명예의 전당 (월간)
  List<Map<String, dynamic>> _myWeeklyHistory = []; // 👈 [신규] 내 주간 랭킹 기록

  // (탭 목표치 리스트)
  final List<double> _targetDistances = [
    10, 30, 50, 100, 150, 200, 300, 400, 500
  ];
  final List<double> _targetCalories = [
    100, 500, 1500, 3000, 5000, 8000, 15000, 30000, 50000
  ];
  final List<double> _targetSteps = [
    2000, 5000, 15000, 35000, 70000, 200000, 500000, 1000000, 2000000
  ];

  @override
  void initState() {
    super.initState();
    // 도전과제와 "내 랭킹 기록"만 로드 (남의 랭킹 로드 함수 삭제)
    _loadAllAchievements();
    _loadMyRankingHistory();
  }

  // (도전과제 로드 함수)
  Future<void> _loadAllAchievements() async {
    if (!mounted) return;
    setState(() => _isLoadingAchievements = true);
    try {
      final allRecords = await _exerciseService.getAllExerciseRecords();
      if (!mounted) return;
      List<AchievementInfo> distAch = [];
      for (double target in _targetDistances) {
        distAch.add(_exerciseService.getAchievementInfo(targetValue: target, allRecords: allRecords, getValueFromRecord: (r) => r.kilometers));
      }
      List<AchievementInfo> calAch = [];
      for (double target in _targetCalories) {
        calAch.add(_exerciseService.getAchievementInfo(targetValue: target, allRecords: allRecords, getValueFromRecord: (r) => r.calories));
      }
      List<AchievementInfo> stepAch = [];
      for (double target in _targetSteps) {
        stepAch.add(_exerciseService.getAchievementInfo(targetValue: target, allRecords: allRecords, getValueFromRecord: (r) => r.stepCount.toDouble()));
      }
      if (mounted) {
        setState(() {
          _distanceAchievements = distAch.where((a) => a.isCompleted).toList();
          _calorieAchievements = calAch.where((a) => a.isCompleted).toList();
          _stepAchievements = stepAch.where((a) => a.isCompleted).toList();
          _isLoadingAchievements = false;
        });
      }
    } catch (e) {
      print("Error loading achievements: $e");
      if (mounted) {
        setState(() {
          _isLoadingAchievements = false;
          _errorMessage = "도전과제를 불러오는 중 오류가 발생했습니다.";
        });
      }
    }
  }

  // ✅ 내 랭킹 히스토리 (월간 Hall of Fame + 주간 History) 로드 함수
  Future<void> _loadMyRankingHistory() async {
    if (!mounted) return;
    setState(() => _isLoadingHallOfFame = true);

    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      if (mounted) setState(() => _isLoadingHallOfFame = false);
      return;
    }

    try {
      final doc = await _firestore.collection('users').doc(user.email).get();
      if (!mounted) return;

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;

        // 1. 월간 명예의 전당 (hallOfFame)
        if (data['hallOfFame'] != null && data['hallOfFame'] is List) {
          final hallData = List<Map<String, dynamic>>.from(
              (data['hallOfFame'] as List).map((item) => Map<String, dynamic>.from(item))
          );
          // 최신순 정렬
          hallData.sort((a, b) => (b['month'] as String? ?? '').compareTo(a['month'] as String? ?? ''));
          _myHallOfFame = hallData;
        }

        // 2. 주간 랭킹 기록 (weeklyHistory) - 새로 추가됨
        if (data['weeklyHistory'] != null && data['weeklyHistory'] is List) {
          final weekData = List<Map<String, dynamic>>.from(
              (data['weeklyHistory'] as List).map((item) => Map<String, dynamic>.from(item))
          );
          // 최신순 정렬
          weekData.sort((a, b) => (b['week'] as String? ?? '').compareTo(a['week'] as String? ?? ''));
          _myWeeklyHistory = weekData;
        }

        if (mounted) setState(() {});
      }
    } catch (e) {
      print("Error loading my ranking history: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoadingHallOfFame = false);
      }
    }
  }

  // (칭호/이미지 경로 헬퍼 함수들)
  Map<String, dynamic> _getDistanceChallengeDetails(double targetDistance) {
    String title;
    if (targetDistance <= 10) title = '첫걸음';
    else if (targetDistance <= 30) title = '마라토너';
    else if (targetDistance <= 50) title = '꾸준함';
    else if (targetDistance <= 100) title = '러너';
    else if (targetDistance <= 150) title = '프로';
    else if (targetDistance <= 200) title = '엘리트';
    else if (targetDistance <= 300) title = '마스터';
    else if (targetDistance <= 400) title = '레전드';
    else title = '히어로';

    final String imagePath = 'assets/badges/${targetDistance.toInt()}km.png';
    return {'title': title, 'imagePath': imagePath};
  }

  Map<String, dynamic> _getCaloriesChallengeDetails(double targetValue) {
    String title;
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

  Map<String, dynamic> _getStepsChallengeDetails(double targetValue) {
    String title;
    if (targetValue <= 2000) title = '첫 산책';
    else if (targetValue <= 5000) title = '동네 한 바퀴';
    else if (targetValue <= 15000) title = '꾸준한 워커';
    else if (targetValue <= 35000) title = '트레킹 입문';
    else if (targetValue <= 70000) title = '장거리 여행자';
    else if (targetValue <= 200000) title = '대륙 탐험가';
    else if (targetValue <= 500000) title = '지구 순례자';
    else if (targetValue <= 1000000) title = '백만 걸음의 신화';
    else title = '천리안';

    final String imagePath = 'assets/badges/${targetValue.toInt()}.png';
    return {'title': title, 'imagePath': imagePath};
  }


  // 팝업 내부 컨텐츠 빌드
  Widget _buildContent() {
    if (_isLoadingAchievements || _isLoadingHallOfFame) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFFF9F80)));
    }
    if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!, style: TextStyle(color: Colors.redAccent)));
    }

    final allCompletedAchievements = [..._distanceAchievements, ..._calorieAchievements, ..._stepAchievements];

    // 아무 기록도 없을 때
    if (allCompletedAchievements.isEmpty && _myHallOfFame.isEmpty && _myWeeklyHistory.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hourglass_empty, size: 40, color: Colors.grey),
            SizedBox(height: 10),
            Text('아직 달성한 도전과제나 랭킹 기록이 없습니다.', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView(
      shrinkWrap: true,
      children: [
        // ✅ 1. 내 명예의 전당 섹션 (월간)
        _buildMyHallOfFameSection(),

        // ✅ 2. 내 주간 랭킹 기록 섹션
        _buildMyWeeklyHistorySection(),

        // 구분선 (랭킹 기록이 있고, 도전과제도 있을 때만)
        if ((_myHallOfFame.isNotEmpty || _myWeeklyHistory.isNotEmpty) && allCompletedAchievements.isNotEmpty)
          const Divider(height: 24, indent: 16, endIndent: 16, thickness: 1),

        // ✅ 3. 도전과제 섹션들
        if (allCompletedAchievements.isNotEmpty) ...[
          _buildSection(title: "거리 도전과제", completedAchievements: _distanceAchievements, detailsGetter: _getDistanceChallengeDetails, unit: 'KM'),
          _buildSection(title: "칼로리 도전과제", completedAchievements: _calorieAchievements, detailsGetter: _getCaloriesChallengeDetails, unit: 'Kcal'),
          _buildSection(title: "걸음수 도전과제", completedAchievements: _stepAchievements, detailsGetter: _getStepsChallengeDetails, unit: '걸음'),
        ]
      ],
    );
  }

  // (지난주 Top 3 섹션 위젯은 완전히 삭제했습니다)

  // ✅ 내 명예의 전당 섹션 위젯 (월간)
  Widget _buildMyHallOfFameSection() {
    if (_isLoadingHallOfFame || _myHallOfFame.isEmpty) {
      return Container();
    }
    // 랭크별 아이콘/색상
    final Map<int, Map<String, dynamic>> rankDetails = {
      1: {'icon': Icons.emoji_events, 'color': Colors.amber.shade700},
      2: {'icon': Icons.emoji_events, 'color': Colors.grey.shade500},
      3: {'icon': Icons.emoji_events, 'color': Colors.brown.shade400},
    };
    final defaultDetail = {'icon': Icons.military_tech_outlined, 'color': Colors.grey.shade400};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Icon(Icons.shield_outlined, color: Colors.black87, size: 20),
              SizedBox(width: 8),
              Text(
                "내 명예의 전당 (월간)",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ],
          ),
        ),
        ..._myHallOfFame.map((entry) {
          final rank = (entry['rank'] as num?)?.toInt() ?? 0;
          final month = entry['month'] as String? ?? '????-??';
          final exp = (entry['exp'] as num?)?.toInt() ?? 0;
          final details = rankDetails[rank] ?? defaultDetail;

          return ListTile(
            dense: true,
            leading: Icon(details['icon'], color: details['color'], size: 30),
            title: Text('$month 월간 랭킹 $rank위', style: TextStyle(fontWeight: FontWeight.w500)),
            trailing: Text('${_formatter.format(exp)} EXP', style: TextStyle(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w500)),
          );
        }).toList(),
      ],
    );
  }

  // ✅ [신규] 내 주간 랭킹 기록 섹션 위젯
  Widget _buildMyWeeklyHistorySection() {
    if (_isLoadingHallOfFame || _myWeeklyHistory.isEmpty) {
      return Container();
    }
    // 랭크별 아이콘/색상
    final Map<int, Map<String, dynamic>> rankDetails = {
      1: {'icon': Icons.emoji_events, 'color': Colors.amber.shade700},
      2: {'icon': Icons.emoji_events, 'color': Colors.grey.shade500},
      3: {'icon': Icons.emoji_events, 'color': Colors.brown.shade400},
    };
    final defaultDetail = {'icon': Icons.military_tech_outlined, 'color': Colors.grey.shade400};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Icon(Icons.history, color: Colors.black87, size: 20),
              SizedBox(width: 8),
              Text(
                "내 주간 랭킹 기록",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ],
          ),
        ),
        ..._myWeeklyHistory.map((entry) {
          final rank = (entry['rank'] as num?)?.toInt() ?? 0;
          final week = entry['week'] as String? ?? '????-??-??';
          final exp = (entry['exp'] as num?)?.toInt() ?? 0;
          final details = rankDetails[rank] ?? defaultDetail;

          return ListTile(
            dense: true,
            leading: Icon(details['icon'], color: details['color'], size: 30),
            title: Text('$week 주간 랭킹 $rank위', style: TextStyle(fontWeight: FontWeight.w500)),
            trailing: Text('${_formatter.format(exp)} EXP', style: TextStyle(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w500)),
          );
        }).toList(),
      ],
    );
  }


  // (도전과제 섹션 빌드 헬퍼)
  Widget _buildSection({
    required String title,
    required List<AchievementInfo> completedAchievements,
    required Map<String, dynamic> Function(double) detailsGetter,
    required String unit,
  }) {
    if (completedAchievements.isEmpty) {
      return Container();
    }
    final formatter = NumberFormat('#,###');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
        ),
        ...completedAchievements.map((ach) {
          final details = detailsGetter(ach.targetValue);
          final String badgeTitle = details['title'];
          final String badgeImagePath = details['imagePath'];

          return ListTile(
            dense: true,
            leading: Image.asset(badgeImagePath, width: 30, height: 30),
            title: Text(badgeTitle, style: TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text("${formatter.format(ach.targetValue)} $unit 달성", style: TextStyle(fontSize: 13, color: Colors.grey[700])),
            trailing: Text(ach.completionDate != null ? DateFormat('yyyy.MM.dd').format(ach.completionDate!) : '', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          );
        }).toList(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      contentPadding: EdgeInsets.zero,
      content: Container(
        width: double.maxFinite,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
        child: _buildContent(),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actionsPadding: const EdgeInsets.only(bottom: 8, top: 0),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('닫기', style: TextStyle(color: Color(0xFFFF9F80), fontWeight: FontWeight.bold, fontSize: 16)),
        ),
      ],
    );
  }
}