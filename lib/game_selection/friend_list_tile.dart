import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class FriendListTile extends StatefulWidget {
  final String friendEmail;
  final String friendNickname;
  final String? friendProfileUrl;

  // '대결 요청' 버튼이 눌렸을 때 부모(FriendBattleListScreen)의 함수를 호출할 콜백
  final Function(String email, String nickname) onBattleRequestPressed;

  const FriendListTile({
    Key? key,
    required this.friendEmail,
    required this.friendNickname,
    this.friendProfileUrl,
    required this.onBattleRequestPressed,
  }) : super(key: key);

  @override
  _FriendListTileState createState() => _FriendListTileState();
}

class _FriendListTileState extends State<FriendListTile> {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  StreamSubscription? _statusSubscription;
  bool _isOnline = false; // 친구의 온라인 상태
  bool _isLoading = true; // 상태 로딩 중

  @override
  void initState() {
    super.initState();
    _listenToFriendStatus();
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    super.dispose();
  }

  /// RTDB에서 친구의 '온라인' 상태를 실시간 구독
  void _listenToFriendStatus() {
    // 1. 이메일을 RTDB 키로 변환
    final String friendEmailKey = widget.friendEmail
        .replaceAll('.', '_dot_')
        .replaceAll('@', '_at_');

    final DatabaseReference presenceRef =
    _database.ref('status/$friendEmailKey');

    // 2. onValue (실시간 값 변경) 구독
    _statusSubscription = presenceRef.onValue.listen(
          (DatabaseEvent event) {
        if (!mounted) return;

        // 3. RTDB에서 가져온 값이 true이면 온라인
        final bool isOnline = (event.snapshot.value as bool? ?? false);

        setState(() {
          _isOnline = isOnline;
          _isLoading = false; // 로딩 완료
        });
      },
      onError: (error) {
        if (mounted) setState(() => _isLoading = false);
        print("🚨 [Presence] 친구(${widget.friendEmail}) 상태 구독 실패: $error");
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      // 1. 프로필 사진 + 온라인 상태 점
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: Colors.grey[200],
            backgroundImage: (widget.friendProfileUrl != null && widget.friendProfileUrl!.isNotEmpty)
                ? NetworkImage(widget.friendProfileUrl!)
                : AssetImage('assets/images/user.png') as ImageProvider,
          ),
          // 온라인 상태 표시 (초록불/회색불)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: _isLoading ? Colors.grey[400] : (_isOnline ? Colors.greenAccent[400] : Colors.grey[600]),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
        ],
      ),
      // 2. 닉네임 (이메일 subtitle 부분은 삭제함)
      title: Text(widget.friendNickname, style: TextStyle(fontWeight: FontWeight.w600)),

      trailing: ElevatedButton(
        onPressed: _isOnline
            ? () => widget.onBattleRequestPressed(widget.friendEmail, widget.friendNickname)
            : null, // null이면 비활성화됨
        child: Text(_isLoading ? '확인 중' : (_isOnline ? '대결 요청' : '오프라인')),
        style: ElevatedButton.styleFrom(
            backgroundColor: _isOnline ? Colors.blueAccent : Colors.grey[300],
            foregroundColor: _isOnline ? Colors.white : Colors.grey[700],
            padding: EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)
            )
        ),
      ),
    );
  }
}