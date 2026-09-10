import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/design.dart';
import '../core/ui.dart';
import 'auth.dart';
import 'returns.dart';

class OrdersPageV2 extends StatefulWidget {
  final String? orderId;
  const OrdersPageV2({super.key, this.orderId});

  @override
  State<OrdersPageV2> createState() => _OrdersPageV2State();
}

class _OrdersPageV2State extends State<OrdersPageV2> {
  RealtimeChannel? channel;
  Timer? timer;
  List<JsonMap>? data;
  Object? error;
  bool previous = false;
  bool fetching = false;

  @override
  void initState() {
    super.initState();
    refresh();
    if (market.user != null && market.profile != null) {
      channel = market.db
          .channel('flutter-orders-v2:${market.user!.id}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'online_orders',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'customer_id',
              value: market.profile!['id'],
            ),
            callback: (_) => refresh(),
          )
          .subscribe();
    }
    timer = Timer.periodic(const Duration(seconds: 30), (_) => refresh());
  }

  @override
  void dispose() {
    timer?.cancel();
    if (channel != null) market.db.removeChannel(channel!);
    super.dispose();
  }

  bool _isStore(JsonMap order) => '${order['source_channel']}' == 'store';

  bool _isPrevious(JsonMap order) =>
      _isStore(order) ||
      [
        'delivered',
        'cancelled',
        'store_completed',
      ].contains('${order['status']}');

  Future<void> refresh() async {
    if (fetching || market.user == null) return;
    fetching = true;
    try {
      final result = await market.purchases();
      if (!mounted) return;
      setState(() {
        data = result;
        error = null;
        if (widget.orderId != null) {
          final target = result
              .where((e) => '${e['id']}' == widget.orderId)
              .firstOrNull;
          if (target != null) previous = _isPrevious(target);
        }
      });
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      fetching = false;
    }
  }

  @override
  Widget build(BuildContext context) => PageFrame(
    'مشترياتي',
    market.user == null
        ? _SignedOutOrders(onLogin: () => open(context, const AuthPage()))
        : data == null
        ? const LoadingSurface()
        : RefreshIndicator(
            onRefresh: refresh,
            child: _OrdersBody(
              orders: data!,
              previous: previous,
              targetOrderId: widget.orderId,
              error: error,
              fetching: fetching,
              onRefresh: refresh,
              onPreviousChanged: (value) => setState(() => previous = value),
            ),
          ),
  );
}

class _SignedOutOrders extends StatelessWidget {
  final VoidCallback onLogin;
  const _SignedOutOrders({required this.onLogin});

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(24, 64, 24, 32),
    children: [
      Center(
        child: Container(
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            color: MarketColors.primarySurface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Icon(
            Icons.inventory_2_outlined,
            size: 38,
            color: MarketColors.primary,
          ),
        ),
      ),
      const SizedBox(height: 18),
      const Text(
        'طلباتك محفوظة في حسابك',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      const Text(
        'سجّل دخولك عشان تتابع طلبات التوصيل ومشتريات الفرع من مكان واحد.',
        textAlign: TextAlign.center,
        style: TextStyle(color: MarketColors.textSecondary, height: 1.6),
      ),
      const SizedBox(height: 22),
      FilledButton(onPressed: onLogin, child: const Text('تسجيل الدخول')),
    ],
  );
}

class _OrdersBody extends StatelessWidget {
  final List<JsonMap> orders;
  final bool previous;
  final String? targetOrderId;
  final Object? error;
  final bool fetching;
  final Future<void> Function() onRefresh;
  final ValueChanged<bool> onPreviousChanged;
  const _OrdersBody({
    required this.orders,
    required this.previous,
    required this.targetOrderId,
    required this.error,
    required this.fetching,
    required this.onRefresh,
    required this.onPreviousChanged,
  });

  bool _isStore(JsonMap order) => '${order['source_channel']}' == 'store';

  bool _isPrevious(JsonMap order) =>
      _isStore(order) ||
      [
        'delivered',
        'cancelled',
        'store_completed',
      ].contains('${order['status']}');

