import 'package:flutter/material.dart';

class MonthlyRankingInfoScreen extends StatelessWidget {
  const MonthlyRankingInfoScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        // 뒤로가기 버튼
        leading: IconButton(
          icon: Image.asset('assets/images/Back-Navs.png', width: 60, height: 60),
          onPressed: () => Navigator.pop(context),
          padding: const EdgeInsets.only(left: 10),
        ),
        title: Text(
          "월간 랭킹 보상 안내",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 월간 1등 보상
            _buildInfoSection(
              context: context,
              icon: Icons.military_tech, // 1등 아이콘
              iconColor: Colors.amber[700]!,
              title: '월간 랭킹 1위',
              content:
              '월간 EXP 누적 1등을 달성하신 분께는 [치킨 기프티콘]을 드립니다!',
            ),

            // 2. 월간 2등 보상
            _buildInfoSection(
              context: context,
              icon: Icons.military_tech, // 2등 아이콘
              iconColor: Colors.grey[500]!,
              title: '월간 랭킹 2위',
              content:
              '월간 EXP 누적 2등을 달성하신 분께는 [스타벅스 기프티콘]을 드립니다.',
            ),

            // 3. 집계 방식 (★ 수정된 부분)
            _buildInfoSection(
              context: context,
              icon: Icons.calendar_month_outlined,
              iconColor: Colors.blueAccent,
              title: '집계 및 지급 방식',
              content:
              '매월 1일 00시 10분에 지난달 랭킹이 최종 집계됩니다.\n\n'
                  '집계가 완료된 후, 관리자가 순위를 확인하여 1, 2위 유저분께 런드벤처 가입 시 사용하신 **이메일 주소**로 기프티콘을 발송해 드립니다.\n\n' // 기존 내용 + 줄바꿈
                  '최종 집계 및 기프티콘 발송까지 며칠 정도 소요될 수 있습니다.', // 추가된 내용
            ),

            // 4. 주의 사항
            _buildInfoSection(
              context: context,
              icon: Icons.email_outlined,
              iconColor: Colors.redAccent,
              title: '주의사항',
              content:
              '이메일 주소가 정확하지 않거나 수신이 불가능할 경우, 보상 지급이 어려울 수 있습니다. [마이페이지 > 프로필 수정]에서 현재 이메일을 꼭 확인해 주세요.\n\n'
                  '만약 이메일 수신이 불가능한 경우, \n [프로필 > 설정(톱니바퀴) > 1:1 문의]를 통해\n문의해 주세요.',
            ),
          ],
        ),
      ),
    );
  }

  // 안내 섹션 UI 헬퍼
  Widget _buildInfoSection({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String content,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 24),
              SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          // '**'를 볼드 처리하기 위해 RichText 사용
          RichText(
            text: TextSpan(
              style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[700],
                  height: 1.6, // 줄 간격
                  fontFamily: Theme.of(context).textTheme.bodyLarge?.fontFamily
              ),
              children: _buildTextSpans(content),
            ),
          )
        ],
      ),
    );
  }

  // '**'를 볼드 처리하는 헬퍼 함수
  List<TextSpan> _buildTextSpans(String text) {
    final List<TextSpan> spans = [];
    final RegExp boldRegex = RegExp(r'\*\*(.*?)\*\*'); // **text** 패턴 찾기

    text.splitMapJoin(
      boldRegex,
      onMatch: (Match match) {
        // 매치된 부분 (예: **이메일 주소**)
        spans.add(TextSpan(
          text: match.group(1), // 괄호 안의 텍스트 (예: 이메일 주소)
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87), // 볼드 스타일
        ));
        return ''; // 매치된 부분은 반환하지 않음
      },
      onNonMatch: (String nonMatch) {
        // 매치되지 않은 일반 텍스트
        spans.add(TextSpan(text: nonMatch));
        return ''; // 비매치 부분은 반환하지 않음
      },
    );

    return spans;
  }
}