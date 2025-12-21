// [전체 코드] friend_battle_list_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart'; // 👈 Cloud Function 호출

// ▼▼▼▼▼ [ ✅ 신규 추가 ] ▼▼▼▼▼
// 1. 대결 기록 탭을 위한 신규 파일
import 'friend_battle_history_tab.dart';
// 2. Part 2에서 생성한 로비 화면
import 'friend_battle_lobby_screen.dart';
// 3. Part 10에서 생성한 '온라인 상태' 타일
import 'friend_list_tile.dart';
// ▲▲▲▲▲ [ ✅ 신규 추가 ] ▲▲▲▲▲

class FriendBattleListScreen extends StatefulWidget {
  const FriendBattleListScreen({Key? key}) : super(key: key);

  @override
  _FriendBattleListScreenState createState() => _FriendBattleListScreenState();
}

class _FriendBattleListScreenState extends State<FriendBattleListScreen>
    with SingleTickerProviderStateMixin {

  final String? _myEmail = FirebaseAuth.instance.currentUser?.email;
  bool _isLoading = false; // 로딩 중 상태
  late TabController _tabController;

  // ▼▼▼▼▼ [ ⭐️ 권한 및 잠금 상태 변수 추가 ⭐️ ] ▼▼▼▼▼
  String? _userRole; // 'user', 'admin', 'general_admin', 'super_admin'
  bool _isDebugLocked = false; // 기능 잠금 여부 (기본값 false)
  // ▲▲▲▲▲ [ ⭐️ 권한 및 잠금 상태 변수 추가 ⭐️ ] ▲▲▲▲▲

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkUserRole(); // 👈 권한 확인
    _listenToSystemLock(); // 👈 잠금 상태 구독
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ▼▼▼▼▼ [ ⭐️ 권한 및 잠금 로직 ⭐️ ] ▼▼▼▼▼
  /// 현재 사용자의 권한(Role)을 확인합니다.
  Future<void> _checkUserRole() async {
    if (_myEmail == null) return;
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(_myEmail).get();
      if (mounted && userDoc.exists) {
        setState(() {
          // DB에 role 필드가 있다고 가정 (없으면 'user')
          _userRole = userDoc.data()?['role'] ?? 'user';
        });
      }
    } catch (e) {
      print("권한 확인 실패: $e");
    }
  }

  /// 시스템 설정(잠금 여부)을 실시간으로 확인합니다.
  void _listenToSystemLock() {
    // 'system' 컬렉션의 'settings' 문서를 실시간 구독
    FirebaseFirestore.instance
        .collection('system')
        .doc('settings')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          // 문서가 없거나 필드가 없으면 기본값 false (풀림)
          _isDebugLocked = snapshot.exists ? (snapshot.data()?['isDebugLocked'] ?? false) : false;
        });
      }
    });
  }

  /// [슈퍼관리자 전용] 잠금 상태 토글 함수 (수정됨)
  Future<void> _toggleSystemLock() async {
    // 1. 변경하려는 목표 상태를 미리 변수에 저장 (현재 상태의 반대)
    // await 실행 중에 스트림이 먼저 업데이트 되어버리는 문제를 방지하기 위함
    final bool nextStatus = !_isDebugLocked;

    try {
      final docRef = FirebaseFirestore.instance.collection('system').doc('settings');

      // 2. 미리 저장해둔 상태값(nextStatus)으로 DB 저장
      await docRef.set({
        'isDebugLocked': nextStatus
      }, SetOptions(merge: true));

      // 3. 메시지 출력 시에도 nextStatus를 사용해야 정확함
      String statusMsg = nextStatus ? "기능을 잠갔습니다. 🔒" : "기능 잠금을 해제했습니다. 🔓";
      _showCustomSnackBar(statusMsg);
    } catch (e) {
      _showCustomSnackBar("설정 변경 실패: $e", isError: true);
    }
  }

  /// 디버그 버튼 클릭 시 처리 로직
  void _handleDebugPress() {
    // 1. 잠겨있는데 슈퍼관리자가 아니면 차단
    if (_isDebugLocked && _userRole != 'super_admin') {
      _showCustomSnackBar("현재 개발자에 의해 기능이 잠겨있습니다.(관리자 모드) 🚫", isError: true);
      return; // 👈 여기서 즉시 함수 종료 (다이얼로그 표시 차단)
    }

    // 2. 경고 다이얼로그 표시 (잠금이 풀렸거나, 슈퍼관리자일 경우에만 실행)
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text("개발 테스트 모드", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text("개발 테스트 모드입니다.\n불필요한 용도는 삼가해 주세요.\n\n정말 진행하시겠습니까?"),
        actions: [
          TextButton(
            child: Text("아니요", style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: Text("예 (진행)", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.pop(context);
              _createFakeBattleAndNavigate(); // 실제 로직 실행
            },
          ),
        ],
      ),
    );
  }
  // ▲▲▲▲▲ [ ⭐️ 권한 및 잠금 로직 ⭐️ ] ▲▲▲▲▲


  // (수정 없음) 스낵바
  void _showCustomSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.blueAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // (수정 없음) 1. 대결 거리 선택 다이얼로그
  Future<int?> _showDistanceSelectionDialog() async {
    return await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('대결 거리 선택', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDistanceButton(context, 1),
              _buildDistanceButton(context, 3),
              _buildDistanceButton(context, 5),
              _buildDistanceButton(context, 10),
            ],
          ),
          actions: [
            TextButton(
              child: Text('취소', style: TextStyle(color: Colors.grey[700])),
              onPressed: () => Navigator.pop(context, null),
            ),
          ],
        );
      },
    );
  }

  // (수정 없음) 1-1. 거리 선택 버튼
  Widget _buildDistanceButton(BuildContext context, int km) {
    return ListTile(
      title: Text('${km}km 대결', style: TextStyle(fontWeight: FontWeight.w500)),
      trailing: Icon(Icons.keyboard_arrow_right),
      onTap: () {
        Navigator.pop(context, km);
      },
    );
  }

  // (수정 없음) 2. 대결 신청 로직
  Future<void> _sendBattleRequest(String opponentEmail, String opponentNickname, int distanceKm) async {
    if (_myEmail == null) {
      _showCustomSnackBar("로그인이 필요합니다.", isError: true);
      return;
    }

    // 1. 확인 다이얼로그
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('대결 신청', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          content: Text('$opponentNickname 님에게 ${distanceKm}km 러닝 대결을 신청하시겠습니까?', style: TextStyle(fontSize: 15)),
          actions: [
            TextButton(
              child: Text('취소', style: TextStyle(color: Colors.grey[700])),
              onPressed: () => Navigator.pop(dialogContext, false),
            ),
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Colors.blueAccent.withOpacity(0.1),
              ),
              child: Text('신청', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
              onPressed: () => Navigator.pop(dialogContext, true),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    // 2. 로딩 상태 시작
    if (mounted) setState(() => _isLoading = true);

    try {
      // 3. Cloud Function 호출
      final callable = FirebaseFunctions.instanceFor(region: 'asia-northeast3')
          .httpsCallable('sendFriendBattleRequest');

      final result = await callable.call({
        'opponentEmail': opponentEmail,
        'targetDistanceKm': distanceKm,
      });

      if (mounted) {
        final battleId = result.data['battleId'] as String?;
        if (battleId != null) {
          _showCustomSnackBar("대결 신청을 보냈습니다. 수락을 기다립니다...");
          // 4. 성공 시 로비 화면으로 이동
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FriendBattleLobbyScreen(
                battleId: battleId,
                isChallenger: true,
              ),
            ),
          );
        } else {
          _showCustomSnackBar(result.data['message'] ?? '신청 실패 (ID 없음)', isError: true);
        }
      }

    } on FirebaseFunctionsException catch (e) {
      _showCustomSnackBar("오류: ${e.message ?? '알 수 없는 오류'}", isError: true);
    } catch (e) {
      _showCustomSnackBar("대결 신청 중 오류가 발생했습니다.", isError: true);
    } finally {
      // 5. 로딩 상태 종료
      if (mounted) setState(() => _isLoading = false);
    }
  }


  // ▼▼▼▼▼ [ ⭐️ 디버그 기능 ⭐️ ] ▼▼▼▼▼
  /// (신규) 디버그용 가짜 대결방을 만들고 로비로 즉시 이동하는 함수
  Future<void> _createFakeBattleAndNavigate() async {
    if (_myEmail == null) {
      _showCustomSnackBar("로그인이 필요합니다.", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    // 1. (Hardcoded) 가짜 상대방 정보 설정
    // (내 정보는 Firestore에서 가져오기)
    final String opponentEmail = "debug_opponent@test.com";
    final String opponentNickname = "디버그봇";
    final String? opponentProfileUrl = null;
    final int targetDistanceKm = 3; // (테스트용 3km)

    try {
      final _firestore = FirebaseFirestore.instance;
      final timestamp = FieldValue.serverTimestamp();

      // 내 닉네임/프로필 가져오기
      final myUserDoc = await _firestore.collection("users").doc(_myEmail).get();
      final String myNickname = myUserDoc.data()?['nickname'] ?? "테스터";
      final String? myProfileUrl = myUserDoc.data()?['profileImageUrl'];

      // 2. Cloud Function이 하는 일을 여기서 '수동'으로 재현
      final battleRef = _firestore.collection("friendBattles").doc();
      final battleId = battleRef.id;

      await battleRef.set({
        'status': 'pending', // 👈 로비 화면이 이 'pending' 상태를 구독함
        'challengerEmail': _myEmail,
        'challengerNickname': myNickname,
        'challengerProfileUrl': myProfileUrl,
        'challengerStatus': 'ready', // 👈 나는 'ready'

        'opponentEmail': opponentEmail,
        'opponentNickname': opponentNickname,
        'opponentProfileUrl': opponentProfileUrl,
        'opponentStatus': 'waiting', // 👈 디버그봇은 'waiting'

        'targetDistanceKm': targetDistanceKm,
        'createdAt': timestamp,
        'participants': [_myEmail, opponentEmail], // 👈 히스토리 탭 조회를 위해 추가
      });

      setState(() => _isLoading = false);

      // 3. 'friendBattles' 문서가 생성되었으므로,
      //    이제 이 battleId를 가지고 로비 화면으로 이동
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FriendBattleLobbyScreen(
            battleId: battleId,
            isChallenger: true, // 👈 내가 도전자(true)로 입장
          ),
        ),
      );

    } catch (e) {
      setState(() => _isLoading = false);
      _showCustomSnackBar("디버그 대결 생성 실패: $e", isError: true);
    }
  }
  // ▲▲▲▲▲ [ ⭐️ 디버그 기능 ⭐️ ] ▲▲▲▲▲


  @override
  Widget build(BuildContext context) {
    if (_myEmail == null) {
      return Scaffold(body: Center(child: Text("로그인이 필요합니다.")));
    }

    // ▼▼▼▼▼ [ ✅ 수정된 권한 체크 로직 ] ▼▼▼▼▼
    // 'head_admin' 대신 'general_admin'으로 수정됨
    final bool isAnyAdmin =
        _userRole == 'admin' || _userRole == 'general_admin' || _userRole == 'super_admin';
    final bool isSuperAdmin = _userRole == 'super_admin';
    // ▲▲▲▲▲ [ ✅ 수정된 권한 체크 로직 ] ▲▲▲▲▲

    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0.5,
            leading: IconButton(
              icon: Image.asset('assets/images/Back-Navs.png', width: 66, height: 66),
              onPressed: () => Navigator.pop(context),
              padding: const EdgeInsets.only(left: 8),
            ),
            title: const Text(
              '친구 대결',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            centerTitle: true,
            bottom: TabBar(
              controller: _tabController,
              labelColor: Colors.blueAccent,
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: Colors.blueAccent,
              indicatorWeight: 3.0,
              tabs: [
                Tab(text: '친구 목록'),
                Tab(text: '대결 기록'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              // 1번 탭: 친구 목록
              _buildFriendListTab(_myEmail!),
              // 2번 탭: 대결 기록
              FriendBattleHistoryTab(myEmail: _myEmail!),
            ],
          ),

          // ▼▼▼▼▼ [ ⭐️ 디버그 및 잠금 버튼 (관리자 전용) ⭐️ ] ▼▼▼▼▼
          // 관리자만 버튼을 볼 수 있음
          floatingActionButton: isAnyAdmin
              ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 1. 잠금 토글 버튼 (슈퍼 관리자만 보임)
              if (isSuperAdmin)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0), // 버튼 사이 간격
                  child: FloatingActionButton.small(
                    heroTag: 'lockBtn',
                    onPressed: _toggleSystemLock,
                    // 잠겨있으면 빨간 자물쇠, 풀려있으면 초록 열린 자물쇠
                    backgroundColor: _isDebugLocked ? Colors.redAccent : Colors.green,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    child: Icon(
                      _isDebugLocked ? Icons.lock : Icons.lock_open,
                      size: 20,
                    ),
                    tooltip: _isDebugLocked ? '기능 잠금 해제' : '기능 잠그기',
                  ),
                ),

              // 2. 디버그 생성 버튼 (모든 관리자 보임)
              FloatingActionButton.small(
                heroTag: 'debugBtn',
                onPressed: _handleDebugPress,
                backgroundColor: Colors.grey[300], // 심플한 회색
                foregroundColor: Colors.black87,
                elevation: 2,
                child: Icon(Icons.bug_report_rounded, size: 20),
                tooltip: '관리자 디버그 모드',
              ),
            ],
          )
              : null,
          // ▲▲▲▲▲ [ ⭐️ 디버그 및 잠금 버튼 (관리자 전용) ⭐️ ] ▲▲▲▲▲
        ),

        // (수정 없음) 전체 화면 로딩 오버레이
        if (_isLoading)
          Container(
            color: Colors.black.withOpacity(0.5),
            child: Center(
              child: CircularProgressIndicator(
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }

  /// 1번 탭: 친구 목록 UI
  // ▼▼▼▼▼ [ ✅ Part 10 수정 (ListTile -> FriendListTile) ] ▼▼▼▼▼
  Widget _buildFriendListTab(String myEmail) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(myEmail)
          .collection('friends')
          .orderBy('nickname', descending: false)
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
              child: Text("🏃\n아직 친구가 없습니다.\n먼저 친구를 추가해주세요.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600], fontSize: 16)
              )
          );
        }

        final friends = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          itemCount: friends.length,
          itemBuilder: (context, index) {
            final friendData = friends[index].data() as Map<String, dynamic>;
            final friendEmail = friendData['email'] as String? ?? '';
            final friendNickname = friendData['nickname'] as String? ?? '알 수 없음';
            final friendProfileUrl = friendData['profileImageUrl'] as String?;

            if (friendEmail.isEmpty) return SizedBox.shrink();

            // [수정] ListTile 대신 FriendListTile 위젯 사용
            return FriendListTile(
              key: Key(friendEmail), // 👈 고유 키
              friendEmail: friendEmail,
              friendNickname: friendNickname,
              friendProfileUrl: friendProfileUrl,
              // '대결 요청' 버튼이 눌렸을 때 실행할 콜백 함수 전달
              onBattleRequestPressed: (email, nickname) async {
                // 1. 거리 선택
                final int? selectedKm = await _showDistanceSelectionDialog();
                // 2. 거리가 선택되었으면 신청
                if (selectedKm != null && mounted) {
                  _sendBattleRequest(email, nickname, selectedKm);
                }
              },
            );
          },
        );
      },
    );
  }
// ▲▲▲▲▲ [ ✅ Part 10 수정 ] ▲▲▲▲▲
}