// [전체 코드] async_battle_create_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

// ▼▼▼▼▼ [ ⭐️ 수정: TTS 임포트 추가 ⭐️ ] ▼▼▼▼▼
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/services.dart'; // for IosTextToSpeechAudioCategory
// ▲▲▲▲▲ [ ⭐️ 수정: TTS 임포트 추가 ⭐️ ] ▲▲▲▲▲

// ▼▼▼▼▼ [ ⭐️⭐️⭐️ 신규 수정: 워치 커넥티비티 임포트 ⭐️⭐️⭐️ ] ▼▼▼▼▼
import 'package:watch_connectivity/watch_connectivity.dart';
// ▲▲▲▲▲ [ ⭐️⭐️⭐️ 신규 수정: 워치 커넥티비티 임포트 ⭐️⭐️⭐️ ] ▲▲▲▲▲

// ▼▼▼▼▼ [ ✨✨✨ 핵심 수정: 설정값 로드용 임포트 ✨✨✨ ] ▼▼▼▼▼
import 'package:shared_preferences/shared_preferences.dart';
// ▲▲▲▲▲ [ ✨✨✨ 핵심 수정: 설정값 로드용 임포트 ✨✨✨ ] ▲▲▲▲▲

// ▼▼▼▼▼ [ ⭐️⭐️⭐️ 파트 4 수정 ⭐️⭐️⭐️ ] ▼▼▼▼▼
// 1. [제거] RunningPage 임포트
// import '../free_running/free_running_start.dart';
// 2. [신규] 오프라인 대결 전용 러닝 페이지 임포트
import 'async_battle_running_screen.dart';
// ▲▲▲▲▲ [ ⭐️⭐️⭐️ 파트 4 수정 ⭐️⭐️⭐️ ] ▲▲▲▲▲

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

  // ▼▼▼▼▼ [ ⭐️⭐️⭐️ 닉네임 수정 1/4: 상태 변수 추가 ⭐️⭐️⭐️ ] ▼▼▼▼▼
  String _myNickname = '알수없음';
  // ▲▲▲▲▲ [ ⭐️⭐️⭐️ 닉네임 수정 1/4: 상태 변수 추가 ⭐️⭐️⭐️ ] ▲▲▲▲▲

  String? _selectedFriendEmail;
  // ▼▼▼▼▼ [ ⭐️⭐️⭐️ UI 수정 (Part 13) ⭐️⭐️⭐️ ] ▼▼▼▼▼
  // 선택된 친구의 전체 정보를 저장하기 위해 FriendData 타입으로 변경
  FriendData? _selectedFriend;
  // ▲▲▲▲▲ [ ⭐️⭐️⭐️ UI 수정 (Part 13) ⭐️⭐️⭐️ ] ▲▲▲▲▲
  double? _selectedDistanceKm;

  // ▼▼▼▼▼ [ ⭐️⭐️⭐️ 7km 추가 ⭐️⭐️⭐️ ] ▼▼▼▼▼
  // 거리 선택 옵션
  final List<double> _distanceOptions = [1.0, 2.0, 3.0, 5.0, 7.0, 10.0];
  // ▲▲▲▲▲ [ ⭐️⭐️⭐️ 7km 추가 ⭐️⭐️⭐️ ] ▲▲▲▲▲

  @override
  void initState() {
    super.initState();
    // ▼▼▼▼▼ [ ⭐️⭐️⭐️ 닉네임 수정 2/4: initState 수정 ⭐️⭐️⭐️ ] ▼▼▼▼▼
    // 닉네임 로딩과 친구 목록 로딩을 동시에 시작
    _loadMyDataAndFriends();
    // ▲▲▲▲▲ [ ⭐️⭐️⭐️ 닉네임 수정 2/4: initState 수정 ⭐️⭐️⭐️ ] ▲▲▲▲▲
  }

  // ▼▼▼▼▼ [ ⭐️⭐️⭐️ 닉네임 수정 3/4: 함수 2개(_loadMyDataAndFriends, _fetchFriends) 수정 ⭐️⭐️⭐️ ] ▼▼▼▼▼
  // (신규) 닉네임과 친구목록을 병렬로 로드하는 함수
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
      // 1. 내 닉네임 가져오기
      final userDocFuture =
      _firestore.collection('users').doc(user.email).get();
      // 2. 친구 목록 가져오기
      final friendsFuture = _firestore
          .collection('users')
          .doc(user.email)
          .collection('friends')
          .get();

      // 두 작업을 동시에 실행
      final results = await Future.wait([userDocFuture, friendsFuture]);

      // 1. 내 닉네임 처리
      final userDoc = results[0] as DocumentSnapshot;
      if (userDoc.exists) {
        _myNickname =
            (userDoc.data() as Map<String, dynamic>)['nickname'] ?? '알수없음';
      } else {
        _myNickname = '알수없음';
      }

      // 2. 친구 목록 처리
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

  // ▼▼▼▼▼ [ ⭐️⭐️⭐️ (요청) 카운트다운 로직 수정 1/2: _startAsyncBattle 함수 수정 ⭐️⭐️⭐️ ] ▼▼▼▼▼
  Future<void> _startAsyncBattle() async {
    if (_isCreatingBattle) return; // 중복 생성 방지

    // 1. 유효성 검사
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
      // 2. Cloud Function (sendAsyncBattleRequest) 호출
      final callable = _functions.httpsCallable('sendAsyncBattleRequest');

      final HttpsCallableResult result = await callable.call({
        'opponentEmail': _selectedFriend!.email,
        'targetDistanceKm': _selectedDistanceKm,
        'challengerNickname': _myNickname,
      });

      if (!mounted) return;
      Navigator.pop(context); // 로딩 다이얼로그 닫기

      if (result.data['success'] == true) {
        // 3. 성공 시: battleId를 받아 RunningPage로 이동
        final String? battleId = result.data['battleId'] as String?;

        // 3-1. [⭐️⭐️⭐️핵심 수정⭐️⭐️⭐️] battleId가 null이거나 비어있는지 확인
        if (battleId == null || battleId.isEmpty) {
          print(
              "🚨 [CREATE BATTLE] CRITICAL ERROR: Cloud Function 'sendAsyncBattleRequest' succeeded but returned an invalid battleId.");
          if (mounted) {
            _showCustomSnackBar("대결 생성에 성공했으나, Battle ID를 받지 못했습니다. (오류)",
                isError: true);
            setState(() => _isCreatingBattle = false);
          }
          return; // 👈 [중요] ID가 없으면 네비게이션을 중단
        }

        // 3-2. (기존 로직)
        if (!mounted) return;

        // ▼▼▼▼▼ [ ✨✨✨ 핵심 수정: 설정값 로드 및 적용 ✨✨✨ ] ▼▼▼▼▼
        // SharedPreferences에서 워치 설정값 미리 로드
        final prefs = await SharedPreferences.getInstance();
        final bool withWatch = prefs.getBool('watchSyncEnabled') ?? false;

        // 3-2. (수정) 3초 카운트다운 다이얼로그 표시
        showDialog(
          context: context,
          barrierDismissible: false, // 👈 뒤로가기/바탕 터치로 닫기 금지
          builder: (context) => CountdownDialog(), // 👈 신규 위젯 호출
        ).then((_) {
          // 3-3. (수정) 다이얼로그가 닫히면 (즉, 3초가 지나면) 러닝 화면으로 이동
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                // ▼▼▼▼▼ [ ⭐️⭐️⭐️ 신규 수정: withWatch 전달 ⭐️⭐️⭐️ ] ▼▼▼▼▼
                builder: (context) => AsyncBattleRunningScreen(
                  targetDistanceKm: _selectedDistanceKm!,
                  battleId: battleId,
                  // ❗️ [수정] 저장된 설정값(withWatch)을 전달합니다.
                  withWatch: withWatch,
                ),
                // ▲▲▲▲▲ [ ⭐️⭐️⭐️ 신규 수정: withWatch 전달 ⭐️⭐️⭐️ ] ▲▲▲▲▲
              ),
            );
          }
        });
        // ▲▲▲▲▲ [ ✨✨✨ 핵심 수정: 설정값 로드 및 적용 ✨✨✨ ] ▲▲▲▲▲

      } else {
        // 4. 실패 시 (Functions에서 success: false 반환)
        _showCustomSnackBar(result.data['message'] ?? "대결 생성에 실패했습니다.",
            isError: true);
        setState(() => _isCreatingBattle = false);
      }
    } catch (e) {
      // 5. 호출 자체 실패 시 (네트워크 오류 등)
      print("Cloud Function 'sendAsyncBattleRequest' 호출 오류: $e");
      if (mounted) {
        Navigator.pop(context); // 로딩 다이얼로그 닫기
        _showCustomSnackBar("대결 생성 중 오류가 발생했습니다.", isError: true);
        setState(() => _isCreatingBattle = false);
      }
    }
  }
  // ▲▲▲▲▲ [ ⭐️⭐️⭐️ (요청) 카운트다운 로직 수정 1/2: _startAsyncBattle 함수 수정 ⭐️⭐️⭐️ ] ▲▲▲▲▲

  // (UI 함수 - 수정 없음)
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        // (Part 12에서 수정한 내용 - 유지)
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
            // ▼▼▼▼▼ [ ⭐️⭐️⭐️ UI 수정 (Part 13) ⭐️⭐️⭐️ ] ▼▼▼▼▼
            // --- 1. 친구 선택 (Dropdown -> ListTile) ---
            Text(
              "1. 친구 선택",
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            _buildFriendSelector(), // 👈 [신규] 헬퍼 위젯 호출
            SizedBox(height: 32),
            // ▲▲▲▲▲ [ ⭐️⭐️⭐️ UI 수정 (Part 13) ⭐️⭐️⭐️ ] ▲▲▲▲▲

            // --- 2. 거리 선택 ---
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
                    // ▼▼▼▼▼ [ ⭐️⭐️⭐️ 요청하신 수정 (1km, 2km 포맷팅) ⭐️⭐️⭐️ ] ▼▼▼▼▼
                    // 1.0, 2.0 등도 .0 없이 "1 km"로 보이도록 .toInt() 사용
                    "${distance.toInt()} km",
                    // ▲▲▲▲▲ [ ⭐️⭐️⭐️ 요청하신 수정 (1km, 2km 포맷팅) ⭐️⭐️⭐️ ] ▼▼▼▼▼
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

  // ▼▼▼▼▼ [ ⭐️⭐️⭐️ 신규 헬퍼 (Part 13) ⭐️⭐️⭐️ ] ▼▼▼▼▼
  /// 친구 선택 버튼 (ListTile) UI
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
              // 선택된 친구 프로필 또는 기본 아이콘
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
              // 선택된 친구 닉네임 또는 힌트 텍스트
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

  /// 친구 선택 바텀시트
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
                          _selectedFriendEmail =
                              friend.email; // (기존 로직 유지를 위해 이것도 세팅)
                        });
                        Navigator.pop(context); // 바텀시트 닫기
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
  // ▲▲▲▲▲ [ ⭐️⭐️⭐️ 신규 헬퍼 (Part 13) ⭐️⭐️⭐️ ] ▲▲▲▲▲

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
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor:
        isError ? Colors.redAccent.shade400 : Colors.blueAccent, // 성공/오류 색상
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(15, 5, 15, 15),
      ),
    );
  }

  // 👇👇👇 [ ⭐️⭐️⭐️ 요청에 의해 수정된 부분: 심플한 로딩 다이얼로그 ⭐️⭐️⭐️ ] 👇👇👇
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
// 👆👆👆 [ ⭐️⭐️⭐️ 요청에 의해 수정된 부분: 심플한 로딩 다이얼로그 ⭐️⭐️⭐️ ] 👆👆👆
}

