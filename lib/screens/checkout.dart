import 'package:flutter/material.dart';
import '../core/design.dart';
import '../core/ui.dart';
import 'address.dart';
import 'auth.dart';
import 'account.dart';
import 'catalog.dart';

class CartPage extends StatelessWidget {
  const CartPage({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: market,
    builder: (context, _) => market.cart.isEmpty
        ? EmptyView(
            'سلتك لسه فاضية',
            actionLabel: 'ابدأ تسوقك',
            onAction: () => open(
              context,
              const CatalogPage(title: 'المنتجات', search: true),
            ),
          )
        : ListView(
            key: const PageStorageKey('cart'),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(MarketSpace.md),
            children: [
              heading('سلة مشترياتك'),
              const Text(
                'راجع الكميات وبعدها كمّل لتفاصيل التوصيل والدفع.',
                style: TextStyle(
                  color: MarketColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: MarketSpace.sm),
              if (market.saving) const LinearProgressIndicator(),
              ...market.cart.map(
                (line) => panel(
                  Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: photo(
                          line.product.picture(line.bulk),
                          height: 60,
                          width: 60,
                        ),
                        title: Text(line.product.title(line.bulk)),
                        subtitle: Text('${line.amount} • ${money(line.total)}'),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            tooltip: 'حذف',
                            onPressed: market.saving
                                ? null
                                : () => perform(
                                    context,
                                    () => market.changeCart(
                                      line.product,
                                      0,
                                      bulk: line.bulk,
                                    ),
                                  ),
                            icon: const Icon(Icons.delete_outline),
                          ),
                          IconButton(
                            tooltip: 'تقليل',
                            onPressed: market.saving
                                ? null
                                : () => perform(
                                    context,
                                    () => market.changeCart(
                                      line.product,
                                      (line.quantity -
                                              (line.product.weighted
                                                  ? line.product.step
                                                  : 1))
                                          .clamp(0, 1000000),
                                      bulk: line.bulk,
                                    ),
                                  ),
                            icon: const Icon(Icons.remove),
                          ),
                          Expanded(
                            child: Text(
                              line.amount,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          IconButton(
                            tooltip: 'زيادة',
                            onPressed: market.saving
                                ? null
                                : () => perform(
                                    context,
                                    () => market.changeCart(
                                      line.product,
                                      line.quantity +
                                          (line.product.weighted
                                              ? line.product.step
                                              : 1),
                                      bulk: line.bulk,
                                    ),
                                  ),
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              heading(
                'المنتجات: ${money(market.cart.fold<double>(0, (sum, line) => sum + line.total))}',
              ),
              const Text(
                'تكلفة التوصيل والخصم يتأكدوا في الخطوة التالية.',
                style: TextStyle(
                  color: MarketColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const CartQuotePanel(),
              const SizedBox(height: MarketSpace.md),
              ActionButton('متابعة لمراجعة الطلب ←', () async {
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
              }, enabled: !market.saving),
              if (market.pending != null)
                TextButton(
                  onPressed: () => open(context, const CheckoutPage()),
                  child: const Text('استكمال محاولة الطلب السابقة'),
                ),
            ],
          ),
  );
}

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});
  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  JsonMap? quote;
  Object? error;
  bool loading = true;
  String method = 'cash';
  final notes = TextEditingController(),
      voucher = TextEditingController(),
      amount = TextEditingController();
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    notes.dispose();
    voucher.dispose();
    amount.dispose();
    super.dispose();
  }

  Future<void> load() async {
    if (mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      if (market.pending != null) {
        final result = await market.reconcile();
        if (result['exists'] == true) {
          await market.acceptReconciled();
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => ReceiptPage('${result['id']}')),
            );
          }
          return;
        }
      }
      final pending = market.pending;
      final q = await market.quote(
        pending == null ? checkoutLines(market.cart) : rows(pending['p_items']),
        '${pending?['p_address_id'] ?? market.address?['id']}',
      );
      if (mounted) setState(() => quote = q);
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> submit() async {
    if (quote == null) return;
    final parsed = double.tryParse(amount.text);
    if (voucher.text.trim().isNotEmpty && (parsed == null || parsed <= 0)) {
      message(context, 'اكتب قيمة القسيمة المطلوبة');
      return;
    }
    try {
      final result = await market.place(
        quote!,
        method: method,
        notes: notes.text.trim(),
        voucher: voucher.text.trim().isEmpty ? null : voucher.text.trim(),
        voucherAmount: parsed,
      );
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => ReceiptPage('${result['id']}')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e);
        message(
          context,
          'لم نقدر نأكد نتيجة الطلب. المحاولة محفوظة؛ راجع النتيجة قبل إنشاء طلب جديد.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => PageFrame(
    'مراجعة وتأكيد الطلب',
    loading
        ? const LoadingSurface()
        : ListView(
            padding: const EdgeInsets.all(MarketSpace.lg),
            children: [
              if (error != null)
                panel(
                  Column(
                    children: [
                      Text(friendlyError(error!)),
                      TextButton(
                        onPressed: load,
                        child: const Text('إعادة التحقق والتسعير'),
                      ),
                    ],
                  ),
                ),
              if (market.pending != null)
                panel(
                  Column(
                    children: [
                      const Text(
                        'عندك محاولة محفوظة. إعادة المحاولة تستخدم نفس رقم الطلب وتفاصيله.',
                      ),
                      if (market.canResetPending)
                        ActionButton(
                          'راجع النتيجة وابدأ مراجعة جديدة',
                          () async {
                            final result = await market.reconcile();
                            if (result['exists'] == true) {
                              await market.acceptReconciled();
                              if (context.mounted) {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ReceiptPage('${result['id']}'),
                                  ),
                                );
                              }
                              return;
                            }
                            await market.forgetPending();
                            await load();
                          },
                        ),
                    ],
                  ),
                ),
              if (quote != null) ...[
                heading('١. عنوانك ومنتجاتك'),
                Text('${market.address?['address'] ?? ''}'),
                if (market.pending == null)
                  TextButton(
                    onPressed: () async {
                      await open(context, const AddressesPage());
                      await load();
                    },
                    child: const Text('تغيير عنوان التوصيل'),
                  ),
                ...rows(quote!['items']).map(
                  (line) => ListTile(
                    title: Text('${line['name']}'),
                    subtitle: Text(
                      '${line['quantity']} ${line['unit_of_measure'] == 'weight'
                          ? 'جم'
                          : line['is_bulk'] == true
                          ? 'عبوة'
                          : 'قطعة'}',
                    ),
                    trailing: Text(money(line['total'])),
                  ),
                ),
                const Divider(),
                panel(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AmountRow('المنتجات', money(quote!['subtotal'])),
                      AmountRow('التوصيل', money(quote!['shipping_cost'])),
                      AmountRow(
                        'الإجمالي قبل القسيمة',
                        money(quote!['total']),
                        emphasized: true,
                      ),
                    ],
                  ),
                ),
                if (market.pending == null) ...[
                  heading('٢. الدفع والملاحظات'),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: method,
                    decoration: const InputDecoration(labelText: 'طريقة الدفع'),
                    items: const [
                      DropdownMenuItem(
                        value: 'cash',
                        child: Text('نقدًا عند الاستلام'),
                      ),
                      DropdownMenuItem(
                        value: 'wallet',
                        child: Text('محفظة إلكترونية'),
                      ),
                    ],
                    onChanged: (v) => setState(() => method = v!),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: notes,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات الطلب (اختياري)',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () async {
                      final vouchers = rows(
                        await market.rpc('get_my_loyalty_vouchers', {
                          'p_status': 'active',
                        }),
                      );
                      if (!context.mounted) return;
                      final selected = await showModalBottomSheet<JsonMap>(
                        context: context,
                        isScrollControlled: true,
                        builder: (c) => SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              MarketSpace.lg,
                              MarketSpace.xs,
                              MarketSpace.lg,
                              MarketSpace.lg,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'اختار قسيمة',
                                  style: Theme.of(c).textTheme.headlineSmall,
                                ),
                                const SizedBox(height: MarketSpace.sm),
                                if (vouchers.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: MarketSpace.xl,
                                    ),
                                    child: Text('مفيش قسائم متاحة'),
                                  )
                                else
                                  ...vouchers.map(
                                    (v) => ListTile(
                                      leading: const Icon(
                                        Icons.confirmation_number_outlined,
                                      ),
                                      title: Text('${v['voucher_code']}'),
                                      subtitle: Text(
                                        money(v['remaining_value_egp']),
                                      ),
                                      trailing: const Icon(
                                        Icons.chevron_left_rounded,
                                      ),
                                      onTap: () => Navigator.pop(c, v),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                      if (selected != null && mounted) {
                        setState(() {
                          voucher.text = '${selected['voucher_code']}';
                          amount.text = number(selected['remaining_value_egp'])
                              .clamp(0, number(quote!['total']))
                              .toStringAsFixed(2);
                        });
                      }
                    },
                    child: const Text('اختار من قسائمي'),
                  ),
                  TextField(
                    controller: voucher,
                    decoration: const InputDecoration(
                      labelText: 'كود قسيمة الولاء (اختياري)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'قيمة القسيمة المطلوب استخدامها',
                    ),
                  ),
                ],
                const SizedBox(height: MarketSpace.lg),
                const Text(
                  'راجع عنوانك وطريقة الدفع قبل التأكيد.',
                  style: TextStyle(
                    fontSize: 13,
                    color: MarketColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 92),
              ],
            ],
          ),
    bottom: !loading && quote != null
        ? StickyBottomCTA(
            child: ActionButton(
              market.pending == null ? 'تأكيد الطلب' : 'إعادة نفس المحاولة',
              submit,
              icon: Icons.check_circle_outline_rounded,
            ),
          )
        : null,
  );
}

