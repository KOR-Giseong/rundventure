// exercise_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'exercise_data.dart'; // 수정된 모델 임포트

// 운동 기록 서비스
class ExerciseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 모든 운동 기록 가져오기 (수정됨)
  Future<List<ExerciseRecord>> getAllExerciseRecords() async {
    try {
      final String? userEmail = _auth.currentUser?.email;
      if (userEmail == null) {
        throw Exception('사용자 이메일을 가져올 수 없습니다.');
      }

      final workoutsSnapshot = await _firestore
          .collection('userRunningData')
          .doc(userEmail)
          .collection('workouts')
          .get();

      List<ExerciseRecord> allRecords = [];
      List<Future<QuerySnapshot>> futureList = workoutsSnapshot.docs.map((workoutDoc) {
        return _firestore
            .collection('userRunningData')
            .doc(userEmail)
            .collection('workouts')
            .doc(workoutDoc.id)
            .collection('records')
            .get();
      }).toList();

      final results = await Future.wait(futureList);

      for (final recordsSnapshot in results) {
        for (final recordDoc in recordsSnapshot.docs) {
          final data = recordDoc.data() as Map<String, dynamic>;

          // 'date' 필드가 있는지 확인 (필수)
          if (data.containsKey('date')) {
            // ExerciseRecord.fromFirestore 팩토리 사용 (모델 파일에 정의됨)
            // 'kilometers', 'calories', 'stepCount'는 모델 내부에서 ?? 0.0 처리
            allRecords.add(
                ExerciseRecord.fromFirestore(recordDoc)
            );
          }
        }
      }

      // 날짜순 정렬
      allRecords.sort((a, b) => a.date.compareTo(b.date));
      return allRecords;

    } catch (e) {
      rethrow;
    }
  }

  // 총 거리 계산
  double calculateTotalKilometers(List<ExerciseRecord> records) {
    double totalDistance = 0.0;
    for (var record in records) {
      totalDistance += record.kilometers;
    }
    return totalDistance;
  }

  // (신규) 총 칼로리 계산
  double calculateTotalCalories(List<ExerciseRecord> records) {
    double totalCalories = 0.0;
    for (var record in records) {
      totalCalories += record.calories;
    }
    return totalCalories;
  }

  // (신규) 총 걸음수 계산
  int calculateTotalSteps(List<ExerciseRecord> records) {
    int totalSteps = 0;
    for (var record in records) {
      totalSteps += record.stepCount;
    }
    return totalSteps;
  }


  // (신규) 범용 도전과제 달성 정보 계산 함수
  AchievementInfo getAchievementInfo({
    required double targetValue,
    required List<ExerciseRecord> allRecords,
    required double Function(ExerciseRecord) getValueFromRecord,
  }) {
    if (allRecords.isEmpty) {
      return AchievementInfo(
        targetValue: targetValue,
        isCompleted: false,
      );
    }

    double cumulativeValue = 0.0;
    DateTime? completionDate;

    // allRecords는 이미 날짜순으로 정렬되어 있음
    for (var record in allRecords) {
      cumulativeValue += getValueFromRecord(record);

      if (cumulativeValue >= targetValue && completionDate == null) {
        completionDate = record.date;
      }
    }

    return AchievementInfo(
      targetValue: targetValue,
      isCompleted: cumulativeValue >= targetValue,
      completionDate: completionDate,
    );
  }
}