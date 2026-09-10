import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../core/design.dart';
import '../core/ui.dart';
import 'account.dart';
import 'address.dart';
import 'orders_v2.dart';

const _walletPhoneNumber = '01005245096';

class CheckoutV2Page extends StatefulWidget {
  const CheckoutV2Page({super.key});

  @override
  State<CheckoutV2Page> createState() => _CheckoutV2PageState();
}

class _CheckoutV2PageState extends State<CheckoutV2Page> {
  JsonMap? quote;
  List<JsonMap> vouchers = [];
  Object? error;
  bool loading = true;
  bool submitting = false;
  String method = 'cash';
  String selectedVoucherId = 'none';
  String requestId = const Uuid().v4();
  final notes = TextEditingController();

  JsonMap? get pending => market.pending;

  @override
  void initState() {
    super.initState();
    _restorePending();
    load();
  }

  @override
  void dispose() {
    notes.dispose();
    super.dispose();
  }

  void _restorePending() {
    final saved = market.pending;
    if (saved == null) return;
    final savedRequest = '${saved['p_request_id'] ?? ''}'.trim();
    if (savedRequest.isNotEmpty) requestId = savedRequest;
    final savedMethod = '${saved['p_payment_method'] ?? 'cash'}';
    if (savedMethod == 'wallet' || savedMethod == 'cash') method = savedMethod;
    notes.text = '${saved['p_notes'] ?? ''}';
  }

