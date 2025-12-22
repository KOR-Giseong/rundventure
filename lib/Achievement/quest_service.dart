import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'quest_data.dart';
import 'package:rundventure/Achievement/exercise_service.dart';

class QuestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ExerciseService _exerciseService = ExerciseService();

  String? get _userEmail => _auth.currentUser?.email;

  CollectionReference get _questCollectionRef {
    if (_userEmail == null) throw Exception('로그인이 필요합니다.');
    return _firestore
        .collection('users')
        .doc(_userEmail)
        .collection('activeQuests');
  }

  Future<Map<QuestType, List<Quest>>> getQuests() async {
    if (_userEmail == null) return {};
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final startOfWeekDate = now.subtract(Duration(days: now.weekday - 1));
    final startOfWeek = DateTime(startOfWeekDate.year, startOfWeekDate.month, startOfWeekDate.day);
    final startOfMonth = DateTime(now.year, now.month, 1);
    final snapshot = await _questCollectionRef.get();
    List<Quest> activeQuests = snapshot.docs.map((doc) => Quest.fromFirestore(doc)).toList();
    List<Quest> daily = activeQuests.where((q) => q.type == QuestType.daily).toList();
    List<Quest> weekly = activeQuests.where((q) => q.type == QuestType.weekly).toList();
    List<Quest> monthly = activeQuests.where((q) => q.type == QuestType.monthly).toList();
    bool needsUpdate = false;

    // 퀘스트 생성 로직
    if (daily.isEmpty || (daily.isNotEmpty && daily.first.generatedAt.toDate().isBefore(startOfDay))) {
      await _generateQuests(QuestType.daily, 5);
      needsUpdate = true;
    }
    if (weekly.isEmpty || (weekly.isNotEmpty && weekly.first.generatedAt.toDate().isBefore(startOfWeek))) {
      await _generateQuests(QuestType.weekly, 4);
      needsUpdate = true;
    }
    if (monthly.isEmpty || (monthly.isNotEmpty && monthly.first.generatedAt.toDate().isBefore(startOfMonth))) {
      await _generateQuests(QuestType.monthly, 5);
      needsUpdate = true;
    }

    if (needsUpdate) {
      final updatedSnapshot = await _questCollectionRef.get();
      activeQuests = updatedSnapshot.docs.map((doc) => Quest.fromFirestore(doc)).toList();
    }

    await _updateQuestsProgress(activeQuests);

    final finalSnapshot = await _questCollectionRef.get();
    activeQuests = finalSnapshot.docs.map((doc) => Quest.fromFirestore(doc)).toList();

    final filteredQuests = activeQuests.where((q) => !q.isClaimed).toList();

    return {
      QuestType.daily: filteredQuests.where((q) => q.type == QuestType.daily).toList(),
      QuestType.weekly: filteredQuests.where((q) => q.type == QuestType.weekly).toList(),
      QuestType.monthly: filteredQuests.where((q) => q.type == QuestType.monthly).toList(),
    };
  }

  Future<void> _updateQuestsProgress(List<Quest> quests) async {
    if (_userEmail == null) return;
    if (quests.isEmpty) return;

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final startOfWeekDate = now.subtract(Duration(days: now.weekday - 1));
    final startOfWeek = DateTime(startOfWeekDate.year, startOfWeekDate.month, startOfWeekDate.day);
    final startOfMonth = DateTime(now.year, now.month, 1);

    final batch = _firestore.batch();

    final allRecords = await _exerciseService.getAllExerciseRecords();

    List<DocumentSnapshot> allGhostRuns = [];
    try {
      final ghostSnapshot = await _firestore.collection('ghostRunRecords').doc(_userEmail).collection('records').get();
      allGhostRuns = ghostSnapshot.docs;
    } catch (e) { print("고스트런 로딩 실패: $e"); }

    List<DocumentSnapshot> allJoinedChallenges = [];
    try {
      final challengeSnapshot = await _firestore.collection('challenges').where('participants', arrayContains: _userEmail).get();
      allJoinedChallenges = challengeSnapshot.docs;
    } catch (e) { print("챌린지 참여 로딩 실패: $e"); }

    List<DocumentSnapshot> allCreatedChallenges = [];
    try {
      final challengePostSnapshot = await _firestore.collection('challenges').where('userEmail', isEqualTo: _userEmail).get();
      allCreatedChallenges = challengePostSnapshot.docs;
    } catch (e) { print("챌린지 생성 로딩 실패: $e"); }

    List<DocumentSnapshot> allComments = [];
    try {
      final commentSnapshot = await _firestore.collectionGroup('comments').where('userEmail', isEqualTo: _userEmail).get();
      allComments = commentSnapshot.docs;
    } catch (e) { print("댓글 로딩 실패: $e"); }

    List<DocumentSnapshot> allFreeTalkLikes = [];
    try {
      final likeSnapshot = await _firestore.collectionGroup('likes').where('userEmail', isEqualTo: _userEmail).get();
      allFreeTalkLikes = likeSnapshot.docs.where((doc) => doc.reference.path.contains('freeTalks')).toList();
    } catch (e) { print("좋아요 로딩 실패: $e"); }

    List<DocumentSnapshot> allFreeTalkPosts = [];
    try {
      final postSnapshot = await _firestore.collection('freeTalks').where('userEmail', isEqualTo: _userEmail).get();
      allFreeTalkPosts = postSnapshot.docs;
    } catch (e) { print("글 작성 로딩 실패: $e"); }

    List<DocumentSnapshot> allGoals = [];
    try {
      final goalSnapshot = await _firestore.collection('userRunningGoals').doc(_userEmail).collection('dailyGoals').get();
      allGoals = goalSnapshot.docs;
    } catch (e) { print("목표 설정 로딩 실패: $e"); }

    List<DocumentSnapshot> allFriendBattles = [];
    try {
      final fbSnapshot = await _firestore
          .collection('friendBattles')
          .where('participants', arrayContains: _userEmail)
          .get();
      allFriendBattles = fbSnapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data['status'] == 'finished';
      }).toList();
    } catch (e) { print("실시간 대결 로딩 실패: $e"); }

    List<DocumentSnapshot> allAsyncBattles = [];
    try {
      final asyncChallenger = await _firestore
          .collection('asyncBattles')
          .where('challengerEmail', isEqualTo: _userEmail)
          .get();
      final asyncOpponent = await _firestore
          .collection('asyncBattles')
          .where('opponentEmail', isEqualTo: _userEmail)
          .get();

      final combined = [...asyncChallenger.docs, ...asyncOpponent.docs];
      final ids = <String>{};
      allAsyncBattles = combined.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        if (!ids.add(doc.id)) return false;
        return data['status'] == 'finished';
      }).toList();
    } catch (e) { print("오프라인 대결 로딩 실패: $e"); }

    for (var quest in quests) {
      if (quest.isCompleted && quest.isClaimed) continue;

      double currentValue = 0;
      final DateTime periodStartTime;
      switch (quest.type) {
        case QuestType.daily: periodStartTime = startOfDay; break;
        case QuestType.weekly: periodStartTime = startOfWeek; break;
        case QuestType.monthly: periodStartTime = startOfMonth; break;
      }
      final questStartTime = periodStartTime;

      if (quest.isCompleted) {
        currentValue = quest.currentValue;
      } else {
        switch (quest.metric) {
        // ... (기존 케이스 생략 없이 유지) ...
          case QuestMetric.km:
            final relevantRecords = allRecords.where((record) => record.date.isAfter(questStartTime));
            currentValue = relevantRecords.fold(0.0, (sum, record) => sum + record.kilometers);
            break;
          case QuestMetric.calories:
            final relevantRecords = allRecords.where((record) => record.date.isAfter(questStartTime));
            currentValue = relevantRecords.fold(0.0, (sum, record) => sum + record.calories);
            break;
          case QuestMetric.steps:
            final relevantRecords = allRecords.where((record) => record.date.isAfter(questStartTime));
            currentValue = relevantRecords.fold(0, (sum, record) => sum + record.stepCount).toDouble();
            break;
          case QuestMetric.ghostWins:
            currentValue = allGhostRuns.where((doc) {
              final data = doc.data() as Map<String, dynamic>?;
              final timestamp = data?['date'] as Timestamp?;
              final result = data?['raceResult'] as String?;
              return timestamp != null && result == 'win' && timestamp.toDate().isAfter(questStartTime);
            }).length.toDouble();
            break;
          case QuestMetric.ghostFirstRecord:
            currentValue = allGhostRuns.where((doc) {
              final data = doc.data() as Map<String, dynamic>?;
              final timestamp = data?['date'] as Timestamp?;
              final isFirst = data?['isFirstRecord'] as bool?;
              return timestamp != null && isFirst == true && timestamp.toDate().isAfter(questStartTime);
            }).length.toDouble();
            break;
          case QuestMetric.challengeJoin:
            currentValue = allJoinedChallenges.where((doc) {
              final data = doc.data() as Map<String, dynamic>?;
              final participantMap = data?['participantMap'] as Map<String, dynamic>?;
              if (participantMap == null || !participantMap.containsKey(_userEmail)) return false;
              try { return DateTime.parse(participantMap[_userEmail]).isAfter(questStartTime); } catch (e) { return false; }
            }).length.toDouble();
            break;
          case QuestMetric.challengePostWrite:
            currentValue = allCreatedChallenges.where((doc) {
              final data = doc.data() as Map<String, dynamic>?;
              final timestamp = data?['timestamp'] as Timestamp?;
              return timestamp != null && timestamp.toDate().isAfter(questStartTime);
            }).length.toDouble();
            break;
          case QuestMetric.commentWrite:
            currentValue = allComments.where((doc) {
              final data = doc.data() as Map<String, dynamic>?;
              final timestamp = data?['timestamp'] as Timestamp?;
              return timestamp != null && doc.reference.path.contains('freeTalks') && timestamp.toDate().isAfter(questStartTime);
            }).length.toDouble();
            break;
          case QuestMetric.challengeCommentWrite:
            currentValue = allComments.where((doc) {
              final data = doc.data() as Map<String, dynamic>?;
              final timestamp = data?['timestamp'] as Timestamp?;
              return timestamp != null && doc.reference.path.contains('challenges') && timestamp.toDate().isAfter(questStartTime);
            }).length.toDouble();
            break;
          case QuestMetric.postLike:
            currentValue = allFreeTalkLikes.where((doc) {
              final data = doc.data() as Map<String, dynamic>?;
              final timestamp = data?['timestamp'] as Timestamp?;
              return timestamp != null && timestamp.toDate().isAfter(questStartTime);
            }).length.toDouble();
            break;
          case QuestMetric.postWrite:
            currentValue = allFreeTalkPosts.where((doc) {
              final data = doc.data() as Map<String, dynamic>?;
              final timestamp = data?['timestamp'] as Timestamp?;
              return timestamp != null && timestamp.toDate().isAfter(questStartTime);
            }).length.toDouble();
            break;
          case QuestMetric.goalSet:
            currentValue = allGoals.where((doc) {
              final data = doc.data() as Map<String, dynamic>?;
              final timestamp = data?['updatedAt'] as Timestamp?;
              return timestamp != null && timestamp.toDate().isAfter(questStartTime);
            }).length.toDouble();
            break;
          case QuestMetric.challengeDistance:
            double totalChallengeDistance = 0.0;
            List<Map<String, DateTime>> challengePeriods = [];
            for (var challengeDoc in allJoinedChallenges) {
              final data = challengeDoc.data() as Map<String, dynamic>;
              final participantMap = data['participantMap'] as Map<String, dynamic>?;
              if (participantMap == null || !participantMap.containsKey(_userEmail)) continue;
              DateTime challengeJoinTime;
              try { challengeJoinTime = DateTime.parse(participantMap[_userEmail]); } catch (e) { continue; }
              final Timestamp? challengeCreateTime = data['timestamp'] as Timestamp?;
              final int durationDays = int.tryParse(data['duration'] ?? '0') ?? 0;
              if (challengeCreateTime == null || durationDays == 0) continue;
              final DateTime challengeEndTime = challengeCreateTime.toDate().add(Duration(days: durationDays));
              final DateTime effectiveStartTime = challengeJoinTime.isAfter(questStartTime) ? challengeJoinTime : questStartTime;
              if (effectiveStartTime.isBefore(challengeEndTime)) {
                challengePeriods.add({'start': effectiveStartTime, 'end': challengeEndTime});
              }
            }
            final relevantRecords = allRecords.where((record) => record.date.isAfter(questStartTime));
            for (var record in relevantRecords) {
              bool runWasInAChallenge = false;
              for (var period in challengePeriods) {
                if (record.date.isAfter(period['start']!) && record.date.isBefore(period['end']!)) {
                  runWasInAChallenge = true; break;
                }
              }
              if (runWasInAChallenge) { totalChallengeDistance += record.kilometers; }
            }
            currentValue = totalChallengeDistance;
            break;

          case QuestMetric.friendBattlePlay:
            currentValue = allFriendBattles.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final Timestamp? timestamp = data['updatedAt'] as Timestamp?;
              return timestamp != null && timestamp.toDate().isAfter(questStartTime);
            }).length.toDouble();
            break;

          case QuestMetric.friendBattleWin:
            int winCount = 0;
            for (var doc in allFriendBattles) {
              final data = doc.data() as Map<String, dynamic>;
              final Timestamp? timestamp = data['updatedAt'] as Timestamp?;
              if (timestamp != null && timestamp.toDate().isAfter(questStartTime)) {
                // 승리 여부 확인 (비동기 조회)
                final recordDoc = await doc.reference.collection('records').doc(_userEmail).get();
                if (recordDoc.exists && recordDoc.data()?['isWinner'] == true) {
                  winCount++;
                }
              }
            }
            currentValue = winCount.toDouble();
            break;

          case QuestMetric.asyncBattlePlay:
            currentValue = allAsyncBattles.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final Timestamp? timestamp = data['createdAt'] as Timestamp?; // 생성일(또는 완료일) 기준
              return timestamp != null && timestamp.toDate().isAfter(questStartTime);
            }).length.toDouble();
            break;

          case QuestMetric.asyncBattleWin:
            currentValue = allAsyncBattles.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final Timestamp? timestamp = data['createdAt'] as Timestamp?;
              final String? winnerEmail = data['winnerEmail'] as String?;
              return timestamp != null &&
                  timestamp.toDate().isAfter(questStartTime) &&
                  winnerEmail == _userEmail;
            }).length.toDouble();
            break;
        }
      }

      bool isCompleted = currentValue >= quest.targetValue.toDouble();
      final docRef = _questCollectionRef.doc(quest.id);

      if (quest.currentValue != currentValue || quest.isCompleted != isCompleted) {
        batch.update(docRef, {'currentValue': currentValue.toDouble(), 'isCompleted': isCompleted});
      }
    }

    try {
      await batch.commit();
    } catch (e) {
      print("퀘스트 진행도 업데이트 배치 커밋 실패: $e");
    }
  }

  Future<void> _generateQuests(QuestType type, int count) async {
    final oldQuests = await _questCollectionRef.where('type', isEqualTo: type.name).get();
    final batch = _firestore.batch();
    for (var doc in oldQuests.docs) { batch.delete(doc.reference); }
    final random = Random();
    final now = Timestamp.now();

    List<QuestMetric> availableMetrics = List.from(QuestMetric.values);
    availableMetrics.shuffle(random);
    availableMetrics.remove(QuestMetric.challengeDistance); // 월간 전용

    if (type == QuestType.daily && availableMetrics.length > count) {
      availableMetrics = availableMetrics.sublist(0, count);
    } else if (type == QuestType.weekly && availableMetrics.length > count) {
      availableMetrics = availableMetrics.sublist(0, count);
    }

    for (int i = 0; i < count; i++) {
      if (availableMetrics.isEmpty) { break; }
      final metric = availableMetrics.removeAt(0);

      double targetValue = 0.0; int rewardXp = 0; String title = '';

      switch (type) {
        case QuestType.daily:
          if (metric == QuestMetric.km) { title = '일일 러닝'; targetValue = (2 + random.nextInt(3)).toDouble(); rewardXp = 120; }
          else if (metric == QuestMetric.calories) { title = '일일 칼로리 소모'; targetValue = (100 + random.nextInt(101)).toDouble(); rewardXp = 80; }
          else if (metric == QuestMetric.steps) { title = '일일 걷기'; targetValue = (2000 + random.nextInt(1001)).toDouble(); rewardXp = 80; }
          else if (metric == QuestMetric.ghostWins) { title = '고스트전 승리'; targetValue = 1.0; rewardXp = 100; }
          else if (metric == QuestMetric.challengeJoin) { title = '챌린지 참여'; targetValue = 1.0; rewardXp = 70; }
          else if (metric == QuestMetric.commentWrite) { title = '자유게시판 댓글 작성'; targetValue = 1.0; rewardXp = 40; }
          else if (metric == QuestMetric.postLike) { title = '게시글 좋아요'; targetValue = 1.0; rewardXp = 20; }
          else if (metric == QuestMetric.postWrite) { title = '자유게시판 글 작성'; targetValue = 1.0; rewardXp = 120; }
          else if (metric == QuestMetric.goalSet) { title = '오늘의 목표 설정'; targetValue = 1.0; rewardXp = 40; }
          else if (metric == QuestMetric.ghostFirstRecord) { title = '고스트 첫 기록 측정'; targetValue = 1.0; rewardXp = 100; }
          else if (metric == QuestMetric.challengePostWrite) { title = '챌린지 생성'; targetValue = 1.0; rewardXp = 120; }
          else if (metric == QuestMetric.challengeCommentWrite) { title = '챌린지 댓글 작성'; targetValue = 1.0; rewardXp = 40; }
          else if (metric == QuestMetric.friendBattlePlay) { title = '실시간 대결 참여'; targetValue = 1.0; rewardXp = 100; }
          else if (metric == QuestMetric.friendBattleWin) { title = '실시간 대결 승리'; targetValue = 1.0; rewardXp = 150; }
          else if (metric == QuestMetric.asyncBattlePlay) { title = '오프라인 대결 참여'; targetValue = 1.0; rewardXp = 100; }
          else if (metric == QuestMetric.asyncBattleWin) { title = '오프라인 대결 승리'; targetValue = 1.0; rewardXp = 150; }
          break;

        case QuestType.weekly:
          if (metric == QuestMetric.km) { title = '주간 러닝'; targetValue = (20 + random.nextInt(11)).toDouble(); rewardXp = 500; }
          else if (metric == QuestMetric.calories) { title = '주간 칼로리 소모'; targetValue = (1000 + random.nextInt(501)).toDouble(); rewardXp = 400; }
          else if (metric == QuestMetric.steps) { title = '주간 걷기'; targetValue = (20000 + random.nextInt(10001)).toDouble(); rewardXp = 350; }
          else if (metric == QuestMetric.ghostWins) { title = '주간 고스트전 승리'; targetValue = (3 + random.nextInt(3)).toDouble(); rewardXp = 450; }
          else if (metric == QuestMetric.challengeJoin) { title = '주간 챌린지 참여'; targetValue = (2 + random.nextInt(2)).toDouble(); rewardXp = 300; }
          else if (metric == QuestMetric.commentWrite) { title = '주간 자유게시판 댓글'; targetValue = (3 + random.nextInt(3)).toDouble(); rewardXp = 200; }
          else if (metric == QuestMetric.postLike) { title = '주간 게시글 좋아요'; targetValue = (5 + random.nextInt(6)).toDouble(); rewardXp = 150; }
          else if (metric == QuestMetric.postWrite) { title = '주간 자유게시판 글 작성'; targetValue = (1 + random.nextInt(2)).toDouble(); rewardXp = 400; }
          else if (metric == QuestMetric.goalSet) { title = '주간 목표 설정'; targetValue = (3 + random.nextInt(3)).toDouble(); rewardXp = 150; }
          else if (metric == QuestMetric.ghostFirstRecord) { title = '주간 고스트 첫 기록 측정'; targetValue = 1.0; rewardXp = 100; }
          else if (metric == QuestMetric.challengePostWrite) { title = '주간 챌린지 생성'; targetValue = (1 + random.nextInt(2)).toDouble(); rewardXp = 400; }
          else if (metric == QuestMetric.challengeCommentWrite) { title = '주간 챌린지 댓글'; targetValue = (3 + random.nextInt(3)).toDouble(); rewardXp = 200; }
          else if (metric == QuestMetric.friendBattlePlay) { title = '주간 실시간 대결'; targetValue = (2 + random.nextInt(2)).toDouble(); rewardXp = 350; }
          else if (metric == QuestMetric.friendBattleWin) { title = '주간 실시간 대결 승리'; targetValue = (1 + random.nextInt(2)).toDouble(); rewardXp = 500; }
          else if (metric == QuestMetric.asyncBattlePlay) { title = '주간 오프라인 대결'; targetValue = (2 + random.nextInt(2)).toDouble(); rewardXp = 350; }
          else if (metric == QuestMetric.asyncBattleWin) { title = '주간 오프라인 대결 승리'; targetValue = (1 + random.nextInt(2)).toDouble(); rewardXp = 500; }
          break;

        case QuestType.monthly:
          if (metric == QuestMetric.km) { title = '월간 러닝'; targetValue = (100 + random.nextInt(51)).toDouble(); rewardXp = 1500; }
          else if (metric == QuestMetric.calories) { title = '월간 칼로리 소모'; targetValue = (5000 + random.nextInt(2001)).toDouble(); rewardXp = 1200; }
          else if (metric == QuestMetric.steps) { title = '월간 걷기'; targetValue = (100000 + random.nextInt(50001)).toDouble(); rewardXp = 1000; }
          else if (metric == QuestMetric.ghostWins) { title = '월간 고스트전 승리'; targetValue = (10 + random.nextInt(6)).toDouble(); rewardXp = 1300; }
          else if (metric == QuestMetric.challengeJoin) { title = '월간 챌린지 참여'; targetValue = (5 + random.nextInt(4)).toDouble(); rewardXp = 800; }
          else if (metric == QuestMetric.commentWrite) { title = '월간 자유게시판 댓글'; targetValue = (10 + random.nextInt(6)).toDouble(); rewardXp = 500; }
          else if (metric == QuestMetric.postLike) { title = '월간 게시글 좋아요'; targetValue = (20 + random.nextInt(11)).toDouble(); rewardXp = 400; }
          else if (metric == QuestMetric.postWrite) { title = '월간 자유게시판 글 작성'; targetValue = (3 + random.nextInt(3)).toDouble(); rewardXp = 1000; }
          else if (metric == QuestMetric.goalSet) { title = '월간 목표 설정'; targetValue = (10 + random.nextInt(6)).toDouble(); rewardXp = 300; }
          else if (metric == QuestMetric.ghostFirstRecord) { title = '월간 고스트 첫 기록 측정'; targetValue = 1.0; rewardXp = 100; }
          else if (metric == QuestMetric.challengePostWrite) { title = '월간 챌린지 생성'; targetValue = (3 + random.nextInt(3)).toDouble(); rewardXp = 1000; }
          else if (metric == QuestMetric.challengeCommentWrite) { title = '월간 챌린지 댓글'; targetValue = (10 + random.nextInt(6)).toDouble(); rewardXp = 500; }
          else if (metric == QuestMetric.challengeDistance) { title = '월간 챌린지 러닝'; targetValue = (50 + random.nextInt(51)).toDouble(); rewardXp = 1500; }
          else if (metric == QuestMetric.friendBattlePlay) { title = '월간 실시간 대결'; targetValue = (5 + random.nextInt(3)).toDouble(); rewardXp = 1000; }
          else if (metric == QuestMetric.friendBattleWin) { title = '월간 실시간 대결 승리'; targetValue = (3 + random.nextInt(3)).toDouble(); rewardXp = 1500; }
          else if (metric == QuestMetric.asyncBattlePlay) { title = '월간 오프라인 대결'; targetValue = (5 + random.nextInt(3)).toDouble(); rewardXp = 1000; }
          else if (metric == QuestMetric.asyncBattleWin) { title = '월간 오프라인 대결 승리'; targetValue = (3 + random.nextInt(3)).toDouble(); rewardXp = 1500; }
          break;
      }
      if (title.isEmpty) continue;
      String description = _getQuestDescription(metric, targetValue);

      final newDocRef = _questCollectionRef.doc();
      final newQuest = Quest(
        id: newDocRef.id,
        type: type,
        metric: metric,
        title: title,
        description: description,
        targetValue: targetValue,
        currentValue: 0.0,
        rewardXp: rewardXp,
        isCompleted: false,
        generatedAt: now,
        isClaimed: false,
      );

      batch.set(newDocRef, newQuest.toMap());
    }
    await batch.commit();
  }

  String _getQuestDescription(QuestMetric metric, double targetValue) {
    final formatter = NumberFormat('#,###');
    switch (metric) {
      case QuestMetric.km: return '자유러닝 ${formatter.format(targetValue)}km 달성하기';
      case QuestMetric.calories: return '총 ${formatter.format(targetValue)}kcal 소모하기';
      case QuestMetric.steps: return '총 ${formatter.format(targetValue)}걸음 달성하기';
      case QuestMetric.ghostWins: return '고스트전 ${formatter.format(targetValue)}회 승리하기';
      case QuestMetric.challengeJoin: return '챌린지 ${formatter.format(targetValue)}회 참여하기';
      case QuestMetric.commentWrite: return '자유게시판 댓글 ${formatter.format(targetValue)}회 작성하기';
      case QuestMetric.postLike: return '자유게시판 게시글 좋아요 ${formatter.format(targetValue)}회 누르기';
      case QuestMetric.postWrite: return '자유게시판 게시글 ${formatter.format(targetValue)}회 작성하기';
      case QuestMetric.goalSet: return '일일 목표 ${formatter.format(targetValue)}회 설정하기';
      case QuestMetric.ghostFirstRecord: return '고스트런 첫 기록 ${formatter.format(targetValue)}회 측정하기';
      case QuestMetric.challengePostWrite: return '챌린지 ${formatter.format(targetValue)}회 생성하기';
      case QuestMetric.challengeCommentWrite: return '챌린지 댓글 ${formatter.format(targetValue)}회 작성하기';
      case QuestMetric.challengeDistance: return '참여한 챌린지에서 총 ${formatter.format(targetValue)}km 달성하기';
      case QuestMetric.friendBattlePlay: return '실시간 대결 ${formatter.format(targetValue)}회 참여하기';
      case QuestMetric.friendBattleWin: return '실시간 대결 ${formatter.format(targetValue)}회 승리하기';
      case QuestMetric.asyncBattlePlay: return '오프라인 대결 ${formatter.format(targetValue)}회 참여하기';
      case QuestMetric.asyncBattleWin: return '오프라인 대결 ${formatter.format(targetValue)}회 승리하기';

      default: return '';
    }
  }

  Future<void> claimQuestReward(Quest quest) async {
    if (_userEmail == null) return;
    if (!quest.isCompleted) throw Exception('퀘스트가 완료되지 않았습니다.');

    final activeQuestRef = _questCollectionRef.doc(quest.id);
    final logRef = _firestore.collection('users').doc(_userEmail).collection('completedQuestsLog').doc(quest.id);
    final userRef = _firestore.collection('users').doc(_userEmail);

    final logDoc = await logRef.get();
    if (logDoc.exists) {
      await activeQuestRef.delete();
      throw Exception('이미 보상을 받았습니다.');
    }

    final batch = _firestore.batch();
    batch.delete(activeQuestRef);
    batch.set(logRef, {
      ...quest.toMap(),
      'isClaimed': true,
      'claimedAt': Timestamp.now()
    });
    batch.update(userRef, {
      'weeklyExp': FieldValue.increment(quest.rewardXp),
      'monthlyExp': FieldValue.increment(quest.rewardXp),
    });

    await batch.commit();
  }
}