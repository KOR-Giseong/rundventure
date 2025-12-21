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
          // ✅ 아이콘 색상을 랭킹 테마색과 유사하게 변경 (선택 사항)
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
            // [유지] 랭킹 구분
            _buildInfoItem(
              context,
              Icons.tab,
              '랭킹 구분',
              '랭킹은 \'주간 랭킹\'과 \'월간 랭킹\' 탭으로 나뉩니다.\n'
                  '• **주간 랭킹:** 해당 주에 획득한 경험치(EXP)로 순위를 정합니다.\n'
                  '• **월간 랭킹:** 해당 월에 누적된 총 경험치(EXP)로 순위를 정합니다.',
            ),

            // ✅✅✅ [신규 추가] 랭킹 갱신 시점 ✅✅✅
            _buildInfoItem(
              context,
              Icons.sync, // 아이콘 변경
              '랭킹 갱신', // 타이틀 변경
              '랭킹 목록은 **매일 자정(00:00)**을 기준으로 갱신됩니다.\n'
                  '내가 획득한 EXP가 목록에 반영되기까지 최대 24시간이 소요될 수 있습니다.',
            ),
            // ✅✅✅ [신규 추가 끝] ✅✅✅

            // [유지] 랭킹 표시
            _buildInfoItem(
              context,
              Icons.format_list_numbered,
              '랭킹 표시',
              '각 랭킹 탭은 상위 30위까지 표시되며, 나의 랭킹은 등수와 관계없이 항상 상단에 별도로 표시됩니다.',
            ),

            // ✅ [수정] '초기화 시점' -> '점수 초기화'
            _buildInfoItem(
              context,
              Icons.refresh,
              '점수 초기화 (EXP 리셋)', // 타이틀 변경
              '• **주간 점수:** 매주 월요일 자정에 **주간 EXP**가 0으로 초기화됩니다.\n'
                  '• **월간 점수:** 매월 1일 자정에 **월간 EXP**가 0으로 초기화됩니다.', // 내용 명확화
            ),

            // [유지] 명예의 전당
            _buildInfoItem(
              context,
              Icons.emoji_events_outlined,
              '명예의 전당 (월간)',
              '매월 랭킹이 초기화될 때, \'월간 랭킹\' 1~3위 사용자는 \'명예의 전당\'에 기록됩니다. 이 기록은 프로필 및 업적 팝업에서 확인할 수 있습니다.',
            ),

            // [유지] 경험치 획득 방법
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
          // ✅ 아이콘 색상을 랭킹 테마색과 유사하게 변경 (선택 사항)
          Icon(icon, color: Color(0xFFEF6C00), size: 22),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
                SizedBox(height: 4),
                // ✅ [수정] RichText 대신 Text 사용 (볼드 처리를 위해)
                // (TextSpan을 사용하려면 RichText 위젯이 필요하지만,
                // 여기서는 Text 위젯 내의 \n과 '**' 마크다운을 플러터가 직접
                // 해석하지 않으므로, TextSpan 대신 직접 문자열로 처리해야 합니다.)
                // (원본 코드에 이미 subtitle이 String이었으므로, 원본 코드 스타일 유지)
                // (단, '**'는 Text 위젯에서 직접 작동하지 않으므로,
                // RichText로 바꾸거나, '**'를 빼야 합니다.)
                // (원본 코드가 '**'를 그대로 출력하고 있었으므로,
                // 사용자 의도를 존중하여 RichText로 수정합니다.)

                // ✅✅✅ [수정] 마크다운(**) 스타일을 적용하기 위해 RichText로 변경 ✅✅✅
                RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.4, fontFamily: Theme.of(context).textTheme.bodyLarge?.fontFamily), // 기본 스타일
                    children: _buildTextSpans(subtitle), // 텍스트를 파싱하는 함수 호출
                  ),
                ),
                // ✅✅✅ [수정 끝] ✅✅✅
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅✅✅ [신규 헬퍼] '**'를 볼드 처리하는 함수 ✅✅✅
  List<TextSpan> _buildTextSpans(String text) {
    final List<TextSpan> spans = [];
    final RegExp boldRegex = RegExp(r'\*\*(.*?)\*\*'); // **text** 패턴 찾기

    text.splitMapJoin(
      boldRegex,
      onMatch: (Match match) {
        // 매치된 부분 (예: **주간 랭킹**)
        spans.add(TextSpan(
          text: match.group(1), // 괄호 안의 텍스트 (예: 주간 랭킹)
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
// ✅✅✅ [신규 헬퍼 끝] ✅✅✅
}