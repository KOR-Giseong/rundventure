# 🏃 Rundventure

소셜 기능과 게임화 요소를 갖춘 러닝 앱 - Flutter로 개발된 iOS 모바일 애플리케이션

## 📱 프로젝트 소개

Rundventure는 러닝을 더 재미있고 동기부여가 되는 경험으로 만들어주는 iOS 앱입니다. GPS 기반 러닝 트래킹, 친구와의 소셜 기능, 다양한 게임 모드를 통해 사용자들이 꾸준히 운동할 수 있도록 돕습니다.

**개발 과정**: 이 프로젝트는 처음에 Android 네이티브로 시작되었으나, 크로스 플랫폼 개발의 필요성을 느껴 **Flutter**로 전환하여 개발했습니다. Flutter를 통해 iOS와 Apple Watch까지 지원하는 단일 코드베이스로 확장할 수 있었습니다.

## ✨ 주요 기능

### 🏃 러닝 트래킹
- GPS 기반 실시간 러닝 기록
- 거리, 시간, 칼로리, 속도 추적
- 러닝 경로 지도 시각화 (Apple Maps)
- 러닝 기록 통계 및 분석

### 👥 소셜 기능
- 친구 추가 및 관리
- 친구와의 실시간 채팅
- 친구 대결 (Friend Battle)
- 친구 러닝 기록 비교

### 🎮 게임 모드
- **고스트런 (Ghost Run)**: 과거 기록과 경쟁
- **비동기 대결 (Async Battle)**: 시간대를 넘나드는 대결
- **챌린지**: 다양한 목표 달성 챌린지
- **퀘스트 시스템**: 일일/주간 퀘스트 완료

### 🏆 성취 시스템
- 배지 시스템 (거리, 칼로리, 걸음수 기반)
- 레벨 및 XP 시스템
- 랭킹 시스템 (월간/전체)
- 성취 기록 및 통계

### 📊 데이터 관리
- 러닝 기록 캘린더 뷰
- 목표 설정 및 추적
- 상세한 통계 및 그래프
- 데이터 내보내기

### ⌚ Apple Watch 지원
- 워치 앱 연동
- 실시간 러닝 데이터 표시
- Live Activity 지원
- 위젯 지원

## 🛠 기술 스택

### 프론트엔드
- **Flutter** (Dart 3.2+)
- **플랫폼**: iOS (주요), Apple Watch

### 백엔드 & 서비스
- **Firebase Authentication**: 이메일, Google, Kakao, Apple 소셜 로그인
- **Cloud Firestore**: 실시간 데이터베이스
- **Firebase Storage**: 이미지 및 미디어 저장
- **Cloud Functions**: 서버 로직 및 비즈니스 로직
- **Realtime Database**: 사용자 온라인 상태 관리
- **Cloud Messaging**: 푸시 알림
- **Firebase Analytics**: 사용자 분석

### iOS 네이티브 기능
- **Apple Maps**: 지도 표시 및 경로 추적
- **Watch Connectivity**: Apple Watch 연동
- **HealthKit**: 건강 데이터 연동 (선택사항)
- **Live Activities**: 실시간 활동 표시
- **Widgets**: 홈 화면 위젯

### 주요 패키지
- `geolocator`: GPS 위치 추적
- `apple_maps_flutter`: Apple Maps 지도 표시
- `watch_connectivity`: Apple Watch 연동
- `lottie`: 애니메이션
- `provider`: 상태 관리
- `image_picker`: 프로필 이미지 업로드
- `table_calendar`: 캘린더 UI
- 기타 30+ 패키지

## 📦 설치 및 실행

### 필수 요구사항
- macOS (Xcode 필요)
- Flutter SDK 3.2.0 이상
- Dart SDK 3.2.0 이상
- Xcode 14 이상
- iOS 13.0 이상 지원 기기
- CocoaPods

### 설치 방법

```bash
# 1. 저장소 클론
git clone https://github.com/KOR-Giseong/rundventure.git
cd rundventure

# 2. 의존성 설치
flutter pub get

# 3. iOS 의존성 설치
cd ios
pod install
cd ..

# 4. Firebase 설정
# - ios/Runner/GoogleService-Info.plist 파일 추가 필요

# 5. 앱 실행
flutter run
```

### 빌드

