import 'package:flutter/material.dart';
import 'weight_input_screen.dart'; // WeightInputScreen 임포트

class BirthdayInputScreen extends StatefulWidget {
  final String email; // 이메일 추가
  final String password; // 비밀번호 추가
  final String nickname; // 닉네임 추가
  final String gender; // 선택된 성별 추가

  const BirthdayInputScreen({
    Key? key,
    required this.email,
    required this.password,
    required this.nickname,
    required this.gender, // 수정된 부분
  }) : super(key: key);

  @override
  _BirthdayInputScreenState createState() => _BirthdayInputScreenState();
}

class _BirthdayInputScreenState extends State<BirthdayInputScreen> {
  final TextEditingController _birthdayController = TextEditingController(); // 생년월일 입력 컨트롤러

  void _goBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context); // 뒤로가기 기능
    } else {
      // 이전 화면으로 돌아갈 수 없을 때, 홈화면으로 이동
      Navigator.pushReplacementNamed(context, '/home');  // '/home'은 실제 앱에서 홈 화면 경로로 수정 필요
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2101),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: Colors.black, // 헤더 색상
            colorScheme: ColorScheme.light(primary: Colors.black), // 선택 색상
            buttonTheme: ButtonThemeData(textTheme: ButtonTextTheme.primary), // 버튼 텍스트 색상
            dialogBackgroundColor: Colors.white, // 다이얼로그 배경색 흰색
          ),
          child: child ?? Container(),
        );
      },
    );
    if (picked != null) {
      setState(() {
        _birthdayController.text = "${picked.toLocal()}".split(' ')[0]; // 날짜 형식 설정 (YYYY-MM-DD)
      });
    }
  }

  void _navigateNext() {
    // 생년월일이 입력되었는지 확인
    if (_birthdayController.text.isEmpty) {
      // 경고 다이얼로그 표시
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: Colors.white, // 다이얼로그 배경을 흰색으로
            title: const Text('경고', style: TextStyle(color: Colors.black)),
            content: const Text('생년월일을 입력해주세요!', style: TextStyle(color: Colors.black)),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // 다이얼로그 닫기
                },
                child: const Text('확인', style: TextStyle(color: Colors.black)),
              ),
            ],
          );
        },
      );
      return; // 생년월일이 비어있으면 다음으로 넘어가지 않음
    }

    // 생년월일 형식이 올바른지 확인
    if (!_isValidDateFormat(_birthdayController.text)) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: Colors.white, // 다이얼로그 배경을 흰색으로
            title: const Text('경고', style: TextStyle(color: Colors.black)),
            content: const Text('생년월일 형식이 올바르지 않습니다! 형식: YYYY-MM-DD', style: TextStyle(color: Colors.black)),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // 다이얼로그 닫기
                },
                child: const Text('확인', style: TextStyle(color: Colors.black)),
              ),
            ],
          );
        },
      );
      return; // 형식이 올바르지 않으면 다음으로 넘어가지 않음
    }

    // WeightInputScreen으로 이동
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => WeightInputScreen(
          email: widget.email,
          password: widget.password,
          nickname: widget.nickname, // 닉네임 전달
          gender: widget.gender, // 성별 전달
          birthday: _birthdayController.text, // 생년월일 전달
        ),
      ),
    );
  }

  bool _isValidDateFormat(String date) {
    // YYYY-MM-DD 형식 검증
    final RegExp regex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    return regex.hasMatch(date);
  }

  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;
    double screenWidth = MediaQuery.of(context).size.width;

    // UI 요소 크기 및 패딩 조정
    double boxHeight = screenHeight * 0.06; // 입력박스 높이
    double boxWidth = screenWidth * 0.8;  // 입력박스 너비
    double buttonHeight = screenHeight * 0.08; // 버튼 높이
    double buttonWidth = screenWidth * 0.4; // 버튼 너비 (WeightInputScreen과 동일)

    // 상단 공백을 위한 변수 (여기서 원하는 값으로 공백을 조정)
    double topPadding = screenHeight * 0.25;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.1, vertical: topPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 프로필 텍스트 위의 공백을 조정하려면 여기서 topPadding 값을 조정
            Text(
              '프로필을 입력해주세요!',
              style: TextStyle(
                fontSize: screenWidth * 0.06, // 화면 크기에 맞춰 텍스트 크기 설정
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '러너님에 대해 더 알게 되면 도움이 될 거예요!',
              style: TextStyle(
                color: Colors.grey,
                fontSize: screenWidth * 0.035, // 화면 크기에 맞춰 텍스트 크기 설정
              ),
            ),
            const SizedBox(height: 40),

            // 생년월일 입력 필드
            TextField(
              controller: _birthdayController,
              readOnly: true, // 읽기 전용
              decoration: InputDecoration(
                hintText: 'YYYY-MM-DD',
                hintStyle: TextStyle(
                  color: Colors.grey,
                  fontSize: screenWidth * 0.04, // 화면 크기에 맞춰 텍스트 크기 설정
                  fontWeight: FontWeight.w400,
                ),
                suffixIcon: IconButton(
                  icon: Icon(Icons.calendar_today),
                  onPressed: () => _selectDate(context), // 날짜 선택기 호출
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey), // 테두리 색상
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.1, vertical: screenHeight * 0.08),
        child: Row(
          children: [
            // 이전 버튼
            Expanded(
              child: ElevatedButton(
                onPressed: _goBack,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: screenHeight * 0.02),
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Colors.black, width: 1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  '이전',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: screenWidth * 0.04,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
            SizedBox(width: screenWidth * 0.03), // 버튼 간격

            // 다음 버튼
            Expanded(
              child: ElevatedButton(
                onPressed: _navigateNext,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: screenHeight * 0.02),
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  '다음',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: screenWidth * 0.04,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
