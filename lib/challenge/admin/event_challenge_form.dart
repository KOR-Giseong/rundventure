import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EventChallengeForm extends StatefulWidget {
  const EventChallengeForm({Key? key}) : super(key: key);

  @override
  State<EventChallengeForm> createState() => _EventChallengeFormState();
}

class _EventChallengeFormState extends State<EventChallengeForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _sloganController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _participantLimitController =
  TextEditingController();
  final TextEditingController _deadlineDaysController = TextEditingController();
  final TextEditingController _rewardController = TextEditingController(); // 상품 안내

  bool _isRankingPublic = true; // 참여도 랭킹 공개 여부
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _sloganController.dispose();
    _durationController.dispose();
    _participantLimitController.dispose();
    _deadlineDaysController.dispose();
    _rewardController.dispose();
    super.dispose();
  }

  void _showCustomSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor:
        isError ? Colors.redAccent.shade400 : Color(0xFFFF9F80),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(15, 5, 15, 15),
      ),
    );
  }

  Future<void> _saveEventChallenge() async {
    if (!_formKey.currentState!.validate()) {
      _showCustomSnackBar('모든 필수 항목을 올바르게 입력해주세요.', isError: true);
      return;
    }

    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      _showCustomSnackBar('관리자 정보를 찾을 수 없습니다.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final String adminEmail = user.email!;
      final String challengeId =
          'event_${DateTime.now().millisecondsSinceEpoch}';

      final int duration = int.parse(_durationController.text);
      final int deadlineDays = int.parse(_deadlineDaysController.text);
      final int participantLimit =
      int.parse(_participantLimitController.text);

      // 마감일 계산 (챌린지 시작일 = 지금)
      final DateTime now = DateTime.now();
      // 종료일 = 지금 + 총 기간
      final DateTime endDate = now.add(Duration(days: duration));
      // 참여 마감일 = 종료일 - 마감 N일 전
      final DateTime participationDeadlineDate =
      endDate.subtract(Duration(days: deadlineDays));

      // 참여 마감일이 지금보다 이전이면 안됨
      if (participationDeadlineDate.isBefore(now)) {
        _showCustomSnackBar('참여 마감일(종료 $deadlineDays일 전)이 현재 시간보다 빠릅니다. 기간이나 마감일을 조절해주세요.', isError: true);
        setState(() => _isLoading = false);
        return;
      }

      final Map<String, dynamic> eventData = {
        'id': challengeId, // 문서 ID를 필드에도 저장
        'adminEmail': adminEmail,
        'name': _nameController.text.trim(),
        'slogan': _sloganController.text.trim(),
        'participantLimit': participantLimit, // 선착순 인원
        'duration': duration, // 총 기간 (일)
        'participationDeadlineDays': deadlineDays, // 종료 N일 전 마감
        'participationDeadlineDate':
        Timestamp.fromDate(participationDeadlineDate), // 실제 마감 날짜
        'isRankingPublic': _isRankingPublic, // 랭킹 공개 여부
        'status': 'active', // 'active', 'ended'
        'timestamp': FieldValue.serverTimestamp(), // 생성일
        'endDate': Timestamp.fromDate(endDate), // 실제 종료 날짜
        'participantCount': 0, // 현재 참여자 수 (증가/감소용)
        'rewardInfo': _rewardController.text.trim().isNotEmpty
            ? _rewardController.text.trim()
            : '이벤트 종료 후 참여도를 집계하여 우수 참여자 및 랜덤 추첨을 통해 관리자가 직접 이메일로 상품을 지급할 예정입니다.',
      };

      await FirebaseFirestore.instance
          .collection('eventChallenges')
          .doc(challengeId)
          .set(eventData);

      _showCustomSnackBar('이벤트 챌린지가 성공적으로 생성되었습니다.');
      if (mounted) Navigator.pop(context);

    } catch (e) {
      _showCustomSnackBar('챌린지 생성 중 오류가 발생했습니다: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: Image.asset('assets/images/Back-Navs.png', width: 60, height: 60),
            onPressed: () => Navigator.pop(context),
            padding: const EdgeInsets.only(left: 10),
          ),
          title: Text(
            '이벤트 챌린지 생성',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black
            ),
          ),
        ),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('기본 정보', style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold
                      )),
                      SizedBox(height: 16),
                      // 챌린지 이름
                      TextFormField(
                        controller: _nameController,
                        decoration: _inputDecoration('이벤트 챌린지 이름', Icons.emoji_events),
                        validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? '이름을 입력하세요.'
                            : null,
                      ),
                      SizedBox(height: 16),
                      // 챌린지 슬로건
                      TextFormField(
                        controller: _sloganController,
                        decoration: _inputDecoration('챌린지 슬로건 (예: 함께 100km 달려요!)', Icons.campaign),
                        maxLines: 3,
                        validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? '슬로건을 입력하세요.'
                            : null,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                _buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('참여 조건', style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold
                      )),
                      SizedBox(height: 16),
                      // 선착순 인원
                      TextFormField(
                        controller: _participantLimitController,
                        decoration: _inputDecoration('선착순 참여 인원 (예: 100)', Icons.people_alt),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty)
                            return '인원을 입력하세요.';
                          if (int.tryParse(value) == null ||
                              int.parse(value) <= 0) return '1 이상의 숫자를 입력하세요.';
                          return null;
                        },
                      ),
                      SizedBox(height: 16),
                      // 총 챌린지 기간
                      TextFormField(
                        controller: _durationController,
                        decoration: _inputDecoration('총 챌린지 기간 (일) (예: 30)', Icons.calendar_today),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty)
                            return '기간을 입력하세요.';
                          if (int.tryParse(value) == null ||
                              int.parse(value) <= 0) return '1 이상의 숫자를 입력하세요.';
                          return null;
                        },
                      ),
                      SizedBox(height: 16),
                      // 참여 마감일
                      TextFormField(
                        controller: _deadlineDaysController,
                        decoration: _inputDecoration('참여 마감 (종료 N일 전) (예: 10)', Icons.timer_off),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty)
                            return '마감일을 입력하세요.';
                          if (int.tryParse(value) == null ||
                              int.parse(value) < 0) return '0 이상의 숫자를 입력하세요.';
                          // 총 기간보다 마감일이 더 길 순 없음
                          if (_durationController.text.isNotEmpty &&
                              int.tryParse(value) != null &&
                              int.tryParse(_durationController.text) != null &&
                              int.parse(value) >
                                  int.parse(_durationController.text)) {
                            return '총 기간보다 길 수 없습니다.';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                _buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('설정 및 보상', style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold
                      )),
                      SizedBox(height: 10),
                      // 랭킹 공개 여부
                      SwitchListTile(
                        title: Text('참여도 랭킹 공개'),
                        subtitle: Text('참여자들이 서로의 닉네임(마스킹)과 순위를 볼 수 있습니다.'),
                        value: _isRankingPublic,
                        onChanged: (value) {
                          setState(() => _isRankingPublic = value);
                        },
                        activeColor: Colors.blueAccent,
                        contentPadding: EdgeInsets.zero,
                      ),
                      SizedBox(height: 10),
                      // 상품 지급 안내 (선택)
                      TextFormField(
                        controller: _rewardController,
                        decoration: _inputDecoration('상품 지급 안내 (선택 사항)', Icons.card_giftcard, isOptional: true),
                        maxLines: 4,
                        // Validator 없음 (선택 사항)
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveEventChallenge,
                  child: _isLoading
                      ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                      : Text('이벤트 챌린지 생성하기',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!)
      ),
      child: child,
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon, {bool isOptional = false}) {
    return InputDecoration(
      labelText: label,
      hintText: isOptional ? '입력하지 않으면 기본 안내 문구가 표시됩니다.' : null,
      prefixIcon: Icon(icon, color: Colors.grey[600]),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.blueAccent, width: 2),
      ),
      fillColor: Colors.grey[50],
      filled: true,
    );
  }
}