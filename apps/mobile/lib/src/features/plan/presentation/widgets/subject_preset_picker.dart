import 'package:flutter/material.dart';

/// 중·고등 시험 주요 과목 카테고리 프리셋
const _categories = <String, List<String>>{
  '주요': ['국어', '영어', '수학'],
  '수학': ['수학Ⅰ', '수학Ⅱ', '미적분', '확률과통계', '기하'],
  // 중학교 과목 보강: '과학', '사회', '역사'를 전면에 포함
  '과학': ['과학', '통합과학', '물리학', '화학', '생명과학', '지구과학'],
  '사회': ['사회', '역사', '통합사회', '한국사', '세계사', '경제', '정치와법', '사회문화', '생활과윤리'],
  '기타': ['도덕', '음악', '미술', '체육', '정보', '제2외국어'],
};

/// 과목 이름에 대응하는 색상 (칩/카드 구분용)
const _subjectColors = <String, Color>{
  '국어': Color(0xFFEF4444),
  '영어': Color(0xFF3B82F6),
  '수학': Color(0xFFF59E0B),
  '수학Ⅰ': Color(0xFFF59E0B),
  '수학Ⅱ': Color(0xFFF59E0B),
  '미적분': Color(0xFFF59E0B),
  '확률과통계': Color(0xFFF59E0B),
  '기하': Color(0xFFF59E0B),
  '과학': Color(0xFF10B981),
  '통합과학': Color(0xFF10B981),
  '물리학': Color(0xFF10B981),
  '화학': Color(0xFF06B6D4),
  '생명과학': Color(0xFF22C55E),
  '지구과학': Color(0xFF84CC16),
  '사회': Color(0xFF8B5CF6),
  '역사': Color(0xFF7C3AED),
  '통합사회': Color(0xFF8B5CF6),
  '한국사': Color(0xFF8B5CF6),
  '세계사': Color(0xFF7C3AED),
  '경제': Color(0xFF6366F1),
  '정치와법': Color(0xFF6366F1),
  '사회문화': Color(0xFF8B5CF6),
  '생활과윤리': Color(0xFFA855F7),
  '도덕': Color(0xFFA855F7),
  '음악': Color(0xFFEC4899),
  '미술': Color(0xFFF472B6),
  '체육': Color(0xFF0EA5E9),
  '정보': Color(0xFF14B8A6),
  '제2외국어': Color(0xFFFF7043),
};

Color subjectColor(String subject) =>
    _subjectColors[subject] ?? const Color(0xFF94A3B8);

/// 과목 프리셋을 카테고리별로 보여주는 위젯.
/// [onSelect] 콜백으로 선택된 과목명을 전달.
class SubjectPresetPicker extends StatefulWidget {
  final ValueChanged<String> onSelect;
  final String? selected;

  const SubjectPresetPicker({
    super.key,
    required this.onSelect,
    this.selected,
  });

  @override
  State<SubjectPresetPicker> createState() => _SubjectPresetPickerState();
}

class _SubjectPresetPickerState extends State<SubjectPresetPicker>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _cats = _categories.keys.toList();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _cats.length, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TabBar(
          controller: _tab,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          dividerColor: Colors.transparent,
          indicatorColor: cs.primary,
          labelColor: cs.primary,
          unselectedLabelColor: cs.onSurfaceVariant,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: _cats.map((c) => Tab(text: c, height: 36)).toList(),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 44,
          child: TabBarView(
            controller: _tab,
            children: _cats.map((cat) {
              final subjects = _categories[cat]!;
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 2),
                itemCount: subjects.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final s = subjects[i];
                  final isSelected = widget.selected == s;
                  final color = subjectColor(s);
                  return ChoiceChip(
                    label: Text(s),
                    selected: isSelected,
                    selectedColor: color.withValues(alpha: 0.18),
                    checkmarkColor: color,
                    labelStyle: TextStyle(
                      color: isSelected ? color : cs.onSurfaceVariant,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13,
                    ),
                    side: BorderSide(
                      color: isSelected ? color : cs.outlineVariant,
                      width: isSelected ? 1.5 : 1,
                    ),
                    backgroundColor: cs.surfaceContainerLowest,
                    onSelected: (_) => widget.onSelect(s),
                  );
                },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
