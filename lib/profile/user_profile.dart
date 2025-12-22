import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_database/firebase_database.dart';

import 'package:rundventure/home_screens/home_screen2.dart';
import 'package:rundventure/main_screens/main_screen.dart';
import 'package:rundventure/login_screens/login_screen.dart';
import '../Achievement/achievements_popup.dart';
import 'Setting.dart';
import 'customer_support_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:rundventure/Achievement/exercise_service.dart';
import 'package:rundventure/profile/leveling_service.dart';
import 'package:rundventure/profile/widgets/level_bar_widget.dart';
import 'package:intl/intl.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  late TextEditingController _nicknameController;
  late TextEditingController _emailController;
  late String _selectedGender;
  late TextEditingController _weightController;
  late TextEditingController _heightController;
  late TextEditingController _birthdateController;
  late String _originalNickname;
  String? _profileImageUrl;
  bool _isNicknameChecked = false;

  // --- 개인 정보 비공개 설정 ---
  bool _hideGender = false;
  bool _hideHeight = false;
  bool _hideWeight = false;
  bool _hideBirthdate = false;
  bool _hideProfile = false;

  bool _hideBattleStats = false;

  String? _userUid;

  // --- 레벨 시스템 ---
  late final LevelingService _levelingService;
  final ExerciseService _exerciseService = ExerciseService();
  LevelData? _levelData;
  bool _isLoadingStats = true;

  // --- 친구 대결 W/L 기록 ---
  int _battleWins = 0;
  int _battleLosses = 0;

  // --- 대결 기록 UI 토글 ---
  bool _showBattleStats = false;

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController();
    _emailController = TextEditingController();
    _selectedGender = '남자';
    _weightController = TextEditingController();
    _heightController = TextEditingController();
    _birthdateController = TextEditingController();
    _originalNickname = '';

    _levelingService = LevelingService(_firestore, _exerciseService);

    _fetchUserData().then((_) {
      _nicknameController.addListener(() {
        final isChanged = _nicknameController.text.trim().toLowerCase() != _originalNickname.toLowerCase();
        if (isChanged && _isNicknameChecked && mounted) {
          setState(() {
            _isNicknameChecked = false;
          });
        }
      });
    });
  }

  // (금칙어 체크 함수 - 변경 없음)
  bool _containsBadWords(String text) {
    const bannedWords = [       'ㅅ1발', 'ㅆ1발', '시1발', '씨1발', 'ㅅㅣ발', '시8', '십팔', '시바', '시방', '시빨',
      'ㅄ', '븅1신', '병1신', '븅신', 'ㅂ1신', '븅신아', '미1친', '미ㅊ', '미쳣', '미췬', '미췬놈', '미췬년',
      'ㅈㄴ', '존1나', '존내', '존니', '좆같', '좇같', '좃같', 'ㅈ같', 'ㅈ1같', '조온나', '조카', '조까',
      'ㅈㄹ', 'ㅈㄴ', 'ㅈㅣ랄', '지1랄', '지릴', 'ㅉㄹ', '쥰나', '줸나',
      '개같', '개지랄', '개같은', '개가튼', '개같네', '개소리', '개빡', '개노답', '개멍청', '개저씨',
      '꺼지', '꺼졍', '꺼져라', '꺼저', 'ㅃㅃ', 'ㅂㅂ', 'ㅂㅃ',
      '닥쳐라', '입닥', '입닥쳐라', '입다물어', '입닫아라',
      '대가리깨', '대가리박', '멍청', '빠가야로', '쪼다', '등신새끼', '멍충', '머갈',
      '뒤져라', '뒤져버려', '죽일', '죽여버려', '죽여라', '죽는다', '자살', '자살해', '목매', '목졸', '목따',
      '엠창', '엠생', '엠병', '옘병', '연병', '엠창같은', '엠병할',
      '느금마', '느그엄마', '느그애미', '느그아비', '니미럴', '니미', '니애미', '니아비',
      '섹스', '성관계', '자위', '오나홀', '콘돔', '딜도', '야동', '에로', '야설', 'porn', 'av', '야사', '야게임', '후장',
      '좆물', '보지', '자지', '가슴', '유두', '유방', '젖', '페니스', 'vagina', 'penis', 'sex', 'fuck', 'suck', 'cum', 'anal', 'orgasm', 'rape', 'horny', 'pornhub', 'xx',
      '딸딸이', '딸침', '야짤', '야사', '변태', '에로틱',
      '병신같', '틀딱', '한남', '김치녀', '된장녀', '맘충', '급식충', '정신병자', '홍어', '짱깨', '쪽바리', '메갈', '워마드', '일베', '패미',
      '게이', '레즈', '호모', '트젠', '트랜스', 'lgbt', 'nigger', 'nigga', 'jap', 'chink', 'gook',
      '대통령', '윤석열', '문재인', '민주당', '국민의힘', '정치', '정치인',
      '예수', '기독교', '교회', '불교', '이슬람', '알라', '하느님', '하나님', '신앙', '종교', '하렘',
      'f*ck', 'f**k', 'f@ck', 'phuck', 'fcuk', 'f0ck',
      'sh*t', 'sh1t', 'b!tch', 'b1tch', 'bi7ch', 'sex', 'SEX', '@sshole', 'a55hole',
      'd1ck', 'd!ck', 'd1ldo', 'p0rn', 'p0rno', 'p*rn', 'b00bs', 'b0obs', 'c0ck',
      'p*ssy', 'p@ssy', 'pu55y', '5uck', '5ex', 's3x', 'c*nt', 'k1ll', 'k!ll',
      '짭새', '짭놈', '간나', '걸레', '잡놈', '잡년', '창녀', '창남', '빠구리', '빠굴', '빠구',
      '씹', '씹덕', '씹새', '씹년', '씹놈', '씹할', '씹치', '씹물', '씹선비', '씹덕후',
      'ㅅㅂㄹㅁ', 'ㅅㅂㅁ', 'ㅂㅅㄴ', 'ㅅㄲ', 'ㅅㄴ', 'ㅈ밥', 'ㅈ같', 'ㅂㅅ같', 'ㅂㅅ새끼',
      '존맛탱', '개존맛', '개쩔', '쩐다', '노답', '뇌절', '개극혐', '극혐', '더럽', '더러운년',
      '불태워', '칼로', '찌른다', '죽인다', '테러', '폭탄', '폭발', '살인', '총맞', '총쏴',
      '목따', '목자른다', '피범벅', '참수', '수류탄', '핵폭탄', 'nuke',
      'naver', 'gmail', 'daum', 'kakao', 'line', 'tiktok', 'instagram', 'facebook', 'twitter', 'youtube', '텔레그램', '카톡', '전화번호', '@', 'dot', 'com'
    ];
    final cleanedText = text
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(RegExp(r'[^\wㄱ-ㅎ가-힣]'), '')
        .toLowerCase();
    return bannedWords.any((word) => cleanedText.contains(word));
  }

  Future<void> _fetchUserData() async {
    final User? user = _auth.currentUser;
    if (user != null) {
      final email = user.email;
      _userUid = user.uid;
      if (email != null) {
        try {
          final doc = await _firestore.collection('users').doc(email).get();
          if (doc.exists && mounted) {
            final userData = doc.data();
            setState(() {
              _nicknameController.text = userData?['nickname'] ?? '';
              _originalNickname = userData?['nickname'] ?? '';
              _selectedGender = userData?['gender'] ?? '남자';
              _weightController.text = userData?['weight']?.toString() ?? '';
              _heightController.text = userData?['height']?.toString() ?? '';
              _birthdateController.text = userData?['birthdate'] ?? '';
              _emailController.text = email;
              _profileImageUrl = userData?['profileImageUrl'];

              // 비공개 설정 불러오기
              _hideGender = userData?['hideGender'] ?? false;
              _hideHeight = userData?['hideHeight'] ?? false;
              _hideWeight = userData?['hideWeight'] ?? false;
              _hideBirthdate = userData?['hideBirthdate'] ?? false;
              _hideProfile = userData?['hideProfile'] ?? false;

              _hideBattleStats = userData?['hideBattleStats'] ?? false;

              _battleWins = userData?['battleWins'] as int? ?? 0;
              _battleLosses = userData?['battleLosses'] as int? ?? 0;
            });
          } else if (mounted) {
            print("User document not found for email: $email");
            setState(() {
              _originalNickname = '';
            });
          }

          if (mounted) {
            _loadLevelData(email);
          }

        } catch (error) {
          print("Error fetching user data: $error");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('프로필 정보를 불러오는 중 오류가 발생했습니다.'))
            );
            setState(() {
              _originalNickname = '';
            });
          }
        }
      } else if (mounted) {
        print("User email is null.");
        setState(() {
          _originalNickname = '';
        });
      }
    } else if (mounted) {
      print("User is not logged in.");
      setState(() {
        _originalNickname = '';
      });
    }
  }

  Future<void> _loadLevelData(String email) async {
    if (!mounted) return;
    setState(() => _isLoadingStats = true);
    try {
      final totalXp = await _levelingService.calculateTotalXp(email);
      final levelData = _levelingService.calculateLevelData(totalXp);

      if (mounted) {
        setState(() {
          _levelData = levelData;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      print("레벨 데이터 로딩 실패: $e");
      if (mounted) {
        setState(() => _isLoadingStats = false);
      }
    }
  }

  Future<void> _pickAndUploadImage() async {
    final User? user = _auth.currentUser;
    if (user == null || user.uid == null) {
      _showCustomSnackBar("로그인이 필요합니다.", isError: true);
      return;
    }
    final email = user.email!;
    final uid = user.uid;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.symmetric(vertical: 10.0),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Text(
                  '프로필 이미지 변경',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Icon(Icons.photo_library_outlined, color: Color(0xFFFF9F80)),
                title: const Text('갤러리에서 선택', style: TextStyle(fontWeight: FontWeight.w500)),
                contentPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    final pickedFile = await _picker.pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 80,
                    );
                    if (pickedFile == null || !mounted) return;
                    File imageFile = File(pickedFile.path);

                    _showCustomSnackBar('이미지 업로드 중...');

                    String fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
                    final storageRef = FirebaseStorage.instance
                        .ref()
                        .child('profile_images')
                        .child(uid)
                        .child(fileName);

                    UploadTask uploadTask = storageRef.putFile(imageFile);
                    TaskSnapshot snapshot = await uploadTask;
                    String imageUrl = await snapshot.ref.getDownloadURL();

                    imageUrl = imageUrl + '?v=${DateTime.now().millisecondsSinceEpoch}';

                    await _firestore.collection('users').doc(email).set({
                      'profileImageUrl': imageUrl,
                    }, SetOptions(merge: true));

                    if (mounted) {
                      setState(() {
                        _profileImageUrl = imageUrl;
                      });
                      _showCustomSnackBar('프로필 이미지가 업데이트되었습니다.');
                    }

                  } catch (e) {
                    print("Error picking/uploading image: $e");
                    if (mounted) {
                      if (e is FirebaseException && e.code == 'permission-denied') {
                        _showCustomSnackBar('오류: 이미지 업로드 권한이 없습니다. Storage 규칙을 확인하세요.', isError: true);
                      } else if (e is FirebaseException && e.code == 'object-not-found') {
                        _showCustomSnackBar('오류: 업로드 경로를 찾을 수 없습니다. Storage 규칙을 확인하세요.', isError: true);
                      } else {
                        _showCustomSnackBar('이미지 처리 중 오류 발생', isError: true);
                      }
                    }
                  }
                },
              ),
              ListTile(
                leading: Icon(Icons.person_remove_outlined, color: Colors.redAccent[400]),
                title: Text(
                  '기본 이미지로 변경',
                  style: TextStyle(fontWeight: FontWeight.w500, color: Colors.redAccent[400]),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    await _firestore.collection('users').doc(email).update({
                      'profileImageUrl': FieldValue.delete(),
                    });

                    if (mounted) {
                      setState(() {
                        _profileImageUrl = null;
                      });
                      _showCustomSnackBar('기본 이미지로 변경되었습니다.');
                    }
                  } catch (e) {
                    print("Error setting default image: $e");
                    if (mounted) {
                      _showCustomSnackBar('기본 이미지 변경 실패', isError: true);
                    }
                  }
                },
              ),
              const Divider(height: 1, indent: 24, endIndent: 24, thickness: 0.5),
              ListTile(
                leading: Icon(Icons.close_rounded, color: Colors.grey[700]),
                title: Text(
                  '취소',
                  style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[700]),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                onTap: () => Navigator.pop(context),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Future<void> _logout() async {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text(
            '로그아웃 하시겠어요?',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: const Text(
            '다시 로그인할 때까지 자동 로그인이 해제됩니다.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          actionsAlignment: MainAxisAlignment.spaceAround,
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          actions: <Widget>[
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: Colors.black12),
                      ),
                    ),
                    child: Text('취소', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(dialogContext);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (context) => Home_screen2()),
                                (Route<dynamic> route) => false,
                          );
                        }
                      });

                      await Future.delayed(const Duration(milliseconds: 100));

                      try {
                        final currentUser = _auth.currentUser;
                        if (currentUser != null && currentUser.email != null) {
                          final uid = currentUser.uid;
                          final email = currentUser.email!;
                          final emailKey = email.replaceAll('.', '_dot_').replaceAll('@', '_at_');
                          final userStatusRef = FirebaseDatabase.instance.ref('status/$emailKey');
                          await userStatusRef.set(false);

                          final adminStatusRef = FirebaseDatabase.instance.ref('adminStatus/$uid');
                          await adminStatusRef.remove();
                        }

                        final prefs = await SharedPreferences.getInstance();
                        await prefs.remove('autoLogin');
                        await prefs.remove('email');
                        await prefs.remove('password');
                        await prefs.remove('loginMethod');

                        await _auth.signOut();

                      } catch (e) {
                        print("Error during background logout cleanup: $e");
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    child: Text('로그아웃', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _showResultDialog(String title, String content) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(title),
        content: Text(content),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
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

  Future<void> _checkNickname() async {
    final nickname = _nicknameController.text.trim();
    final lowercaseNickname = nickname.toLowerCase();

    if (nickname.isEmpty) {
      _showResultDialog('입력 오류', '닉네임을 입력해주세요.');
      return;
    }
    if (nickname.length < 2 || nickname.length > 10) {
      _showResultDialog('입력 오류', '닉네임은 2자 이상 10자 이하로 입력해주세요.');
      return;
    }
    if (_containsBadWords(nickname)) {
      _showResultDialog('사용 불가', '부적절한 닉네임은 사용할 수 없습니다.');
      return;
    }

    if (lowercaseNickname == _originalNickname.toLowerCase()) {
      if (mounted) setState(() => _isNicknameChecked = true);
      _showResultDialog('닉네임 확인', '현재 사용 중인 닉네임입니다.');
      return;
    }

    try {
      final doc = await _firestore.collection('nicknames').doc(lowercaseNickname).get();

      if (doc.exists) {
        if (mounted) setState(() => _isNicknameChecked = false);
        _showResultDialog('닉네임 확인', '이미 사용 중인 닉네임입니다.');
      } else {
        if (mounted) setState(() => _isNicknameChecked = true);
        _showResultDialog('닉네임 확인', '사용 가능한 닉네임입니다!');
      }
    } catch (e) {
      print("Error checking nickname: $e");
      if (mounted) setState(() => _isNicknameChecked = false);
      _showResultDialog('오류', '닉네임 확인 중 오류가 발생했습니다.');
    }
  }

  Future<void> _saveProfile() async {
    final User? user = _auth.currentUser;
    if (user == null || user.email == null) {
      _showCustomSnackBar('사용자 정보를 찾을 수 없습니다. 다시 로그인해주세요.', isError: true);
      return;
    }
    final email = user.email!;

    final newNickname = _nicknameController.text.trim();
    final newLowercaseNickname = newNickname.toLowerCase();
    final originalLowercaseNickname = _originalNickname.toLowerCase();

    if (newNickname.isEmpty) {
      _showCustomSnackBar('닉네임을 입력해주세요.', isError: true);
      return;
    }
    if (newNickname.length < 2 || newNickname.length > 10) {
      _showCustomSnackBar('닉네임은 2자 이상 10자 이하로 입력해주세요.', isError: true);
      return;
    }
    if (_containsBadWords(newNickname)) {
      _showCustomSnackBar('부적절한 닉네임은 사용할 수 없습니다.', isError: true);
      return;
    }

    if (newLowercaseNickname != originalLowercaseNickname && !_isNicknameChecked) {
      _showCustomSnackBar('닉네임 중복 확인을 해주세요.', isError: true);
      return;
    }

    final heightValue = double.tryParse(_heightController.text);
    final weightValue = double.tryParse(_weightController.text);
    if (_heightController.text.isNotEmpty && (heightValue == null || heightValue <= 0)) {
      _showCustomSnackBar('올바른 키(숫자)를 입력해주세요.', isError: true);
      return;
    }
    if (_weightController.text.isNotEmpty && (weightValue == null || weightValue <= 0)) {
      _showCustomSnackBar('올바른 체중(숫자)를 입력해주세요.', isError: true);
      return;
    }

    _showCustomSnackBar('프로필 저장 중...');

    try {
      double bmi = (heightValue != null && heightValue > 0 && weightValue != null)
          ? weightValue / ((heightValue / 100) * (heightValue / 100))
          : 0;

      Map<String, dynamic> updateData = {
        'gender': _selectedGender,
        'weight': weightValue != null ? _weightController.text : FieldValue.delete(),
        'height': heightValue != null ? _heightController.text : FieldValue.delete(),
        'birthdate': _birthdateController.text.isNotEmpty ? _birthdateController.text : FieldValue.delete(),
        'bmi': bmi,
        'hideGender': _hideGender,
        'hideHeight': _hideHeight,
        'hideWeight': _hideWeight,
        'hideBirthdate': _hideBirthdate,
        'hideProfile': _hideProfile,
        'hideBattleStats': _hideBattleStats,
      };

      if (newLowercaseNickname != originalLowercaseNickname) {
        final batch = _firestore.batch();
        final userRef = _firestore.collection('users').doc(email);

        updateData['nickname'] = newNickname;
        batch.update(userRef, updateData);

        if (originalLowercaseNickname.isNotEmpty) {
          final oldNicknameRef = _firestore.collection('nicknames').doc(originalLowercaseNickname);
          batch.delete(oldNicknameRef);
        }
        final newNicknameRef = _firestore.collection('nicknames').doc(newLowercaseNickname);
        batch.set(newNicknameRef, {'email': email});

        await batch.commit();

      } else {
        await _firestore.collection('users').doc(email).update(updateData);
      }

      if (mounted) {
        setState(() {
          _originalNickname = newNickname;
          _isNicknameChecked = true;
        });
        _showCustomSnackBar('프로필이 업데이트 되었습니다.');
      }

    } catch (error) {
      print("Error updating profile: $error");
      if (mounted) {
        _showCustomSnackBar('프로필 업데이트 중 오류가 발생했습니다.', isError: true);
      }
    }
  }

  void _showAchievementsPopup(BuildContext context) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AchievementsPopup();
      },
    );
  }

  Widget _buildProfileForm() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Form(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ProfileTextField(
                    label: '닉네임 (2~10자)',
                    icon: Icons.person_outline_rounded,
                    controller: _nicknameController,
                    width: double.infinity,
                    height: 60,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 60,
                  child: ElevatedButton(
                    onPressed: _checkNickname,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: _isNicknameChecked ? Colors.green : Colors.black,
                      side: BorderSide(color: _isNicknameChecked ? Colors.green : Colors.grey),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: EdgeInsets.symmetric(horizontal: 10),
                    ),
                    child: const Text('중복 확인', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 11),

            ProfileTextField(
              label: '',
              icon: Icons.email_outlined,
              controller: _emailController,
              width: double.infinity,
              height: 60,
              readOnly: true,
            ),
            const SizedBox(height: 24),

            Text("프로필 공개 설정", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[800])),
            const SizedBox(height: 8),

            Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: SwitchListTile(
                title: const Text('다른 사용자에게 프로필 비공개', style: TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Text(_hideProfile ? '모든 정보가 다른 사용자에게 보이지 않습니다.' : '다른 사용자가 내 정보를 볼 수 있습니다.', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                value: _hideProfile,
                onChanged: (bool value) {
                  setState(() {
                    _hideProfile = value;
                  });
                },
                secondary: Icon(_hideProfile ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: _hideProfile ? Colors.grey : Color(0xFFFF9F80)),
                activeColor: Color(0xFFFF9F80),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
            ),
            const SizedBox(height: 11),

            Text("개별 항목 공개 설정", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[700])),
            const SizedBox(height: 8),

            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: GenderButton(label: '남자', isSelected: _selectedGender == '남자', onPressed: () => setState(() => _selectedGender = '남자'), width: double.infinity, height: 60)),
                const SizedBox(width: 9),
                Expanded(child: GenderButton(label: '여자', isSelected: _selectedGender == '여자', onPressed: () => setState(() => _selectedGender = '여자'), width: double.infinity, height: 60)),
                const SizedBox(width: 8),
                _buildHideCheckbox('성별', _hideGender, (value) => setState(() => _hideGender = value ?? false)),
              ],
            ),
            const SizedBox(height: 11),

            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _selectBirthdate(context),
                    child: AbsorbPointer(
                      child: ProfileTextField(
                        label: _birthdateController.text.isEmpty ? '생년월일 선택' : '',
                        icon: Icons.calendar_today_outlined,
                        controller: _birthdateController,
                        width: double.infinity,
                        height: 60,
                        readOnly: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _buildHideCheckbox('생년월일', _hideBirthdate, (value) => setState(() => _hideBirthdate = value ?? false)),
              ],
            ),
            const SizedBox(height: 11),

            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: ProfileTextField(label: '키', icon: Icons.height_rounded, controller: _heightController, width: double.infinity, height: 60, keyboardType: TextInputType.numberWithOptions(decimal: true),textInputAction: TextInputAction.done,)),
                const SizedBox(width: 12),
                UnitButton(label: 'CM', width: 60, height: 60),
                const SizedBox(width: 8),
                _buildHideCheckbox('키', _hideHeight, (value) => setState(() => _hideHeight = value ?? false)),
              ],
            ),
            const SizedBox(height: 11),

            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: ProfileTextField(label: '체중', icon: Icons.monitor_weight_outlined, controller: _weightController, width: double.infinity, height: 60, keyboardType: TextInputType.numberWithOptions(decimal: true),textInputAction: TextInputAction.done,)),
                const SizedBox(width: 12),
                UnitButton(label: 'KG', width: 60, height: 60),
                const SizedBox(width: 8),
                _buildHideCheckbox('체중', _hideWeight, (value) => setState(() => _hideWeight = value ?? false)),
              ],
            ),
            const SizedBox(height: 1),

            Center(
              child: TextButton(
                onPressed: () {
                  if (!mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => CustomerSupportScreen()),
                  );
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 8),
                ),
                child: Text(
                  '문의하기',
                  style: TextStyle(fontSize: 14, color: Colors.blueAccent, decoration: TextDecoration.underline),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHideCheckbox(String label, bool value, ValueChanged<bool?> onChanged) {
    return Tooltip(
      message: '$label 비공개',
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 30,
              width: 30,
              child: Checkbox(
                value: value,
                onChanged: onChanged,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                activeColor: Color(0xFFFF9F80),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectBirthdate(BuildContext context) async {
    DateTime initial = DateTime.now();
    try {
      if (_birthdateController.text.isNotEmpty) {
        initial = DateFormat('yyyy-MM-dd').parse(_birthdateController.text);
      }
    } catch (e) { }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1930),
      lastDate: DateTime.now(),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: Color(0xFFFF9F80),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
            dialogBackgroundColor: Colors.white,
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: Color(0xFFFF9F80)),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() {
        _birthdateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _emailController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _birthdateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Center(
                      child: Text(
                        '프로필 수정',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: Image.asset('assets/images/Back-Navs.png', width: 45, height: 45),
                          onPressed: () => Navigator.pop(context),
                          tooltip: '뒤로가기',
                          padding: EdgeInsets.all(8),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.settings_outlined, size: 26, color: Colors.grey[700]),
                              onPressed: () {
                                if (!mounted) return;
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => ProfileSettingsScreen()),
                                );
                              },
                              tooltip: '설정',
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints(),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: Icon(Icons.logout_outlined, size: 26, color: Colors.grey[700]),
                              onPressed: _logout,
                              tooltip: '로그아웃',
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints(),
                            ),
                            const SizedBox(width: 4),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 600),
                    margin: const EdgeInsets.symmetric(horizontal: 0),
                    child: Column(
                      children: [
                        Center(
                          child: Column(
                            children: [
                              GestureDetector(
                                onTap: _pickAndUploadImage,
                                child: Stack(
                                  alignment: Alignment.bottomRight,
                                  children: [
                                    CircleAvatar(
                                      radius: 55,
                                      backgroundColor: Colors.grey[200],
                                      backgroundImage: _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                                          ? NetworkImage(_profileImageUrl!)
                                          : AssetImage('assets/images/user.png') as ImageProvider,
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Color(0xFFFF9F80),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 1.5),
                                      ),
                                      child: Icon(Icons.camera_alt_outlined, color: Colors.white, size: 18),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 11),

                              GestureDetector(
                                onTap: () => _showAchievementsPopup(context),
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Color(0xFFFFF3E0),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Color(0xFFFFE0B2), width: 1),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.emoji_events_outlined, size: 14, color: Color(0xFFEF6C00)),
                                      const SizedBox(width: 5),
                                      Text(
                                        '내 업적 보기',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFFEF6C00),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 8),

                              if (_userUid != null)
                                GestureDetector(
                                  onTap: () async {
                                    await Clipboard.setData(ClipboardData(text: _userUid!));
                                    if(mounted) _showCustomSnackBar('UID가 복사되었습니다.');
                                  },
                                  child: Container(
                                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            'UID: $_userUid',
                                            style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(Icons.copy_all_outlined, size: 13, color: Colors.grey[700]),
                                      ],
                                    ),
                                  ),
                                ),

                              const SizedBox(height: 1),

                              LevelBarWidget(
                                levelData: _levelData,
                                isLoading: _isLoadingStats,
                                isOtherUserProfile: false,
                              ),

                            ],
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                          child: TextButton.icon(
                            icon: Icon(
                              _showBattleStats ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                              color: Colors.grey[700],
                            ),
                            label: Text(
                              _showBattleStats ? '대결 기록 숨기기' : '대결 기록 보기',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                            style: TextButton.styleFrom(
                              minimumSize: Size(double.infinity, 48),
                              backgroundColor: Colors.grey[100],
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              alignment: Alignment.center,
                            ),
                            onPressed: () {
                              setState(() {
                                _showBattleStats = !_showBattleStats;
                              });
                            },
                          ),
                        ),

                        Visibility(
                          visible: _showBattleStats,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: [
                                      _buildWLStatColumn('총 대결', '${_battleWins + _battleLosses} 회'),
                                      _buildWLStatColumn('승리', '$_battleWins 회', color: Colors.blueAccent),
                                      _buildWLStatColumn('패배', '$_battleLosses 회', color: Colors.redAccent),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  const Divider(height: 1, thickness: 0.5),

                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text(
                                        '상대방에게 이 기록 비공개',
                                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                      ),
                                      _buildHideCheckbox('대결 기록', _hideBattleStats, (value) => setState(() => _hideBattleStats = value ?? false)),
                                    ],
                                  )
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        _buildProfileForm(),

                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          child: Row(
                            children: [
                              Expanded(
                                child: ActionButton(label: '취소', isOutlined: true, onPressed: () => Navigator.pop(context)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ActionButton(label: '저장', isOutlined: false, onPressed: _saveProfile),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWLStatColumn(String label, String value, {Color color = Colors.black87}) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

}

class ActionButton extends StatelessWidget {
  final String label;
  final bool isOutlined;
  final VoidCallback onPressed;

  const ActionButton({
    Key? key,
    required this.label,
    required this.isOutlined,
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 55),
        backgroundColor: isOutlined ? Colors.white : Colors.black,
        foregroundColor: isOutlined ? Colors.black : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isOutlined ? Colors.grey[400]! : Colors.transparent,
            width: 1,
          ),
        ),
        elevation: isOutlined ? 0 : 2,
      ),
      onPressed: onPressed,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          fontFamily: 'Pretendard',
        ),
      ),
    );
  }
}

class GenderButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onPressed;
  final double width;
  final double height;

  const GenderButton({
    Key? key,
    required this.label,
    required this.isSelected,
    required this.onPressed,
    required this.width,
    required this.height,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Colors.black : Colors.white,
        foregroundColor: isSelected ? Colors.white : Colors.black,
        minimumSize: Size(width, height),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: isSelected ? Colors.black : Colors.grey.shade300,
            width: 1,
          ),
        ),
        elevation: 0,
      ),
      onPressed: onPressed,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          fontFamily: 'Pretendard',
        ),
      ),
    );
  }
}

class UnitButton extends StatelessWidget {
  final String label;
  final double width;
  final double height;

  const UnitButton({
    Key? key,
    required this.label,
    required this.width,
    required this.height,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Color(0xFFFF9F80),
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            fontFamily: 'Pretendard',
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class ProfileTextField extends StatelessWidget {
  final String label;
  final IconData icon;
  final TextEditingController controller;
  final double width;
  final double height;
  final bool readOnly;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;

  const ProfileTextField({
    Key? key,
    required this.label,
    required this.icon,
    required this.controller,
    required this.width,
    required this.height,
    this.readOnly = false,
    this.keyboardType,
    this.textInputAction,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.only(left: 13),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[300]!, width: 0.8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: Colors.grey[600]),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              readOnly: readOnly,
              keyboardType: keyboardType,
              textInputAction: textInputAction,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                fontFamily: 'Pretendard',
                color: Colors.black87,
              ),
              decoration: InputDecoration(
                hintText: label,
                hintStyle: TextStyle(color: Colors.grey[500]),
                border: InputBorder.none,
                contentPadding: EdgeInsets.only(bottom: 5, right: 13),
              ),
              enableInteractiveSelection: !readOnly,
              focusNode: readOnly ? FocusNode(canRequestFocus: false) : null,
            ),
          ),
        ],
      ),
    );
  }
}