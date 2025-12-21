import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ChallengeContent extends StatelessWidget {
  const ChallengeContent({Key? key}) : super(key: key);

  // URL 열기 함수
  void _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => _launchURL(
              "https://marathon365.net/?gad_source=1&gbraid=0AAAAA-9Q6TR9-lv3J6BSL1DX4o8SXgkgQ&gclid=Cj0KCQjwoNzABhDbARIsALfY8VNyzU-Eyevcb1NxffUIYRsGYtHrxYVk98LKwEQ8pBOPcBkhpFzDkAYaAofzEALw_wcB"),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset(
              "assets/images/image 17.png",
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => _launchURL("http://www.marathon.pe.kr/schedule_index.html"),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset(
              "assets/images/image 18.png",
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ],
    );
  }
}