  Future<void> load() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      if (market.user == null) throw StateError('AUTH_REQUIRED');
      if (market.pending != null) {
        _restorePending();
        final result = await market.reconcile();
        if (result['exists'] == true) {
          await market.acceptReconciled();
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => OrderSuccessV2Page(orderId: '${result['id']}'),
            ),
          );
          return;
        }
      }

      final saved = market.pending;
      final items = saved == null
          ? checkoutLines(market.cart)
          : rows(saved['p_items']);
      final addressId =
          '${saved?['p_address_id'] ?? market.address?['id'] ?? ''}';
      if (items.isEmpty) throw StateError('INVALID_CART');
      if (addressId.isEmpty) throw StateError('ADDRESS_REQUIRED');

      final results = await Future.wait<dynamic>([
        market.quote(items, addressId),
        market.rpc('get_my_loyalty_vouchers', {'p_status': 'active'}),
      ]);
      if (!mounted) return;
      setState(() {
        quote = row(results[0]);
        vouchers = rows(results[1]);
      });
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  double get grossTotal => number(quote?['total']);

  JsonMap? get selectedVoucher {
    if (selectedVoucherId == 'none') return null;
    return vouchers.where((v) => '${v['id']}' == selectedVoucherId).firstOrNull;
  }

  double get voucherAmount {
    final saved = pending;
    if (saved != null) {
      return number(saved['p_voucher_amount']).clamp(0, grossTotal);
    }
    final voucher = selectedVoucher;
    if (voucher == null) return 0;
    return number(voucher['remaining_value_egp']).clamp(0, grossTotal);
  }

  String? get voucherCode {
    final saved = pending;
    if (saved != null) {
      final value = '${saved['p_voucher_code'] ?? ''}'.trim();
      return value.isEmpty ? null : value;
    }
    final voucher = selectedVoucher;
    final value = '${voucher?['voucher_code'] ?? ''}'.trim();
    return value.isEmpty ? null : value;
  }

  double get payableTotal =>
      (grossTotal - voucherAmount).clamp(0, double.infinity);

  String get orderReference => requestId.replaceAll('-', '').toUpperCase();

  Future<void> _copy(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) message(context, 'تم نسخ $label');
  }

  Future<void> _resetAttempt() async {
    await market.forgetPending();
    requestId = const Uuid().v4();
    method = 'cash';
    selectedVoucherId = 'none';
    notes.clear();
    await load();
  }

  Future<void> submit() async {
    if (submitting || quote == null) return;
    setState(() {
      submitting = true;
      error = null;
    });
    try {
      final result = await market.place(
        quote!,
        method: payableTotal <= 0 ? 'cash' : method,
        notes: notes.text.trim(),
        voucher: voucherCode,
        voucherAmount: voucherAmount > 0 ? voucherAmount : null,
        requestId: requestId,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => OrderSuccessV2Page(orderId: '${result['id']}'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e);
      if (market.canResetPending) {
        message(context, 'راجع بيانات الطلب قبل التأكيد مرة تانية.');
      } else {
        message(
          context,
          'تعذر التأكد من نتيجة الطلب. اضغط تأكيد مرة تانية وهنكمل نفس المحاولة بدون طلب مكرر.',
        );
      }
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  Future<void> _confirmWallet() async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            4,
            20,
            20 + MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'تحويل المبلغ عبر المحفظة الإلكترونية',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                'حوّل القيمة بعد الخصم، واستخدم مرجع الطلب مع التحويل.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: MarketColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 18),
              _WalletAmountCard(amount: payableTotal, discount: voucherAmount),
              const SizedBox(height: 12),
              _CopyRow(
                label: 'فودافون كاش / إنستا باي',
                value: _walletPhoneNumber,
                onCopy: () => _copy(_walletPhoneNumber, 'رقم المحفظة'),
              ),
              const SizedBox(height: 10),
              _CopyRow(
                label: 'مرجع الطلب',
                value: orderReference,
                onCopy: () => _copy(orderReference, 'مرجع الطلب'),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => Navigator.pop(sheetContext, true),
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: const Text('تم، تأكيد الطلب'),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed == true && mounted) await submit();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const PageFrame('تأكيد الطلب', LoadingSurface());
    }

    if (market.cart.isEmpty && market.pending == null) {
      return PageFrame(
        'تأكيد الطلب',
        StatusSurface(
          title: 'السلة فاضية',
          message: 'أضف منتجات الأول وبعدها ارجع لتأكيد الطلب.',
          icon: Icons.shopping_cart_outlined,
          action: FilledButton(
            onPressed: () => openShellTab(context, 0),
            child: const Text('ابدأ التسوق'),
          ),
        ),
      );
    }

    return PageFrame(
      'تأكيد الطلب',
      RefreshIndicator(
        onRefresh: load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 130),
          children: [
            const Text(
              'آخر خطوة، وطلبك عندنا.',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 5),
            const Text(
              'السعر والتوصيل والتوفر وكوبون الخصم بيتراجعوا من السيرفر قبل إنشاء الطلب.',
              style: TextStyle(
                color: MarketColors.textSecondary,
                fontSize: 12,
                height: 1.6,
              ),
            ),
            if (pending != null) ...[
              const SizedBox(height: 14),
              _PendingNotice(
                canReset: market.canResetPending,
                onReset: _resetAttempt,
              ),
            ],
            if (error != null) ...[
              const SizedBox(height: 14),
              _ErrorCard(
                messageText: friendlyError(error!),
                onRetry: load,
                onReset: pending != null && market.canResetPending
                    ? _resetAttempt
                    : null,
              ),
            ],
            if (quote != null) ...[
              const SizedBox(height: 16),
              _SectionCard(
                icon: Icons.location_on_outlined,
                title: 'عنوان التوصيل',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${market.address?['address'] ?? 'عنوان محفوظ للمحاولة الحالية'}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          size: 15,
                          color: MarketColors.primary,
                        ),
                        const SizedBox(width: 5),
                        const Expanded(
                          child: Text(
                            'العنوان الافتراضي للتوصيل',
                            style: TextStyle(
                              fontSize: 11,
                              color: MarketColors.textSecondary,
                            ),
                          ),
                        ),
                        if (pending == null)
                          TextButton(
                            onPressed: () async {
                              await open(context, const AddressesPage());
                              if (mounted) await load();
                            },
                            child: const Text('تغيير'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _VoucherSection(
                vouchers: vouchers,
                selectedId: selectedVoucherId,
                lockedCode: pending == null ? null : voucherCode,
                lockedAmount: pending == null ? null : voucherAmount,
                grossTotal: grossTotal,
                onSelect: pending == null
                    ? (value) => setState(() => selectedVoucherId = value)
                    : null,
                onManage: () => open(context, const LoyaltyPage()),
              ),
              const SizedBox(height: 14),
              _SectionCard(
                icon: Icons.credit_card_outlined,
                title: 'طريقة الدفع',
                child: payableTotal <= 0
                    ? const _CoveredByVoucher()
                    : Column(
                        children: [
                          _PaymentChoice(
                            icon: Icons.payments_outlined,
                            title: 'الدفع عند الاستلام',
                            subtitle: 'ادفع المبلغ المطلوب عند وصول طلبك.',
                            selected: method == 'cash',
                            enabled: pending == null,
                            onTap: () => setState(() => method = 'cash'),
                          ),
                          const SizedBox(height: 10),
                          _PaymentChoice(
                            icon: Icons.account_balance_wallet_outlined,
                            title: 'المحفظة الإلكترونية',
                            subtitle:
                                'فودافون كاش أو إنستا باي بالقيمة بعد الخصم.',
                            selected: method == 'wallet',
                            enabled: pending == null,
                            onTap: () => setState(() => method = 'wallet'),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 14),
              _SectionCard(
                icon: Icons.edit_note_rounded,
                title: 'ملاحظة للطلب',
                child: pending != null
                    ? Text(
                        notes.text.trim().isEmpty
                            ? 'بدون ملاحظات'
                            : notes.text.trim(),
                        style: const TextStyle(
                          color: MarketColors.textSecondary,
                        ),
                      )
                    : TextField(
                        controller: notes,
                        maxLines: 3,
                        maxLength: 300,
                        decoration: const InputDecoration(
                          hintText:
                              'مثلاً: الاتصال قبل الوصول أو ملاحظة تخص التجهيز',
                          counterText: '',
                        ),
                      ),
              ),
              const SizedBox(height: 14),
              _OrderSummary(
                quote: quote!,
                voucherAmount: voucherAmount,
                payableTotal: payableTotal,
                reference: orderReference,
                onCopyReference: () => _copy(orderReference, 'مرجع الطلب'),
              ),
            ],
          ],
        ),
      ),
      bottom: quote == null
          ? null
          : StickyBottomCTA(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'المطلوب دفعه',
                          style: TextStyle(
                            fontSize: 10,
                            color: MarketColors.textSecondary,
                          ),
                        ),
                        Text(
                          money(payableTotal),
                          style: const TextStyle(
                            color: MarketColors.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: submitting
                          ? null
                          : () {
                              if (method == 'wallet' && payableTotal > 0) {
                                _confirmWallet();
                              } else {
                                submit();
                              }
                            },
                      icon: submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.lock_outline_rounded, size: 18),
                      label: Text(
                        submitting
                            ? 'جاري التأكيد...'
                            : pending == null
                            ? 'تأكيد الطلب'
                            : 'استكمال نفس المحاولة',
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class OrderSuccessV2Page extends StatelessWidget {
  final String orderId;
  const OrderSuccessV2Page({super.key, required this.orderId});

  Future<JsonMap> _load() async => row(
    await market.db
        .from('online_orders')
        .select()
        .eq('id', orderId)
        .eq('customer_id', market.profile!['id'])
        .single(),
  );

  @override
  Widget build(BuildContext context) => PageFrame(
    'تم تأكيد الطلب',
    LoadView<JsonMap>(
      load: _load,
      builder: (order) {
        final reference = '${order['tracking_number'] ?? orderId}';
        final amountDue = number(
          order['amount_due'] ??
              number(order['total']) - number(order['loyalty_voucher_amount']),
        );
        final wallet = order['payment_method'] == 'wallet' && amountDue > 0;
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 34, 20, 28),
          children: [
            Center(
              child: Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  color: MarketColors.successSurface,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  size: 52,
                  color: MarketColors.success,
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'طلبك وصلنا بنجاح',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'تقدر تتابع حالة طلبك لحظة بلحظة، وأي تحديث جديد هيظهر في مركز الإشعارات.',
              textAlign: TextAlign.center,
              style: TextStyle(color: MarketColors.textSecondary, height: 1.6),
            ),
            const SizedBox(height: 20),
            _CopyRow(
              label: 'مرجع الطلب',
              value: reference,
              onCopy: () async {
                await Clipboard.setData(ClipboardData(text: reference));
                if (context.mounted) message(context, 'تم نسخ رقم الطلب');
              },
            ),
            const SizedBox(height: 12),
            _SuccessSummary(order: order, amountDue: amountDue),
            if (wallet) ...[
              const SizedBox(height: 12),
              _SectionCard(
                icon: Icons.account_balance_wallet_outlined,
                title: 'بيانات التحويل',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'حوّل ${money(amountDue)} عبر فودافون كاش أو إنستا باي.',
                    ),
                    const SizedBox(height: 10),
                    _CopyRow(
                      label: 'رقم التحويل',
                      value: _walletPhoneNumber,
                      onCopy: () async {
                        await Clipboard.setData(
                          const ClipboardData(text: _walletPhoneNumber),
                        );
                        if (context.mounted) {
                          message(context, 'تم نسخ رقم المحفظة');
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: MarketColors.primarySurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: MarketColors.primaryLight),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.notifications_active_outlined,
                    color: MarketColors.primary,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'تحديثات حالة الطلب والدفع هتظهر في مركز الإشعارات داخل التطبيق.',
                      style: TextStyle(fontSize: 12, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => open(context, OrdersPageV2(orderId: orderId)),
              icon: const Icon(Icons.local_shipping_outlined),
              label: const Text('متابعة الطلب الآن'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => openShellTab(context, 0),
              icon: const Icon(Icons.home_outlined),
              label: const Text('العودة للرئيسية'),
            ),
          ],
        );
      },
    ),
  );
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: MarketColors.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: MarketColors.divider),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, color: MarketColors.primary, size: 21),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 14),
        child,
      ],
    ),
  );
}

class _PaymentChoice extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  const _PaymentChoice({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? MarketColors.primarySurface : MarketColors.surface,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? MarketColors.primary : MarketColors.divider,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Radio<bool>(
              value: true,
              groupValue: selected,
              onChanged: enabled ? (_) => onTap() : null,
            ),
            const SizedBox(width: 4),
            Icon(
              icon,
              color: selected
                  ? MarketColors.primary
                  : MarketColors.textSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: MarketColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _VoucherSection extends StatelessWidget {
  final List<JsonMap> vouchers;
  final String selectedId;
  final String? lockedCode;
  final double? lockedAmount;
  final double grossTotal;
  final ValueChanged<String>? onSelect;
  final VoidCallback onManage;
  const _VoucherSection({
    required this.vouchers,
    required this.selectedId,
    required this.lockedCode,
    required this.lockedAmount,
    required this.grossTotal,
    required this.onSelect,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context) => _SectionCard(
    icon: Icons.confirmation_number_outlined,
    title: 'استخدم كوبون خصم',
    child: lockedCode != null
        ? Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: MarketColors.successSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: MarketColors.primaryLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'كوبون الخصم للمحاولة الحالية',
                  style: TextStyle(fontSize: 11, color: MarketColors.primary),
                ),
                Text(
                  lockedCode!,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 5),
                Text('الخصم ${money(lockedAmount ?? 0)}'),
              ],
            ),
          )
        : vouchers.isEmpty
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'مفيش كوبون خصم متاح حاليًا. تقدر تحوّل نقاطك إلى كوبون خصم.',
                style: TextStyle(
                  color: MarketColors.textSecondary,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: onManage,
                child: const Text('كوبوناتي وتحويل النقاط'),
              ),
            ],
          )
        : Column(
            children: [
              _VoucherChoice(
                title: 'بدون كوبون خصم',
                subtitle: 'ادفع إجمالي الطلب بدون خصم نقاط.',
                selected: selectedId == 'none',
                onTap: () => onSelect?.call('none'),
              ),
              const SizedBox(height: 8),
              ...vouchers.map((voucher) {
                final balance = number(voucher['remaining_value_egp']);
                final applied = balance.clamp(0, grossTotal);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _VoucherChoice(
                    title: '${voucher['voucher_code']}',
                    subtitle:
                        'الرصيد ${money(balance)} · الخصم ${money(applied)}',
                    selected: selectedId == '${voucher['id']}',
                    onTap: () => onSelect?.call('${voucher['id']}'),
                  ),
                );
              }),
              TextButton(
                onPressed: onManage,
                child: const Text('إدارة كوبونات الخصم'),
              ),
            ],
          ),
  );
}

class _VoucherChoice extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  const _VoucherChoice({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? MarketColors.primarySurface : MarketColors.surface,
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? MarketColors.primary : MarketColors.divider,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: MarketColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle_rounded,
                color: MarketColors.primary,
              )
            else
              const Icon(
                Icons.circle_outlined,
                color: MarketColors.textTertiary,
              ),
          ],
        ),
      ),
    ),
  );
}

