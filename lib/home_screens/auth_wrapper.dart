import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../home_screens/home_screen2.dart';
import '../main_screens/main_screen.dart';
import 'suspended_screen.dart';

/// 로그인 상태를 감지하여 적절한 화면으로 라우팅합니다.
///
/// - 미로그인 → [Home_screen2] (스플래시)
/// - 이메일 미인증 → [Home_screen2]
/// - 인증 완료 → [UserStatusWrapper] (정지 여부 확인 후 메인)
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          final user = snapshot.data!;
          if (!user.emailVerified) return Home_screen2();
          return const UserStatusWrapper();
        }

        return Home_screen2();
      },
    );
  }
}

/// Firestore 에서 계정 정지 여부를 확인하고 메인 화면 또는 정지 화면으로 분기합니다.
class UserStatusWrapper extends StatelessWidget {
  const UserStatusWrapper({Key? key}) : super(key: key);

  Future<DocumentSnapshot> _checkUserStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      throw Exception('로그인한 사용자가 없습니다.');
    }

    try {
      return await FirebaseFirestore.instance
          .collection('users')
          .doc(user.email!)
          .get(const GetOptions(source: Source.server));
    } on FirebaseException catch (e) {
      throw Exception('계정 상태 확인 중 오류 발생: ${e.code}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: _checkUserStatus(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return SuspendedScreen(
            reason: '계정 상태를 확인하는 중 오류가 발생했습니다. 앱을 다시 시작해주세요.',
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          FirebaseAuth.instance.signOut();
          return Home_screen2();
        }

        final data =
            snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final bool isSuspended = data['isSuspended'] ?? false;
        final String reason =
            data['suspensionReason'] ?? '관리자에 의해 계정이 정지되었습니다.';

        if (isSuspended) return SuspendedScreen(reason: reason);
        return const MainScreen(showWelcomeMessage: false);
      },
    );
  }
}
