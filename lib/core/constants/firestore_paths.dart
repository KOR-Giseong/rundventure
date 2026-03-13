/// Firestore 컬렉션/문서 경로를 상수로 관리합니다.
/// 오타 및 경로 변경 시 한 곳에서만 수정하면 됩니다.
class FirestorePaths {
  FirestorePaths._();

  // ── Users ──────────────────────────────────────────────
  static const String users = 'users';

  static String userDoc(String email) => '$users/$email';

  static String friendRequests(String email) =>
      '$users/$email/friendRequests';

  static String activeQuests(String email) =>
      '$users/$email/activeQuests';

  static String completedQuestsLog(String email) =>
      '$users/$email/completedQuestsLog';

  // ── Notifications ──────────────────────────────────────
  static const String notifications = 'notifications';

  static String notificationItems(String email) =>
      '$notifications/$email/items';

  // ── Running Data ───────────────────────────────────────
  static const String userRunningData = 'userRunningData';

  static String workouts(String email) =>
      '$userRunningData/$email/workouts';

  static String records(String email, String workoutId) =>
      '$userRunningData/$email/workouts/$workoutId/records';

  // ── Ghost Run ──────────────────────────────────────────
  static const String ghostRunRecords = 'ghostRunRecords';

  static String ghostRunUserDoc(String email) =>
      '$ghostRunRecords/$email';

  static String ghostRunUserRecords(String email) =>
      '$ghostRunRecords/$email/records';

  // ── Announcements ──────────────────────────────────────
  static const String mainAnnouncements = 'mainAnnouncements';

  // ── Chat ───────────────────────────────────────────────
  static const String userChats = 'userChats';

  // ── Board ──────────────────────────────────────────────
  static const String boardStatus = 'boardStatus';

  // ── Admin ──────────────────────────────────────────────
  static const String adminStatus = 'adminStatus';
}
