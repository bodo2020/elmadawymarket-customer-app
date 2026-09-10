import 'package:flutter/material.dart';

import '../core/design.dart';
import '../core/ui.dart';
import 'address.dart';
import 'auth.dart';
import 'checkout.dart';

class CartV2Page extends StatelessWidget {
  const CartV2Page({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: market,
        builder: (context, _) {
          if (!market.cartReady && market.loading) {
            return const LoadingSurface();
          }
          if (market.cart.isEmpty) return const _EmptyCart();
          return _CartContent(
            key: ValueKey(
              '${market.cart.map((e) => '${e.key}:${e.quantity}').join('|')}:${market.address?['latitude']}:${market.address?['longitude']}',
            ),
          );
        },
      );
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 64, 24, 32),
        children: [
          Center(
            child: Container(
              width: 82,
              height: 82,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: MarketColors.primarySurface,
                borderRadius: BorderRadius.circular(26),
              ),
              child: const Icon(
                Icons.shopping_bag_outlined,
                size: 39,
                color: MarketColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'سلتك مستنية اختياراتك',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'ضيف احتياجاتك، وهتلاقيها كلها هنا.\nتقدر تتسوّق وتختار براحتك قبل تسجيل الدخول.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: MarketColors.textSecondary,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => openShellTab(context, 0),
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('ابدأ التسوق'),
          ),
        ],
      );
}

class _CartContent extends StatelessWidget {
  const _CartContent({super.key});

  @override
  Widget build(BuildContext context) {
    final address = market.address;
    if (address == null) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const StatusSurface(
            title: 'حدد عنوان التوصيل',
            message: 'محتاجين عنوانك عشان نحسب الفرع والمخزون وسعر التوصيل بدقة.',
            icon: Icons.location_on_outlined,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => open(context, const AddressPage()),
            icon: const Icon(Icons.map_outlined),
            label: const Text('اختيار العنوان'),
          ),
        ],
      );
    }

    return LoadView<JsonMap>(
      load: () async => row(
        await market.rpc('quote_customer_cart', {
          'p_items': checkoutLines(market.cart),
          'p_latitude': address['latitude'],
          'p_longitude': address['longitude'],
        }),
      ),
      builder: (quote) => _QuotedCart(quote: quote),
    );
  }
}

class _QuotedCart extends StatelessWidget {
  final JsonMap quote;
  const _QuotedCart({required this.quote});

  JsonMap? quoteLine(CartLine cartLine) {
    final candidates = rows(quote['items']).where((line) {
      final unit = cartLine.product.weighted ? 'weight' : 'piece';
      return '${line['product_id']}' == cartLine.product.id &&
          (line['is_bulk'] == true) == cartLine.bulk &&
          '${line['unit_of_measure'] ?? unit}' == unit;
    });
    return candidates.isEmpty ? null : candidates.first;
  }

