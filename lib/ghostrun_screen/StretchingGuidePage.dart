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
        // ✅ [수정] AppBar의 기본 그림자 및 스크롤 시 그림자 제거
        elevation: 0,
        scrolledUnderElevation: 0,
        // (수정 없음) 자동 뒤로가기 버튼 비활성화
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
          // 스크롤 가능한 본문 내용
          Expanded(
            child: ListView(
              // ✅ [수정] 상하 패딩은 ListView 자체에 부여
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              children: [
                // 🧘‍♂️ 팔벌려뛰기 섹션
                _buildStretchingCard(
                  title: "팔벌려뛰기",
                  lottiePath: 'assets/lottie/armsjump.json',
                  instructions: "1. 양발을 모으고 똑바로 선 상태를 유지하세요.\n"
                      "2. 팔을 머리 위로 벌리면서 동시에 발을 어깨 너비만큼 벌립니다.\n"
                      "3. 원래 자세로 돌아오세요.\n"
                      "4. 이 동작을 10회 반복합니다.",
                ),
                // ✅ [수정] 카드 사이 간격
                const SizedBox(height: 20),

                // 🧘‍♀️ 스쿼트 섹션
                _buildStretchingCard(
                  title: "스쿼트 (다리 스트레칭)",
                  lottiePath: 'assets/lottie/legexercise.json',
                  instructions: "1. 발을 어깨 너비만큼 벌리고 똑바로 선 상태를 만듭니다.\n"
                      "2. 상체를 곧게 펴고 천천히 무릎을 구부리며 앉습니다.\n"
                      "3. 허벅지가 바닥과 평행이 될 때까지 내려오세요.\n"
                      "4. 다시 일어서고, 이 동작을 10회 반복합니다.",
                ),

                // ✅ [추가] 다른 스트레칭 예시 (필요시 주석 해제)
                // const SizedBox(height: 20),
                // _buildStretchingCard(
                //   title: "무릎 당기기",
                //   lottiePath: 'assets/lottie/armsjump.json', // TODO: Lottie 경로 변경
                //   instructions: "1. 바닥에 등을 대고 눕습니다.\n"
                //       "2. 한쪽 무릎을 가슴 쪽으로 당겨 15초간 유지합니다.\n"
                //       "3. 반대쪽도 동일하게 반복합니다.",
                // ),
              ],
            ),
          ),

          // --- 하단 고정 버튼 ---
          Padding(
            // ✅ [수정] 버튼과 본문 내용이 겹치지 않도록 SafeArea 적용
            padding: EdgeInsets.fromLTRB(
                16.0, 16.0, 16.0, MediaQuery.of(context).padding.bottom + 16.0
            ),
            child: ElevatedButton( // ✅ [수정] 아이콘 제거 (더 심플하게)
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                "닫기",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                // ✅ [수정] 다크 모드에 어울리는 버튼 스타일
                backgroundColor: Colors.grey[850], // 어두운 회색
                foregroundColor: Colors.white, // 흰색 텍스트
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12), // 둥근 모서리
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ [추가] 스트레칭 카드 위젯 빌더
  Widget _buildStretchingCard({
    required String title,
    required String lottiePath,
    required String instructions,
  }) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        // ✅ [수정] 검은색 배경과 구분되는 카드 색상
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. 제목
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22, // 폰트 크기 강조
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          // 2. Lottie 애니메이션
          SizedBox(
            height: 200,
            width: double.infinity, // 너비 꽉 채우기
            child: Lottie.asset(lottiePath),
          ),
          const SizedBox(height: 16),
          // 3. 설명
          Text(
            instructions,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
              height: 1.5, // ✅ [추가] 줄 간격을 넓혀 가독성 향상
            ),
          ),
        ],
      ),
    );
  }
}