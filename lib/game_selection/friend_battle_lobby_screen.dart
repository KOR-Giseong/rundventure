// [전체 코드] friend_battle_lobby_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

// ▼▼▼▼▼ [ ⭐️ (요청) 수정: TTS 임포트 추가 ⭐️ ] ▼▼▼▼▼
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/services.dart'; // for IosTextToSpeechAudioCategory
// ▲▲▲▲▲ [ ⭐️ (요청) 수정: TTS 임포트 추가 ⭐️ ] ▲▲▲▲▲

// ▼▼▼▼▼ [ ⭐️⭐️⭐️ 신규 수정: 워치 커넥티비티 임포트 ⭐️⭐️⭐️ ] ▼▼▼▼▼
import 'package:watch_connectivity/watch_connectivity.dart';
// ▲▲▲▲▲ [ ⭐️⭐️⭐️ 신규 수정: 워치 커넥티비티 임포트 ⭐️⭐️⭐️ ] ▲▲▲▲▲

// ▼▼▼▼▼ [ ✨✨✨ 핵심 수정: 설정값 로드용 임포트 ✨✨✨ ] ▼▼▼▼▼
import 'package:shared_preferences/shared_preferences.dart';
// ▲▲▲▲▲ [ ✨✨✨ 핵심 수정: 설정값 로드용 임포트 ✨✨✨ ] ▲▲▲▲▲

// Part 4에서 생성한 파일 (미리 임포트)
import 'friend_battle_running_screen.dart';


class FriendBattleLobbyScreen extends StatefulWidget {
  final String battleId;
  final bool isChallenger; // 내가 도전자(true)인지, 상대방(false)인지

  const FriendBattleLobbyScreen({
    Key? key,
    required this.battleId,
    required this.isChallenger,
  }) : super(key: key);

  @override
  _FriendBattleLobbyScreenState createState() => _FriendBattleLobbyScreenState();
}