// ▼▼▼▼▼ [ ⭐️⭐️⭐️ TTS 및 워치 연동이 포함된 CountdownDialog 수정 ⭐️⭐️⭐️ ] ▼▼▼▼▼
class CountdownDialog extends StatefulWidget {
  const CountdownDialog({Key? key}) : super(key: key);

  @override
  _CountdownDialogState createState() => _CountdownDialogState();
}

class _CountdownDialogState extends State<CountdownDialog> {
  int _countdown = 3;
  Timer? _timer;

  // ▼▼▼▼▼ [ ⭐️ 수정: TTS 인스턴스 추가 ⭐️ ] ▼▼▼▼▼
  late FlutterTts _flutterTts;
  // ▲▲▲▲▲ [ ⭐️ 수정: TTS 인스턴스 추가 ⭐️ ] ▼▼▼▼▼

  final _watch = WatchConnectivity();

  @override
  void initState() {
    super.initState();
    // ▼▼▼▼▼ [ ⭐️ 수정: TTS 초기화 후 타이머 시작 ⭐️ ] ▼▼▼▼▼
    _flutterTts = FlutterTts();
    _initTts();
    // ▲▲▲▲▲ [ ⭐️ 수정: TTS 초기화 후 타이머 시작 ⭐️ ] ▼▼▼▼▼
  }

