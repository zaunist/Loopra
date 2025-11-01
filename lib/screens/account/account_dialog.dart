import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/auth_controller.dart';

class AccountDialog extends StatefulWidget {
  const AccountDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const AccountDialog(),
    );
  }

  @override
  State<AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<AccountDialog> {
  final TextEditingController _loginEmailController = TextEditingController();
  final TextEditingController _loginPasswordController = TextEditingController();
  final TextEditingController _signupEmailController = TextEditingController();
  final TextEditingController _signupPasswordController = TextEditingController();

  String? _loginError;
  String? _signupError;

  @override
  void dispose() {
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _signupEmailController.dispose();
    _signupPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AuthController auth = context.watch<AuthController>();

    if (!auth.isConfigured) {
      return AlertDialog(
        title: const Text('账号登录'),
        content: const Text('暂未配置 Supabase，账号登录功能不可用。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('关闭'),
          ),
        ],
      );
    }

    if (auth.isLoggedIn) {
      return AlertDialog(
        title: const Text('账号信息'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              auth.email ?? '已登录',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text(
              '已登录的用户可以在订阅后同步统计数据。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: auth.isLoading ? null : () => Navigator.of(context).maybePop(),
            child: const Text('关闭'),
          ),
          TextButton(
            onPressed: auth.isLoading
                ? null
                : () async {
                    final NavigatorState navigator = Navigator.of(context);
                    await auth.signOut();
                    navigator.maybePop();
                  },
            child: const Text('退出登录'),
          ),
        ],
      );
    }

    return DefaultTabController(
      length: 2,
      child: AlertDialog(
        title: const Text('账号登录'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const TabBar(
                tabs: <Widget>[
                  Tab(text: '登录'),
                  Tab(text: '注册'),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 260,
                child: TabBarView(
                  children: <Widget>[
                    _AuthForm(
                      emailController: _loginEmailController,
                      passwordController: _loginPasswordController,
                      isLoading: auth.isLoading,
                      errorText: _loginError ?? auth.lastError,
                      primaryLabel: '登录',
                      helperText: '使用注册邮箱登录以启用云同步。',
                      onSubmitted: (String email, String password) async {
                        setState(() {
                          _loginError = null;
                        });
                        final NavigatorState navigator = Navigator.of(context);
                        final ScaffoldMessengerState messenger =
                            ScaffoldMessenger.of(context);
                        final AuthResult result = await auth.signIn(email: email, password: password);
                        if (!mounted) {
                          return;
                        }
                        if (result.success) {
                          if (result.message != null && result.message!.isNotEmpty) {
                            messenger.showSnackBar(SnackBar(content: Text(result.message!)));
                          }
                          navigator.maybePop();
                        } else {
                          setState(() {
                            _loginError = result.message;
                          });
                        }
                      },
                    ),
                    _AuthForm(
                      emailController: _signupEmailController,
                      passwordController: _signupPasswordController,
                      isLoading: auth.isLoading,
                      errorText: _signupError ?? auth.lastError,
                      primaryLabel: '注册',
                      helperText: '注册后即可在多个设备上同步进度。',
                      onSubmitted: (String email, String password) async {
                        setState(() {
                          _signupError = null;
                        });
                        final NavigatorState navigator = Navigator.of(context);
                        final ScaffoldMessengerState messenger =
                            ScaffoldMessenger.of(context);
                        final AuthResult result = await auth.signUp(email: email, password: password);
                        if (!mounted) {
                          return;
                        }
                        if (result.success) {
                          if (result.requiresVerification) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  result.message ?? '注册成功，请完成邮箱验证后再登录。',
                                ),
                              ),
                            );
                          }
                          navigator.maybePop();
                        } else {
                          setState(() {
                            _signupError = result.message;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: auth.isLoading ? null : () => Navigator.of(context).maybePop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}

class _AuthForm extends StatelessWidget {
  const _AuthForm({
    required this.emailController,
    required this.passwordController,
    required this.isLoading,
    required this.onSubmitted,
    required this.primaryLabel,
    required this.helperText,
    this.errorText,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isLoading;
  final Future<void> Function(String email, String password) onSubmitted;
  final String primaryLabel;
  final String helperText;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: '邮箱',
            ),
            enabled: !isLoading,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: '密码',
            ),
            enabled: !isLoading,
          ),
          const SizedBox(height: 12),
          Text(
            helperText,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (errorText != null && errorText!.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              errorText!,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.error),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      FocusScope.of(context).unfocus();
                      await onSubmitted(emailController.text.trim(), passwordController.text);
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(primaryLabel),
            ),
          ),
        ],
      ),
    );
  }
}
