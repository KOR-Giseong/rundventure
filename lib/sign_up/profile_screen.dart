import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'profile_gender_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String email;
  final String password;

  const ProfileScreen({Key? key, required this.email, required this.password}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _nicknameController = TextEditingController();
  bool _isNicknameChecked = false;

  void _showDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(title, style: const TextStyle(color: Colors.black)),
        content: Text(message, style: const TextStyle(color: Colors.black)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  bool _containsBadWords(String text) {
    const bannedWords = [
      'ㅅ1발', 'ㅆ1발', '시1발', '씨1발', 'ㅅㅣ발', '시8', '십팔', '시바', '시방', '시빨',
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
      'sh*t', 'sh1t', 'b!tch', 'b1tch', 'bi7ch', 'sex', 'SEX' '@sshole', 'a55hole',
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


    // 공백, 특수문자 제거 후 소문자 변환
    final cleanedText = text
        .replaceAll(RegExp(r'\s+'), '')                 // 공백 제거
        .replaceAll(RegExp(r'[^\wㄱ-ㅎ가-힣]'), '')      // 특수문자 제거
        .toLowerCase();

    return bannedWords.any((word) => cleanedText.contains(word));
  }

  Future<void> _checkNickname() async {
    String nickname = _nicknameController.text.trim().toLowerCase();

    if (nickname.isEmpty) {
      _showDialog('경고', '닉네임을 입력해주세요.');
      return;
    }

    if (_containsBadWords(nickname)) {
      _showDialog('경고', '부적절한 닉네임은 사용할 수 없습니다.');
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('nicknames').doc(nickname).get();

      if (doc.exists) {
        setState(() => _isNicknameChecked = false);
        _showDialog('중복 확인', '이미 사용 중인 닉네임입니다. 다른 닉네임을 사용해주세요.');
      } else {
        setState(() => _isNicknameChecked = true);
        _showDialog('확인', '사용 가능한 닉네임입니다.');
      }
    } catch (e) {
      setState(() => _isNicknameChecked = false);
      _showDialog('오류', '닉네임 확인 중 오류가 발생했습니다.\n네트워크 상태를 확인하세요.');
    }
  }

  void _navigateNext() {
    final nickname = _nicknameController.text.trim();

    if (nickname.isEmpty) {
      _showDialog('경고', '닉네임을 입력해주세요!');
      return;
    }

    if (!_isNicknameChecked) {
      _showDialog('경고', '닉네임 중복 확인을 해주세요!');
      return;
    }

    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, __, ___) => ProfileGenderScreen(
          email: widget.email,
          password: widget.password,
          nickname: nickname,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    final boxHeight = screenHeight * 0.06;
    final buttonHeight = screenHeight * 0.07;
    final buttonWidth = screenWidth * 0.9;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.1, vertical: screenHeight * 0.15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 70,
              height: 70,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Image.asset('assets/images/Back-Navs.png'),
              ),
            ),
            const SizedBox(height: 20),
            Text('프로필을 입력해주세요!',
                style: TextStyle(fontSize: screenWidth * 0.06, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Text('러너님에 대해 더 알게 되면 도움이 될 거예요!',
                style: TextStyle(color: Colors.grey, fontSize: screenWidth * 0.035)),
            const SizedBox(height: 40),

            // 닉네임 입력 + 버튼
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: boxHeight,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey, width: 1),
                    ),
                    child: TextField(
                      controller: _nicknameController,
                      onChanged: (value) {
                        if (_isNicknameChecked) {
                          setState(() {
                            _isNicknameChecked = false;
                          });
                        }
                      },
                      decoration: InputDecoration(
                        hintText: '닉네임을 입력하세요',
                        hintStyle: TextStyle(
                          color: Colors.grey,
                          fontSize: screenWidth * 0.03,
                          fontWeight: FontWeight.w400,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          vertical: screenHeight * 0.012,
                          horizontal: screenWidth * 0.01,
                        ),
                        prefixIcon: Padding(
                          padding: EdgeInsets.symmetric(
                              vertical: screenHeight * 0.015, horizontal: screenWidth * 0.04),
                          child: const Icon(Icons.person, size: 20, color: Colors.grey),
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 80,
                  height: 30,
                  child: ElevatedButton(
                    onPressed: _checkNickname,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Colors.grey, width: 1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                    ),
                    child: const Text('중복 확인',
                        style: TextStyle(color: Colors.black54, fontSize: 8, fontWeight: FontWeight.w500)),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Text(
              '닉네임은 프로필 화면에서 변경 가능합니다.',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),

            const SizedBox(height: 300),

            SizedBox(
              width: buttonWidth,
              height: buttonHeight,
              child: ElevatedButton(
                onPressed: _navigateNext,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: screenHeight * 0.02),
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('다음',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w400)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