class _FriendBattleLobbyScreenState extends State<FriendBattleLobbyScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String? _myEmail = FirebaseAuth.instance.currentUser?.email;

  StreamSubscription? _battleSubscription;
  bool _isCancelling = false; // 취소 로딩
  bool _isNavigating = false; // 러닝 화면으로 이동 중인지 (중복 방지)

  // ▼▼▼▼▼ [ ⭐️ 권한 상태 변수 추가 ⭐️ ] ▼▼▼▼▼
  String? _userRole; // 'user', 'admin', 'head_admin', 'super_admin'
  // ▲▲▲▲▲ [ ⭐️ 권한 상태 변수 추가 ⭐️ ] ▲▲▲▲▲

  @override
  void initState() {
    super.initState();
    _listenToBattleStatus();
    _checkUserRole(); // 👈 권한 확인
  }

  @override
  void dispose() {
    _battleSubscription?.cancel();
    super.dispose();
  }

  // ▼▼▼▼▼ [ ⭐️ 권한 확인 로직 ⭐️ ] ▼▼▼▼▼
  Future<void> _checkUserRole() async {
    if (_myEmail == null) return;
    try {
      final userDoc = await _firestore.collection('users').doc(_myEmail).get();
      if (mounted && userDoc.exists) {
        setState(() {
          _userRole = userDoc.data()?['role'] ?? 'user';
        });
      }
    } catch (e) {
      print("권한 확인 실패: $e");
    }
  }
  // ▲▲▲▲▲ [ ⭐️ 권한 확인 로직 ⭐️ ] ▲▲▲▲▲

  // Firestore 스트림 리스너
  void _listenToBattleStatus() {
    final docRef = _firestore.collection('friendBattles').doc(widget.battleId);
    _battleSubscription = docRef.snapshots().listen(
          (snapshot) {
        if (!mounted || _isNavigating) return;

        if (!snapshot.exists) {
          // 문서가 삭제됨 (아마도 취소됨)
          _showInfoAndPop("대결이 취소되었습니다.");
          return;
        }

        final data = snapshot.data() as Map<String, dynamic>;
        final status = data['status'] as String?;

        switch (status) {
          case 'accepted':
          // ✅ 양쪽 모두 준비 완료!
            _startCountdownAndNavigate(data);
            break;
          case 'rejected':
            _showInfoAndPop("상대방이 대결을 거절했습니다.");
            break;
          case 'cancelled':
            _showInfoAndPop("대결이 취소되었습니다.");
            break;
        // 'pending' 상태는 UI가 알아서 처리하므로 별도 로직 X
        }
      },
      onError: (error) {
        if (mounted) {
          _showInfoAndPop("대결 상태 조회 중 오류 발생");
        }
      },
    );
  }

  // ▼▼▼▼▼ [ ✨✨✨ 핵심 수정: 설정값 로드 및 적용 ✨✨✨ ] ▼▼▼▼▼
  // 카운트다운 후 러닝 화면으로 이동
  Future<void> _startCountdownAndNavigate(Map<String, dynamic> battleData) async {
    if (_isNavigating) return; // 중복 실행 방지
    _isNavigating = true;

    // 1. SharedPreferences에서 워치 설정값 미리 로드
    final prefs = await SharedPreferences.getInstance();
    final bool withWatch = prefs.getBool('watchSyncEnabled') ?? false;

    if (!mounted) return;

    // 2. 3초 카운트다운 다이얼로그 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CountdownDialog(),
    ).then((_) {
      // 다이얼로그가 닫히면 (즉, 3초가 지나면) 러닝 화면으로 이동
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => FriendBattleRunningScreen(
              battleId: widget.battleId,
              battleData: battleData, // 👈 대결 데이터 전달
              // ❗️ [수정] 저장된 설정값(withWatch)을 전달합니다.
              withWatch: withWatch,
            ),
          ),
        );
      }
    });
  }
  // ▲▲▲▲▲ [ ✨✨✨ 핵심 수정: 설정값 로드 및 적용 ✨✨✨ ] ▲▲▲▲▲

  // 대결 취소 (Cloud Function 호출)
  Future<void> _cancelBattle() async {
    if (_isCancelling) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          // ▼▼▼▼▼ [ ⭐️ 디자인 수정 2/2: 흰색 배경 다이얼로그 ⭐️ ] ▼▼▼▼▼
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('대결 취소', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text('정말로 대결을 취소하시겠습니까?'),
          actions: [
            TextButton(
              child: Text('아니오', style: TextStyle(color: Colors.grey[600])),
              onPressed: () => Navigator.pop(context, false),
            ),
            TextButton(
              child: Text('예', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
          // ▲▲▲▲▲ [ ⭐️ 디자인 수정 2/2: 흰색 배경 다이얼로그 ⭐️ ] ▲▲▲▲▲
        );
      },
    );

    if (confirmed != true) return;

    setState(() => _isCancelling = true);

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-northeast3')
          .httpsCallable('cancelFriendBattle');
      await callable.call({'battleId': widget.battleId});
      // 성공 시, 스트림 리스너가 'cancelled' 상태를 감지하고 자동으로 pop함
    } on FirebaseFunctionsException catch (e) {
      _showErrorDialog(e.message ?? "알 수 없는 오류");
    } catch (e) {
      _showErrorDialog("취소 중 오류가 발생했습니다.");
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  // 정보 다이얼로그 (거절/취소 시)
  void _showInfoAndPop(String message) {
    if (!mounted) return;
    // 다이얼로그가 이미 떠있는지 확인 (중복 방지)
    if (ModalRoute.of(context)?.isCurrent != true) {
      Navigator.pop(context); // 기존 다이얼로그 닫기
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          // ▼▼▼▼▼ [ ⭐️ 디자인 수정 2/2: 흰색 배경 다이얼로그 ⭐️ ] ▼▼▼▼▼
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('알림', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text(message),
          actions: [
            TextButton(
              child: Text('확인', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.pop(context); // 다이얼로그 닫기
                if (Navigator.canPop(context)) {
                  Navigator.pop(context); // 로비 화면 닫기
                }
              },
            ),
          ],
          // ▲▲▲▲▲ [ ⭐️ 디자인 수정 2/2: 흰색 배경 다이얼로그 ⭐️ ] ▲▲▲▲▲
        );
      },
    );
  }

  // 에러 다이얼로그
  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        // ▼▼▼▼▼ [ ⭐️ 디자인 수정 2/2: 흰색 배경 다이얼로그 ⭐️ ] ▼▼▼▼▼
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('오류', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('확인', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
        // ▲▲▲▲▲ [ ⭐️ 디자인 수정 2/2: 흰색 배경 다이얼로그 ⭐️ ] ▲▲▲▲▲
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 권한 확인
    final bool isAnyAdmin =
        _userRole == 'admin' || _userRole == 'head_admin' || _userRole == 'super_admin';

    // 뒤로가기 버튼 처리 (대결 취소)
    return WillPopScope(
      onWillPop: () async {
        await _cancelBattle();
        return false; // WillPopScope가 직접 pop하지 않음 (스트림 리스너가 처리)
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.close, color: Colors.black),
            onPressed: _cancelBattle, // X 버튼 눌러도 취소
          ),
          title: Text(
            '대결 대기 중',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
        body: StreamBuilder<DocumentSnapshot>(
          stream: _firestore.collection('friendBattles').doc(widget.battleId).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
              return Center(child: Text('대결 정보를 불러올 수 없습니다.'));
            }

            final data = snapshot.data!.data() as Map<String, dynamic>;
            final status = data['status'] as String;

            // ▼▼▼▼▼ [ ✅ 수정 ] ▼▼▼▼▼
            // targetDistanceKm를 스트림에서 직접 읽어옴
            final targetDistanceKm = (data['targetDistanceKm'] as num? ?? 5).toDouble();
            // ▲▲▲▲▲ [ ✅ 수정 ] ▲▲▲▲▲

            // 내가 도전자 / 상대방 정보
            final myInfo = {
              'email': widget.isChallenger ? data['challengerEmail'] : data['opponentEmail'],
              'nickname': widget.isChallenger ? data['challengerNickname'] : data['opponentNickname'],
              'profileUrl': widget.isChallenger ? data['challengerProfileUrl'] : data['opponentProfileUrl'],
              'status': widget.isChallenger ? data['challengerStatus'] : data['opponentStatus'],
            };
            final opponentInfo = {
              'email': widget.isChallenger ? data['opponentEmail'] : data['challengerEmail'],
              'nickname': widget.isChallenger ? data['opponentNickname'] : data['challengerNickname'],
              'profileUrl': widget.isChallenger ? data['opponentProfileUrl'] : data['challengerProfileUrl'],
              'status': widget.isChallenger ? data['opponentStatus'] : data['challengerStatus'],
            };

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0), // 심플화
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- 대결 정보 요약 ---
                  // ▼▼▼▼▼ [ ⭐️ 디자인 수정 1/2: km 텍스트 심플화 ⭐️ ] ▼▼▼▼▼
                  Text(
                    '${targetDistanceKm.toStringAsFixed(0)} km', // 거리만 강조
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28, // 크기 키우기
                      fontWeight: FontWeight.w900,
                      color: Colors.blueAccent,
                    ),
                  ),
                  Text(
                    '목표 거리', // 레이블 추가
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600],
                    ),
                  ),
                  // ▲▲▲▲▲ [ ⭐️ 디자인 수정 1/2: km 텍스트 심플화 ⭐️ ] ▲▲▲▲▲
                  SizedBox(height: 24), // 간격 조정

                  // --- 플레이어 카드 비교 ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    crossAxisAlignment: CrossAxisAlignment.center, // 중앙 정렬
                    children: [
                      // 나 (Challenger or Opponent)
                      _buildPlayerCard(
                        nickname: myInfo['nickname'],
                        profileUrl: myInfo['profileUrl'],
                        status: myInfo['status'],
                        isMe: true,
                      ),
                      // 'VS' 텍스트 (심플화)
                      Padding(
                        padding: const EdgeInsets.only(top: 10.0),
                        child: Text(
                          'VS',
                          style: TextStyle(
                            fontSize: 24, // 크기 감소
                            fontWeight: FontWeight.w900,
                            color: Colors.grey[400],
                          ),
                        ),
                      ),
                      // 상대방
                      _buildPlayerCard(
                        nickname: opponentInfo['nickname'],
                        profileUrl: opponentInfo['profileUrl'],
                        status: opponentInfo['status'],
                        isMe: false,
                      ),
                    ],
                  ),
                  SizedBox(height: 40),

                  // --- 상태 메시지 ---
                  _buildStatusMessage(status, opponentInfo['nickname']),
                  Spacer(),

                  // ▼▼▼▼▼ [ ⭐️ 디버그 기능 추가 (관리자 전용) ⭐️ ] ▼▼▼▼▼
                  if (isAnyAdmin)
                    Column(
                      children: [
                        TextButton(
                          child: Text(
                            "DEBUG: 상대방 강제 수락 (강제 시작)",
                            style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () async {
                            final docRef = _firestore.collection('friendBattles').doc(widget.battleId);

                            final String opponentStatusField = widget.isChallenger
                                ? 'opponentStatus'
                                : 'challengerStatus';

                            await docRef.update({
                              'status': 'accepted',
                              opponentStatusField: 'ready',
                            });
                          },
                        ),
                        SizedBox(height: 8),
                      ],
                    ),
                  // ▲▲▲▲▲ [ ⭐️ 디버그 기능 추가 (관리자 전용) ⭐️ ] ▲▲▲▲▲

                  // --- 취소 버튼 (심플 스타일) ---
                  ElevatedButton(
                    onPressed: _isCancelling ? null : _cancelBattle,
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 50), // 버튼 크기 조정
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      elevation: 0, // 그림자 제거
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), // 모서리 둥글기 감소
                    ),
                    child: _isCancelling
                        ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(
                      widget.isChallenger ? '신청 취소' : '대결 거절',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  SizedBox(height: 16),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // 플레이어 카드 UI (심플화)
  Widget _buildPlayerCard({
    required String nickname,
    required String? profileUrl,
    required String status,
    required bool isMe,
  }) {
    return Column(
      children: [
        CircleAvatar(
          radius: 40, // 크기 감소
          backgroundColor: Colors.grey[200],
          backgroundImage: (profileUrl != null && profileUrl.isNotEmpty)
              ? NetworkImage(profileUrl)
              : AssetImage('assets/images/user.png') as ImageProvider,
        ),
        SizedBox(height: 10),
        Text(
          nickname,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16, // 크기 감소
            fontWeight: FontWeight.bold,
            color: isMe ? Colors.blueAccent : Colors.black,
          ),
        ),
        SizedBox(height: 6),
        _buildStatusTag(status),
      ],
    );
  }

  // 플레이어 상태 태그 (심플화)
  Widget _buildStatusTag(String status) {
    String text;
    Color color;
    switch (status) {
      case 'ready':
        text = '준비 완료';
        color = Colors.green;
        break;
      case 'waiting':
        text = '응답 대기 중';
        color = Colors.grey;
        break;
      default:
        text = status.toUpperCase();
        color = Colors.black;
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2), // 패딩 감소
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10), // 둥글기 감소
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600, // 폰트 굵기 조정
          fontSize: 11, // 크기 감소
        ),
      ),
    );
  }

  // 하단 상태 메시지 (심플화)
  Widget _buildStatusMessage(String status, String opponentNickname) {
    String message = '';
    Color color = Colors.grey[800]!;

    if (status == 'pending') {
      message = widget.isChallenger
          ? '$opponentNickname 님의 수락을 기다리는 중입니다...'
          : '대결을 수락해주세요!';
    } else if (status == 'accepted') {
      message = '잠시 후 대결이 시작됩니다! 🚀';
      color = Colors.blueAccent;
    }

    if (message.isEmpty) return SizedBox.shrink();

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 15, // 크기 조정
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}


