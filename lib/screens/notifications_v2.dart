import 'dart:async';

import 'package:flutter/material.dart';

import '../core/design.dart';
import '../core/ui.dart';
import 'account.dart';
import 'address.dart';
import 'returns.dart';

typedef JsonMap = Map<String, dynamic>;

enum CustomerNotificationFilterV2 { all, unread }

class CustomerNotificationItemV2 {
  final String id;
  final String eventKey;
  final String category;
  final String severity;
  final String title;
  final String body;
  final String sourceKind;
  final String? sourceId;
  final String? actionUrl;
  final String? actionLabel;
  final List<String> eligibleChannels;
  final String? readAt;
  final String createdAt;
  final String updatedAt;
  final JsonMap metadata;

  const CustomerNotificationItemV2({
    required this.id,
    required this.eventKey,
    required this.category,
    required this.severity,
    required this.title,
    required this.body,
    required this.sourceKind,
    required this.sourceId,
    required this.actionUrl,
    required this.actionLabel,
    required this.eligibleChannels,
    required this.readAt,
    required this.createdAt,
    required this.updatedAt,
    required this.metadata,
  });

  bool get unread => readAt == null;

  factory CustomerNotificationItemV2.fromMap(JsonMap raw) {
    final channels = raw['eligible_channels'];
    return CustomerNotificationItemV2(
      id: '${raw['id'] ?? ''}',
      eventKey: '${raw['event_key'] ?? ''}',
      category: '${raw['category'] ?? 'customers'}',
      severity: const {'critical', 'high', 'normal', 'info'}
              .contains('${raw['severity']}')
          ? '${raw['severity']}'
          : 'normal',
      title: '${raw['title'] ?? 'إشعار جديد'}',
      body: '${raw['body'] ?? ''}',
      sourceKind: '${raw['source_kind'] ?? ''}',
      sourceId: raw['source_id'] is String ? raw['source_id'] as String : null,
      actionUrl: raw['action_url'] is String ? raw['action_url'] as String : null,
      actionLabel:
          raw['action_label'] is String ? raw['action_label'] as String : null,
      eligibleChannels: channels is List
          ? channels.map((value) => '$value').toList(growable: false)
          : const ['in_app'],
      readAt: raw['read_at'] is String ? raw['read_at'] as String : null,
      createdAt: '${raw['created_at'] ?? ''}',
      updatedAt: '${raw['updated_at'] ?? raw['created_at'] ?? ''}',
      metadata: raw['metadata'] is Map
          ? Map<String, dynamic>.from(raw['metadata'] as Map)
          : const {},
    );
  }
}

class CustomerNotificationCenterV2 {
  final int total;
  final int unread;
  final int today;
  final List<CustomerNotificationItemV2> items;

  const CustomerNotificationCenterV2({
    required this.total,
    required this.unread,
    required this.today,
    required this.items,
  });
}

Future<CustomerNotificationCenterV2> fetchCustomerNotificationCenterV2(
  CustomerNotificationFilterV2 filter,
) async {
  await market.rpc('sync_my_notification_center_v2', {'p_branch_id': null});
  final rawValue = await market.rpc('get_my_notification_center_v2', {
    'p_branch_id': null,
    'p_filter': filter == CustomerNotificationFilterV2.unread ? 'unread' : 'all',
    'p_category': null,
    'p_limit': 150,
  });
  final raw = rawValue is Map
      ? Map<String, dynamic>.from(rawValue)
      : <String, dynamic>{};
  final summary = raw['summary'] is Map
      ? Map<String, dynamic>.from(raw['summary'] as Map)
      : <String, dynamic>{};
  final rawItems = raw['items'] is List ? raw['items'] as List : const [];
  return CustomerNotificationCenterV2(
    total: _asInt(summary['total']),
    unread: _asInt(summary['unread']),
    today: _asInt(summary['today']),
    items: rawItems
        .whereType<Map>()
        .map((item) => CustomerNotificationItemV2.fromMap(
              Map<String, dynamic>.from(item),
            ))
        .toList(growable: false),
  );
}

Future<void> markCustomerNotificationReadV2(String notificationId) async {
  await market.rpc('mark_notification_read_v2', {
    'p_notification_id': notificationId,
  });
}

Future<int> markAllCustomerNotificationsReadV2() async {
  final result = await market.rpc('mark_all_notifications_read_v2', {
    'p_branch_id': null,
  });
  return _asInt(result);
}

int _asInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}

class CustomerNotificationBellV2 extends StatefulWidget {
  final Color? color;
  const CustomerNotificationBellV2({super.key, this.color});

  @override
  State<CustomerNotificationBellV2> createState() =>
      _CustomerNotificationBellV2State();
}

