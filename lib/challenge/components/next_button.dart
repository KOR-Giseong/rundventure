import 'package:flutter/material.dart';
import 'package:rundventure/challenge/challenge_screen.dart'; // 목록 화면
import '../challenge.dart'; // 필요한 import

class NextButton extends StatelessWidget {
  final VoidCallback? onPressed;

  NextButton({Key? key, this.onPressed}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        children: [
          // 목록 버튼
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                // 목록 페이지로 이동
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ChallengeScreen(), // 목록 화면
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                minimumSize: const Size(0, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey[300]!),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              child: const Text('목록'),
            ),
          ),

          SizedBox(width: 12), // 버튼 사이 간격

          // '다음' 버튼
          Expanded(
            child: ElevatedButton(
              onPressed: onPressed ??
                      () {
                    // 기본적으로 목록 페이지로 이동 (ChallengeScreen)
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ChallengeScreen(), // 목록 화면
                      ),
                    );
                  },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              child: const Text('다음'),
            ),
          ),
        ],
      ),
    );
  }
}