// --- (신규) 3초 카운트다운 다이얼로그 위젯 ---
class CountdownDialog extends StatefulWidget {
  const CountdownDialog({Key? key}) : super(key: key);

  @override
  _CountdownDialogState createState() => _CountdownDialogState();
}

// ▼▼▼▼▼ [ ⭐️ (요청) 수정: TTS 기능 + ⭐️⭐️⭐️ 워치 전송 ⭐️⭐️⭐️ ⭐️ ] ▼▼▼▼▼
class _CountdownDialogState extends State<CountdownDialog> {
  int _countdown = 3;
  Timer? _timer;
  late FlutterTts _flutterTts; // 👈 TTS 인스턴스 추가
  // ▼▼▼▼▼ [ ⭐️⭐️⭐️ 신규 수정: 워치 인스턴스 ⭐️⭐️⭐️ ] ▼▼▼▼▼
  final _watch = WatchConnectivity();
  // ▲▲▲▲▲ [ ⭐️⭐️⭐️ 신규 수정: 워치 인스턴스 ⭐️⭐️⭐️ ] ▲▲▲▲▲

  @override
  void initState() {
    super.initState();
    _flutterTts = FlutterTts();
    _initTts(); // 👈 TTS 초기화 후 타이머 시작
  }

  // (신규) TTS 초기화 함수
  Future<void> _initTts() async {
    // (Running Screen의 TTS 설정과 동일하게 맞춤)
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

    // TTS 준비 완료 후 타이머 시작
    _startTimer();
  }