class _OrderSummary extends StatelessWidget {
  final JsonMap quote;
  final double voucherAmount;
  final double payableTotal;
  final String reference;
  final VoidCallback onCopyReference;
  const _OrderSummary({
    required this.quote,
    required this.voucherAmount,
    required this.payableTotal,
    required this.reference,
    required this.onCopyReference,
  });

  String _amount(JsonMap item) {
    final quantity = number(item['quantity']);
    if ('${item['unit_of_measure']}' == 'weight') {
      if (quantity >= 1000) {
        return '${(quantity / 1000).toStringAsFixed(2)} كجم';
      }
      return '${quantity.round()} جم';
    }
    if (item['is_bulk'] == true) {
      return '${quantity.round()} عبوة × ${number(item['bulk_quantity']).round().clamp(1, 99999)} قطعة';
    }
    return '${quantity.round()} قطعة';
  }

  @override
  Widget build(BuildContext context) {
    final items = rows(quote['items']);
    final shipping = number(quote['shipping_cost']);
    return _SectionCard(
      icon: Icons.shopping_bag_outlined,
      title: 'ملخص الطلب',
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MarketColors.primarySurface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  color: MarketColors.primary,
                  size: 19,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'الأسعار والمخزون وكوبون الخصم بيتأكدوا من السيرفر وقت إنشاء الطلب.',
                    style: TextStyle(fontSize: 11, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item['name']}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          _amount(item),
                          style: const TextStyle(
                            fontSize: 10,
                            color: MarketColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    money(item['total']),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
          const Divider(),
          _AmountLine('قيمة المنتجات', money(quote['subtotal'])),
          _AmountLine(
            'التوصيل',
            quote['free_delivery'] == true || shipping <= 0
                ? 'مجاني'
                : money(shipping),
          ),
          _AmountLine('إجمالي الطلب', money(quote['total'])),
          if (voucherAmount > 0)
            _AmountLine(
              'كوبون الخصم',
              '- ${money(voucherAmount)}',
              accent: true,
            ),
          const Divider(),
          _AmountLine('المطلوب دفعه', money(payableTotal), emphasized: true),
          const SizedBox(height: 10),
          _CopyRow(
            label: 'مرجع الطلب',
            value: reference,
            onCopy: onCopyReference,
          ),
        ],
      ),
    );
  }
}

