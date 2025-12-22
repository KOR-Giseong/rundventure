import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart'; // 날짜 로케일

class FriendChatScreen extends StatefulWidget {
  final String friendEmail;
  final String friendNickname;
  final String? friendProfileUrl;

  const FriendChatScreen({
    Key? key,
    required this.friendEmail,
    required this.friendNickname,
    this.friendProfileUrl,
  }) : super(key: key);

  @override
  _FriendChatScreenState createState() => _FriendChatScreenState();
}

class _FriendChatScreenState extends State<FriendChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ScrollController _scrollController = ScrollController();

  String? _myEmail;
  String? _myNickname;
  String? _myProfileUrl;
  String? _chatRoomId;

  bool _isInitialLoading = true;

  Timer? _typingTimer;
  bool _isFriendTyping = false;
  bool _isReadByFriend = true; // 친구가 읽었는지
  Stream<DocumentSnapshot>? _summaryStream; // 채팅방 요약 정보 스트림

  String? _myEmailKey;
  String? _friendEmailKey;


  @override
  void initState() {
    super.initState();
    _myEmail = _auth.currentUser?.email;

    // 비동기 초기화 실행
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    if (_myEmail == null) {
      if (mounted) setState(() => _isInitialLoading = false);
      return;
    }

    _myEmailKey = _emailToKey(_myEmail!);
    _friendEmailKey = _emailToKey(widget.friendEmail);

    // 1. 내 닉네임 및 프로필 URL 로드 (Firestore에서)
    try {
      final doc = await _firestore.collection('users').doc(_myEmail).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()! as Map;
        if (mounted) {
          _myNickname = data['nickname'] ?? '나';
          _myProfileUrl = data['profileImageUrl'] as String?;
        }
      } else {
        _myNickname = '나';
        _myProfileUrl = null;
      }
    } catch (e) {
      print("내 정보 로드 실패: $e");
      _myNickname = '나';
      _myProfileUrl = null;
    }

    // 2. 채팅방 ID 생성
    _chatRoomId = _getChatRoomId(_myEmail!, widget.friendEmail);
    _summaryStream =
        _firestore.collection('userChats').doc(_chatRoomId).snapshots();

    await _markAsReadByMe();

    // 4. 타이핑 리스너 추가
    _messageController.addListener(_onTyping);

    // 5. 로딩 완료
    if (mounted) {
      setState(() {
        _isInitialLoading = false;
      });
    }
  }

  String _emailToKey(String email) {
    return email.replaceAll('.', '_dot_').replaceAll('@', '_at_');
  }

  String _getChatRoomId(String email1, String email2) {
    if (email1.compareTo(email2) > 0) {
      return '${email2}_$email1';
    } else {
      return '${email1}_$email2';
    }
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTyping);
    _typingTimer?.cancel();
    if (_chatRoomId != null && _myEmailKey != null) {
      _firestore.collection('userChats').doc(_chatRoomId).set({
        'typing_$_myEmailKey': false,
      }, SetOptions(merge: true));
    }
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // 타이핑 이벤트 핸들러
  void _onTyping() {
    if (_chatRoomId == null || _myEmailKey == null || _friendEmailKey == null || _myNickname == null) return;
    final myTypingKey = 'typing_$_myEmailKey';

    Map<String, dynamic> typingData = {
      myTypingKey: true,
      'participants': [_myEmail, widget.friendEmail],
      'participantNicknames': {
        _myEmailKey!: _myNickname,
        _friendEmailKey!: widget.friendNickname,
      },
      'participantProfileUrls': {
        _myEmailKey!: _myProfileUrl,
        _friendEmailKey!: widget.friendProfileUrl,
      },
    };

    _firestore.collection('userChats').doc(_chatRoomId).set(
        typingData,
        SetOptions(merge: true)
    );

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      _firestore.collection('userChats').doc(_chatRoomId).set({
        myTypingKey: false,
      }, SetOptions(merge: true));
    });
  }

  Future<void> _markAsReadByMe() async {
    if (_chatRoomId == null || _myEmailKey == null || _friendEmailKey == null || _myNickname == null) {
      print("Warning: _markAsReadByMe called before _myNickname was loaded.");
      return;
    }

    final myReadKey = 'isReadBy_$_myEmailKey';
    final summaryRef = _firestore.collection('userChats').doc(_chatRoomId!);

    try {
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(summaryRef);

        Map<String, dynamic> updateData = {
          myReadKey: true,
          'hiddenBy_$_myEmailKey': false,
          'participants': [_myEmail, widget.friendEmail],
          'participantNicknames': {
            _myEmailKey!: _myNickname,
            _friendEmailKey!: widget.friendNickname,
          },
          'participantProfileUrls': {
            _myEmailKey!: _myProfileUrl,
            _friendEmailKey!: widget.friendProfileUrl,
          },
          'lastUpdated': FieldValue.serverTimestamp(),
        };

        if (!snapshot.exists) {
          updateData.addAll({
            'lastMessage': '채팅이 시작되었습니다.',
            'lastSenderEmail': 'system',
            'isReadBy_$_friendEmailKey': false,
          });
          transaction.set(summaryRef, updateData);
        } else {
          transaction.set(summaryRef, updateData, SetOptions(merge: true));
        }
      });
    } catch (e) {
      print("Error in _markAsReadByMe transaction: $e");
      try {
        await summaryRef.set({
          myReadKey: true,
          'hiddenBy_$_myEmailKey': false,
          'participants': [_myEmail, widget.friendEmail],
          'participantNicknames': {
            _myEmailKey!: _myNickname,
            _friendEmailKey!: widget.friendNickname,
          },
          'participantProfileUrls': {
            _myEmailKey!: _myProfileUrl,
            _friendEmailKey!: widget.friendProfileUrl,
          },
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e2) {
        print("Error in _markAsReadByMe fallback: $e2");
      }
    }
  }


  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _myEmail == null || _myNickname == null || _chatRoomId == null || _myEmailKey == null || _friendEmailKey == null) {
      return;
    }

    _typingTimer?.cancel();
    final messageTimestamp = FieldValue.serverTimestamp();
    _messageController.clear();

    final batch = _firestore.batch();
    final summaryRef = _firestore.collection('userChats').doc(_chatRoomId!);
    final messagesCollectionRef = summaryRef.collection('messages');

    final myReadKey = 'isReadBy_$_myEmailKey';
    final friendReadKey = 'isReadBy_$_friendEmailKey';
    final myTypingKey = 'typing_$_myEmailKey';

    // 1. 채팅방 요약(summary) 정보 업데이트
    Map<String, dynamic> summaryUpdateData = {
      'lastMessage': text,
      'lastSenderEmail': _myEmail,
      'lastSenderNickname': _myNickname,
      'lastUpdated': messageTimestamp,
      myReadKey: true,
      friendReadKey: false,
      myTypingKey: false,
      'hiddenBy_$_myEmailKey': false,
      'participants': [_myEmail, widget.friendEmail],
      'participantNicknames': {
        _myEmailKey!: _myNickname,
        _friendEmailKey!: widget.friendNickname,
      },
      'participantProfileUrls': {
        _myEmailKey!: _myProfileUrl,
        _friendEmailKey!: widget.friendProfileUrl,
      },
    };
    batch.set(summaryRef, summaryUpdateData, SetOptions(merge: true));

    // 2. 실제 메시지 추가
    final adminMessageRef = messagesCollectionRef.doc();
    batch.set(adminMessageRef, {
      'text': text,
      'timestamp': messageTimestamp,
      'senderEmail': _myEmail,
      'senderNickname': _myNickname,
    });

    await batch.commit();
    _scrollToBottom();
  }

  // (수정 없음) 스크롤
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
    final textScaler = MediaQuery.textScalerOf(context);

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
        title: Text(
          widget.friendNickname,
          style: TextStyle(
            fontSize: textScaler.scale(18),
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: _isInitialLoading || _chatRoomId == null || _friendEmailKey == null || _myNickname == null
          ? Center(child: CircularProgressIndicator()) // 로딩 중
          : StreamBuilder<DocumentSnapshot>(
        stream: _summaryStream,
        builder: (context, summarySnapshot) {
          if (summarySnapshot.hasData && summarySnapshot.data!.exists) {
            final summaryData =
                summarySnapshot.data!.data() as Map<String, dynamic>? ??
                    {};

            final friendTypingKey = 'typing_$_friendEmailKey';
            _isFriendTyping = summaryData[friendTypingKey] ?? false;

            final friendReadKey = 'isReadBy_$_friendEmailKey';
            _isReadByFriend = summaryData[friendReadKey] ?? true;

          } else {
            // 채팅방이 아예 처음 생성된 경우
            _isFriendTyping = false;
            _isReadByFriend = false;
          }

          return Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('userChats')
                      .doc(_chatRoomId)
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
                    final bool isFirstChat = docs.isEmpty;

                    Future.delayed(
                        Duration(milliseconds: 100), _scrollToBottom);

                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.all(16.0),
                      itemCount: docs.length + 1 + (isFirstChat ? 1 : 0),
                      itemBuilder: (context, index) {

                        if (isFirstChat && index == docs.length + 1) {
                          return _buildSystemMessage(
                            context,
                            '욕설, 비방, 불쾌감을 주는 언행은 서비스 이용이 제재될 수 있습니다.',
                            icon: Icons.warning_amber_rounded,
                          );
                        }

                        if (index == docs.length) {
                          return _isFriendTyping
                              ? _buildTypingIndicator(context, widget.friendNickname)
                              : SizedBox.shrink();
                        }

                        final doc = docs[index];
                        final data =
                        doc.data() as Map<String, dynamic>;
                        final bool isLastMessage = (index == 0);
                        final bool isMe = (data['senderEmail'] == _myEmail);

                        bool showDateSeparator = false;
                        final dynamic currentTimestamp = data['timestamp'];

                        if (currentTimestamp is Timestamp) {
                          if (index == docs.length - 1) {
                            showDateSeparator = true;
                          } else {
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
                            if (showDateSeparator &&
                                currentTimestamp is Timestamp)
                              _buildDateSeparator(context, currentTimestamp),

                            _buildChatBubble(
                              context,
                              data,
                              isMe: isMe,
                              isLastMessage: isLastMessage,
                              isReadByFriend: _isReadByFriend,
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
              // 메시지 입력창
              _buildMessageInput(context)
            ],
          );
        },
      ),
    );
  }

  // (수정 없음)
  Widget _buildTypingIndicator(BuildContext context, String nickname) {
    final textScaler = MediaQuery.textScalerOf(context);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5.0),
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
        decoration: BoxDecoration(
          color: Color(0xFFE5E5EA),
          borderRadius: BorderRadius.only(
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
            fontSize: textScaler.scale(16),
            fontStyle: FontStyle.italic,
            height: 1.3,
          ),
        ),
      ),
    );
  }

  // (수정 없음)
  Widget _buildChatBubble(BuildContext context, Map<String, dynamic> data,
      {required bool isMe,
        required bool isLastMessage,
        required bool isReadByFriend}) {

    final textScaler = MediaQuery.textScalerOf(context);
    final String text = data['text'] ?? '';
    final dynamic timestamp = data['timestamp'];

    if (data['senderEmail'] == 'system') {
      return _buildSystemMessage(context, text);
    }

    String timeString = '';
    if (timestamp is Timestamp) {
      timeString = DateFormat('HH:mm').format(timestamp.toDate());
    }

    final Color myColor = Colors.blue;
    final Color otherColor = Color(0xFFE5E5EA);
    final Color myTextColor = Colors.white;
    final Color otherTextColor = Colors.black87;
    final Radius corner = Radius.circular(18);
    final Radius sharpCorner = Radius.circular(4);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5.0),
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
        decoration: BoxDecoration(
          color: isMe ? myColor : otherColor,
          borderRadius: BorderRadius.only(
            topLeft: corner,
            topRight: corner,
            bottomLeft: isMe ? corner : sharpCorner,
            bottomRight: isMe ? sharpCorner : corner,
          ),
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: TextStyle(
                color: isMe
                    ? myTextColor
                    : otherTextColor,
                fontSize: textScaler.scale(16),
                height: 1.3,
              ),
            ),
            SizedBox(height: 5),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLastMessage && isMe)
                  Padding(
                    padding: const EdgeInsets.only(right: 4.0),
                    child: Text(
                      isReadByFriend ? '읽음' : '전송됨',
                      style: TextStyle(
                        color: isMe ? Colors.white70 : Colors.black54,
                        fontSize: textScaler.scale(10),
                      ),
                    ),
                  ),
                Text(
                  timeString,
                  style: TextStyle(
                    color: isMe ? Colors.white70 : Colors.black54,
                    fontSize: textScaler.scale(10),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // (수정 없음)
  Widget _buildSystemMessage(BuildContext context, String text, {IconData? icon}) {
    final textScaler = MediaQuery.textScalerOf(context);

    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null)
              Icon(icon, color: Colors.black54, size: 16),
            if (icon != null) SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                textAlign: TextAlign.center,
                style:
                TextStyle(
                    fontSize: textScaler.scale(11),
                    color: Colors.black54
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // (수정 없음)
  Widget _buildMessageInput(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);

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
                style: TextStyle(fontSize: textScaler.scale(16)),
                decoration: InputDecoration(
                  hintText: '메시지 입력...',
                  hintStyle: TextStyle(fontSize: textScaler.scale(16), color: Colors.grey[600]),
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
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
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

  // (수정 없음)
  bool _isDifferentDay(Timestamp ts1, Timestamp ts2) {
    final date1 = ts1.toDate();
    final date2 = ts2.toDate();
    return date1.year != date2.year ||
        date1.month != date2.month ||
        date1.day != date2.day;
  }

  // (수정 없음)
  Widget _buildDateSeparator(BuildContext context, Timestamp timestamp) {
    final textScaler = MediaQuery.textScalerOf(context);
    initializeDateFormatting('ko_KR', null);
    final date = timestamp.toDate();
    final formatter = DateFormat('yyyy년 M월 d일 EEEE', 'ko_KR');
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
        decoration: BoxDecoration(
          color: Color(0xFFEFEFF4),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          formatter.format(date),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: textScaler.scale(12),
            color: Colors.black54,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}