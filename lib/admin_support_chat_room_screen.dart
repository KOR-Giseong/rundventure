import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:rundventure/profile/other_user_profile.dart';

class AdminSupportChatRoomScreen extends StatefulWidget {
  final String userEmail;
  final String userNickname;

  const AdminSupportChatRoomScreen({
    Key? key,
    required this.userEmail,
    required this.userNickname,
  }) : super(key: key);

  @override
  _AdminSupportChatRoomScreenState createState() =>
      _AdminSupportChatRoomScreenState();
}

class _AdminSupportChatRoomScreenState
    extends State<AdminSupportChatRoomScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ScrollController _scrollController = ScrollController();

  String? _adminEmail;
  String _adminNickname = '관리자';

  bool _isAdminReplyStarted = false;
  bool _isInitialLoading = true;

  Timer? _typingTimer;
  bool _isUserTyping = false;
  bool _isReadByUser = true;
  Stream<DocumentSnapshot>? _summaryStream;

  @override
  void initState() {
    super.initState();
    _adminEmail = _auth.currentUser?.email;

    _summaryStream =
        _firestore.collection('supportChats').doc(widget.userEmail).snapshots();

    _loadInitialStateAndMarkAsRead();

    _messageController.addListener(_onTyping);
  }

  Future<void> _loadInitialStateAndMarkAsRead() async {
    if (_adminEmail == null) {
      if (mounted) {
        setState(() {
          _isInitialLoading = false;
        });
      }
      return;
    }

    // 1. 관리자 닉네임 로드
    try {
      final doc = await _firestore.collection('users').doc(_adminEmail).get();
      if (doc.exists && doc.data() != null) {
        if (mounted) {
          _adminNickname = (doc.data()! as Map)['nickname'] ?? '관리자';
        }
      }
    } catch (e) {
      print("관리자 닉네임 로드 실패: $e");
    }

    // 2. 채팅방의 *현재* 상태를 확인
    try {
      final summaryRef =
      _firestore.collection('supportChats').doc(widget.userEmail);
      final summaryDoc = await summaryRef.get();

      if (summaryDoc.exists) {
        final data = summaryDoc.data() ?? {};
        final String? assignedAdmin = data['assignedAdminNickname'];

        if (assignedAdmin == null) {
          _isAdminReplyStarted = false;
        } else {
          _isAdminReplyStarted = (assignedAdmin == _adminNickname);
        }
      } else {
        if (mounted) {
          _isAdminReplyStarted = false;
        }
      }
    } catch (e) {
      print("채팅 요약 정보 로드 실패: $e");
      _isAdminReplyStarted = false; // 오류 발생 시 기본값
    }

    // 3. 채팅방을 '읽음'으로 처리
    await _markAsReadByAdmin();

    // 4. (로드가 끝난 후) 닉네임, 담당 상태, 로딩 상태 state 반영
    if (mounted) {
      setState(() {
        _isInitialLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTyping);
    _typingTimer?.cancel();
    if (_adminEmail != null) {
      _firestore.collection('supportChats').doc(widget.userEmail).set({
        'isAdminTyping': false,
      }, SetOptions(merge: true));
    }
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // 타이핑 이벤트 핸들러
  void _onTyping() {
    if (_adminEmail == null) return;

    _firestore.collection('supportChats').doc(widget.userEmail).set({
      'isAdminTyping': true,
    }, SetOptions(merge: true));

    _typingTimer?.cancel();

    _typingTimer = Timer(const Duration(seconds: 2), () {
      _firestore.collection('supportChats').doc(widget.userEmail).set({
        'isAdminTyping': false,
      }, SetOptions(merge: true));
    });
  }

  Future<void> _markAsReadByAdmin() async {
    await _firestore.collection('supportChats').doc(widget.userEmail).set({
      'isReadByAdmin': true,
    }, SetOptions(merge: true));
  }

  // "답변 담당하기" 버튼을 눌렀을 때 실행되는 함수
  Future<void> _assignChatToAdmin() async {
    if (_adminEmail == null) return;

    final messageTimestamp = FieldValue.serverTimestamp();
    final batch = _firestore.batch();
    final summaryRef =
    _firestore.collection('supportChats').doc(widget.userEmail);
    final messagesCollectionRef = summaryRef.collection('messages');

    final String systemMessageText = '$_adminNickname 님이 답변을 시작합니다.';

    // 1. "답변 시작" 시스템 메시지 추가
    final systemMessageRef = messagesCollectionRef.doc();
    batch.set(systemMessageRef, {
      'text': systemMessageText,
      'timestamp': messageTimestamp,
      'senderEmail': 'system',
      'isUser': false,
      'nickname': '시스템 알림',
    });

    // 2. 채팅방 요약 정보(summary) 업데이트
    Map<String, dynamic> summaryUpdateData = {
      'lastMessage': systemMessageText,
      'lastUpdated': messageTimestamp,
      'isReadByAdmin': true,
      'isChatClosed': false,
      'assignedAdminNickname': _adminNickname,
      'isReadByUser': false,
    };

    batch.set(summaryRef, summaryUpdateData, SetOptions(merge: true));

    try {
      await batch.commit();
      // 3. UI 상태 변경 (버튼 -> 입력창)
      if (mounted) {
        setState(() {
          _isAdminReplyStarted = true;
        });
      }
      _scrollToBottom();
    } catch (e) {
      print("채팅 담당하기 실패: $e");
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _adminEmail == null) {
      return;
    }

    _typingTimer?.cancel();
    final messageTimestamp = FieldValue.serverTimestamp();
    _messageController.clear();

    final batch = _firestore.batch();
    final summaryRef =
    _firestore.collection('supportChats').doc(widget.userEmail);
    final messagesCollectionRef = summaryRef.collection('messages');

    Map<String, dynamic> summaryUpdateData = {
      'lastMessage': '[관리자] $text',
      'lastUpdated': messageTimestamp,
      'isReadByAdmin': true,
      'isChatClosed': false,
      'isAdminTyping': false,
      'isReadByUser': false,
    };

    final adminMessageRef = messagesCollectionRef.doc();
    batch.set(adminMessageRef, {
      'text': text,
      'timestamp': messageTimestamp,
      'senderEmail': _adminEmail,
      'isUser': false,
      'nickname': _adminNickname,
    });

    batch.set(summaryRef, summaryUpdateData, SetOptions(merge: true));

    await batch.commit();
    _scrollToBottom();
  }

  Future<void> _showEndChatConfirmation() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(Icons.gpp_bad_outlined, color: Colors.red),
            SizedBox(width: 10),
            Text('상담 종료',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text('이 문의 상담을 종료하시겠습니까?\n사용자는 이 내역을 볼 수 있습니다.',
            style: TextStyle(color: Colors.black87)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('취소',
                style:
                TextStyle(color: Colors.grey[700], fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('상담 종료', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _endChat();
    }
  }

  Future<void> _endChat() async {
    if (_adminEmail == null) return;

    _typingTimer?.cancel();

    final messageTimestamp = FieldValue.serverTimestamp();
    final batch = _firestore.batch();
    final summaryRef =
    _firestore.collection('supportChats').doc(widget.userEmail);
    final messagesCollectionRef = summaryRef.collection('messages');

    final systemMessageRef = messagesCollectionRef.doc();
    batch.set(systemMessageRef, {
      'text': '$_adminNickname 님에 의해 상담이 종료되었습니다.',
      'timestamp': messageTimestamp,
      'senderEmail': 'system',
      'isUser': false,
      'nickname': '안내봇',
    });

    batch.set(summaryRef, {
      'lastMessage': '상담이 종료되었습니다.',
      'lastUpdated': messageTimestamp,
      'isReadByAdmin': true,
      'isChatClosed': true,
      'assignedAdminNickname': FieldValue.delete(),
      'isAdminTyping': false,
      'isUserTyping': false,
    }, SetOptions(merge: true));

    await batch.commit();

    if (mounted) {
      setState(() {
        _isAdminReplyStarted = false;
      });
    }
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
        title: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => OtherUserProfileScreen(
                  userEmail: widget.userEmail, // 사용자 이메일 전달
                  isAdminViewing: true, // 👈 [핵심] 관리자 모드로 프로필 보기
                ),
              ),
            );
          },
          child: Row(
            mainAxisSize: MainAxisSize.min, // Row 크기를 내용에 맞춤
            children: [
              Text(
                widget.userNickname,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              SizedBox(width: 4),
              Icon(
                Icons.account_circle_outlined, // 프로필 아이콘
                size: 20,
                color: Colors.grey[700],
              ),
            ],
          ),
        ),
        titleSpacing: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.gpp_bad_outlined, color: Colors.redAccent),
            tooltip: '상담 종료',
            onPressed: _showEndChatConfirmation,
          )
        ],
      ),
      body: _isInitialLoading
          ? Center(child: CircularProgressIndicator()) // 로딩 중이면 인디케이터 표시
          : StreamBuilder<DocumentSnapshot>(
        // 로딩 끝나면 기존 UI 표시
        stream: _summaryStream,
        builder: (context, summarySnapshot) {
          if (summarySnapshot.hasData && summarySnapshot.data!.exists) {
            final summaryData =
                summarySnapshot.data!.data() as Map<String, dynamic>? ??
                    {};
            _isUserTyping = summaryData['isUserTyping'] ?? false;
            _isReadByUser = summaryData['isReadByUser'] ?? true;
          }

          return Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('supportChats')
                      .doc(widget.userEmail)
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

                    Future.delayed(
                        Duration(milliseconds: 100), _scrollToBottom);

                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.all(16.0),
                      itemCount: docs.length + 2,
                      itemBuilder: (context, index) {
                        // 1. 운영 시간
                        if (index == docs.length + 1) {
                          return _buildSystemMessage(
                            '운영 시간: 평일 09:00 - 18:00 (주말/공휴일 휴무)',
                            icon: Icons.info_outline,
                          );
                        }

                        // 2. 타이핑 인디케이터
                        if (index == docs.length) {
                          return _isUserTyping
                              ? _buildTypingIndicator(widget.userNickname)
                              : SizedBox.shrink();
                        }

                        // 3. 메시지 버블 (+ 날짜 구분선)
                        final doc = docs[index];
                        final data =
                        doc.data() as Map<String, dynamic>;
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
                              isReadByUser: _isReadByUser,
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
              // 담당자 할당 여부에 따라 입력창 또는 담당하기 버튼 표시
              if (_isAdminReplyStarted)
                _buildMessageInput()
              else
                _buildAssignChatButton(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTypingIndicator(String nickname) {
    return Align(
      alignment: Alignment.centerLeft, // 상대방(사용자)이므로 왼쪽
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5.0),
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
        decoration: BoxDecoration(
          color: Color(0xFFE5E5EA), // NEW: 상대방 채팅 버블 색상
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
      {required bool isLastMessage, required bool isReadByUser}) {
    final bool isUserMessage = data['isUser'] ?? false;
    final String text = data['text'] ?? '';
    final dynamic timestamp = data['timestamp'];
    final String nickname =
        data['nickname'] ?? (isUserMessage ? widget.userNickname : '관리자');

    final String senderEmail = data['senderEmail'] ?? '';
    if (senderEmail == 'system') {
      return _buildSystemMessage(text,
          icon: nickname == '안내봇' ? Icons.info_outline : null);
    }

    String timeString = '';
    if (timestamp is Timestamp) {
      timeString = DateFormat('HH:mm').format(timestamp.toDate());
    }

    // NEW: 디자인 변수 정의 (관리자 시점)
    final Color myColor = Colors.blue; // '나'(관리자)의 색상
    final Color otherColor = Color(0xFFE5E5EA); // '상대'(사용자)의 색상
    final Color myTextColor = Colors.white;
    final Color otherTextColor = Colors.black87;

    final Radius corner = Radius.circular(18);
    final Radius sharpCorner = Radius.circular(4);

    return Align(
      // '나'(관리자)는 오른쪽, '상대'(사용자)는 왼쪽
      alignment: isUserMessage ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5.0),
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
        decoration: BoxDecoration(
          color: isUserMessage ? otherColor : myColor, // NEW: 색상 반전
          borderRadius: BorderRadius.only(
            topLeft: corner,
            topRight: corner,
            bottomLeft: isUserMessage ? sharpCorner : corner, // NEW: 꼬리 반전
            bottomRight: isUserMessage ? corner : sharpCorner, // NEW: 꼬리 반전
          ),
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, // 텍스트는 항상 왼쪽 정렬
          children: [
            // '나'(관리자) 닉네임은 안보여주고, '상대'(사용자) 닉네임만 표시
            if (isUserMessage)
              Text(
                nickname, // 사용자 닉네임
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.deepPurple, // NEW: 사용자 닉네임 색상
                ),
              ),
            if (isUserMessage) SizedBox(height: 4),

            Text(
              text,
              style: TextStyle(
                color: isUserMessage
                    ? otherTextColor
                    : myTextColor, // NEW: 텍스트 색상 반전
                fontSize: 16,
                height: 1.3,
              ),
            ),
            SizedBox(height: 5),

            // 시간 및 읽음 표시는 버블의 오른쪽 하단에 정렬
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // '나'(관리자)가 보낸 마지막 메시지일 때만 '읽음' 표시
                if (isLastMessage && !isUserMessage)
                  Padding(
                    padding: const EdgeInsets.only(right: 4.0),
                    child: Text(
                      isReadByUser ? '읽음' : '전송됨',
                      style: TextStyle(
                        color:
                        isUserMessage ? Colors.black54 : Colors.white70,
                        fontSize: 10,
                      ),
                    ),
                  ),
                Text(
                  timeString,
                  style: TextStyle(
                    color: isUserMessage ? Colors.black54 : Colors.white70,
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

  // "담당하기" 버튼 위젯
  Widget _buildAssignChatButton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      padding: EdgeInsets.only(left: 16, right: 16, top: 8),
      child: SafeArea(
        child: Padding(
          padding:
          const EdgeInsets.only(bottom: 8.0), // 하단 여백을 위해 Padding 추가
          child: ElevatedButton(
            onPressed: _assignChatToAdmin,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              minimumSize: Size(double.infinity, 45),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              '답변 담당하기',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      padding: EdgeInsets.only(left: 16, right: 16, top: 8),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: '답변을 입력하세요...',
                  filled: true,
                  fillColor: Colors.grey[100],
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
              icon: Icon(Icons.send, color: Colors.blueAccent),
              onPressed: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }

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
}