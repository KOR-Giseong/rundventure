  import 'package:flutter/material.dart';
  import 'package:intl/intl.dart'; // 날짜 형식 지정용

  class ProfileForm extends StatefulWidget {
    final String? nickname;
    final String? email;
    final String? gender;
    final String? weight;
    final String? height;
    final String? birthdate;

    const ProfileForm({
      Key? key,
      this.nickname,
      this.email,
      this.gender,
      this.weight,
      this.height,
      this.birthdate,
    }) : super(key: key);

    @override
    _ProfileFormState createState() => _ProfileFormState();
  }

  class _ProfileFormState extends State<ProfileForm> {
    String? _selectedGender;
    TextEditingController _nicknameController = TextEditingController();
    TextEditingController _emailController = TextEditingController();
    TextEditingController _weightController = TextEditingController();
    TextEditingController _heightController = TextEditingController();
    TextEditingController _birthdateController = TextEditingController();

    @override
    void initState() {
      super.initState();
      _selectedGender = widget.gender ?? '남자'; // 기본 선택 성별
      _nicknameController.text = widget.nickname ?? '';
      _emailController.text = widget.email ?? '';
      _weightController.text = widget.weight ?? '';
      _heightController.text = widget.height ?? '';
      _birthdateController.text = widget.birthdate ?? '';
    }

    Future<void> _selectBirthdate(BuildContext context) async {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(1900),
        lastDate: DateTime.now(),
        builder: (BuildContext context, Widget? child) {
          return Theme(
            data: ThemeData.light().copyWith(
              primaryColor: Colors.blue, // 선택된 날짜의 색상
              colorScheme: ColorScheme.light(primary: Colors.blue), // 색상 스킴
              buttonTheme: ButtonThemeData(textTheme: ButtonTextTheme.primary), // 버튼 색상
              dialogBackgroundColor: Colors.white, // 배경색을 흰색으로 변경
            ),
            child: child!,
          );
        },
      );

      if (picked != null) {
        setState(() {
          _birthdateController.text = DateFormat('yyyy-MM-dd').format(picked); // 날짜 형식 지정
        });
      }
    }

    @override
    Widget build(BuildContext context) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProfileTextField(
                label: '닉네임',
                icon: Icons.person,
                controller: _nicknameController,
                width: double.infinity,
                height: 60,
              ),
              const SizedBox(height: 16),
              ProfileTextField(
                label: '이메일',
                icon: Icons.email,
                controller: _emailController,
                width: double.infinity,
                height: 60,
                readOnly: true, // 이메일 수정 불가능하도록 설정
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: GenderButton(
                      label: '남자',
                      isSelected: _selectedGender == '남자',
                      onPressed: () {
                        setState(() {
                          _selectedGender = '남자';
                        });
                      },
                      width: double.infinity,
                      height: 60,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: GenderButton(
                      label: '여자',
                      isSelected: _selectedGender == '여자',
                      onPressed: () {
                        setState(() {
                          _selectedGender = '여자';
                        });
                      },
                      width: double.infinity,
                      height: 60,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => _selectBirthdate(context), // 날짜 선택 시 호출
                child: ProfileTextField(
                  label: '생년월일',
                  icon: Icons.calendar_today,
                  controller: _birthdateController,
                  width: double.infinity,
                  height: 60,
                  readOnly: true, // 입력 방지
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ProfileImageField(
                      label: '체중',
                      imageAsset: 'assets/images/weight.png', // 체중 아이콘 이미지 경로 설정
                      controller: _weightController,
                      width: double.infinity,
                      height: 60,
                    ),
                  ),
                  const SizedBox(width: 12),
                  UnitButton(
                    label: 'KG',
                    width: 60,
                    height: 60,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ProfileImageField(
                      label: '키',
                      imageAsset: 'assets/images/Height.png', // 키 아이콘 이미지 경로 설정
                      controller: _heightController,
                      width: double.infinity,
                      height: 60,
                    ),
                  ),
                  const SizedBox(width: 12),
                  UnitButton(
                    label: 'CM',
                    width: 60,
                    height: 60,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
  }

  class ProfileTextField extends StatelessWidget {
    final String label;
    final IconData icon;
    final TextEditingController? controller;
    final double? width;
    final double? height;
    final bool readOnly;

    const ProfileTextField({
      Key? key,
      required this.label,
      required this.icon,
      this.controller,
      this.width,
      this.height,
      this.readOnly = false,
    }) : super(key: key);

    @override
    Widget build(BuildContext context) {
      return Container(
        width: width ?? double.infinity,
        height: height ?? 60,
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8F8),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Row(
          children: [
            Icon(icon, size: 24, color: Colors.grey),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: controller,
                readOnly: readOnly,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: label,
                  hintStyle: const TextStyle(
                    color: Color(0xFFADA4A5),
                    fontSize: 14,
                    fontFamily: 'Pretendard',
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  class ProfileImageField extends StatelessWidget {
    final String label;
    final String imageAsset;
    final TextEditingController? controller;
    final double? width;
    final double? height;
    final TextInputType? keyboardType;
    final TextInputAction? textInputAction;

    const ProfileImageField({
      Key? key,
      required this.label,
      required this.imageAsset,
      this.controller,
      this.width,
      this.height,
      this.keyboardType,
      this.textInputAction,
    }) : super(key: key);

    @override
    Widget build(BuildContext context) {
      return Container(
        width: width ?? double.infinity,
        height: height ?? 60,
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8F8),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Row(
          children: [
            Image.asset(imageAsset, width: 24, height: 24, color: Colors.grey),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: controller,
                keyboardType: keyboardType,
                textInputAction: textInputAction,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: label,
                  hintStyle: const TextStyle(
                    color: Color(0xFFADA4A5),
                    fontSize: 14,
                    fontFamily: 'Pretendard',
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  class GenderButton extends StatelessWidget {
    final String label;
    final bool isSelected;
    final VoidCallback onPressed;
    final double? width;
    final double? height;

    const GenderButton({
      Key? key,
      required this.label,
      required this.isSelected,
      required this.onPressed,
      this.width,
      this.height,
    }) : super(key: key);

    @override
    Widget build(BuildContext context) {
      return GestureDetector(
        onTap: onPressed,
        child: Container(
          width: width ?? double.infinity,
          height: height ?? 60,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.black : const Color(0xFFDDDADA),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontFamily: 'Pretendard',
            ),
          ),
        ),
      );
    }
  }

  class UnitButton extends StatelessWidget {
    final String label;
    final double? width;
    final double? height;

    const UnitButton({
      Key? key,
      required this.label,
      this.width,
      this.height,
    }) : super(key: key);

    @override
    Widget build(BuildContext context) {
      return Container(
        width: width ?? 60,
        height: height ?? 60,
        decoration: BoxDecoration(
          color: const Color(0xFFFF9F80),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 14,
            fontWeight: FontWeight.w400,
            fontFamily: 'Pretendard',
          ),
        ),
      );
    }
  }