  @override
  Widget build(BuildContext context) {
    final current = orders.where((e) => !_isPrevious(e)).toList();
    final old = orders.where(_isPrevious).toList();
    final visible = previous ? old : current;
    final storeCount = orders.where(_isStore).length;
    final onlineCount = orders.length - storeCount;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: MarketColors.primarySurface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: MarketColors.primaryLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.inventory_2_outlined,
                    color: MarketColors.primary,
                    size: 30,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'مشترياتك كلها',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'تابع طلبات التوصيل لحظة بلحظة، وراجع فواتير الفرع المرتبطة بحسابك.',
                          style: TextStyle(
                            fontSize: 12,
                            color: MarketColors.textSecondary,
                            height: 1.55,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'تحديث',
                    onPressed: fetching ? null : onRefresh,
                    icon: fetching
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _Stat(
                      label: 'جارية',
                      value: '${current.length}',
                      emphasized: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Stat(label: 'أونلاين', value: '$onlineCount'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Stat(label: 'من الفرع', value: '$storeCount'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(
              value: false,
              label: Text('الجارية (${current.length})'),
            ),
            ButtonSegment(value: true, label: Text('السابقة (${old.length})')),
          ],
          selected: {previous},
          onSelectionChanged: (value) => onPreviousChanged(value.first),
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MarketColors.errorSurface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: MarketColors.error,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(friendlyError(error!))),
                TextButton(onPressed: onRefresh, child: const Text('تحديث')),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        if (visible.isEmpty)
          StatusSurface(
            title: previous ? 'مفيش مشتريات سابقة' : 'مفيش طلبات جارية دلوقتي',
            message: previous
                ? 'الطلبات المكتملة أو الملغاة ومشتريات الفرع هتظهر هنا.'
                : 'أول ما تعمل طلب أونلاين هتقدر تتابعه من هنا خطوة بخطوة.',
            icon: Icons.shopping_bag_outlined,
            actionLabel: previous ? null : 'تسوق الآن',
            onAction: previous ? null : () => openShellTab(context, 0),
          )
        else
          ...visible.map(
            (order) => _OrderCardV2(
              order: order,
              initiallyExpanded: '${order['id']}' == targetOrderId,
            ),
          ),
      ],
    );
  }
}

class _OrderCardV2 extends StatefulWidget {
  final JsonMap order;
  final bool initiallyExpanded;
  const _OrderCardV2({required this.order, required this.initiallyExpanded});

  @override
  State<_OrderCardV2> createState() => _OrderCardV2State();
}

class _OrderCardV2State extends State<_OrderCardV2> {
  late bool expanded = widget.initiallyExpanded;

