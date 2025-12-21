// [전체 코드] async_battle_list_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart'; // 날짜 포맷을 위해 추가
import 'dart:async'; // StreamGroup.merge 및 StreamTransformer를 위해 추가
import 'package:async/async.dart' as async; // 👈 [유지] 별명 사용

// ▼▼▼▼▼ [ ⭐️ 신규: 카운트다운 및 설정 로드용 임포트 ⭐️ ] ▼▼▼▼▼
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/services.dart';
import 'package:watch_connectivity/watch_connectivity.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ▲▲▲▲▲ [ ⭐️ 신규: 카운트다운 및 설정 로드용 임포트 ⭐️ ] ▲▲▲▲▲

import 'async_battle_running_screen.dart'; // 👈 오프라인 대결 전용 러닝 페이지
import 'async_battle_detail_screen.dart'; // 👈 상세 페이지 임포트


class AsyncBattleListScreen extends StatefulWidget {
  const AsyncBattleListScreen({Key? key}) : super(key: key);

  @override
  _AsyncBattleListScreenState createState() => _AsyncBattleListScreenState();
}

class _AsyncBattleListScreenState extends State<AsyncBattleListScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  late Stream<List<QueryDocumentSnapshot>> _battlesStream;
  String? _currentUserEmail;
  bool _isLoading = true;
  bool _isProcessing = false; // 취소/시작 시 중복 클릭 방지

  @override
  void initState() {
    super.initState();
    _currentUserEmail = _auth.currentUser?.email;
    if (_currentUserEmail != null) {
      _setupStream();
      setState(() => _isLoading = false);
    } else {
      // 로그인되지 않은 상태 처리
      setState(() => _isLoading = false);
    }
  }

  // (로직 함수 - 수정됨)
  void _setupStream() {
    if (_currentUserEmail == null) return;

    // 1. 내가 도전자(challenger)인 대결 스트림
    Stream<QuerySnapshot> stream1 = _firestore
        .collection('asyncBattles')
        .where('challengerEmail', isEqualTo: _currentUserEmail)
        .orderBy('createdAt', descending: true)
        .snapshots();

    // 2. 내가 상대방(opponent)인 대결 스트림
    Stream<QuerySnapshot> stream2 = _firestore
        .collection('asyncBattles')
        .where('opponentEmail', isEqualTo: _currentUserEmail)
        .orderBy('createdAt', descending: true)
        .snapshots();

    // 3. StreamGroup.merge + StreamTransformer
    _battlesStream = async.StreamGroup.merge([stream1, stream2])
        .transform(StreamTransformer.fromHandlers(
      handleData: (data, sink) async {
        if (_currentUserEmail == null) {
          sink.add([]);
          return;
        }

        try {
          // 1. 도전자 쿼리 (수동 .get())
          final challengerFuture = _firestore
              .collection('asyncBattles')
              .where('challengerEmail', isEqualTo: _currentUserEmail)
              .get();

          // 2. 상대방 쿼리 (수동 .get())
          final opponentFuture = _firestore
              .collection('asyncBattles')
              .where('opponentEmail', isEqualTo: _currentUserEmail)
              .get();

          // 3. 두 쿼리를 동시에 실행
          final results = await Future.wait([challengerFuture, opponentFuture]);

          final List<QueryDocumentSnapshot> challengerDocs = results[0].docs;
          final List<QueryDocumentSnapshot> opponentDocs = results[1].docs;

          // 4. 두 목록을 Map을 사용해 병합 (중복 제거)
          final allDocsMap = <String, QueryDocumentSnapshot>{};

          for (var doc in challengerDocs) {
            allDocsMap[doc.id] = doc;
          }
          for (var doc in opponentDocs) {
            allDocsMap[doc.id] = doc;
          }

          // 5. 결합된 목록을 스트림으로 전달
          sink.add(allDocsMap.values.toList());

        } catch (e) {
          print("Error combining streams in _setupStream: $e");
          sink.addError(e);
        }
      },
      handleError: (error, stackTrace, sink) {
        sink.addError(error);
      },
    ));
  }


  // (로직 함수 - 수정 없음)
  Future<void> _cancelBattle(String battleId) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    _showLoadingDialog("대결을 취소하는 중...");

    try {
      final callable = _functions.httpsCallable('cancelAsyncBattle');
      final result = await callable.call({'battleId': battleId});

      if (!mounted) return;
      Navigator.pop(context); // 로딩 닫기

      if (result.data['success'] == true) {
        _showCustomSnackBar("대결이 취소되었습니다.");
      } else {
        _showCustomSnackBar(result.data['message'] ?? "취소에 실패했습니다.", isError: true);
      }
    } catch (e) {
      print("cancelAsyncBattle 호출 오류: $e");
      if (mounted) {
        Navigator.pop(context); // 로딩 닫기
        _showCustomSnackBar("대결 취소 중 오류가 발생했습니다.", isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  // ▼▼▼▼▼ [ ⭐️⭐️⭐️ 수정: 카운트다운 적용된 시작 함수 ⭐️⭐️⭐️ ] ▼▼▼▼▼
  Future<void> _startRun(String battleId, double targetDistanceKm) async {
    if (_isProcessing) return;
    // setState(() => _isProcessing = true); // 필요 시 활성화

    // 1. SharedPreferences 로드 (워치 설정 확인)
    final prefs = await SharedPreferences.getInstance();
    final bool withWatch = prefs.getBool('watchSyncEnabled') ?? false;

    if (!mounted) return;

    // 2. 카운트다운 다이얼로그 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      // ⭐️ [수정] withWatch 값을 전달
      builder: (context) => CountdownDialog(withWatch: withWatch),
    ).then((_) {
      // 3. 다이얼로그 종료(3초 후) -> 러닝 화면으로 이동
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AsyncBattleRunningScreen(
              targetDistanceKm: targetDistanceKm,
              battleId: battleId,
              withWatch: withWatch, // 👈 설정값 전달
            ),
          ),
        );
      }
    });
  }
  // ▲▲▲▲▲ [ ⭐️⭐️⭐️ 수정: 카운트다운 적용된 시작 함수 ⭐️⭐️⭐️ ] ▲▲▲▲▲

  // (UI 함수 - 수정 없음)
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        leading: IconButton(
          icon: Image.asset('assets/images/Back-Navs.png', width: 66, height: 66),
          onPressed: () => Navigator.of(context).pop(),
          padding: const EdgeInsets.only(left: 8),
        ),
        title: Text('오프라인 대결 목록'),
        backgroundColor: Colors.grey[100],
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Color(0xFFFF9F80)))
          : _currentUserEmail == null
          ? Center(child: Text("로그인이 필요합니다."))
          : StreamBuilder<List<QueryDocumentSnapshot>>(
        stream: _battlesStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: Color(0xFFFF9F80)));
          }
          if (snapshot.hasError) {
            print("스트림 오류: ${snapshot.error}");
            return Center(child: Text("대결 목록을 불러오는데 실패했습니다."));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
                child: Text(
                  "진행 중인 대결이 없습니다.\n[오프라인 대결 생성하기]로\n새로운 대결을 만들어보세요.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600], fontSize: 16, height: 1.5),
                )
            );
          }

          final allBattles = snapshot.data!;

          // (정렬 로직)
          allBattles.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTime = aData['createdAt'] as Timestamp?;
            final bTime = bData['createdAt'] as Timestamp?;

            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime);
          });

          // (목록 분류 로직)
          final List<QueryDocumentSnapshot> myTurnBattles = [];
          final List<QueryDocumentSnapshot> waitingBattles = [];
          final List<QueryDocumentSnapshot> completedBattles = [];

          for (var doc in allBattles) {
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'] as String;
            final amIChallenger = data['challengerEmail'] == _currentUserEmail;

            final bool isOpponentMyTurn = !amIChallenger &&
                status == 'running' &&
                data['opponentRunData'] == null;

            final bool isChallengerMyTurn = amIChallenger &&
                status == 'pending';


            if (status == 'finished' || status == 'cancelled') {
              completedBattles.add(doc);
            } else if (isOpponentMyTurn || isChallengerMyTurn) {
              myTurnBattles.add(doc);
            } else {
              waitingBattles.add(doc);
            }
          }

          // (UI 렌더링)
          return ListView(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              // --- 내 차례 섹션 ---
              if (myTurnBattles.isNotEmpty)
                _buildSectionTitle("🔥 내 차례인 대결", myTurnBattles.length),
              ...myTurnBattles.map((doc) => _buildBattleCard(doc)).toList(),

              // --- 대기 중 섹션 ---
              if (waitingBattles.isNotEmpty)
                _buildSectionTitle("⏳ 대기 중인 대결", waitingBattles.length),
              ...waitingBattles.map((doc) => _buildBattleCard(doc)).toList(),

              // --- 완료/취소 섹션 ---
              if (completedBattles.isNotEmpty)
                _buildSectionTitle("🗓️ 완료 / 취소된 대결", completedBattles.length),
              ...completedBattles.map((doc) => _buildBattleCard(doc)).toList(),
            ],
          );
        },
      ),
    );
  }

  // (UI 헬퍼)
  Widget _buildSectionTitle(String title, int count) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0, left: 4.0),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          SizedBox(width: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Color(0xFFFF9F80),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              "$count",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          )
        ],
      ),
    );
  }

  // (UI 헬퍼)
  Widget _buildBattleCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final battleId = doc.id;

    final bool amIChallenger = data['challengerEmail'] == _currentUserEmail;

    // 상대방 정보
    final String opponentNickname = amIChallenger ? data['opponentNickname'] : data['challengerNickname'];
    final String? opponentProfileUrl = amIChallenger ? data['opponentProfileUrl'] : data['challengerProfileUrl'];

    final double targetKm = (data['targetDistanceKm'] as num).toDouble();
    final String status = data['status'];

    // "내 차례" 여부
    final bool isOpponentMyTurn = !amIChallenger &&
        status == 'running' &&
        data['opponentRunData'] == null;
    final bool isChallengerMyTurn = amIChallenger &&
        status == 'pending';
    final bool isMyTurn = isOpponentMyTurn || isChallengerMyTurn;


    // 상태 텍스트/색상/액션 결정
    String statusText = "";
    Color statusColor = Colors.grey;
    Widget? actionWidget;

    if (isMyTurn) {
      statusText = "🚩 내 차례";
      statusColor = Colors.blueAccent;

      Widget startButton = ElevatedButton.icon(
        icon: Icon(Icons.directions_run_rounded, size: 18),
        label: Text("시작"),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: EdgeInsets.symmetric(horizontal: 16),
        ),
        onPressed: () => _startRun(battleId, targetKm),
      );

      if (isChallengerMyTurn) {
        actionWidget = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              child: Text("취소", style: TextStyle(color: Colors.redAccent)),
              onPressed: () => _showCancelConfirmDialog(battleId),
            ),
            SizedBox(width: 8),
            startButton,
          ],
        );
      } else {
        actionWidget = startButton;
      }

    } else if (status == 'pending') {
      statusText = "⏳ 도전자 대기";
      statusColor = Colors.orangeAccent;

    } else if (status == 'running') {
      statusText = "🏃 상대방 대기";
      statusColor = Colors.orangeAccent;

    } else if (status == 'finished') {
      // ▼▼▼▼▼ [ ⭐️⭐️⭐️ 파트 2 수정: 무승부 UI 처리 ⭐️⭐️⭐️ ] ▼▼▼▼▼
      final bool isDraw = data['isDraw'] == true; // 무승부 여부 체크

      if (isDraw) {
        statusText = "🤝 무승부";
        statusColor = Colors.indigo; // 무승부는 남색 등으로 구별
      } else {
        final String winnerEmail = data['winnerEmail'] ?? '';
        if (winnerEmail == _currentUserEmail) {
          statusText = "🎉 승리";
          statusColor = Colors.green;
        } else {
          statusText = "💧 패배";
          statusColor = Colors.red;
        }
      }
      // ▲▲▲▲▲ [ ⭐️⭐️⭐️ 파트 2 수정: 무승부 UI 처리 ⭐️⭐️⭐️ ] ▲▲▲▲▲

    } else if (status == 'cancelled') {
      statusText = "❌ 취소됨";
      statusColor = Colors.grey[600]!;
    }

    Widget? trailingWidget;
    if (status == 'finished') {
      trailingWidget = Text(
        statusText,
        style: TextStyle(fontWeight: FontWeight.bold, color: statusColor, fontSize: 14),
      );
    } else {
      trailingWidget = actionWidget;
    }


    return Card(
      elevation: 0,
      margin: EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 22,
          backgroundImage: opponentProfileUrl != null
              ? NetworkImage(opponentProfileUrl)
              : AssetImage('assets/images/user.png') as ImageProvider,
          backgroundColor: Colors.grey[200],
        ),
        title: Text(
          opponentNickname,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          "${targetKm.toInt()}km 대결 • $statusText",
          style: TextStyle(
            fontSize: 14,
            color: statusColor,
            fontWeight: isMyTurn ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        trailing: trailingWidget,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AsyncBattleDetailScreen(
                battleId: battleId,
              ),
            ),
          );
        },
      ),
    );
  }

  // (헬퍼 함수 - 수정 없음)
  String _formatTime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
  }

  // (헬퍼 함수 - 수정 없음)
  void _showCancelConfirmDialog(String battleId) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text("대결 취소", style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text("아직 상대방이 뛰기 전입니다.\n이 대결을 취소하시겠습니까?"),
          actions: [
            TextButton(
              child: Text("닫기", style: TextStyle(color: Colors.grey[700])),
              onPressed: () => Navigator.pop(dialogContext),
            ),
            TextButton(
              child: Text("대결 취소", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.pop(dialogContext);
                _cancelBattle(battleId);
              },
            ),
          ],
        );
      },
    );
  }

  // (헬퍼 함수 - 수정 없음)
  void _showCustomSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
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

  // (헬퍼 함수 - 수정 없음)
  void _showLoadingDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          content: Row(
            children: [
              CircularProgressIndicator(color: Color(0xFFFF9F80)),
              SizedBox(width: 20),
              Text(message, style: TextStyle(fontSize: 16)),
            ],
          ),
        );
      },
    );
  }
}