  // ▼▼▼▼▼ [ ⭐️ 수정: TTS 설정 및 음성 출력 함수 추가 ⭐️ ] ▼▼▼▼▼
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

    // TTS 준비 완료 후 타이머 시작
    _startTimer();
  }

  Future<void> _speak(String text) async {
    if (mounted) {
      await _flutterTts.speak(text);
    }
  }
  // ▲▲▲▲▲ [ ⭐️ 수정: TTS 설정 및 음성 출력 함수 추가 ⭐️ ] ▲▲▲▲▲

  void _startTimer() {
    // 시작 시 3초 음성 및 워치 전송
    if (_countdown > 0) {
      _speak(_countdown.toString()); // 👈 3초 음성
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
        setState(() => _countdown = 0); // "START!"로 변경

        // ▼▼▼▼▼ [ ⭐️ 수정: START 화면과 함께 음성 출력 ⭐️ ] ▼▼▼▼▼
        _speak("대결을 시작합니다!"); // 👈 여기로 이동됨
        // ▲▲▲▲▲ [ ⭐️ 수정: START 화면과 함께 음성 출력 ⭐️ ] ▲▲▲▲▲

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
          _speak(_countdown.toString()); // 👈 2초, 1초 음성
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
    _flutterTts.stop(); // 👈 TTS 중지
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
// ▲▲▲▲▲ [ ⭐️⭐️⭐️ TTS 및 워치 연동이 포함된 CountdownDialog 수정 ⭐️⭐️⭐️ ] ▲▲▲▲▲