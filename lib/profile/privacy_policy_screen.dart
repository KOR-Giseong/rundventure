import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leadingWidth: 70,
        leading: Padding(
          padding: const EdgeInsets.only(left: 20.0),
          child: IconButton(
            icon: Image.asset('assets/images/Back-Navs.png', width: 45, height: 45),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ),
        title: const Text('개인정보 처리방침', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
        titleSpacing: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '런드벤처 개인정보 처리방침',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              '시행일: 2025년 10월 31일',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            SizedBox(height: 24),
            _buildArticleTitle('제1조 (총칙)'),
            _buildArticleBody(
              '런드벤처(이하 "회사"라 함)는 이용자의 개인정보를 중요시하며, 「정보통신망 이용촉진 및 정보보호 등에 관한 법률」, 「개인정보보호법」 등 관련 법규를 준수하고 있습니다. 회사는 본 개인정보 처리방침을 통하여 이용자가 제공하는 개인정보가 어떠한 용도와 방식으로 이용되고 있으며, 개인정보보호를 위해 어떠한 조치가 취해지고 있는지 알려드립니다.',
            ),
            SizedBox(height: 16),
            _buildArticleTitle('제2조 (수집하는 개인정보 항목 및 수집방법)'),
            _buildArticleBody(
              '1. 수집 항목\n'
                  ' 가. 필수 항목 : 이메일, 비밀번호, 닉네임\n'
                  ' 나. 선택 항목 : 성별, 생년월일, 키, 체중 (서비스 내 기능 이용 시)\n'
                  ' 다. 자동 수집 : 서비스 이용 기록, 접속 로그, 쿠키, 접속 IP 정보, 기기 정보 (OS, 기기 식별번호)\n'
                  ' 라. 위치 정보 : 운동 기록 시 GPS를 통한 위치 정보\n\n'
                  '2. 수집 방법 : 회원가입, 소셜 로그인 연동, 서비스 이용 과정에서 자동 수집, 고객센터 문의',
            ),
            SizedBox(height: 16),
            _buildArticleTitle('제3조 (개인정보의 수집 및 이용목적)'),
            _buildArticleBody(
              '회사는 수집한 개인정보를 다음의 목적을 위해 활용합니다.\n'
                  ' 가. 회원 관리 : 회원제 서비스 이용에 따른 본인 식별, 불량 회원의 부정 이용 방지와 비인가 사용 방지, 가입 의사 확인, 연령 확인, 분쟁 조정을 위한 기록 보존, 민원 처리\n'
                  ' 나. 서비스 제공 : 러닝 기록 측정, 랭킹 산정, 챌린지 운영, 친구 기능, 고객 문의 응대\n'
                  ' 다. 신규 서비스 개발 및 마케팅·광고에의 활용 : 신규 서비스 개발 및 맞춤 서비스 제공, 통계학적 특성에 따른 서비스 제공 및 광고 게재, 이벤트 정보 제공',
            ),
            SizedBox(height: 16),
            _buildArticleTitle('제4조 (개인정보의 보유 및 이용 기간)'),
            _buildArticleBody(
              '이용자의 개인정보는 원칙적으로 개인정보의 수집 및 이용목적이 달성되면 지체 없이 파기합니다. 단, 다음의 정보에 대해서는 아래의 이유로 명시한 기간 동안 보존합니다.\n\n'
                  '1. 회사 내부 방침에 의한 정보 보유 사유\n'
                  ' - 부정이용기록 : 1년 (부정 이용 방지)\n\n'
                  '2. 관련 법령에 의한 정보 보유 사유\n'
                  ' - 계약 또는 청약철회 등에 관한 기록 : 5년 (전자상거래 등에서의 소비자보호에 관한 법률)\n'
                  ' - 대금결제 및 재화 등의 공급에 관한 기록 : 5년\n'
                  ' - 소비자의 불만 또는 분쟁처리에 관한 기록 : 3년\n'
                  ' - 본인확인에 관한 기록 : 6개월 (정보통신망법)\n'
                  ' - 방문에 관한 기록 : 3개월 (통신비밀보호법)',
            ),
            SizedBox(height: 16),
            _buildArticleTitle('제5조 (개인정보의 파기절차 및 방법)'),
            _buildArticleBody(
              '회사는 원칙적으로 개인정보 수집 및 이용목적이 달성된 후에는 해당 정보를 지체 없이 파기합니다. 파기절차 및 방법은 다음과 같습니다.\n'
                  ' - 파기절차 : 이용자가 회원가입 등을 위해 입력한 정보는 목적이 달성된 후 별도의 DB로 옮겨져(종이의 경우 별도의 서류함) 내부 방침 및 기타 관련 법령에 의한 정보보호 사유에 따라(보유 및 이용 기간 참조) 일정 기간 저장된 후 파기됩니다.\n'
                  ' - 파기방법 : 전자적 파일 형태로 저장된 개인정보는 기록을 재생할 수 없는 기술적 방법을 사용하여 삭제합니다. 종이에 출력된 개인정보는 분쇄기로 분쇄하거나 소각을 통하여 파기합니다.',
            ),
            SizedBox(height: 16),
            _buildArticleTitle('제6조 (개인정보의 제3자 제공)'),
            _buildArticleBody(
              '회사는 이용자들의 개인정보를 원칙적으로 외부에 제공하지 않습니다. 다만, 아래의 경우에는 예외로 합니다.\n'
                  ' - 이용자들이 사전에 동의한 경우\n'
                  ' - 법령의 규정에 의거하거나, 수사 목적으로 법령에 정해진 절차와 방법에 따라 수사기관의 요구가 있는 경우',
            ),
            SizedBox(height: 16),
            _buildArticleTitle('제7조 (이용자 및 법정대리인의 권리와 그 행사방법)'),
            _buildArticleBody(
              '1. 이용자는 언제든지 등록되어 있는 자신의 개인정보를 조회하거나 수정할 수 있으며 회원 탈퇴를 요청할 수도 있습니다.\n'
                  '2. 개인정보 조회, 수정을 위해서는 ‘내 정보 수정’을, 회원 탈퇴를 위해서는 ‘회원 탈퇴’ 기능을 통하여 본인 확인 절차를 거치신 후 직접 열람, 정정 또는 탈퇴가 가능합니다.\n'
                  '3. 혹은 개인정보보호 책임자에게 서면, 전화 또는 이메일로 연락하시면 지체 없이 조치하겠습니다.',
            ),
            SizedBox(height: 16),
            _buildArticleTitle('제8조 (개인정보 자동 수집 장치의 설치, 운영 및 거부)'),
            _buildArticleBody(
              '회사는 이용자에게 특화된 맞춤 서비스를 제공하기 위해서 이용자들의 정보를 저장하고 수시로 불러오는 ‘쿠키(cookie)’를 사용합니다. 이용자는 쿠키 설치에 대한 선택권을 가지고 있습니다. 따라서, 이용자는 웹브라우저에서 옵션을 설정함으로써 모든 쿠키를 허용하거나, 쿠키가 저장될 때마다 확인을 거치거나, 아니면 모든 쿠키의 저장을 거부할 수도 있습니다.',
            ),
            SizedBox(height: 16),
            _buildArticleTitle('제9조 (개인정보의 기술적/관리적 보호 대책)'),
            _buildArticleBody(
              '회사는 이용자들의 개인정보를 처리함에 있어 개인정보가 분실, 도난, 유출, 변조 또는 훼손되지 않도록 안전성 확보를 위하여 다음과 같은 기술적/관리적 대책을 강구하고 있습니다.\n'
                  '1. 비밀번호 암호화 : 회원 비밀번호는 암호화되어 저장 및 관리되고 있어 본인만이 알고 있습니다.\n'
                  '2. 해킹 등에 대비한 대책 : 회사는 해킹이나 컴퓨터 바이러스 등에 의해 회원의 개인정보가 유출되거나 훼손되는 것을 막기 위해 최선을 다하고 있습니다.',
            ),
            SizedBox(height: 16),
            _buildArticleTitle('제10조 (개인정보보호 책임자)'),
            _buildArticleBody(
              '회사는 이용자의 개인정보를 보호하고 개인정보와 관련한 불만을 처리하기 위하여 아래와 같이 관련 부서 및 개인정보보호 책임자를 지정하고 있습니다.\n\n'
                  ' - 개인정보보호 책임자 : 홍기성\n'
                  ' - 이메일 : support@rundventure.com\n'
                  ' - 전화번호 : 010-5572-4143\n\n'
                  '기타 개인정보 침해에 대한 신고나 상담이 필요하신 경우에는 아래 기관에 문의하시기 바랍니다.\n'
                  ' - 개인정보침해신고센터 (privacy.kisa.or.kr / 국번없이 118)\n'
                  ' - 대검찰청 사이버수사과 (www.spo.go.kr / 국번없이 1301)\n'
                  ' - 경찰청 사이버안전지킴이 (www.police.go.kr / 국번없이 182)',
            ),
            SizedBox(height: 16),
            _buildArticleTitle('제11조 (고지의 의무)'),
            _buildArticleBody(
              '현 개인정보 처리방침 내용 추가, 삭제 및 수정이 있을 시에는 개정 최소 7일 전부터 앱 내 공지사항을 통하여 고지할 것입니다.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArticleTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildArticleBody(String body) {
    return Text(
      body,
      style: TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
    );
  }
}
