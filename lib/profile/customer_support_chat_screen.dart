import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

// ▼▼▼▼▼▼▼▼▼▼ [추가된 부분] ▼▼▼▼▼▼▼▼▼▼
// MainScreen의 실제 경로에 맞게 수정해야 할 수 있습니다.
// (이전 파일들을 기반으로 경로를 추측했습니다.)
import 'package:rundventure/main_screens/main_screen.dart';
// ▲▲▲▲▲▲▲▲▲▲ [추가된 부분] ▲▲▲▲▲▲▲▲▲▲


class CustomerSupportChatScreen extends StatefulWidget {
  const CustomerSupportChatScreen({Key? key}) : super(key: key);

  @override
  _CustomerSupportChatScreenState createState() =>
      _CustomerSupportChatScreenState();
}

class _CustomerSupportChatScreenState extends State<CustomerSupportChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ScrollController _scrollController = ScrollController();

  String? _userEmail;
  String _userNickname = '나';
  bool _hasAgreed = false;
  bool _isLoading = true;

  // 타이핑 및 읽음 상태 관리를 위한 변수
  Timer? _typingTimer;
  bool _isAdminTyping = false;
  bool _isReadByAdmin = true; // 기본값 true
  Stream<DocumentSnapshot>? _summaryStream;

  @override
  void initState() {
    super.initState();
    _userEmail = _auth.currentUser?.email;
    _checkChatStatusAndLoadNickname();

    // 타이핑 감지 리스너 추가
    _messageController.addListener(_onTyping);
  }

  Future<void> _checkChatStatusAndLoadNickname() async {
    if (_userEmail == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final userDocFuture = _firestore.collection('users').doc(_userEmail).get();
      final chatDocFuture =
      _firestore.collection('supportChats').doc(_userEmail).get();

      final responses = await Future.wait([userDocFuture, chatDocFuture]);

      final userDoc = responses[0] as DocumentSnapshot;
      final chatDoc = responses[1] as DocumentSnapshot;

      if (userDoc.exists && userDoc.data() != null) {
        _userNickname = (userDoc.data()! as Map)['nickname'] ?? '나';
      }

      bool isChatClosed = true;
      if (chatDoc.exists && chatDoc.data() != null) {
        isChatClosed = (chatDoc.data()! as Map)['isChatClosed'] ?? true;
      }

      if (mounted) {
        setState(() {
          _userNickname = _userNickname;
          _hasAgreed = !isChatClosed;
          _isLoading = false;
          // 스트림 초기화
          _summaryStream =
              _firestore.collection('supportChats').doc(_userEmail).snapshots();
        });

        // 채팅방에 들어왔으므로 '읽음'으로 표시
        _markAsReadByUser();
      }
    } catch (e) {
      print("사용자 정보 또는 채팅 상태 로드 실패: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTyping); // 리스너 제거
    _typingTimer?.cancel(); // 타이머 취소
    // 화면 나갈 때 타이핑 상태 false로 변경
    if (_userEmail != null) {
      _firestore.collection('supportChats').doc(_userEmail).set({
        'isUserTyping': false,
      }, SetOptions(merge: true));
    }
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // 타이핑 이벤트 핸들러
  void _onTyping() {
    // 동의(채팅 시작)를 해야만 타이핑 전송
    if (_userEmail == null || !_hasAgreed) return;

    // 즉시 타이핑 상태를 true로 설정
    _firestore.collection('supportChats').doc(_userEmail).set({
      'isUserTyping': true,
    }, SetOptions(merge: true));

    // 기존 타이머가 있다면 취소
    _typingTimer?.cancel();

    // 2초 후에 타이핑 상태를 false로 변경하는 타이머 설정
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (_userEmail == null) return;
      _firestore.collection('supportChats').doc(_userEmail).set({
        'isUserTyping': false,
      }, SetOptions(merge: true));
    });
  }

  // 사용자가 채팅방을 읽었음을 표시
  Future<void> _markAsReadByUser() async {
    if (_userEmail == null) return;
    await _firestore.collection('supportChats').doc(_userEmail).set({
      'isReadByUser': true,
    }, SetOptions(merge: true));
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _userEmail == null) {
      return;
    }

    _typingTimer?.cancel(); // 메시지 전송 시 타이머 취소
    final messageTimestamp = FieldValue.serverTimestamp();
    _messageController.clear();

    await _firestore
        .collection('supportChats')
        .doc(_userEmail)
        .collection('messages')
        .add({
      'text': text,
      'timestamp': messageTimestamp,
      'senderEmail': _userEmail,
      'isUser': true,
      'nickname': _userNickname,
    });

    await _firestore.collection('supportChats').doc(_userEmail).set({
      'lastMessage': text,
      'lastUpdated': messageTimestamp,
      'userEmail': _userEmail,
      'userNickname': _userNickname,
      'isReadByAdmin': false, // 관리자가 아직 안 읽음
      'isChatClosed': false,
      'isUserTyping': false, // 타이핑 상태 false
      'isReadByUser': true, // 내가 보냈으니 나는 읽음
    }, SetOptions(merge: true));

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.minScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leadingWidth: 70,
        leading: Padding(
          padding: const EdgeInsets.only(left: 20.0),
          child: IconButton(
            icon: Image.asset('assets/images/Back-Navs.png',
                width: 45, height: 45),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ),
        title: const Text('1:1 문의하기',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black)),
        titleSpacing: 0,
        // ▼▼▼▼▼▼▼▼▼▼ [수정된 부분] ▼▼▼▼▼▼▼▼▼▼
        actions: [
          Padding(
            // 뒤로가기 버튼의 왼쪽 여백(left: 20.0)과 동일하게 오른쪽 여백을 줌
            padding: const EdgeInsets.only(right: 20.0),
            child: IconButton(
              icon: Icon(
                Icons.home_outlined,
                color: Colors.black, // 제목과 색상 통일
                size: 28, // 아이콘 크기 (뒤로가기 버튼과 비슷하게)
              ),
              onPressed: () {
                // 모든 이전 화면을 스택에서 제거하고 MainScreen으로 이동
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    // 환영 메시지는 다시 표시하지 않음
                    builder: (context) => const MainScreen(showWelcomeMessage: false),
                  ),
                      (Route<dynamic> route) => false, // 모든 경로 제거
                );
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
        ],
        // ▲▲▲▲▲▲▲▲▲▲ [수정된 부분] ▲▲▲▲▲▲▲▲▲▲
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _buildChatUI(),
    );
  }

  Widget _buildChatUI() {
    return Column(
      children: [
        // 채팅방 상태(요약) StreamBuilder로 Expanded 감싸기
        Expanded(
          child: StreamBuilder<DocumentSnapshot>(
            stream: _summaryStream,
            builder: (context, summarySnapshot) {
              // 요약 데이터에서 타이핑 및 읽음 상태 업데이트
              if (summarySnapshot.hasData && summarySnapshot.data!.exists) {
                final summaryData =
                    summarySnapshot.data!.data() as Map<String, dynamic>? ?? {};
                _isAdminTyping = summaryData['isAdminTyping'] ?? false;
                _isReadByAdmin = summaryData['isReadByAdmin'] ?? true;
              }

              // 기존 메시지 스트림 빌더 (내부에 중첩)
              return _userEmail == null
                  ? Center(child: Text('로그인이 필요합니다.'))
                  : StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('supportChats')
                    .doc(_userEmail)
                    .collection('messages')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState ==
                      ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text("오류가 발생했습니다."));
                  }

                  final docs = snapshot.data?.docs ?? [];
                  final bool hasMessages = docs.isNotEmpty;

                  Future.delayed(
                      Duration(milliseconds: 100), _scrollToBottom);

                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.all(16.0),
                    // itemCount + 2 (안내메시지 + 타이핑 인디케이터)
                    itemCount: docs.length + 2,
                    itemBuilder: (context, index) {
                      // 1. 안내 메시지 (가장 위)
                      if (index == docs.length + 1) {
                        if (!hasMessages) {
                          return _buildSystemMessage(
                              '무엇을 도와드릴까요?\n문의 내용을 입력하시면 관리자가 확인 후 답변드립니다.',
                              icon: Icons.support_agent);
                        }
                        return _buildSystemMessage(
                          '운영 시간: 평일 09:00 - 18:00 (주말/공휴일 휴무)',
                          icon: Icons.info_outline,
                        );
                      }

                      // 2. 타이핑 인디케이터 (메시지 목록 바로 위)
                      if (index == docs.length) {
                        return _isAdminTyping
                            ? _buildTypingIndicator('관리자')
                            : SizedBox.shrink();
                      }

                      // 3. 메시지 버블 (+ 날짜 구분선)
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;

                      // 마지막 메시지인지 확인
                      final bool isLastMessage = (index == 0);

                      // 날짜 구분선 로직
                      bool showDateSeparator = false;
                      final dynamic currentTimestamp = data['timestamp'];

                      if (currentTimestamp is Timestamp) {
                        if (index == docs.length - 1) {
                          // 가장 오래된 메시지 (리스트의 끝)
                          showDateSeparator = true;
                        } else {
                          // 다음 메시지(더 오래된 메시지)와 날짜 비교
                          final previousDoc = docs[index + 1];
                          final dynamic previousTimestamp =
                          (previousDoc.data()
                          as Map<String, dynamic>)[
                          'timestamp'];

                          if (previousTimestamp is Timestamp) {
                            if (_isDifferentDay(
                                currentTimestamp, previousTimestamp)) {
                              showDateSeparator = true;
                            }
                          }
                        }
                      }

                      return Column(
                        children: [
                          // 날짜 구분선 표시
                          if (showDateSeparator &&
                              currentTimestamp is Timestamp)
                            _buildDateSeparator(currentTimestamp),

                          _buildChatBubble(
                            data,
                            isLastMessage: isLastMessage,
                            isReadByAdmin: _isReadByAdmin,
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
        ),

        // 동의 위젯
        if (!_hasAgreed) _buildAgreementBubble(),

        // 메시지 입력창
        _buildMessageInput(isEnabled: _hasAgreed),
      ],
    );
  }

  // 타이핑 인디케이터 위젯
  Widget _buildTypingIndicator(String nickname) {
    return Align(
      alignment: Alignment.centerLeft, // 상대방(관리자)이므로 왼쪽
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5.0),
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
        decoration: BoxDecoration(
          color: Color(0xFFE5E5EA), // NEW: 상대방 채팅 버블 색상과 동일하게
          borderRadius: BorderRadius.only(
            // NEW: 더 둥글게
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
          ),
        ),
        child: Text(
          '$nickname 님이 입력 중...',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 16, // NEW: 메시지 폰트와 동일하게
            fontStyle: FontStyle.italic,
            height: 1.3,
          ),
        ),
      ),
    );
  }

  Widget _buildAgreementBubble() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 0.0),
      color: Colors.white,
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Colors.orange.shade700, size: 20),
                SizedBox(width: 8),
                Text(
                  '안내 및 주의사항',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              '욕설, 비방, 성희롱 등 부적절한 언어 사용 시 사전 통보 없이 채팅이 종료되며, 정도에 따라 서비스 이용이 제재될 수 있습니다.',
              style:
              TextStyle(fontSize: 14, color: Colors.grey[800], height: 1.4),
            ),
            SizedBox(height: 8),
            Text(
              '원활한 상담을 위해 문의 내용은 저장될 수 있습니다.',
              style:
              TextStyle(fontSize: 14, color: Colors.grey[800], height: 1.4),
            ),
            SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _hasAgreed = true;
                });
                _markAsReadByUser();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text('네, 확인했습니다.',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSystemMessage(String text, {IconData? icon}) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: Color(0xFFF0F0F0), // NEW: 더 연한 회색
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null)
              Icon(icon, color: Colors.black54, size: 16), // NEW: 아이콘 색상
            if (icon != null) SizedBox(width: 8),
            Text(
              text,
              textAlign: TextAlign.center,
              style:
              TextStyle(fontSize: 12, color: Colors.black54), // NEW: 텍스트 색상
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatBubble(Map<String, dynamic> data,
      {required bool isLastMessage, required bool isReadByAdmin}) {
    final bool isUserMessage = data['isUser'] ?? false;
    final String text = data['text'] ?? '';
    final dynamic timestamp = data['timestamp'];
    final String nickname = data['nickname'] ?? (isUserMessage ? '나' : '관리자');

    final String senderEmail = data['senderEmail'] ?? '';
    if (senderEmail == 'system') {
      // '안내봇' 닉네임일 때만 아이콘 추가
      return _buildSystemMessage(text,
          icon: nickname == '안내봇' ? Icons.info_outline : null);
    }

    String timeString = '';
    if (timestamp is Timestamp) {
      timeString = DateFormat('HH:mm').format(timestamp.toDate());
    }

    // NEW: 디자인 변수 정의
    final Color myColor = Colors.blue;
    final Color otherColor = Color(0xFFE5E5EA); // iMessage 회색
    final Color myTextColor = Colors.white;
    final Color otherTextColor = Colors.black87;

    final Radius corner = Radius.circular(18);
    final Radius sharpCorner = Radius.circular(4);

    return Align(
      // '나'(사용자)는 오른쪽, '상대'(관리자)는 왼쪽
      alignment: isUserMessage ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5.0),
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
        decoration: BoxDecoration(
          color: isUserMessage ? myColor : otherColor,
          borderRadius: BorderRadius.only(
            topLeft: corner,
            topRight: corner,
            bottomLeft: isUserMessage ? corner : sharpCorner,
            bottomRight: isUserMessage ? sharpCorner : corner,
          ),
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, // 텍스트는 항상 왼쪽 정렬
          children: [
            // '나'의 닉네임("나")은 표시 안 함. 관리자 닉네임만 표시
            if (!isUserMessage)
              Text(
                nickname,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.deepPurple, // NEW: 관리자 닉네임 색상
                ),
              ),
            if (!isUserMessage) SizedBox(height: 4),

            Text(
              text,
              style: TextStyle(
                color: isUserMessage ? myTextColor : otherTextColor,
                fontSize: 16,
                height: 1.3, // NEW: 줄 간격
              ),
            ),
            SizedBox(height: 5),

            // 시간 및 읽음 표시는 버블의 오른쪽 하단에 정렬
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isLastMessage && isUserMessage)
                  Padding(
                    padding: const EdgeInsets.only(right: 4.0),
                    child: Text(
                      isReadByAdmin ? '읽음' : '전송됨',
                      style: TextStyle(
                        color: isUserMessage ? Colors.white70 : Colors.black54,
                        fontSize: 10,
                      ),
                    ),
                  ),
                Text(
                  timeString,
                  style: TextStyle(
                    color: isUserMessage ? Colors.white70 : Colors.black54,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput({required bool isEnabled}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border:
        isEnabled ? Border(top: BorderSide(color: Colors.grey[200]!)) : null,
      ),
      padding: EdgeInsets.only(left: 16, right: 16, top: 8),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                enabled: isEnabled,
                decoration: InputDecoration(
                  hintText:
                  isEnabled ? '문의 내용을 입력하세요...' : '안내 사항에 동의해주세요.',
                  filled: true,
                  fillColor: isEnabled ? Colors.grey[100] : Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                maxLines: null,
                textInputAction: TextInputAction.done,
                onEditingComplete: () {
                  FocusScope.of(context).unfocus();
                },
              ),
            ),
            SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.send,
                  color: isEnabled ? Colors.blueAccent : Colors.grey[400]),
              onPressed: isEnabled ? _sendMessage : null,
            ),
          ],
        ),
      ),
    );
  }

  // ▼▼▼▼▼▼▼▼▼▼ [추가된 헬퍼 함수] ▼▼▼▼▼▼▼▼▼▼

  // 날짜가 다른지 확인하는 헬퍼 함수
  bool _isDifferentDay(Timestamp ts1, Timestamp ts2) {
    final date1 = ts1.toDate();
    final date2 = ts2.toDate();
    return date1.year != date2.year ||
        date1.month != date2.month ||
        date1.day != date2.day;
  }

  // 날짜 구분선 위젯
  Widget _buildDateSeparator(Timestamp timestamp) {
    final date = timestamp.toDate();
    final formatter = DateFormat('yyyy년 M월 d일 EEEE', 'ko_KR');
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
        decoration: BoxDecoration(
          color: Color(0xFFEFEFF4), // 연한 회색 배경
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          formatter.format(date),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: Colors.black54,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
// ▲▲▲▲▲▲▲▲▲▲ [추가된 헬퍼 함수] ▲▲▲▲▲▲▲▲▲▲
}