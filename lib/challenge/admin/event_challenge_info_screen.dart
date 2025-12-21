import 'package:flutter/material.dart';

class EventChallengeInfoScreen extends StatelessWidget {
  const EventChallengeInfoScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        // 뒤로가기 버튼 (기존과 동일한 에셋)
        leading: IconButton(
          icon: Image.asset('assets/images/Back-Navs.png', width: 60, height: 60),
          onPressed: () => Navigator.pop(context),
          padding: const EdgeInsets.only(left: 10),
        ),
        title: Text(
          "이벤트 상세 안내",
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
            _buildInfoSection(
              context: context,
              icon: Icons.emoji_events_outlined,
              title: '이벤트 챌린지란?',
              content:
              '관리자가 주최하는 특별 챌린지입니다. 정해진 기간과 선착순 인원 내에서만 참여할 수 있으며, 참여자들의 참여도를 집계하여 특별한 보상을 지급합니다.',
            ),
            _buildInfoSection(
              context: context,
              icon: Icons.assessment_outlined,
              title: '참여도 집계 방식',
              content:
              '\'참여도\'는 이벤트 챌린지에 **참여한 이후**부터 달린 총 누적 러닝 거리(km)를 기준으로 집계됩니다.\n\n이벤트 참여 전에 달린 거리는 소급 적용되지 않으며, 참여를 취소할 경우 집계된 거리는 0으로 초기화됩니다.',
            ),
            _buildInfoSection(
              context: context,
              icon: Icons.redeem_outlined,
              title: '보상 지급 안내',
              content:
              '이벤트가 종료되면(상태가 \'종료됨\'으로 변경) 관리자가 최종 집계를 시작합니다.\n\n'
                  '1. 참여도 1등 (Top Runner)\n'
                  '2. 럭키 드로우 (Lucky Runner)\n\n'
                  '위 두 분류의 당첨자를 선정하며, 이벤트 상세 내용에 기재된 보상이 지급됩니다.',
            ),
            // 4. 보상 수령 방법 (★ 수정된 부분)
            _buildInfoSection(
              context: context,
              icon: Icons.email_outlined,
              title: '보상 수령 방법',
              content:
              '모든 보상은 런드벤처 가입 시 사용하신 **회원님의 이메일 주소**로 발송됩니다. (예: 스타벅스 기프티콘 등)\n\n' // 기존 내용
                  '이벤트 종료 후 당첨자 집계 및 발송까지 며칠 정도 소요될 수 있습니다.\n\n' // 기존 내용
                  '이메일 주소가 정확하지 않거나 수신이 불가능할 경우 보상 지급이 어려울 수 있습니다.\n[프로필 > 설정(톱니바퀴) > 1:1 문의]를 통해\n문의해 주세요.', // 추가된 내용
            ),
          ],
        ),
      ),
    );
  }

  // 안내 섹션 UI (★ RichText로 수정됨)
  Widget _buildInfoSection({
    required BuildContext context,
    required IconData icon,
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
              Icon(icon, color: Colors.blueAccent, size: 24),
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
          // '**'를 볼드 처리하기 위해 RichText 사용 (★ 수정됨)
          RichText(
            text: TextSpan(
              style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[700],
                  height: 1.6, // 줄 간격
                  fontFamily: Theme.of(context).textTheme.bodyLarge?.fontFamily
              ),
              children: _buildTextSpans(content), // 헬퍼 함수 사용
            ),
          )
        ],
      ),
    );
  }

  // '**'를 볼드 처리하는 헬퍼 함수 (★ 추가됨)
  List<TextSpan> _buildTextSpans(String text) {
    final List<TextSpan> spans = [];
    final RegExp boldRegex = RegExp(r'\*\*(.*?)\*\*'); // **text** 패턴 찾기

    text.splitMapJoin(
      boldRegex,
      onMatch: (Match match) {
        // 매치된 부분 (예: **회원님의 이Mail 주소**)
        spans.add(TextSpan(
          text: match.group(1), // 괄호 안의 텍스트
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