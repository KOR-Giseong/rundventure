import 'package:flutter/material.dart';

/// 앱 전체 색상 팔레트를 한 곳에서 관리합니다.
class AppColors {
  AppColors._();

  // ── Brand ───────────────────────────────────────────────
  static const Color primary = Color(0xFFFF9F80);
  static const Color primaryDark = Color(0xFFFF7043);
  static const Color background = Color(0xFFF9F9F9);

  // ── Semantic ────────────────────────────────────────────
  static const Color success = Color(0xFFFF9F80);  // snackbar 성공
  static const Color error = Colors.redAccent;
  static const Color warning = Colors.orangeAccent;

  // ── Text ────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textWhite = Colors.white;

  // ── Notification Badge ───────────────────────────────────
  static const Color badge = Colors.redAccent;

  // ── Admin Card ───────────────────────────────────────────
  static const Color adminCard = Colors.redAccent;
}
