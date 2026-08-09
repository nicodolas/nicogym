import 'package:flutter/material.dart';
import 'package:nicogym/auth/auth_api.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.authApi});

  final AuthApi authApi;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _registering = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_email.text.trim().isEmpty || _password.text.length < 10) {
      setState(() => _error = 'Nhập email và mật khẩu từ 10 ký tự.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_registering) {
        await widget.authApi.signUp(
          name: _name.text.isEmpty ? 'NicoGym user' : _name.text,
          email: _email.text,
          password: _password.text,
        );
      } else {
        await widget.authApi.signIn(
          email: _email.text,
          password: _password.text,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            Text(
              _registering ? 'TẠO TÀI KHOẢN' : 'ĐĂNG NHẬP',
              style: Theme.of(context).textTheme.displayLarge,
            ),
            const SizedBox(height: 32),
            if (_registering) ...[
              TextField(
                controller: _name,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Tên hiển thị'),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(labelText: 'Mật khẩu'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text(
                _busy
                    ? 'Đang xử lý…'
                    : (_registering ? 'Đăng ký' : 'Đăng nhập'),
              ),
            ),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() => _registering = !_registering),
              child: Text(_registering ? 'Đã có tài khoản' : 'Tạo tài khoản'),
            ),
          ],
        ),
      ),
    );
  }
}
