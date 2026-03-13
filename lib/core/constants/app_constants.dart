import 'package:flutter/material.dart';
import 'app_colors.dart';

/// SharedPreferences 키 상수
class PrefKeys {
  PrefKeys._();

  static const String autoLogin = 'autoLogin';
  static const String email = 'email';
  static const String password = 'password';
  static const String watchSyncEnabled = 'watchSyncEnabled';

  /// "오늘 하루 안 보기" 공지사항 키 (날짜별 생성됨)
  static String hiddenAnnouncements(String date) =>
      'hiddenAnnouncements_$date';
}

/// 앱 전체 공통 SnackBar 스타일
class AppSnackBar {
  AppSnackBar._();

  static SnackBar success(String message) => _build(
        message: message,
        icon: Icons.check_circle_outline,
        color: AppColors.success,
      );

  static SnackBar error(String message) => _build(
        message: message,
        icon: Icons.error_outline,
        color: Colors.redAccent.shade400,
        duration: const Duration(seconds: 4),
      );

  static SnackBar info(String message) => _build(
        message: message,
        icon: Icons.info_outline,
        color: Colors.black87,
      );

  static SnackBar _build({
    required String message,
    required IconData icon,
    required Color color,
    Duration duration = const Duration(seconds: 2),
  }) {
    return SnackBar(
      content: Row(
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(15, 5, 15, 15),
      duration: duration,
    );
  }
}
