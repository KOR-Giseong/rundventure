import 'package:flutter/material.dart';

class RankingInfoPopup extends StatelessWidget {
  const RankingInfoPopup({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      titlePadding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      actionsPadding: const EdgeInsets.only(bottom: 8),
      title: Row(
        children: [
          Icon(Icons.leaderboard_outlined, color: Color(0xFFEF6C00)),
          SizedBox(width: 10),
          Text(
            '랭킹 시스템 안내',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoItem(
              context,
              Icons.tab,
              '랭킹 구분',
              '랭킹은 \'주간 랭킹\'과 \'월간 랭킹\' 탭으로 나뉩니다.\n'
                  '• **주간 랭킹:** 해당 주에 획득한 경험치(EXP)로 순위를 정합니다.\n'
                  '• **월간 랭킹:** 해당 월에 누적된 총 경험치(EXP)로 순위를 정합니다.',
            ),

            _buildInfoItem(
              context,
              Icons.sync,
              '랭킹 갱신',
              '랭킹 목록은 **매일 자정(00:00)**을 기준으로 갱신됩니다.\n'
                  '내가 획득한 EXP가 목록에 반영되기까지 최대 24시간이 소요될 수 있습니다.',
            ),

            _buildInfoItem(
              context,
              Icons.format_list_numbered,
              '랭킹 표시',
              '각 랭킹 탭은 상위 30위까지 표시되며, 나의 랭킹은 등수와 관계없이 항상 상단에 별도로 표시됩니다.',
            ),

            _buildInfoItem(
              context,
              Icons.refresh,
              '점수 초기화 (EXP 리셋)',
              '• **주간 점수:** 매주 월요일 자정에 **주간 EXP**가 0으로 초기화됩니다.\n'
                  '• **월간 점수:** 매월 1일 자정에 **월간 EXP**가 0으로 초기화됩니다.',
            ),

            _buildInfoItem(
              context,
              Icons.emoji_events_outlined,
              '명예의 전당 (월간)',
              '매월 랭킹이 초기화될 때, \'월간 랭킹\' 1~3위 사용자는 \'명예의 전당\'에 기록됩니다. 이 기록은 프로필 및 업적 팝업에서 확인할 수 있습니다.',
            ),

            _buildInfoItem(
              context,
              Icons.add_circle_outline,
              '경험치 획득 방법',
              '• 자유 러닝 완료 (거리에 비례)\n• 퀘스트 보상 수령 (보상 EXP)\n• 고스트런 완료 (승리 보너스 포함)',
            ),
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text(
            '확인',
            style: TextStyle(color: Color(0xFFFF9F80), fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      ],
    );
  }

  // 정보 항목 스타일을 위한 헬퍼 위젯
  Widget _buildInfoItem(BuildContext context, IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Color(0xFFEF6C00), size: 22),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
                SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.4, fontFamily: Theme.of(context).textTheme.bodyLarge?.fontFamily),
                    children: _buildTextSpans(subtitle),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<TextSpan> _buildTextSpans(String text) {
    final List<TextSpan> spans = [];
    final RegExp boldRegex = RegExp(r'\*\*(.*?)\*\*');

    text.splitMapJoin(
      boldRegex,
      onMatch: (Match match) {
        spans.add(TextSpan(
          text: match.group(1),
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ));
        return '';
      },
      onNonMatch: (String nonMatch) {
        spans.add(TextSpan(text: nonMatch));
        return '';
      },
    );

    return spans;
  }
}