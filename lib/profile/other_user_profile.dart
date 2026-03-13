import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:rundventure/profile/leveling_service.dart';
import 'package:rundventure/profile/report/report_user_screen.dart';
import 'package:rundventure/profile/widgets/level_bar_widget.dart';
import 'package:rundventure/Achievement/exercise_service.dart';
import 'package:rundventure/Achievement/exercise_data.dart';

import '../main_screens/main_screen.dart';
import 'widgets/other_profile_widgets.dart';


class OtherUserProfileScreen extends StatefulWidget {
  final String userEmail;
  final bool isAdminViewing;

  const OtherUserProfileScreen({
    Key? key,
    required this.userEmail,
    this.isAdminViewing = false,
  }) : super(key: key);

  @override
  _OtherUserProfileScreenState createState() => _OtherUserProfileScreenState();
}

class _OtherUserProfileScreenState extends State<OtherUserProfileScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ExerciseService _exerciseService = ExerciseService();
  late final LevelingService _levelingService;

  // User Data State
  String nickname = '사용자';
  String gender = '';
  String height = '';
  String weight = '';
  String birthdate = '';
  String? profileImageUrl;

  // 비공개 설정 상태들
  bool hideGender = true;
  bool hideHeight = true;
  bool hideWeight = true;
  bool hideBirthdate = true;

  bool hideBattleStats = true;

  bool _isLoadingProfile = true;
  bool _profileIsHidden = false;

  bool _userNotFound = false;

  // Level State
  LevelData? _levelData;
  bool _isLoadingLevel = true;

  // Achievement State
  List<AchievementInfo> _distanceAchievements = [];
  List<AchievementInfo> _stepsAchievements = [];
  List<AchievementInfo> _caloriesAchievements = [];
  bool _isLoadingAchievements = true;

  // 도전과제 목표 리스트
  final List<double> _targetDistances = [
    10, 30, 50, 100, 150, 200, 300, 400, 500
  ];
  final List<double> _targetSteps = [
    2000, 5000, 15000, 35000, 70000, 200000, 500000, 1000000, 2000000
  ];
  final List<double> _targetCalories = [
    100, 500, 1500, 3000, 5000, 8000, 15000, 30000, 50000
  ];

  // 명예의 전당 (월간 랭킹) 상태
  List<Map<String, dynamic>> _hallOfFame = [];
  // Latest Run Record State
  Map<String, dynamic>? latestRunRecord;
  bool _isLoadingLatestRun = true;

  late String _decodedEmail;

  // 친구 관계 상태 변수
  final String? _myEmail = FirebaseAuth.instance.currentUser?.email;
  String _friendshipStatus = 'loading';
  bool _isProcessingFriendAction = false;

  // 친구 대결 W/L 기록
  int _battleWins = 0;
  int _battleLosses = 0;


  @override
  void initState() {
    super.initState();
    // 이메일 디코딩
    _decodedEmail = widget.userEmail.replaceAll('_at_', '@').replaceAll('_dot_', '.');

    _levelingService = LevelingService(_firestore, _exerciseService);
    _loadAllData();
  }

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
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.redAccent.shade400 : Color(0xFFFF9F80),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(15, 5, 15, 15),
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  void _showFullProfileImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      _showCustomSnackBar("확대할 프로필 이미지가 없습니다.", isError: true);
      return;
    }

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.8),
      builder: (context) {
        return GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Dialog(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            insetPadding: EdgeInsets.all(20),
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 1.0,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[200],
                      child: Icon(Icons.error_outline, color: Colors.red, size: 50),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _loadAllData() async {
    if (mounted) {
      setState(() {
        _isLoadingProfile = true;
        _isLoadingLevel = true;
        _isLoadingAchievements = true;
        _isLoadingLatestRun = true;
        _hallOfFame = [];
        _distanceAchievements = [];
        _stepsAchievements = [];
        _caloriesAchievements = [];
        _userNotFound = false;
        _friendshipStatus = 'loading';
      });
    }

    try {
      await _loadUserData();

      if (_userNotFound) {
        if (mounted) {
          setState(() {
            _isLoadingLevel = false;
            _isLoadingAchievements = false;
            _isLoadingLatestRun = false;
            _friendshipStatus = 'none';
          });
        }
        return;
      }

      if (_myEmail != _decodedEmail && _myEmail != null) {
        await _checkFriendshipStatus();
      } else if (_myEmail == _decodedEmail) {
        if (mounted) setState(() => _friendshipStatus = 'myself');
      } else {
        if (mounted) setState(() => _friendshipStatus = 'none');
      }

      await _loadLevelData();

      if (!_profileIsHidden) {
        await Future.wait([
          _loadUserAchievements(),
          _loadLatestRunRecord(),
        ]);
      } else {
        if (mounted) {
          setState(() {
            _isLoadingAchievements = false;
            _isLoadingLatestRun = false;
          });
        }
      }
    } catch (e) {
      print("Error loading data for other user profile: $e");
      if (mounted) {
        _showCustomSnackBar('사용자 정보를 불러오는 중 오류 발생: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
          if (_profileIsHidden) {
            _isLoadingAchievements = false;
            _isLoadingLatestRun = false;
          }
        });
      }
    }
  }

  // 1. Load Basic User Profile Data
  Future<void> _loadUserData() async {
    try {
      final doc = await _firestore.collection('users').doc(_decodedEmail).get();
      if (doc.exists) {
        final data = doc.data()!;

        final bool userHideSetting = data['hideProfile'] ?? false;
        final bool shouldHide = userHideSetting && !widget.isAdminViewing;

        final bool userHideBattleStats = data['hideBattleStats'] ?? false;
        final bool shouldHideBattleStats = userHideBattleStats && !widget.isAdminViewing;

        if (mounted) {
          setState(() {
            nickname = data['nickname'] ?? '알 수 없음';
            _profileIsHidden = shouldHide;

            hideBattleStats = shouldHideBattleStats;

            _battleWins = data['battleWins'] as int? ?? 0;
            _battleLosses = data['battleLosses'] as int? ?? 0;

            if (!shouldHide) {
              gender = data['gender'] ?? '';
              height = data['height'] ?? '';
              weight = data['weight'] ?? '';
              birthdate = data['birthdate'] ?? '';
              profileImageUrl = data['profileImageUrl'];

              hideGender = (data['hideGender'] ?? false) && !widget.isAdminViewing;
              hideHeight = (data['hideHeight'] ?? false) && !widget.isAdminViewing;
              hideWeight = (data['hideWeight'] ?? false) && !widget.isAdminViewing;
              hideBirthdate = (data['hideBirthdate'] ?? false) && !widget.isAdminViewing;

              if (data['hallOfFame'] != null && data['hallOfFame'] is List) {
                _hallOfFame = List<Map<String, dynamic>>.from(
                    (data['hallOfFame'] as List)
                        .map((item) => Map<String, dynamic>.from(item)));
                _hallOfFame.sort((a, b) =>
                    (b['month'] as String? ?? '')
                        .compareTo(a['month'] as String? ?? ''));
              } else {
                _hallOfFame = [];
              }
            } else {
              profileImageUrl = data['profileImageUrl'];
              if (data['hallOfFame'] != null && data['hallOfFame'] is List) {
                _hallOfFame = List<Map<String, dynamic>>.from(
                    (data['hallOfFame'] as List)
                        .map((item) => Map<String, dynamic>.from(item)));
                _hallOfFame.sort((a, b) =>
                    (b['month'] as String? ?? '')
                        .compareTo(a['month'] as String? ?? ''));
              } else {
                _hallOfFame = [];
              }
            }
          });
        }
      } else if (mounted) {
        setState(() {
          nickname = '탈퇴한 사용자';
          _profileIsHidden = true;
          _userNotFound = true;
        });
        print("User document not found for email: $_decodedEmail");
      }
    } catch (e) {
      print("Error loading user data: $e");
      if (mounted) {
        setState(() {
          nickname = '정보 로딩 오류';
          _profileIsHidden = true;
          _userNotFound = true;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  // 2. Load User Level and XP
  Future<void> _loadLevelData() async {
    if (_userNotFound || !mounted) {
      return;
    }
    try {
      final totalXp = await _levelingService.calculateTotalXp(_decodedEmail);
      final levelData = _levelingService.calculateLevelData(totalXp);
      if (mounted) {
        setState(() {
          _levelData = levelData;
        });
      }
    } catch (e) {
      print("Error loading level data: $e");
    } finally {
      if (mounted) setState(() => _isLoadingLevel = false);
    }
  }

  // 3. Load User Achievements
  Future<void> _loadUserAchievements() async {
    if (_profileIsHidden || !mounted) {
      if (mounted) setState(() => _isLoadingAchievements = false);
      return;
    }
    try {
      final allRecords = await _getAllExerciseRecordsForUser(_decodedEmail);

      List<AchievementInfo> distAchievements = [];
      for (double target in _targetDistances) {
        distAchievements.add(_exerciseService.getAchievementInfo(
          targetValue: target,
          allRecords: allRecords,
          getValueFromRecord: (record) => record.kilometers,
        ));
      }

      List<AchievementInfo> stepsAchievements = [];
      for (double target in _targetSteps) {
        stepsAchievements.add(_exerciseService.getAchievementInfo(
          targetValue: target,
          allRecords: allRecords,
          getValueFromRecord: (record) => record.stepCount.toDouble(),
        ));
      }

      List<AchievementInfo> calAchievements = [];
      for (double target in _targetCalories) {
        calAchievements.add(_exerciseService.getAchievementInfo(
          targetValue: target,
          allRecords: allRecords,
          getValueFromRecord: (record) => record.calories,
        ));
      }

      if (mounted) {
        setState(() {
          _distanceAchievements = distAchievements.where((a) => a.isCompleted).toList();
          _stepsAchievements = stepsAchievements.where((a) => a.isCompleted).toList();
          _caloriesAchievements = calAchievements.where((a) => a.isCompleted).toList();
        });
      }
    } catch (e) {
      print("Error loading achievements: $e");
    } finally {
      if (mounted) setState(() => _isLoadingAchievements = false);
    }
  }

  Future<List<ExerciseRecord>> _getAllExerciseRecordsForUser(
      String userEmail) async {
    List<ExerciseRecord> userRecords = [];

    try {
      final workoutsSnapshot = await _firestore
          .collection('userRunningData')
          .doc(userEmail)
          .collection('workouts')
          .get();

      List<Future<QuerySnapshot>> futureList =
      workoutsSnapshot.docs.map((workoutDoc) {
        return workoutDoc.reference.collection('records').get();
      }).toList();

      final results = await Future.wait(futureList);

      for (final recordsSnapshot in results) {
        for (final recordDoc in recordsSnapshot.docs) {
          try {
            if (recordDoc.exists && recordDoc.data() != null) {
              userRecords.add(ExerciseRecord.fromFirestore(recordDoc));
            } else {
              print("Skipping empty record: ${recordDoc.id}");
            }
          } catch (e) {
            print("Error parsing record ${recordDoc.id}: $e");
          }
        }
      }
      userRecords.sort((a, b) => a.date.compareTo(b.date));
    } catch (e) {
      print("Error fetching records for $userEmail: $e");
    }
    return userRecords;
  }

  // 4. Load Latest Run Record
  Future<void> _loadLatestRunRecord() async {
    if (!mounted) {
      if (mounted) setState(() => _isLoadingLatestRun = false);
      return;
    }
    try {
      final workoutsSnapshot = await _firestore
          .collection('userRunningData')
          .doc(_decodedEmail)
          .collection('workouts')
          .orderBy(FieldPath.documentId, descending: true)
          .limit(1)
          .get();

      if (workoutsSnapshot.docs.isNotEmpty) {
        final workoutDocRef = workoutsSnapshot.docs.first.reference;
        final recordsSnapshot = await workoutDocRef
            .collection('records')
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get();

        if (recordsSnapshot.docs.isNotEmpty && mounted) {
          final recordData = recordsSnapshot.docs.first.data();

          Timestamp? recordTimestamp = recordData['timestamp'] as Timestamp?;
          recordTimestamp ??= recordData['date'] as Timestamp?;

          setState(() {
            latestRunRecord = {
              'kilometers': (recordData['kilometers'] as num? ?? 0.0).toDouble(),
              'seconds': (recordData['seconds'] as num? ?? 0).toInt(),
              'pace': (recordData['pace'] as num? ?? 0.0).toDouble(),
              'date': recordTimestamp?.toDate(),
            };
          });
        }
      }
    } catch (e) {
      print("Error loading latest run record: $e");
    } finally {
      if (mounted) setState(() => _isLoadingLatestRun = false);
    }
  }

  Future<void> _checkFriendshipStatus() async {
    if (_myEmail == null) {
      setState(() => _friendshipStatus = 'none');
      return;
    }

    if (_myEmail == _decodedEmail) {
      if (mounted) setState(() => _friendshipStatus = 'myself');
      return;
    }

    try {
      final friendDoc = await _firestore
          .collection('users')
          .doc(_myEmail)
          .collection('friends')
          .doc(_decodedEmail)
          .get();

      if (friendDoc.exists) {
        if (mounted) setState(() => _friendshipStatus = 'friends');
        return;
      }

      final sentRequestDoc = await _firestore
          .collection('users')
          .doc(_decodedEmail)
          .collection('friendRequests')
          .doc(_myEmail)
          .get();

      if (sentRequestDoc.exists && sentRequestDoc.data()?['status'] == 'pending') {
        if (mounted) setState(() => _friendshipStatus = 'pending_sent');
        return;
      }

      final receivedRequestDoc = await _firestore
          .collection('users')
          .doc(_myEmail)
          .collection('friendRequests')
          .doc(_decodedEmail)
          .get();

      if (receivedRequestDoc.exists && receivedRequestDoc.data()?['status'] == 'pending') {
        if (mounted) setState(() => _friendshipStatus = 'pending_received');
        return;
      }

      if (mounted) setState(() => _friendshipStatus = 'none');

    } catch (e) {
      print("Error checking friendship status: $e");
      if (mounted) setState(() => _friendshipStatus = 'none');
    }
  }

  Future<void> _sendFriendRequest() async {
    if (_isProcessingFriendAction) return;
    setState(() => _isProcessingFriendAction = true);

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-northeast3')
          .httpsCallable('sendFriendRequest');

      await callable.call({'recipientEmail': _decodedEmail});

      if (mounted) {
        setState(() => _friendshipStatus = 'pending_sent');
        _showCustomSnackBar("친구 요청을 보냈습니다.");
      }
    } catch (e) {
      print("Error sending friend request: $e");
      if (mounted) {
        _showCustomSnackBar("오류: 친구 요청에 실패했습니다.", isError: true);
      }
    } finally {
      if (mounted) setState(() => _isProcessingFriendAction = false);
    }
  }

  // 7-2. 친구 요청 수락하기
  Future<void> _acceptFriendRequest() async {
    if (_isProcessingFriendAction) return;
    setState(() => _isProcessingFriendAction = true);

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-northeast3')
          .httpsCallable('acceptFriendRequest');

      await callable.call({'senderEmail': _decodedEmail});

      if (mounted) {
        setState(() => _friendshipStatus = 'friends');
        _showCustomSnackBar("🎉 $nickname 님과 친구가 되었습니다.");
      }
    } catch (e) {
      print("Error accepting friend request: $e");
      if (mounted) {
        _showCustomSnackBar("오류: 요청 수락에 실패했습니다.", isError: true);
      }
    } finally {
      if (mounted) setState(() => _isProcessingFriendAction = false);
    }
  }

  // 7-3. 친구 삭제 또는 요청 거절
  Future<void> _removeOrRejectFriend(bool isRejecting) async {
    if (_isProcessingFriendAction) return;

    final bool? confirmed = await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isRejecting ? '친구 요청 거절' : '친구 삭제'),
        content: Text(isRejecting
            ? '정말로 $nickname 님의 친구 요청을 거절하시겠습니까?'
            : '정말로 $nickname 님을 친구 목록에서 삭제하시겠습니까?'),
        actions: [
          TextButton(
            child: Text('취소'),
            onPressed: () => Navigator.pop(dialogContext, false),
          ),
          TextButton(
            child: Text(isRejecting ? '거절' : '삭제', style: TextStyle(color: Colors.red)),
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessingFriendAction = true);

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-northeast3')
          .httpsCallable('rejectOrRemoveFriend');

      await callable.call({'friendEmail': _decodedEmail});

      if (mounted) {
        setState(() => _friendshipStatus = 'none');
        _showCustomSnackBar(isRejecting ? "요청을 거절했습니다." : "친구 목록에서 삭제했습니다.");
      }
    } catch (e) {
      print("Error removing/rejecting friend: $e");
      if (mounted) {
        _showCustomSnackBar("오류: 작업에 실패했습니다.", isError: true);
      }
    } finally {
      if (mounted) setState(() => _isProcessingFriendAction = false);
    }
  }


  String _formatDuration(int totalSeconds) {
    if (totalSeconds < 0) return "00:00";
    final duration = Duration(seconds: totalSeconds);
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return "$hours:$minutes:$seconds";
    } else {
      return "$minutes:$seconds";
    }
  }

  String _formatPace(double pace) {
    if (pace.isInfinite || pace.isNaN || pace <= 0) return '--:--';
    final minutes = pace.floor();
    final seconds = ((pace - minutes) * 60).round();
    return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy.MM.dd HH:mm');

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.grey[100],
        scrolledUnderElevation: 0.0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Image.asset(
              'assets/images/Back-Navs.png',
              width: 50,
              height: 50,
            ),
          ),
        ),
        title: Text(
          _isLoadingProfile
              ? '프로필 로딩 중...'
              : _userNotFound
              ? '알 수 없는 사용자'
              : '$nickname 프로필',
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black87),
        ),
        centerTitle: true,
        actions: [
          if (_friendshipStatus != 'myself' && !_userNotFound)
            IconButton(
              iconSize: 26.0,
              icon: const Icon(Icons.flag_outlined, color: Colors.red),
              tooltip: '사용자 신고',
              onPressed: () {
                if (!_isLoadingProfile) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ReportUserScreen(
                        reportedUserEmail: _decodedEmail,
                        reportedUserNickname: nickname,
                      ),
                    ),
                  );
                }
              },
            ),
          IconButton(
            iconSize: 28.0,
            icon: const Icon(Icons.home_outlined, color: Colors.black87),
            tooltip: '메인 화면',
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const MainScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _loadAllData,
          color: Colors.white,
          backgroundColor: Colors.black54,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // --- Profile Header ---
                  _isLoadingProfile
                      ? SizedBox(
                      height: 130,
                      child: Center(child: CircularProgressIndicator()))
                      : Column(
                    children: [
                      GestureDetector(
                        onLongPress: () {
                          if (!_userNotFound) {
                            _showFullProfileImage(profileImageUrl);
                          }
                        },
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.grey[300],
                          backgroundImage: (profileImageUrl != null &&
                              profileImageUrl!.isNotEmpty)
                              ? NetworkImage(profileImageUrl!)
                              : AssetImage('assets/images/user.png')
                          as ImageProvider,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(nickname,
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                    ],
                  ),

                  // --- Level Bar ---
                  _isLoadingProfile
                      ? SizedBox(height: 20)
                      : _userNotFound
                      ? const ProfilePrivateLevelBar()
                      : _profileIsHidden
                      ? const ProfilePrivateLevelBar()
                      : LevelBarWidget(
                    levelData: _levelData,
                    isLoading: _isLoadingLevel,
                    isOtherUserProfile: true,
                  ),

                  if (!_isLoadingProfile && !_profileIsHidden && !_userNotFound && !hideBattleStats)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.grey.withOpacity(0.1),
                                  spreadRadius: 1,
                                  blurRadius: 3,
                                  offset: Offset(0, 2))
                            ]
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            buildWLStatColumn('총 대결', '${_battleWins + _battleLosses} 회'),
                            buildWLStatColumn('승리', '$_battleWins 회', color: Colors.blueAccent),
                            buildWLStatColumn('패배', '$_battleLosses 회', color: Colors.redAccent),
                          ],
                        ),
                      ),
                    ),

                  if (!_userNotFound) _buildFriendshipButton(),

                  const SizedBox(height: 20),

                  // --- 비공개 또는 공개 프로필 ---
                  _isLoadingProfile
                      ? Container()
                      : _userNotFound
                      ? const ProfileWithdrawnMessage()
                      : _profileIsHidden
                      ? const ProfilePrivateMessage()
                      : _buildPublicProfileDetails(dateFormat),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFriendshipButton() {
    if (_friendshipStatus == 'loading' || _friendshipStatus == 'myself' || _myEmail == _decodedEmail) {
      return SizedBox(height: 20);
    }

    if (_isProcessingFriendAction) {
      return Padding(
        padding: const EdgeInsets.only(top: 16.0),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    switch (_friendshipStatus) {
      case 'none':
        return Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: ElevatedButton.icon(
            icon: Icon(Icons.person_add_alt_1_outlined, size: 20),
            label: Text('친구 추가'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              minimumSize: Size(double.infinity, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _sendFriendRequest,
          ),
        );

      case 'pending_sent':
        return Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: ElevatedButton.icon(
            icon: Icon(Icons.check, size: 20),
            label: Text('요청 보냄'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[300],
              foregroundColor: Colors.grey[700],
              minimumSize: Size(double.infinity, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: null,
          ),
        );

      case 'pending_received':
        return Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Column(
              children: [
                Text('$nickname 님이 친구 요청을 보냈습니다.', style: TextStyle(color: Colors.grey[700])),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        child: Text('거절'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[200],
                          foregroundColor: Colors.black87,
                          minimumSize: Size(0, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => _removeOrRejectFriend(true),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        child: Text('수락'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          minimumSize: Size(0, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _acceptFriendRequest,
                      ),
                    ),
                  ],
                ),
              ],
            )
        );

      case 'friends':
        return Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: ElevatedButton.icon(
            icon: Icon(Icons.person_remove_outlined, size: 20),
            label: Text('친구 삭제'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent[100],
              foregroundColor: Colors.red[800],
              minimumSize: Size(double.infinity, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => _removeOrRejectFriend(false),
          ),
        );

      default:
        return SizedBox(height: 20);
    }
  }

  Widget _buildPublicProfileDetails(DateFormat dateFormat) {
    final bool hasNoAchievements = _distanceAchievements.isEmpty &&
        _stepsAchievements.isEmpty &&
        _caloriesAchievements.isEmpty;

    return Column(
      children: [
        const Divider(thickness: 0.8),
        const SizedBox(height: 20),

        Align(
            alignment: Alignment.centerLeft,
            child: Text('달성 기록',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
        const SizedBox(height: 12),
        _isLoadingAchievements
            ? SizedBox(
            height: 50, child: Center(child: CircularProgressIndicator()))
            : hasNoAchievements
            ? Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12)),
          child: Center(
              child: Text('아직 달성한 기록이 없습니다.',
                  style: TextStyle(color: Colors.grey[600]))),
        )
            : Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: Offset(0, 2))
              ]),
          child: Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            alignment: WrapAlignment.start,
            children: [
              ..._distanceAchievements
                  .map((ach) => Chip(
                avatar: Image.asset(
                  _getIconForDistance(ach.targetValue),
                  width: 18,
                  height: 18,
                ),
                label: Text('${ach.targetValue.toInt()}km',
                    style:
                    TextStyle(fontWeight: FontWeight.w500)),
                backgroundColor: Colors.green[50],
                side: BorderSide(
                    color: Colors.green.withOpacity(0.3)),
                padding: EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
              ))
                  .toList(),

              ..._stepsAchievements
                  .map((ach) => Chip(
                avatar: Image.asset(
                  _getIconForSteps(ach.targetValue),
                  width: 18,
                  height: 18,
                ),
                label: Text(_formatSteps(ach.targetValue),
                    style:
                    TextStyle(fontWeight: FontWeight.w500)),
                backgroundColor: Colors.blue[50],
                side: BorderSide(
                    color: Colors.blue.withOpacity(0.3)),
                padding: EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
              ))
                  .toList(),

              ..._caloriesAchievements
                  .map((ach) => Chip(
                avatar: Image.asset(
                  _getIconForCalories(ach.targetValue),
                  width: 18,
                  height: 18,
                ),
                label: Text('${ach.targetValue.toInt()}kcal',
                    style:
                    TextStyle(fontWeight: FontWeight.w500)),
                backgroundColor: Colors.red[50],
                side: BorderSide(
                    color: Colors.red.withOpacity(0.3)),
                padding: EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
              ))
                  .toList(),
            ],
          ),
        ),

        _buildHallOfFameSection(),

        const SizedBox(height: 24),
        const Divider(thickness: 0.8),
        const SizedBox(height: 20),

        Align(
            alignment: Alignment.centerLeft,
            child: Text('기본 정보',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
        const SizedBox(height: 12),
        _isLoadingProfile
            ? SizedBox(
            height: 100, child: Center(child: CircularProgressIndicator()))
            : Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 8.0),
                child: _buildInfoList())),
        const SizedBox(height: 24),
        const Divider(thickness: 0.8),
        const SizedBox(height: 20),

        Align(
            alignment: Alignment.centerLeft,
            child: Text('최근 활동',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
        const SizedBox(height: 12),
        _isLoadingLatestRun
            ? SizedBox(
            height: 70, child: Center(child: CircularProgressIndicator()))
            : latestRunRecord == null
            ? Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12)),
          child: Center(
              child: Text('최근 러닝 기록이 없습니다.',
                  style: TextStyle(color: Colors.grey[600]))),
        )
            : Card(
            elevation: 0,
            margin: EdgeInsets.zero,
            color: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: Icon(Icons.directions_run_rounded,
                  color: Colors.blueAccent, size: 28),
              title: Text(
                  '${(latestRunRecord?['kilometers'] as double? ?? 0.0).toStringAsFixed(2)} km / ${_formatDuration(latestRunRecord?['seconds'] as int? ?? 0)}',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 16)),
              subtitle: Text(
                  '페이스: ${_formatPace(latestRunRecord?['pace'] as double? ?? 0.0)}' +
                      (latestRunRecord?['date'] != null
                          ? '\n${dateFormat.format(latestRunRecord!['date'])}'
                          : ''),
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                      height: 1.4)),
              isThreeLine: latestRunRecord?['date'] != null,
            )),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildHallOfFameSection() {
    if (_hallOfFame.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '명예의 전당 (월간 랭킹)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: Offset(0, 2),
                )
              ],
            ),
            child: Column(
              children: _hallOfFame.map((entry) {
                final rank = (entry['rank'] as num?)?.toInt() ?? 0;
                final month = entry['month'] as String? ?? '????-??';
                final exp = (entry['exp'] as num?)?.toInt() ?? 0;
                return buildHallOfFameListItem(
                    rank: rank, title: '$month 월간 랭킹', exp: exp);
              }).toList(),
            ),
          ),
        ],
      );
    }
    return Container();
  }


  Widget _buildInfoList() {
    List<Widget> infoWidgets = [];
    bool firstItemAdded = false;

    if (!hideGender && gender.isNotEmpty) {
      infoWidgets.add(buildProfileInfoRow(Icons.person_outline_rounded, '성별', gender));
      firstItemAdded = true;
    }
    if (!hideHeight && height.isNotEmpty) {
      if (firstItemAdded)
        infoWidgets.add(const Divider(height: 1, thickness: 0.5));
      infoWidgets.add(buildProfileInfoRow(Icons.height_rounded, '키', '$height cm'));
      firstItemAdded = true;
    }
    if (!hideWeight && weight.isNotEmpty) {
      if (firstItemAdded)
        infoWidgets.add(const Divider(height: 1, thickness: 0.5));
      infoWidgets
          .add(buildProfileInfoRow(Icons.monitor_weight_outlined, '체중', '$weight kg'));
      firstItemAdded = true;
    }
    if (!hideBirthdate && birthdate.isNotEmpty) {
      if (firstItemAdded)
        infoWidgets.add(const Divider(height: 1, thickness: 0.5));
      infoWidgets
          .add(buildProfileInfoRow(Icons.cake_outlined, '생년월일', birthdate));
      firstItemAdded = true;
    }

    if (infoWidgets.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child:
        Text('공개된 기본 정보가 없습니다.', style: TextStyle(color: Colors.grey[600])),
      );
    }
    return ListBody(children: infoWidgets);
  }

  String _getIconForDistance(double targetDistance) {
    if (targetDistance <= 10) return 'assets/badges/10km.png';
    if (targetDistance <= 30) return 'assets/badges/30km.png';
    if (targetDistance <= 50) return 'assets/badges/50km.png';
    if (targetDistance <= 100) return 'assets/badges/100km.png';
    if (targetDistance <= 150) return 'assets/badges/150km.png';
    if (targetDistance <= 200) return 'assets/badges/200km.png';
    if (targetDistance <= 300) return 'assets/badges/300km.png';
    if (targetDistance <= 400) return 'assets/badges/400km.png';
    return 'assets/badges/500km.png';
  }

  String _getIconForSteps(double targetValue) {
    if (targetValue <= 2000) return 'assets/badges/2000.png';
    if (targetValue <= 5000) return 'assets/badges/5000.png';
    if (targetValue <= 15000) return 'assets/badges/15000.png';
    if (targetValue <= 35000) return 'assets/badges/35000.png';
    if (targetValue <= 70000) return 'assets/badges/70000.png';
    if (targetValue <= 200000) return 'assets/badges/200000.png';
    if (targetValue <= 500000) return 'assets/badges/500000.png';
    if (targetValue <= 1000000) return 'assets/badges/1000000.png';
    return 'assets/badges/2000000.png';
  }

  String _getIconForCalories(double targetValue) {
    if (targetValue <= 100) return 'assets/badges/100Kcal.png';
    if (targetValue <= 500) return 'assets/badges/500Kcal.png';
    if (targetValue <= 1500) return 'assets/badges/1500Kcal.png';
    if (targetValue <= 3000) return 'assets/badges/3000Kcal.png';
    if (targetValue <= 5000) return 'assets/badges/5000Kcal.png';
    if (targetValue <= 8000) return 'assets/badges/8000Kcal.png';
    if (targetValue <= 15000) return 'assets/badges/15000Kcal.png';
    if (targetValue <= 30000) return 'assets/badges/30000Kcal.png';
    return 'assets/badges/50000Kcal.png';
  }

  String _formatSteps(double steps) {
    final formatter = NumberFormat('#,###');

    if (steps >= 1000000) {
      return '${(steps / 1000000).toStringAsFixed(0)}백만보';
    }

    if (steps >= 10000) {
      double value = steps / 10000;

      if (value == value.toInt()) {
        return '${value.toInt()}만보';
      }

      return '${value.toStringAsFixed(1)}만보';
    }

    return '${formatter.format(steps)}보';
  }

}