class _AmountLine extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasized;
  final bool accent;
  const _AmountLine(
    this.label,
    this.value, {
    this.emphasized = false,
    this.accent = false,
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
              fontWeight: emphasized ? FontWeight.w800 : FontWeight.w500,
              color: accent ? MarketColors.primary : MarketColors.textPrimary,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: emphasized ? 17 : 13,
            fontWeight: emphasized ? FontWeight.w800 : FontWeight.w700,
            color: emphasized || accent
                ? MarketColors.primary
                : MarketColors.textPrimary,
          ),
        ),
      ],
    ),
  );
}

class _PendingNotice extends StatelessWidget {
  final bool canReset;
  final VoidCallback onReset;
  const _PendingNotice({required this.canReset, required this.onReset});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: MarketColors.warningSurface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: MarketColors.warning.withValues(alpha: .24)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.refresh_rounded, color: MarketColors.warning),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'في محاولة طلب سابقة محفوظة بأمان. هنكمل بنفس المرجع عشان مايتعملش طلب مكرر أو يتخصم الكوبون مرتين.',
                style: TextStyle(fontSize: 12, height: 1.55),
              ),
            ),
          ],
        ),
        if (canReset) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: onReset,
            child: const Text('إلغاء المحاولة ومراجعة الطلب من جديد'),
          ),
        ],
      ],
    ),
  );
}

