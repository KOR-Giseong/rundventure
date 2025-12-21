import 'package:flutter/material.dart';

class GhostRunRulePage extends StatelessWidget {
  const GhostRunRulePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('고스트런 규칙 안내'),
        // [수정] leading 속성을 삭제하고, 자동 뒤로가기 버튼 생성을 막습니다.
        automaticallyImplyLeading: false,
        centerTitle: true, // 제목을 중앙에 배치하여 더 깔끔하게 보입니다.
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            const Text(
              '📌 고스트런은 과거 나의 러닝 기록을 바탕으로 한 도전 모드입니다.',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 20),
            const Text(
              '1. 첫 도전 시작하기\n- 처음 고스트런을 시작할 때 사용합니다.\n- 현재 위치에서 실시간 트래킹을 하며 기록을 남깁니다.',
              style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 15),
            const Text(
              '2. 지난기록 도전\n- 저장된 기록을 바탕으로 다시 도전할 수 있습니다.\n- 과거 나의 시간과 거리, 페이스를 따라가며 승패를 확인할 수 있습니다.',
              style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 15),
            const Text(
              '3. 결과 분석\n- 기록된 데이터(시간, 거리, 페이스)를 비교해보세요.\n- 시간에 따라 승리/패배/무승부 결과가 표시됩니다.',
              style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(), // [수정] 익명 함수로 변경
              icon: Icon(Icons.check_circle_outline),
              label: const Text('확인'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
              ),
            )
          ],
        ),
      ),
    );
  }
}