  bool get online => '${widget.order['source_channel']}' != 'store';

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final status = '${order['status'] ?? ''}';
    final items = _normalizeItems(order['items']);
    final meta = _statusMeta(status, online: online);
    final identifier =
        '${order['invoice_number'] ?? order['tracking_number'] ?? order['id'] ?? ''}';
    final payment = _paymentMethod('${order['payment_method'] ?? ''}');
    final paymentStatus = _paymentStatus('${order['payment_status'] ?? ''}');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: MarketColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: MarketColors.divider),
        boxShadow: const [
          BoxShadow(
            color: Color(0x09000000),
            blurRadius: 16,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      _SourceBadge(online: online),
                      const Spacer(),
                      Text(
                        '${order['branch_name'] ?? 'المعداوي ماركت'}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: MarketColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 11),
                  Text(
                    online ? 'رقم الطلب' : 'رقم الفاتورة',
                    style: const TextStyle(
                      fontSize: 10,
                      color: MarketColors.textTertiary,
                    ),
                  ),
                  SelectableText(
                    '#$identifier',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    displayDate(order['created_at']),
                    style: const TextStyle(
                      fontSize: 10,
                      color: MarketColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _StatusCard(meta: meta),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _OrderMetric(
                          label: 'الإجمالي',
                          value: money(order['total']),
                        ),
                      ),
                      Expanded(
                        child: _OrderMetric(
                          label: 'المنتجات',
                          value: '${items.length}',
                        ),
                      ),
                    ],
                  ),
                  if (items.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _ProductStrip(items: items),
                  ],
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => setState(() => expanded = !expanded),
                    icon: Icon(
                      expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                    ),
                    label: Text(
                      expanded ? 'إخفاء التفاصيل' : 'عرض تفاصيل الطلب',
                    ),
                  ),
                ],
              ),
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 220),
              crossFadeState: expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: Container(
                color: MarketColors.surfaceSecondary,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (online) ...[
                      const _DetailsTitle(
                        icon: Icons.route_outlined,
                        text: 'تتبع الطلب',
                      ),
                      const SizedBox(height: 10),
                      status == 'cancelled'
                          ? const _CancelledNotice()
                          : OrderTimelineV2(
                              status: status,
                              orderId: '${order['id']}',
                            ),
                      const SizedBox(height: 16),
                    ],
                    const _DetailsTitle(
                      icon: Icons.receipt_long_outlined,
                      text: 'بيانات الطلب',
                    ),
                    const SizedBox(height: 8),
                    if ('${order['shipping_address'] ?? ''}'.trim().isNotEmpty)
                      _DetailRow(
                        icon: Icons.location_on_outlined,
                        label: 'عنوان التوصيل',
                        value: '${order['shipping_address']}',
                      ),
                    if (online)
                      _DetailRow(
                        icon: Icons.credit_card_outlined,
                        label: 'طريقة الدفع',
                        value: paymentStatus.isEmpty
                            ? payment
                            : '$payment · $paymentStatus',
                      ),
                    if ('${order['delivery_person'] ?? ''}'.trim().isNotEmpty)
                      _DetailRow(
                        icon: Icons.local_shipping_outlined,
                        label: 'مندوب التوصيل',
                        value: '${order['delivery_person']}',
                      ),
                    if ('${order['notes'] ?? ''}'.trim().isNotEmpty)
                      _DetailRow(
                        icon: Icons.edit_note_rounded,
                        label: 'ملاحظات الطلب',
                        value: '${order['notes']}',
                      ),
                    const SizedBox(height: 12),
                    _ItemsSection(items: items),
                    const SizedBox(height: 12),
                    if (number(order['shipping_cost']) > 0)
                      _SummaryLine('التوصيل', money(order['shipping_cost'])),
                    _SummaryLine(
                      'الإجمالي',
                      money(order['total']),
                      emphasized: true,
                    ),
                    if (online && status == 'delivered') ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => open(context, ReturnFormPage(order)),
                        icon: const Icon(Icons.assignment_return_outlined),
                        label: const Text('طلب استرجاع'),
                      ),
                    ],
                    if (!online ||
                        ['delivered', 'cancelled'].contains(status)) ...[
                      const SizedBox(height: 8),
                      FilledButton.tonalIcon(
                        onPressed: () => openShellTab(context, 0),
                        icon: const Icon(Icons.shopping_bag_outlined),
                        label: const Text('تسوق مرة أخرى'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OrderTimelineV2 extends StatelessWidget {
  final String status;
  final String orderId;
  const OrderTimelineV2({
    super.key,
    required this.status,
    required this.orderId,
  });

  static const stages = [
    'pending',
    'confirmed',
    'preparing',
    'ready',
    'shipped',
    'delivered',
  ];

  @override
  Widget build(BuildContext context) {
    final current = stages.indexOf(status);
    return LoadView<List<JsonMap>>(
      key: ValueKey('$orderId:$status'),
      load: () async => await market.db
          .from('order_status_history')
          .select('new_status,created_at,notes')
          .eq('order_id', orderId)
          .order('created_at'),
      builder: (history) => Column(
        children: [
          for (var i = 0; i < stages.length; i++)
            _TimelineStep(
              label: statusLabels[stages[i]] ?? stages[i],
              date: _historyDate(history, stages[i]),
              active: current >= 0 && i <= current,
              current: current == i,
              last: i == stages.length - 1,
            ),
        ],
      ),
    );
  }

  String _historyDate(List<JsonMap> history, String stage) {
    final match = history
        .where((e) => '${e['new_status']}' == stage)
        .firstOrNull;
    return match == null ? '' : displayDate(match['created_at']);
  }
}

class _TimelineStep extends StatelessWidget {
  final String label;
  final String date;
  final bool active;
  final bool current;
  final bool last;
  const _TimelineStep({
    required this.label,
    required this.date,
    required this.active,
    required this.current,
    required this.last,
  });

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 30,
          child: Column(
            children: [
              Icon(
                active ? Icons.check_circle_rounded : Icons.circle_outlined,
                size: current ? 24 : 20,
                color: active
                    ? MarketColors.success
                    : MarketColors.textTertiary,
              ),
              if (!last)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    color: active ? MarketColors.success : MarketColors.divider,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: current ? FontWeight.w800 : FontWeight.w600,
                    color: active
                        ? MarketColors.textPrimary
                        : MarketColors.textTertiary,
                  ),
                ),
                if (date.isNotEmpty)
                  Text(
                    date,
                    style: const TextStyle(
                      fontSize: 10,
                      color: MarketColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _StatusMeta {
  final String label;
  final String description;
  final Color color;
  final IconData icon;
  const _StatusMeta(this.label, this.description, this.color, this.icon);
}

_StatusMeta _statusMeta(String status, {required bool online}) {
  if (!online) {
    return const _StatusMeta(
      'شراء من الفرع',
      'تم تسجيل عملية الشراء ونقاطها في حسابك.',
      MarketColors.primary,
      Icons.storefront_outlined,
    );
  }
  return switch (status) {
    'pending' => const _StatusMeta(
      'تم استلام الطلب',
      'وصلنا طلبك وبنراجعه دلوقتي.',
      MarketColors.warning,
      Icons.schedule_rounded,
    ),
    'confirmed' => const _StatusMeta(
      'تم تأكيد الطلب',
      'طلبك اتأكد وداخل على مرحلة التجهيز.',
      MarketColors.info,
      Icons.verified_outlined,
    ),
    'preparing' => const _StatusMeta(
      'جاري التجهيز',
      'بنجهز منتجات طلبك بعناية.',
      Color(0xFF7C3AED),
      Icons.inventory_2_outlined,
    ),
    'ready' => const _StatusMeta(
      'الطلب جاهز',
      'طلبك جاهز ومستني يخرج للتوصيل.',
      Color(0xFF0284C7),
      Icons.shopping_bag_outlined,
    ),
    'shipped' => const _StatusMeta(
      'في الطريق إليك',
      'طلبك خرج للتوصيل وهو في الطريق.',
      Color(0xFF4F46E5),
      Icons.local_shipping_outlined,
    ),
    'delivered' => const _StatusMeta(
      'تم التسليم',
      'تم توصيل طلبك بنجاح.',
      MarketColors.success,
      Icons.check_circle_outline_rounded,
    ),
    'cancelled' => const _StatusMeta(
      'تم إلغاء الطلب',
      'الطلب اتلغى ولن يتم توصيله.',
      MarketColors.error,
      Icons.cancel_outlined,
    ),
    _ => _StatusMeta(
      statusLabels[status] ?? (status.isEmpty ? 'حالة الطلب' : status),
      'يتم تحديث حالة الطلب أول بأول.',
      MarketColors.textSecondary,
      Icons.info_outline_rounded,
    ),
  };
}

String _paymentMethod(String method) => switch (method) {
  'cash' || 'cod' => 'الدفع عند الاستلام',
  'wallet' => 'محفظة إلكترونية',
  'card' => 'بطاقة بنكية',
  _ => method.isEmpty ? 'غير محدد' : method,
};

String _paymentStatus(String status) => switch (status) {
  'pending' => 'بانتظار الدفع',
  'paid' => 'مدفوع',
  'failed' => 'فشل الدفع',
  'refunded' => 'تم رد المبلغ',
  _ => status,
};

List<JsonMap> _normalizeItems(dynamic value) =>
    value is Map ? value.values.map(row).toList() : rows(value);

class _StatusCard extends StatelessWidget {
  final _StatusMeta meta;
  const _StatusCard({required this.meta});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: meta.color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: meta.color.withValues(alpha: .12)),
    ),
    child: Row(
      children: [
        Icon(meta.icon, color: meta.color),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                meta.label,
                style: TextStyle(
                  color: meta.color,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                meta.description,
                style: TextStyle(color: meta.color, fontSize: 10, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SourceBadge extends StatelessWidget {
  final bool online;
  const _SourceBadge({required this.online});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: online ? MarketColors.infoSurface : MarketColors.primarySurface,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          online ? Icons.local_shipping_outlined : Icons.storefront_outlined,
          size: 16,
          color: online ? MarketColors.info : MarketColors.primary,
        ),
        const SizedBox(width: 5),
        Text(
          online ? 'طلب أونلاين' : 'شراء من الفرع',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: online ? MarketColors.info : MarketColors.primary,
          ),
        ),
      ],
    ),
  );
}

class _OrderMetric extends StatelessWidget {
  final String label;
  final String value;
  const _OrderMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 10, color: MarketColors.textTertiary),
      ),
      const SizedBox(height: 2),
      Text(
        value,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: MarketColors.primary,
        ),
      ),
    ],
  );
}