class _CustomerNotificationBellV2State
    extends State<CustomerNotificationBellV2> {
  Timer? _timer;
  int _unread = 0;
  String? _latestTitle;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _refresh());
  }

  @override
  void didUpdateWidget(covariant CustomerNotificationBellV2 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (market.user == null && _unread != 0) {
      setState(() {
        _unread = 0;
        _latestTitle = null;
      });
    }
  }

  Future<void> _refresh() async {
    if (market.user == null) return;
    try {
      final center = await fetchCustomerNotificationCenterV2(
        CustomerNotificationFilterV2.unread,
      );
      if (!mounted) return;
      setState(() {
        _unread = center.unread;
        _latestTitle = center.items.isEmpty ? null : center.items.first.title;
      });
    } catch (_) {
      // The bell must never block the customer app because of a transient
      // notification-service failure.
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (market.user == null) return const SizedBox.shrink();
    final visible = _unread > 0;
    return IconButton(
      tooltip: _latestTitle ?? 'الإشعارات',
      onPressed: () async {
        await open(context, const NotificationsV2Page());
        await _refresh();
      },
      icon: Badge(
        isLabelVisible: visible,
        backgroundColor: MarketColors.discount,
        label: Text(_unread > 99 ? '99+' : '$_unread'),
        child: Icon(
          Icons.notifications_outlined,
          color: widget.color ?? MarketColors.primary,
        ),
      ),
    );
  }
}

class NotificationsV2Page extends StatefulWidget {
  const NotificationsV2Page({super.key});

  @override
  State<NotificationsV2Page> createState() => _NotificationsV2PageState();
}

class _NotificationsV2PageState extends State<NotificationsV2Page> {
  CustomerNotificationFilterV2 filter = CustomerNotificationFilterV2.all;
  Timer? timer;
  int revision = 0;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) setState(() => revision++);
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<CustomerNotificationCenterV2> _load() =>
      fetchCustomerNotificationCenterV2(filter);

  Future<void> _markAllRead() async {
    final ok = await perform(context, () async {
      await markAllCustomerNotificationsReadV2();
    });
    if (ok && mounted) setState(() => revision++);
  }

  Future<void> _openNotification(CustomerNotificationItemV2 item) async {
    if (item.unread) {
      try {
        await markCustomerNotificationReadV2(item.id);
      } catch (_) {
        // Opening the destination is more important than blocking the customer
        // when read-state persistence temporarily fails.
      }
    }
    if (!mounted) return;
    await _navigateAction(item);
    if (mounted) setState(() => revision++);
  }

  Future<void> _navigateAction(CustomerNotificationItemV2 item) async {
    final metadataOrderId = item.metadata['order_id'];
    String? orderId = metadataOrderId is String && metadataOrderId.isNotEmpty
        ? metadataOrderId
        : null;
    final rawUrl = item.actionUrl?.trim();
    Uri? uri;
    if (rawUrl != null && rawUrl.startsWith('/')) {
      uri = Uri.tryParse(rawUrl);
      if (orderId == null) {
        final queryOrder = uri?.queryParameters['order_id'];
        if (queryOrder != null && queryOrder.isNotEmpty) orderId = queryOrder;
      }
    }

    if (orderId != null) {
      await open(context, OrdersPage(orderId: orderId));
      return;
    }

    switch (uri?.path) {
      case '/orders':
        await open(context, const OrdersPage());
        return;
      case '/favorites':
        await open(context, const FavoritesPage());
        return;
      case '/loyalty':
      case '/vouchers':
        await open(context, const LoyaltyPage());
        return;
      case '/returns':
        await open(context, const ReturnsPage());
        return;
      case '/addresses':
        await open(context, const AddressesPage());
        return;
      case '/cart':
        openShellTab(context, 2);
        return;
      case '/account':
        openShellTab(context, 3);
        return;
      case '/categories':
        openShellTab(context, 1);
        return;
      case '/':
        openShellTab(context, 0);
        return;
      default:
        return;
    }
  }

  @override
  Widget build(BuildContext context) => PageFrame(
        'الإشعارات',
        market.user == null
            ? _SignedOutNotifications(onLogin: () => openShellTab(context, 3))
            : LoadView<CustomerNotificationCenterV2>(
                key: ValueKey('$revision:$filter'),
                load: _load,
                builder: (center) {
                  final items = center.items;
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                    children: [
                      _NotificationHero(
                        unread: center.unread,
                        today: center.today,
                        total: center.total,
                        onMarkAllRead:
                            center.unread > 0 ? _markAllRead : null,
                      ),
                      const SizedBox(height: 16),
                      SegmentedButton<CustomerNotificationFilterV2>(
                        segments: [
                          const ButtonSegment(
                            value: CustomerNotificationFilterV2.all,
                            label: Text('الكل'),
                          ),
                          ButtonSegment(
                            value: CustomerNotificationFilterV2.unread,
                            label: Text('غير مقروء (${center.unread})'),
                          ),
                        ],
                        selected: {filter},
                        onSelectionChanged: (value) {
                          setState(() => filter = value.first);
                        },
                      ),
                      const SizedBox(height: 16),
                      if (items.isEmpty)
                        StatusSurface(
                          title: filter == CustomerNotificationFilterV2.unread
                              ? 'مفيش إشعارات جديدة'
                              : 'مفيش إشعارات لسه',
                          message:
                              'أي رسالة من المعداوي ماركت أو تحديث مرتبط بحسابك هيظهر هنا تلقائيًا.',
                          icon: Icons.notifications_none_rounded,
                        )
                      else
                        ...items.map(
                          (item) => _NotificationCardV2(
                            item: item,
                            onTap: () => _openNotification(item),
                          ),
                        ),
                    ],
                  );
                },
              ),
      );
}

