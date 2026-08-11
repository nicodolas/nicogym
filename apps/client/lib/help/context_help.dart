import 'package:flutter/material.dart';

class ContextHelpButton extends StatelessWidget {
  const ContextHelpButton({
    super.key,
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Hướng dẫn',
    icon: const Icon(Icons.help_outline_rounded),
    onPressed: () => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 12),
              Text(message),
            ],
          ),
        ),
      ),
    ),
  );
}
