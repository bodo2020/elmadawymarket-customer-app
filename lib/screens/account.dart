import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:barcode_widget/barcode_widget.dart';
import '../core/design.dart';
import '../core/ui.dart';
import 'auth.dart';
import 'address.dart';
import 'catalog.dart';
import 'returns.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});
  @override
  Widget build(BuildContext context) => market.user == null
      ? ListView(
          padding: const EdgeInsets.all(MarketSpace.xl),
          children: [
            heading('حسابك في المعداوي'),
            const Text(
              'سجّل دخولك لحفظ السلة والعناوين ومتابعة طلباتك ونقاطك.',
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => open(context, const AuthPage()),
              child: const Text('تسجيل الدخول'),
            ),
          ],
        )
      : ListView(
          key: const PageStorageKey('account'),
          padding: const EdgeInsets.all(MarketSpace.md),
          children: [
            Container(
              padding: const EdgeInsets.all(MarketSpace.lg),
              margin: const EdgeInsets.only(bottom: MarketSpace.sm),
              decoration: BoxDecoration(
                color: MarketColors.primarySurface,
                borderRadius: BorderRadius.circular(MarketRadius.extraLarge),
                border: Border.all(color: MarketColors.primaryLight),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 28,
                    backgroundColor: MarketColors.primaryLight,
                    child: Icon(
                      Icons.person_outline_rounded,
                      color: MarketColors.primary,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'أهلًا بيك في المعداوي',
                          style: TextStyle(
                            fontSize: 12,
                            color: MarketColors.textSecondary,
                          ),
                        ),
                        Text(
                          '${market.profile?['name'] ?? 'حسابك'}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: MarketColors.textPrimary,
                          ),
                        ),
                        Text(
                          market.user!.phone ?? market.user!.email ?? '',
                          style: const TextStyle(
                            fontSize: 12,
                            color: MarketColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if ('${market.profile?['name'] ?? ''}'.trim().isEmpty)
              const Text('كمّل اسمك علشان تقدر تؤكد الطلب'),
            const SectionHeader(
              'إدارة حسابك',
              subtitle: 'طلباتك، عناوينك ومزايا العضوية في مكان واحد',
            ),
            AccountLink(
              leading: const Icon(Icons.person_outline),
              title: const Text('بيانات الحساب وكلمة المرور'),
              onTap: () => open(context, const ProfilePage()),
            ),
            AccountLink(
              leading: const Icon(Icons.location_on_outlined),
              title: const Text('عناوين التوصيل'),
              onTap: () => open(context, const AddressesPage()),
            ),
            AccountLink(
              leading: const Icon(Icons.shopping_bag_outlined),
              title: const Text('مشترياتي وتتبع الطلبات'),
              onTap: () => open(context, const OrdersPage()),
            ),
            AccountLink(
              leading: const Icon(Icons.favorite_outline),
              title: const Text('المفضلة'),
              onTap: () => open(context, const FavoritesPage()),
            ),
            AccountLink(
              leading: const Icon(Icons.card_giftcard),
              title: const Text('بطاقة العضوية والنقاط والقسائم'),
              onTap: () => open(context, const LoyaltyPage()),
            ),
            AccountLink(
              leading: const Icon(Icons.assignment_return_outlined),
              title: const Text('طلبات الاسترجاع'),
              onTap: () => open(context, const ReturnsPage()),
            ),
            AccountLink(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('الإشعارات'),
              onTap: () => open(context, const NotificationsPage()),
            ),
            const SizedBox(height: MarketSpace.sm),
            ActionButton(
              'تسجيل الخروج',
              () async {
                await market.db.auth.signOut();
                await market.load();
              },
              icon: Icons.logout_rounded,
              danger: true,
            ),
          ],
        );
}

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});
  @override
  Widget build(BuildContext context) => PageFrame(
    'المفضلة',
    LoadView<List<JsonMap>>(
      load: () async {
        if (market.profile == null) return [];
        return await market.db
            .from('favorites')
            .select('product_id,variant_id')
            .eq('customer_id', market.profile!['id']);
      },
      builder: (favorites) => favorites.isEmpty
          ? const EmptyView('مفيش منتجات محفوظة لسه')
          : LoadView<List<Product>>(
              load: () async => rows(
                await market.rpc('get_customer_branch_products_by_ids', {
                  'p_branch_id': market.runtime?['delivery_branch_id'],
                  'p_product_ids': favorites
                      .map((e) => e['product_id'])
                      .toSet()
                      .toList(),
                }),
              ).map(Product.new).toList(),
              builder: (products) => GridView(
                gridDelegate: productGrid(context),
                padding: const EdgeInsets.all(12),
                children: favorites.expand((f) {
                  final found = products.where((p) => p.id == f['product_id']);
                  return found.isEmpty
                      ? <Widget>[]
                      : [
                          ProductCard(
                            found.first,
                            bulk: f['variant_id'] != null,
                          ),
                        ];
                }).toList(),
              ),
            ),
    ),
  );
}

