import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../models/subscription.dart';
import '../services/subscription_repository.dart';
import 'auth_controller.dart';

class SubscriptionController extends ChangeNotifier {
  SubscriptionController(this._repository, this._authController) {
    _authListener = _handleAuthChanged;
    _authController.addListener(_authListener!);
  }

  final SubscriptionRepository _repository;
  final AuthController _authController;

  VoidCallback? _authListener;
  SubscriptionStatus _status = const SubscriptionStatus.pending();
  List<SubscriptionPlan> _plans = const <SubscriptionPlan>[];
  bool _isLoading = false;
  String? _note;
  Future<void>? _pendingRefresh;
  bool _isCreatingCheckout = false;

  bool get isConfigured => _repository.isConfigured && AppConfig.hasCreemConfig;

  bool get isLoading => _isLoading;

  SubscriptionStatus get status => _status;

  List<SubscriptionPlan> get availablePlans => List<SubscriptionPlan>.unmodifiable(_plans);

  String? get note => _note;

  bool get canSync => status.isActive;

  bool get isCreatingCheckout => _isCreatingCheckout;

  Future<void> initialise() async {
    if (!isConfigured) {
      _status = _repository.isConfigured ? const SubscriptionStatus.pending() : const SubscriptionStatus.disabled();
      _note ??= 'Creem 配置缺失，暂无法启用订阅同步。';
      notifyListeners();
      return;
    }
    await refresh();
  }

  Future<void> refresh() {
    if (_pendingRefresh != null) {
      return _pendingRefresh!;
    }
    final Future<void> future = _performRefresh().whenComplete(() {
      _pendingRefresh = null;
    });
    _pendingRefresh = future;
    return future;
  }

  Future<Uri> createCheckoutSession({
    required SubscriptionPlan plan,
    String? returnUrl,
  }) async {
    if (!isConfigured) {
      throw StateError('Creem 未配置，无法创建订阅。');
    }
    final String? userId = _authController.user?.id;
    final String? email = _authController.email;
    if (email == null || email.isEmpty) {
      throw StateError('当前账号缺少邮箱信息，请重新登录后再试。');
    }
    if (userId == null || userId.isEmpty) {
      throw StateError('请先登录后再订阅。');
    }
    if (_isCreatingCheckout) {
      throw StateError('正在创建订阅，请稍候。');
    }
    _isCreatingCheckout = true;
    notifyListeners();
    try {
      return await _repository.createCheckoutSession(
        plan: plan,
        email: email,
        userId: userId,
        returnUrl: returnUrl,
      );
    } finally {
      _isCreatingCheckout = false;
      notifyListeners();
    }
  }

  Future<void> _performRefresh() async {
    if (!isConfigured) {
      _status = const SubscriptionStatus.disabled();
      _plans = const <SubscriptionPlan>[];
      _note = 'Creem 配置缺失，暂无法启用订阅同步。';
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      _plans = await _repository.fetchAvailablePlans();
      _note = null;
    } on UnimplementedError catch (error) {
      _plans = const <SubscriptionPlan>[];
      _status = const SubscriptionStatus.pending();
      _note = error.message;
      _isLoading = false;
      notifyListeners();
      return;
    } catch (error) {
      _plans = const <SubscriptionPlan>[];
      _status = const SubscriptionStatus.pending();
      _note = '获取订阅计划失败：$error';
      _isLoading = false;
      notifyListeners();
      return;
    }

    if (_authController.isLoggedIn) {
      final String? email = _authController.email;
      if (email != null && email.isNotEmpty) {
        try {
          _status = await _repository.fetchStatus(
            email: email,
            userId: _authController.user?.id,
          );
          _note = null;
        } on UnimplementedError catch (error) {
          _status = const SubscriptionStatus.pending();
          _note = error.message;
        } catch (error) {
          _status = const SubscriptionStatus.pending();
          _note = '查询订阅状态失败：$error';
        }
      } else {
        _status = const SubscriptionStatus.pending();
        _note = '当前账号缺少邮箱信息，无法查询订阅状态。';
      }
    } else {
      _status = const SubscriptionStatus.inactive();
    }

    _isLoading = false;
    notifyListeners();
  }

  void _handleAuthChanged() {
    if (!isConfigured) {
      return;
    }
    unawaited(refresh());
  }

  @override
  void dispose() {
    if (_authListener != null) {
      _authController.removeListener(_authListener!);
      _authListener = null;
    }
    super.dispose();
  }
}
