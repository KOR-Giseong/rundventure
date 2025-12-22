import 'package:cloud_firestore/cloud_firestore.dart';

enum QuestType { daily, weekly, monthly }

enum QuestMetric {
  km,
  calories,
  steps,
  ghostWins,
  challengeJoin,      // 챌린지 참여
  commentWrite,       // 자유게시판 댓글
  postLike,           // 자유게시판 좋아요
  postWrite,          // 자유게시판 글 작성
  goalSet,            // 목표 설정
  ghostFirstRecord,   // 고스트런 첫 기록
  challengePostWrite, // 챌린지 생성 (글 작성)
  challengeCommentWrite, // 챌린지 댓글
  challengeDistance,   // 챌린지에서 뛴 거리
  friendBattlePlay,   // 실시간 대결 플레이 (승패 무관)
  friendBattleWin,    // 실시간 대결 승리
  asyncBattlePlay,    // 오프라인 대결 플레이 (승패 무관)
  asyncBattleWin      // 오프라인 대결 승리
}

class Quest {
  final String id;
  final QuestType type;
  final QuestMetric metric;
  final String title;
  final String description;
  final double targetValue;
  final double currentValue;
  final int rewardXp;
  final bool isCompleted;
  final Timestamp generatedAt;
  final bool isClaimed; // 보상 수령 여부

  Quest({
    required this.id,
    required this.type,
    required this.metric,
    required this.title,
    required this.description,
    required this.targetValue,
    required this.currentValue,
    required this.rewardXp,
    required this.isCompleted,
    required this.generatedAt,
    required this.isClaimed,
  });

  factory Quest.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Quest(
      id: doc.id,
      type: QuestType.values.byName(data['type'] ?? 'daily'),
      metric: QuestMetric.values.firstWhere(
            (e) => e.name == data['metric'],
        orElse: () => QuestMetric.km,
      ),
      title: data['title'] ?? '퀘스트',
      description: data['description'] ?? '',
      targetValue: (data['targetValue'] as num? ?? 0.0).toDouble(),
      currentValue: (data['currentValue'] as num? ?? 0.0).toDouble(),
      rewardXp: (data['rewardXp'] as num? ?? 0).toInt(),
      isCompleted: data['isCompleted'] ?? false,
      generatedAt: data['generatedAt'] ?? Timestamp.now(),
      isClaimed: data['isClaimed'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'metric': metric.name,
      'title': title,
      'description': description,
      'targetValue': targetValue,
      'currentValue': currentValue,
      'rewardXp': rewardXp,
      'isCompleted': isCompleted,
      'generatedAt': generatedAt,
      'isClaimed': isClaimed,
    };
  }
}