class OrdersPage extends StatefulWidget {
  final String? orderId;
  const OrdersPage({super.key, this.orderId});
  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  RealtimeChannel? channel;
  Timer? timer;
  List<JsonMap>? data;
  Object? error;
  bool previous = false, fetching = false;
  @override
  void initState() {
    super.initState();
    refresh();
    if (market.profile != null) {
      channel = market.db
          .channel('flutter-orders:${market.user!.id}')
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

  Future<void> refresh() async {
    if (fetching || market.user == null) return;
    fetching = true;
    try {
      final result = await market.purchases();
      if (mounted) {
        setState(() {
          if (data == null && widget.orderId != null) {
            final target = result
                .where((e) => e['id'] == widget.orderId)
                .firstOrNull;
            if (target != null) {
              previous =
                  target['source_channel'] == 'store' ||
                  ['delivered', 'cancelled'].contains(target['status']);
            }
          }
          data = result;
          error = null;
        });
      }
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
        ? Center(
            child: FilledButton(
              onPressed: () => open(context, const AuthPage()),
              child: const Text('تسجيل الدخول'),
            ),
          )
        : Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('الجارية')),
                    ButtonSegment(value: true, label: Text('السابقة')),
                  ],
                  selected: {previous},
                  onSelectionChanged: (s) => setState(() => previous = s.first),
                ),
              ),
              if (error != null)
                TextButton(
                  onPressed: refresh,
                  child: Text('${friendlyError(error!)} — تحديث'),
                ),
              Expanded(
                child: data == null
                    ? const LoadingSurface()
                    : RefreshIndicator(
                        onRefresh: refresh,
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            if (!data!.any(
                              (e) =>
                                  previous ==
                                  (e['source_channel'] == 'store' ||
                                      [
                                        'delivered',
                                        'cancelled',
                                      ].contains(e['status'])),
                            ))
                              const StatusSurface(
                                title: 'مفيش طلبات هنا لسه',
                                message:
                                    'طلباتك هتظهر هنا لمتابعة حالتها وتفاصيلها.',
                                icon: Icons.receipt_long_outlined,
                              ),
                            for (final order in data!.where(
                              (e) =>
                                  previous ==
                                  (e['source_channel'] == 'store' ||
                                      [
                                        'delivered',
                                        'cancelled',
                                      ].contains(e['status'])),
                            ))
                              panel(
                                ExpansionTile(
                                  initiallyExpanded:
                                      order['id'] == widget.orderId,
                                  tilePadding: EdgeInsets.zero,
                                  title: Text(
                                    '#${order['tracking_number'] ?? '${order['id']}'.substring(0, 8)}',
                                  ),
                                  subtitle: Text(
                                    '${statusLabels['${order['status']}'] ?? order['status']} • ${money(order['total'])}',
                                  ),
                                  children: [
                                    Text(displayDate(order['created_at'])),
                                    Text('${order['branch_name'] ?? ''}'),
                                    if (order['source_channel'] != 'store')
                                      OrderTimeline(
                                        '${order['status']}',
                                        orderId: '${order['id']}',
                                      ),
                                    Text('${order['shipping_address'] ?? ''}'),
                                    Text(
                                      'الدفع: ${statusLabels['${order['payment_status']}'] ?? order['payment_status'] ?? ''}',
                                    ),
                                    ...normalizeOrderItems(order['items']).map(
                                      (item) => ListTile(
                                        title: Text(
                                          '${item['name'] ?? 'منتج'}',
                                        ),
                                        subtitle: Text(
                                          '${item['quantity']} ${item['unit_of_measure'] == 'weight'
                                              ? 'كجم'
                                              : item['is_bulk'] == true
                                              ? 'عبوة'
                                              : 'قطعة'}',
                                        ),
                                        trailing: Text(money(item['total'])),
                                      ),
                                    ),
                                    if (order['source_channel'] == 'online' &&
                                        order['status'] == 'delivered')
                                      TextButton(
                                        onPressed: () => open(
                                          context,
                                          ReturnFormPage(order),
                                        ),
                                        child: const Text('طلب استرجاع'),
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
    actions: [
      IconButton(
        tooltip: 'تحديث',
        onPressed: refresh,
        icon: const Icon(Icons.refresh),
      ),
    ],
  );
}

List<JsonMap> normalizeOrderItems(dynamic value) =>
    value is Map ? value.values.map(row).toList() : rows(value);

class OrderTimeline extends StatelessWidget {
  final String status;
  final String orderId;
  const OrderTimeline(this.status, {super.key, required this.orderId});
  @override
  Widget build(BuildContext context) {
    const stages = [
      'pending',
      'confirmed',
      'preparing',
      'ready',
      'shipped',
      'delivered',
    ];
    if (status == 'cancelled') return const Text('تم إلغاء الطلب');
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
            ListTile(
              dense: true,
              leading: Icon(
                i <= current ? Icons.check_circle : Icons.circle_outlined,
                color: i <= current
                    ? MarketColors.success
                    : MarketColors.textTertiary,
              ),
              title: Text(statusLabels[stages[i]]!),
              subtitle: Text(
                '${history.where((e) => e['new_status'] == stages[i]).firstOrNull?['created_at'] ?? ''}',
              ),
            ),
        ],
      ),
    );
  }
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  RealtimeChannel? channel;
  int revision = 0;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    if (market.user != null) {
      channel = market.db
          .channel('flutter-notifications:${market.user!.id}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'customer_notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: market.user!.id,
            ),
            callback: (_) {
              if (mounted) setState(() => revision++);
            },
          )
          .subscribe();
    }
    timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => revision++);
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    if (channel != null) market.db.removeChannel(channel!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PageFrame(
    'الإشعارات',
    market.user == null
        ? const Center(child: Text('سجّل دخولك لعرض الإشعارات'))
        : LoadView<List<JsonMap>>(
            key: ValueKey(revision),
            load: () async => await market.db
                .from('customer_notifications')
                .select()
                .eq('user_id', market.user!.id)
                .order('created_at', ascending: false)
                .limit(200),
            builder: (data) => data.isEmpty
                ? const EmptyView('مفيش إشعارات جديدة')
                : ListView(
                    padding: const EdgeInsets.all(12),
                    children: data
                        .map(
                          (n) => Card(
                            child: ListTile(
                              leading: Icon(
                                n['read_at'] == null
                                    ? Icons.notifications_active
                                    : Icons.notifications_none,
                              ),
                              title: Text('${n['title']}'),
                              subtitle: Text('${n['body']}'),
                              onTap: () => perform(context, () async {
                                await market.db
                                    .from('customer_notifications')
                                    .update({
                                      'read_at': DateTime.now()
                                          .toUtc()
                                          .toIso8601String(),
                                    })
                                    .eq('id', n['id'])
                                    .eq('user_id', market.user!.id);
                                if (mounted) setState(() => revision++);
                                if (context.mounted && n['order_id'] != null) {
                                  await open(
                                    context,
                                    OrdersPage(orderId: '${n['order_id']}'),
                                  );
                                }
                              }),
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
    actions: [
      if (market.user != null)
        IconButton(
          tooltip: 'تحديد الكل كمقروء',
          onPressed: () => perform(context, () async {
            await market.db
                .from('customer_notifications')
                .update({'read_at': DateTime.now().toUtc().toIso8601String()})
                .eq('user_id', market.user!.id)
                .isFilter('read_at', null);
            if (mounted) setState(() => revision++);
          }),
          icon: const Icon(Icons.done_all),
        ),
    ],
  );
}

class LoyaltyPage extends StatefulWidget {
  const LoyaltyPage({super.key});
  @override
  State<LoyaltyPage> createState() => _LoyaltyPageState();
}

class _LoyaltyPageState extends State<LoyaltyPage> {
  int revision = 0;
  final points = TextEditingController();
  @override
  void dispose() {
    points.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PageFrame(
    'العضوية والنقاط',
    LoadView<List<dynamic>>(
      key: ValueKey(revision),
      load: () => Future.wait([
        market.rpc('get_my_loyalty_card'),
        market.rpc('get_my_loyalty_vouchers', {'p_status': null}),
        market.rpc('get_my_loyalty_history', {'p_limit': 50}),
      ]),
      builder: (data) {
        final card = row(data[0]);
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            panel(
              Column(
                children: [
                  heading('${card['name'] ?? 'بطاقة المعداوي'}'),
                  Text('رقم العضوية: ${card['membership_number']}'),
                  const SizedBox(height: 16),
                  if ('${card['barcode_token'] ?? ''}'.isNotEmpty)
                    BarcodeWidget(
                      barcode: Barcode.code128(),
                      data: '${card['barcode_token']}',
                      height: 90,
                      drawText: false,
                    ),
                  heading('${card['points_balance']} نقطة'),
                  Text('رصيد التحويل: ${money(card['redeemable_credit_egp'])}'),
                ],
              ),
            ),
            heading('تحويل النقاط لقسيمة'),
            Text(
              '${card['redemption_points']} نقطة = ${money(card['redemption_value_egp'])}',
            ),
            TextField(
              controller: points,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'عدد النقاط'),
            ),
            ActionButton('إنشاء قسيمة خصم', () async {
              final value = int.tryParse(points.text);
              if (value == null || value <= 0) {
                message(context, 'اكتب عدد نقاط صحيح');
                return;
              }
              await market.rpc('create_loyalty_voucher', {'p_points': value});
              if (mounted) setState(() => revision++);
            }),
            heading('قسائمي'),
            ...rows(data[1]).map(
              (v) => panel(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(
                      '${v['voucher_code']}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text('المتبقي: ${money(v['remaining_value_egp'])}'),
                    Text('${v['status']}'),
                    if (v['barcode_token'] != null)
                      BarcodeWidget(
                        barcode: Barcode.code128(),
                        data: '${v['barcode_token']}',
                        height: 80,
                        drawText: false,
                      ),
                  ],
                ),
              ),
            ),
            heading('حركة النقاط'),
            ...rows(data[2]).map(
              (e) => ListTile(
                title: Text('${e['reference'] ?? e['entry_type']}'),
                subtitle: Text('${e['created_at']}'),
                trailing: Text('${e['points_delta']}'),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class AccountLink extends StatelessWidget {
  final Widget leading, title;
  final VoidCallback onTap;
  const AccountLink({
    super.key,
    required this.leading,
    required this.title,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: MarketSpace.xs),
    child: Material(
      color: MarketColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MarketRadius.large),
        side: const BorderSide(color: MarketColors.divider),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MarketRadius.large),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: MarketSpace.md,
          vertical: MarketSpace.xxs,
        ),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: MarketColors.primarySurface,
            borderRadius: BorderRadius.circular(MarketRadius.medium),
          ),
          child: IconTheme(
            data: const IconThemeData(size: 20, color: MarketColors.primary),
            child: leading,
          ),
        ),
        title: DefaultTextStyle.merge(
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          child: title,
        ),
        trailing: const Icon(
          Icons.chevron_left,
          size: 18,
          color: MarketColors.textTertiary,
        ),
        onTap: onTap,
      ),
    ),
  );
}
