import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class RankingHistoryPopup extends StatefulWidget {
  const RankingHistoryPopup({Key? key}) : super(key: key);

  @override
  _RankingHistoryPopupState createState() => _RankingHistoryPopupState();
}

class _RankingHistoryPopupState extends State<RankingHistoryPopup> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NumberFormat _formatter = NumberFormat('#,###');

  bool _isLoading = true;
  String? _errorMessage;

  // 랭킹 데이터
  List<Map<String, dynamic>> _previousWeekWinners = [];
  List<Map<String, dynamic>> _previousMonthWinners = [];
  List<Map<String, dynamic>> _myHallOfFame = []; // 내 명예의 전당 (월간 1~3위)

  @override
  void initState() {
    super.initState();
    _loadAllHistory();
  }

  // ✅✅✅ [수정됨] _loadAllHistory 함수 ✅✅✅
  Future<void> _loadAllHistory() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final user = _auth.currentUser;
    final userEmail = user?.email;

    try {
      // 3가지 데이터를 병렬로 가져오기
      final results = await Future.wait([
        // 1. 지난주 Top 3
        _firestore.collection('metadata').doc('previousWeekWinners').get(),
        // 2. 지난달 Top 3
        _firestore.collection('metadata').doc('previousMonthWinners').get(),
        // 3. 내 명예의 전당 (로그인 상태일 때만)
        if (userEmail != null)
          _firestore.collection('users').doc(userEmail).get()
        else
          Future.value(null), // 로그인 안했으면 null 반환
      ]);

      if (!mounted) return;

      // --- 1. 지난주 Top 3 처리 ---
      final weekDoc = results[0] as DocumentSnapshot;
      // ✅ [수정] data()를 Map 타입으로 명시적으로 변환
      final weekData = weekDoc.data() as Map<String, dynamic>?;
      if (weekData != null && weekData.containsKey('winners') && weekData['winners'] is List) {
        // ✅ [수정] 타입 변환된 weekData 변수 사용
        _previousWeekWinners = List<Map<String, dynamic>>.from(weekData['winners']);
      }

      // --- 2. 지난달 Top 3 처리 ---
      final monthDoc = results[1] as DocumentSnapshot;
      // ✅ [수정] data()를 Map 타입으로 명시적으로 변환
      final monthData = monthDoc.data() as Map<String, dynamic>?;
      if (monthData != null && monthData.containsKey('winners') && monthData['winners'] is List) {
        // ✅ [수정] 타입 변환된 monthData 변수 사용
        _previousMonthWinners = List<Map<String, dynamic>>.from(monthData['winners']);
      }

      // --- 3. 내 명예의 전당 처리 --- (수정 없음)
      final userDoc = results[2] as DocumentSnapshot?;
      if (userDoc != null && userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data() as Map<String, dynamic>;
        if (data['hallOfFame'] != null && data['hallOfFame'] is List) {
          _myHallOfFame = List<Map<String, dynamic>>.from(
              (data['hallOfFame'] as List).map((item) => Map<String, dynamic>.from(item))
          );
          // 최신순으로 정렬
          _myHallOfFame.sort((a, b) => (b['month'] as String? ?? '').compareTo(a['month'] as String? ?? ''));
        }
      }

    } catch (e) {
      print("랭킹 기록 로딩 실패: $e");
      if (mounted) _errorMessage = "기록을 불러오는 중 오류가 발생했습니다.";
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      contentPadding: EdgeInsets.zero,
      // 팝업 컨텐츠
      content: Container(
        width: double.maxFinite,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        child: _buildContent(),
      ),
      // 닫기 버튼
      actionsAlignment: MainAxisAlignment.center,
      actionsPadding: const EdgeInsets.only(bottom: 8, top: 0),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('닫기', style: TextStyle(color: Color(0xFFFF9F80), fontWeight: FontWeight.bold, fontSize: 16)),
        ),
      ],
    );
  }

  // 팝업 내부 컨텐츠 빌드
  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(32.0),
        child: CircularProgressIndicator(color: Color(0xFFFF9F80)),
      ));
    }
    if (_errorMessage != null) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Text(_errorMessage!, style: TextStyle(color: Colors.redAccent)),
      ));
    }

    final bool noData = _previousWeekWinners.isEmpty && _previousMonthWinners.isEmpty && _myHallOfFame.isEmpty;

    if (noData) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.hourglass_empty, size: 40, color: Colors.grey),
              SizedBox(height: 10),
              Text('아직 집계된 랭킹 기록이 없습니다.', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    final bool showDivider = _myHallOfFame.isNotEmpty && (_previousWeekWinners.isNotEmpty || _previousMonthWinners.isNotEmpty);

    return ListView(
      shrinkWrap: true,
      children: [
        // --- 1. 내 명예의 전당 (월간 1~3위 기록) ---
        _buildMyHallOfFameSection(),

        // --- 구분선 ---
        if (showDivider)
          const Divider(height: 16, indent: 16, endIndent: 16, thickness: 1),

        // --- 2. 지난주 Top 3 ---
        _buildWinnersSection(
          title: "지난주 랭킹 Top 3",
          winners: _previousWeekWinners,
          icon: Icons.leaderboard_outlined,
        ),

        // --- 3. 지난달 Top 3 ---
        _buildWinnersSection(
          title: "지난달 랭킹 Top 3",
          winners: _previousMonthWinners,
          icon: Icons.calendar_month_outlined,
        ),
      ],
    );
  }

  // (AchievementsPopup의 _buildWinnersSection 재활용)
  Widget _buildWinnersSection({
    required String title,
    required List<Map<String, dynamic>> winners,
    required IconData icon,
  }) {
    if (winners.isEmpty) return Container();

    final List<Map<String, dynamic>> rankDetails = [
      {'icon': Icons.emoji_events, 'color': Colors.amber.shade700},
      {'icon': Icons.emoji_events, 'color': Colors.grey.shade500},
      {'icon': Icons.emoji_events, 'color': Colors.brown.shade400},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Icon(icon, color: Colors.black87, size: 20),
              SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ],
          ),
        ),
        ...winners.asMap().entries.map((entry) {
          int index = entry.key;
          Map<String, dynamic> winner = entry.value;
          String nickname = winner['nickname'] ?? 'Unknown';
          int exp = (winner['exp'] as num?)?.toInt() ?? 0;
          if (index >= rankDetails.length) return Container();
          return ListTile(
            dense: true,
            leading: Icon(rankDetails[index]['icon'], color: rankDetails[index]['color'], size: 30),
            title: Text(nickname, style: TextStyle(fontWeight: FontWeight.w500)),
            trailing: Text(
              '${_formatter.format(exp)} EXP',
              style: TextStyle(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w500),
            ),
          );
        }).toList(),
      ],
    );
  }

  // (OtherUserProfileScreen의 _buildHallOfFameListItem 재활용)
  Widget _buildMyHallOfFameSection() {
    if (_myHallOfFame.isEmpty) return Container();

    final Map<int, Map<String, dynamic>> rankDetails = {
      1: {'icon': Icons.emoji_events, 'color': Colors.amber.shade700},
      2: {'icon': Icons.emoji_events, 'color': Colors.grey.shade500},
      3: {'icon': Icons.emoji_events, 'color': Colors.brown.shade400},
    };
    final defaultDetail = {'icon': Icons.military_tech_outlined, 'color': Colors.grey.shade400};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Icon(Icons.shield_outlined, color: Colors.black87, size: 20),
              SizedBox(width: 8),
              Text(
                "내 명예의 전당 (월간 1-3위)",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ],
          ),
        ),
        ..._myHallOfFame.map((entry) {
          final rank = (entry['rank'] as num?)?.toInt() ?? 0;
          final month = entry['month'] as String? ?? '????-??';
          final exp = (entry['exp'] as num?)?.toInt() ?? 0;
          final details = rankDetails[rank] ?? defaultDetail;

          return ListTile(
            dense: true,
            leading: Icon(details['icon'], color: details['color'], size: 30),
            title: Text('$month 월간 $rank위', style: TextStyle(fontWeight: FontWeight.w500)),
            trailing: Text(
              '${_formatter.format(exp)} EXP',
              style: TextStyle(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w500),
            ),
          );
        }).toList(),
      ],
    );
  }
}