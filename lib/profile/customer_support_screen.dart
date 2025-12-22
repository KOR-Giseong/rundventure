import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class CustomerSupportScreen extends StatelessWidget {
  const CustomerSupportScreen({Key? key}) : super(key: key);

  void _showEmailOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.email_outlined, color: Colors.blueAccent),
                  title: const Text('기본 이메일 앱'),
                  onTap: () async {
                    Navigator.pop(context);
                    final Uri emailUri = Uri(
                      scheme: 'mailto',
                      path: 'support@rundventure.co.kr',
                      query: Uri.encodeFull(
                        'subject=런드벤처 고객 문의&body=문의 내용을 작성해주세요.',
                      ),
                    );
                    if (await canLaunchUrl(emailUri)) {
                      await launchUrl(emailUri);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('이메일 앱을 열 수 없습니다.')),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: Image.asset('assets/images/gmail_icon.png', width: 24),
                  title: const Text('Gmail 앱으로 열기'),
                  onTap: () async {
                    Navigator.pop(context);
                    final Uri gmailUri = Uri(
                      scheme: 'mailto',
                      path: 'support@rundventure.co.kr',
                      query: Uri.encodeFull(
                        'subject=런드벤처 고객 문의&body=문의 내용을 작성해주세요.',
                      ),
                    );

                    try {
                      await launchUrl(gmailUri);
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Gmail 앱을 열 수 없습니다. 설치되어 있는지 확인해주세요.')),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: Image.asset('assets/images/naver_icon.png', width: 24),
                  title: const Text('네이버 메일'),
                  onTap: () async {
                    Navigator.pop(context);
                    final Uri naverUri = Uri.parse('https://mail.naver.com');
                    await launchUrl(naverUri, mode: LaunchMode.externalApplication);

                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        title: const Text('안내'),
                        content: const Text('메일 주소가 자동으로 입력되지 않을 수 있습니다.\n받는 사람: support@rundventure.co.kr'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('확인'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Image.asset(
            'assets/images/Back-Navs.png',
            width: 40,
            height: 40,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          '고객센터',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.support_agent_rounded,
                    size: 40,
                    color: Colors.blueAccent.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '무엇을 도와드릴까요?',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '런드벤처 앱에 대해 궁금한 점이나 불편 사항이 있으시면 언제든 문의해주세요.',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade700,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showEmailOptions(context),
                      icon: const Icon(Icons.mail_outline, size: 20),
                      label: const Text('이메일로 문의하기'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'support@rundventure.co.kr',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}