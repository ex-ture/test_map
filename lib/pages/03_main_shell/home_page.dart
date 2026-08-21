import 'package:flutter/material.dart';

import '../../repositories/mock_auth_repository.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final MockAuthRepository _authRepository = const MockAuthRepository();
  MockAuthSession _session = const MockAuthSession(
    isLoggedIn: false,
    loggedInEmail: null,
  );

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final MockAuthSession session = await _authRepository.fetchSession();
    if (!mounted) {
      return;
    }

    setState(() {
      _session = session;
    });
  }

  Future<void> _showAuthSheet(_AuthFormMode mode) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (BuildContext context) {
        return _AuthFormSheet(
          mode: mode,
          authRepository: _authRepository,
          onSessionChanged: _loadSession,
        );
      },
    );
  }

  Future<void> _logout() async {
    await _authRepository.logout();
    await _loadSession();
  }

  Widget _buildStatusBadge() {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Center(
        child: Container(
          key: const ValueKey<String>('mock-auth-status-badge'),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F3F5),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFE2E2E6)),
          ),
          child: Text(
            _session.displayName,
            key: const ValueKey<String>('mock-auth-status-label'),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4A4A4F),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHomeIllustration() {
    return Container(
      width: 112,
      height: 112,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFFE2E2E6)),
      ),
      child: const Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 26,
            top: 26,
            child: Icon(Icons.map_outlined, size: 44, color: Color(0xFFB0B0B6)),
          ),
          Positioned(
            right: 24,
            top: 30,
            child: Icon(Icons.location_on, size: 34, color: Color(0xFF1F1F22)),
          ),
          Positioned(
            right: 24,
            bottom: 24,
            child: Icon(Icons.search, size: 28, color: Color(0xFF6B6B70)),
          ),
        ],
      ),
    );
  }

  Widget _buildLoggedInIcon() {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F22),
        borderRadius: BorderRadius.circular(30),
      ),
      child: const Icon(
        Icons.check_circle_outline,
        size: 44,
        color: Colors.white,
      ),
    );
  }

  Widget _buildActionButton({
    required Key key,
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    required bool filled,
  }) {
    final ButtonStyle style = filled
        ? FilledButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          )
        : OutlinedButton.styleFrom(
            foregroundColor: Colors.black,
            side: const BorderSide(color: Color(0xFFD8D8DC)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          );

    final Widget button = filled
        ? FilledButton.icon(
            key: key,
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label),
            style: style,
          )
        : OutlinedButton.icon(
            key: key,
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label),
            style: style,
          );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: SizedBox(width: double.infinity, height: 50, child: button),
    );
  }

  Widget _buildLoggedOutContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHomeIllustration(),
        const SizedBox(height: 28),
        const Text(
          '場所を見つけよう',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1F1F22),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          '検索した場所や閲覧履歴を、この端末で確認できます。',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF6B6B70)),
        ),
        const SizedBox(height: 30),
        _buildActionButton(
          key: const ValueKey<String>('mock-auth-login-button'),
          label: 'ログイン',
          icon: Icons.login,
          onPressed: () => _showAuthSheet(_AuthFormMode.login),
          filled: true,
        ),
        const SizedBox(height: 12),
        _buildActionButton(
          key: const ValueKey<String>('mock-auth-register-button'),
          label: '新規登録',
          icon: Icons.person_add_alt_1_outlined,
          onPressed: () => _showAuthSheet(_AuthFormMode.register),
          filled: false,
        ),
      ],
    );
  }

  Widget _buildLoggedInContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildLoggedInIcon(),
        const SizedBox(height: 28),
        const Text(
          'ログイン中',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1F1F22),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _session.displayName,
          key: const ValueKey<String>('mock-auth-home-display-name'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1F1F22),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'このアカウントで引き続き周辺の場所を探せます。',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF6B6B70)),
        ),
        const SizedBox(height: 30),
        _buildActionButton(
          key: const ValueKey<String>('mock-auth-logout-button'),
          label: 'ログアウト',
          icon: Icons.logout,
          onPressed: _logout,
          filled: false,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ホーム'), actions: [_buildStatusBadge()]),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _session.isLoggedIn
                  ? _buildLoggedInContent()
                  : _buildLoggedOutContent(),
            ),
          ),
        ),
      ),
    );
  }
}

