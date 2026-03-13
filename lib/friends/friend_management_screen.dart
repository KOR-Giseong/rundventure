import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart'; // 날짜 포맷팅
import 'dart:async';

import '../profile/other_user_profile.dart';
import 'search_friend_screen.dart';
import 'friend_chat_screen.dart';


class FriendManagementScreen extends StatefulWidget {
  // 알림을 통해 들어올 때 '요청' 탭(index: 1)을 바로 보여주기 위함
  final int initialIndex;

  const FriendManagementScreen({Key? key, this.initialIndex = 0}) : super(key: key);

  @override
  _FriendManagementScreenState createState() => _FriendManagementScreenState();
}

class _FriendManagementScreenState extends State<FriendManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final String? _myEmail = FirebaseAuth.instance.currentUser?.email;

  // 탭 알림 배지를 위한 변수
  bool _hasNewFriendRequests = false;
  StreamSubscription? _friendRequestSubscription;
  bool _hasNewChatMessages = false;
  StreamSubscription? _chatMessageSubscription;

  @override
  void initState() {
    super.initState();
    // 탭 3개 (친구 목록, 받은 요청, 채팅)
    _tabController = TabController(length: 3, vsync: this, initialIndex: widget.initialIndex);

    _listenForFriendRequests();
    _listenForNewChatMessages();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _friendRequestSubscription?.cancel();
    _chatMessageSubscription?.cancel();
    super.dispose();
  }

  // 새로운 친구 요청 실시간 감지
  void _listenForFriendRequests() {
    if (_myEmail == null) return;

    _friendRequestSubscription?.cancel();
    final query = FirebaseFirestore.instance
        .collection('users')
        .doc(_myEmail)
        .collection('friendRequests')
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .snapshots();

    _friendRequestSubscription = query.listen((snapshot) {
      if (mounted) {
        setState(() {
          _hasNewFriendRequests = snapshot.docs.isNotEmpty;
        });
      }
    });
  }

  // 새로운 채팅 메시지 실시간 감지
  void _listenForNewChatMessages() {
    if (_myEmail == null) return;

    final String myEmailKey = _emailToKey(_myEmail);

    _chatMessageSubscription?.cancel();

    // 내가 참여하고, 내가 아직 읽지 않은('isReadBy_내키'가 false) 채팅방 확인
    final query = FirebaseFirestore.instance
        .collection('userChats')
        .where('participants', arrayContains: _myEmail)
        .where('isReadBy_$myEmailKey', isEqualTo: false)
        .limit(1)
        .snapshots();

    _chatMessageSubscription = query.listen((snapshot) {
      if (mounted) {
        setState(() {
          _hasNewChatMessages = snapshot.docs.isNotEmpty;
        });
      }
    });
  }


  // 스낵바 함수
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
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.redAccent.shade400 : Color(0xFFFF9F80),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(15, 5, 15, 15),
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  /// 친구 관련 Cloud Function 헬퍼
  Future<void> _callFriendFunction(String functionName, String friendEmail, {String? successMessage}) async {
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-northeast3')
          .httpsCallable(functionName);

      Map<String, dynamic> params = {};
      if (functionName == 'acceptFriendRequest') {
        params = {'senderEmail': friendEmail};
      } else {
        params = {'friendEmail': friendEmail};
      }

      await callable.call(params);

      if (mounted && successMessage != null) {
        _showCustomSnackBar(successMessage, isError: false);
      }
    } on FirebaseFunctionsException catch (e) {
      print("Firebase Functions 오류 ($functionName): ${e.message}");
      _showCustomSnackBar("오류: ${e.message ?? '알 수 없는 오류'}", isError: true);
    } catch (e) {
      print("일반 오류 ($functionName): $e");
      _showCustomSnackBar("작업 중 오류가 발생했습니다.", isError: true);
    }
  }

  /// 친구 삭제 확인 다이얼로그
  void _showRemoveFriendDialog(String friendEmail, String friendNickname) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('친구 삭제', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          content: Text('$friendNickname 님을 정말로 친구 목록에서 삭제하시겠습니까?', style: TextStyle(fontSize: 15)),
          actions: [
            TextButton(
              child: Text('취소', style: TextStyle(color: Colors.grey[700])),
              onPressed: () => Navigator.pop(dialogContext),
            ),
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Colors.redAccent.withOpacity(0.1),
              ),
              child: Text('삭제', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.pop(dialogContext);
                // 친구 삭제 호출
                _callFriendFunction(
                    'rejectOrRemoveFriend',
                    friendEmail,
                    successMessage: "$friendNickname 님을 삭제했습니다."
                );
              },
            ),
          ],
        );
      },
    );
  }

  /// 친구 액션 다이얼로그
  void _showFriendActionDialog(String friendEmail, String friendNickname, String? friendProfileUrl) {
    final fNickname = friendNickname == '알 수 없음' ? '친구' : friendNickname;

    Widget _buildActionItem(String title, VoidCallback onTap, {Color? color, FontWeight? fontWeight}) {
      return InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                color: color ?? Colors.black87,
                fontWeight: fontWeight ?? FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. 프로필 보기
              _buildActionItem(
                '$fNickname 님 프로필 보기',
                    () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OtherUserProfileScreen(
                        userEmail: friendEmail,
                      ),
                    ),
                  );
                },
              ),
              Divider(height: 1, indent: 16, endIndent: 16),
              // 2. 1:1 채팅하기
              _buildActionItem(
                '$fNickname 님과 1:1 채팅하기',
                    () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FriendChatScreen(
                        friendEmail: friendEmail,
                        friendNickname: fNickname,
                        friendProfileUrl: friendProfileUrl,
                      ),
                    ),
                  );
                },
                color: Colors.blueAccent,
                fontWeight: FontWeight.w600,
              ),
              Container(
                height: 8,
                color: Colors.grey[100],
              ),
              // 3. 취소
              _buildActionItem(
                '취소',
                    () => Navigator.pop(context),
                color: Colors.grey[700],
              ),
            ],
          ),
        );
      },
    );
  }

  // 채팅방 숨기기 (스와이프)
  Future<void> _hideChatRoom(String chatRoomId) async {
    if (_myEmail == null) return;

    try {
      final String myEmailKey = _emailToKey(_myEmail);
      await FirebaseFirestore.instance
          .collection('userChats')
          .doc(chatRoomId)
          .set({
        'hiddenBy_$myEmailKey': true,
      }, SetOptions(merge: true));

      _showCustomSnackBar("채팅방을 목록에서 숨겼습니다.");

    } catch (e) {
      _showCustomSnackBar("오류: 채팅방을 숨길 수 없습니다.", isError: true);
      print("Error hiding chat room: $e");
    }
  }

  // 헬퍼 함수
  String _emailToKey(String email) {
    return email.replaceAll('.', '_dot_').replaceAll('@', '_at_');
  }

  // 날짜 포맷 헬퍼
  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';

    try {
      DateTime date = timestamp.toDate();
      DateTime now = DateTime.now();

      if (date.year == now.year && date.month == now.month && date.day == now.day) {
        return DateFormat('HH:mm', 'ko_KR').format(date);
      }
      else if (date.year == now.year) {
        return DateFormat('MM.dd', 'ko_KR').format(date);
      }
      else {
        return DateFormat('yyyy.MM.dd', 'ko_KR').format(date);
      }
    } catch (e) {
      print("Error formatting timestamp: $e");
      return '';
    }
  }

  // 탭 배지 위젯
  Widget _buildTabWithBadge(String text, bool showBadge) {
    return Tab(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(text),
          ),
          if (showBadge)
            Positioned(
              top: -4,
              right: -8,
              child: Container(
                padding: const EdgeInsets.all(3.5),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    if (_myEmail == null) {
      return Scaffold(body: Center(child: Text("로그인이 필요합니다.")));
    }

    return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Image.asset(
                'assets/images/Back-Navs.png',
                width: 50,
                height: 50,
              ),
            ),
          ),
          title: const Text(
            '친구 관리',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(Icons.person_add_alt_1_outlined, color: Colors.grey[700]),
              tooltip: '친구 찾기',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SearchFriendScreen()),
                );
              },
            ),
            SizedBox(width: 10),
          ],
          bottom: TabBar(
            controller: _tabController,
            labelColor: Colors.blueAccent,
            unselectedLabelColor: Colors.grey[600],
            indicatorColor: Colors.blueAccent,
            indicatorWeight: 3.0,
            tabs: [
              _buildTabWithBadge('친구 목록', false),
              _buildTabWithBadge('받은 요청', _hasNewFriendRequests),
              _buildTabWithBadge('채팅', _hasNewChatMessages),
            ],
          ),
        ),
        body: Stack(
          children: [
            TabBarView(
              controller: _tabController,
              children: [
                _buildFriendListTab(_myEmail),
                _buildFriendRequestTab(_myEmail),
                _buildChatListTab(_myEmail),
              ],
            ),
          ],
        )
    );
  }

  /// --- 1. 친구 목록 탭 위젯 (30명 제한 카운트 표시 추가) ---
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
        // 친구가 없어도 0/30 표시는 하기 위해 docs 비었는지 체크는 뒤로 미룸

        final friends = snapshot.data?.docs ?? [];
        final int currentCount = friends.length;
        final int maxCount = 30;

        // 친구가 없을 때 화면
        if (friends.isEmpty) {
          return Column(
            children: [
              // 친구가 없어도 카운트는 보여줌 (0/30)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Text(
                        "내 친구",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                    ),
                    Spacer(),
                    Text(
                      "$currentCount / $maxCount 명",
                      style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w600
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                    child: Text("🏃\n아직 친구가 없습니다.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600], fontSize: 16)
                    )
                ),
              ),
            ],
          );
        }

        // 친구가 있을 때 화면
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 상단 카운트 헤더
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Text(
                      "내 친구",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                  ),
                  Spacer(),
                  Text(
                    "$currentCount / $maxCount 명",
                    style: TextStyle(
                        fontSize: 14,
                        // 30명 이상이면 빨간색 강조
                        color: currentCount >= maxCount ? Colors.redAccent : Colors.grey[600],
                        fontWeight: FontWeight.w600
                    ),
                  ),
                ],
              ),
            ),

            // 2. 친구 리스트
            Expanded(
              child: ListView.builder(
                itemCount: friends.length,
                itemBuilder: (context, index) {
                  final friendData = friends[index].data() as Map<String, dynamic>;
                  final friendEmail = friendData['email'] as String? ?? '';
                  final friendNickname = friendData['nickname'] as String? ?? '알 수 없음';
                  final friendProfileUrl = friendData['profileImageUrl'] as String?;

                  if (friendEmail.isEmpty) return SizedBox.shrink();

                  return ListTile(
                    leading: CircleAvatar(
                      radius: 25,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: (friendProfileUrl != null && friendProfileUrl.isNotEmpty)
                          ? NetworkImage(friendProfileUrl)
                          : AssetImage('assets/images/user.png') as ImageProvider,
                    ),
                    title: Text(friendNickname, style: TextStyle(fontWeight: FontWeight.w600)),
                    // subtitle: Text(friendEmail...), // 보안상 이메일 숨김

                    trailing: TextButton(
                      child: Text('삭제', style: TextStyle(color: Colors.redAccent)),
                      style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(color: Colors.redAccent.withOpacity(0.3))
                          )
                      ),
                      onPressed: () => _showRemoveFriendDialog(friendEmail, friendNickname),
                    ),
                    onTap: () {
                      _showFriendActionDialog(friendEmail, friendNickname, friendProfileUrl);
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  /// --- 2. 받은 요청 탭 위젯 (수정 없음) ---
  Widget _buildFriendRequestTab(String myEmail) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(myEmail)
          .collection('friendRequests')
          .where('status', isEqualTo: 'pending')
          .orderBy('timestamp', descending: true)
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
              child: Text("🔔\n받은 친구 요청이 없습니다.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600], fontSize: 16)
              )
          );
        }

        final requests = snapshot.data!.docs;

        return ListView.builder(
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final requestData = requests[index].data() as Map<String, dynamic>;
            final senderEmail = requestData['senderEmail'] as String? ?? '';
            final senderNickname = requestData['senderNickname'] as String? ?? '알 수 없음';
            final senderProfileUrl = requestData['senderProfileImageUrl'] as String?;

            if (senderEmail.isEmpty) return SizedBox.shrink();

            return ListTile(
              leading: CircleAvatar(
                radius: 25,
                backgroundColor: Colors.grey[200],
                backgroundImage: (senderProfileUrl != null && senderProfileUrl.isNotEmpty)
                    ? NetworkImage(senderProfileUrl)
                    : AssetImage('assets/images/user.png') as ImageProvider,
              ),
              title: Text(senderNickname, style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                senderEmail,
                style: TextStyle(color: Colors.grey[600], fontSize: 11),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    child: Text('거절', style: TextStyle(color: Colors.grey[700])),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onPressed: () {
                      _callFriendFunction(
                          'rejectOrRemoveFriend',
                          senderEmail,
                          successMessage: "$senderNickname 님의 요청을 거절했습니다."
                      );
                    },
                  ),
                  SizedBox(width: 6),
                  ElevatedButton(
                    child: Text('수락'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)
                        )
                    ),
                    onPressed: () {
                      // 서버에서 30명 체크 후 에러 던짐 -> _callFriendFunction이 스낵바로 표시
                      _callFriendFunction(
                          'acceptFriendRequest',
                          senderEmail,
                          successMessage: "$senderNickname 님과 친구가 되었습니다!"
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// --- 3. 채팅 목록 탭 위젯 (수정 없음) ---
  Widget _buildChatListTab(String myEmail) {
    final String myEmailKey = _emailToKey(myEmail);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('userChats')
          .where('participants', arrayContains: myEmail)
          .orderBy('lastUpdated', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("오류가 발생했습니다: ${snapshot.error}"));
        }

        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          return (data['hiddenBy_$myEmailKey'] ?? false) == false;
        }).toList();

        if (docs.isEmpty) {
          return Center(
              child: Text("💬\n아직 시작된 채팅이 없습니다.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600], fontSize: 16)
              )
          );
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final chatRoomId = doc.id;
            final data = doc.data() as Map<String, dynamic>;

            List<dynamic> participants = data['participants'] ?? [];
            String friendEmail = participants.firstWhere(
                    (p) => p != _myEmail, orElse: () => '');

            if (friendEmail.isEmpty) return SizedBox.shrink();

            String friendEmailKey = _emailToKey(friendEmail);

            Map<String, dynamic> nicknames = data['participantNicknames'] ?? {};
            String friendNickname = nicknames[friendEmailKey] ?? '알 수 없음';

            Map<String, dynamic> profileUrls = data['participantProfileUrls'] ?? {};
            String? friendProfileUrl = profileUrls[friendEmailKey];

            String lastMessage = data['lastMessage'] ?? '...';
            Timestamp? lastUpdated = data['lastUpdated'] as Timestamp?;

            bool isUnread = (data['isReadBy_$myEmailKey'] ?? true) == false;

            return Dismissible(
              key: Key(chatRoomId),
              direction: DismissDirection.endToStart,
              onDismissed: (_) {
                _hideChatRoom(chatRoomId);
              },
              background: Container(
                color: Colors.redAccent,
                padding: EdgeInsets.symmetric(horizontal: 20),
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.visibility_off_outlined, color: Colors.white),
                    SizedBox(width: 8),
                    Text('숨기기', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              child: ListTile(
                leading: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: (friendProfileUrl != null && friendProfileUrl.isNotEmpty)
                          ? NetworkImage(friendProfileUrl)
                          : AssetImage('assets/images/user.png') as ImageProvider,
                    ),
                    if (isUnread)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.blueAccent,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                title: Text(
                  friendNickname,
                  style: TextStyle(
                      fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                      color: isUnread ? Colors.black : Colors.black87
                  ),
                ),
                subtitle: Text(
                  lastMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                      color: isUnread ? Colors.black87 : Colors.grey[600]
                  ),
                ),
                trailing: Text(
                  _formatTimestamp(lastUpdated),
                  style: TextStyle(
                      color: isUnread ? Colors.blueAccent : Colors.grey[500],
                      fontSize: 12,
                      fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal
                  ),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FriendChatScreen(
                        friendEmail: friendEmail,
                        friendNickname: friendNickname,
                        friendProfileUrl: friendProfileUrl,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}