import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

class ShareButton extends StatelessWidget {
  const ShareButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          final String message = '''
📢 함께 참여해봐요! 🏃‍♀️

✅ 마라톤365
https://marathon365.net/?gad_source=1&gbraid=0AAAAA-9Q6TR9-lv3J6BSL1DX4o8SXgkgQ&gclid=Cj0KCQjwoNzABhDbARIsALfY8VNyzU-Eyevcb1NxffUIYRsGYtHrxYVk98LKwEQ8pBOPcBkhpFzDkAYaAofzEALw_wcB

✅ 전국 마라톤 일정
http://www.marathon.pe.kr/schedule_index.html

런드벤처에서 다양한 챌린지를 확인해보세요!
👉 https://rundventure.page.link/challenge
''';
          Share.share(message);
        },
        child: const Text('공유하기'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 19),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            fontFamily: 'Pretendard',
          ),
        ),
      ),
    );
  }
}