enum _AuthFormMode { login, register }

class _AuthFormSheet extends StatefulWidget {
  const _AuthFormSheet({
    required this.mode,
    required this.authRepository,
    required this.onSessionChanged,
  });

  final _AuthFormMode mode;
  final MockAuthRepository authRepository;
  final Future<void> Function() onSessionChanged;

  @override
  State<_AuthFormSheet> createState() => _AuthFormSheetState();
}

class _AuthFormSheetState extends State<_AuthFormSheet> {
  late _AuthFormMode _mode;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _passwordConfirmationController =
      TextEditingController();

  String? _emailErrorText;
  String? _passwordErrorText;
  String? _passwordConfirmationErrorText;
  String? _formErrorText;
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  bool _obscurePasswordConfirmation = true;

  @override
  void initState() {
    super.initState();
    _mode = widget.mode;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmationController.dispose();
    super.dispose();
  }

  String? _validateEmail(String email) {
    if (email.isEmpty) {
      return 'メールアドレスを入力してください';
    }

    final List<String> parts = email.split('@');
    if (parts.length != 2 || parts.first.isEmpty || parts.last.isEmpty) {
      return 'メールアドレスの形式を確認してください';
    }

    return null;
  }

  String? _validatePassword(String password, {required bool requireMinLength}) {
    if (password.isEmpty) {
      return 'パスワードを入力してください';
    }

    if (requireMinLength && password.length < 4) {
      return 'パスワードは4文字以上で入力してください';
    }

    return null;
  }

  Future<void> _submit() async {
    final String email = _emailController.text.trim();
    final String password = _passwordController.text;
    final String passwordConfirmation = _passwordConfirmationController.text;
    final bool isRegister = _mode == _AuthFormMode.register;

    final String? emailError = _validateEmail(email);
    final String? passwordError = _validatePassword(
      password,
      requireMinLength: isRegister,
    );
    final String? passwordConfirmationError =
        isRegister && password != passwordConfirmation ? 'パスワードが一致しません' : null;

    setState(() {
      _emailErrorText = emailError;
      _passwordErrorText = passwordError;
      _passwordConfirmationErrorText = passwordConfirmationError;
      _formErrorText = null;
    });

    if (emailError != null ||
        passwordError != null ||
        passwordConfirmationError != null) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    if (isRegister) {
      final bool isEmailRegistered = await widget.authRepository
          .isEmailRegistered(email: email);
      if (!mounted) {
        return;
      }

      if (isEmailRegistered) {
        setState(() {
          _formErrorText = 'すでにアカウントが登録されています';
          _isSubmitting = false;
        });
        return;
      }

      await widget.authRepository.registerAndLogin(
        email: email,
        password: password,
      );
    } else {
      final bool isLoggedIn = await widget.authRepository.login(
        email: email,
        password: password,
      );
      if (!mounted) {
        return;
      }

      if (!isLoggedIn) {
        setState(() {
          _formErrorText = 'メールアドレスまたはパスワードが違います';
          _isSubmitting = false;
        });
        return;
      }
    }

    await widget.onSessionChanged();
    if (!mounted) {
      return;
    }

    Navigator.of(context).pop();
  }

  void _switchMode(_AuthFormMode mode) {
    setState(() {
      _mode = mode;
      _emailErrorText = null;
      _passwordErrorText = null;
      _passwordConfirmationErrorText = null;
      _formErrorText = null;
      _isSubmitting = false;
      _obscurePassword = true;
      _obscurePasswordConfirmation = true;
    });
  }

