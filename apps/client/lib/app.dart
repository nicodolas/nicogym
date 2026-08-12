import 'package:flutter/material.dart';
import 'package:nicogym/app/app_theme.dart';
import 'package:nicogym/auth/auth_api.dart';
import 'package:nicogym/admin/catalog_api.dart';
import 'package:nicogym/auth/auth_screen.dart';
import 'package:nicogym/features/account/account_status_screen.dart';
import 'package:nicogym/features/workout/workout_screen.dart';
import 'package:nicogym/member/member_hub.dart';
import 'package:nicogym/member/planner_api.dart';
import 'package:nicogym/workouts/exercise.dart';
import 'package:url_launcher/url_launcher.dart';

class NicoGymApp extends StatelessWidget {
  const NicoGymApp({
    super.key,
    this.showRecoverySuggestion = false,
    this.apkDownloadUrl = const String.fromEnvironment('APK_DOWNLOAD_URL'),
    this.apiBaseUrl = const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://localhost:3000',
    ),
    this.baseAppVersion = const String.fromEnvironment(
      'BASE_APP_VERSION',
      defaultValue: '1.1.1+5',
    ),
    this.exerciseLoader = ExerciseLibrary.load,
    this.memberTokenStore,
  });

  final bool showRecoverySuggestion;
  final String apkDownloadUrl;
  final String apiBaseUrl;
  final String baseAppVersion;
  final Future<List<Exercise>> Function() exerciseLoader;
  final TokenStore? memberTokenStore;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NicoGym',
      debugShowCheckedModeBanner: false,
      theme: buildNicoGymTheme(),
      home: TodayScreen(
        showRecoverySuggestion: showRecoverySuggestion,
        apkDownloadUrl: apkDownloadUrl,
        apiBaseUrl: apiBaseUrl,
        baseAppVersion: baseAppVersion,
        exerciseLoader: exerciseLoader,
        memberTokenStore: memberTokenStore,
      ),
    );
  }
}

class TodayScreen extends StatelessWidget {
  const TodayScreen({
    super.key,
    required this.showRecoverySuggestion,
    required this.apkDownloadUrl,
    required this.apiBaseUrl,
    required this.baseAppVersion,
    required this.exerciseLoader,
    required this.memberTokenStore,
  });

