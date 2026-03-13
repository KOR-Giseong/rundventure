import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../presentation/providers/announcement_provider.dart';

/// 메인 화면 공지사항 팝업 다이얼로그입니다.
///
/// [AnnouncementProvider]에서 데이터를 받고 "오늘 하루 안 보기",
/// 관리자 삭제 버튼 등을 처리합니다.
class MainAnnouncementDialog extends StatefulWidget {
  final List<DocumentSnapshot> announcements;
  final bool isAdmin;
  final Future<void> Function(String) onHideToday;
  final Future<void> Function(String) onRemove;

  const MainAnnouncementDialog({
    Key? key,
    required this.announcements,
    required this.isAdmin,
    required this.onHideToday,
    required this.onRemove,
  }) : super(key: key);

  @override
  State<MainAnnouncementDialog> createState() => _MainAnnouncementDialogState();
}

class _MainAnnouncementDialogState extends State<MainAnnouncementDialog> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _hideTodayChecked = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: EdgeInsets.zero,
      content: SizedBox(
        width: 300,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 500),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(child: _buildPageView()),
                const SizedBox(height: 16),
                _buildFooter(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPageView() {
    return PageView.builder(
      controller: _pageController,
      onPageChanged: (page) => setState(() => _currentPage = page),
      itemCount: widget.announcements.length,
      itemBuilder: (context, index) {
        final data =
            widget.announcements[index].data() as Map<String, dynamic>;
        return _AnnouncementPageItem(
          data: data,
          isAdmin: widget.isAdmin,
          announcementId: widget.announcements[index].id,
          onRemove: () async {
            await widget.onRemove(widget.announcements[index].id);
            if (context.mounted) Navigator.of(context).pop();
          },
        );
      },
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (widget.announcements.length > 1) _PageIndicator(
          count: widget.announcements.length,
          current: _currentPage,
        ),
        const Spacer(),
        _HideTodayCheckbox(
          value: _hideTodayChecked,
          onChanged: (v) => setState(() => _hideTodayChecked = v ?? false),
        ),
        TextButton(
          onPressed: () => _onClose(context),
          child: const Text(
            '닫기',
            style: TextStyle(
              color: Colors.black,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  void _onClose(BuildContext context) {
    if (_hideTodayChecked && widget.announcements.isNotEmpty) {
      widget.onHideToday(widget.announcements[_currentPage].id);
    }
    Navigator.of(context).pop();
  }
}

// ── Sub-widgets ────────────────────────────────────────────────

class _AnnouncementPageItem extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isAdmin;
  final String announcementId;
  final VoidCallback onRemove;

  const _AnnouncementPageItem({
    required this.data,
    required this.isAdmin,
    required this.announcementId,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2.0),
              child: Icon(Icons.campaign, color: Colors.blueAccent, size: 20),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                data['title'] ?? '공지사항',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            if (isAdmin)
              SizedBox(
                width: 24,
                height: 24,
                child: IconButton(
                  icon: const Icon(Icons.delete_forever,
                      color: Colors.redAccent, size: 20),
                  onPressed: onRemove,
                  tooltip: '메인 공지에서 내리기',
                  padding: EdgeInsets.zero,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              child: Text(
                data['message'] ?? '',
                style:
                    const TextStyle(fontSize: 14, color: Colors.black87),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PageIndicator extends StatelessWidget {
  final int count;
  final int current;

  const _PageIndicator({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        return Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: current == i
                ? Colors.blueAccent
                : Colors.grey.withOpacity(0.4),
          ),
        );
      }),
    );
  }
}

class _HideTodayCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;

  const _HideTodayCheckbox({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.only(right: 4.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              value: value,
              onChanged: onChanged,
              visualDensity: VisualDensity.compact,
              activeColor: Colors.grey[700],
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            Text(
              '오늘 하루 안 보기',
              style: TextStyle(color: Colors.grey[700], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
