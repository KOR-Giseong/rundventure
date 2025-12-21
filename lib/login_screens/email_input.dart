import 'package:flutter/material.dart';

class EmailInput extends StatelessWidget {
  const EmailInput({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFFF7F8F8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Color(0xFFF7F8F8)),
      ),
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          Image.asset(
            'assets/images/Email.png', // 여기에 아이콘 PNG 파일 이름을 입력하세요.
            width: 18,
            height: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              decoration: InputDecoration(
                hintText: '이메일',
                hintStyle: TextStyle(
                  color: Color(0xFFADA4A5),
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ),
        ],
      ),
    );
  }
}

class PasswordInput extends StatelessWidget {
  const PasswordInput({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFFF7F8F8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Color(0xFFF7F8F8)),
      ),
      padding: const EdgeInsets.all(15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/Lock.png', // 여기에 이미지 파일 이름을 입력하세요.
            width: 18,
            height: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              decoration: InputDecoration(
                hintText: '비밀번호',
                hintStyle: TextStyle(
                  color: Color(0xFFADA4A5),
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
              ),
              obscureText: true,
            ),
          ),
          Image.asset(
            'assets/images/Hide-Password.png', // 여기에 이미지 파일 이름을 입력하세요.
            width: 18,
            height: 18,
          ),
        ],
      ),
    );
  }
}