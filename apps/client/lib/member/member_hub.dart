import 'package:flutter/material.dart';
import 'package:nicogym/workouts/exercise.dart';

class MemberHubScreen extends StatefulWidget {
  const MemberHubScreen({
    super.key,
    required this.exerciseLoader,
    required this.onOpenExercise,
    this.initialTab = 0,
  });

  final Future<List<Exercise>> Function() exerciseLoader;
  final ValueChanged<Exercise> onOpenExercise;
  final int initialTab;

  @override
  State<MemberHubScreen> createState() => _MemberHubScreenState();
}

class _MemberHubScreenState extends State<MemberHubScreen> {
  late int _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('KHÔNG GIAN CỦA BẠN')),
    body: IndexedStack(
      index: _tab,
      children: [
        _ExerciseLibrary(
          loader: widget.exerciseLoader,
          onOpen: widget.onOpenExercise,
        ),
        const _SchedulePlanner(),
      ],
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _tab,
      onDestinationSelected: (value) => setState(() => _tab = value),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.grid_view_rounded),
          label: 'Thư viện',
        ),
        NavigationDestination(
          icon: Icon(Icons.calendar_month_outlined),
          label: 'Lịch & gợi ý',
        ),
      ],
    ),
  );
}

class _ExerciseLibrary extends StatefulWidget {
  const _ExerciseLibrary({required this.loader, required this.onOpen});

  final Future<List<Exercise>> Function() loader;
  final ValueChanged<Exercise> onOpen;

  @override
  State<_ExerciseLibrary> createState() => _ExerciseLibraryState();
}

class _ExerciseLibraryState extends State<_ExerciseLibrary> {
  late final Future<List<Exercise>> _exercises = widget.loader();
  String _category = 'Tất cả';

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Exercise>>(
    future: _exercises,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Center(child: Text('Không tải được thư viện bài tập.'));
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final exercises = snapshot.data!;
      final categories = [
        'Tất cả',
        ...{for (final item in exercises) item.category},
      ];
      final visible = _category == 'Tất cả'
          ? exercises
          : exercises.where((item) => item.category == _category).toList();
      return CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TOÀN THÂN',
                    style: Theme.of(context).textTheme.displayLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${exercises.length} bài đã biên soạn · dùng được offline',
                  ),
                  const SizedBox(height: 18),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final category in categories)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(category),
                              selected: category == _category,
                              onSelected: (_) =>
                                  setState(() => _category = category),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 430,
                mainAxisExtent: 142,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: visible.length,
              itemBuilder: (context, index) {
                final exercise = visible[index];
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    mouseCursor: SystemMouseCursors.click,
                    onTap: () => widget.onOpen(exercise),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            exercise.category,
                            style: const TextStyle(color: Color(0xFF74786E)),
                          ),
                          const Spacer(),
                          Text(
                            exercise.name,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            exercise.primaryMuscles.join(' · '),
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
    },
  );
}

class _SchedulePlanner extends StatefulWidget {
  const _SchedulePlanner();

  @override
  State<_SchedulePlanner> createState() => _SchedulePlannerState();
}

class _SchedulePlannerState extends State<_SchedulePlanner> {
  double _recoveryHours = 48;
  bool _acceptedSuggestion = false;
  bool _dismissedSuggestion = false;

  @override
  Widget build(BuildContext context) {
    final legsReady = 24 >= _recoveryHours;
    final today = _acceptedSuggestion ? 'Ngực + Tay sau' : 'Chân + Mông';
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
      children: [
        Text('LỊCH CỦA BẠN', style: Theme.of(context).textTheme.displayLarge),
        const SizedBox(height: 8),
        const Text(
          'Ưu tiên lịch đã xếp. Thuật toán chỉ đề nghị đổi và luôn cần bạn xác nhận.',
        ),
        const SizedBox(height: 22),
        Card(
          key: const Key('today-workout-card'),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('HÔM NAY'),
                const SizedBox(height: 8),
                Text(today, style: Theme.of(context).textTheme.headlineLarge),
                const Text('45 phút · 4 bài · 12 hiệp'),
              ],
            ),
          ),
        ),
        if (!legsReady && !_acceptedSuggestion && !_dismissedSuggestion) ...[
          const SizedBox(height: 12),
          Card(
            color: const Color(0xFFC7F36B),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('GỢI Ý THEO PHỤC HỒI'),
                  const SizedBox(height: 8),
                  Text(
                    'Đổi sang Ngực + Tay sau?',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    'Chân mới nghỉ 24 giờ, còn khoảng ${(_recoveryHours - 24).round()} giờ theo cấu hình của bạn.',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () =>
                            setState(() => _dismissedSuggestion = true),
                        child: const Text('Giữ lịch cũ'),
                      ),
                      FilledButton(
                        onPressed: () =>
                            setState(() => _acceptedSuggestion = true),
                        child: const Text('Xác nhận đổi'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Text('TUẦN NÀY', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        for (final session in const [
          ('Thứ hai', 'Ngực + Tay sau'),
          ('Thứ tư', 'Lưng + Tay trước'),
          ('Thứ sáu', 'Chân + Mông'),
        ])
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today_outlined),
            title: Text(session.$2),
            subtitle: Text(session.$1),
            trailing: const Icon(Icons.drag_handle_rounded),
          ),
        const Divider(height: 32),
        Text(
          'CẤU HÌNH PHỤC HỒI CHUNG',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text('${_recoveryHours.round()} giờ trước khi tập lại cùng nhóm cơ'),
        Slider(
          value: _recoveryHours,
          min: 24,
          max: 96,
          divisions: 6,
          label: '${_recoveryHours.round()} giờ',
          onChanged: (value) => setState(() => _recoveryHours = value),
        ),
        const Text(
          'Đây là quy tắc lập lịch, không phải chẩn đoán y tế. Bạn có thể chỉnh riêng từng nhóm cơ ở phiên bản tiếp theo.',
        ),
      ],
    );
  }
}