class _ProductStrip extends StatelessWidget {
  final List<JsonMap> items;
  const _ProductStrip({required this.items});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 58,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: items.length.clamp(0, 8),
      separatorBuilder: (_, _) => const SizedBox(width: 7),
      itemBuilder: (_, index) => _ProductImage(item: items[index], size: 56),
    ),
  );
}

class _ProductImage extends StatelessWidget {
  final JsonMap item;
  final double size;
  const _ProductImage({required this.item, required this.size});

  String get imageUrl {
    final product = item['product'] is Map
        ? row(item['product'])
        : item['products'] is Map
        ? row(item['products'])
        : <String, dynamic>{};
    final direct =
        item['image_url'] ??
        item['product_image_url'] ??
        item['thumbnail_url'] ??
        item['image'] ??
        product['image_url'];
    if (direct != null && '$direct'.trim().isNotEmpty) return '$direct';
    final images = item['image_urls'] ?? product['image_urls'];
    if (images is List && images.isNotEmpty) return '${images.first}';
    return '';
  }

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: MarketColors.surface,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: MarketColors.divider),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: photo(imageUrl, width: size - 8, height: size - 8),
    ),
  );
}

class _ItemsSection extends StatelessWidget {
  final List<JsonMap> items;
  const _ItemsSection({required this.items});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: MarketColors.surface,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'المنتجات (${items.length})',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          const Text(
            'تفاصيل المنتجات غير متاحة لهذا الطلب.',
            style: TextStyle(color: MarketColors.textSecondary),
          )
        else
          ...items.map((item) {
            final quantity = number(item['quantity']);
            final unit = '${item['unit_of_measure']}';
            final amount = unit == 'weight'
                ? quantity >= 1000
                      ? '${(quantity / 1000).toStringAsFixed(2)} كجم'
                      : '${quantity.round()} جم'
                : '${quantity.round()} ${item['is_bulk'] == true ? 'عبوة' : 'قطعة'}';
            final total = number(item['total']) > 0
                ? number(item['total'])
                : quantity *
                      number(item['price']) /
                      (unit == 'weight' ? 1000 : 1);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  _ProductImage(item: item, size: 50),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item['name'] ?? 'منتج'}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          amount,
                          style: const TextStyle(
                            fontSize: 10,
                            color: MarketColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    money(total),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: MarketColors.primary,
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    ),
  );
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: MarketColors.textTertiary),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: MarketColors.textTertiary,
                ),
              ),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(height: 1.5)),
            ],
          ),
        ),
      ],
    ),
  );
}

class _DetailsTitle extends StatelessWidget {
  final IconData icon;
  final String text;
  const _DetailsTitle({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 20, color: MarketColors.primary),
      const SizedBox(width: 7),
      Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
    ],
  );
}

class _SummaryLine extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasized;
  const _SummaryLine(this.label, this.value, {this.emphasized = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: emphasized ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: emphasized ? 16 : 13,
            color: emphasized ? MarketColors.primary : MarketColors.textPrimary,
          ),
        ),
      ],
    ),
  );
}

class _CancelledNotice extends StatelessWidget {
  const _CancelledNotice();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: MarketColors.errorSurface,
      borderRadius: BorderRadius.circular(14),
    ),
    child: const Text(
      'تم إلغاء الطلب. لو محتاج مساعدة تواصل مع خدمة العملاء.',
      style: TextStyle(color: MarketColors.error, fontSize: 12, height: 1.5),
    ),
  );
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasized;
  const _Stat({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: MarketColors.surface,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: MarketColors.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: emphasized ? MarketColors.primary : MarketColors.textPrimary,
          ),
        ),
      ],
    ),
  );
}
