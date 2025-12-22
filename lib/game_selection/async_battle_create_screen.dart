import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/services.dart';
import 'package:watch_connectivity/watch_connectivity.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'async_battle_running_screen.dart';

// 친구 정보를 담기 위한 간단한 모델
class FriendData {
  final String email;
  final String nickname;
  final String? profileImageUrl;

  FriendData({
    required this.email,
    required this.nickname,
    this.profileImageUrl,
  });
}

class AsyncBattleCreateScreen extends StatefulWidget {
  const AsyncBattleCreateScreen({Key? key}) : super(key: key);

  @override
  _AsyncBattleCreateScreenState createState() => _AsyncBattleCreateScreenState();
}

class _AsyncBattleCreateScreenState extends State<AsyncBattleCreateScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions =
  FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  List<FriendData> _friendsList = [];
  bool _isLoadingFriends = true;
  bool _isCreatingBattle = false;

  String _myNickname = '알수없음';

  String? _selectedFriendEmail;
  FriendData? _selectedFriend;
  double? _selectedDistanceKm;

  final List<double> _distanceOptions = [1.0, 2.0, 3.0, 5.0, 7.0, 10.0];

  @override
  void initState() {
    super.initState();
    _loadMyDataAndFriends();
  }

  Future<void> _loadMyDataAndFriends() async {
    if (!mounted) return;
    setState(() => _isLoadingFriends = true);

    final User? user = _auth.currentUser;
    if (user == null || user.email == null) {
      _showCustomSnackBar("로그인 정보가 없습니다.", isError: true);
      setState(() => _isLoadingFriends = false);
      return;
    }

    try {
      final userDocFuture =
      _firestore.collection('users').doc(user.email).get();
      final friendsFuture = _firestore
          .collection('users')
          .doc(user.email)
          .collection('friends')
          .get();

      final results = await Future.wait([userDocFuture, friendsFuture]);

      final userDoc = results[0] as DocumentSnapshot;
      if (userDoc.exists) {
        _myNickname =
            (userDoc.data() as Map<String, dynamic>)['nickname'] ?? '알수없음';
      } else {
        _myNickname = '알수없음';
      }

      final friendsSnapshot = results[1] as QuerySnapshot;
      final friends = friendsSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return FriendData(
          email: doc.id,
          nickname: data['nickname'] ?? '이름없음',
          profileImageUrl: data['profileImageUrl'],
        );
      }).toList();

      if (mounted) {
        setState(() {
          _friendsList = friends;
          _isLoadingFriends = false;
        });
      }
    } catch (e) {
      print("데이터 로딩 오류: $e");
      if (mounted) {
        _showCustomSnackBar("데이터를 불러오는 중 오류가 발생했습니다.", isError: true);
        setState(() => _isLoadingFriends = false);
      }
    }
  }

  Future<void> _startAsyncBattle() async {
    if (_isCreatingBattle) return;

    if (_selectedFriend == null) {
      _showCustomSnackBar("대결할 친구를 선택해주세요.", isError: true);
      return;
    }
    if (_selectedDistanceKm == null) {
      _showCustomSnackBar("대결 거리를 선택해주세요.", isError: true);
      return;
    }

    if (!mounted) return;
    setState(() => _isCreatingBattle = true);
    _showLoadingDialog("대결 생성 중...");

    try {
      final callable = _functions.httpsCallable('sendAsyncBattleRequest');

      final HttpsCallableResult result = await callable.call({
        'opponentEmail': _selectedFriend!.email,
        'targetDistanceKm': _selectedDistanceKm,
        'challengerNickname': _myNickname,
      });

      if (!mounted) return;
      Navigator.pop(context);

      if (result.data['success'] == true) {
        final String? battleId = result.data['battleId'] as String?;

        if (battleId == null || battleId.isEmpty) {
          print(
              "🚨 [CREATE BATTLE] CRITICAL ERROR: Cloud Function 'sendAsyncBattleRequest' succeeded but returned an invalid battleId.");
          if (mounted) {
            _showCustomSnackBar("대결 생성에 성공했으나, Battle ID를 받지 못했습니다. (오류)",
                isError: true);
            setState(() => _isCreatingBattle = false);
          }
          return;
        }

        if (!mounted) return;

        final prefs = await SharedPreferences.getInstance();
        final bool withWatch = prefs.getBool('watchSyncEnabled') ?? false;

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => CountdownDialog(),
        ).then((_) {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => AsyncBattleRunningScreen(
                  targetDistanceKm: _selectedDistanceKm!,
                  battleId: battleId,
                  withWatch: withWatch,
                ),
              ),
            );
          }
        });

      } else {
        _showCustomSnackBar(result.data['message'] ?? "대결 생성에 실패했습니다.",
            isError: true);
        setState(() => _isCreatingBattle = false);
      }
    } catch (e) {
      print("Cloud Function 'sendAsyncBattleRequest' 호출 오류: $e");
      if (mounted) {
        Navigator.pop(context);
        _showCustomSnackBar("대결 생성 중 오류가 발생했습니다.", isError: true);
        setState(() => _isCreatingBattle = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: Image.asset('assets/images/Back-Navs.png',
              width: 66, height: 66),
          onPressed: () => Navigator.of(context).pop(),
          padding: const EdgeInsets.only(left: 8),
        ),
        title: Text('오프라인 대결 생성'),
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
      ),
      body: _isLoadingFriends
          ? Center(child: CircularProgressIndicator(color: Color(0xFFFF9F80)))
          : _friendsList.isEmpty
          ? Center(
        child: Text(
          "대결을 신청할 친구가 없습니다.\n먼저 친구를 추가해주세요.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.grey[700]),
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "1. 친구 선택",
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            _buildFriendSelector(),
            SizedBox(height: 32),

            Text(
              "2. 대결 거리 선택",
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Wrap(
              spacing: 12.0,
              runSpacing: 12.0,
              children: _distanceOptions.map((distance) {
                final isSelected = _selectedDistanceKm == distance;
                return ChoiceChip(
                  label: Text(
                    "${distance.toInt()} km",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color:
                      isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                  selected: isSelected,
                  onSelected: _isCreatingBattle
                      ? null
                      : (selected) {
                    setState(() {
                      _selectedDistanceKm =
                      selected ? distance : null;
                    });
                  },
                  selectedColor: Color(0xFFFF9F80),
                  backgroundColor: Colors.grey[100],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSelected
                          ? Color(0xFFFF9F80)
                          : Colors.grey[300]!,
                    ),
                  ),
                  padding: EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                );
              }).toList(),
            ),
            SizedBox(height: 40),

            // --- 3. 대결 시작 버튼 ---
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 55),
                backgroundColor: _isCreatingBattle
                    ? Colors.grey[400]
                    : Color(0xFFFF9F80),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed:
              _isCreatingBattle ? null : _startAsyncBattle,
              child: Text(
                _isCreatingBattle
                    ? "대결 생성 중..."
                    : "대결 시작하기 (먼저 달리기)",
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(height: 12),
            Center(
              child: Text(
                "대결 시작 버튼을 누르면 즉시 러닝이 시작됩니다.\n상대방은 내가 러닝을 완료한 후에 알림을 받습니다.",
                textAlign: TextAlign.center,
                style:
                TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendSelector() {
    return Material(
      color: Colors.grey[100],
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: _isCreatingBattle ? null : _showFriendSelectionDialog,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            children: [
              _selectedFriend != null
                  ? CircleAvatar(
                radius: 18,
                backgroundImage: _selectedFriend!.profileImageUrl != null
                    ? NetworkImage(_selectedFriend!.profileImageUrl!)
                    : AssetImage('assets/images/user.png')
                as ImageProvider,
                backgroundColor: Colors.grey[300],
              )
                  : Icon(Icons.person_outline,
                  color: Colors.grey[700], size: 24),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  _selectedFriend?.nickname ?? "대결할 친구를 선택하세요",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: _selectedFriend != null
                        ? FontWeight.w500
                        : FontWeight.normal,
                    color: _selectedFriend != null
                        ? Colors.black87
                        : Colors.grey[600],
                  ),
                ),
              ),
              Icon(Icons.arrow_drop_down_rounded, color: Colors.grey[700]),
            ],
          ),
        ),
      ),
    );
  }

  void _showFriendSelectionDialog() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. 핸들
              Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.symmetric(vertical: 10.0),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              // 2. 제목
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  '친구 선택',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Divider(height: 1, color: Colors.grey[200]),
              // 3. 친구 목록 (스크롤 가능)
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true, // 내용물 크기에 맞게 조절
                  itemCount: _friendsList.length,
                  itemBuilder: (context, index) {
                    final friend = _friendsList[index];
                    final bool isSelected =
                        _selectedFriend?.email == friend.email;

                    return ListTile(
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundImage: friend.profileImageUrl != null
                            ? NetworkImage(friend.profileImageUrl!)
                            : AssetImage('assets/images/user.png')
                        as ImageProvider,
                        backgroundColor: Colors.grey[200],
                      ),
                      title: Text(
                        friend.nickname,
                        style: TextStyle(
                          fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                          color:
                          isSelected ? Color(0xFFFF9F80) : Colors.black87,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check_circle, color: Color(0xFFFF9F80))
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedFriend = friend;
                          _selectedFriendEmail = friend.email;
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
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
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w500),
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
        return Dialog(
          backgroundColor: Colors.white,
          elevation: 0,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Color(0xFFFF9F80),
                    strokeWidth: 3,
                  ),
                ),
                SizedBox(width: 24),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class CountdownDialog extends StatefulWidget {
  const CountdownDialog({Key? key}) : super(key: key);

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
      try {
        _watch.sendMessage({'command': 'showWarmup'});
        _watch.sendMessage({'command': 'countdown', 'value': _countdown});
      } catch (e) {
        print("Watch SendMessage Error (Countdown Start): $e");
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

        try {
          _watch.sendMessage({'command': 'startRunningUI'});
        } catch (e) {
          print("Watch SendMessage Error (Countdown START!): $e");
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
          try {
            _watch.sendMessage(
                {'command': 'countdown', 'value': _countdown});
          } catch (e) {
            print("Watch SendMessage Error (Countdown $e): $e");
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