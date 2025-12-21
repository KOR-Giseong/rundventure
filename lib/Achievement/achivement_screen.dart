import 'dart:async'; // ✅ [신규] StreamSubscription 임포트
import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ [신규] Firestore 임포트
import 'package:firebase_auth/firebase_auth.dart'; // ✅ [신규] Auth 임포트
import 'package:flutter/material.dart';
import 'package:rundventure/Achievement/quest_screen.dart';
import 'package:rundventure/Achievement/quest_service.dart';
import 'package:rundventure/Achievement/quest_data.dart';
import 'exercise_data.dart';
import 'exercise_service.dart';
import 'distance_achievements_tab.dart';
import 'calories_achievements_tab.dart';
import 'steps_achievements_tab.dart';

class AchievementScreen extends StatefulWidget {
  @override
  State<AchievementScreen> createState() => _AchievementScreenState();
}

class _AchievementScreenState extends State<AchievementScreen>
    with SingleTickerProviderStateMixin {
  final ExerciseService _exerciseService = ExerciseService();
  final QuestService _questService = QuestService(); // ✅ QuestService 인스턴스
  late TabController _tabController;
  List<ExerciseRecord> _allRecords = [];
  bool _isLoading = true;

  // ▼▼▼▼▼ [ ✨ 수정된 부분 ✨ ] ▼▼▼▼▼
  bool _hasUnclaimedQuests = false; // ✅ 퀘스트 알림 표시 상태 변수
  // (제목 옆 빨간점 관련 변수 _hasNewAchievements 및 구독 변수 제거)
  // ▲▲▲▲▲ [ ✨ 수정된 부분 ✨ ] ▲▲▲▲▲

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllData(); // ✅ 데이터 로드 함수 이름 변경 및 호출
    // (제목 옆 빨간점 관련 리스너 _listenForNewAchievements() 호출 제거)
  }

  @override
  void dispose() {
    _tabController.dispose();
    // (제목 옆 빨간점 관련 구독 취소 코드 제거)
    super.dispose();
  }

  // ▼▼▼▼▼ [ ✨ 수정된 부분 ✨ ] ▼▼▼▼▼
  // (제목 옆 빨간점 관련 함수 _listenForNewAchievements() 전체 제거)
  // ▲▲▲▲▲ [ ✨ 수정된 부분 ✨ ] ▲▲▲▲▲


  // ✅ 운동 기록과 퀘스트 상태를 함께 로드하는 함수
  Future<void> _loadAllData() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      // 두 작업 병렬 실행 (효율성)
      // ▼▼▼▼▼ [ ✨ 수정된 부분 ✨ ] ▼▼▼▼▼
      // (_checkNewAchievements는 리스너로 대체되었으므로 여기서는 퀘스트와 운동기록만 로드)
      await Future.wait([
        _loadExerciseData(),
        _checkUnclaimedQuests(),
      ]);
      // ▲▲▲▲▲ [ ✨ 수정된 부분 ✨ ] ▲▲▲▲▲
    } catch (e) {
      if (mounted) {
        // ▼▼▼▼▼ [ ✨ 수정된 부분 ✨ ] ▼▼▼▼▼
        // 기존 SnackBar 대신 _showCustomSnackBar 호출
        _showCustomSnackBar('데이터 로딩 중 오류가 발생했습니다.', isError: true);
        // ▲▲▲▲▲ [ ✨ 수정된 부분 ✨ ] ▲▲▲▲▲
      }
      print("Error loading data in AchievementScreen: $e");
    } finally {
      // 모든 로딩이 끝난 후 로딩 상태 해제
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ✅ 기존 운동 기록 로드 로직 분리
  Future<void> _loadExerciseData() async {
    final records = await _exerciseService.getAllExerciseRecords();
    if (mounted) {
      setState(() {
        _allRecords = records;
      });
    }
  }

  // ✅ 보상받지 않은 퀘스트 확인 함수
  Future<void> _checkUnclaimedQuests() async {
    try {
      final questsResult = await _questService.getQuests();
      bool hasUnclaimed = questsResult.values
          .expand((list) => list) // 모든 퀘스트 리스트를 하나로 합침
      // ▼▼▼▼▼ [ ✨ 수정된 부분 ✨ ] ▼▼▼▼▼
      // .any((quest) => quest.isCompleted); // (기존)
          .any((quest) => quest.isCompleted && !quest.isClaimed); // (수정: 보상 안 받은 퀘스트)
      // ▲▲▲▲▲ [ ✨ 수정된 부분 ✨ ] ▲▲▲▲▲

      if (mounted) {
        setState(() {
          _hasUnclaimedQuests = hasUnclaimed;
        });
      }
    } catch (e) {
      print("Error checking unclaimed quests: $e");
      // 퀘스트 확인 중 오류 발생 시 배지 표시 안 함 (선택 사항)
      if (mounted) {
        setState(() {
          _hasUnclaimedQuests = false;
        });
      }
    }
  }

  // ▼▼▼▼▼ [ ✨ 추가된 함수 ✨ ] ▼▼▼▼▼
  // ProfileScreen/RunningStatsPage에서 가져온 커스텀 스낵바 함수
  void _showCustomSnackBar(String message, {bool isError = false}) {
    if (!mounted) return; // Check mounted
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: isError
            ? Colors.redAccent.shade400
            : Color(0xFFFF9F80), // 에러는 붉은색, 성공은 주황색
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(15, 5, 15, 15),
        duration: Duration(seconds: isError ? 4 : 2), // 에러는 더 길게
      ),
    );
  }
  // ▲▲▲▲▲ [ ✨ 추가된 함수 ✨ ] ▲▲▲▲▲

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.grey[100],
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Padding(
            padding: const EdgeInsets.all(5.0),
            child: Image.asset(
              'assets/images/Back-Navs.png',
              width: 48,
              height: 48,
            ),
          ),
        ),
        // ▼▼▼▼▼ [ ✨ 수정된 부분 (타이틀) ✨ ] ▼▼▼▼▼
        title: Text(
          // ✅ Row에서 Text로 다시 변경 (빨간 점 제거)
          '도전과제',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
        // ▲▲▲▲▲ [ ✨ 수정된 부분 (타이틀) ✨ ] ▲▲▲▲▲
        centerTitle: true,
        actions: [
          // ✅ IconButton을 Badge로 감싸기
          Badge(
            // ✅ _hasUnclaimedQuests 상태에 따라 배지(점) 표시/숨김
            isLabelVisible: _hasUnclaimedQuests,
            // 기본 작은 점 모양 사용 (label을 설정하지 않음)
            // offset: Offset(-2, 2), // 필요시 위치 조정
            child: IconButton(
              icon: Icon(Icons.list_alt_outlined,
                  color: Colors.black87, size: 30),
              onPressed: () async {
                // QuestScreen으로 이동 후 돌아왔을 때 상태 갱신
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => QuestScreen()),
                );
                // QuestScreen에서 보상을 받으면 배지가 사라지도록 상태 재확인
                if (mounted) {
                  // ▼▼▼▼▼ [ ✨ 수정된 부분 ✨ ] ▼▼▼▼▼
                  // 퀘스트 확인 (배지 갱신)
                  _checkUnclaimedQuests();
                  // ▲▲▲▲▲ [ ✨ 수정된 부분 ✨ ] ▲▲▲▲▲
                }
              },
            ),
          ),
          SizedBox(width: MediaQuery.of(context).size.width * 0.02),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: Colors.black,
          tabs: const [
            Tab(icon: Icon(Icons.directions_run), text: '거리'),
            Tab(icon: Icon(Icons.local_fire_department), text: '칼로리'),
            Tab(icon: Icon(Icons.directions_walk), text: '걸음수'),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        // ✅ onRefresh에 _loadAllData 연결
        child: RefreshIndicator(
          onRefresh: _loadAllData,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
            controller: _tabController,
            children: [
              DistanceAchievementsTab(allRecords: _allRecords),
              CaloriesAchievementsTab(allRecords: _allRecords),
              StepsAchievementsTab(allRecords: _allRecords),
            ],
          ),
        ),
      ),
    );
  }
}