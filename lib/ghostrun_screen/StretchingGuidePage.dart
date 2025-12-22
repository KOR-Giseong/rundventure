import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class StretchingGuidePage extends StatelessWidget {
  const StretchingGuidePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          "스트레칭 방법",
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              children: [
                _buildStretchingCard(
                  title: "팔벌려뛰기",
                  lottiePath: 'assets/lottie/armsjump.json',
                  instructions: "1. 양발을 모으고 똑바로 선 상태를 유지하세요.\n"
                      "2. 팔을 머리 위로 벌리면서 동시에 발을 어깨 너비만큼 벌립니다.\n"
                      "3. 원래 자세로 돌아오세요.\n"
                      "4. 이 동작을 10회 반복합니다.",
                ),
                const SizedBox(height: 20),

                _buildStretchingCard(
                  title: "스쿼트 (다리 스트레칭)",
                  lottiePath: 'assets/lottie/legexercise.json',
                  instructions: "1. 발을 어깨 너비만큼 벌리고 똑바로 선 상태를 만듭니다.\n"
                      "2. 상체를 곧게 펴고 천천히 무릎을 구부리며 앉습니다.\n"
                      "3. 허벅지가 바닥과 평행이 될 때까지 내려오세요.\n"
                      "4. 다시 일어서고, 이 동작을 10회 반복합니다.",
                ),
              ],
            ),
          ),

          Padding(
            padding: EdgeInsets.fromLTRB(
                16.0, 16.0, 16.0, MediaQuery.of(context).padding.bottom + 16.0
            ),
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                "닫기",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[850],
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStretchingCard({
    required String title,
    required String lottiePath,
    required String instructions,
  }) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            width: double.infinity,
            child: Lottie.asset(lottiePath),
          ),
          const SizedBox(height: 16),
          Text(
            instructions,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}