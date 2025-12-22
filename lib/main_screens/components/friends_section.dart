import 'package:flutter/material.dart';
import 'package:rundventure/friends/friend_management_screen.dart';

class FriendsSection extends StatefulWidget {
  const FriendsSection({Key? key}) : super(key: key);

  @override
  _FriendsSectionState createState() => _FriendsSectionState();
}

class _FriendsSectionState extends State<FriendsSection> {
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
          height: 120,
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
              _buildGradientOverlay(),
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
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

          const Spacer(),
        ],
      ),
    );
  }
}
