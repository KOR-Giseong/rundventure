import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'friend_battle_history_tab.dart';
import 'friend_battle_lobby_screen.dart';
import 'friend_list_tile.dart';

class FriendBattleListScreen extends StatefulWidget {
  const FriendBattleListScreen({Key? key}) : super(key: key);

  @override
  _FriendBattleListScreenState createState() => _FriendBattleListScreenState();
}

class _FriendBattleListScreenState extends State<FriendBattleListScreen>
    with SingleTickerProviderStateMixin {

  final String? _myEmail = FirebaseAuth.instance.currentUser?.email;
  bool _isLoading = false;
  late TabController _tabController;

  String? _userRole;
  bool _isDebugLocked = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkUserRole();
    _listenToSystemLock();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkUserRole() async {
    if (_myEmail == null) return;
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(_myEmail).get();
      if (mounted && userDoc.exists) {
        setState(() {
          _userRole = userDoc.data()?['role'] ?? 'user';
        });
      }
    } catch (e) {
      print("권한 확인 실패: $e");
    }
  }

  void _listenToSystemLock() {
    FirebaseFirestore.instance
        .collection('system')
        .doc('settings')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _isDebugLocked = snapshot.exists ? (snapshot.data()?['isDebugLocked'] ?? false) : false;
        });
      }
    });
  }

  Future<void> _toggleSystemLock() async {
    final bool nextStatus = !_isDebugLocked;

    try {
      final docRef = FirebaseFirestore.instance.collection('system').doc('settings');

      await docRef.set({
        'isDebugLocked': nextStatus
      }, SetOptions(merge: true));

      String statusMsg = nextStatus ? "기능을 잠갔습니다. 🔒" : "기능 잠금을 해제했습니다. 🔓";
      _showCustomSnackBar(statusMsg);
    } catch (e) {
      _showCustomSnackBar("설정 변경 실패: $e", isError: true);
    }
  }

  void _handleDebugPress() {
    if (_isDebugLocked && _userRole != 'super_admin') {
      _showCustomSnackBar("현재 개발자에 의해 기능이 잠겨있습니다.(관리자 모드) 🚫", isError: true);
      return;
    }

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

  Widget _buildDistanceButton(BuildContext context, int km) {
    return ListTile(
      title: Text('${km}km 대결', style: TextStyle(fontWeight: FontWeight.w500)),
      trailing: Icon(Icons.keyboard_arrow_right),
      onTap: () {
        Navigator.pop(context, km);
      },
    );
  }

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

  Future<void> _createFakeBattleAndNavigate() async {
    if (_myEmail == null) {
      _showCustomSnackBar("로그인이 필요합니다.", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    final String opponentEmail = "debug_opponent@test.com";
    final String opponentNickname = "디버그봇";
    final String? opponentProfileUrl = null;
    final int targetDistanceKm = 3;

    try {
      final _firestore = FirebaseFirestore.instance;
      final timestamp = FieldValue.serverTimestamp();

      final myUserDoc = await _firestore.collection("users").doc(_myEmail).get();
      final String myNickname = myUserDoc.data()?['nickname'] ?? "테스터";
      final String? myProfileUrl = myUserDoc.data()?['profileImageUrl'];

      final battleRef = _firestore.collection("friendBattles").doc();
      final battleId = battleRef.id;

      await battleRef.set({
        'status': 'pending',
        'challengerEmail': _myEmail,
        'challengerNickname': myNickname,
        'challengerProfileUrl': myProfileUrl,
        'challengerStatus': 'ready',
        'opponentEmail': opponentEmail,
        'opponentNickname': opponentNickname,
        'opponentProfileUrl': opponentProfileUrl,
        'opponentStatus': 'waiting',
        'targetDistanceKm': targetDistanceKm,
        'createdAt': timestamp,
        'participants': [_myEmail, opponentEmail],
      });

      setState(() => _isLoading = false);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FriendBattleLobbyScreen(
            battleId: battleId,
            isChallenger: true,
          ),
        ),
      );

    } catch (e) {
      setState(() => _isLoading = false);
      _showCustomSnackBar("디버그 대결 생성 실패: $e", isError: true);
    }
  }


  @override
  Widget build(BuildContext context) {
    if (_myEmail == null) {
      return Scaffold(body: Center(child: Text("로그인이 필요합니다.")));
    }

    final bool isAnyAdmin =
        _userRole == 'admin' || _userRole == 'general_admin' || _userRole == 'super_admin';
    final bool isSuperAdmin = _userRole == 'super_admin';

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

          floatingActionButton: isAnyAdmin
              ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (isSuperAdmin)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: FloatingActionButton.small(
                    heroTag: 'lockBtn',
                    onPressed: _toggleSystemLock,
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

              FloatingActionButton.small(
                heroTag: 'debugBtn',
                onPressed: _handleDebugPress,
                backgroundColor: Colors.grey[300],
                foregroundColor: Colors.black87,
                elevation: 2,
                child: Icon(Icons.bug_report_rounded, size: 20),
                tooltip: '관리자 디버그 모드',
              ),
            ],
          )
              : null,
        ),

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

            return FriendListTile(
              key: Key(friendEmail),
              friendEmail: friendEmail,
              friendNickname: friendNickname,
              friendProfileUrl: friendProfileUrl,
              onBattleRequestPressed: (email, nickname) async {
                final int? selectedKm = await _showDistanceSelectionDialog();
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
}