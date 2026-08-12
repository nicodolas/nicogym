import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nicogym/app/app_theme.dart';
import 'package:nicogym/help/context_help.dart';
import 'package:nicogym/workouts/exercise.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key, required this.exercise});

  final Exercise exercise;

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  final _loadController = TextEditingController(text: '40');
  final _repsController = TextEditingController(text: '10');
  final List<String> _sets = [];
  YoutubePlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    final videoId = widget.exercise.videoId;
    if (videoId != null) {
      _videoController = YoutubePlayerController.fromVideoId(
        videoId: videoId,
        autoPlay: false,
        params: const YoutubePlayerParams(
          showFullscreenButton: true,
          interfaceLanguage: 'vi',
          captionLanguage: 'vi',
          privacyEnhancedMode: true,
        ),
      );
    }
  }

  @override
  void dispose() {
    _loadController.dispose();
    _repsController.dispose();
    _videoController?.close();
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
        title: Text(
          widget.exercise.name.toUpperCase(),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        actions: const [
          ContextHelpButton(
            title: 'Hướng dẫn bài tập',
            message:
                'Xem phần chuẩn bị và cách thực hiện trước, dùng mức tạ nhẹ để học kỹ thuật rồi ghi từng hiệp. Dừng nếu có đau nhói hoặc mất kiểm soát.',
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final muscle in widget.exercise.primaryMuscles)
                      Chip(label: Text(muscle)),
                    Chip(
                      avatar: const Icon(Icons.fitness_center, size: 16),
                      label: Text(widget.exercise.equipment),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  widget.exercise.name,
                  style: Theme.of(context).textTheme.displayLarge,
                ),
                const SizedBox(height: 12),
                Text(
                  widget.exercise.summary,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                if (widget.exercise.imageAsset case final imageAsset?) ...[
                  const SizedBox(height: 20),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.asset(imageAsset, fit: BoxFit.cover),
                  ),
                ],
                if (widget.exercise.imageAsset == null)
                  if (widget.exercise.imageUrl case final imageUrl?) ...[
                    const SizedBox(height: 20),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          height: 220,
                          color: NicoGymColors.ink.withValues(alpha: .06),
                          alignment: Alignment.center,
                          child: const Icon(Icons.image_not_supported_outlined),
                        ),
                      ),
                    ),
                  ],
                if (_videoController case final controller?) ...[
                  const SizedBox(height: 20),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: YoutubePlayer(
                      controller: controller,
                      aspectRatio: 16 / 9,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Video phát ngay trong NicoGym · YouTube privacy-enhanced mode',
                    style: TextStyle(color: NicoGymColors.muted, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 28),
                _GuideSection(
                  title: 'CHUẨN BỊ',
                  icon: Icons.tune_rounded,
                  items: widget.exercise.setup,
                ),
                _GuideSection(
                  title: 'CÁCH THỰC HIỆN',
                  icon: Icons.format_list_numbered_rounded,
                  items: widget.exercise.steps,
                  numbered: true,
                ),
                _GuideSection(
                  title: 'NHỚ 3 ĐIỂM',
                  icon: Icons.bolt_rounded,
                  items: widget.exercise.cues,
                  highlight: true,
                ),
                _GuideSection(
                  title: 'LỖI THƯỜNG GẶP',
                  icon: Icons.warning_amber_rounded,
                  items: widget.exercise.mistakes,
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.health_and_safety_outlined, size: 20),
                      const SizedBox(width: 10),
                      Expanded(child: Text(widget.exercise.safety)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    if (widget.exercise.videoUrl.isNotEmpty)
                      FilledButton.icon(
                        onPressed: () => _openLink(widget.exercise.videoUrl),
                        icon: const Icon(Icons.play_circle_outline_rounded),
                        label: const Text('Xem video mẫu'),
                      ),
                    if (widget.exercise.sourceUrl.isNotEmpty)
                      TextButton.icon(
                        onPressed: () => _openLink(widget.exercise.sourceUrl),
                        icon: const Icon(Icons.open_in_new_rounded, size: 18),
                        label: Text('Nguồn: ${widget.exercise.sourceLabel}'),
                      ),
                  ],
                ),
                const SizedBox(height: 32),
                Text(
                  'GHI NHẬN HIỆP',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
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
                    backgroundColor: NicoGymColors.lime,
                    foregroundColor: NicoGymColors.ink,
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
        ),
      ),
    );
  }

  Future<void> _openLink(String url) async {
    try {
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) _showLinkError();
    } on PlatformException {
      if (mounted) _showLinkError();
    }
  }

  void _showLinkError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Không thể mở liên kết lúc này.')),
    );
  }
}

class _GuideSection extends StatelessWidget {
  const _GuideSection({
    required this.title,
    required this.icon,
    required this.items,
    this.numbered = false,
    this.highlight = false,
  });

  final String title;
  final IconData icon;
  final List<String> items;
  final bool numbered;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (final entry in items.indexed)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: highlight
                  ? NicoGymColors.lime.withValues(alpha: .35)
                  : Colors.white.withValues(alpha: .48),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  child: Text(numbered ? '${entry.$1 + 1}.' : '•'),
                ),
                Expanded(child: Text(entry.$2)),
              ],
            ),
          ),
      ],
    ),
  );
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
