// leveling_service.dart

import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rundventure/Achievement/exercise_data.dart';
import 'package:rundventure/Achievement/exercise_service.dart';

// (LevelData 클래스는 변경 없음)
class LevelData {
  final int level;
  final int currentLevelXp;
  final int requiredXp;
  final double progress;
  final int totalXp;

  LevelData({
    required this.level,
    required this.currentLevelXp,
    required this.requiredXp,
    required this.progress,
    required this.totalXp,
  });
}

class LevelingService {
  final FirebaseFirestore _firestore;
  final ExerciseService _exerciseService;

  LevelingService(this._firestore, this._exerciseService);

  // (XP, 레벨 공식 변경 없음)
  final int _xpPerKm = 100;
  final int _ghostWinBonusXp = 50;
  final double _baseXp = 500.0;

  int _getTotalXpForLevel(int level) {
    if (level <= 1) return 0;
    return ((level * (level - 1) / 2) * _baseXp).round();
  }

  int _getLevel(int totalXp) {
    if (totalXp < _baseXp) return 1;
    int level = ((1 + sqrt(1 + 8 * totalXp / _baseXp)) / 2).floor();
    return level;
  }

  // (✅ 수정됨) 퀘스트 XP 계산 함수
  Future<int> _calculateQuestXp(String email) async {
    int questXp = 0;

    // '보상 받기'를 누른 퀘스트 로그를 읽어와서 XP 합산
    final questSnapshot = await _firestore
        .collection('users')
        .doc(email)
        .collection('completedQuestsLog') // ✅ 'activeQuests'가 아닌 'log'를 읽음
        .get();

    for (var doc in questSnapshot.docs) {
      // ✅ [수정] doc.data()를 Map으로 변환
      final data = doc.data() as Map<String, dynamic>;
      // ✅ [수정] 안전하게 'num' 타입으로 받고 toInt()
      questXp += (data['rewardXp'] as num? ?? 0).toInt();
    }

    return questXp;
  }

  // 1. 총 누적 XP 계산 (✅ 수정됨)
  Future<int> calculateTotalXp(String email) async {
    int totalXp = 0;

    try {
      // 1. 자유러닝 XP
      final List<ExerciseRecord> freeRuns = await _exerciseService.getAllExerciseRecords();
      for (var run in freeRuns) {
        totalXp += (run.kilometers * _xpPerKm).round();
      }

      // 2. 고스트런 XP
      final ghostRunsSnapshot = await _firestore
          .collection('ghostRunRecords')
          .doc(email)
          .collection('records')
          .get();

      for (var doc in ghostRunsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>; // ✅ 여기도 캐스팅 추가
        double distance = (data['distance'] as num? ?? 0.0).toDouble();
        String raceResult = data['raceResult'] ?? '';

        totalXp += (distance * _xpPerKm).round();
        if (raceResult == 'win') {
          totalXp += _ghostWinBonusXp;
        }
      }

      // 3. 퀘스트 완료 보상 XP (✅ 수정된 함수 호출)
      int questXp = await _calculateQuestXp(email);
      totalXp += questXp;

    } catch (e) {
      print("XP 계산 중 오류 발생: $e");
    }

    return totalXp;
  }

  // 2. 레벨 데이터 계산 (변경 없음)
  LevelData calculateLevelData(int totalXp) {
    int level = _getLevel(totalXp);
    int xpForCurrentLevel = _getTotalXpForLevel(level);
    int xpForNextLevel = _getTotalXpForLevel(level + 1);
    int currentLevelXp = totalXp - xpForCurrentLevel;
    int requiredXp = xpForNextLevel - xpForCurrentLevel;
    double progress = (requiredXp > 0) ? (currentLevelXp.toDouble() / requiredXp.toDouble()) : 0.0;

    return LevelData(
      level: level,
      currentLevelXp: currentLevelXp,
      requiredXp: requiredXp,
      progress: progress.clamp(0.0, 1.0),
      totalXp: totalXp,
    );
  }
}