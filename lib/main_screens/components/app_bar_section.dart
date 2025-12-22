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

      if (mounted) {
        setState(() {
          unreadCount = snapshot.size;
        });
      }
    } catch (e) {
      if (mounted) {
        print("Firestore에서 알림 수 불러오기 실패: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
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
          Expanded(
            child: Center(
              child: Image.asset(
                'assets/images/mainrundventure2.png',
                height: 80,
              ),
            ),
          ),
          Stack(
            children: [
              SizedBox(
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
