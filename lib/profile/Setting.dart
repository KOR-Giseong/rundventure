import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 👈 ✨ [수정] SharedPreferences 임포트
import 'package:cloud_functions/cloud_functions.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../home_Screens/home_screen2.dart';
import 'package:flutter/services.dart';

import 'terms_screen.dart';
import 'privacy_policy_screen.dart';
import 'customer_support_chat_screen.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({Key? key}) : super(key: key);

  @override
  _ProfileSettingsScreenState createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  String _appVersion = '';
  final TextEditingController _passwordController = TextEditingController();
  final User? currentUser = FirebaseAuth.instance.currentUser;

  bool _isSuperAdmin = false;

  // ▼▼▼▼▼ [ ✨ 1. 신규 추가 ✨ ] ▼▼▼▼▼
  bool _watchSyncEnabled = false; // 👈 Apple Watch 연동 스위치 상태
  bool _isLoadingWatchSync = true; // 👈 설정 로딩 중 상태
  // ▲▲▲▲▲ [ ✨ 1. 신규 추가 ✨ ] ▲▲▲▲▲

  final FirebaseFunctions _functions =
  FirebaseFunctions.instanceFor(region: 'us-central1');

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
    _checkSuperAdminStatus();
    _loadWatchSyncSetting(); // 👈 ✨ [수정] 워치 설정 로드
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  // ▼▼▼▼▼ [ ✨ 2. 신규 추가 ✨ ] ▼▼▼▼▼
  /// SharedPreferences에서 Apple Watch 연동 설정을 불러옵니다.
  Future<void> _loadWatchSyncSetting() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        // 'watchSyncEnabled' 키로 저장된 값을 읽어오며, 없으면 false(끄기)를 기본값으로 합니다.
        _watchSyncEnabled = prefs.getBool('watchSyncEnabled') ?? false;
        _isLoadingWatchSync = false;
      });
    }
  }

  /// Apple Watch 연동 설정을 SharedPreferences에 저장합니다.
  Future<void> _updateWatchSyncSetting(bool newValue) async {
    setState(() {
      _watchSyncEnabled = newValue;
    });
    final prefs = await SharedPreferences.getInstance();
    // 'watchSyncEnabled' 키로 새로운 값을 저장합니다.
    await prefs.setBool('watchSyncEnabled', newValue);
  }
  // ▲▲▲▲▲ [ ✨ 2. 신규 추가 ✨ ] ▲▲▲▲▲

  // (수정 없음) 슈퍼 관리자 확인
  Future<void> _checkSuperAdminStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final idTokenResult = await user.getIdTokenResult(true);
      final bool isSuper = idTokenResult.claims?['isSuperAdmin'] == true;

      if (mounted) {
        setState(() {
          _isSuperAdmin = isSuper;
        });
      }
    } catch (e) {
      print("Error fetching user claims: $e");
    }
  }

  // (수정 없음) 슈퍼 관리자 권한 부여
  Future<void> _callSetSuperAdminRole() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
      const Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
    );

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-northeast3')
          .httpsCallable('setSuperAdminRole');

      final result = await callable.call();

      if (!mounted) return;
      Navigator.pop(context);
      _showCustomSnackBar(
          result.data['message'] ?? '슈퍼 관리자 권한이 부여되었습니다.');
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showCustomSnackBar(e.message ?? '오류가 발생했습니다.', isError: true);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showCustomSnackBar(e.toString(), isError: true);
    }
  }

  // (수정 없음) 앱 버전 로드
  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _appVersion = '${info.version} (${info.buildNumber})';
    });
  }

  // (수정 없음) 커스텀 스낵바
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
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor:
        isError ? Colors.redAccent.shade400 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(15, 5, 15, 15),
      ),
    );
  }

  // (수정 없음) 비밀번호 재설정
  Future<void> _sendPasswordResetEmail() async {
    if (currentUser == null || currentUser!.email == null) {
      _showCustomSnackBar('사용자 정보를 찾을 수 없습니다.', isError: true);
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('비밀번호 재설정'),
        content: Text(
          '${currentUser!.email!}으로\n비밀번호 재설정 메일을 보내시겠습니까?',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('보내기',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.blueAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseAuth.instance
            .sendPasswordResetEmail(email: currentUser!.email!);
        _showCustomSnackBar('✅ 비밀번호 재설정 이메일을 보냈습니다.');
      } catch (e) {
        _showCustomSnackBar('이메일 전송에 실패했습니다: ${e.toString()}', isError: true);
      }
    }
  }

  // (수정 없음) 탈퇴 확인
  void _confirmDelete() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final isEmailLogin = user.providerData.first.providerId == 'password';
    _passwordController.clear();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        titlePadding: EdgeInsets.zero,
        contentPadding:
        const EdgeInsets.only(top: 10, left: 24, right: 24, bottom: 0),
        title: Column(
          children: [
            const SizedBox(height: 20),
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.red,
              size: 40,
            ),
            const SizedBox(height: 10),
            const Text(
              '정말 탈퇴하시겠어요?',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              '모든 데이터가 영구적으로 삭제되며 복구할 수 없습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            if (isEmailLogin) ...[
              const SizedBox(height: 15),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  hintText: '비밀번호를 입력하세요',
                  focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.black)),
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
                obscureText: true,
              ),
            ]
          ],
        ),
        actionsPadding: const EdgeInsets.all(16),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: Colors.black12),
                    ),
                  ),
                  child: const Text('취소',
                      style: TextStyle(
                          color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => const Center(
                          child: CircularProgressIndicator(color: Colors.black)),
                    );

                    try {
                      if (isEmailLogin) {
                        if (_passwordController.text.trim().isEmpty) {
                          Navigator.pop(context);
                          _showCustomSnackBar('비밀번호를 입력해 주세요.', isError: true);
                          return;
                        }
                        final cred = EmailAuthProvider.credential(
                            email: user.email!,
                            password: _passwordController.text.trim());
                        await user.reauthenticateWithCredential(cred);
                      } else if (user.providerData.first.providerId ==
                          'google.com') {
                        final googleUser = await GoogleSignIn().signIn();
                        if (googleUser == null) {
                          Navigator.pop(context);
                          return;
                        }
                        final googleAuth = await googleUser.authentication;
                        final cred = GoogleAuthProvider.credential(
                            accessToken: googleAuth.accessToken,
                            idToken: googleAuth.idToken);
                        await user.reauthenticateWithCredential(cred);
                      } else if (user.providerData.first.providerId ==
                          'apple.com') {
                        final appleCredential =
                        await SignInWithApple.getAppleIDCredential(
                            scopes: []);
                        final oauthCredential =
                        OAuthProvider("apple.com").credential(
                          idToken: appleCredential.identityToken,
                          accessToken: appleCredential.authorizationCode,
                        );
                        await user.reauthenticateWithCredential(oauthCredential);
                      }

                      final callable = _functions.httpsCallable('deleteUserAccount');
                      await callable.call();
                      await FirebaseAuth.instance.signOut();
                      await GoogleSignIn().signOut();
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.clear();

                      if (!mounted) return;
                      Navigator.pop(context);
                      _showCustomSnackBar('계정 탈퇴가 완료되었습니다.');

                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        Navigator.of(context, rootNavigator: true)
                            .pushAndRemoveUntil(
                          MaterialPageRoute(
                              builder: (context) => Home_screen2()),
                              (route) => false,
                        );
                      });
                    } on FirebaseAuthException catch (e) {
                      if (!mounted) return;
                      Navigator.pop(context);
                      String message = "인증에 실패했습니다. 잠시 후 다시 시도해주세요.";
                      if (e.code == 'wrong-password')
                        message = '비밀번호가 올바르지 않습니다.';
                      if (e.code == 'popup-closed-by-user' ||
                          e.code == 'cancelled') message = '인증을 취소했습니다.';
                      _showCustomSnackBar(message, isError: true);
                    } catch (e) {
                      if (!mounted) return;
                      Navigator.pop(context);
                      String errorMessage = '알 수 없는 오류가 발생했습니다.';
                      if (e is FirebaseFunctionsException) {
                        errorMessage = '오류: ${e.message}';
                      }
                      _showCustomSnackBar(errorMessage, isError: true);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('탈퇴',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // (수정 없음) 설정 아이템 위젯
  Widget _buildSettingItem({
    required String title,
    String? value,
    Color titleColor = Colors.black,
    VoidCallback? onTap,
    IconData? trailingIcon,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 5),
        decoration: const BoxDecoration(
          border: Border(
              bottom: BorderSide(color: Color(0xFFE0E0E0), width: 0.8)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                  fontSize: 16,
                  color: titleColor,
                  fontWeight: FontWeight.w500),
            ),
            Row(
              children: [
                if (value != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Text(
                      value,
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ),
                if (trailingIcon != null)
                  Icon(trailingIcon, color: Colors.grey, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isEmailLogin =
        currentUser?.providerData.first.providerId == 'password';

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
        title: const Text('설정',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black)),
        titleSpacing: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        children: [
          _buildSettingItem(
            title: '앱 버전',
            value: _appVersion,
          ),

          // ▼▼▼▼▼ [ ✨ 3. 신규 추가 (UI) ✨ ] ▼▼▼▼▼
          // SharedPreferences에서 설정을 불러오는 동안 로딩 인디케이터를 표시합니다.
          if (_isLoadingWatchSync)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 5),
              decoration: const BoxDecoration(
                border: Border(
                    bottom: BorderSide(color: Color(0xFFE0E0E0), width: 0.8)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Apple Watch 연동',
                    style: TextStyle(
                        fontSize: 16,
                        color: Colors.black,
                        fontWeight: FontWeight.w500),
                  ),
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ),
            )
          // 로딩이 끝나면 스위치 타일을 표시합니다.
          else
            Container(
              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 0),
              decoration: const BoxDecoration(
                border: Border(
                    bottom: BorderSide(color: Color(0xFFE0E0E0), width: 0.8)),
              ),
              child: SwitchListTile(
                title: const Text(
                  'Apple Watch 연동',
                  style: TextStyle(
                      fontSize: 16,
                      color: Colors.black,
                      fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  '활성화 시 Apple Watch와 연동하여 러닝을 시작합니다.',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey[600]),
                ),
                value: _watchSyncEnabled,
                onChanged: _updateWatchSyncSetting, // 👈 스위치 조작 시 저장 함수 호출
                activeColor: Colors.blueAccent,
                // 👇👇👇 [ 여기 색상 수정됨 ] 👇👇👇
                // 꺼져있을 때 색상을 깔끔한 회색/흰색 조합으로 변경
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: Colors.grey[300],
                trackOutlineColor: MaterialStateProperty.all(Colors.transparent), // 테두리 없앰
                // 👆👆👆 [ 여기까지 ] 👆👆👆
                contentPadding: const EdgeInsets.symmetric(horizontal: 5),
                visualDensity: VisualDensity.compact,
              ),
            ),
          // ▲▲▲▲▲ [ ✨ 3. 신규 추가 (UI) ✨ ] ▲▲▲▲▲

          if (isEmailLogin)
            _buildSettingItem(
              title: '비밀번호 변경',
              onTap: _sendPasswordResetEmail,
              trailingIcon: Icons.arrow_forward_ios,
            ),

          // (수정 없음) 1:1 문의하기
          _buildSettingItem(
            title: '1:1 문의하기',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const CustomerSupportChatScreen()),
              );
            },
            trailingIcon: Icons.arrow_forward_ios,
          ),

          // (수정 없음) 이용약관
          _buildSettingItem(
            title: '이용약관',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TermsScreen()),
              );
            },
            trailingIcon: Icons.arrow_forward_ios,
          ),

          // (수정 없음) 개인정보 처리방침
          _buildSettingItem(
            title: '개인정보 처리방침',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const PrivacyPolicyScreen()),
              );
            },
            trailingIcon: Icons.arrow_forward_ios,
          ),

          // (수정 없음) 오픈소스 라이선스
          _buildSettingItem(
            title: '오픈소스 라이선스',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => Scaffold(
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
                      title: const Text(
                        '오픈소스 라이선스',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black),
                      ),
                      titleSpacing: 0,
                    ),
                    body: Theme(
                      data: Theme.of(context).copyWith(
                        appBarTheme: const AppBarTheme(
                          toolbarHeight: 0,
                          elevation: 0,
                          backgroundColor: Colors.white,
                        ),
                        scaffoldBackgroundColor: Colors.white,
                        cardColor: Colors.white,
                        dividerColor: Colors.grey[200],
                      ),
                      child: LicensePage(
                        applicationName: 'Rundventure',
                        applicationVersion: _appVersion,
                      ),
                    ),
                  ),
                ),
              );
            },
            trailingIcon: Icons.arrow_forward_ios,
          ),

          // (수정 없음) 슈퍼 관리자
          if (_isSuperAdmin)
            _buildSettingItem(
              title: '슈퍼 관리자 권한 부여 (개발자 전용)',
              titleColor: Colors.blueAccent,
              onTap: _callSetSuperAdminRole,
              trailingIcon: Icons.arrow_forward_ios,
            ),

          // (수정 없음) 탈퇴하기
          _buildSettingItem(
            title: '탈퇴하기',
            titleColor: Colors.red,
            onTap: _confirmDelete,
            trailingIcon: Icons.arrow_forward_ios,
          ),

          const SizedBox(height: 50),

          // (수정 없음) 로그인 계정
          Center(
            child: Text(
              '로그인 계정: ${currentUser?.email ?? '정보 없음'}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}