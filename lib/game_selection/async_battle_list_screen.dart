import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:async/async.dart' as async;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/services.dart';
import 'package:watch_connectivity/watch_connectivity.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'async_battle_running_screen.dart';
import 'async_battle_detail_screen.dart';


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

  void _setupStream() {
    if (_currentUserEmail == null) return;

    Stream<QuerySnapshot> stream1 = _firestore
        .collection('asyncBattles')
        .where('challengerEmail', isEqualTo: _currentUserEmail)
        .orderBy('createdAt', descending: true)
        .snapshots();

    Stream<QuerySnapshot> stream2 = _firestore
        .collection('asyncBattles')
        .where('opponentEmail', isEqualTo: _currentUserEmail)
        .orderBy('createdAt', descending: true)
        .snapshots();

    _battlesStream = async.StreamGroup.merge([stream1, stream2])
        .transform(StreamTransformer.fromHandlers(
      handleData: (data, sink) async {
        if (_currentUserEmail == null) {
          sink.add([]);
          return;
        }

        try {
          final challengerFuture = _firestore
              .collection('asyncBattles')
              .where('challengerEmail', isEqualTo: _currentUserEmail)
              .get();

          final opponentFuture = _firestore
              .collection('asyncBattles')
              .where('opponentEmail', isEqualTo: _currentUserEmail)
              .get();

          final results = await Future.wait([challengerFuture, opponentFuture]);

          final List<QueryDocumentSnapshot> challengerDocs = results[0].docs;
          final List<QueryDocumentSnapshot> opponentDocs = results[1].docs;

          final allDocsMap = <String, QueryDocumentSnapshot>{};

          for (var doc in challengerDocs) {
            allDocsMap[doc.id] = doc;
          }
          for (var doc in opponentDocs) {
            allDocsMap[doc.id] = doc;
          }

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


  Future<void> _cancelBattle(String battleId) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    _showLoadingDialog("대결을 취소하는 중...");

    try {
      final callable = _functions.httpsCallable('cancelAsyncBattle');
      final result = await callable.call({'battleId': battleId});

      if (!mounted) return;
      Navigator.pop(context);

      if (result.data['success'] == true) {
        _showCustomSnackBar("대결이 취소되었습니다.");
      } else {
        _showCustomSnackBar(result.data['message'] ?? "취소에 실패했습니다.", isError: true);
      }
    } catch (e) {
      print("cancelAsyncBattle 호출 오류: $e");
      if (mounted) {
        Navigator.pop(context);
        _showCustomSnackBar("대결 취소 중 오류가 발생했습니다.", isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _startRun(String battleId, double targetDistanceKm) async {
    if (_isProcessing) return;

    final prefs = await SharedPreferences.getInstance();
    final bool withWatch = prefs.getBool('watchSyncEnabled') ?? false;

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CountdownDialog(withWatch: withWatch),
    ).then((_) {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AsyncBattleRunningScreen(
              targetDistanceKm: targetDistanceKm,
              battleId: battleId,
              withWatch: withWatch,
            ),
          ),
        );
      }
    });
  }

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

          return ListView(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              if (myTurnBattles.isNotEmpty)
                _buildSectionTitle("🔥 내 차례인 대결", myTurnBattles.length),
              ...myTurnBattles.map((doc) => _buildBattleCard(doc)).toList(),

              if (waitingBattles.isNotEmpty)
                _buildSectionTitle("⏳ 대기 중인 대결", waitingBattles.length),
              ...waitingBattles.map((doc) => _buildBattleCard(doc)).toList(),

              if (completedBattles.isNotEmpty)
                _buildSectionTitle("🗓️ 완료 / 취소된 대결", completedBattles.length),
              ...completedBattles.map((doc) => _buildBattleCard(doc)).toList(),
            ],
          );
        },
      ),
    );
  }

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

  Widget _buildBattleCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final battleId = doc.id;

    final bool amIChallenger = data['challengerEmail'] == _currentUserEmail;

    final String opponentNickname = amIChallenger ? data['opponentNickname'] : data['challengerNickname'];
    final String? opponentProfileUrl = amIChallenger ? data['opponentProfileUrl'] : data['challengerProfileUrl'];

    final double targetKm = (data['targetDistanceKm'] as num).toDouble();
    final String status = data['status'];

    final bool isOpponentMyTurn = !amIChallenger &&
        status == 'running' &&
        data['opponentRunData'] == null;
    final bool isChallengerMyTurn = amIChallenger &&
        status == 'pending';
    final bool isMyTurn = isOpponentMyTurn || isChallengerMyTurn;

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
      final bool isDraw = data['isDraw'] == true;

      if (isDraw) {
        statusText = "🤝 무승부";
        statusColor = Colors.indigo;
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

class CountdownDialog extends StatefulWidget {
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
    if (_countdown > 0) {
      _speak(_countdown.toString());
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
        setState(() => _countdown = 0);

        _speak("대결을 시작합니다!");

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
          _speak(_countdown.toString());
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