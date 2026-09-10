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

  bool _isPrevious(JsonMap order) =>
      ['delivered', 'cancelled'].contains('${order['status']}');

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
        : data == null
        ? const LoadingSurface()
        : RefreshIndicator(
            onRefresh: refresh,
            child: Builder(
              builder: (context) {
                final visible = data!
                    .where((order) => previous == _isPrevious(order))
                    .toList();
                final currentCount = data!.where((e) => !_isPrevious(e)).length;
                final storeCount = data!
                    .where((e) => e['source_channel'] == 'store')
                    .length;
                final onlineCount = data!.length - storeCount;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                  children: [
                    _FeatureIntro(
                      icon: Icons.receipt_long_outlined,
                      title: 'مشترياتك كلها',
                      subtitle:
                          'طلبات التوصيل وفواتير الفرع المرتبطة بباركود العضوية في سجل واحد.',
                      actions: [
                        OutlinedButton.icon(
                          onPressed: refresh,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('تحديث'),
                        ),
                        OutlinedButton(
                          onPressed: () => open(context, const ReturnsPage()),
                          child: const Text('طلبات الاسترجاع'),
                        ),
                      ],
                      stats: [
                        _MiniStat('جارية', '$currentCount'),
                        _MiniStat('من الفرع', '$storeCount'),
                        _MiniStat('أونلاين', '$onlineCount'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SegmentedButton<bool>(
                      segments: [
                        ButtonSegment(
                          value: false,
                          label: Text('الجارية ($currentCount)'),
                        ),
                        ButtonSegment(
                          value: true,
                          label: Text(
                            'السابقة (${data!.length - currentCount})',
                          ),
                        ),
                      ],
                      selected: {previous},
                      onSelectionChanged: (s) =>
                          setState(() => previous = s.first),
                    ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: TextButton(
                          onPressed: refresh,
                          child: Text('${friendlyError(error!)} — تحديث'),
                        ),
                      ),
                    const SizedBox(height: 16),
                    if (visible.isEmpty)
                      const StatusSurface(
                        title: 'مفيش طلبات هنا لسه',
                        message: 'طلباتك هتظهر هنا لمتابعة حالتها وتفاصيلها.',
                        icon: Icons.receipt_long_outlined,
                      )
                    else
                      ...visible.map(
                        (order) => _OrderCard(
                          order: order,
                          initiallyExpanded: order['id'] == widget.orderId,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
  );
}

class _OrderCard extends StatelessWidget {
  final JsonMap order;
  final bool initiallyExpanded;
  const _OrderCard({required this.order, required this.initiallyExpanded});

  @override
  Widget build(BuildContext context) {
    final online = order['source_channel'] != 'store';
    final status = '${order['status'] ?? ''}';
    final items = normalizeOrderItems(order['items']);
    final delivered = status == 'delivered';
    final cancelled = status == 'cancelled';
    final statusColor = cancelled
        ? MarketColors.error
        : delivered
        ? MarketColors.success
        : MarketColors.warning;
    final identifier =
        order['invoice_number'] ??
        order['tracking_number'] ??
        '${order['id'] ?? ''}';
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: online
                        ? MarketColors.infoSurface
                        : MarketColors.primarySurface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    online ? 'طلب أونلاين' : 'شراء من الفرع',
                    style: TextStyle(
                      color: online ? MarketColors.info : MarketColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '${order['branch_name'] ?? 'ماركت المعداوي'}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: MarketColors.textTertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'رقم الطلب',
              style: TextStyle(fontSize: 11, color: MarketColors.textTertiary),
            ),
            SelectableText(
              '#$identifier',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            Text(
              displayDate(order['created_at']),
              style: const TextStyle(
                fontSize: 11,
                color: MarketColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    delivered
                        ? Icons.check_circle_outline
                        : cancelled
                        ? Icons.cancel_outlined
                        : Icons.schedule_rounded,
                    color: statusColor,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          statusLabels[status] ?? status,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          delivered
                              ? 'تم توصيل طلبك بنجاح.'
                              : cancelled
                              ? 'تم إلغاء هذا الطلب.'
                              : 'طلبك قيد التجهيز والمتابعة.',
                          style: TextStyle(color: statusColor, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _OrderValue('الإجمالي', money(order['total']))),
                Expanded(child: _OrderValue('عدد المنتجات', '${items.length}')),
              ],
            ),
            ExpansionTile(
              initiallyExpanded: initiallyExpanded,
              tilePadding: EdgeInsets.zero,
              title: const Text(
                'عرض التفاصيل',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              children: [
                if (online) OrderTimeline(status, orderId: '${order['id']}'),
                if ('${order['shipping_address'] ?? ''}'.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.location_on_outlined),
                    title: Text('${order['shipping_address']}'),
                  ),
                ...items.map(
                  (item) => ListTile(
                    leading: _accountIcon(Icons.inventory_2_outlined),
                    title: Text('${item['name'] ?? 'منتج'}'),
                    subtitle: Text('الكمية: ${item['quantity']}'),
                    trailing: Text(
                      money(item['total']),
                      style: const TextStyle(
                        color: MarketColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                if (online && delivered)
                  FilledButton.tonal(
                    onPressed: () => open(context, ReturnFormPage(order)),
                    child: const Text('طلب استرجاع'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderValue extends StatelessWidget {
  final String label, value;
  const _OrderValue(this.label, this.value);
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 11, color: MarketColors.textTertiary),
      ),
      Text(
        value,
        style: const TextStyle(
          fontSize: 15,
          color: MarketColors.primary,
          fontWeight: FontWeight.w700,
        ),
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

  bool unreadOnly = false;

  Future<void> _markAllRead() async {
    await perform(context, () async {
      await market.db
          .from('customer_notifications')
          .update({'read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('user_id', market.user!.id)
          .isFilter('read_at', null);
      if (mounted) setState(() => revision++);
    });
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
            builder: (data) {
              final unread = data.where((n) => n['read_at'] == null).toList();
              final visible = unreadOnly ? unread : data;
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                children: [
                  _FeatureIntro(
                    icon: Icons.notifications_active_outlined,
                    title: 'تحديثات طلباتك',
                    subtitle:
                        'أي تغيير في حالة الطلب أو الدفع يظهر هنا فورًا وتقدر تفتح الطلب من الإشعار.',
                    actions: [
                      FilledButton.tonalIcon(
                        onPressed: _markAllRead,
                        icon: const Icon(Icons.done_all_rounded, size: 18),
                        label: const Text('تحديد الكل كمقروء'),
                      ),
                    ],
                    stats: [
                      _MiniStat(
                        'غير مقروء',
                        '${unread.length}',
                        emphasized: true,
                      ),
                      _MiniStat('كل الإشعارات', '${data.length}'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<bool>(
                    segments: [
                      const ButtonSegment(value: false, label: Text('الكل')),
                      ButtonSegment(
                        value: true,
                        label: Text('غير مقروء (${unread.length})'),
                      ),
                    ],
                    selected: {unreadOnly},
                    onSelectionChanged: (value) =>
                        setState(() => unreadOnly = value.first),
                  ),
                  const SizedBox(height: 16),
                  if (visible.isEmpty)
                    const StatusSurface(
                      title: 'مفيش إشعارات هنا',
                      message: 'التحديثات الجديدة هتظهر في المكان ده.',
                      icon: Icons.notifications_none_rounded,
                    )
                  else
                    ...visible.map(
                      (n) => _NotificationCard(
                        notification: n,
                        onTap: () => perform(context, () async {
                          if (n['read_at'] == null) {
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
                          }
                          if (context.mounted && n['order_id'] != null) {
                            await open(
                              context,
                              OrdersPage(orderId: '${n['order_id']}'),
                            );
                          }
                        }),
                      ),
                    ),
                ],
              );
            },
          ),
  );
}

class _NotificationCard extends StatelessWidget {
  final JsonMap notification;
  final VoidCallback onTap;
  const _NotificationCard({required this.notification, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final unread = notification['read_at'] == null;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: unread ? MarketColors.successSurface : MarketColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(17),
        side: BorderSide(
          color: unread ? MarketColors.primaryLight : MarketColors.divider,
        ),
      ),
      child: ListTile(
        minTileHeight: 92,
        leading: _accountIcon(Icons.inventory_2_outlined),
        title: Text(
          '${notification['title'] ?? 'تحديث طلبك'}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${notification['body'] ?? ''}'),
            if (notification['order_id'] != null)
              const Text(
                'فتح تفاصيل الطلب',
                style: TextStyle(
                  color: MarketColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            Text(
              displayDate(notification['created_at']),
              style: const TextStyle(
                fontSize: 10,
                color: MarketColors.textTertiary,
              ),
            ),
          ],
        ),
        trailing: unread
            ? const Icon(Icons.circle, color: MarketColors.primary, size: 10)
            : null,
        onTap: onTap,
      ),
    );
  }
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
    'كوبونات الخصم',
    LoadView<List<dynamic>>(
      key: ValueKey(revision),
      load: () => Future.wait([
        market.rpc('get_my_loyalty_card'),
        market.rpc('get_my_loyalty_vouchers', {'p_status': null}),
        market.rpc('get_my_loyalty_history', {'p_limit': 50}),
      ]),
      builder: (data) {
        final card = row(data[0]);
        final vouchers = rows(data[1]);
        final active = vouchers
            .where(
              (v) =>
                  '${v['status']}'.toLowerCase() == 'active' &&
                  number(v['remaining_value_egp']) > 0,
            )
            .toList();
        final previous = vouchers.where((v) => !active.contains(v)).toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xff006b3c), Color(0xff00542f)],
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1f005931),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '✦ نقاط المعداوي',
                    style: TextStyle(
                      color: Color(0xffc9ead8),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${card['points_balance'] ?? 0} نقطة',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'كل ${card['redemption_points'] ?? '—'} نقطة = كوبون خصم بقيمة ${money(card['redemption_value_egp'] ?? 0)}',
                    style: const TextStyle(
                      color: Color(0xffd4eee0),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'المتاح للتحويل الآن',
                          style: TextStyle(
                            color: Color(0xffc9ead8),
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          money(card['redeemable_credit_egp']),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _accountCard(
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '🎁 حوّل نقاطك لكوبون خصم',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'اختر عدد نقاط بمضاعفات التحويل، والكوبون يظهر فور إنشائه ويظل رصيده محفوظًا.',
                      style: TextStyle(
                        color: MarketColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: points,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'عدد النقاط',
                      ),
                    ),
                    const SizedBox(height: 12),
                    ActionButton('إنشاء كوبون خصم', () async {
                      final value = int.tryParse(points.text);
                      if (value == null || value <= 0) {
                        message(context, 'اكتب عدد نقاط صحيح');
                        return;
                      }
                      await market.rpc('create_loyalty_voucher', {
                        'p_points': value,
                      });
                      if (mounted) setState(() => revision++);
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'كوبونات الخصم المتاحة  ${active.length}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 10),
            if (active.isEmpty)
              const StatusSurface(
                title: 'لا توجد كوبونات متاحة',
                message: 'حوّل نقاطك إلى كوبون خصم ليظهر هنا.',
                icon: Icons.confirmation_number_outlined,
              )
            else
              ...active.map((v) => _VoucherCard(v)),
            const SizedBox(height: 18),
            Text(
              'كوبونات خصم سابقة',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 10),
            if (previous.isEmpty)
              const Text(
                'لا توجد كوبونات سابقة',
                style: TextStyle(color: MarketColors.textSecondary),
              )
            else
              ...previous.map((v) => _PreviousVoucherCard(v)),
            const SizedBox(height: 18),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text(
                'حركة النقاط',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              children: rows(data[2])
                  .map(
                    (e) => ListTile(
                      title: Text('${e['reference'] ?? e['entry_type']}'),
                      subtitle: Text(displayDate(e['created_at'])),
                      trailing: Text(
                        '${e['points_delta']}',
                        style: const TextStyle(
                          color: MarketColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        );
      },
    ),
  );
}

class _VoucherCard extends StatelessWidget {
  final JsonMap voucher;
  const _VoucherCard(this.voucher);
  @override
  Widget build(BuildContext context) {
    final barcode =
        '${voucher['barcode_token'] ?? voucher['voucher_code'] ?? ''}';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: MarketColors.primarySurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MarketColors.primaryLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  '${voucher['voucher_code']}',
                  style: const TextStyle(
                    color: MarketColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'متاح',
                  style: TextStyle(color: MarketColors.success, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _OrderValue(
                  'الرصيد المتبقي',
                  money(voucher['remaining_value_egp']),
                ),
              ),
              Expanded(
                child: _OrderValue(
                  'القيمة الأصلية',
                  money(voucher['initial_value_egp'] ?? voucher['value_egp']),
                ),
              ),
            ],
          ),
          if (barcode.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: BarcodeWidget(
                barcode: Barcode.code128(),
                data: barcode,
                height: 92,
                drawText: true,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'اعرض الباركود للكاشير أو اختر كوبون الخصم عند الدفع في التطبيق.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: MarketColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _PreviousVoucherCard extends StatelessWidget {
  final JsonMap voucher;
  const _PreviousVoucherCard(this.voucher);
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  '${voucher['voucher_code']}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  'القيمة الأصلية ${money(voucher['initial_value_egp'] ?? voucher['value_egp'])}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: MarketColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'تم استخدامه',
                style: TextStyle(
                  fontSize: 11,
                  color: MarketColors.textSecondary,
                ),
              ),
              Text(
                'متبقي ${money(voucher['remaining_value_egp'])}',
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _FeatureIntro extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final List<Widget> actions;
  final List<Widget> stats;
  const _FeatureIntro({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actions = const [],
    this.stats = const [],
  });
  @override
  Widget build(BuildContext context) => Container(
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
            Icon(icon, color: MarketColors.primary, size: 30),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: MarketColors.primary,
                      fontSize: 23,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: MarketColors.textSecondary,
                      height: 1.7,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(spacing: 10, runSpacing: 10, children: actions),
        ],
        if (stats.isNotEmpty) ...[
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: stats
                .map(
                  (s) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: s,
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    ),
  );
}

class _MiniStat extends StatelessWidget {
  final String label, value;
  final bool emphasized;
  const _MiniStat(this.label, this.value, {this.emphasized = false});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
    ),
    child: Column(
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 10,
            color: MarketColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            color: emphasized ? MarketColors.primary : MarketColors.textPrimary,
          ),
        ),
      ],
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
