import 'package:flutter/material.dart';
import 'UserService.dart'; // UserService 임포트

class UserScreen extends StatelessWidget {
  final UserService _userService = UserService();

  void _deleteAllUsers() async {
    try {
      await _userService.deleteAllUsers();
      // 삭제 후 UI 갱신
      print('모든 사용자 문서가 삭제되었습니다.');
    } catch (e) {
      // 오류 처리
      print('문서 삭제 중 오류 발생: $e');
    }
  }

  void _deleteUsersInBatch() async {
    try {
      await _userService.deleteUsersInBatch();
      // 삭제 후 UI 갱신
      print('모든 사용자 문서가 배치로 삭제되었습니다.');
    } catch (e) {
      // 오류 처리
      print('배치 삭제 중 오류 발생: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('User Management')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _deleteAllUsers, // 모든 사용자 삭제
              child: Text('모든 사용자 삭제'),
            ),
            ElevatedButton(
              onPressed: _deleteUsersInBatch, // 배치 삭제
              child: Text('배치로 사용자 삭제'),
            ),
          ],
        ),
      ),
    );
  }
}