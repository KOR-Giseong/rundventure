import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'event_challenge_detail_screen.dart'; // 상세 페이지 재사용
// ▼▼▼▼▼ [ ⭐️ 신규 추가 ⭐️ ] ▼▼▼▼▼
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rundventure/main_screens/main_screen.dart'; // 👈 홈 화면 임포트
// ▲▲▲▲▲ [ ⭐️ 신규 추가 ⭐️ ] ▲▲▲▲▲


// ▼▼▼▼▼ [ ⭐️ 수정: StatefulWidget으로 변경 ⭐️ ] ▼▼▼▼▼
class EndedEventChallengesScreen extends StatefulWidget {
  EndedEventChallengesScreen({Key? key}) : super(key: key);

  @override
  State<EndedEventChallengesScreen> createState() =>
      _EndedEventChallengesScreenState();
}

class _EndedEventChallengesScreenState
    extends State<EndedEventChallengesScreen> {
  // ▲▲▲▲▲ [ ⭐️ 수정: StatefulWidget으로 변경 ⭐️ ] ▲▲▲▲▲

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // ▼▼▼▼▼ [ ⭐️ 신규 추가 ⭐️ ] ▼▼▼▼▼
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isAdmin = false;
  // ▲▲▲▲▲ [ ⭐️ 신규 추가 ⭐️ ] ▲▲▲▲▲

  // ▼▼▼▼▼ [ ⭐️ 신규 추가: 관리자 확인 로직 ⭐️ ] ▼▼▼▼▼
  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) return;

    if (user.email == 'ghdrltjd244142@gmail.com') {
      if (mounted) setState(() => _isAdmin = true);
      return;
    }

    try {
      final userDoc =
      await _firestore.collection('users').doc(user.email!).get();
      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data()!;
        final role = data['role'] ?? 'user';
        if (mounted) {
          setState(() {
            _isAdmin = (role == 'super_admin' || role == 'general_admin');
          });
        }
      }
    } catch (e) {
      print("관리자 권한 확인 오류(EndedEvent): $e");
    }
  }
  // ▲▲▲▲▲ [ ⭐️ 신규 추가 ⭐️ ] ▲▲▲▲▲

  // 닉네임 마스킹 헬퍼 함수 (당첨자 표기용)
  String _maskNickname(String nickname) {
    if (nickname.isEmpty) return '알 수 없음';
    if (nickname.length <= 2) {
      return '${nickname.substring(0, 1)}*';
    } else if (nickname.length == 3) {
      return '${nickname.substring(0, 1)}*${nickname.substring(2, 3)}';
    } else {
      return '${nickname.substring(0, 2)}${'*' * (nickname.length - 3)}${nickname.substring(nickname.length - 1)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    // ▼▼▼▼▼ [ ⭐️ 신규 추가: 홈 버튼 위젯 ⭐️ ] ▼▼▼▼▼
    Widget homeButton = IconButton(
      icon: Icon(Icons.home_outlined, color: Colors.black),
      tooltip: '홈으로 이동',
      onPressed: () {
        // 홈 화면(MainScreen)으로 이동하고, 이전 스택 모두 제거
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => MainScreen()),
              (Route<dynamic> route) => false,
        );
      },
    );

    // ⭐️ 관리자용 '...' 버튼 (현재 이 화면에서는 특별한 기능이 없으므로 비활성화된 메뉴 표시)
    Widget adminEllipsisButton = PopupMenuButton<String>(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      icon: Icon(Icons.more_vert, color: Colors.black),
      itemBuilder: (BuildContext context) => [
        PopupMenuItem(
          value: 'info',
          enabled: false, // 👈 기능이 없으므로 비활성화
          child: Text('관리자 메뉴'),
        ),
      ],
    );
    // ▲▲▲▲▲ [ ⭐️ 신규 추가 ⭐️ ] ▲▲▲▲▲

    return Scaffold(
      backgroundColor: Colors.white, // 👈 배경 흰색으로 변경
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0, // 👈 그림자 제거
        centerTitle: true,
        // 👈 뒤로가기 버튼
        leading: IconButton(
          icon: Image.asset('assets/images/Back-Navs.png', width: 60, height: 60),
          onPressed: () => Navigator.pop(context),
          padding: const EdgeInsets.only(left: 10),
        ),
        title: Text(
          '종료된 이벤트 챌린지',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black
          ),
        ),
        // ▼▼▼▼▼ [ 🔴 여기가 수정된 부분입니다 🔴 ] ▼▼▼▼▼
        actions: _isAdmin
            ? [
          // 관리자: [홈 버튼] [ ... 버튼]
          homeButton,
          adminEllipsisButton,
        ]
            : [
          // 일반 사용자: [ (... 버튼 자리) ] [홈 버튼]
          // ... 버튼 자리를 빈 공간으로 채워 홈 버튼을 오른쪽 끝으로 민다.
          SizedBox(width: 48), // IconButton의 기본 너비
          homeButton,
        ],
        // ▲▲▲▲▲ [ 🔴 여기가 수정된 부분입니다 🔴 ] ▲▲▲▲▲
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('eventChallenges')
            .where('status', isEqualTo: 'ended') // 'ended' 상태인 것만
            .orderBy('endDate', descending: true) // 최근 종료 순으로
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_toggle_off,
                      size: 60, color: Colors.grey[400]),
                  SizedBox(height: 16),
                  Text(
                    '종료된 이벤트 챌린지가 없습니다.',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          final eventDocs = snapshot.data!.docs;

          return ListView.builder(
            padding: EdgeInsets.all(12.0),
            itemCount: eventDocs.length,
            itemBuilder: (context, index) {
              final doc = eventDocs[index];
              final data = doc.data() as Map<String, dynamic>;
              final eventId = doc.id;

              // 데이터 파싱
              final String name = data['name'] ?? '종료된 이벤트';
              final Timestamp endDate = data['endDate'] ?? Timestamp.now();
              final Map<String, dynamic> winners = data['winners'] ?? {};

              final String topRunnerNickname =
                  winners['topRunner']?['nickname'] ?? '집계 중...';
              final String luckyRunnerNickname =
                  winners['luckyRunner']?['nickname'] ?? '집계 중...';

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!) // 👈 옅은 테두리
                ),
                child: InkWell(
                  onTap: () {
                    // 상세 페이지로 이동 (재사용)
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            EventChallengeDetailScreen(eventChallengeId: eventId),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.calendar_today_outlined,
                                size: 14, color: Colors.grey[600]),
                            SizedBox(width: 6),
                            Text(
                              '종료일: ${DateFormat('yyyy.MM.dd').format(endDate.toDate())}',
                              style: TextStyle(
                                  fontSize: 14, color: Colors.grey[700]),
                            ),
                          ],
                        ),
                        Divider(height: 24, thickness: 0.5, color: Colors.grey[300]), // 👈 옅은 구분선
                        Text('🏆 1등: ${_maskNickname(topRunnerNickname)}',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w500)),
                        SizedBox(height: 6),
                        Text('🎉 행운: ${_maskNickname(luckyRunnerNickname)}',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}