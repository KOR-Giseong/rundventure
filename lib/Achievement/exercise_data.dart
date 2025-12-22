// exercise_data.dart

import 'package:cloud_firestore/cloud_firestore.dart';

// 운동 기록 모델 (칼로리, 걸음수 추가)
class ExerciseRecord {
  final String id;
  final double kilometers;
  final double calories; // 칼로리 추가
  final int stepCount;   // 걸음수 추가
  final DateTime date;
  final String userId;

  ExerciseRecord({
    required this.id,
    required this.kilometers,
    required this.calories,
    required this.stepCount,
    required this.date,
    required this.userId,
  });

  factory ExerciseRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ExerciseRecord(
      id: doc.id,
      kilometers: (data['kilometers'] as num? ?? 0.0).toDouble(),
      calories: (data['calories'] as num? ?? 0.0).toDouble(),
      stepCount: (data['stepCount'] as num? ?? 0).toInt(),
      date: (data['date'] as Timestamp).toDate(),
      userId: data['userId'] ?? (data['userEmail'] ?? ''),
    );
  }
}

// 도전과제 달성 정보 모델 (변경 없음)
class AchievementInfo {
  final double targetValue;
  final bool isCompleted;
  final DateTime? completionDate;

  AchievementInfo({
    required this.targetValue,
    required this.isCompleted,
    this.completionDate,
  });
}