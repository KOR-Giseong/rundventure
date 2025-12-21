// [전체 코드] friend_battle_history_tab.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

// Part 2에서 수정한 결과 화면
import 'friend_battle_result_screen.dart';
// RouteDataPoint (free_running_start.dart)
import 'package:rundventure/free_running/free_running_start.dart';


class FriendBattleHistoryTab extends StatelessWidget {
  final String myEmail;
  const FriendBattleHistoryTab({Key? key, required this.myEmail}) : super(key: key);

  // 헬퍼: 시간 포맷
  String _formatTime(int seconds) {
    final int minutes = (seconds ~/ 60) % 60;
    final int hours = seconds ~/ 3600;
    final int remainingSeconds = seconds % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
    } else {
      return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
    }
  }

  // 헬퍼: 페이스 포맷
  String _formatPace(double pace) {
    if (pace <= 0.0 || !pace.isFinite) return "--'--''";
    int minutes = pace.floor();
    int seconds = ((pace - minutes) * 60).round();
    if (seconds == 60) { minutes++; seconds = 0; }
    return '${minutes}\'${seconds.toString().padLeft(2, '0')}\'\'';
  }

  // 스낵바 헬퍼
  void _showCustomSnackBar(BuildContext context, String message, {bool isError = false}) {
    if (!ScaffoldMessenger.of(context).mounted) return;
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
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.redAccent.shade400 : Colors.blueAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(15, 5, 15, 15),
      ),
    );
  }


  // ▼▼▼▼▼ [ ⭐️⭐️⭐️ 상세 페이지 이동 로직 수정 ⭐️⭐️⭐️ ] ▼▼▼▼▼
  /// 상세 기록 조회 로직 (밀리초 데이터 포함)
  void _navigateToResult(BuildContext context, DocumentSnapshot battleDoc) async {
    // 1. 로딩 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (BuildContext context) => Center(child: CircularProgressIndicator()),
    );

    try {
      final battleData = battleDoc.data() as Map<String, dynamic>;
      final String battleId = battleDoc.id;

      // 2. 'records' 컬렉션에서 모든 참가자의 기록 쿼리
      final _firestore = FirebaseFirestore.instance;
      final runRecordSnapshot = await _firestore
          .collection('friendBattles')
          .doc(battleId)
          .collection('records')
          .get();

      // 3. 로딩 닫기
      Navigator.of(context, rootNavigator: true).pop();

      if (runRecordSnapshot.docs.isEmpty) {
        // (주의) Part 2 적용 전의 옛날 데이터는 기록이 없을 수 있음
        _showCustomSnackBar(context, '상세 기록이 존재하지 않습니다. (업데이트 전 기록)', isError: true);
        return;
      }

      // 4. 내 기록과 상대방 기록 분리 및 파싱
      List<RouteDataPoint> myRoutePoints = [];
      List<RouteDataPoint>? opponentRoutePoints = null;

      int myFinalSeconds = 0;
      // ▼▼▼▼▼ [ ⭐️ 밀리초 변수 추가 ⭐️ ] ▼▼▼▼▼
      int? myFinalTimeMs; // DB에서 가져올 밀리초
      // ▲▲▲▲▲ [ ⭐️ 밀리초 변수 추가 ⭐️ ] ▲▲▲▲▲

      int myStepCount = 0;
      double myElevation = 0.0;
      double myAverageSpeed = 0.0;
      double myCalories = 0.0;
      bool myDataFound = false;

      for (var doc in runRecordSnapshot.docs) {
        final runRecordData = doc.data();

        // 경로 데이터 역직렬화
        List<RouteDataPoint> routePoints = [];
        if (runRecordData['routePointsWithSpeed'] != null) {
          routePoints = (runRecordData['routePointsWithSpeed'] as List)
              .map((map) => RouteDataPoint.fromMap(map as Map<String, dynamic>))
              .toList();
        }

        if (runRecordData['email'] == myEmail) {
          // 내 기록
          myRoutePoints = routePoints;
          myFinalSeconds = runRecordData['seconds'] as int;
          // ▼▼▼▼▼ [ ⭐️ 밀리초 데이터 추출 ⭐️ ] ▼▼▼▼▼
          // DB에 'finalTimeMs'가 있으면 가져오고, 없으면(구버전 데이터) null
          myFinalTimeMs = runRecordData['finalTimeMs'] as int?;
          // ▲▲▲▲▲ [ ⭐️ 밀리초 데이터 추출 ⭐️ ] ▲▲▲▲▲

          myStepCount = runRecordData['stepCount'] as int;
          myElevation = (runRecordData['elevation'] as num).toDouble();
          myAverageSpeed = (runRecordData['averageSpeed'] as num).toDouble();
          myCalories = (runRecordData['calories'] as num).toDouble();
          myDataFound = true;
        } else {
          // 상대방 기록 (지도에 표시하기 위해 저장)
          opponentRoutePoints = routePoints;
        }
      }

      if (!myDataFound) {
        _showCustomSnackBar(context, '내 상세 기록을 찾을 수 없습니다.', isError: true);
        return;
      }

      // 5. 상세 화면으로 이동
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (context) => FriendBattleResultScreen(
            battleId: battleId,
            finalBattleData: battleData,

            // 내 상세 정보
            myRoutePoints: myRoutePoints,
            myFinalSeconds: myFinalSeconds,
            // ▼▼▼▼▼ [ ⭐️ 밀리초 전달 ⭐️ ] ▼▼▼▼▼
            myFinalTimeMs: myFinalTimeMs, // 👈 여기에 밀리초 전달
            // ▲▲▲▲▲ [ ⭐️ 밀리초 전달 ⭐️ ] ▲▲▲▲▲

            myStepCount: myStepCount,
            myElevation: myElevation,
            myAverageSpeed: myAverageSpeed,
            myCalories: myCalories,

            // 상대방 경로 전달
            opponentRoutePoints: opponentRoutePoints,

            // 히스토리에서 진입함 표시
            isFromHistory: true,
          ),
        ),
      );

    } catch (e) {
      // 로딩 닫기가 안 된 상태일 수 있으니 안전장치
      // (위에서 pop을 했지만, 에러가 그 전에 났을 수도 있음)
      // 하지만 try-catch 구조상 pop은 try 블록 안에서 실행되므로
      // 에러가 catch로 오면 다이얼로그가 안 닫혔을 가능성은 적음.
      // 혹시 모르니 catch에서도 pop 시도하는 것이 좋지만, useRootNavigator 복잡도 때문에 생략.
      _showCustomSnackBar(context, '기록 로딩 중 오류: ${e.toString()}', isError: true);
    }
  }
  // ▲▲▲▲▲ [ ⭐️⭐️⭐️ 상세 페이지 이동 로직 수정 ⭐️⭐️⭐️ ] ▲▲▲▲▲


  @override
  Widget build(BuildContext context) {
    timeago.setLocaleMessages('ko', timeago.KoMessages());

    return StreamBuilder<QuerySnapshot>(
      // 참여자(participants)에 내가 포함되고, 상태가 완료/취소된 대결 조회
      stream: FirebaseFirestore.instance
          .collection('friendBattles')
          .where('participants', arrayContains: myEmail)
          .where('status', whereIn: ['finished', 'cancelled'])
          .orderBy('updatedAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("오류가 발생했습니다: ${snapshot.error}"));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
              child: Text("⚔️\n아직 완료된 대결 기록이 없습니다.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600], fontSize: 16)
              )
          );
        }

        final battles = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          itemCount: battles.length,
          itemBuilder: (context, index) {
            final doc = battles[index];
            final data = doc.data() as Map<String, dynamic>;

            // --- 1. 공통 데이터 추출 ---
            final String status = data['status'] as String;
            final bool isMeChallenger = data['challengerEmail'] == myEmail;
            final myNickname = isMeChallenger ? data['challengerNickname'] : data['opponentNickname'];
            final opNickname = isMeChallenger ? data['opponentNickname'] : data['challengerNickname'];
            final distance = (data['targetDistanceKm'] as num).toDouble();
            final Timestamp? timestamp = data['updatedAt'] as Timestamp?;
            final String timeAgo = timestamp != null ? timeago.format(timestamp.toDate(), locale: 'ko') : '시간 없음';

            // --- 2. UI 변수 ---
            bool isWinner = false;
            bool isDraw = false;
            String recordText;
            Color recordColor;
            IconData leadingIcon;
            Color leadingIconColor;
            String resultText;
            Color resultTextColor;
            VoidCallback? onTapCallback;

            if (status == 'finished') {
              // --- A. '완주'한 대결 ---
              isDraw = data['isDraw'] == true;

              if (isDraw) {
                // 1. 무승부일 때
                final myPace = (isMeChallenger ? data['challengerPace'] : data['opponentPace'] as num).toDouble();
                resultText = '무승부';
                resultTextColor = Colors.indigo;
                leadingIcon = Icons.handshake;
                leadingIconColor = Colors.indigo;
                recordText = '기록: ${_formatPace(myPace)} (Draw)';
                recordColor = Colors.indigo;
              } else {
                // 2. 승패가 갈렸을 때
                final myPace = (isMeChallenger ? data['challengerPace'] : data['opponentPace'] as num).toDouble();
                final opPace = (isMeChallenger ? data['opponentPace'] : data['challengerPace'] as num).toDouble();
                isWinner = myPace <= opPace;

                recordText = '내 기록: ${_formatPace(myPace)} (${_formatTime((myPace * distance * 60).round())})';
                recordColor = Colors.blueAccent;
                leadingIcon = isWinner ? Icons.emoji_events : Icons.sentiment_dissatisfied;
                leadingIconColor = isWinner ? Colors.amber[700]! : Colors.grey[600]!;
                resultText = isWinner ? '승리' : '패배';
                resultTextColor = isWinner ? Colors.amber[800]! : Colors.grey[700]!;
              }

              // 탭하면 상세 기록 보기
              onTapCallback = () {
                _navigateToResult(context, doc);
              };

            } else {
              // --- B. '기권'한 대결 ('cancelled') ---
              final String? cancellerEmail = data['cancellerEmail'] as String?;
              // 내가 취소한 게 아니면(상대가 취소했거나 null) -> 나의 승리(기권승)
              // 내가 취소했으면 -> 나의 패배(기권패)
              isWinner = (cancellerEmail != null && myEmail != cancellerEmail);

              if (isWinner) {
                recordText = '상대방이 기권했습니다.';
                recordColor = Colors.green;
                leadingIcon = Icons.check_circle_outline;
                leadingIconColor = Colors.green;
                resultText = '기권승';
                resultTextColor = Colors.green;
              } else {
                recordText = '내가 기권했습니다. (기록 확인)';
                recordColor = Colors.redAccent;
                leadingIcon = Icons.cancel_outlined;
                leadingIconColor = Colors.redAccent;
                resultText = '기권패';
                resultTextColor = Colors.redAccent;
              }

              // ▼▼▼▼▼ [ ⭐️⭐️⭐️ 핵심 수정: 취소된 대결도 상세 페이지로 이동 ⭐️⭐️⭐️ ] ▼▼▼▼▼
              onTapCallback = () {
                // 기존: _showCustomSnackBar(...)
                // 수정: 상세 페이지로 이동 시도
                _navigateToResult(context, doc);
              };
              // ▲▲▲▲▲ [ ⭐️⭐️⭐️ 핵심 수정: 취소된 대결도 상세 페이지로 이동 ⭐️⭐️⭐️ ] ▲▲▲▲▲
            }

            // --- 4. 리스트 아이템 반환 ---
            return Card(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              elevation: 2,
              shadowColor: Colors.black.withOpacity(0.1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              color: Colors.white,
              child: ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                // 1. 결과 아이콘
                leading: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      leadingIcon,
                      color: leadingIconColor,
                      size: 32,
                    ),
                    Text(
                      resultText,
                      style: TextStyle(
                        color: resultTextColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    )
                  ],
                ),
                // 2. 대결 제목
                title: Text(
                  '$myNickname vs $opNickname',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                // 3. 내용
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 5),
                    Text(
                      recordText,
                      style: TextStyle(
                        fontSize: 14,
                        color: recordColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      '${distance.toStringAsFixed(0)}km • $timeAgo',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ),
                // ⭐️ 수정: 취소된 대결도 화살표 표시
                trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
                onTap: onTapCallback,
              ),
            );
          },
        );
      },
    );
  }
}