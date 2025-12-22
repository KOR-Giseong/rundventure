import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  final QuestService _questService = QuestService();
  late TabController _tabController;
  List<ExerciseRecord> _allRecords = [];
  bool _isLoading = true;

  bool _hasUnclaimedQuests = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      await Future.wait([
        _loadExerciseData(),
        _checkUnclaimedQuests(),
      ]);
    } catch (e) {
      if (mounted) {
        _showCustomSnackBar('데이터 로딩 중 오류가 발생했습니다.', isError: true);
      }
      print("Error loading data in AchievementScreen: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadExerciseData() async {
    final records = await _exerciseService.getAllExerciseRecords();
    if (mounted) {
      setState(() {
        _allRecords = records;
      });
    }
  }

  Future<void> _checkUnclaimedQuests() async {
    try {
      final questsResult = await _questService.getQuests();
      bool hasUnclaimed = questsResult.values
          .expand((list) => list)
          .any((quest) => quest.isCompleted && !quest.isClaimed);

      if (mounted) {
        setState(() {
          _hasUnclaimedQuests = hasUnclaimed;
        });
      }
    } catch (e) {
      print("Error checking unclaimed quests: $e");
      if (mounted) {
        setState(() {
          _hasUnclaimedQuests = false;
        });
      }
    }
  }

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
        title: Text(
          '도전과제',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
        actions: [
          Badge(
            isLabelVisible: _hasUnclaimedQuests,
            child: IconButton(
              icon: Icon(Icons.list_alt_outlined,
                  color: Colors.black87, size: 30),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => QuestScreen()),
                );
                if (mounted) {
                  _checkUnclaimedQuests();
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