  final bool showRecoverySuggestion;
  final String apkDownloadUrl;
  final String apiBaseUrl;
  final String baseAppVersion;
  final Future<List<Exercise>> Function() exerciseLoader;
  final TokenStore? memberTokenStore;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final contentWidth = constraints.maxWidth > 1120
                ? 1080.0
                : constraints.maxWidth;
            return Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: contentWidth,
                child: CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 112),
                      sliver: SliverList.list(
                        children: [
                          _Header(
                            apkDownloadUrl: apkDownloadUrl,
                            apiBaseUrl: apiBaseUrl,
                            exerciseLoader: exerciseLoader,
                            tokenStore: memberTokenStore,
                          ),
                          const SizedBox(height: 28),
                          _TodayHero(compact: constraints.maxWidth < 760),
                          const SizedBox(height: 18),
                          const _ReadinessStrip(),
                          const SizedBox(height: 28),
                          if (showRecoverySuggestion) ...[
                            _SuggestionNotice(
                              onOpen: () => _showSuggestion(context),
                            ),
                            const SizedBox(height: 20),
                          ],
                          _WorkoutOverview(loader: exerciseLoader),
                          const SizedBox(height: 28),
                          Center(
                            child: Text(
                              'v$baseAppVersion',
                              style: const TextStyle(
                                color: NicoGymColors.muted,
                                fontSize: 12,
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
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 18),
        child: Align(
          heightFactor: 1,
          child: SizedBox(
            width: 680,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(60),
                backgroundColor: NicoGymColors.ink,
                foregroundColor: NicoGymColors.paper,
                shape: const RoundedRectangleBorder(),
              ),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _WorkoutLoaderScreen(loader: exerciseLoader),
                ),
              ),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Bắt đầu buổi tập'),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showSuggestion(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Đổi sang Ngực + Vai?',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 12),
              const Text(
                'Chân của bạn mới nghỉ 24 giờ. Lịch cũ vẫn được giữ cho tới khi bạn xác nhận.',
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Giữ lịch chân'),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Xác nhận đổi'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkoutLoaderScreen extends StatefulWidget {
  const _WorkoutLoaderScreen({required this.loader});

  final Future<List<Exercise>> Function() loader;

  @override
  State<_WorkoutLoaderScreen> createState() => _WorkoutLoaderScreenState();
}

class _WorkoutLoaderScreenState extends State<_WorkoutLoaderScreen> {
  late Future<List<Exercise>> _exercises = widget.loader();

  void _retry() {
    final nextLoad = widget.loader();
    setState(() {
      _exercises = nextLoad;
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Exercise>>(
    future: _exercises,
    builder: (context, snapshot) {
      if (snapshot.hasError || (snapshot.hasData && snapshot.data!.isEmpty)) {
        return Scaffold(
          appBar: AppBar(),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Không tải được bài tập. Hãy thử lại.'),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        );
      }
      if (!snapshot.hasData) {
        return Scaffold(
          appBar: AppBar(),
          body: const Center(child: CircularProgressIndicator()),
        );
      }
      return WorkoutScreen(exercise: snapshot.data!.first);
    },
  );
}

class _Header extends StatefulWidget {
  const _Header({
    required this.apkDownloadUrl,
    required this.apiBaseUrl,
    required this.exerciseLoader,
    required this.tokenStore,
  });

  final String apkDownloadUrl;
  final String apiBaseUrl;
  final Future<List<Exercise>> Function() exerciseLoader;
  final TokenStore? tokenStore;

  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> {
  late final TokenStore _tokenStore;
  bool _authenticated = false;
  Future<bool>? _authenticationRead;

  @override
  void initState() {
    super.initState();
    _tokenStore = widget.tokenStore ?? SecureTokenStore();
    _refreshAuthentication();
  }

  Future<bool> _refreshAuthentication() async {
    final pendingRead = _authenticationRead;
    if (pendingRead != null) return pendingRead;

    final read = _readAuthentication();
    _authenticationRead = read;
    try {
      return await read;
    } finally {
      if (identical(_authenticationRead, read)) _authenticationRead = null;
    }
  }

  Future<bool> _readAuthentication() async {
    var authenticated = false;
    try {
      authenticated = (await _tokenStore.read())?.isNotEmpty ?? false;
    } catch (_) {
      // Unavailable or damaged secure storage should degrade to signed out.
    }
    if (mounted) setState(() => _authenticated = authenticated);
    return authenticated;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            'assets/images/nicogym-mark.png',
            width: 34,
            height: 34,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 11),
        if (MediaQuery.sizeOf(context).width >= 430)
          Text('NICOGYM', style: Theme.of(context).textTheme.titleLarge),
        const Spacer(),
        if (widget.apkDownloadUrl.isNotEmpty)
          IconButton(
            tooltip: 'Tải Android',
            onPressed: () => _downloadApk(context),
            icon: const Icon(Icons.android),
          ),
        IconButton(
          tooltip: 'Thư viện và lịch tập',
          onPressed: () => _openMemberHub(context),
          icon: const Icon(Icons.grid_view_rounded),
        ),
        IconButton(
          tooltip: _authenticated ? 'Đã đăng nhập' : 'Tài khoản',
          onPressed: () => _openAccount(context),
          icon: Icon(
            _authenticated ? Icons.account_circle : Icons.person_outline,
          ),
        ),
      ],
    );
  }

  Future<void> _openMemberHub(BuildContext context) async {
    final authTokenStore = _tokenStore;
    var authenticated = await _refreshAuthentication();
    if (!authenticated && context.mounted) {
      await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => AuthScreen(
            authApi: AuthApi(
              baseUrl: Uri.parse(widget.apiBaseUrl),
              tokenStore: authTokenStore,
            ),
          ),
        ),
      );
      authenticated = await _refreshAuthentication();
    }
    if (!authenticated || !context.mounted) return;
    final plannerRepository = CachedPlannerRepository(
      remote: PlannerApi(
        baseUrl: Uri.parse(widget.apiBaseUrl),
        tokenStore: authTokenStore,
      ),
      cache: SecurePlannerCache(),
    );
    final catalogApi = CatalogApi(
      baseUrl: Uri.parse(widget.apiBaseUrl),
      tokenStore: authTokenStore,
    );
    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (memberContext) => MemberHubScreen(
            exerciseLoader: () async {
              try {
                final remote = await catalogApi.loadExercises();
                if (remote.isNotEmpty) return remote;
              } catch (_) {
                // The curated bundled catalog keeps the member experience usable offline.
              }
              return widget.exerciseLoader();
            },
            plannerRepository: plannerRepository,
            catalogRepository: catalogApi,
            onOpenExercise: (exercise) => Navigator.of(memberContext).push(
              MaterialPageRoute<void>(
                builder: (_) => WorkoutScreen(exercise: exercise),
              ),
            ),
          ),
        ),
      );
    } finally {
      await plannerRepository.whenIdle();
      plannerRepository.close();
      catalogApi.close();
      await _refreshAuthentication();
    }
  }

  Future<void> _openAccount(BuildContext context) async {
    await _refreshAuthentication();
    if (!context.mounted) return;
    if (!_authenticated) {
      await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => AuthScreen(
            authApi: AuthApi(
              baseUrl: Uri.parse(widget.apiBaseUrl),
              tokenStore: _tokenStore,
            ),
          ),
        ),
      );
      await _refreshAuthentication();
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AccountStatusScreen(
          onSignOut: () async {
            await _tokenStore.clear();
            if (mounted) setState(() => _authenticated = false);
          },
        ),
      ),
    );
    await _refreshAuthentication();
  }

  Future<void> _downloadApk(BuildContext context) async {
    final launched = await launchUrl(
      Uri.parse(widget.apkDownloadUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không mở được liên kết tải APK.')),
      );
    }
  }
}

