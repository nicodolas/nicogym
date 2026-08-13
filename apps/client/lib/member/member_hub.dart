import 'package:flutter/material.dart';
import 'package:nicogym/admin/catalog_admin_screen.dart';
import 'package:nicogym/admin/catalog_api.dart';
import 'package:nicogym/help/context_help.dart';
import 'package:nicogym/member/planner_api.dart';
import 'package:nicogym/member/progress_api.dart';
import 'package:nicogym/workouts/exercise.dart';

class MemberHubScreen extends StatefulWidget {
  const MemberHubScreen({
    super.key,
    required this.exerciseLoader,
    required this.onOpenExercise,
    this.initialTab = 0,
    this.plannerRepository,
    this.catalogRepository,
    this.progressRepository,
  });

  final Future<List<Exercise>> Function() exerciseLoader;
  final ValueChanged<Exercise> onOpenExercise;
  final int initialTab;
  final PlannerRepository? plannerRepository;
  final CatalogRepository? catalogRepository;
  final ProgressRepository? progressRepository;

  @override
  State<MemberHubScreen> createState() => _MemberHubScreenState();
}

class _MemberHubScreenState extends State<MemberHubScreen> {
  late int _tab = widget.initialTab;
  late bool _progressOpened = widget.initialTab == 2;
  int _progressRefresh = 0;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    try {
      final identity = await widget.catalogRepository?.me();
      if (mounted && identity != null) {
        setState(() => _isAdmin = identity.isAdmin);
      }
    } catch (_) {
      // Catalog and planner remain usable when role lookup is temporarily offline.
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('KHÔNG GIAN CỦA BẠN'),
      actions: const [
        ContextHelpButton(
          title: 'Không gian của bạn',
          message:
              'Mở Thư viện để xem đúng kỹ thuật. Mở Lịch & gợi ý để xếp buổi tập; lịch đã xếp luôn được ưu tiên và mọi thay đổi đều cần xác nhận.',
        ),
      ],
    ),
    body: IndexedStack(
      index: _tab,
      children: [
        _ExerciseLibrary(
          loader: widget.exerciseLoader,
          onOpen: widget.onOpenExercise,
        ),
        _SchedulePlanner(repository: widget.plannerRepository),
        if (_progressOpened)
          _ProgressView(
            repository: widget.progressRepository,
            refresh: _progressRefresh,
          )
        else
          const SizedBox.shrink(),
        if (_isAdmin && widget.catalogRepository != null)
          CatalogAdminScreen(repository: widget.catalogRepository!),
      ],
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _tab,
      onDestinationSelected: (value) => setState(() {
        _tab = value;
        if (value == 2) {
          _progressOpened = true;
          _progressRefresh += 1;
        }
      }),
      destinations: [
        const NavigationDestination(
          icon: Icon(Icons.grid_view_rounded),
          label: 'Thư viện',
        ),
        const NavigationDestination(
          icon: Icon(Icons.calendar_month_outlined),
          label: 'Lịch & gợi ý',
        ),
        const NavigationDestination(
          icon: Icon(Icons.insights_outlined),
          label: 'Tiến độ',
        ),
        if (_isAdmin)
          const NavigationDestination(
            icon: Icon(Icons.admin_panel_settings_outlined),
            label: 'Quản trị',
          ),
      ],
    ),
  );
}

class _ProgressView extends StatefulWidget {
  const _ProgressView({required this.repository, required this.refresh});

  final ProgressRepository? repository;
  final int refresh;

  @override
  State<_ProgressView> createState() => _ProgressViewState();
}

class _ProgressViewState extends State<_ProgressView> {
  late Future<ProgressSummary> _summary = _load();

  Future<ProgressSummary> _load() =>
      widget.repository?.load() ??
      Future.value(
        const ProgressSummary(sessions: 0, sets: 0, volumeKg: 0, latest: []),
      );