```bash
# iOS 디버그 빌드
flutter build ios --debug

# iOS 릴리즈 빌드
flutter build ios --release

# Xcode에서 아카이브 및 배포
# 1. Xcode에서 ios/Runner.xcworkspace 열기
# 2. Product > Archive
# 3. App Store Connect에 업로드
```

## 📁 프로젝트 구조

```
lib/
├── Achievement/          # 성취 및 퀘스트 시스템
├── admin/               # 관리자 기능
├── challenge/           # 챌린지 기능
├── free_running/        # 자유 러닝 모드
├── friends/             # 친구 관리 및 채팅
├── game_selection/      # 게임 모드 선택
├── ghostrun_screen/     # 고스트런 게임
├── home_screens/        # 홈 화면
├── login_screens/       # 로그인 화면
├── main_screens/        # 메인 화면
├── profile/             # 프로필 관리
├── RunningData_screen/  # 러닝 데이터 화면
├── services/            # 서비스 레이어
└── sign_up/             # 회원가입 화면

ios/
├── Runner/              # iOS 메인 앱
├── RundventureWatch Watch App/  # Apple Watch 앱
└── RundventureWidget/   # 위젯 확장
```

## 🎯 주요 기능 상세

### 러닝 트래킹
- 실시간 GPS 추적 (Apple Maps)
- 배터리 최적화를 위한 백그라운드 실행
- 러닝 중 잠금 화면 지원
- 러닝 완료 후 상세 결과 화면
- Apple Watch에서 직접 러닝 시작 가능

### 소셜 기능
- 친구 검색 및 추가
- 친구 요청 수락/거절
- 실시간 1:1 채팅
- 친구 프로필 조회
- 친구 대결 생성 및 참여

### 게임 모드
- **고스트런**: 과거 자신의 기록과 경쟁
- **비동기 대결**: 다른 사용자와 시간대를 넘나드는 대결
- **친구 대결**: 친구와 실시간 대결
- **챌린지**: 거리, 시간, 칼로리 기반 챌린지

### Apple Watch 통합
- 워치에서 직접 러닝 시작
- 실시간 데이터 표시
- Live Activity로 iPhone에서 진행 상황 확인
- 위젯으로 빠른 통계 확인

## 🔐 보안 및 권한

- 사용자 인증: Firebase Authentication
- 데이터 암호화: Firestore 보안 규칙
- 개인정보 보호: 프로필 공개/비공개 설정
- 관리자 시스템: 계정 정지 및 관리 기능
- iOS 권한: 위치 정보, 알림, 카메라, 사진 라이브러리

## 📱 지원 기기

- iPhone (iOS 13.0 이상)
- Apple Watch (watchOS 7.0 이상)
- iPad (호환 가능)

## 🚀 버전 정보

- 현재 버전: 1.1.0+7
- 최소 지원 iOS: 13.0
- 최소 지원 watchOS: 7.0

## 🤖 AI 도구 활용

이 프로젝트는 AI 도구를 적극적으로 활용하여 개발되었습니다:
- **Gemini**: 대부분의 코드 작성
- **Claude**: 코드 작성 및 최적화 제안
- **Cursor AI**: 리팩토링 및 코드 점검
- **ChatGPT**: 문제 해결 및 개념 학습

**개발자의 역할**:
- 프로젝트의 기능 기획 및 아키텍처 설계
- Android에서 Flutter로 전환 시 발생한 Xcode 오류 직접 해결
- AI가 생성한 코드의 이해 및 수정
- 디자인 및 UI/UX 구현 (AI 도구 활용)
- Firebase 연동 및 백엔드 로직 구현

**학습 경험**: AI 도구를 통해 Flutter와 Firebase의 다양한 기능을 학습하고, 복잡한 로직을 구현하는 방법을 익혔습니다. 특히 Android에서 Flutter로 전환하는 과정에서 발생한 네이티브 오류들을 직접 해결하며 깊이 있는 학습을 할 수 있었습니다.

## 👨‍💻 개발자

- 개발자: [Giseong Hong]
- 이메일: [ghdrltjd244142@gmail.com]
- GitHub: [KOR-Giseong]

## 📄 라이선스

이 프로젝트는 개인 포트폴리오용입니다.

## 🙏 감사의 말

이 프로젝트를 위해 사용된 오픈소스 라이브러리와 도구들에 감사드립니다.
