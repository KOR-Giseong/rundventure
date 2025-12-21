import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../Notification/user_notification.dart';
import '../../profile/user_profile.dart';

class AppBarSection extends StatefulWidget {
  @override
  _AppBarSectionState createState() => _AppBarSectionState();
}

class _AppBarSectionState extends State<AppBarSection> {
  int unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final ref = FirebaseFirestore.instance
          .collection('notifications')
          .doc(user.email)
          .collection('items');

      final snapshot = await ref.where('isRead', isEqualTo: false).get();

      // ✅ [수정] 위젯이 화면에 있을 때만 상태를 업데이트하도록 확인
      if (mounted) {
        setState(() {
          unreadCount = snapshot.size;
        });
      }
    } catch (e) {
      // 오류가 발생해도 mounted를 확인하여 안전하게 로그를 출력할 수 있습니다.
      if (mounted) {
        print("❌ Firestore에서 알림 수 불러오기 실패: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // ✅ 1. 상하 여백(vertical)을 8에서 0으로 줄여 불필요한 공간 제거
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Profile 버튼
          SizedBox(
            // ✅ 2. 아이콘 버튼 크기를 60x60에서 50x50으로 줄임
            height: 60,
            width: 60,
            child: IconButton(
              icon: Image.asset('assets/images/user.png'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ProfileScreen()),
                );
              },
            ),
          ),
          // 로고
          Expanded(
            child: Center(
              child: Image.asset(
                'assets/images/mainrundventure2.png',
                // ✅ 3. 로고 높이를 90에서 50으로 대폭 줄임 (핵심 원인)
                height: 80,
                // width: 230, // ⬅️ width는 비율에 맞게 자동 조절되도록 주석 처리
              ),
            ),
          ),
          // 알림 아이콘 + 뱃지
          Stack(
            children: [
              SizedBox(
                // ✅ 4. 아이콘 버튼 크기를 60x60에서 50x50으로 줄임
                height: 60,
                width: 60,
                child: IconButton(
                  icon: Image.asset('assets/images/alarm.png'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => UserNotificationPage()),
                    ).then((_) {
                      // 알림 페이지에서 돌아왔을 때 다시 로드
                      _loadUnreadCount();
                    });
                  },
                ),
              ),
              if (unreadCount > 0)
                Positioned(
                  // ✅ 5. 버튼이 작아졌으므로 뱃지 위치 미세 조정
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.red,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      unreadCount.toString(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
