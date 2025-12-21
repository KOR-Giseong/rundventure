import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Firebase Firestore 추가
import 'package:firebase_auth/firebase_auth.dart'; // Firebase Authentication 추가
import '../challenge_screen.dart';
import 'next_button.dart'; // NextButton import
import 'dart:convert'; // URL 인코딩을 위한 라이브러리 추가
import '../challenge.dart';

class ChallengeForm extends StatefulWidget {
  const ChallengeForm({Key? key}) : super(key: key);

  @override
  State<ChallengeForm> createState() => _ChallengeFormState();
}

class _ChallengeFormState extends State<ChallengeForm> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();

  // ✅ "대형 이벤트" 방식 옵션 (수정 없음)
  final Map<String, Map<String, dynamic>> _challengeOptions = {
    // key: { distance: '저장할 거리 값(km)', limit: 참여제한 인원 }
    '10km (최대 20명)': {'distance': '10', 'limit': 20},
    '20km (최대 30명)': {'distance': '20', 'limit': 30},
    '50km (최대 50명)': {'distance': '50', 'limit': 50},
    '100km (최대 80명)': {'distance': '100', 'limit': 80},
    '200km (최대 100명)': {'distance': '200', 'limit': 100},
  };

  String? _selectedDistanceKey;

  // (수정 없음)
  void _showCustomSnackBar(String message, {bool isError = false}) {
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
        backgroundColor: Color(0xFFFF9F80),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(15, 5, 15, 15),
      ),
    );
  }

  // (수정 없음)
  Future<void> _saveChallenge() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showCustomSnackBar('사용자가 로그인되지 않았습니다.', isError: true);
      return;
    }

    final String userEmail = user.email ?? '';
    if (userEmail.isEmpty) {
      _showCustomSnackBar('사용자의 이메일이 없습니다.', isError: true);
      return;
    }

    final String userEmailFormatted = userEmail.replaceAll('@', '_at_').replaceAll('.', '_dot_');
    final String challengeId = '${userEmailFormatted}_${DateTime.now().millisecondsSinceEpoch}';

    if (_nameController.text.isNotEmpty &&
        _durationController.text.isNotEmpty &&
        _selectedDistanceKey != null) {

      final selectedOption = _challengeOptions[_selectedDistanceKey!];
      if (selectedOption == null) {
        _showCustomSnackBar('유효하지 않은 거리 옵션입니다.', isError: true);
        return;
      }

      final String distance = selectedOption['distance'];
      final int participantLimit = selectedOption['limit'];

      await FirebaseFirestore.instance.collection('challenges').doc(challengeId).set({
        'name': _nameController.text,
        'duration': _durationController.text,
        'distance': distance,
        'participantLimit': participantLimit,
        'timestamp': FieldValue.serverTimestamp(),
        'userEmail': userEmail,
      });

      _showCustomSnackBar('챌린지가 성공적으로 생성되었습니다.');


      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ChallengeScreen()),
      );

      _nameController.clear();
      _durationController.clear();
      setState(() {
        _selectedDistanceKey = null;
      });
    } else {
      _showCustomSnackBar('모든 필드를 입력해 주세요.', isError: true);
    }
  }

  // (수정 없음)
  void _validateAndProceed() {
    if (_nameController.text.isEmpty ||
        _durationController.text.isEmpty ||
        _selectedDistanceKey == null) {
      _showDialog();
    } else {
      _saveChallenge();
    }
  }

  // (수정 없음)
  void _showDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            '정보를 입력해주세요',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: const Text(
            "모든 필드를 입력해 주세요.",
            style: TextStyle(
              color: Colors.black,
              fontSize: 16,
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                '확인',
                style: TextStyle(color: Colors.blue),
              ),
            ),
          ],
        );
      },
    );
  }

  // (수정 없음)
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '새로운 챌린지 설정',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '목표를 정하고 함께 도전해 보세요!',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 32),
            _buildFormField(
              '챌린지 이름 (예: 100km 마라톤)',
              Icons.label_outline,
              _nameController,
              isNumber: false,
            ),
            const SizedBox(height: 16),
            _buildFormField(
              '기간 (일 단위)',
              Icons.date_range,
              _durationController,
              isNumber: true,
            ),
            const SizedBox(height: 16),
            _buildDistanceDropdown(),
            const SizedBox(height: 40),
            NextButton(onPressed: _validateAndProceed),
          ],
        ),
      ),
    );
  }

  // ✅✅✅ [디자인 수정] 드롭다운 위젯 (흰색 배경) ✅✅✅
  Widget _buildDistanceDropdown() {
    return Container(
      // 1. 외부 컨테이너 (흰색 배경, 회색 테두리)
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white, // ✅ 배경 흰색
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300, width: 1), // ✅ 테두리
      ),
      child: Row(
        children: [
          // 2. 아이콘
          Icon(
            Icons.directions_run_outlined,
            size: 20,
            color: Colors.blueAccent,
          ),
          const SizedBox(width: 12),
          // 3. 확장 영역
          Expanded(
            // 4. 내부 패딩 (TextField와 높이 맞춤)
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedDistanceKey, // 현재 선택된 값
                  hint: Text(
                    '목표 거리 선택',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade400,
                    ),
                  ),
                  // 메뉴 아이템 목록
                  items: _challengeOptions.keys.map((String key) {
                    return DropdownMenuItem<String>(
                      value: key,
                      child: Text(
                        key, // 예: "100km (최대 80명)"
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 16, // TextField 입력 글꼴과 맞춤
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedDistanceKey = newValue;
                    });
                  },
                  isExpanded: true, // 가로로 꽉 채우기
                  icon: Icon(Icons.expand_more_rounded, color: Colors.grey.shade600),
                  isDense: true, // 불필요한 내부 패딩 제거
                  dropdownColor: Colors.white, // 메뉴 펼쳤을 때 배경도 흰색
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅✅✅ [디자인 수정] 텍스트필드 위젯 (흰색 배경) ✅✅✅
  Widget _buildFormField(String hint, IconData icon, TextEditingController controller, {required bool isNumber}) {
    return Container(
      // 1. 외부 컨테이너 (흰색 배경, 회색 테두리)
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white, // ✅ 배경 흰색
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300, width: 1), // ✅ 테두리
      ),
      child: Row(
        children: [
          // 2. 아이콘
          Icon(
            icon,
            size: 20,
            color: Colors.blueAccent,
          ),
          const SizedBox(width: 12),
          // 3. 텍스트필드
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: isNumber ? TextInputType.number : TextInputType.text,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade400,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16), // ✅ 높이 맞춤
              ),
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}