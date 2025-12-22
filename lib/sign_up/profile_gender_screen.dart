import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart';
import 'birthday_input_screen.dart';

class ProfileGenderScreen extends StatefulWidget {
  final String email;
  final String password;
  final String nickname;

  const ProfileGenderScreen(
      {Key? key,
        required this.email,
        required this.password,
        required this.nickname})
      : super(key: key);

  @override
  _ProfileGenderScreenState createState() => _ProfileGenderScreenState();
}

class _ProfileGenderScreenState extends State<ProfileGenderScreen> {
  String? _selectedGender;
  VideoPlayerController? _controller;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _onGenderSelected(String gender) {
    if (_selectedGender == gender) return;

    setState(() {
      _selectedGender = gender;
      _controller?.dispose();

      final videoPath =
      gender == '남자' ? 'assets/videos/man.mp4' : 'assets/videos/woman.mp4';

      _controller = VideoPlayerController.asset(videoPath)
        ..initialize().then((_) {
          setState(() {});
          _controller?.setLooping(true);
          _controller?.setVolume(0.0);
          _controller?.play();
        });
    });
  }

  void _navigateNext() {
    if (_selectedGender == null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          title: Text('성별 선택', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text('성별을 선택해주세요!', style: TextStyle(color: Colors.black54)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('확인', style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BirthdayInputScreen(
            email: widget.email,
            password: widget.password,
            nickname: widget.nickname,
            gender: _selectedGender!,
          ),
        ),
      );
    }
  }

  Widget _genderBox(String gender, {double? height, double? width}) {
    return GestureDetector(
      onTap: () {
        _onGenderSelected(gender);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10),
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: _selectedGender == gender ? Colors.black : Colors.grey[300]!,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Text(
            gender,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w400),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;
    double screenWidth = MediaQuery.of(context).size.width;

    double boxHeight = screenHeight * 0.07;
    double boxWidth = screenWidth * 0.4;
    double minBoxHeight = 50;
    double minBoxWidth = 100;

    boxHeight = boxHeight < minBoxHeight ? minBoxHeight : boxHeight;
    boxWidth = boxWidth < minBoxWidth ? minBoxWidth : boxWidth;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.1, vertical: screenHeight * 0.25),
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
              const SizedBox(height: 45),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: _genderBox('남자', height: boxHeight, width: boxWidth),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _genderBox('여자', height: boxHeight, width: boxWidth),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              Center(
                child: Container(
                  height: screenHeight * 0.29,
                  width: screenWidth * 0.5,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: _controller != null && _controller!.value.isInitialized
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: _controller!.value.aspectRatio,
                      child: VideoPlayer(_controller!),
                    ),
                  )
                      : Center(
                    child: Text(
                      '성별을 선택하세요',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      // 다음 버튼만 하단에 고정
      bottomNavigationBar: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.1, vertical: screenHeight * 0.08),
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
    );
  }
}