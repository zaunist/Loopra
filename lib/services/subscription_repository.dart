import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/subscription.dart';

/// 封装 Creem.io 订阅 API 的访问逻辑。
class SubscriptionRepository {
  SubscriptionRepository({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

  static final Uri _defaultBaseUri = Uri.parse('https://api.creem.io');
  static const String _productPath = '/v1/products';
  static const String _productsSearchPath = '/v1/products/search';
  static const String _transactionsSearchPath = '/v1/transactions/search';
  static const String _checkoutPath = '/v1/checkouts';

  final http.Client _httpClient;
  final Random _random = Random();

  bool get isConfigured => AppConfig.hasCreemConfig;

  Future<List<SubscriptionPlan>> fetchAvailablePlans() async {
    if (!isConfigured) {
      return const <SubscriptionPlan>[];
    }

    final bool hasSpecificProduct = AppConfig.creemProductId.isNotEmpty;
    final String path = hasSpecificProduct ? _productPath : _productsSearchPath;
    final Map<String, String> queryParameters = hasSpecificProduct
        ? <String, String>{'product_id': AppConfig.creemProductId}
        : <String, String>{'page_size': '50'};

    final Uri uri = _buildUri(path, queryParameters);

    final http.Response response = await _httpClient.get(uri, headers: _headers());
    if (response.statusCode == 204) {
      return const <SubscriptionPlan>[];
    }

    if (response.statusCode == 404) {
      return const <SubscriptionPlan>[];
    }

    _ensureSuccess(response, context: '获取订阅计划失败');

    final dynamic decoded = _decodeBody(response.body);
    final List<Map<String, dynamic>> items = _extractList(decoded);

    final List<SubscriptionPlan> plans = <SubscriptionPlan>[];
    for (final Map<String, dynamic> item in items) {
      final String? id = item['id'] as String?;
      final String? name = item['name'] as String?;
      if (id == null || name == null) {
        continue;
      }

      final String? billingType = (item['billing_type'] as String?)?.toLowerCase();
      if (billingType != 'onetime') {
        continue;
      }

      final String? status = (item['status'] as String?)?.toLowerCase();
      if (status != null && status != 'active') {
        continue;
      }

      plans.add(
        SubscriptionPlan(
          id: id,
          name: name,
          type: SubscriptionPlanType.lifetime,
          currency: item['currency'] as String?,
          price: _normalisePrice(_toNum(item['price'])),
          description: item['description'] as String?,
        ),
      );
    }

    plans.sort(
      (SubscriptionPlan a, SubscriptionPlan b) {
        if (a.price != null && b.price != null) {
          return a.price!.compareTo(b.price!);
        }
        return a.name.compareTo(b.name);
      },
    );

    return plans;
  }

  Future<SubscriptionStatus> fetchStatus({required String email}) async {
    if (!isConfigured) {
      return const SubscriptionStatus.disabled();
    }

    final String normalisedEmail = _normaliseEmail(email);
    if (normalisedEmail.isEmpty) {
      return const SubscriptionStatus.pending();
    }

    final Map<String, String> queryParameters = <String, String>{
      'page_size': '50',
      'customer_email': normalisedEmail,
      'metadata.customerEmail': normalisedEmail,
      'metadata.customer_email': normalisedEmail,
    }..removeWhere((_, String value) => value.isEmpty);

    final Uri uri = _buildUri(_transactionsSearchPath, queryParameters);

    final http.Response response = await _httpClient.get(uri, headers: _headers());

    if (response.statusCode == 404 || response.statusCode == 204) {
      return const SubscriptionStatus.inactive();
    }

    _ensureSuccess(response, context: '获取订阅状态失败');

    final dynamic decoded = _decodeBody(response.body);
    final List<Map<String, dynamic>> items = _extractList(decoded);
    if (items.isEmpty) {
      return const SubscriptionStatus.inactive();
    }

    List<Map<String, dynamic>> scoped = _filterTransactionsByEmail(items, normalisedEmail);
    if (scoped.isEmpty) {
      scoped = items;
    }

    scoped.sort(
      (Map<String, dynamic> a, Map<String, dynamic> b) =>
          _extractCreatedAt(b).compareTo(_extractCreatedAt(a)),
    );

    final Map<String, dynamic>? completed = _findTransactionByStatus(
      scoped,
      <String>{'completed', 'paid', 'success', 'succeeded', 'captured', 'fulfilled'},
    );
    if (completed != null) {
      final String? planId = _resolveProductId(completed);
      return SubscriptionStatus.active(
        planType: SubscriptionPlanType.lifetime,
        planId: planId,
      );
    }

    final Map<String, dynamic>? pending = _findTransactionByStatus(
      scoped,
      <String>{'pending', 'processing', 'requires_action', 'requires_payment_method', 'authorized'},
    );
    if (pending != null) {
      return const SubscriptionStatus.pending();
    }

    return const SubscriptionStatus.inactive();
  }

  Future<Uri> createCheckoutSession({
    required SubscriptionPlan plan,
    required String email,
    String? userId,
    String? returnUrl,
  }) async {
    if (!isConfigured) {
      throw StateError('Creem 未配置，无法创建订阅。');
    }

    if (plan.type != SubscriptionPlanType.lifetime) {
      throw ArgumentError.value(
        plan.type,
        'plan.type',
        '当前仅支持一次性付费（终身会员）计划。',
      );
    }

    final String normalisedEmail = _normaliseEmail(email);
    if (normalisedEmail.isEmpty) {
      throw ArgumentError.value(email, 'email', '邮箱地址无效，无法创建订阅。');
    }

    final Map<String, dynamic> payload = <String, dynamic>{
      'product_id': plan.id,
      'units': 1,
      'request_id': _generateRequestId(normalisedEmail),
      'customer': <String, String>{
        'email': normalisedEmail,
      },
      'metadata': <String, String>{
        'planId': plan.id,
        'customerEmail': normalisedEmail,
        if (userId != null && userId.isNotEmpty) 'userId': userId,
      },
    };
    if (returnUrl != null && returnUrl.isNotEmpty) {
      payload['success_url'] = returnUrl;
    }

    final Uri uri = _buildUri(_checkoutPath);
    final http.Response response = await _httpClient.post(
      uri,
      headers: _headers(contentTypeJson: true),
      body: jsonEncode(payload),
    );

    _ensureSuccess(response, context: '创建结算会话失败');

    final dynamic decoded = _decodeBody(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('Creem API 响应格式异常，未包含 checkout_url。');
    }

    final String? checkoutUrl = decoded['checkout_url'] as String? ?? decoded['success_url'] as String?;
    if (checkoutUrl == null || checkoutUrl.isEmpty) {
      throw StateError('Creem API 响应缺少 checkout_url。');
    }

    return Uri.parse(checkoutUrl);
  }

  void dispose() {
    _httpClient.close();
  }

  Map<String, String> _headers({bool contentTypeJson = false}) {
    final Map<String, String> headers = <String, String>{
      'Accept': 'application/json',
    };
    if (AppConfig.creemSendApiKeyFromClient && AppConfig.creemApiKey.isNotEmpty) {
      headers['x-api-key'] = AppConfig.creemApiKey;
    }
    if (contentTypeJson) {
      headers['Content-Type'] = 'application/json';
    }
    return headers;
  }

  Uri _buildUri(String path, [Map<String, String>? queryParameters]) {
    final Uri base = _resolveBaseUri();
    final String combinedPath = _combinePath(base.path, path);
    final Map<String, String> mergedQuery = <String, String>{
      if (base.hasQuery) ...base.queryParametersAll.map((String key, List<String> values) => MapEntry(key, values.isEmpty ? '' : values.last)),
      if (queryParameters != null) ...queryParameters,
    };
    if (mergedQuery.isEmpty) {
      return base.replace(path: combinedPath);
    }
    return base.replace(
      path: combinedPath,
      queryParameters: mergedQuery,
    );
  }

  Uri _resolveBaseUri() {
    final String raw = AppConfig.creemApiBaseUrl.trim();
    final String normalised = raw.isEmpty
        ? _defaultBaseUri.toString()
        : (raw.contains('://') ? raw : 'https://$raw');
    try {
      return Uri.parse(normalised);
    } catch (_) {
      return _defaultBaseUri;
    }
  }

  String _combinePath(String basePath, String relativePath) {
    final String trimmedBase = () {
      if (basePath.isEmpty || basePath == '/') {
        return '';
      }
      return basePath.endsWith('/') ? basePath.substring(0, basePath.length - 1) : basePath;
    }();
    final String trimmedRelative = relativePath.isEmpty
        ? ''
        : (relativePath.startsWith('/') ? relativePath : '/$relativePath');
    if (trimmedBase.isEmpty) {
      return trimmedRelative.isEmpty ? '/' : trimmedRelative;
    }
    if (trimmedRelative.isEmpty) {
      return trimmedBase;
    }
    return '$trimmedBase$trimmedRelative';
  }

  void _ensureSuccess(http.Response response, {required String context}) {
    final int statusCode = response.statusCode;
    if (statusCode >= 200 && statusCode < 300) {
      return;
    }
    throw http.ClientException(
      '$context（状态码 $statusCode）：${response.body}',
      response.request?.url,
    );
  }

  dynamic _decodeBody(String body) {
    if (body.isEmpty) {
      return null;
    }
    return jsonDecode(body);
  }

  List<Map<String, dynamic>> _extractList(dynamic data) {
    if (data == null) {
      return <Map<String, dynamic>>[];
    }
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().toList(growable: false);
    }
    if (data is Map<String, dynamic>) {
      final Object? items = data['items'];
      if (items is List) {
        return items.whereType<Map<String, dynamic>>().toList(growable: false);
      }
      return <Map<String, dynamic>>[data];
    }
    return <Map<String, dynamic>>[];
  }

  Map<String, dynamic>? _findTransactionByStatus(
    List<Map<String, dynamic>> items,
    Set<String> expectedStatuses,
  ) {
    for (final Map<String, dynamic> item in items) {
      final String? status = _normaliseStatus(item['status']);
      if (status == null || !expectedStatuses.contains(status)) {
        continue;
      }
      if (!_isLifetimeTransaction(item)) {
        continue;
      }
      final num? refundedAmount = _toNum(item['refunded_amount']);
      if (refundedAmount != null && refundedAmount > 0) {
        continue;
      }
      return item;
    }
    return null;
  }

  bool _isLifetimeTransaction(Map<String, dynamic> item) {
    final String? type = _normaliseStatus(item['type']);
    if (type != null) {
      const Set<String> lifetimeTypes = <String>{
        'onetime',
        'one-time',
        'one_time',
        'lifetime',
        'payment',
        'purchase',
        'sale',
      };
      if (lifetimeTypes.contains(type)) {
        return true;
      }
      if (type == 'subscription' || type == 'recurring') {
        final Object? planType = item['plan_type'] ?? item['planType'];
        if (_normaliseStatus(planType) == 'lifetime') {
          return true;
        }
      }
    }

    final Object? order = item['order'];
    if (order is Map<String, dynamic>) {
      final String? orderType = (order['type'] as String?)?.toLowerCase();
      if (orderType != null) {
        return orderType == 'onetime' || orderType == 'lifetime';
      }
      final String? billingType = (order['billing_type'] as String?)?.toLowerCase();
      if (billingType != null) {
        return billingType == 'onetime';
      }
    }

    final Object? metadata = item['metadata'];
    if (metadata is Map<String, dynamic>) {
      final String? planType = _normaliseStatus(metadata['planType'] ?? metadata['plan_type']);
      if (planType == 'lifetime') {
        return true;
      }
    }

    return true;
  }

  String? _resolveProductId(Map<String, dynamic> item) {
    final Object? product = item['product'];
    if (product is String && product.isNotEmpty) {
      return product;
    }

    final Object? order = item['order'];
    if (order is Map<String, dynamic>) {
      final Object? productId = order['product'] ?? order['product_id'];
      if (productId is String && productId.isNotEmpty) {
        return productId;
      }
    } else if (order is String && order.isNotEmpty) {
      return order;
    }

    final Object? metadata = item['metadata'];
    if (metadata is Map<String, dynamic>) {
      final Object? planId = metadata['planId'] ?? metadata['plan_id'];
      if (planId is String && planId.isNotEmpty) {
        return planId;
      }
    }

    return null;
  }

  List<Map<String, dynamic>> _filterTransactionsByEmail(
    List<Map<String, dynamic>> items,
    String email,
  ) {
    if (email.isEmpty) {
      return items;
    }
    final List<Map<String, dynamic>> matches = <Map<String, dynamic>>[];
    for (final Map<String, dynamic> item in items) {
      if (_transactionMatchesEmail(item, email)) {
        matches.add(item);
      }
    }
    return matches;
  }

  bool _transactionMatchesEmail(Map<String, dynamic> item, String email) {
    for (final String candidate in _extractEmailsFromTransaction(item)) {
      if (candidate == email) {
        return true;
      }
    }
    return false;
  }

  Iterable<String> _extractEmailsFromTransaction(Map<String, dynamic> item) {
    final Set<String> emails = <String>{};

    void addCandidate(Object? value) {
      if (value is! String) {
        return;
      }
      final String normalised = _normaliseEmail(value);
      if (normalised.isNotEmpty) {
        emails.add(normalised);
      }
    }

    addCandidate(item['customer_email']);
    addCandidate(item['customerEmail']);

    final Object? metadata = item['metadata'];
    if (metadata is Map<String, dynamic>) {
      addCandidate(metadata['customerEmail']);
      addCandidate(metadata['customer_email']);
      addCandidate(metadata['email']);
    }

    final Object? customer = item['customer'];
    if (customer is Map<String, dynamic>) {
      addCandidate(customer['email']);
      addCandidate(customer['primary_email']);
    }

    final Object? order = item['order'];
    if (order is Map<String, dynamic>) {
      addCandidate(order['customer_email']);
      addCandidate(order['customerEmail']);
    }

    final Object? billing = item['billing'];
    if (billing is Map<String, dynamic>) {
      addCandidate(billing['email']);
    }

    final String? fromRequestId = _extractEmailFromRequestId(item['request_id'] as String?);
    if (fromRequestId != null) {
      addCandidate(fromRequestId);
    }

    return emails;
  }

  String? _extractEmailFromRequestId(String? requestId) {
    if (requestId == null || requestId.isEmpty) {
      return null;
    }
    const String prefix = 'loopra_';
    if (!requestId.startsWith(prefix)) {
      return null;
    }
    final String rest = requestId.substring(prefix.length);
    final int lastUnderscore = rest.lastIndexOf('_');
    if (lastUnderscore <= 0) {
      return null;
    }
    final String withoutRandom = rest.substring(0, lastUnderscore);
    final int separatorIndex = withoutRandom.indexOf('_');
    if (separatorIndex < 0 || separatorIndex + 1 >= withoutRandom.length) {
      return null;
    }
    final String candidate = withoutRandom.substring(separatorIndex + 1);
    final String normalised = _normaliseEmail(candidate);
    return normalised.isEmpty ? null : normalised;
  }

  int _extractCreatedAt(Map<String, dynamic> item) {
    final Object? raw = item['created_at'] ?? item['createdAt'] ?? item['created'];
    if (raw is num) {
      return raw.toInt();
    }
    if (raw is String) {
      final int? parsed = int.tryParse(raw);
      if (parsed != null) {
        return parsed;
      }
      final DateTime? dateTime = DateTime.tryParse(raw);
      if (dateTime != null) {
        return dateTime.millisecondsSinceEpoch;
      }
    }
    return 0;
  }

  String? _normaliseStatus(Object? status) {
    if (status is String) {
      final String trimmed = status.trim();
      if (trimmed.isEmpty) {
        return null;
      }
      return trimmed.toLowerCase();
    }
    return null;
  }

  String _normaliseEmail(String? email) {
    if (email == null) {
      return '';
    }
    final String trimmed = email.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    return trimmed.toLowerCase();
  }

  num? _toNum(Object? value) {
    if (value is num) {
      return value;
    }
    if (value is String) {
      return num.tryParse(value);
    }
    return null;
  }

  num? _normalisePrice(num? raw) {
    if (raw == null) {
      return null;
    }
    if (raw is int) {
      return raw / 100;
    }
    if (raw is double && raw.roundToDouble() == raw) {
      return raw / 100;
    }
    return raw;
  }

  String _generateRequestId(String identifier) {
    final int millis = DateTime.now().millisecondsSinceEpoch;
    final StringBuffer buffer = StringBuffer('loopra_$millis');
    final String sanitized = identifier.trim().isEmpty
        ? ''
        : identifier.replaceAll(RegExp(r'[^a-zA-Z0-9@._-]'), '');
    if (sanitized.isNotEmpty) {
      buffer.write('_');
      buffer.write(sanitized.length > 40 ? sanitized.substring(0, 40) : sanitized);
    }
    buffer.write('_');
    for (int i = 0; i < 8; i++) {
      buffer.write(_random.nextInt(16).toRadixString(16));
    }
    return buffer.toString();
  }
}
