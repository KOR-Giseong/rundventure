import 'package:flutter/material.dart';
import 'weight_input_screen.dart';

class BirthdayInputScreen extends StatefulWidget {
  final String email;
  final String password;
  final String nickname;
  final String gender;

  const BirthdayInputScreen({
    Key? key,
    required this.email,
    required this.password,
    required this.nickname,
    required this.gender,
  }) : super(key: key);

  @override
  _BirthdayInputScreenState createState() => _BirthdayInputScreenState();
}

class _BirthdayInputScreenState extends State<BirthdayInputScreen> {
  final TextEditingController _birthdayController = TextEditingController();

  void _goBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, '/home');
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
            primaryColor: Colors.black,
            colorScheme: ColorScheme.light(primary: Colors.black),
            buttonTheme: ButtonThemeData(textTheme: ButtonTextTheme.primary),
            dialogBackgroundColor: Colors.white,
          ),
          child: child ?? Container(),
        );
      },
    );
    if (picked != null) {
      setState(() {
        _birthdayController.text = "${picked.toLocal()}".split(' ')[0];
      });
    }
  }

  void _navigateNext() {
    if (_birthdayController.text.isEmpty) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: Colors.white,
            title: const Text('경고', style: TextStyle(color: Colors.black)),
            content: const Text('생년월일을 입력해주세요!', style: TextStyle(color: Colors.black)),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('확인', style: TextStyle(color: Colors.black)),
              ),
            ],
          );
        },
      );
      return;
    }

    if (!_isValidDateFormat(_birthdayController.text)) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: Colors.white,
            title: const Text('경고', style: TextStyle(color: Colors.black)),
            content: const Text('생년월일 형식이 올바르지 않습니다! 형식: YYYY-MM-DD', style: TextStyle(color: Colors.black)),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('확인', style: TextStyle(color: Colors.black)),
              ),
            ],
          );
        },
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => WeightInputScreen(
          email: widget.email,
          password: widget.password,
          nickname: widget.nickname,
          gender: widget.gender,
          birthday: _birthdayController.text,
        ),
      ),
    );
  }

  bool _isValidDateFormat(String date) {
    final RegExp regex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    return regex.hasMatch(date);
  }

  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;
    double screenWidth = MediaQuery.of(context).size.width;

    double boxHeight = screenHeight * 0.06;
    double boxWidth = screenWidth * 0.8;
    double buttonHeight = screenHeight * 0.08;
    double buttonWidth = screenWidth * 0.4;

    double topPadding = screenHeight * 0.25;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.1, vertical: topPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '프로필을 입력해주세요!',
              style: TextStyle(
                fontSize: screenWidth * 0.06,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '러너님에 대해 더 알게 되면 도움이 될 거예요!',
              style: TextStyle(
                color: Colors.grey,
                fontSize: screenWidth * 0.035,
              ),
            ),
            const SizedBox(height: 40),

            TextField(
              controller: _birthdayController,
              readOnly: true,
              decoration: InputDecoration(
                hintText: 'YYYY-MM-DD',
                hintStyle: TextStyle(
                  color: Colors.grey,
                  fontSize: screenWidth * 0.04,
                  fontWeight: FontWeight.w400,
                ),
                suffixIcon: IconButton(
                  icon: Icon(Icons.calendar_today),
                  onPressed: () => _selectDate(context),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey),
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
            SizedBox(width: screenWidth * 0.03),

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
