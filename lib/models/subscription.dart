enum SubscriptionState {
  pending,
  inactive,
  active,
  disabled,
}

enum SubscriptionPlanType {
  monthly,
  yearly,
  lifetime,
}

class SubscriptionPlan {
  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.type,
    this.currency,
    this.price,
    this.description,
  });

  final String id;
  final String name;
  final SubscriptionPlanType type;
  final String? currency;
  final num? price;
  final String? description;
}

class SubscriptionStatus {
  const SubscriptionStatus._({
    required this.state,
    this.planId,
    this.planType,
    this.expiresAt,
  });

  final SubscriptionState state;
  final String? planId;
  final SubscriptionPlanType? planType;
  final DateTime? expiresAt;

  const SubscriptionStatus.pending() : this._(state: SubscriptionState.pending);

  const SubscriptionStatus.disabled() : this._(state: SubscriptionState.disabled);

  const SubscriptionStatus.inactive() : this._(state: SubscriptionState.inactive);

  const SubscriptionStatus.active({
    required SubscriptionPlanType planType,
    String? planId,
    DateTime? expiresAt,
  }) : this._(
          state: SubscriptionState.active,
          planType: planType,
          planId: planId,
          expiresAt: expiresAt,
        );

  bool get isActive => state == SubscriptionState.active;

  bool get isPending => state == SubscriptionState.pending;

  bool get isDisabled => state == SubscriptionState.disabled;

  bool get isLifetime => planType == SubscriptionPlanType.lifetime;

  String describeState() {
    switch (state) {
      case SubscriptionState.pending:
        return '订阅状态待确认';
      case SubscriptionState.inactive:
        return '尚未订阅';
      case SubscriptionState.active:
        if (isLifetime) {
          return '已激活（永久）';
        }
        if (expiresAt != null) {
          final DateTime local = expiresAt!.toLocal();
          final String formatted =
              '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
          return '已激活，截止 $formatted';
        }
        return '已激活';
      case SubscriptionState.disabled:
        return '订阅功能未启用';
    }
  }
}
