// lib/ranking/ranking_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
// ✅ [신규] SharedPreferences import
import 'package:shared_preferences/shared_preferences.dart';
// ✅ [신규] 명예의 전당 팝업 import (알림 팝업에서 사용)
import 'ranking_history_popup.dart';
import 'ranking_header.dart';
// ▼▼▼▼▼ [ ⭐️ 신규 추가 ⭐️ ] ▼▼▼▼▼
import 'monthly_ranking_info_screen.dart'; // 👈 월간 랭킹 보상 안내 페이지
// ▲▲▲▲▲ [ ⭐️ 신규 추가 ⭐️ ] ▲▲▲▲▲

class RankingScreen extends StatefulWidget {
  const RankingScreen({Key? key}) : super(key: key);

  @override
  _RankingScreenState createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // ✅✅✅ [오류 수정] .aRundventure -> .instance ✅✅✅
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NumberFormat _formatter = NumberFormat('#,###');

  TabController? _tabController;

  Stream<QuerySnapshot>? _weeklyRankingStream;
  Stream<QuerySnapshot>? _monthlyRankingStream;

  DocumentSnapshot? _myWeeklyRankData;
  DocumentSnapshot? _myMonthlyRankData;
  bool _isLoadingMyRank = true;
  String? _currentUserEmail;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController?.addListener(() {
      if (_tabController!.indexIsChanging || !_tabController!.indexIsChanging) { // 👈 탭 변경 시 setState 호출
        setState(() {});
      }
    });

    _currentUserEmail = _auth.currentUser?.email;

    // ✅✅✅ [수정됨] ✅✅✅
    // 'users' 컬렉션 대신 'weeklyLeaderboard' 컬렉션을 읽도록 변경
    // 보안 규칙에서 이 컬렉션은 "allow read: if isSignedIn()"이므로 모든 사용자가 접근 가능
    _weeklyRankingStream = _firestore
        .collection('weeklyLeaderboard/current/users') // 👈 경로 변경
    // ✅✅✅ [오류 수정] ascending: true -> descending: false ✅✅✅
        .orderBy('rank', descending: false) // 👈 'rank' 필드로 오름차순 정렬
        .limit(30)
        .snapshots();

    // ✅✅✅ [수정됨] ✅✅✅
    // 월간 랭킹도 동일한 구조를 가진다고 가정하고 'monthlyLeaderboard'를 읽도록 변경
    // (참고: 'scheduled.js'에서 이 컬렉션을 생성하는 로직이 필요합니다)
    _monthlyRankingStream = _firestore
        .collection('monthlyLeaderboard/current/users') // 👈 경로 변경
    // ✅✅✅ [오류 수정] ascending: true -> descending: false ✅✅✅
        .orderBy('rank', descending: false) // 👈 'rank' 필드로 오름차순 정렬
        .limit(30)
        .snapshots();

    _fetchMyRank(); // 내 순위 가져오기