class ReceiptPage extends StatelessWidget {
  final String id;
  const ReceiptPage(this.id, {super.key});
  @override
  Widget build(BuildContext context) => PageFrame(
    'بيانات الطلب',
    LoadView<JsonMap>(
      load: () async => await market.db
          .from('online_orders')
          .select()
          .eq('id', id)
          .eq('customer_id', market.profile!['id'])
          .single(),
      builder: (order) => ListView(
        padding: const EdgeInsets.all(MarketSpace.lg),
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: MarketColors.success,
            size: 72,
          ),
          heading('طلبك اتسجل'),
          Text('رقم الطلب: ${order['tracking_number'] ?? id}'),
          Text('الإجمالي: ${money(order['total'])}'),
          Text(
            'حالة الدفع: ${statusLabels['${order['payment_status']}'] ?? 'بانتظار الدفع'}',
          ),
          if (order['payment_method'] == 'wallet') ...[
            const Text(
              'حوّل المبلغ المستحق بعد الخصم عبر فودافون كاش أو انستا باي. الدفع لا يتأكد تلقائيًا.',
            ),
            const SelectableText('01005245096'),
            Text(
              'المستحق: ${money(order['amount_due'] ?? number(order['total']) - number(order['loyalty_voucher_amount']))}',
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => open(context, const OrdersPage()),
            child: const Text('متابعة الطلب'),
          ),
        ],
      ),
    ),
  );
}

class CartQuotePanel extends StatelessWidget {
  const CartQuotePanel({super.key});
  @override
  Widget build(BuildContext context) {
    if (market.address == null) return const SizedBox.shrink();
    return LoadView<JsonMap>(
      key: ValueKey(
        '${market.cart.map((e) => '${e.key}:${e.quantity}').join(',')}:${market.address?['latitude']}:${market.address?['longitude']}',
      ),
      load: () async => row(
        await market.rpc('quote_customer_cart', {
          'p_items': checkoutLines(market.cart),
          'p_latitude': market.address!['latitude'],
          'p_longitude': market.address!['longitude'],
        }),
      ),
      builder: (quote) => Column(
        children: [
          AmountRow('شامل التوصيل', money(quote['total']), emphasized: true),
          if (quote['minimum_order_met'] == false)
            Text('الحد الأدنى للطلب ${money(quote['min_order_amount'])}'),
        ],
      ),
    );
  }
}