  // (신규) TTS Speak 헬퍼
  Future<void> _speak(String text) async {
    if (mounted) {
      await _flutterTts.speak(text);
    }
  }

  void _startTimer() {
    // (수정) 타이머 시작 시 첫 숫자(3) 음성 재생 및 ⭐️ 워치 전송 ⭐️
    if (_countdown > 0) {
      _speak(_countdown.toString());
      // ▼▼▼▼▼ [ ⭐️⭐️⭐️ 신규 수정: 워치 전송 ⭐️⭐️⭐️ ] ▼▼▼▼▼
      try {
        _watch.sendMessage({'command': 'showWarmup'}); // 👈 '준비'
        _watch.sendMessage({'command': 'countdown', 'value': _countdown}); // 👈 '3'
      } catch (e) {
        print("Watch SendMessage Error (Countdown Start): $e");
      }
      // ▲▲▲▲▲ [ ⭐️⭐️⭐️ 신규 수정: 워치 전송 ⭐️⭐️⭐️ ] ▲▲▲▲▲
    }

    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_countdown == 1) {
        timer.cancel();
        // "START!"를 1초간 더 보여준 뒤 다이얼로그 닫기
        setState(() => _countdown = 0); // "START!"로 변경
        // ▼▼▼▼▼ [ ⭐️ 수정 ⭐️ ] ▼▼▼▼▼
        // _speak("START!"); // 👈 [제거] START 음성은 여기서 안함 (다음 화면에서 함)
        // ▲▲▲▲▲ [ ⭐️ 수정 ⭐️ ] ▲▲▲▲▲

        // ▼▼▼▼▼ [ ⭐️⭐️⭐️ 신규 수정: 워치 전송 ⭐️⭐️⭐️ ] ▼▼▼▼▼
        try {
          _watch.sendMessage({'command': 'startRunningUI'}); // 👈 '시작!'
        } catch (e) {
          print("Watch SendMessage Error (Countdown START!): $e");
        }
        // ▲▲▲▲▲ [ ⭐️⭐️⭐️ 신규 수정: 워치 전송 ⭐️⭐️⭐️ ] ▲▲▲▲▲
        Future.delayed(Duration(seconds: 1), () {
          if (mounted) Navigator.pop(context);
        });
      } else {
        setState(() {
          _countdown--;
        });
        // (수정) 다음 숫자 (2, 1) 음성 재생 및 ⭐️ 워치 전송 ⭐️
        if (_countdown > 0) {
          _speak(_countdown.toString());
          // ▼▼▼▼▼ [ ⭐️⭐️⭐️ 신규 수정: 워치 전송 ⭐️⭐️⭐️ ] ▼▼▼▼▼
          try {
            _watch.sendMessage({'command': 'countdown', 'value': _countdown}); // 👈 '2', '1'
          } catch (e) {
            print("Watch SendMessage Error (Countdown $e): $e");
          }
          // ▲▲▲▲▲ [ ⭐️⭐️⭐️ 신규 수정: 워치 전송 ⭐️⭐️⭐️ ] ▲▲▲▲▲
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _flutterTts.stop(); // 👈 (수정) TTS 정지
    super.dispose();
  }
  // ▲▲▲▲▲ [ ⭐️ (요청) 수정: TTS 기능 + ⭐️⭐️⭐️ 워치 전송 ⭐️⭐️⭐️ ⭐️ ] ▲▲▲▲▲

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
            key: ValueKey<String>(displayText), // 키를 주어 애니메이션이 동작하도록 함
            style: TextStyle(
              fontSize: 75, // ⭐️ [수정] 폰트 크기 80
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