    // ✅ [신규] 랭킹 리셋 팝업 확인 로직 호출
    _checkRankingReset();
  }

  // (수정 없음) _checkRankingReset 함수
  Future<void> _checkRankingReset() async {
    // SharedPreferences 인스턴스 가져오기
    final prefs = await SharedPreferences.getInstance();

    // metadata에서 지난주/지난달 집계 시간 가져오기
    try {
      final weekDoc = await _firestore.collection('metadata').doc('previousWeekWinners').get();
      final monthDoc = await _firestore.collection('metadata').doc('previousMonthWinners').get();

      if (!mounted) return;

      // --- 주간 랭킹 확인 ---
      if (weekDoc.exists && (weekDoc.data() as Map).containsKey('updatedAt')) {
        final weeklyResetTimestamp = (weekDoc.data()!['updatedAt'] as Timestamp).toDate().toIso8601String();
        final lastCheckedWeekly = prefs.getString('lastCheckedWeeklyReset');

        // SharedPreferences에 저장된 시간이 서버 시간과 다르면 (즉, 새로 집계됨)
        if (weeklyResetTimestamp != lastCheckedWeekly) {
          // 팝업 보여주기
          _showResetNotificationDialog(
              context: context,
              title: '주간 랭킹 집계 완료',
              message: '지난주 랭킹이 마감되었습니다.\n명예의 전당 버튼에서 지난 랭킹을 확인해 보세요!',
              onConfirm: () {
                // 팝업의 '기록 확인' 버튼 누르면 명예의 전당 팝업 띄우기
                Navigator.pop(context); // 알림 팝업 닫기
                showDialog(
                  context: context,
                  builder: (context) => const RankingHistoryPopup(),
                );
              },
              prefsKey: 'lastCheckedWeeklyReset', // 이 키로
              newValue: weeklyResetTimestamp      // 이 값을 저장
          );
        }
      }

      // --- 월간 랭킹 확인 ---
      if (monthDoc.exists && (monthDoc.data() as Map).containsKey('updatedAt')) {
        final monthlyResetTimestamp = (monthDoc.data()!['updatedAt'] as Timestamp).toDate().toIso8601String();
        final lastCheckedMonthly = prefs.getString('lastCheckedMonthlyReset');

        // 월간 랭킹도 확인
        if (monthlyResetTimestamp != lastCheckedMonthly) {
          _showResetNotificationDialog(
              context: context,
              title: '월간 랭킹 집계 완료',
              message: '지난달 랭킹이 마감되었습니다.\n명예의 전당에서 내 수상 기록을 확인해 보세요!',
              onConfirm: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (context) => const RankingHistoryPopup(),
                );
              },
              prefsKey: 'lastCheckedMonthlyReset',
              newValue: monthlyResetTimestamp
          );
        }
      }
    } catch (e) {
      print("랭킹 리셋 확인 중 오류: $e");
    }
  }

  // (수정 없음) _showResetNotificationDialog 함수
  void _showResetNotificationDialog({
    required BuildContext context,
    required String title,
    required String message,
    required VoidCallback onConfirm,
    required String prefsKey,
    required String newValue,
  }) {
    // (빌드가 완료된 후에 팝업을 띄우기 위해 addPostFrameCallback 사용)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text(title, style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
          content: Text(message, style: TextStyle(color: Colors.black87.withOpacity(0.8))),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('닫기', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: onConfirm,
              child: Text('기록 확인하기', style: TextStyle(color: Color(0xFFFF9F80), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      // 팝업이 닫힌 후, SharedPreferences에 "확인 완료" 타임스탬프 저장
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefsKey, newValue);
    });
  }
  // ✅✅✅ [신규 함수 끝] ✅✅✅


  @override
  void dispose() {
    _tabController?.removeListener(() {}); // 👈 리스너 정리
    _tabController?.dispose();
    super.dispose();
  }


  // (수정 없음) _fetchMyRank 함수
  Future<void> _fetchMyRank() async {
    if (!mounted) return;
    setState(() => _isLoadingMyRank = true);

    if (_currentUserEmail == null) {
      if (mounted) setState(() => _isLoadingMyRank = false);
      return;
    }

    try {
      // 1. 내 기본 사용자 정보 가져오기 (닉네임, 현재 EXP 등)
      // (보안 규칙 allow get: if true; 로 허용됨)
      final myUserDoc = await _firestore.collection('users').doc(_currentUserEmail).get();
      if (!mounted) return;

      if (!myUserDoc.exists) {
        if (mounted) setState(() => _isLoadingMyRank = false);
        return; // 사용자 문서가 없으면 중단
      }

      final myUserData = myUserDoc.data() as Map<String, dynamic>;

      // 2. 내 랭킹 정보 가져오기 (주간/월간 리더보드에서)
      // (보안 규칙 allow read: if isSignedIn(); 으로 허용됨)
      final rankResults = await Future.wait([
        _firestore.doc('weeklyLeaderboard/current/users/$_currentUserEmail').get(),
        _firestore.doc('monthlyLeaderboard/current/users/$_currentUserEmail').get(),
      ]);

      if (!mounted) return;

      final myWeeklyRankDoc = rankResults[0];
      final myMonthlyRankDoc = rankResults[1];

      // 3. 주간 랭킹 설정
      int myWeeklyRank = 0; // 0위는 '순위권 밖'으로 간주
      if (myWeeklyRankDoc.exists) {
        myWeeklyRank = (myWeeklyRankDoc.data() as Map<String, dynamic>)['rank'] as int? ?? 0;
      }
      _myWeeklyRankData = await _createMyRankSnapshot(myWeeklyRank, myUserData, 'weeklyExp');

      // 4. 월간 랭킹 설정
      int myMonthlyRank = 0; // 0위는 '순위권 밖'으로 간주
      if (myMonthlyRankDoc.exists) {
        myMonthlyRank = (myMonthlyRankDoc.data() as Map<String, dynamic>)['rank'] as int? ?? 0;
      }
      _myMonthlyRankData = await _createMyRankSnapshot(myMonthlyRank, myUserData, 'monthlyExp');

    } catch (e) {
      print("내 순위 정보 로딩 실패: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('내 순위 정보를 불러오는 중 오류가 발생했습니다.'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingMyRank = false);
      }
    }
  }

  // (수정 없음)
  Future<DocumentSnapshot> _createMyRankSnapshot(int rank, Map<String, dynamic> userData, String expField) async {
    return _SyntheticDocumentSnapshot({
      'rank': rank,
      'nickname': userData['nickname'] ?? '나',
      'exp': (userData[expField] as num?)?.toInt() ?? 0,
      'isCurrentUser': true
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight + 10.0),
        child: RankingHeader(),
      ),
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // ▼▼▼▼▼ [ ⭐️ 여기가 수정된 부분입니다 ⭐️ ] ▼▼▼▼▼
          Container(
            color: Colors.white,
            // 1. Stack을 사용하여 TabBar와 IconButton을 겹치게 함
            child: Stack(
              alignment: Alignment.centerRight, // 👈 아이콘을 오른쪽 중앙에 정렬
              children: [
                // 2. TabBar는 전체 너비를 차지
                TabBar(
                  controller: _tabController,
                  labelColor: Color(0xFFFF9F80),
                  unselectedLabelColor: Colors.grey[500],
                  indicatorColor: Color(0xFFFF9F80),
                  indicatorWeight: 3.0,
                  labelStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  tabs: [
                    Tab(text: '주간 랭킹'),
                    Tab(text: '월간 랭킹'),
                  ],
                ),
                // 3. 월간 랭킹 탭일 때만 오른쪽에 아이콘 버튼 표시
                // Visibility 위젯을 사용해 탭 인덱스에 따라 아이콘을 끄고 켬
                Visibility(
                  visible: _tabController?.index == 1, // 👈 월간 랭킹 탭(index 1)일 때만 보임
                  maintainSize: true, // 👈 공간은 항상 차지 (레이아웃 밀림 방지)
                  maintainAnimation: true,
                  maintainState: true,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: IconButton(
                      icon: Icon(Icons.card_giftcard_outlined, color: Colors.blueAccent),
                      tooltip: '월간 랭킹 보상 안내',
                      onPressed: () {
                        // 👈 [신규] 새 페이지로 이동
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MonthlyRankingInfoScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ▲▲▲▲▲ [ ⭐️ 여기가 수정된 부분입니다 ⭐️ ] ▲▲▲▲▲

          // --- 내 순위 표시 (선택된 탭 기준) ---
          // (수정 없음)
          _buildMyRankCard(),

          // --- Top 30 랭킹 리스트 (탭뷰) --- (수정 없음)
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRankingList(
                  stream: _weeklyRankingStream,
                  expField: 'weeklyExp', // Cloud Function이 'weeklyExp'로 저장함
                  emptyMessage: '아직 주간 랭킹이 없습니다',
                ),
                _buildRankingList(
                  stream: _monthlyRankingStream,
                  expField: 'monthlyExp', // Cloud Function이 'monthlyExp'로 저장한다고 가정
                  emptyMessage: '아직 월간 랭킹이 없습니다',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // (수정 없음) _buildMyRankCard 함수
  Widget _buildMyRankCard() {
    final isWeeklyTab = (_tabController?.index ?? 0) == 0;
    final DocumentSnapshot? myDataSnapshot = isWeeklyTab ? _myWeeklyRankData : _myMonthlyRankData;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8.0),
      decoration: BoxDecoration(
          color: Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Color(0xFFFFE0B2).withOpacity(0.8))
      ),
      child: Builder(
          builder: (context) {
            if (_isLoadingMyRank) {
              return Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF9F80))));
            }
            if (myDataSnapshot == null || !myDataSnapshot.exists || _currentUserEmail == null) {
              return ListTile(
                dense: true,
                title: Text('내 순위를 보려면 로그인해주세요.', style: TextStyle(color: Colors.grey[700], fontSize: 14)),
                leading: SizedBox(width: 40, child: Icon(Icons.person_outline, color: Colors.grey[600])),
              );
            }
            final myData = myDataSnapshot.data() as Map<String, dynamic>;
            final int myRank = myData['rank'] as int? ?? 0; // 랭크 가져오기

            // 랭크가 0 (또는 순위권 밖)일 때 다른 UI 표시
            if (myRank <= 0) {
              return _buildRankListItem(
                rank: 0, // 순위권 밖 UI를 위해 0 전달
                nickname: myData['nickname'],
                exp: myData['exp'],
                isCurrentUser: true,
              );
            }

            // 랭킹에 있을 때 (기존 로직)
            return _buildRankListItem(
              rank: myRank,
              nickname: myData['nickname'],
              exp: myData['exp'],
              isCurrentUser: true,
            );
          }
      ),
    );
  }

  // (수정 없음 - 동점자 처리 로직은 이전 답변에서 이미 반영됨)
  Widget _buildRankingList({
    required Stream<QuerySnapshot>? stream,
    required String expField,
    required String emptyMessage,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: Color(0xFFFF9F80)));
        }
        if (snapshot.hasError) {
          print("랭킹 스트림 오류 ($expField): ${snapshot.error}");
          // ❗️[수정] .count() 쿼리가 아니므로 'permission-denied' 오류는 여기서 발생하면 안 됨
          // ❗️'monthlyLeaderboard/current/users' 컬렉션이 없는 경우 오류가 날 수 있음
          if (snapshot.error.toString().contains('permission-denied')) {
            return Center(child: Text('랭킹을 불러오는 중 오류가 발생했습니다.\n(보안 규칙 확인)'));
          } else if (snapshot.error.toString().contains('not found') || snapshot.error.toString().contains('NOT_FOUND')) {
            return Center(child: Text('랭킹 데이터($expField)를 찾을 수 없습니다.\n(Cloud Function 설정 확인)'));
          }
          return Center(child: Text('랭킹을 불러오는 중 오류가 발생했습니다.'));
        }

        // ✅ [수정됨] leaderboard 컬렉션은 'exp > 0'인 사용자만 저장한다고 가정함.
        // ✅ 만약 0 EXP 유저도 포함된다면 이전 로직(where)을 다시 사용해야 함.
        final participatingUsers = snapshot.data?.docs;

        if (participatingUsers == null || participatingUsers.isEmpty) {
          return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.leaderboard_outlined, size: 60, color: Colors.grey[300]),
                  SizedBox(height: 16),
                  Text(emptyMessage, style: TextStyle(color: Colors.grey[500])),
                  Text('이번 주 첫 번째 주자가 되어보세요!', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                ],
              )
          );
        }

        // ✅ [수정됨] 랭킹 리스트는 Cloud Function이 이미 'rank' 기준으로 정렬해서 줌.
        // ✅ 'weeklyLeaderboard'는 'rank' 필드를 포함해야 함.
        // ✅ [주의] 동점자 처리가 Cloud Function에서 이미 계산되었다고 가정함.
        // ✅ 만약 Cloud Function이 동점자 처리를 안했다면, 'exp'로 다시 정렬해야 함.
        // ✅ 지금 코드는 Cloud Function이 'rank'를 완벽히 계산했다고 가정함.

        // ❗️❗️❗️ [자체 수정]
        // ❗️ 'expField'가 여전히 필요함. leaderboard 문서에도 'weeklyExp'/'monthlyExp'가 저장되어야 함.
        // ❗️ 'scheduled.js'에서 'weeklyExp'를 저장하고 있으므로 'expField'는 유효함.
        // ❗️ 'doc.id'가 userEmail이므로 'isCurrentUser' 로직도 유효함.

        return RefreshIndicator(
          onRefresh: _fetchMyRank,
          color: Color(0xFFFF9F80),
          child: ListView.separated(
            itemCount: participatingUsers.length,
            itemBuilder: (context, index) {
              final doc = participatingUsers[index];
              final data = doc.data() as Map<String, dynamic>;

              // Cloud Function이 저장한 'rank' 필드를 사용
              final rank = data['rank'] as int? ?? (index + 1); // rank 필드 없으면 index로 대체
              final userEmail = doc.id; // leaderboard 문서 ID가 userEmail이어야 함
              final isCurrentUser = (userEmail.isNotEmpty && userEmail == _currentUserEmail);

              return _buildRankListItem(
                rank: rank,
                nickname: data['nickname'] ?? 'Unknown',
                exp: (data[expField] as num?)?.toInt() ?? 0, // 'weeklyExp' 또는 'monthlyExp'
                isCurrentUser: isCurrentUser,
              );
            },
            separatorBuilder: (context, index) => Divider(height: 1, indent: 16, endIndent: 16, color: Colors.grey[200]),
          ),
        );
      },
    );
  }


  // (수정 없음) _buildRankListItem 함수
  Widget _buildRankListItem({required int rank, required String nickname, required int exp, bool isCurrentUser = false}) {
    IconData rankIcon;
    Color rankColor;
    double iconSize = 24;
    Widget rankWidget; // 랭크 표시 위젯 분리

    switch (rank) {
      case 0: // 랭크 0 (순위권 밖)
        rankWidget = Text(
          '-', // 순위권 밖 표시
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        );
        break;
      case 1:
        rankIcon = Icons.emoji_events;
        rankColor = Colors.amber.shade700;
        rankWidget = Icon(rankIcon, color: rankColor, size: 24);
        break;
      case 2:
        rankIcon = Icons.emoji_events;
        rankColor = Colors.grey.shade500;
        rankWidget = Icon(rankIcon, color: rankColor, size: 24);
        break;
      case 3:
        rankIcon = Icons.emoji_events;
        rankColor = Colors.brown.shade400;
        rankWidget = Icon(rankIcon, color: rankColor, size: 24);
        break;
      default: // 4위 이하
        rankWidget = Text(
          rank.toString(),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
          textAlign: TextAlign.center,
        );
    }

    return ListTile(
      dense: true,
      leading: Container(
        width: 40,
        alignment: Alignment.center,
        child: rankWidget, // 랭크 위젯 사용
      ),
      title: Text(
        nickname,
        style: TextStyle(
          fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
          fontSize: 15,
          color: Colors.black87,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        '${_formatter.format(exp)} EXP',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: Color(0xFFEF6C00),
        ),
      ),
    );
  }
}


// (수정 없음)
class _SyntheticDocumentSnapshot implements DocumentSnapshot {
  final Map<String, dynamic> _data;
  _SyntheticDocumentSnapshot(this._data);

  @override
  dynamic get(Object field) => _data[field as String];

  @override
  Map<String, dynamic> data() => _data;

  @override
  bool get exists => true;

  @override
  String get id => _data['nickname'] ?? 'current_user';

  @override
  SnapshotMetadata get metadata => _SyntheticMetadata();

  @override
  DocumentReference<Object?> get reference => throw UnimplementedError("Synthetic document has no reference");

  @override
  dynamic operator [](Object field) => _data[field as String];
}

class _SyntheticMetadata implements SnapshotMetadata {
  @override
  bool get hasPendingWrites => false;
  @override
  bool get isFromCache => false;
}