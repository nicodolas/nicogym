import 'package:flutter/material.dart';
import 'package:nicogym/admin/catalog_api.dart';
import 'package:nicogym/auth/auth_api.dart';
import 'package:nicogym/auth/auth_screen.dart';
import 'package:nicogym/features/account/account_status_screen.dart';
import 'package:nicogym/features/workout/workout_screen.dart';
import 'package:nicogym/member/member_hub.dart';
import 'package:nicogym/member/planner_api.dart';
import 'package:nicogym/workouts/exercise.dart';
import 'package:url_launcher/url_launcher.dart';

class TodayHeader extends StatefulWidget {
  const TodayHeader({
    super.key,
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
  State<TodayHeader> createState() => _TodayHeaderState();
}

class _TodayHeaderState extends State<TodayHeader> {
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
                // The bundled catalog keeps the member experience usable offline.
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