  @override
  void didUpdateWidget(covariant _ProgressView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refresh != oldWidget.refresh) {
      _retry();
    }
  }

  Future<void> _retry() async {
    final next = _load();
    setState(() {
      _summary = next;
    });
    try {
      await next;
    } catch (_) {
      // FutureBuilder renders the error; callbacks must not leak it as unhandled.
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<ProgressSummary>(
    future: _summary,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        final message = snapshot.error is ProgressException
            ? (snapshot.error! as ProgressException).message
            : 'Chưa tải được tiến độ.';
        return RefreshIndicator(
          onRefresh: _retry,
          child: ListView(
            key: const Key('progress-error-view'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 120),
              const Icon(Icons.cloud_off_outlined, size: 40),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Center(
                child: OutlinedButton(
                  onPressed: _retry,
                  child: const Text('Thử lại'),
                ),
              ),
            ],
          ),
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final summary = snapshot.data!;
      return RefreshIndicator(
        onRefresh: _retry,
        child: ListView(
          key: const Key('progress-view'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
          children: [
            Text('TIẾN ĐỘ', style: Theme.of(context).textTheme.displayLarge),
            const SizedBox(height: 8),
            const Text('Tính từ các hiệp đã đồng bộ với tài khoản của bạn.'),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _ProgressMetric(
                  label: 'BUỔI ĐÃ TẬP',
                  value: '${summary.sessions}',
                ),
                _ProgressMetric(label: 'TỔNG HIỆP', value: '${summary.sets}'),
                _ProgressMetric(
                  label: 'KHỐI LƯỢNG',
                  value: '${_formatLoad(summary.volumeKg)} kg',
                ),
              ],
            ),
            const SizedBox(height: 26),
            Text('GẦN ĐÂY', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (summary.latest.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Text('Ghi hiệp đầu tiên để bắt đầu theo dõi tiến độ.'),
                ),
              )
            else
              for (final entry in summary.latest)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.fitness_center),
                  title: Text(entry.exerciseName),
                  subtitle: Text(_progressDate(entry.completedAt)),
                  trailing: Text(
                    '${_formatLoad(entry.loadKg)} kg × ${entry.repetitions}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
          ],
        ),
      );
    },
  );
}

class _ProgressMetric extends StatelessWidget {
  const _ProgressMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 150,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11)),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
      ),
    ),
  );
}

String _formatLoad(double value) => value == value.truncateToDouble()
    ? value.toStringAsFixed(0)
    : value.toString();

String _progressDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

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
  const _SchedulePlanner({this.repository});

  final PlannerRepository? repository;

  @override
  State<_SchedulePlanner> createState() => _SchedulePlannerState();
}

class _SchedulePlannerState extends State<_SchedulePlanner> {
  double _recoveryHours = 48;
  String _todayWorkout = 'Chân + Mông';
  bool _suggestionAccepted = false;
  bool _dismissedSuggestion = false;
  List<PlannedSession> _weeklySchedule = PlannerState.defaults.weeklySchedule;
  bool _loading = false;
  int _activeSaves = 0;
  String? _syncError;
  bool _retryLoad = false;
  bool _needsOnboarding = false;
  String _onboardingGoal = 'muscle_strength';
  int _onboardingDays = 3;
  int _onboardingMinutes = 45;

  bool get _saving => _activeSaves > 0;

