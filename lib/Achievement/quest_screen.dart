// quest_screen.dart

import 'package:flutter/material.dart';
import 'package:rundventure/Achievement/quest_data.dart';
import 'package:rundventure/Achievement/quest_service.dart';
import 'package:intl/intl.dart';
import 'package:rundventure/main_screens/main_screen.dart';

class QuestScreen extends StatefulWidget {
  const QuestScreen({Key? key}) : super(key: key);

  @override
  State<QuestScreen> createState() => _QuestScreenState();
}

class _QuestScreenState extends State<QuestScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final QuestService _questService = QuestService();

  Future<Map<QuestType, List<Quest>>>? _questDataFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadQuests();
  }

  Future<void> _loadQuests() async {
    setState(() {
      _questDataFuture = _questService.getQuests();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.grey[100],
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Padding(
            padding: const EdgeInsets.all(5.0),
            child: Image.asset(
              'assets/images/Back-Navs.png', // Back-Navs.png 경로 확인
              width: 48,
              height: 48,
            ),
          ),
        ),
        title: Text(
          '퀘스트',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined, color: Colors.black87),
            tooltip: '메인 화면',
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const MainScreen()),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: Colors.black,
          tabs: const [
            Tab(text: '일일'),
            Tab(text: '주간'),
            Tab(text: '월간'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadQuests,
        child: FutureBuilder<Map<QuestType, List<Quest>>>(
          future: _questDataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              // 오류 메시지를 좀 더 자세히 표시
              print("Quest loading error: ${snapshot.error}");
              print("Stack trace: ${snapshot.stackTrace}");
              return Center(child: Text('퀘스트 로딩 중 오류가 발생했습니다. 앱을 재시작하거나 관리자에게 문의하세요.'));
            }
            if (!snapshot.hasData || snapshot.data!.values.every((list) => list.isEmpty)) {
              // 모든 탭에 데이터가 없을 때만 메시지 표시
              return TabBarView(
                controller: _tabController,
                children: [
                  _buildEmptyQuestList(QuestType.daily),
                  _buildEmptyQuestList(QuestType.weekly),
                  _buildEmptyQuestList(QuestType.monthly),
                ],
              );
            }

            final quests = snapshot.data!;

            return TabBarView(
              controller: _tabController,
              children: [
                _buildQuestList(quests[QuestType.daily] ?? [], QuestType.daily),
                _buildQuestList(quests[QuestType.weekly] ?? [], QuestType.weekly),
                _buildQuestList(quests[QuestType.monthly] ?? [], QuestType.monthly),
              ],
            );
          },
        ),
      ),
    );
  }

  // 퀘스트 목록 UI
  Widget _buildQuestList(List<Quest> quests, QuestType type) {
    if (quests.isEmpty) {
      return _buildEmptyQuestList(type); // 비어있을 때 UI 함수 호출
    }

    return ListView.builder(
      // 스크롤 시 키보드 닫기 등 상호작용 개선
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      // 부드러운 스크롤 효과
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: const EdgeInsets.only(top: 8, bottom: 8), // 목록 상하 여백 추가
      itemCount: quests.length,
      itemBuilder: (context, index) {
        final quest = quests[index];
        return _buildQuestCard(quest);
      },
    );
  }

  // 퀘스트 카드 UI
  Widget _buildQuestCard(Quest quest) {
    final progress = (quest.targetValue > 0)
        ? (quest.currentValue / quest.targetValue).clamp(0.0, 1.0)
        : 0.0;

    final formatter = NumberFormat('#,###');

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 타이틀과 보상
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 퀘스트 제목이 길 경우 줄바꿈 처리
                Expanded(
                  child: Text(
                    quest.title,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis, // 제목이 너무 길면 ... 처리
                    maxLines: 1,
                  ),
                ),
                SizedBox(width: 8), // 제목과 보상 사이 간격
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '+${formatter.format(quest.rewardXp)} XP',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber[800]),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            // 2. 퀘스트 설명
            Text(quest.description, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
            SizedBox(height: 16),
            // 3. 프로그레스 바
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 10,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                          quest.isCompleted ? Colors.green : Colors.blue
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                // 진행도 텍스트 (간결하게)
                Text(
                  // 소수점 필요 여부에 따라 포맷 변경 (예: 걸음수는 정수, km는 소수점)
                    (quest.metric == QuestMetric.km || quest.metric == QuestMetric.calories)
                        ? '${formatter.format(quest.currentValue.toInt())} / ${formatter.format(quest.targetValue.toInt())}'
                        : '${formatter.format(quest.currentValue.toInt())} / ${formatter.format(quest.targetValue.toInt())}',
                    // '${quest.currentValue.toStringAsFixed(quest.metric == QuestMetric.km ? 1:0)} / ${quest.targetValue.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[800]) // 색상 약간 진하게
                ),
              ],
            ),
            SizedBox(height: 12),
            // 4. 보상 받기 버튼
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                // 완료되었고 아직 보상을 받지 않았을 때만 활성화
                onPressed: quest.isCompleted ? () async {
                  try {
                    await _questService.claimQuestReward(quest);
                    if (!mounted) return;
                    _showCustomSnackBar('보상을 받았습니다! +${quest.rewardXp} XP');
                    _loadQuests();
                  } catch (e) {
                    if (!mounted) return;
                    _showCustomSnackBar(
                        '보상 받기 실패: ${e.toString().replaceFirst("Exception: ", "")}',
                        isError: true
                    );
                    if (e.toString().contains("이미 보상을 받았습니다")) {
                      _loadQuests();
                    }
                  }
                } : null,
                child: Text(quest.isCompleted ? '보상 받기' : '진행 중'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: quest.isCompleted ? Colors.green : Colors.grey[400], // 완료 시 초록색, 아니면 회색
                    foregroundColor: Colors.white, // 텍스트 색상 흰색
                    // 그림자 제거 등 스타일 통일
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    )
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyQuestList(QuestType type) {
    String typeName = '';
    switch(type) {
      case QuestType.daily: typeName = '일일'; break;
      case QuestType.weekly: typeName = '주간'; break;
      case QuestType.monthly: typeName = '월간'; break;
    }
      return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.list_alt_rounded, size: 80, color: Colors.grey[350]),
          SizedBox(height: 16),
          Text(
            '$typeName 퀘스트가 없습니다.',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          SizedBox(height: 8),
          Text(
            '다음 갱신 시간에 새로운 퀘스트가 지급됩니다.',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
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
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.redAccent.shade400 : Colors.blueAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(15, 5, 15, 15),
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }
}