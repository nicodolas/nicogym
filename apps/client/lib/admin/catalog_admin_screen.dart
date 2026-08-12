import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:nicogym/admin/catalog_api.dart';
import 'package:nicogym/auth/auth_api.dart';
import 'package:nicogym/help/context_help.dart';

class CatalogAdminScreen extends StatefulWidget {
  const CatalogAdminScreen({super.key, required this.repository});

  final CatalogRepository repository;

  @override
  State<CatalogAdminScreen> createState() => _CatalogAdminScreenState();
}

class _CatalogAdminScreenState extends State<CatalogAdminScreen> {
  final _jsonController = TextEditingController(text: _sampleJson);
  String _mode = 'upsert';
  ImportPreview? _preview;
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _jsonController.dispose();
    super.dispose();
  }

  Future<void> _previewImport() async {
    setState(() {
      _busy = true;
      _message = null;
      _preview = null;
    });
    try {
      final preview = await widget.repository.preview(
        _jsonController.text,
        _mode,
      );
      if (mounted) {
        setState(() => _preview = preview);
      }
    } on FormatException {
      if (mounted) {
        setState(
          () => _message = 'JSON chưa hợp lệ. Kiểm tra dấu phẩy và ngoặc.',
        );
      }
    } on AuthException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _applyImport() async {
    final preview = _preview;
    if (preview == null) return;
    setState(() => _busy = true);
    try {
      await widget.repository.apply(preview.token);
      if (mounted) {
        setState(() {
          _preview = null;
          _message = 'Đã cập nhật danh mục thành công.';
        });
      }
    } on AuthException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'QUẢN LÝ BÀI TẬP',
              style: Theme.of(context).textTheme.displayLarge,
            ),
          ),
          const ContextHelpButton(
            title: 'Import bài tập',
            message:
                'Dán một object hoặc danh sách JSON, chọn cách cập nhật rồi kiểm tra trước. NicoGym chỉ ghi dữ liệu sau khi bạn xác nhận bản xem trước.',
          ),
        ],
      ),
      const SizedBox(height: 8),
      const Text(
        'Tối đa 100 bài mỗi lần. Ảnh dùng URL HTTPS bên ngoài và có ảnh dự phòng khi lỗi.',
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'create', label: Text('Chỉ thêm mới')),
              ButtonSegment(value: 'update', label: Text('Chỉ cập nhật')),
              ButtonSegment(value: 'upsert', label: Text('Kết hợp')),
            ],
            selected: {_mode},
            onSelectionChanged: _busy
                ? null
                : (value) => setState(() => _mode = value.first),
          ),
          OutlinedButton.icon(
            onPressed: _busy ? null : _createSingleTemplate,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Tạo mẫu một bài'),
          ),
        ],
      ),
      const SizedBox(height: 14),
      TextField(
        key: const Key('exercise-json-input'),
        controller: _jsonController,
        minLines: 14,
        maxLines: 26,
        autocorrect: false,
        decoration: const InputDecoration(
          labelText: 'Dữ liệu JSON',
          alignLabelWithHint: true,
          border: OutlineInputBorder(),
        ),
        onChanged: (_) => setState(() => _preview = null),
      ),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: _busy ? null : _previewImport,
        icon: const Icon(Icons.fact_check_outlined),
        label: const Text('Kiểm tra JSON'),
      ),
      if (_busy) ...[
        const SizedBox(height: 12),
        const LinearProgressIndicator(),
      ],
      if (_preview case final preview?) ...[
        const SizedBox(height: 16),
        Card(
          color: const Color(0xFFC7F36B),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BẢN XEM TRƯỚC',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  '${preview.creates} bài mới · ${preview.updates} bài cập nhật',
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _busy ? null : _applyImport,
                  child: const Text('Xác nhận cập nhật danh mục'),
                ),
              ],
            ),
          ),
        ),
      ],
      if (_message case final message?) ...[
        const SizedBox(height: 12),
        Text(message, key: const Key('admin-import-message')),
      ],
    ],
  );

  Future<void> _createSingleTemplate() async {
    final slug = TextEditingController();
    final name = TextEditingController();
    final category = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tạo mẫu một bài'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: slug,
              decoration: const InputDecoration(
                labelText: 'Mã slug, ví dụ goblet-squat',
              ),
            ),
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Tên bài tập'),
            ),
            TextField(
              controller: category,
              decoration: const InputDecoration(
                labelText: 'Nhóm, ví dụ Chân & Mông',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Tạo mẫu'),
          ),
        ],
      ),
    );
    if (accepted == true &&
        slug.text.trim().isNotEmpty &&
        name.text.trim().isNotEmpty) {
      final template = jsonDecode(_sampleJson) as Map<String, dynamic>;
      template['slug'] = slug.text.trim();
      template['name'] = name.text.trim();
      template['category'] = category.text.trim().isEmpty
          ? 'Khác'
          : category.text.trim();
      _jsonController.text = const JsonEncoder.withIndent(
        '  ',
      ).convert(template);
      setState(() => _preview = null);
    }
    slug.dispose();
    name.dispose();
    category.dispose();
  }
}

const _sampleJson = '''{
  "slug": "goblet-squat",
  "name": "Goblet squat",
  "category": "Chân & Mông",
  "equipment": "Tạ đơn",
  "prescription": "3 × 8–12",
  "primaryMuscles": ["Đùi trước", "Mông"],
  "summary": "Squat với một tạ giữ trước ngực.",
  "setup": ["Giữ tạ sát ngực và đứng vững."],
  "steps": ["Hạ hông có kiểm soát rồi đứng lên."],
  "cues": ["Giữ cả bàn chân trên sàn."],
  "mistakes": ["Để đầu gối đổ vào trong."],
  "safety": "Dừng nếu có đau nhói.",
  "sourceLabel": "NicoGym",
  "sourceUrl": "https://example.com/source",
  "imageUrl": "https://example.com/goblet-squat.jpg"
}''';
