import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../services/auth_repository.dart';

class AuthResult {
  const AuthResult({
    required this.success,
    this.requiresVerification = false,
    this.message,
  });

  final bool success;
  final bool requiresVerification;
  final String? message;

  static const AuthResult successResult = AuthResult(success: true);

  const AuthResult.success({String? message})
      : this(
          success: true,
          message: message,
        );

  AuthResult.failure(String message)
      : this(
          success: false,
          message: message,
        );
}

class AuthController extends ChangeNotifier {
  AuthController(this._repository);

  final AuthRepository _repository;

  StreamSubscription<AuthState>? _authSubscription;
  bool _isInitialized = false;
  bool _isLoading = false;
  User? _user;
  String? _lastError;

  bool get isConfigured => _repository.isConfigured && AppConfig.hasSupabaseConfig;

  bool get isInitialized => _isInitialized;

  bool get isLoading => _isLoading;

  bool get isLoggedIn => _user != null;

  String? get email => _user?.email;

  User? get user => _user;

  String? get lastError => _lastError;

  Future<void> initialise() async {
    if (_isInitialized) {
      return;
    }
    if (!isConfigured) {
      _isInitialized = true;
      notifyListeners();
      return;
    }

    _user = _repository.currentUser;
    _authSubscription = _repository.authStateChanges.listen((AuthState state) {
      final User? nextUser = state.session?.user;
      if (_user?.id != nextUser?.id) {
        _user = nextUser;
        notifyListeners();
      } else if (_user != nextUser) {
        _user = nextUser;
        notifyListeners();
      }
    });

    _isInitialized = true;
    notifyListeners();
  }

  Future<AuthResult> signUp({required String email, required String password}) async {
    if (!isConfigured) {
      return AuthResult.failure('Supabase 未配置，无法注册');
    }
    _setLoading(true);
    _lastError = null;
    notifyListeners();
    try {
      final AuthResponse response = await _repository.signUp(
        email: email,
        password: password,
        emailRedirectTo:
            AppConfig.supabaseEmailRedirectTo.isNotEmpty ? AppConfig.supabaseEmailRedirectTo : null,
      );
      final User? sessionUser = response.session?.user;
      final User? user = response.user;

      if (sessionUser != null) {
        _user = sessionUser;
        return const AuthResult.success();
      }

      if (user != null && user.emailConfirmedAt != null) {
        _user = user;
        return const AuthResult.success();
      }

      final String message = '注册成功，请查收邮箱完成验证后再登录。';
      return AuthResult(
        success: true,
        requiresVerification: true,
        message: message,
      );
    } on AuthException catch (error) {
      final String message = error.message;
      _lastError = message;
      return AuthResult.failure(message.isEmpty ? '注册失败' : message);
    } catch (error) {
      final String message = '注册出现异常，请稍后重试';
      _lastError = message;
      debugPrint('Supabase signUp error: $error');
      return AuthResult.failure(message);
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  Future<AuthResult> signIn({required String email, required String password}) async {
    if (!isConfigured) {
      return AuthResult.failure('Supabase 未配置，无法登录');
    }
    _setLoading(true);
    _lastError = null;
    notifyListeners();
    try {
      final AuthResponse response = await _repository.signIn(email: email, password: password);
      _user = response.user ?? _user;
      return const AuthResult.success();
    } on AuthException catch (error) {
      final String message = error.message;
      _lastError = message;
      return AuthResult.failure(message.isEmpty ? '登录失败' : message);
    } catch (error) {
      final String message = '登录出现异常，请稍后重试';
      _lastError = message;
      debugPrint('Supabase signIn error: $error');
      return AuthResult.failure(message);
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    if (!isConfigured || !isLoggedIn) {
      return;
    }
    _setLoading(true);
    notifyListeners();
    try {
      await _repository.signOut();
      _user = null;
      _lastError = null;
    } on AuthException catch (error) {
      _lastError = error.message;
    } catch (error) {
      _lastError = '退出登录失败';
      debugPrint('Supabase signOut error: $error');
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
