import 'package:flutter/material.dart';
import 'package:nicogym/app/app_theme.dart';

class AccountStatusScreen extends StatelessWidget {
  const AccountStatusScreen({super.key, required this.onSignOut});

  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TÀI KHOẢN')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.verified_user,
                    size: 56,
                    color: NicoGymColors.ink,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'ĐÃ ĐĂNG NHẬP',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Lịch tập, tiến độ và quyền quản trị đang dùng phiên tài khoản này.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: NicoGymColors.muted),
                  ),
                  const SizedBox(height: 28),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await onSignOut();
                      if (context.mounted) Navigator.pop(context);
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Đăng xuất'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
