import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rundventure/Achievement/exercise_data.dart';
import 'package:rundventure/Achievement/exercise_service.dart';

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

  Future<int> _calculateQuestXp(String email) async {
    int questXp = 0;

    final questSnapshot = await _firestore
        .collection('users')
        .doc(email)
        .collection('completedQuestsLog')
        .get();

    for (var doc in questSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      questXp += (data['rewardXp'] as num? ?? 0).toInt();
    }

    return questXp;
  }

  Future<int> calculateTotalXp(String email) async {
    int totalXp = 0;

    try {
      final List<ExerciseRecord> freeRuns = await _exerciseService.getAllExerciseRecords();
      for (var run in freeRuns) {
        totalXp += (run.kilometers * _xpPerKm).round();
      }

      final ghostRunsSnapshot = await _firestore
          .collection('ghostRunRecords')
          .doc(email)
          .collection('records')
          .get();

      for (var doc in ghostRunsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        double distance = (data['distance'] as num? ?? 0.0).toDouble();
        String raceResult = data['raceResult'] ?? '';

        totalXp += (distance * _xpPerKm).round();
        if (raceResult == 'win') {
          totalXp += _ghostWinBonusXp;
        }
      }

      int questXp = await _calculateQuestXp(email);
      totalXp += questXp;

    } catch (e) {
      print("XP 계산 중 오류 발생: $e");
    }

    return totalXp;
  }

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