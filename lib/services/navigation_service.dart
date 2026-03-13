import 'package:flutter/material.dart';

/// [NavigatorState] GlobalKey를 앱 전체에서 공유합니다.
/// main.dart 에서 선언했던 navigatorKey를 이 서비스로 이전합니다.
class NavigationService {
  NavigationService._();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
}
