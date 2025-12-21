import 'package:flutter/material.dart';

class TermsAndConditionsScreen extends StatelessWidget {
  const TermsAndConditionsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 90),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 뒤로가기 버튼과 중앙 제목
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  child: Image.asset('assets/images/Back-Navs.png', width: 70, height: 70),
                ),
                const SizedBox(width: 80),
                Expanded(
                  child: Text(
                    '이용약관',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),

            // 이용약관 내용 텍스트 박스
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(20),
                width: MediaQuery.of(context).size.width * 0.9,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ScrollConfiguration(
                  behavior: CustomScrollBehavior(), // 커스텀 스크롤 동작 설정
                  child: SingleChildScrollView(
                    child: Text(
                      '''제1조 (목적)
이 약관은 Rundventure(이하 "회사")가 제공하는 모바일 애플리케이션(이하 "앱")과 관련된 모든 서비스(이하 "서비스")의 이용조건 및 절차, 이용자와 회사의 권리·의무 및 책임사항 등을 규정함을 목적으로 합니다.

제2조 (용어의 정의)
① "이용자"란 본 약관에 따라 회사가 제공하는 서비스를 이용하는 자를 말합니다.
② "회원"이란 앱에 개인정보를 제공하여 회원등록을 한 자로서, 회사가 제공하는 서비스를 지속적으로 이용할 수 있는 자를 말합니다.
③ "비회원"이란 회원가입 없이 회사가 제공하는 서비스를 이용하는 자를 말합니다.

제3조 (약관의 효력 및 변경)
① 본 약관은 앱 화면에 게시하거나 기타의 방법으로 공지함으로써 효력을 발생합니다.
② 회사는 관련 법령을 위반하지 않는 범위에서 본 약관을 변경할 수 있으며, 변경된 약관은 앱에 게시하거나 회원에게 통지함으로써 효력을 발생합니다.

제4조 (서비스의 제공 및 변경)
① 회사는 이용자에게 다음과 같은 서비스를 제공합니다:
  - 러닝 기록 추적 및 통계 제공
  - 사용자 간 챌린지 기능
  - 커뮤니티 게시판
  - 기타 관련 기능

② 회사는 서비스의 내용을 변경할 수 있으며, 이 경우 사전에 앱을 통해 공지합니다.

제5조 (서비스의 중단)
① 회사는 시스템 점검, 교체 및 고장 등 불가피한 사유가 발생한 경우 서비스의 제공을 일시적으로 중단할 수 있습니다.
② 이 경우 회사는 사전 또는 사후에 이를 공지합니다.

제6조 (회원가입)
① 이용자는 회사가 정한 절차에 따라 회원가입을 할 수 있으며, 필수 정보는 정확하게 입력해야 합니다.
② 회사는 등록된 정보에 허위가 있는 경우 가입을 거절하거나 취소할 수 있습니다.

제7조 (회원의 의무)
① 회원은 다음 각 호의 행위를 하여서는 안 됩니다.
  1. 타인의 정보 도용
  2. 허위 정보 등록
  3. 회사의 운영을 방해하는 행위
  4. 기타 불법적이거나 부당한 행위

제8조 (개인정보의 보호)
회사는 개인정보 보호법 등 관련 법령이 정하는 바에 따라 회원의 개인정보를 보호하기 위해 노력합니다. 개인정보의 수집, 이용, 보관, 파기에 관한 사항은 별도의 "개인정보처리방침"에 따릅니다.

제9조 (책임의 한계)
① 회사는 천재지변, 불가항력적인 사유로 인해 서비스를 제공할 수 없는 경우에는 책임이 면제됩니다.
② 회사는 이용자가 앱을 이용하여 기대하는 수익, 체중 감량 등의 효과를 보장하지 않습니다.

제10조 (분쟁의 해결)
이 약관에 따른 분쟁은 대한민국의 법령에 따라 해결하며, 회사와 회원 간에 발생한 분쟁은 회사의 본사 소재지를 관할하는 법원을 제1심 관할 법원으로 합니다.

부칙
본 약관은 2025년 6월 25일부터 시행합니다.
''',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// 커스텀 스크롤 동작 정의
class CustomScrollBehavior extends ScrollBehavior {
  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
    return Scrollbar(
      thumbVisibility: true, // 스크롤바 항상 보이기
      radius: Radius.circular(10), // 스크롤바 둥글기
      thickness: 8, // 스크롤바 두께
      child: super.buildScrollbar(context, child, details),
    );
  }
}