// ▼▼▼▼▼ [ ⭐️ 신규 추가: 카운트다운 다이얼로그 ⭐️ ] ▼▼▼▼▼
class CountdownDialog extends StatefulWidget {
  // ⭐️ [수정] withWatch 변수 추가
  final bool withWatch;
  const CountdownDialog({Key? key, required this.withWatch}) : super(key: key);

  @override
  _CountdownDialogState createState() => _CountdownDialogState();
}

class _CountdownDialogState extends State<CountdownDialog> {
  int _countdown = 3;
  Timer? _timer;
  late FlutterTts _flutterTts;
  final _watch = WatchConnectivity();

  @override
  void initState() {
    super.initState();
    _flutterTts = FlutterTts();
    _initTts();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("ko-KR");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.duckOthers,
        ],
        IosTextToSpeechAudioMode.voicePrompt
    );
    _startTimer();
  }

  Future<void> _speak(String text) async {
    if (mounted) {
      await _flutterTts.speak(text);
    }
  }

  void _startTimer() {
    // 1. 시작 시 3초 음성 및 워치 전송
    if (_countdown > 0) {
      _speak(_countdown.toString()); // "3"
      // ⭐️ [수정] withWatch 체크 후 전송
      if (widget.withWatch) {
        try {
          _watch.sendMessage({'command': 'showWarmup'});
          _watch.sendMessage({'command': 'countdown', 'value': _countdown});
        } catch (e) {
          print("Watch SendMessage Error (Countdown Start): $e");
        }
      }
    }

    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_countdown == 1) {
        timer.cancel();
        setState(() => _countdown = 0); // "START!"로 변경

        // ▼▼▼▼▼ [ ⭐️ 수정: START 화면과 함께 음성 출력 ⭐️ ] ▼▼▼▼▼
        _speak("대결을 시작합니다!");
        // ▲▲▲▲▲ [ ⭐️ 수정: START 화면과 함께 음성 출력 ⭐️ ] ▲▲▲▲▲

        // ⭐️ [수정] withWatch 체크 후 전송
        if (widget.withWatch) {
          try {
            _watch.sendMessage({'command': 'startRunningUI'});
          } catch (e) {
            print("Watch SendMessage Error (Countdown START!): $e");
          }
        }

        Future.delayed(Duration(seconds: 1), () {
          if (mounted) Navigator.pop(context);
        });
      } else {
        setState(() {
          _countdown--;
        });

        if (_countdown > 0) {
          _speak(_countdown.toString()); // "2", "1"
          // ⭐️ [수정] withWatch 체크 후 전송
          if (widget.withWatch) {
            try {
              _watch.sendMessage({'command': 'countdown', 'value': _countdown});
            } catch (e) {
              print("Watch SendMessage Error (Countdown $e): $e");
            }
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String displayText = _countdown > 0 ? _countdown.toString() : "START!";

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return ScaleTransition(child: child, scale: animation);
          },
          child: Text(
            displayText,
            key: ValueKey<String>(displayText),
            style: TextStyle(
              fontSize: 75,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              shadows: [
                Shadow(blurRadius: 10.0, color: Colors.black.withOpacity(0.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
// ▲▲▲▲▲ [ ⭐️ 신규 추가: 카운트다운 다이얼로그 ⭐️ ] ▲▲▲▲▲