class _SignedOutNotifications extends StatelessWidget {
  final VoidCallback onLogin;
  const _SignedOutNotifications({required this.onLogin});

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 56),
          const StatusSurface(
            title: 'إشعاراتك في مكان واحد',
            message:
                'سجّل دخولك عشان تستقبل تحديثات الطلب والعروض والتنبيهات المرتبطة بحسابك.',
            icon: Icons.notifications_outlined,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onLogin,
            child: const Text('تسجيل الدخول'),
          ),
        ],
      );
}

class _NotificationHero extends StatelessWidget {
  final int unread;
  final int today;
  final int total;
  final Future<void> Function()? onMarkAllRead;

  const _NotificationHero({
    required this.unread,
    required this.today,
    required this.total,
    required this.onMarkAllRead,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: MarketColors.successSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: MarketColors.primaryLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.notifications_active_outlined,
                  color: MarketColors.primary,
                  size: 25,
                ),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'مركز إشعاراتك',
                    style: TextStyle(
                      color: MarketColors.primary,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'الإشعارات داخل التطبيق مفعّلة تلقائيًا. تحديثات الطلب والعروض والمكافآت تظهر هنا وتحفظ حالة القراءة على حسابك.',
              style: TextStyle(
                color: MarketColors.textSecondary,
                height: 1.7,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                const Chip(
                  avatar: Icon(Icons.done_all_rounded, size: 17),
                  label: Text('داخل التطبيق مفعّل'),
                ),
                if (onMarkAllRead != null)
                  ActionChip(
                    avatar: const Icon(Icons.done_all_rounded, size: 17),
                    label: const Text('تحديد الكل كمقروء'),
                    onPressed: () => onMarkAllRead!(),
                  ),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(child: _SummaryTile(label: 'غير مقروء', value: unread)),
                const SizedBox(width: 8),
                Expanded(child: _SummaryTile(label: 'اليوم', value: today)),
                const SizedBox(width: 8),
                Expanded(child: _SummaryTile(label: 'الإجمالي', value: total)),
              ],
            ),
          ],
        ),
      );
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final int value;
  const _SummaryTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                color: MarketColors.textTertiary,
              ),
            ),
            Text(
              '$value',
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w700,
                color: MarketColors.primary,
              ),
            ),
          ],
        ),
      );
}

class _NotificationCardV2 extends StatelessWidget {
  final CustomerNotificationItemV2 item;
  final VoidCallback onTap;
  const _NotificationCardV2({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final visual = _visualFor(item);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: item.unread ? MarketColors.successSurface : MarketColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: item.unread ? MarketColors.primaryLight : MarketColors.divider,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: visual.background,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: visual.border),
                ),
                child: Icon(visual.icon, color: visual.foreground, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          displayDate(item.createdAt),
                          style: const TextStyle(
                            fontSize: 10,
                            color: MarketColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                    if (item.body.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.body,
                        style: const TextStyle(
                          color: MarketColors.textSecondary,
                          height: 1.55,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 7,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: MarketColors.surfaceSecondary,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _categoryLabel(item.category),
                            style: const TextStyle(
                              fontSize: 10,
                              color: MarketColors.textSecondary,
                            ),
                          ),
                        ),
                        if (item.actionUrl != null ||
                            item.metadata['order_id'] != null)
                          Text(
                            item.actionLabel ?? 'فتح التفاصيل',
                            style: const TextStyle(
                              fontSize: 11,
                              color: MarketColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (item.unread) ...[
                const SizedBox(width: 8),
                const Padding(
                  padding: EdgeInsets.only(top: 7),
                  child: Icon(
                    Icons.circle,
                    color: MarketColors.primary,
                    size: 9,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

({IconData icon, Color foreground, Color background, Color border}) _visualFor(
  CustomerNotificationItemV2 item,
) {
  final icon = switch (item.category) {
    'marketing' => Icons.auto_awesome_outlined,
    'loyalty' => Icons.card_giftcard_outlined,
    'returns' => Icons.assignment_return_outlined,
    _ => Icons.inventory_2_outlined,
  };
  if (item.severity == 'critical') {
    return (
      icon: icon,
      foreground: MarketColors.error,
      background: MarketColors.errorSurface,
      border: MarketColors.error.withValues(alpha: .16),
    );
  }
  if (item.severity == 'high') {
    return (
      icon: icon,
      foreground: const Color(0xff9b6500),
      background: const Color(0xfffff8e7),
      border: const Color(0xffffe3a3),
    );
  }
  return (
    icon: icon,
    foreground: MarketColors.primary,
    background: MarketColors.successSurface,
    border: MarketColors.primaryLight,
  );
}

String _categoryLabel(String category) => switch (category) {
      'orders' => 'الطلبات',
      'returns' => 'المرتجعات',
      'marketing' => 'العروض',
      'loyalty' => 'النقاط والمكافآت',
      'customers' => 'حسابك',
      _ => 'إشعار',
    };