  @override
  void initState() {
    super.initState();
    if (widget.repository != null) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final result = await widget.repository!.load();
      final state = result.state ?? PlannerState.defaults;
      if (!mounted) return;
      setState(() {
        _needsOnboarding = result.state == null;
        _weeklySchedule = state.weeklySchedule;
        _recoveryHours = state.recoveryHours.toDouble();
        _todayWorkout = state.todayWorkout;
        _suggestionAccepted = state.suggestionAccepted;
        _onboardingGoal = state.goal;
        _onboardingMinutes = state.sessionMinutes;
        _syncError = result.usedOfflineFallback
            ? 'Đang dùng lịch đã lưu trên thiết bị. Chạm để đồng bộ lại.'
            : null;
        _retryLoad = result.usedOfflineFallback;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _syncError = 'Đang dùng lịch trên thiết bị. Thử đồng bộ lại.';
          _retryLoad = true;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (widget.repository == null) return;
    final snapshot = PlannerState(
      weeklySchedule: _weeklySchedule,
      recoveryHours: _recoveryHours.round(),
      todayWorkout: _todayWorkout,
      suggestionAccepted: _suggestionAccepted,
      goal: _onboardingGoal,
      sessionMinutes: _onboardingMinutes,
    );
    setState(() {
      _activeSaves += 1;
      _syncError = null;
      _retryLoad = false;
    });
    try {
      await widget.repository!.save(snapshot);
      if (mounted) setState(() => _syncError = null);
    } catch (_) {
      if (mounted) {
        setState(
          () => _syncError = 'Đã lưu trên thiết bị. Chạm để đồng bộ lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _activeSaves -= 1);
    }
  }

  Future<void> _finishOnboarding() async {
    final schedule = _sampleSchedule(_onboardingDays);
    final nextSession = _nextSession(schedule, DateTime.now().weekday);
    setState(() {
      _weeklySchedule = schedule;
      _todayWorkout = nextSession.title;
      _suggestionAccepted = false;
      _dismissedSuggestion = false;
      _needsOnboarding = false;
    });
    await _save();
  }

  PlannedSession _nextSession(List<PlannedSession> schedule, int weekday) {
    final ordered = [...schedule]..sort((a, b) => a.day.compareTo(b.day));
    return ordered.firstWhere(
      (session) => session.day >= weekday,
      orElse: () => ordered.first,
    );
  }

  Future<void> _editSession(PlannedSession session) async {
    final titleController = TextEditingController(text: session.title);
    var selectedDay = session.day;
    final usedDays = _weeklySchedule
        .where((item) => item != session)
        .map((item) => item.day)
        .toSet();
    final updated = await showDialog<PlannedSession>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Sửa buổi tập'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  maxLength: 80,
                  decoration: const InputDecoration(labelText: 'Tên buổi tập'),
                ),
                DropdownButtonFormField<int>(
                  initialValue: selectedDay,
                  decoration: const InputDecoration(labelText: 'Ngày tập'),
                  items: [
                    for (var day = 1; day <= 7; day++)
                      if (!usedDays.contains(day))
                        DropdownMenuItem(
                          value: day,
                          child: Text(_dayLabel(day)),
                        ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => selectedDay = value ?? selectedDay),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                final title = titleController.text.trim();
                if (title.isNotEmpty) {
                  Navigator.pop(
                    context,
                    PlannedSession(day: selectedDay, title: title),
                  );
                }
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
    if (updated == null || !mounted) return;
    setState(() {
      _weeklySchedule =
          _weeklySchedule
              .map((item) => item == session ? updated : item)
              .toList()
            ..sort((a, b) => a.day.compareTo(b.day));
      if (_todayWorkout == session.title) _todayWorkout = updated.title;
    });
    await _save();
  }

  List<PlannedSession> _sampleSchedule(int days) {
    if (_onboardingGoal == 'general_fitness') {
      const daySlots = [1, 3, 5, 7];
      return List.generate(
        days,
        (index) => PlannedSession(
          day: daySlots[index],
          title: 'Toàn thân ${String.fromCharCode(65 + index)}',
        ),
      );
    }
    return switch (days) {
      2 => const [
        PlannedSession(day: 2, title: 'Toàn thân A'),
        PlannedSession(day: 5, title: 'Toàn thân B'),
      ],
      4 => const [
        PlannedSession(day: 1, title: 'Thân trên A'),
        PlannedSession(day: 2, title: 'Thân dưới A'),
        PlannedSession(day: 4, title: 'Thân trên B'),
        PlannedSession(day: 6, title: 'Thân dưới B'),
      ],
      _ => PlannerState.defaults.weeklySchedule,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_needsOnboarding) return _buildOnboarding(context);
    const elapsedRecoveryHours = 24;
    final exerciseCount = switch (_onboardingMinutes) {
      30 => 3,
      60 => 5,
      _ => 4,
    };
    final isScheduledToday = _weeklySchedule.any(
      (session) =>
          session.day == DateTime.now().weekday &&
          session.title == _todayWorkout,
    );
    final musclesReady = elapsedRecoveryHours >= _recoveryHours;
    final alternativeWorkout = _weeklySchedule
        .map((session) => session.title)
        .firstWhere(
          (title) => title != _todayWorkout,
          orElse: () => _todayWorkout,
        );
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
      children: [
        Text('LỊCH CỦA BẠN', style: Theme.of(context).textTheme.displayLarge),
        const SizedBox(height: 8),
        const Text(
          'Ưu tiên lịch đã xếp. Thuật toán chỉ đề nghị đổi và luôn cần bạn xác nhận.',
        ),
        if (_loading || _saving) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
        ],
        if (_syncError != null) ...[
          const SizedBox(height: 12),
          ActionChip(
            avatar: const Icon(Icons.sync_problem_outlined),
            label: Text(_syncError!),
            onPressed: _saving || _loading
                ? null
                : (_retryLoad ? _load : _save),
          ),
        ],
        const SizedBox(height: 22),
        Card(
          key: const Key('today-workout-card'),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isScheduledToday ? 'HÔM NAY' : 'BUỔI TIẾP THEO'),
                const SizedBox(height: 8),
                Text(
                  _todayWorkout,
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                Text(
                  '$_onboardingMinutes phút · $exerciseCount bài · ${exerciseCount * 3} hiệp',
                ),
              ],
            ),
          ),
        ),
        if (!musclesReady &&
            !_suggestionAccepted &&
            alternativeWorkout != _todayWorkout &&
            !_dismissedSuggestion) ...[
          const SizedBox(height: 12),
          Card(
            color: const Color(0xFFC7F36B),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('GỢI Ý THEO CẤU HÌNH'),
                  const SizedBox(height: 8),
                  Text(
                    'Đổi sang $alternativeWorkout?',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    'Chưa có lịch sử tập, tạm dùng mặc định. Nhóm cơ của $_todayWorkout được ước tính mới nghỉ $elapsedRecoveryHours giờ, còn khoảng ${(_recoveryHours - elapsedRecoveryHours).round()} giờ theo cấu hình. Lịch tuần không tự dịch chuyển.',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: _loading
                            ? null
                            : () => setState(() => _dismissedSuggestion = true),
                        child: const Text('Giữ lịch hôm nay'),
                      ),
                      FilledButton(
                        onPressed: _loading
                            ? null
                            : () {
                                setState(() {
                                  _todayWorkout = alternativeWorkout;
                                  _suggestionAccepted = true;
                                });
                                _save();
                              },
                        child: Text('Đổi sang $alternativeWorkout'),
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
        for (final session in _weeklySchedule)
          ListTile(
            key: ValueKey('schedule-${session.day}'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today_outlined),
            title: Text(session.title),
            subtitle: Text(_dayLabel(session.day)),
            trailing: const Icon(Icons.edit_outlined),
            onTap: _saving ? null : () => _editSession(session),
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
          onChanged: _loading
              ? null
              : (value) => setState(() => _recoveryHours = value),
          onChangeEnd: _loading ? null : (_) => _save(),
        ),
        const Text(
          'Đây là quy tắc lập lịch, không phải chẩn đoán y tế. Bạn có thể chỉnh riêng từng nhóm cơ ở phiên bản tiếp theo.',
        ),
      ],
    );
  }

  Widget _buildOnboarding(BuildContext context) => ListView(
    key: const Key('planner-onboarding'),
    padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
    children: [
      Text(
        'BẮT ĐẦU NHẸ NHÀNG',
        style: Theme.of(context).textTheme.displayLarge,
      ),
      const SizedBox(height: 8),
      const Text(
        'Chọn vài thông tin cơ bản. NicoGym sẽ tạo lịch mẫu; bạn luôn có thể sửa lại sau.',
      ),
      const SizedBox(height: 24),
      Text('MỤC TIÊU', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'muscle_strength', label: Text('Tăng cơ')),
          ButtonSegment(value: 'general_fitness', label: Text('Khỏe hơn')),
        ],
        selected: {_onboardingGoal},
        onSelectionChanged: (value) =>
            setState(() => _onboardingGoal = value.first),
      ),
      const SizedBox(height: 22),
      Text('SỐ BUỔI MỖI TUẦN', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      SegmentedButton<int>(
        segments: const [
          ButtonSegment(value: 2, label: Text('2 buổi')),
          ButtonSegment(value: 3, label: Text('3 buổi')),
          ButtonSegment(value: 4, label: Text('4 buổi')),
        ],
        selected: {_onboardingDays},
        onSelectionChanged: (value) =>
            setState(() => _onboardingDays = value.first),
      ),
      const SizedBox(height: 22),
      Text('THỜI GIAN MỖI BUỔI', style: Theme.of(context).textTheme.titleLarge),
      SegmentedButton<int>(
        segments: const [
          ButtonSegment(value: 30, label: Text('30 phút')),
          ButtonSegment(value: 45, label: Text('45 phút')),
          ButtonSegment(value: 60, label: Text('60 phút')),
        ],
        selected: {_onboardingMinutes},
        onSelectionChanged: (value) =>
            setState(() => _onboardingMinutes = value.first),
      ),
      const SizedBox(height: 16),
      FilledButton.icon(
        key: const Key('create-sample-plan'),
        onPressed: _saving ? null : _finishOnboarding,
        icon: const Icon(Icons.auto_awesome_outlined),
        label: Text(
          'Tạo lịch $_onboardingDays buổi · $_onboardingMinutes phút',
        ),
      ),
      const SizedBox(height: 10),
      Text(
        'Đây là lịch khởi đầu theo mục tiêu đã chọn, không phải chỉ định y tế.',
        textAlign: TextAlign.center,
      ),
    ],
  );

  String _dayLabel(int day) => switch (day) {
    1 => 'Thứ hai',
    2 => 'Thứ ba',
    3 => 'Thứ tư',
    4 => 'Thứ năm',
    5 => 'Thứ sáu',
    6 => 'Thứ bảy',
    _ => 'Chủ nhật',
  };
}
