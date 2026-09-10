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

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  late Future<List<dynamic>> summary;

  @override
  void initState() {
    super.initState();
    summary = _loadSummary();
  }

  Future<List<dynamic>> _loadSummary() =>
      Future.wait([market.rpc('get_my_loyalty_card'), market.addresses()]);

  Future<void> _refresh() async {
    setState(() => summary = _loadSummary());
    await summary;
  }

  @override
  Widget build(BuildContext context) {
    if (market.user == null) {
      return ListView(
        padding: const EdgeInsets.all(MarketSpace.xl),
        children: [
          heading('حسابك في المعداوي'),
          const Text('سجّل دخولك لحفظ السلة والعناوين ومتابعة طلباتك ونقاطك.'),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => open(context, const AuthPage()),
            child: const Text('تسجيل الدخول'),
          ),
        ],
      );
    }

    return FutureBuilder<List<dynamic>>(
      future: summary,
      builder: (context, snapshot) {
        final card = snapshot.hasData
            ? row(snapshot.data![0])
            : <String, dynamic>{};
        final addresses = snapshot.hasData
            ? rows(snapshot.data![1])
            : <JsonMap>[];
        final defaultAddress = addresses.firstOrNull;
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            key: const PageStorageKey('account'),
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
            children: [
              _ProfileSummaryCard(
                name: '${market.profile?['name'] ?? 'حسابك'}',
                phone: market.user!.phone ?? market.user!.email ?? '',
                onEdit: () => open(context, const ProfilePage()),
              ),
              const SizedBox(height: 18),
              _LoyaltySummaryCard(
                card: card,
                loading: snapshot.connectionState != ConnectionState.done,
                onOpen: () => open(context, const LoyaltyPage()),
              ),
              const SizedBox(height: 18),
              _AddressSummaryCard(
                address: defaultAddress,
                onOpen: () => open(context, const AddressesPage()),
              ),
              const SizedBox(height: 18),
              _AccountShortcuts(
                onOrders: () => open(context, const OrdersPage()),
                onVouchers: () => open(context, const LoyaltyPage()),
                onFavorites: () => open(context, const FavoritesPage()),
              ),
              const SizedBox(height: 18),
              _AccountMenu(
                onNotifications: () => open(context, const NotificationsPage()),
                onAddresses: () => open(context, const AddressesPage()),
                onReturns: () => open(context, const ReturnsPage()),
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: MarketColors.error,
                  side: BorderSide(
                    color: MarketColors.error.withValues(alpha: .18),
                  ),
                  backgroundColor: MarketColors.surface,
                ),
                onPressed: () async {
                  await market.db.auth.signOut();
                  await market.load();
                },
                icon: const Icon(Icons.logout_rounded, size: 19),
                label: const Text('تسجيل الخروج'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProfileSummaryCard extends StatelessWidget {
  final String name, phone;
  final VoidCallback onEdit;
  const _ProfileSummaryCard({
    required this.name,
    required this.phone,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) => _accountCard(
    Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: MarketColors.primarySurface,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: MarketColors.primary,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'حسابك في المعداوي',
                      style: TextStyle(
                        fontSize: 12,
                        color: MarketColors.textTertiary,
                      ),
                    ),
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (phone.isNotEmpty)
                      Text(
                        phone,
                        textDirection: TextDirection.ltr,
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
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('تعديل بياناتي'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _LoyaltySummaryCard extends StatelessWidget {
  final JsonMap card;
  final bool loading;
  final VoidCallback onOpen;
  const _LoyaltySummaryCard({
    required this.card,
    required this.loading,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final barcode =
        '${card['barcode_token'] ?? card['membership_number'] ?? ''}';
    final points = card['points_balance'] ?? 0;
    final credit = card['redeemable_credit_egp'] ?? 0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xff006c3d), Color(0xff00552f)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26005931),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(
                Icons.card_giftcard_rounded,
                color: Color(0xffc9ead8),
                size: 19,
              ),
              SizedBox(width: 7),
              Expanded(
                child: Text(
                  'بطاقة المعداوي',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Color(0xffc9ead8), fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'نقاطك ومشترياتك في مكان واحد',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _LoyaltyMetric(
                  label: 'رصيد النقاط',
                  value: loading ? '—' : '$points',
                  suffix: 'نقطة',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _LoyaltyMetric(
                  label: 'قابل للتحويل لكوبون خصم',
                  value: loading ? '—' : money(credit),
                  suffix: 'رصيد متاح',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: MarketColors.primary,
              minimumSize: const Size(48, 52),
            ),
            onPressed: onOpen,
            icon: const Icon(Icons.confirmation_number_outlined, size: 18),
            label: const Text('تحويل النقاط إلى كوبون خصم'),
          ),
          if (barcode.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'امسح الباركود عند الكاشير',
                      style: TextStyle(
                        color: MarketColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  BarcodeWidget(
                    barcode: Barcode.code128(),
                    data: barcode,
                    height: 76,
                    drawText: true,
                    style: const TextStyle(fontSize: 11, letterSpacing: 2),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 13),
          Text(
            '${card['redemption_points'] ?? '—'} نقطة = ${money(card['redemption_value_egp'] ?? 0)} خصم',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xffd4eee0),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoyaltyMetric extends StatelessWidget {
  final String label, value, suffix;
  const _LoyaltyMetric({
    required this.label,
    required this.value,
    required this.suffix,
  });
  @override
  Widget build(BuildContext context) => Container(
    height:
        112 +
        (MediaQuery.textScalerOf(context).scale(14) - 14).clamp(0, 20) * 8,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0xffc9ead8), fontSize: 11),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          suffix,
          style: const TextStyle(color: Color(0xffc9ead8), fontSize: 10),
        ),
      ],
    ),
  );
}

class _AddressSummaryCard extends StatelessWidget {
  final JsonMap? address;
  final VoidCallback onOpen;
  const _AddressSummaryCard({required this.address, required this.onOpen});
  @override
  Widget build(BuildContext context) => _accountCard(
    Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _accountIcon(Icons.location_on_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'العنوان الأساسي',
                      style: TextStyle(
                        fontSize: 11,
                        color: MarketColors.primary,
                      ),
                    ),
                    const Text(
                      'عنوان التوصيل',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${address?['address'] ?? 'أضف عنوان التوصيل'}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onOpen,
            icon: const Icon(Icons.location_on_outlined, size: 18),
            label: const Text('إدارة أو تغيير العنوان'),
          ),
        ],
      ),
    ),
  );
}

class _AccountShortcuts extends StatelessWidget {
  final VoidCallback onOrders, onVouchers, onFavorites;
  const _AccountShortcuts({
    required this.onOrders,
    required this.onVouchers,
    required this.onFavorites,
  });
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final width = (box.maxWidth - 12) / 2;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          SizedBox(
            width: width,
            child: _ShortcutCard(
              icon: Icons.inventory_2_outlined,
              title: 'مشترياتي',
              subtitle: 'مشتريات الفرع وطلبات الأونلاين',
              onTap: onOrders,
            ),
          ),
          SizedBox(
            width: width,
            child: _ShortcutCard(
              icon: Icons.confirmation_number_outlined,
              title: 'كوبوناتي',
              subtitle: 'حوّل نقاطك لكوبون خصم',
              onTap: onVouchers,
            ),
          ),
          SizedBox(
            width: width,
            child: _ShortcutCard(
              icon: Icons.favorite_border_rounded,
              title: 'المفضلة',
              subtitle: 'منتجاتك المفضلة جاهزة للتسوق',
              onTap: onFavorites,
            ),
          ),
        ],
      );
    },
  );
}

class _ShortcutCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  const _ShortcutCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height:
            164 +
            (MediaQuery.textScalerOf(context).scale(14) - 14).clamp(0, 20) * 9,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: MarketColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _accountIcon(icon),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                height: 1.6,
                color: MarketColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _AccountMenu extends StatelessWidget {
  final VoidCallback onNotifications, onAddresses, onReturns;
  const _AccountMenu({
    required this.onNotifications,
    required this.onAddresses,
    required this.onReturns,
  });
  @override
  Widget build(BuildContext context) => _accountCard(
    Column(
      children: [
        _AccountMenuRow(
          icon: Icons.notifications_outlined,
          title: 'الإشعارات',
          subtitle: 'تابع تحديثات الطلب والدفع أول بأول',
          onTap: onNotifications,
        ),
        const Divider(),
        _AccountMenuRow(
          icon: Icons.location_on_outlined,
          title: 'عناوين التوصيل',
          subtitle: 'ضيف عنوان أو اختار عنوانك الافتراضي',
          onTap: onAddresses,
        ),
        const Divider(),
        _AccountMenuRow(
          icon: Icons.assignment_return_outlined,
          title: 'طلبات الاسترجاع',
          subtitle: 'راجع طلبات الاسترجاع وتابع حالتها',
          onTap: onReturns,
        ),
      ],
    ),
  );
}

class _AccountMenuRow extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  const _AccountMenuRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => ListTile(
    minTileHeight: 78,
    leading: _accountIcon(icon),
    title: Text(
      title,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
    ),
    subtitle: Text(
      subtitle,
      style: const TextStyle(fontSize: 11, color: MarketColors.textSecondary),
    ),
    trailing: const Icon(
      Icons.chevron_left_rounded,
      color: MarketColors.textTertiary,
      size: 19,
    ),
    onTap: onTap,
  );
}

Widget _accountCard(Widget child) => Container(
  decoration: BoxDecoration(
    color: MarketColors.surface,
    borderRadius: BorderRadius.circular(22),
    border: Border.all(color: MarketColors.divider),
    boxShadow: const [
      BoxShadow(color: Color(0x08000000), blurRadius: 16, offset: Offset(0, 6)),
    ],
  ),
  child: child,
);

Widget _accountIcon(IconData icon) => Container(
  width: 42,
  height: 42,
  decoration: BoxDecoration(
    color: MarketColors.primarySurface,
    borderRadius: BorderRadius.circular(13),
  ),
  child: Icon(icon, color: MarketColors.primary, size: 22),
);

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