  OutlineInputBorder _inputBorder(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color),
    );
  }

  InputDecoration _inputDecoration({
    required String labelText,
    required String? errorText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      errorText: errorText,
      filled: true,
      fillColor: Colors.white,
      border: _inputBorder(const Color(0xFFD8D8DC)),
      enabledBorder: _inputBorder(const Color(0xFFD8D8DC)),
      focusedBorder: _inputBorder(Colors.black),
      errorBorder: _inputBorder(const Color(0xFFB3261E)),
      focusedErrorBorder: _inputBorder(const Color(0xFFB3261E)),
      suffixIcon: suffixIcon,
    );
  }

  Widget _buildVisibilityButton({
    required Key key,
    required bool isObscured,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      key: key,
      onPressed: onPressed,
      icon: Icon(
        isObscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isRegister = _mode == _AuthFormMode.register;
    final String title = isRegister ? '新規登録' : 'ログイン';
    final String submitLabel = isRegister ? '登録する' : 'ログインする';

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1F1F22),
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey<String>('mock-auth-close-button'),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                isRegister ? 'この端末にモックアカウントを作成します。' : '登録済みのモックアカウントでログインします。',
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: Color(0xFF6B6B70),
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                key: const ValueKey<String>('mock-auth-email-field'),
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textCapitalization: TextCapitalization.none,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                enableSuggestions: false,
                autofillHints: const <String>[AutofillHints.email],
                decoration: _inputDecoration(
                  labelText: 'メールアドレス',
                  errorText: _emailErrorText,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                key: const ValueKey<String>('mock-auth-password-field'),
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: isRegister
                    ? TextInputAction.next
                    : TextInputAction.done,
                onSubmitted: (_) {
                  if (!isRegister) {
                    _submit();
                  }
                },
                decoration: _inputDecoration(
                  labelText: 'パスワード',
                  errorText: _passwordErrorText,
                  suffixIcon: _buildVisibilityButton(
                    key: const ValueKey<String>(
                      'mock-auth-password-visibility-button',
                    ),
                    isObscured: _obscurePassword,
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
              ),
              if (isRegister) ...[
                const SizedBox(height: 14),
                TextField(
                  key: const ValueKey<String>(
                    'mock-auth-password-confirmation-field',
                  ),
                  controller: _passwordConfirmationController,
                  obscureText: _obscurePasswordConfirmation,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  decoration: _inputDecoration(
                    labelText: 'パスワード確認',
                    errorText: _passwordConfirmationErrorText,
                    suffixIcon: _buildVisibilityButton(
                      key: const ValueKey<String>(
                        'mock-auth-password-confirmation-visibility-button',
                      ),
                      isObscured: _obscurePasswordConfirmation,
                      onPressed: () {
                        setState(() {
                          _obscurePasswordConfirmation =
                              !_obscurePasswordConfirmation;
                        });
                      },
                    ),
                  ),
                ),
              ],
              if (_formErrorText != null) ...[
                const SizedBox(height: 12),
                Text(
                  _formErrorText!,
                  key: const ValueKey<String>('mock-auth-error-text'),
                  style: const TextStyle(
                    color: Color(0xFFB3261E),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                height: 50,
                child: FilledButton(
                  key: ValueKey<String>(
                    isRegister
                        ? 'mock-auth-register-submit-button'
                        : 'mock-auth-login-submit-button',
                  ),
                  onPressed: _isSubmitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(submitLabel),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    isRegister ? 'すでにアカウントをお持ちの方は' : 'アカウントをお持ちでない方は',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B6B70),
                    ),
                  ),
                  TextButton(
                    key: ValueKey<String>(
                      isRegister
                          ? 'mock-auth-switch-login-button'
                          : 'mock-auth-switch-register-button',
                    ),
                    onPressed: () => _switchMode(
                      isRegister ? _AuthFormMode.login : _AuthFormMode.register,
                    ),
                    child: Text(isRegister ? 'ログイン' : '新規登録'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
