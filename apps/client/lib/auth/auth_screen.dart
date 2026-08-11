import 'package:flutter/material.dart';
import 'package:nicogym/auth/auth_api.dart';

const _authInk = Color(0xFF111310);
const _authPaper = Color(0xFFF1F0E9);
const _authLime = Color(0xFFC7F36B);
const _authMuted = Color(0xFF74786E);

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.authApi});

  final AuthApi authApi;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _registering = false;
  bool _busy = false;
  bool _submitted = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  void _setMode(bool registering) {
    if (_busy || _registering == registering) return;
    setState(() {
      _registering = registering;
      _submitted = false;
      _error = null;
      _password.clear();
      _confirmPassword.clear();
    });
  }

  Future<void> _submit() async {
    setState(() {
      _submitted = true;
      _error = null;
    });
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _busy = true);
    try {
      if (_registering) {
        await widget.authApi.signUp(
          name: _name.text,
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
      backgroundColor: _authPaper,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: const Text('NICOGYM'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: AutofillGroup(
              child: Form(
                key: _formKey,
                autovalidateMode: _submitted
                    ? AutovalidateMode.onUserInteraction
                    : AutovalidateMode.disabled,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 108),
                  children: [
                    Container(
                      width: 52,
                      height: 7,
                      margin: const EdgeInsets.only(bottom: 22),
                      color: _authLime,
                    ),
                    Text(
                      _registering ? 'TẠO TÀI KHOẢN' : 'ĐĂNG NHẬP',
                      style: Theme.of(context).textTheme.displayLarge,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _registering
                          ? 'Lưu lịch tập và đồng bộ tiến độ trên mọi thiết bị.'
                          : 'Tiếp tục lịch tập của bạn trên web hoặc điện thoại.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: _authMuted),
                    ),
                    const SizedBox(height: 24),
                    _ModeSelector(
                      registering: _registering,
                      enabled: !_busy,
                      onChanged: _setMode,
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .72),
                        border: Border.all(
                          color: _authInk.withValues(alpha: .1),
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_registering) ...[
                            TextFormField(
                              key: const Key('auth-name'),
                              controller: _name,
                              enabled: !_busy,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.name],
                              decoration: const InputDecoration(
                                labelText: 'Tên hiển thị',
                                prefixIcon: Icon(Icons.person_outline_rounded),
                              ),
                              validator: (value) =>
                                  value?.trim().isEmpty ?? true
                                  ? 'Nhập tên bạn muốn hiển thị.'
                                  : null,
                            ),
                            const SizedBox(height: 14),
                          ],
                          TextFormField(
                            key: const Key('auth-email'),
                            controller: _email,
                            enabled: !_busy,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            textInputAction: TextInputAction.next,
                            autocorrect: false,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              hintText: 'ban@example.com',
                              prefixIcon: Icon(Icons.mail_outline_rounded),
                            ),
                            validator: (value) {
                              final email = value?.trim() ?? '';
                              if (email.isEmpty) return 'Nhập email của bạn.';
                              if (!RegExp(
                                r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                              ).hasMatch(email)) {
                                return 'Email chưa đúng định dạng.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            key: const Key('auth-password'),
                            controller: _password,
                            enabled: !_busy,
                            obscureText: !_showPassword,
                            autofillHints: [
                              _registering
                                  ? AutofillHints.newPassword
                                  : AutofillHints.password,
                            ],
                            textInputAction: _registering
                                ? TextInputAction.next
                                : TextInputAction.done,
                            onFieldSubmitted: (_) {
                              if (!_registering) _submit();
                            },
                            decoration: InputDecoration(
                              labelText: 'Mật khẩu',
                              helperText: _registering
                                  ? 'Ít nhất 12 ký tự'
                                  : null,
                              prefixIcon: const Icon(
                                Icons.lock_outline_rounded,
                              ),
                              suffixIcon: IconButton(
                                tooltip: _showPassword
                                    ? 'Ẩn mật khẩu'
                                    : 'Hiện mật khẩu',
                                onPressed: _busy
                                    ? null
                                    : () => setState(
                                        () => _showPassword = !_showPassword,
                                      ),
                                icon: Icon(
                                  _showPassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Nhập mật khẩu.';
                              }
                              if (_registering && value.length < 12) {
                                return 'Mật khẩu cần có ít nhất 12 ký tự.';
                              }
                              return null;
                            },
                          ),
                          if (_registering) ...[
                            const SizedBox(height: 14),
                            TextFormField(
                              key: const Key('auth-confirm-password'),
                              controller: _confirmPassword,
                              enabled: !_busy,
                              obscureText: !_showPassword,
                              autofillHints: const [AutofillHints.newPassword],
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              decoration: const InputDecoration(
                                labelText: 'Nhập lại mật khẩu',
                                prefixIcon: Icon(Icons.verified_user_outlined),
                              ),
                              validator: (value) => value != _password.text
                                  ? 'Hai mật khẩu chưa trùng nhau.'
                                  : null,
                            ),
                          ],
                          if (_error case final error?) ...[
                            const SizedBox(height: 16),
                            Semantics(
                              liveRegion: true,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.errorContainer,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.error_outline_rounded,
                                      size: 20,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onErrorContainer,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(error)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock_rounded, size: 15, color: _authMuted),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Thông tin đăng nhập được truyền qua kết nối HTTPS.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _authMuted, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 10, 20, 16),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(58),
                backgroundColor: _authInk,
                foregroundColor: _authPaper,
              ),
              onPressed: _busy ? null : _submit,
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _authPaper,
                      ),
                    )
                  : Icon(
                      _registering
                          ? Icons.person_add_alt_1_rounded
                          : Icons.arrow_forward_rounded,
                    ),
              label: Text(
                _busy
                    ? 'Đang xử lý…'
                    : (_registering ? 'Đăng ký' : 'Đăng nhập'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({
    required this.registering,
    required this.enabled,
    required this.onChanged,
  });

  final bool registering;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: _authInk.withValues(alpha: .06),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Expanded(
          child: _ModeButton(
            label: 'Đăng nhập',
            selected: !registering,
            enabled: enabled,
            onPressed: () => onChanged(false),
          ),
        ),
        Expanded(
          child: _ModeButton(
            label: 'Tạo tài khoản',
            selected: registering,
            enabled: enabled,
            onPressed: () => onChanged(true),
          ),
        ),
      ],
    ),
  );
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
    style: TextButton.styleFrom(
      minimumSize: const Size.fromHeight(44),
      backgroundColor: selected ? _authLime : Colors.transparent,
      foregroundColor: _authInk,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
    ),
    onPressed: enabled ? onPressed : null,
    child: Text(label),
  );
}
