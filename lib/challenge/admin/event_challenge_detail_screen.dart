import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
// ▼▼▼▼▼ [신규 추가] ▼▼▼▼▼
// 1. Cloud Functions를 사용하기 위해 임포트
import 'package:cloud_functions/cloud_functions.dart';
// ▲▲▲▲▲ [신규 추가] ▲▲▲▲▲
import '../../profile/other_user_profile.dart'; // OtherUserProfileScreen 임포트
// ▼▼▼▼▼ [ ⭐️ 신규 추가 ⭐️ ] ▼▼▼▼▼
import 'event_challenge_info_screen.dart'; // 👈 이벤트 상세 안내 페이지 임포트
// ▲▲▲▲▲ [ ⭐️ 신규 추가 ⭐️ ] ▲▲▲▲▲

class EventChallengeDetailScreen extends StatefulWidget {
  final String eventChallengeId;

  const EventChallengeDetailScreen(
      {Key? key, required this.eventChallengeId})
      : super(key: key);

  @override
  State<EventChallengeDetailScreen> createState() =>
      _EventChallengeDetailScreenState();
}

class _EventChallengeDetailScreenState
    extends State<EventChallengeDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions =
  FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  bool _isProcessingParticipation = false; // 참여/취소 중복 클릭 방지
  bool _isAdmin = false;
  String _currentUserEmail = '';
  bool _isDeleting = false; // 삭제 작업 중복 방지

  // 닉네임 마스킹 헬퍼 함수
  String _maskNickname(String nickname) {
    if (nickname.isEmpty) return '알 수 없음';
    if (nickname.length <= 2) {
      return '${nickname.substring(0, 1)}*';
    } else if (nickname.length == 3) {
      return '${nickname.substring(0, 1)}*${nickname.substring(2, 3)}';
    } else {
      // 4글자 이상
      return '${nickname.substring(0, 2)}${'*' * (nickname.length - 3)}${nickname.substring(nickname.length - 1)}';
    }
  }

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) return;

    _currentUserEmail = user.email!;

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
      print("관리자 권한 확인 오류(EventDetail): $e");
    }
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
        backgroundColor:
        isError ? Colors.redAccent.shade400 : Color(0xFFFF9F80),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(15, 5, 15, 15),
      ),
    );
  }

  // ▼▼▼▼▼ [ 🔴 여기가 수정된 부분입니다 🔴 ] ▼▼▼▼▼
  // 이벤트 참여/취소 로직 ('calculating' 상태 확인 추가)
  Future<void> _toggleParticipation(
      DocumentSnapshot eventDoc, bool hasJoined) async {
    if (_isProcessingParticipation) return;
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      _showCustomSnackBar('로그인이 필요합니다.', isError: true);
      return;
    }

    setState(() => _isProcessingParticipation = true);

    final String userEmail = user.email!;
    final eventData = eventDoc.data() as Map<String, dynamic>;
    final DocumentReference eventRef = eventDoc.reference;
    final String status = eventData['status'] ?? 'active'; // 👈 상태 확인

    // 1. 참여자용 하위 컬렉션 참조
    final DocumentReference participantRef =
    eventRef.collection('participants').doc(userEmail);

    // --- 참여 (Join) 로직 ---
    if (!hasJoined) {
      // 2. 조건 검사 (상태, 마감일, 인원)
      if (status == 'ended') {
        _showCustomSnackBar('이미 종료된 이벤트입니다.', isError: true);
        setState(() => _isProcessingParticipation = false);
        return;
      }
      if (status == 'calculating') {
        _showCustomSnackBar('현재 순위 집계 중으로 참여할 수 없습니다.', isError: true); // 👈 문구 수정
        setState(() => _isProcessingParticipation = false);
        return;
      }
      // 'active'일 때만 아래 로직 실행

      final Timestamp deadline =
      eventData['participationDeadlineDate'] as Timestamp;
      final int limit = eventData['participantLimit'] ?? 0;
      final int currentCount = eventData['participantCount'] ?? 0;

      if (DateTime.now().isAfter(deadline.toDate())) {
        _showCustomSnackBar('참여 신청 기간이 마감되었습니다.', isError: true);
        setState(() => _isProcessingParticipation = false);
        return;
      }

      if (limit > 0 && currentCount >= limit) {
        _showCustomSnackBar('선착순 인원이 마감되었습니다.', isError: true);
        setState(() => _isProcessingParticipation = false);
        return;
      }

      // 3. 트랜잭션으로 참여 처리 (동시성 문제 방지)
      try {
        await _firestore.runTransaction((transaction) async {
          // 최신 이벤트 데이터 다시 읽기
          final freshEventSnap = await transaction.get(eventRef);
          final freshEventData = freshEventSnap.data() as Map<String, dynamic>;
          final int freshCount = freshEventData['participantCount'] ?? 0;
          final String freshStatus = freshEventData['status'] ?? 'active';

          // 트랜잭션 도중 상태가 변경되었는지 다시 확인
          if (freshStatus != 'active') {
            throw Exception('이벤트가 방금 마감되거나 집계가 시작되었습니다.');
          }
          if (limit > 0 && freshCount >= limit) {
            throw Exception('선착순 인원이 방금 마감되었습니다.');
          }

          // 내 닉네임 정보 가져오기
          final userDoc =
          await _firestore.collection('users').doc(userEmail).get();
          final String nickname = userDoc.data()?['nickname'] ?? '알 수 없음';
          final String profileImg =
              userDoc.data()?['profileImageUrl'] ?? '';

          // 4. participants 하위 컬렉션에 내 정보 쓰기
          transaction.set(participantRef, {
            'email': userEmail,
            'nickname': nickname,
            'profileImageUrl': profileImg,
            'joinedAt': FieldValue.serverTimestamp(),
            'totalDistance': 0.0, // 참여도(거리) 초기화
          });

          // 5. eventChallenges 문서의 participantCount 1 증가
          transaction.update(eventRef, {
            'participantCount': FieldValue.increment(1),
          });
        });

        _showCustomSnackBar('이벤트 참여가 완료되었습니다. 지금부터 달린 거리가 집계됩니다!');
      } catch (e) {
        _showCustomSnackBar('참여 처리 중 오류: ${e.toString()}', isError: true);
      }
    }
    // --- 참여 취소 (Leave) 로직 ---
    else {
      // ❗️ [신규] 참여 취소도 'active'일 때만 가능
      if (status != 'active') {
        _showCustomSnackBar(
            status == 'calculating'
                ? '순위 집계 중에는 참여를 취소할 수 없습니다.' // 👈 문구 수정
                : '종료된 이벤트는 참여를 취소할 수 없습니다.',
            isError: true);
        setState(() => _isProcessingParticipation = false);
        return;
      }

      // 6. 참여 취소 확인 다이얼로그
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('참여 취소'),
          content: Text(
              '정말 참여를 취소하시겠습니까?\n취소 시 집계된 참여도(러닝 거리)가 모두 삭제되며, 선착순 인원이 다시 확보되지 않을 수 있습니다.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('닫기', style: TextStyle(color: Colors.grey[700]))),
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('참여 취소', style: TextStyle(color: Colors.red))),
          ],
        ),
      );

      if (confirm != true) {
        setState(() => _isProcessingParticipation = false);
        return;
      }

      // 7. 트랜잭션으로 참여 취소 처리
      try {
        await _firestore.runTransaction((transaction) async {
          // ❗️ [신규] 트랜잭션 내에서 상태 재확인
          final freshEventSnap = await transaction.get(eventRef);
          final String freshStatus = (freshEventSnap.data() as Map<String, dynamic>)['status'] ?? 'active';
          if (freshStatus != 'active') {
            throw Exception('참여 취소 중 이벤트가 마감되었습니다.');
          }

          // participants 하위 컬렉션에서 내 문서 삭제
          transaction.delete(participantRef);
          // eventChallenges 문서의 participantCount 1 감소
          transaction.update(eventRef, {
            'participantCount': FieldValue.increment(-1),
          });
        });
        _showCustomSnackBar('이벤트 참여가 취소되었습니다.');
      } catch (e) {
        _showCustomSnackBar('참여 취소 중 오류: $e', isError: true);
      }
    }

    if (mounted) setState(() => _isProcessingParticipation = false);
  }
  // ▲▲▲▲▲ [ 🔴 여기가 수정된 부분입니다 🔴 ] ▲▲▲▲▲

  // (수정 없음) 관리자용 컨트롤 함수 (토글)
  // 공개/비공개 토글
  Future<void> _toggleRankingPublic(DocumentSnapshot eventDoc) async {
    final bool currentStatus =
        (eventDoc.data() as Map<String, dynamic>)['isRankingPublic'] ?? true;
    try {
      await eventDoc.reference.update({'isRankingPublic': !currentStatus});
      _showCustomSnackBar(
          currentStatus ? '랭킹을 비공개로 설정했습니다.' : '랭킹을 공개로 설정했습니다.');
    } catch (e) {
      _showCustomSnackBar('설정 변경 실패: $e', isError: true);
    }
  }

  // (수정 없음) 이벤트 조기 종료 (백엔드가 'calculating'으로 변경하도록 endDate만 수정)
  Future<void> _endEventManually(DocumentSnapshot eventDoc) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('이벤트 조기 종료'),
        content: Text(
            '이벤트를 지금 즉시 종료하고 집계를 시작하시겠습니까?\n이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('취소', style: TextStyle(color: Colors.grey[700]))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('즉시 종료', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // 'endDate'만 '지금'으로 당겨서 백엔드 스케줄러(Part 1)가 집계하도록 합니다.
      await eventDoc.reference.update({
        'endDate': Timestamp.now(), // 👈 종료 시간만 지금으로 설정
      });
      _showCustomSnackBar('이벤트가 종료되었습니다. 10분 내로 집계가 시작됩니다.');
    } catch (e) {
      _showCustomSnackBar('종료 처리 실패: $e', isError: true);
    }
  }

  // (수정 없음) 이벤트 삭제 (Cloud Function 호출)
  Future<void> _deleteEvent(DocumentSnapshot eventDoc) async {
    if (_isDeleting) return; // 중복 실행 방지

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('이벤트 삭제'),
        content: Text(
            '정말 이 이벤트를 삭제하시겠습니까?\n모든 참여자 정보와 참여도 기록이 함께 삭제되며, 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('취소', style: TextStyle(color: Colors.grey[700]))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('삭제', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;

    if (mounted) setState(() => _isDeleting = true);

    try {
      // 3. Cloud Function 'deleteEventChallenge' 호출
      final HttpsCallable callable =
      _functions.httpsCallable('deleteEventChallenge');
      final result = await callable.call<Map<String, dynamic>>(
        {'eventId': eventDoc.id}, // 👈 eventId를 파라미터로 전달
      );

      if (mounted) {
        if (result.data['success'] == true) {
          _showCustomSnackBar('이벤트가 성공적으로 삭제되었습니다.');
          Navigator.pop(context); // 상세 페이지 닫기
        } else {
          _showCustomSnackBar(
              result.data['message'] ?? '삭제에 실패했습니다.', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        _showCustomSnackBar('삭제 요청 중 오류가 발생했습니다: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Image.asset('assets/images/Back-Navs.png', width: 60, height: 60),
          onPressed: () => Navigator.pop(context),
          padding: const EdgeInsets.only(left: 10),
        ),
        title: Text("이벤트 챌린지",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
        actions: [
          StreamBuilder<DocumentSnapshot>(
              stream: _firestore
                  .collection('eventChallenges')
                  .doc(widget.eventChallengeId)
                  .snapshots(),
              builder: (context, eventSnapshot) {
                if (!eventSnapshot.hasData || !eventSnapshot.data!.exists || !_isAdmin) {
                  return SizedBox.shrink(); // 관리자가 아니거나 데이터 없으면 숨김
                }
                final eventDoc = eventSnapshot.data!;
                final data = eventDoc.data() as Map<String, dynamic>;
                final bool isPublic = data['isRankingPublic'] ?? true;
                // ▼▼▼▼▼ [ 🔴 여기가 수정된 부분입니다 🔴 ] ▼▼▼▼▼
                final String status = data['status'] ?? 'active';
                // ▲▲▲▲▲ [ 🔴 여기가 수정된 부분입니다 🔴 ] ▲▲▲▲▲

                return _isDeleting
                    ? Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.black,
                        strokeWidth: 2,
                      )),
                )
                    : PopupMenuButton<String>(
                  color: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  icon: Icon(Icons.more_vert, color: Colors.black),
                  onSelected: (value) {
                    if (value == 'togglePublic') {
                      _toggleRankingPublic(eventDoc);
                    } else if (value == 'endEvent') {
                      _endEventManually(eventDoc);
                    } else if (value == 'deleteEvent') {
                      _deleteEvent(eventDoc);
                    }
                  },
                  // ▼▼▼▼▼ [ 🔴 여기가 수정된 부분입니다 🔴 ] ▼▼▼▼▼
                  itemBuilder: (BuildContext context) => [
                    PopupMenuItem(
                      value: 'togglePublic',
                      child: Text(
                          isPublic ? '랭킹 비공개로' : '랭킹 공개로'),
                    ),
                    if (status == 'active') // 👈 'active'일 때만 조기 종료 표시
                      PopupMenuItem(
                        value: 'endEvent',
                        child: Text('이벤트 조기 종료',
                            style: TextStyle(color: Colors.red)),
                      ),
                    if (status != 'calculating') // 👈 'calculating'이 아닐 때만 삭제 표시
                      PopupMenuItem(
                        value: 'deleteEvent',
                        child: Text('이벤트 삭제',
                            style: TextStyle(color: Colors.red)),
                      ),
                  ],
                  // ▲▲▲▲▲ [ 🔴 여기가 수정된 부분입니다 🔴 ] ▲▲▲▲▲
                );
              }
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore
            .collection('eventChallenges')
            .doc(widget.eventChallengeId)
            .snapshots(),
        builder: (context, eventSnapshot) {
          if (!eventSnapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }
          if (!eventSnapshot.data!.exists) {
            return Center(child: Text('삭제되었거나 존재하지 않는 이벤트입니다.'));
          }

          final eventDoc = eventSnapshot.data!;
          final data = eventDoc.data() as Map<String, dynamic>;

          // 데이터 파싱
          final String name = data['name'] ?? '이벤트 챌린지';
          final String slogan = data['slogan'] ?? '함께 달려요!';
          final Timestamp endDate =
              data['endDate'] ?? Timestamp.now();
          final Timestamp deadlineDate =
              data['participationDeadlineDate'] ?? Timestamp.now();
          final String rewardInfo = data['rewardInfo'] ?? '보상 정보 없음';
          final bool isPublic = data['isRankingPublic'] ?? true;
          // ▼▼▼▼▼ [ 🔴 여기가 수정된 부분입니다 🔴 ] ▼▼▼▼▼
          final String status = data['status'] ?? 'active';
          final bool isEnded = status == 'ended';
          final bool isCalculating = status == 'calculating';
          // ▲▲▲▲▲ [ 🔴 여기가 수정된 부분입니다 🔴 ] ▲▲▲▲▲

          final int daysLeft =
              endDate.toDate().difference(DateTime.now()).inDays;
          final bool canJoin =
              DateTime.now().isBefore(deadlineDate.toDate()) &&
                  status == 'active'; // 👈 'active' 상태일 때만 참여 가능

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.emoji_events_outlined, color: Colors.blueAccent, size: 36),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                slogan,
                                style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 24),

                  // ▼▼▼▼▼ [ 🔴 여기가 수정된 부분입니다 🔴 ] ▼▼▼▼▼
                  // 정보 카드 (isCalculating 전달)
                  _buildInfoCard(data, isEnded, isCalculating, daysLeft, canJoin),
                  // ▲▲▲▲▲ [ 🔴 여기가 수정된 부분입니다 🔴 ] ▲▲▲▲▲

                  // 참여 버튼
                  SizedBox(height: 24),
                  // ▼▼▼▼▼ [ 🔴 여기가 수정된 부분입니다 🔴 ] ▼▼▼▼▼
                  _buildParticipationButton(eventDoc, canJoin, status), // 👈 status 전달
                  // ▲▲▲▲▲ [ 🔴 여기가 수정된 부분입니다 🔴 ] ▲▲▲▲▲

                  // 보상 안내
                  SizedBox(height: 24),
                  _buildSectionCard(
                    title: '🎁 이벤트 보상',
                    child: Text(
                      rewardInfo,
                      style: TextStyle(fontSize: 15, height: 1.5, color: Colors.grey[800]),
                    ),
                  ),

                  // ▼▼▼▼▼ [ 🔴 여기가 수정된 부분입니다 🔴 ] ▼▼▼▼▼
                  // 당첨자 안내 (종료된 경우)
                  if (isEnded) // 👈 'ended'일 때만 표시 ('calculating'일 땐 숨김)
                    _buildWinnersCard(data),
                  // ▲▲▲▲▲ [ 🔴 여기가 수정된 부분입니다 🔴 ] ▲▲▲▲▲

                  // 랭킹 (공개 설정된 경우)
                  if (isPublic || _isAdmin)
                    _buildRankingSection(eventDoc.reference, isPublic, isCalculating), // 👈 isCalculating 전달

                  SizedBox(height: 20), // 하단 여백

                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ▼▼▼▼▼ [ 🔴 여기가 수정된 부분입니다 🔴 ] ▼▼▼▼▼
  // 정보 카드 위젯 (isCalculating 추가)
  Widget _buildInfoCard(Map<String, dynamic> data, bool isEnded,
      bool isCalculating, int daysLeft, bool canJoin) {
    // ▲▲▲▲▲ [ 🔴 여기가 수정된 부분입니다 🔴 ] ▲▲▲▲▲
    final int limit = data['participantLimit'] ?? 0;
    final int count = data['participantCount'] ?? 0;
    final int duration = data['duration'] ?? 0;
    final int deadlineDays = data['participationDeadlineDays'] ?? 0;
    final Timestamp startDate = data['timestamp'] ?? Timestamp.now();
    final Timestamp endDate = data['endDate'] ?? Timestamp.now();

    final DateFormat formatter = DateFormat('yyyy.MM.dd');

    return _buildSectionCard(
      title: '이벤트 정보',
      titleTrailingWidget: IconButton(
        icon: Icon(Icons.info_outline_rounded, color: Colors.blueAccent),
        tooltip: '이벤트 상세 안내',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EventChallengeInfoScreen(), // 👈 새 페이지로 이동
            ),
          );
        },
      ),
      child: Column(
        children: [
          // ▼▼▼▼▼ [ 🔴 여기가 수정된 부분입니다 🔴 ] ▼▼▼▼▼
          // 1. 이벤트 상태 행 추가
          _infoRow(
            isCalculating
                ? Icons.sync // 집계 중 아이콘
                : (isEnded
                ? Icons.check_circle_outline // 종료 아이콘
                : Icons.run_circle_outlined), // 진행 중 아이콘
            '이벤트 상태',
            isCalculating
                ? '순위 집계 중' // 👈 [수정] (약 1시간 소요) 삭제
                : (isEnded ? '종료됨' : '진행 중'), // 종료/진행 텍스트
            highlight: isCalculating, // '집계 중'일 때 강조
          ),
          // 2. 기존 행들 (폰트 사이즈 수정 가능하도록 valueFontSize 추가)
          _infoRow(Icons.calendar_today_outlined, '이벤트 기간',
              '${formatter.format(startDate.toDate())} ~ ${formatter.format(endDate.toDate())} ($duration일)',
              valueFontSize: 13.0), // 👈 여기서 크기 조절 (기본값은 15.0)
          _infoRow(
              Icons.people_alt_outlined,
              '참여 인원',
              limit > 0
                  ? '$count / $limit 명'
                  : '$count 명'),
          // 3. 남은 기간 (집계 중 반영)
          _infoRow(
              Icons.hourglass_bottom_outlined,
              '남은 기간',
              isEnded
                  ? '종료됨'
                  : (isCalculating
                  ? '순위 집계 중' // 👈 [수정]
                  : (daysLeft >= 0 ? 'D-$daysLeft' : '종료됨'))),
          // 4. 참여 마감 (집계 중 반영)
          _infoRow(
              Icons.timer_off_outlined,
              '참여 마감',
              isEnded
                  ? '마감됨'
                  : (isCalculating
                  ? '순위 집계 중' // 👈 [수정]
                  : (canJoin
                  ? '종료 $deadlineDays일 전 (${formatter.format(data['participationDeadlineDate'].toDate())})'
                  : '마감됨')),
              highlight: !canJoin && !isEnded && !isCalculating),
          // ▲▲▲▲▲ [ 🔴 여기가 수정된 부분입니다 🔴 ] ▲▲▲▲▲
        ],
      ),
    );
  }

  // (수정 없음) 참여 버튼 위젯 (status 받도록 수정)
  Widget _buildParticipationButton(
      DocumentSnapshot eventDoc, bool canJoin, String status) {
    // 참여자인지 확인하기 위한 StreamBuilder
    return StreamBuilder<DocumentSnapshot>(
      stream: eventDoc.reference
          .collection('participants')
          .doc(_currentUserEmail)
          .snapshots(),
      builder: (context, snapshot) {
        final bool hasJoined = snapshot.hasData && snapshot.data!.exists;

        // 상태별 버튼 텍스트 및 활성화
        String buttonText = '';
        bool isEnabled = false;

        if (status == 'ended') {
          buttonText = '종료된 이벤트입니다';
        } else if (status == 'calculating') {
          buttonText = '순위 집계 중...';
        } else if (hasJoined) { // 'active'
          buttonText = '참여 취소하기';
          isEnabled = true; // 언제든 취소는 가능
        } else if (canJoin) { // 'active'
          buttonText = '참여하기';
          isEnabled = true;
        } else { // 'active' & !canJoin (마감)
          buttonText = '참여 마감되었습니다';
        }

        return ElevatedButton(
          onPressed: (isEnabled && !_isProcessingParticipation)
              ? () => _toggleParticipation(eventDoc, hasJoined)
              : null,
          child: _isProcessingParticipation
              ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2))
              : Text(
            buttonText,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: hasJoined ? Colors.grey[700] : Colors.blueAccent,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            minimumSize: Size(double.infinity, 50), // 가로 꽉 채우기
            disabledBackgroundColor: Colors.grey[300],
          ),
        );
      },
    );
  }

  // (수정 없음) 당첨자 카드 위젯 (종료 시)
  Widget _buildWinnersCard(Map<String, dynamic> data) {
    final Map<String, dynamic> winners = data['winners'] ?? {};
    final String? topRunnerEmail = winners['topRunner']?['email'];
    final String? topRunnerNickname = winners['topRunner']?['nickname'];
    final double topRunnerDistance = winners['topRunner']?['distance'] ?? 0.0;

    final String? luckyRunnerEmail = winners['luckyRunner']?['email'];
    final String? luckyRunnerNickname = winners['luckyRunner']?['nickname'];
    final double luckyRunnerDistance = winners['luckyRunner']?['distance'] ?? 0.0;

    // 당첨자 집계가 아직 안됐으면 (status: ended인데 winners: null인 경우)
    if (topRunnerEmail == null || luckyRunnerEmail == null) {
      return _buildSectionCard(
        title: '🏆 당첨자 발표',
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Center(
            child: Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 10),
                Text('순위 정보를 불러오는 중입니다...'),
              ],
            ),
          ),
        ),
      );
    }

    return _buildSectionCard(
      title: '🏆 당첨자 발표',
      child: Column(
        children: [
          Text('축하합니다! 당첨자에게는 관리자가 이메일로 상품을 지급할 예정입니다.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[700])),
          SizedBox(height: 16),
          ListTile(
            leading:
            Icon(Icons.military_tech, color: Colors.amber[700], size: 30),
            title: Text('참여도 1등 (Top Runner)',
                style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
                '${_maskNickname(topRunnerNickname!)} (${topRunnerDistance.toStringAsFixed(2)}km)'),
          ),
          ListTile(
            leading: Icon(Icons.shuffle, color: Colors.green[600], size: 30),
            title: Text('랜덤 추첨 (Lucky Runner)',
                style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
                '${_maskNickname(luckyRunnerNickname!)} (${luckyRunnerDistance.toStringAsFixed(2)}km)'),
          ),
        ],
      ),
    );
  }

  // ▼▼▼▼▼ [ 🔴 여기가 수정된 부분입니다 🔴 ] ▼▼▼▼▼
  // 랭킹 섹션 위젯 (isCalculating 추가)
  Widget _buildRankingSection(DocumentReference eventRef, bool isPublic, bool isCalculating) {
    return _buildSectionCard(
      title: '📊 참여도 랭킹',
      child: Column(
        children: [
          // '집계 중'일 때 랭킹 숨김 처리
          if (isCalculating && !_isAdmin)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.sync, // 집계 중 아이콘
                        color: Colors.grey[600], size: 30),
                    SizedBox(height: 8),
                    Text(
                      '이벤트가 종료되어 순위 집계 중입니다.\n잠시 후 순위 및 당첨자가 공개됩니다.', // 👈 [수정] (약 1시간 후) 삭제
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
            )
          // 랭킹이 비공개일 때 (집계 중이 아닐 때)
          else if (!_isAdmin && !isPublic)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.visibility_off_outlined,
                        color: Colors.grey[600], size: 30),
                    SizedBox(height: 8),
                    Text(
                      '랭킹이 비공개로 설정되었습니다.\n이벤트 종료 후 당첨자를 확인해주세요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
            )
          else // 관리자거나 공개일 때 (집계 중이어도 관리자는 랭킹 확인 가능)
            StreamBuilder<QuerySnapshot>(
              // participants 하위 컬렉션에서 'totalDistance' 순으로 정렬
              stream: eventRef
                  .collection('participants')
                  .orderBy('totalDistance', descending: true)
                  .limit(100) // 100명까지만 표시
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Padding( // 👈 [디자인 수정] 로딩 시 패딩 추가
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.data!.docs.isEmpty) {
                  return Padding( // 👈 [디자인 수정] 비어있을 때 패딩 추가
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Center(child: Text('아직 참여자가 없습니다.', style: TextStyle(color: Colors.grey[600]))),
                  );
                }

                final participants = snapshot.data!.docs;

                // 👈 [디자인 수정] ListView 대신 Column + ListTile 사용 (스크롤 충돌 없음)
                return Column(
                  children: List.generate(participants.length, (index) {
                    final data =
                    participants[index].data() as Map<String, dynamic>;
                    final String nickname = data['nickname'] ?? '알 수 없음';
                    final String email = data['email'] ?? '';
                    final double distance =
                    (data['totalDistance'] as num? ?? 0.0).toDouble();

                    return ListTile(
                      contentPadding: EdgeInsets.symmetric(horizontal: 4.0), // 👈 [디자인 수정]
                      leading: Text(
                        '${index + 1}',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: index < 3
                                ? Colors.blueAccent
                                : Colors.grey[800]),
                      ),
                      title: GestureDetector(
                        onTap: () {
                          // 관리자만 다른 사람 프로필 볼 수 있게 (선택적)
                          if (_isAdmin && email.isNotEmpty) {
                            final encodedEmail = email
                                .replaceAll('@', '_at_')
                                .replaceAll('.', '_dot_');
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        OtherUserProfileScreen(
                                            userEmail: encodedEmail)));
                          }
                        },
                        child: Text(
                          // 관리자는 실명, 사용자는 마스킹된 닉네임
                          _isAdmin ? nickname : _maskNickname(nickname),
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      trailing: Text(
                        '${distance.toStringAsFixed(2)} km',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87),
                      ),
                    );
                  }),
                );
              },
            ),
        ],
      ),
    );
  }
  // ▲▲▲▲▲ [ 🔴 여기가 수정된 부분입니다 🔴 ] ▲▲▲▲▲

  // (수정 없음) 공통 섹션 카드 UI (titleTrailingWidget 추가)
  Widget _buildSectionCard({
    required String title,
    Widget? titleTrailingWidget, // 👈 [신규] 타이틀 옆에 붙을 위젯
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8.0), // 👈 상단 마진 줄임
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
          color: Colors.white, // 👈 흰색 배경
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!) // 👈 옅은 테두리
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                title,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black), // 👈 검은색
              ),
              if (titleTrailingWidget != null) titleTrailingWidget, // 👈 [신규]
            ],
          ),
          Divider(height: 24, thickness: 0.5, color: Colors.grey[300]), // 👈 옅은 구분선
          child,
        ],
      ),
    );
  }

  // (수정됨) 공통 정보 행 UI
  Widget _infoRow(IconData icon, String title, String value,
      {bool highlight = false, double valueFontSize = 15.0}) { // 👈 valueFontSize 추가 (기본 15)
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center, // 👈 Center로 변경
        children: [
          Icon(icon, color: Colors.grey[600], size: 20),
          SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(fontSize: 15, color: Colors.grey[700]),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: valueFontSize, // 👈 여기서 크기 조절
                fontWeight: FontWeight.w600, // 👈 Semi-bold
                color: highlight ? Colors.red.shade600 : Colors.black87, // 👈 색상 변경
              ),
            ),
          ),
        ],
      ),
    );
  }
}