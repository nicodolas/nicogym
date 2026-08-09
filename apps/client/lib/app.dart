import 'package:flutter/material.dart';
import 'package:nicogym/auth/auth_api.dart';
import 'package:nicogym/auth/auth_screen.dart';
import 'package:url_launcher/url_launcher.dart';

const _ink = Color(0xFF111310);
const _paper = Color(0xFFF1F0E9);
const _lime = Color(0xFFC7F36B);
const _muted = Color(0xFF74786E);

class NicoGymApp extends StatelessWidget {
  const NicoGymApp({
    super.key,
    this.showRecoverySuggestion = false,
    this.apkDownloadUrl = const String.fromEnvironment('APK_DOWNLOAD_URL'),
    this.apiBaseUrl = const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://localhost:3000',
    ),
  });

  final bool showRecoverySuggestion;
  final String apkDownloadUrl;
  final String apiBaseUrl;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NicoGym',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: _paper,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _lime,
          brightness: Brightness.light,
          surface: _paper,
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontFamily: 'BarlowCondensed',
            fontSize: 64,
            height: .86,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.5,
          ),
          headlineLarge: TextStyle(
            fontFamily: 'BarlowCondensed',
            fontSize: 38,
            height: .95,
            fontWeight: FontWeight.w800,
          ),
          titleLarge: TextStyle(
            fontFamily: 'BarlowCondensed',
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
          bodyLarge: TextStyle(fontFamily: 'Barlow', fontSize: 16),
          bodyMedium: TextStyle(fontFamily: 'Barlow', fontSize: 14),
          labelLarge: TextStyle(
            fontFamily: 'Barlow',
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      home: TodayScreen(
        showRecoverySuggestion: showRecoverySuggestion,
        apkDownloadUrl: apkDownloadUrl,
        apiBaseUrl: apiBaseUrl,
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
  });

  final bool showRecoverySuggestion;
  final String apkDownloadUrl;
  final String apiBaseUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final contentWidth = constraints.maxWidth > 720
                ? 680.0
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
                          ),
                          const SizedBox(height: 44),
                          Text(
                            'HÔM NAY',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'CHÂN + MÔNG',
                            maxLines: 1,
                            style: Theme.of(context).textTheme.displayLarge
                                ?.copyWith(
                                  fontSize: constraints.maxWidth < 430
                                      ? 54
                                      : 64,
                                ),
                          ),
                          const SizedBox(height: 22),
                          const _ReadinessStrip(),
                          const SizedBox(height: 28),
                          if (showRecoverySuggestion) ...[
                            _SuggestionNotice(
                              onOpen: () => _showSuggestion(context),
                            ),
                            const SizedBox(height: 20),
                          ],
                          const _WorkoutOverview(),
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
        child: FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(58),
            backgroundColor: _ink,
            foregroundColor: _paper,
            shape: const RoundedRectangleBorder(),
          ),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const WorkoutScreen()),
          ),
          child: const Text('Bắt đầu buổi tập'),
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

class _Header extends StatelessWidget {
  const _Header({required this.apkDownloadUrl, required this.apiBaseUrl});

  final String apkDownloadUrl;
  final String apiBaseUrl;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 10, height: 28, color: _lime),
        const SizedBox(width: 10),
        Text('NICOGYM', style: Theme.of(context).textTheme.titleLarge),
        const Spacer(),
        if (apkDownloadUrl.isNotEmpty)
          IconButton(
            tooltip: 'Tải Android',
            onPressed: () => _downloadApk(context),
            icon: const Icon(Icons.android),
          ),
        IconButton(
          tooltip: 'Tài khoản',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => AuthScreen(
                authApi: AuthApi(
                  baseUrl: Uri.parse(apiBaseUrl),
                  tokenStore: SecureTokenStore(),
                ),
              ),
            ),
          ),
          icon: const Icon(Icons.person_outline),
        ),
      ],
    );
  }

  Future<void> _downloadApk(BuildContext context) async {
    final launched = await launchUrl(
      Uri.parse(apkDownloadUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không mở được liên kết tải APK.')),
      );
    }
  }
}

class _ReadinessStrip extends StatelessWidget {
  const _ReadinessStrip();

  @override
  Widget build(BuildContext context) {
    const states = [true, true, false, true, false];
    return Semantics(
      label: '3 trên 5 nhóm cơ sẵn sàng',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (final ready in states)
                Expanded(
                  child: Container(
                    height: 7,
                    margin: const EdgeInsets.only(right: 4),
                    color: ready ? _ink : _ink.withValues(alpha: .14),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('3/5 nhóm cơ sẵn sàng', style: TextStyle(color: _muted)),
        ],
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
      decoration: const BoxDecoration(color: _lime),
      child: Row(
        children: [
          const Expanded(child: Text('Lịch hiện tại vẫn được giữ')),
          TextButton(onPressed: onOpen, child: const Text('Xem gợi ý')),
        ],
      ),
    );
  }
}

class _WorkoutOverview extends StatelessWidget {
  const _WorkoutOverview();

  @override
  Widget build(BuildContext context) {
    const exercises = [
      ('01', 'Leg press', '3 × 8–10'),
      ('02', 'Romanian deadlift', '3 × 8'),
      ('03', 'Leg curl', '3 × 10–12'),
      ('04', 'Calf raise', '3 × 12'),
    ];
    return Column(
      children: [
        for (final exercise in exercises)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 17),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0x26111310))),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 38,
                  child: Text(
                    exercise.$1,
                    style: const TextStyle(color: _muted),
                  ),
                ),
                Expanded(
                  child: Text(
                    exercise.$2,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Text(exercise.$3),
              ],
            ),
          ),
      ],
    );
  }
}

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  final _loadController = TextEditingController(text: '40');
  final _repsController = TextEditingController(text: '10');
  final List<String> _sets = [];

  @override
  void dispose() {
    _loadController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  void _logSet() {
    final load = double.tryParse(_loadController.text.replaceAll(',', '.'));
    final reps = int.tryParse(_repsController.text);
    if (load == null || load < 0 || reps == null || reps < 1) return;
    setState(
      () => _sets.add(
        '${load.toStringAsFixed(load % 1 == 0 ? 0 : 1)} kg × $reps',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('LEG PRESS', style: Theme.of(context).textTheme.titleLarge),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Text('Leg press', style: Theme.of(context).textTheme.displayLarge),
            const SizedBox(height: 12),
            const Text(
              'Đặt bàn chân ngang vai. Hạ có kiểm soát, giữ lưng và hông áp sát ghế.',
            ),
            const SizedBox(height: 32),
            Text(
              'HIỆP ${_sets.length + 1}',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _MetricInput(
                    keyName: 'load-input',
                    label: 'KG',
                    controller: _loadController,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricInput(
                    keyName: 'reps-input',
                    label: 'LẦN',
                    controller: _repsController,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(58),
                backgroundColor: _lime,
                foregroundColor: _ink,
                shape: const RoundedRectangleBorder(),
              ),
              onPressed: _logSet,
              child: const Text('Ghi hiệp'),
            ),
            const SizedBox(height: 24),
            for (final entry in _sets.indexed)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Text('${entry.$1 + 1}'.padLeft(2, '0')),
                title: Text(entry.$2),
                trailing: const Icon(Icons.check, size: 18),
              ),
          ],
        ),
      ),
    );
  }
}

class _MetricInput extends StatelessWidget {
  const _MetricInput({
    required this.keyName,
    required this.label,
    required this.controller,
  });

  final String keyName;
  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: Key(keyName),
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: Theme.of(context).textTheme.headlineLarge,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
      ),
    );
  }
}
