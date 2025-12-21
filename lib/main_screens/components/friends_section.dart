import 'package:flutter/material.dart';
// ▼▼▼ [수정] 'firebase_auth'와 'cloud_firestore'는 더 이상 필요하지 않으므로 삭제합니다. ▼▼▼
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// ▲▲▲ [수정] ▲▲▲

import 'package:rundventure/friends/friend_management_screen.dart';

class FriendsSection extends StatefulWidget {
  const FriendsSection({Key? key}) : super(key: key);

  @override
  _FriendsSectionState createState() => _FriendsSectionState();
}

class _FriendsSectionState extends State<FriendsSection> {
  // ▼▼▼ [삭제] '친구 요청' 버튼이 사라졌으므로 스트림과 이메일 변수가 필요 없습니다. ▼▼▼
  // final String? _myEmail = FirebaseAuth.instance.currentUser?.email;
  //
  // Stream<QuerySnapshot>? _getFriendRequestsStream() {
  //   if (_myEmail == null) {
  //     return null;
  //   }
  //   return FirebaseFirestore.instance
  //       .collection('users')
  //       .doc(_myEmail)
  //       .collection('friendRequests')
  //       .where('status', isEqualTo: 'pending')
  //       .snapshots();
  // }
  // ▲▲▲ [삭제] ▲▲▲

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10.0),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => FriendManagementScreen()),
          );
        },
        child: Container(
          // ▼▼▼ [유지] 높이 120 ▼▼▼
          height: 120,
          // ▲▲▲ [유지] ▲▲▲
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black45,
                offset: const Offset(0, 3),
                blurRadius: 6,
              ),
            ],
          ),
          child: Stack(
            children: [
              // 2. 그래디언트 오버레이 (배경 역할)
              _buildGradientOverlay(),
              // 3. 콘텐츠
              _buildContent(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGradientOverlay() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.bottomRight,
            end: Alignment.topLeft,
            colors: [
              Colors.white.withOpacity(0.6),
              Colors.white,
            ],
            stops: [0.1, 0.5],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단 콘텐츠(제목, 부제목)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- 섹션 타이틀 ---
              Row(
                children: [
                  Icon(Icons.people_alt_outlined,
                      color: Colors.black, size: 28),
                  const SizedBox(width: 10),
                  const Text(
                    '친구',
                    style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                        color: Colors.black),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              const Text(
                '친구 목록을 확인하거나 요청을 관리하세요.',
                style: TextStyle(fontSize: 14, color: Colors.black45),
              ),
            ],
          ),

          // ▼▼▼ [유지] Spacer (하단 버튼이 없어도 공간을 채우는 데 문제없음) ▼▼▼
          const Spacer(),
          // ▲▲▲ [유지] ▲▲▲

          // ▼▼▼ [삭제] '친구 요청' 배지 및 버튼 관련 Align, StreamBuilder 전체 삭제 ▼▼▼
          /*
          Align(
            alignment: Alignment.bottomRight,
            child: StreamBuilder<QuerySnapshot>(
              stream: _getFriendRequestsStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildRequestButton(requestCount: 0);
                }
                int requestCount = snapshot.data!.docs.length;
                return _buildRequestButton(requestCount: requestCount);
              },
            ),
          ),
          */
          // ▲▲▲ [삭제] ▲▲▲
        ],
      ),
    );
  }

// ▼▼▼ [삭제] _buildRequestButton 함수 전체 삭제 ▼▼▼
/*
  Widget _buildRequestButton({required int requestCount}) {
    Widget buttonContent = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '친구 요청',
          style: TextStyle(
              color: Colors.black, // 흰색 -> 검은색
              fontWeight: FontWeight.w600,
              fontSize: 15),
        ),
        const SizedBox(width: 8),
        Icon(Icons.arrow_forward_ios,
            color: Colors.black, // 흰색 -> 검은색
            size: 14),
      ],
    );

    if (requestCount > 0) {
      // 요청이 1개 이상이면 Badge 위젯 사용
      return Badge(
        label: Text('$requestCount'), // 배지 자체는 그대로 유지
        backgroundColor: Colors.redAccent,
        child: buttonContent,
      );
    } else {
      // 요청이 없으면 배지 없이 내용만 표시
      return buttonContent;
    }
  }
  */
// ▲▲▲ [삭제] ▲▲▲
}