class _TodayHero extends StatelessWidget {
  const _TodayHero({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final copy = Padding(
      padding: EdgeInsets.fromLTRB(22, compact ? 22 : 30, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 16,
                color: NicoGymColors.lime,
              ),
              const SizedBox(width: 8),
              Text(
                'HÔM NAY',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: NicoGymColors.paper,
                  letterSpacing: 1.1,
                ),
              ),
              const Spacer(),
              const Text(
                '45 PHÚT',
                style: TextStyle(color: Color(0xFFBFC3B8), fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'CHÂN + MÔNG',
            maxLines: 1,
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
              color: NicoGymColors.paper,
              fontSize: compact ? 54 : 70,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '4 bài · 12 hiệp · ưu tiên kỹ thuật',
            style: TextStyle(color: Color(0xFFBFC3B8)),
          ),
        ],
      ),
    );

    final artwork = Semantics(
      image: true,
      label: 'Minh họa tư thế tập máy ép ngực đúng kỹ thuật',
      child: Image.asset(
        'assets/images/training-hero.png',
        fit: BoxFit.cover,
        alignment: Alignment.centerRight,
      ),
    );

    return Container(
      height: compact ? 360 : 300,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: NicoGymColors.ink,
        borderRadius: BorderRadius.circular(22),
      ),
      child: compact
          ? Column(
              children: [
                SizedBox(height: 190, width: double.infinity, child: copy),
                Expanded(
                  child: SizedBox(width: double.infinity, child: artwork),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(flex: 4, child: copy),
                Expanded(flex: 6, child: artwork),
              ],
            ),
    );
  }
}

class _ReadinessStrip extends StatelessWidget {
  const _ReadinessStrip();

  @override
  Widget build(BuildContext context) {
    const states = [true, true, false, true, false];
    return Semantics(
      label: '3 trên 5 nhóm cơ sẵn sàng',
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .65),
          border: Border.all(color: NicoGymColors.ink.withValues(alpha: .09)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bolt_rounded, size: 20),
                const SizedBox(width: 6),
                Text(
                  'MỨC SẴN SÀNG',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const Spacer(),
                const Text(
                  'TỐT',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                for (final ready in states)
                  Expanded(
                    child: Container(
                      height: 7,
                      margin: const EdgeInsets.only(right: 4),
                      color: ready
                          ? NicoGymColors.ink
                          : NicoGymColors.ink.withValues(alpha: .14),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            const Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                Text(
                  '3/5 nhóm cơ sẵn sàng',
                  style: TextStyle(color: NicoGymColors.muted),
                ),
                Text(
                  'Nghỉ đủ 48 giờ',
                  style: TextStyle(color: NicoGymColors.muted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionNotice extends StatelessWidget {
  const _SuggestionNotice({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(color: NicoGymColors.lime),
      child: Row(
        children: [
          const Expanded(child: Text('Lịch hiện tại vẫn được giữ')),
          TextButton(onPressed: onOpen, child: const Text('Xem gợi ý')),
        ],
      ),
    );
  }
}

class _WorkoutOverview extends StatefulWidget {
  const _WorkoutOverview({required this.loader});

  final Future<List<Exercise>> Function() loader;

  @override
  State<_WorkoutOverview> createState() => _WorkoutOverviewState();
}

class _WorkoutOverviewState extends State<_WorkoutOverview> {
  late final Future<List<Exercise>> _exercises = widget.loader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('BÀI TẬP', style: Theme.of(context).textTheme.titleLarge),
            const Spacer(),
            const Text('12 HIỆP', style: TextStyle(color: NicoGymColors.muted)),
          ],
        ),
        const SizedBox(height: 8),
        FutureBuilder<List<Exercise>>(
          future: _exercises,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const _LibraryMessage(
                icon: Icons.error_outline,
                message: 'Không tải được thư viện bài tập.',
              );
            }
            if (!snapshot.hasData) {
              return const _LibraryMessage(
                icon: Icons.hourglass_top_rounded,
                message: 'Đang chuẩn bị bài tập…',
              );
            }
            if (snapshot.data!.isEmpty) {
              return const _LibraryMessage(
                icon: Icons.error_outline,
                message: 'Chưa có bài tập trong lịch này.',
              );
            }
            return Column(
              children: [
                for (final entry in snapshot.data!.indexed)
                  _ExerciseCard(index: entry.$1, exercise: entry.$2),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _LibraryMessage extends StatelessWidget {
  const _LibraryMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Flexible(child: Text(message, textAlign: TextAlign.center)),
      ],
    ),
  );
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({required this.index, required this.exercise});

  final int index;
  final Exercise exercise;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Material(
      color: Colors.white.withValues(alpha: .56),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: NicoGymColors.ink.withValues(alpha: .08)),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        mouseCursor: SystemMouseCursors.click,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => WorkoutScreen(exercise: exercise),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          child: Row(
            children: [
              SizedBox(
                width: 38,
                child: Text(
                  '${index + 1}'.padLeft(2, '0'),
                  style: const TextStyle(color: NicoGymColors.muted),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      exercise.primaryMuscles.join(' · '),
                      style: const TextStyle(
                        color: NicoGymColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(exercise.prescription),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                color: NicoGymColors.muted,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