  @override
  Widget build(BuildContext context) {
    final subtotal = number(
      quote['subtotal'] ??
          market.cart.fold<double>(0, (sum, line) => sum + line.total),
    );
    final shipping = number(quote['shipping_cost']);
    final total = number(quote['total'] ?? subtotal + shipping);
    final branchName = '${quote['branch_name'] ?? market.runtime?['branch_name'] ?? ''}'.trim();
    final distance = number(quote['road_distance_km']);
    final duration = number(
      quote['road_duration_minutes'] ?? quote['duration_minutes'],
    );
    final minimumMet = quote['minimum_order_met'] != false;

    return Stack(
      children: [
        ListView(
          key: const PageStorageKey('cart-v2'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 132),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'سلتك، على ذوقك.',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${market.cart.length} أصناف · راجع اختياراتك وكمّل طلبك',
                        style: const TextStyle(
                          fontSize: 12,
                          color: MarketColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: MarketColors.primarySurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (market.saving)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        const Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: MarketColors.primary,
                        ),
                      const SizedBox(width: 5),
                      Text(
                        market.saving
                            ? 'جارٍ الحفظ'
                            : market.user == null
                                ? 'سلة الضيف جاهزة'
                                : 'سلتك محفوظة',
                        style: const TextStyle(
                          fontSize: 10,
                          color: MarketColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (market.error != null) ...[
              const SizedBox(height: 14),
              _Notice(
                icon: Icons.error_outline_rounded,
                text: market.error!,
                error: true,
              ),
            ],
            if (branchName.isNotEmpty) ...[
              const SizedBox(height: 14),
              _Notice(
                icon: Icons.route_outlined,
                text: [
                  'السلة متصلة بفرع $branchName',
                  if (distance > 0) 'مسافة الطريق ${distance.toStringAsFixed(1)} كم',
                  if (duration > 0) 'حوالي ${duration.round()} دقيقة',
                ].join(' · '),
              ),
            ],
            const SizedBox(height: 18),
            ...market.cart.map((line) {
              final serverLine = quoteLine(line);
              return _CartLineCard(line: line, serverLine: serverLine);
            }),
            const SizedBox(height: 8),
            _SummaryCard(
              subtotal: subtotal,
              shipping: shipping,
              total: total,
              freeDelivery: quote['free_delivery'] == true,
              minOrderAmount: number(quote['min_order_amount']),
              minimumMet: minimumMet,
            ),
            if (market.user == null) ...[
              const SizedBox(height: 12),
              const Text(
                'هنطلب رقم موبايلك عشان تكمّل طلبك ونحفظ العنوان في حسابك.',
                style: TextStyle(
                  fontSize: 11,
                  color: MarketColors.textSecondary,
                  height: 1.6,
                ),
              ),
            ],
          ],
        ),
        PositionedDirectional(
          start: 0,
          end: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            decoration: const BoxDecoration(
              color: MarketColors.surface,
              border: Border(top: BorderSide(color: MarketColors.divider)),
              boxShadow: [
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 18,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'الإجمالي شامل التوصيل',
                          style: TextStyle(
                            fontSize: 10,
                            color: MarketColors.textSecondary,
                          ),
                        ),
                        Text(
                          money(total),
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: MarketColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: market.saving || !minimumMet
                          ? null
                          : () => _proceed(context),
                      iconAlignment: IconAlignment.end,
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: const Text('متابعة الطلب'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _proceed(BuildContext context) async {
    if (market.user == null) {
      await open(context, const AuthPage());
      if (market.user == null || !context.mounted) return;
    }
    if ('${market.profile?['name'] ?? ''}'.trim().length < 2) {
      await open(context, const ProfilePage());
      if (!context.mounted) return;
    }
    if (market.address?['id'] == null) {
      await open(context, const AddressPage());
      if (!context.mounted) return;
    }
    if (market.address?['id'] != null) {
      await open(context, const CheckoutPage());
    }
  }
}

class _CartLineCard extends StatelessWidget {
  final CartLine line;
  final JsonMap? serverLine;
  const _CartLineCard({required this.line, required this.serverLine});

  @override
  Widget build(BuildContext context) {
    final p = line.product;
    final isWeight = p.weighted && !line.bulk;
    final available = number(serverLine?['available_stock']);
    final localMax = p.maxQuantity(line.bulk);
    final serverMax = available > 0
        ? isWeight
            ? (available * 1000).floor()
            : line.bulk
                ? (available / number(serverLine?['bulk_quantity'] ?? p.data['bulk_quantity']).clamp(1, double.infinity)).floor()
                : available.floor()
        : localMax;
    final maxQuantity = serverMax < localMax ? serverMax : localMax;
    final unitPrice = number(
      serverLine?['price'] ?? p.unitPrice(line.bulk),
    );
    final lineTotal = number(serverLine?['total'] ?? line.total);
    final step = isWeight ? p.step : 1;
    final atLimit = line.quantity + step > maxQuantity;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: MarketColors.surface,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: MarketColors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: photo(
              p.picture(line.bulk),
              width: 84,
              height: 84,
            ),
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
                        p.title(line.bulk),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'حذف',
                      onPressed: market.saving
                          ? null
                          : () => perform(
                                context,
                                () => market.changeCart(
                                  p,
                                  0,
                                  bulk: line.bulk,
                                ),
                              ),
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        size: 19,
                        color: MarketColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Icon(
                      line.bulk
                          ? Icons.inventory_2_outlined
                          : isWeight
                              ? Icons.scale_outlined
                              : Icons.shopping_bag_outlined,
                      size: 14,
                      color: MarketColors.textSecondary,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        line.bulk
                            ? 'جملة · ${number(p.data['bulk_quantity']).round()} قطعة'
                            : isWeight
                                ? 'بالوزن · الخطوة ${p.step} جم'
                                : 'بالقطعة',
                        style: const TextStyle(
                          fontSize: 10,
                          color: MarketColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${money(unitPrice)} ${isWeight ? '/ كجم' : line.bulk ? '/ عبوة' : '/ قطعة'}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: MarketColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      height: 38,
                      decoration: BoxDecoration(
                        color: MarketColors.primarySurface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            constraints: const BoxConstraints(
                              minWidth: 38,
                              minHeight: 38,
                            ),
                            padding: EdgeInsets.zero,
                            tooltip: line.quantity <= step ? 'حذف' : 'تقليل',
                            onPressed: market.saving
                                ? null
                                : () => perform(
                                      context,
                                      () => market.changeCart(
                                        p,
                                        line.quantity <= step
                                            ? 0
                                            : line.quantity - step,
                                        bulk: line.bulk,
                                      ),
                                    ),
                            icon: Icon(
                              line.quantity <= step
                                  ? Icons.delete_outline_rounded
                                  : Icons.remove_rounded,
                              size: 17,
                            ),
                          ),
                          ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 58),
                            child: Text(
                              line.amount,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: MarketColors.primary,
                              ),
                            ),
                          ),
                          IconButton(
                            constraints: const BoxConstraints(
                              minWidth: 38,
                              minHeight: 38,
                            ),
                            padding: EdgeInsets.zero,
                            tooltip: atLimit ? 'وصلت للكمية المتاحة' : 'زيادة',
                            onPressed: market.saving || atLimit
                                ? null
                                : () => perform(
                                      context,
                                      () => market.changeCart(
                                        p,
                                        line.quantity + step,
                                        bulk: line.bulk,
                                      ),
                                    ),
                            icon: const Icon(Icons.add_rounded, size: 17),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      money(lineTotal),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: MarketColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final double subtotal;
  final double shipping;
  final double total;
  final bool freeDelivery;
  final double minOrderAmount;
  final bool minimumMet;

  const _SummaryCard({
    required this.subtotal,
    required this.shipping,
    required this.total,
    required this.freeDelivery,
    required this.minOrderAmount,
    required this.minimumMet,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: MarketColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: MarketColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'ملخص سلتك',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            _SummaryRow('قيمة المنتجات', money(subtotal)),
            _SummaryRow(
              'التوصيل',
              shipping <= 0 ? 'مجاني' : money(shipping),
              valuePrimary: shipping <= 0,
            ),
            if (freeDelivery)
              const _SummaryRow(
                'عرض التوصيل',
                'توصيل مجاني مطبق',
                valuePrimary: true,
              ),
            const Divider(height: 24),
            _SummaryRow(
              'الإجمالي',
              money(total),
              emphasized: true,
              valuePrimary: true,
            ),
            if (minOrderAmount > 0) ...[
              const SizedBox(height: 10),
              Text(
                minimumMet
                    ? 'الحد الأدنى للطلب ${money(minOrderAmount)}'
                    : 'كمّل السلة للحد الأدنى ${money(minOrderAmount)}',
                style: TextStyle(
                  fontSize: 11,
                  color: minimumMet
                      ? MarketColors.textSecondary
                      : MarketColors.error,
                  fontWeight: minimumMet ? FontWeight.w400 : FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 8),
            const Text(
              'مسافة التوصيل محسوبة على طريق القيادة الفعلي.',
              style: TextStyle(
                fontSize: 10,
                color: MarketColors.textTertiary,
              ),
            ),
          ],
        ),
      );
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasized;
  final bool valuePrimary;
  const _SummaryRow(
    this.label,
    this.value, {
    this.emphasized = false,
    this.valuePrimary = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: emphasized ? 15 : 12,
                  fontWeight: emphasized ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: emphasized ? 18 : 12,
                fontWeight: FontWeight.w700,
                color: valuePrimary
                    ? MarketColors.primary
                    : MarketColors.textPrimary,
              ),
            ),
          ],
        ),
      );
}

class _Notice extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool error;
  const _Notice({required this.icon, required this.text, this.error = false});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: error ? MarketColors.errorSurface : MarketColors.primarySurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: error
                ? MarketColors.error.withValues(alpha: .18)
                : MarketColors.primaryLight,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: error ? MarketColors.error : MarketColors.primary,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.55,
                  color: error
                      ? MarketColors.error
                      : MarketColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
}