class _ErrorCard extends StatelessWidget {
  final String messageText;
  final VoidCallback onRetry;
  final VoidCallback? onReset;
  const _ErrorCard({
    required this.messageText,
    required this.onRetry,
    this.onReset,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: MarketColors.errorSurface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: MarketColors.error.withValues(alpha: .2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: MarketColors.error),
            const SizedBox(width: 8),
            Expanded(child: Text(messageText)),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: onRetry, child: const Text('إعادة المراجعة')),
        if (onReset != null)
          TextButton(onPressed: onReset, child: const Text('بدء مراجعة جديدة')),
      ],
    ),
  );
}

class _CoveredByVoucher extends StatelessWidget {
  const _CoveredByVoucher();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: MarketColors.successSurface,
      borderRadius: BorderRadius.circular(16),
    ),
    child: const Text(
      'مش مطلوب دفع إضافي. كوبون الخصم يغطي كامل قيمة الطلب.',
      style: TextStyle(
        color: MarketColors.primary,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _CopyRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onCopy;
  const _CopyRow({
    required this.label,
    required this.value,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: MarketColors.surfaceSecondary,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: MarketColors.divider),
    ),
    child: Row(
      children: [
        Expanded(
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
              SelectableText(
                value,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onCopy,
          tooltip: 'نسخ',
          icon: const Icon(Icons.copy_rounded, size: 20),
        ),
      ],
    ),
  );
}

class _WalletAmountCard extends StatelessWidget {
  final double amount;
  final double discount;
  const _WalletAmountCard({required this.amount, required this.discount});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: MarketColors.primarySurface,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      children: [
        const Text('المبلغ المطلوب'),
        const SizedBox(height: 3),
        Text(
          money(amount),
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: MarketColors.primary,
          ),
        ),
        if (discount > 0)
          Text(
            'بعد خصم ${money(discount)} بالكوبون',
            style: const TextStyle(fontSize: 11, color: MarketColors.primary),
          ),
      ],
    ),
  );
}

class _SuccessSummary extends StatelessWidget {
  final JsonMap order;
  final double amountDue;
  const _SuccessSummary({required this.order, required this.amountDue});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: MarketColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: MarketColors.divider),
    ),
    child: Column(
      children: [
        _AmountLine('إجمالي الطلب', money(order['total'])),
        if (number(order['loyalty_voucher_amount']) > 0)
          _AmountLine(
            'كوبون الخصم',
            '- ${money(order['loyalty_voucher_amount'])}',
            accent: true,
          ),
        _AmountLine('المطلوب دفعه', money(amountDue), emphasized: true),
        const Divider(),
        _AmountLine(
          'حالة الدفع',
          statusLabels['${order['payment_status']}'] ??
              ('${order['payment_status']}'.isEmpty
                  ? 'بانتظار الدفع'
                  : '${order['payment_status']}'),
        ),
      ],
    ),
  );
}
