import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../core/design.dart';
import '../core/ui.dart';

String formatWeightV2(int grams) {
  if (grams >= 1000) {
    final kg = grams / 1000;
    final digits = grams % 1000 == 0 ? 0 : (grams % 100 == 0 ? 1 : 2);
    return '${kg.toStringAsFixed(digits)} كجم';
  }
  return '$grams جم';
}

String _normalizeDigitsV2(String value) {
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  const persian = '۰۱۲۳۴۵۶۷۸۹';
  final out = StringBuffer();
  for (final rune in value.runes) {
    final char = String.fromCharCode(rune);
    final ai = arabic.indexOf(char);
    final pi = persian.indexOf(char);
    if (ai >= 0) {
      out.write(ai);
    } else if (pi >= 0) {
      out.write(pi);
    } else {
      out.write(char);
    }
  }
  return out.toString();
}

class CustomerFavoritesV2 extends ChangeNotifier {
  String? _customerId;
  bool _loaded = false;
  Future<void>? _loading;
  Set<String> _items = <String>{};

  String _key(String productId, String? variantId) =>
      '$productId:${variantId ?? 'regular'}';

  Future<void> ensureLoaded() async {
    final customerId = market.profile?['id']?.toString();
    if (customerId == null || market.user == null) {
      if (_customerId != null || _items.isNotEmpty || _loaded) {
        _customerId = null;
        _loaded = false;
        _items = <String>{};
        notifyListeners();
      }
      return;
    }
    if (_customerId == customerId && _loaded) return;
    if (_customerId == customerId && _loading != null) return _loading!;

    _customerId = customerId;
    _loaded = false;
    final task = () async {
      final data = await market.db
          .from('favorites')
          .select('product_id,variant_id')
          .eq('customer_id', customerId);
      if (_customerId != customerId) return;
      _items = data
          .map(
            (row) =>
                _key('${row['product_id']}', row['variant_id']?.toString()),
          )
          .toSet();
      _loaded = true;
      notifyListeners();
    }();
    _loading = task;
    try {
      await task;
    } finally {
      if (identical(_loading, task)) _loading = null;
    }
  }

  bool contains(Product product, bool bulk) {
    if (!_loaded || market.user == null) return false;
    return _items.contains(
      _key(
        product.id,
        bulk ? product.data['bulk_variant_id']?.toString() : null,
      ),
    );
  }

  bool get loaded => _loaded;

  Future<void> toggle(Product product, bool bulk) async {
    if (market.user == null) return;
    await ensureLoaded();
    final variantId = bulk ? product.data['bulk_variant_id']?.toString() : null;
    final key = _key(product.id, variantId);
    final selected = _items.contains(key);
    await market.favorite(product, bulk, !selected);
    if (_customerId != market.profile?['id']?.toString()) return;
    if (selected) {
      _items.remove(key);
    } else {
      _items.add(key);
    }
    notifyListeners();
  }
}

final customerFavoritesV2 = CustomerFavoritesV2();

class ProductFavoriteButtonV2 extends StatefulWidget {
  final Product product;
  final bool bulk;
  final double size;
  const ProductFavoriteButtonV2({
    super.key,
    required this.product,
    required this.bulk,
    this.size = 20,
  });

  @override
  State<ProductFavoriteButtonV2> createState() =>
      _ProductFavoriteButtonV2State();
}

class _ProductFavoriteButtonV2State extends State<ProductFavoriteButtonV2> {
  bool busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(customerFavoritesV2.ensureLoaded());
    });
  }

  @override
  Widget build(BuildContext context) {
    if (market.user == null) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: customerFavoritesV2,
      builder: (context, _) {
        final selected = customerFavoritesV2.contains(
          widget.product,
          widget.bulk,
        );
        return IconButton(
          tooltip: selected ? 'إزالة من المفضلة' : 'إضافة إلى المفضلة',
          onPressed: busy
              ? null
              : () async {
                  setState(() => busy = true);
                  final ok = await perform(
                    context,
                    () =>
                        customerFavoritesV2.toggle(widget.product, widget.bulk),
                  );
                  if (mounted) setState(() => busy = false);
                  if (ok && context.mounted) {
                    message(
                      context,
                      selected ? 'اتشال من المفضلة' : 'اتحفظ في المفضلة',
                    );
                  }
                },
          icon: busy && !customerFavoritesV2.loaded
              ? SizedBox(
                  width: widget.size,
                  height: widget.size,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                )
              : AnimatedSwitcher(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  child: Icon(
                    selected
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    key: ValueKey(selected),
                    size: widget.size,
                    color: selected
                        ? MarketColors.success
                        : MarketColors.textTertiary,
                  ),
                ),
        );
      },
    );
  }
}

Future<int?> showWeightSelectorV2(
  BuildContext context, {
  required Product product,
  required int initialWeight,
}) async {
  final max = product.maxQuantity(false).clamp(0, 100000);
  final step = product.step;
  final start = initialWeight.clamp(1, max > 0 ? max : 1);
  final controller = TextEditingController(text: '$start');
  final presets = <int>{
    step,
    step * 2,
    step * 5,
    step * 10,
  }.where((value) => value > 0 && value <= max).take(4).toList();

  final result = await showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: MarketColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) {
        final amount =
            int.tryParse(
              _normalizeDigitsV2(controller.text).replaceAll(RegExp(r'\D'), ''),
            ) ??
            0;
        final valid = amount > 0 && max > 0 && amount <= max;
        final price = valid ? product.unitPrice(false) * amount / 1000 : 0.0;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            12,
            18,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: MarketColors.borderStrong,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'تحب وزن قد إيه؟',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '${product.name} · ${money(product.unitPrice(false))} للكيلو · خطوة الزيادة ${formatWeightV2(step)}',
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.6,
                    color: MarketColors.textSecondary,
                  ),
                ),
                if (presets.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: presets
                        .map(
                          (value) => ChoiceChip(
                            selected: amount == value,
                            label: Text(formatWeightV2(value)),
                            onSelected: (_) {
                              controller.text = '$value';
                              setSheetState(() {});
                            },
                          ),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: 18),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  textDirection: TextDirection.ltr,
                  onChanged: (_) => setSheetState(() {}),
                  decoration: InputDecoration(
                    labelText: 'الوزن بالجرام',
                    hintText: '$step',
                    errorText: controller.text.isNotEmpty && !valid
                        ? max <= 0
                              ? 'المنتج غير متاح بالوزن حاليًا'
                              : 'اكتب وزن من 1 جم إلى ${formatWeightV2(max)}'
                        : null,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'تقدر تكتب أي وزن مناسب داخل الكمية المتاحة، ومش لازم يكون من مضاعفات خطوة الزيادة.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.55,
                    color: MarketColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: MarketColors.primarySurface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Expanded(child: Text('قيمة الكمية')),
                      Text(
                        valid ? money(price) : '—',
                        style: const TextStyle(
                          color: MarketColors.primary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: valid
                      ? () => Navigator.of(sheetContext).pop(amount)
                      : null,
                  child: const Text('تأكيد الوزن'),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
  controller.dispose();
  return result;
}

double productCardV2Height(BuildContext context) =>
    372 + (MediaQuery.textScalerOf(context).scale(14) - 14).clamp(0, 18) * 14;

SliverGridDelegate productGridV2(BuildContext context) =>
    SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: MediaQuery.textScalerOf(context).scale(14) > 21
          ? 410
          : 240,
      mainAxisExtent: productCardV2Height(context),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
    );

class ProductCardV2 extends StatefulWidget {
  final Product product;
  final bool bulk;
  const ProductCardV2(this.product, {super.key, this.bulk = false});

  @override
  State<ProductCardV2> createState() => _ProductCardV2State();
}

class _ProductCardV2State extends State<ProductCardV2> {
  late int draftWeight;

  @override
  void initState() {
    super.initState();
    draftWeight = widget.product.weighted ? widget.product.step : 1;
  }

  @override
  void didUpdateWidget(covariant ProductCardV2 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product.id != widget.product.id) {
      draftWeight = widget.product.weighted ? widget.product.step : 1;
    }
  }

  Future<void> _editWeight(CartLine? line) async {
    final selected = await showWeightSelectorV2(
      context,
      product: widget.product,
      initialWeight: line?.quantity ?? draftWeight,
    );
    if (!mounted || selected == null) return;
    if (line != null) {
      await perform(
        context,
        () => market.changeCart(widget.product, selected, bulk: false),
      );
    } else {
      setState(() => draftWeight = selected);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: market,
    builder: (context, _) {
      final p = widget.product;
      final bulk = widget.bulk && p.bulk;
      final key = CartLine(p, 1, bulk: bulk).key;
      final line = market.cart.where((item) => item.key == key).firstOrNull;
      final stockMax = p.maxQuantity(bulk);
      final unavailable = stockMax <= 0 || (widget.bulk && !p.bulk);
      final selectedWeight = p.weighted
          ? (line?.quantity ?? draftWeight).clamp(
              1,
              stockMax > 0 ? stockMax : 1,
            )
          : 0;
      final originalPrice = bulk ? 0.0 : number(p.data['price']);
      final offerPrice = bulk ? 0.0 : number(p.data['offer_price']);
      final hasOffer = offerPrice > 0 && offerPrice < originalPrice;
      final discount = hasOffer
          ? ((originalPrice - offerPrice) / originalPrice * 100).round()
          : 0;
      final shownPrice = p.weighted
          ? p.unitPrice(false) * selectedWeight / 1000
          : p.unitPrice(bulk);
      final originalShownPrice = p.weighted
          ? originalPrice * selectedWeight / 1000
          : originalPrice;
      final pack = number(p.data['bulk_quantity']).round().clamp(1, 999999);
      final bulkType = '${p.data['bulk_variant_type'] ?? ''}'.trim().isEmpty
          ? 'جملة'
          : '${p.data['bulk_variant_type']}';
      final image = p.picture(bulk).trim();

      return Card(
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () =>
                            open(context, ProductPageV2(p.id, bulk: bulk)),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: bulk && image.isEmpty
                                ? MarketColors.primarySurface
                                : MarketColors.surfaceSecondary,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: bulk && image.isEmpty
                              ? _BulkPlaceholderV2(pack: pack)
                              : photo(image),
                        ),
                      ),
                    ),
                    if (hasOffer)
                      PositionedDirectional(
                        top: 6,
                        start: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: MarketColors.discountSurface,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(
                            'خصم $discount٪',
                            style: const TextStyle(
                              color: MarketColors.discount,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    PositionedDirectional(
                      top: 2,
                      end: 2,
                      child: DecoratedBox(
                        decoration: const BoxDecoration(
                          color: Color(0xf7ffffff),
                          shape: BoxShape.circle,
                        ),
                        child: ProductFavoriteButtonV2(
                          product: p,
                          bulk: bulk,
                          size: 19,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => open(context, ProductPageV2(p.id, bulk: bulk)),
                child: Text(
                  p.title(bulk),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    p.weighted
                        ? Icons.scale_outlined
                        : bulk
                        ? Icons.inventory_2_outlined
                        : Icons.sell_outlined,
                    size: 14,
                    color: MarketColors.textTertiary,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      p.weighted
                          ? 'بالوزن'
                          : bulk
                          ? '$bulkType · $pack قطعة'
                          : 'سعر القطعة',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: MarketColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.end,
                spacing: 6,
                runSpacing: 2,
                children: [
                  Text(
                    money(shownPrice),
                    style: const TextStyle(
                      color: MarketColors.primary,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (p.weighted)
                    Text(
                      '/ ${formatWeightV2(selectedWeight)}',
                      style: const TextStyle(
                        color: MarketColors.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  if (hasOffer)
                    Text(
                      money(originalShownPrice),
                      style: const TextStyle(
                        color: MarketColors.textTertiary,
                        fontSize: 10,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (unavailable)
                const FilledButton(
                  onPressed: null,
                  child: Text('غير متاح حاليًا'),
                )
              else if (p.weighted)
                _WeightedCardControlV2(
                  product: p,
                  line: line,
                  selectedWeight: selectedWeight,
                  onEdit: () => _editWeight(line),
                  onDraftChanged: (value) {
                    if (mounted) setState(() => draftWeight = value);
                  },
                )
              else
                _PieceCardControlV2(product: p, bulk: bulk, line: line),
            ],
          ),
        ),
      );
    },
  );
}

class _BulkPlaceholderV2 extends StatelessWidget {
  final int pack;
  const _BulkPlaceholderV2({required this.pack});

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 88,
      height: 88,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: MarketColors.primary,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24005931),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Text(
        '$pack',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 34,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );
}

class _PieceCardControlV2 extends StatelessWidget {
  final Product product;
  final bool bulk;
  final CartLine? line;
  const _PieceCardControlV2({
    required this.product,
    required this.bulk,
    required this.line,
  });

  @override
  Widget build(BuildContext context) {
    if (line == null) {
      return FilledButton.icon(
        onPressed: market.saving
            ? null
            : () => perform(
                context,
                () => market.add(product, bulk: bulk),
                success: 'اتضاف للسلة',
              ),
        icon: const Icon(Icons.add_rounded, size: 18),
        label: const Text('إضافة للسلة'),
      );
    }
    final max = product.maxQuantity(bulk);
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      decoration: BoxDecoration(
        color: MarketColors.primarySurface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: line!.quantity <= 1 ? 'حذف من السلة' : 'تقليل الكمية',
            onPressed: market.saving
                ? null
                : () => perform(
                    context,
                    () => market.changeCart(
                      product,
                      line!.quantity <= 1 ? 0 : line!.quantity - 1,
                      bulk: bulk,
                    ),
                  ),
            icon: Icon(
              line!.quantity <= 1
                  ? Icons.delete_outline_rounded
                  : Icons.remove_rounded,
              size: 18,
            ),
          ),
          Expanded(
            child: Text(
              '${line!.quantity}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: MarketColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            tooltip: line!.quantity >= max ? 'وصلت للكمية المتاحة' : 'زيادة',
            onPressed: market.saving || line!.quantity >= max
                ? null
                : () => perform(context, () => market.add(product, bulk: bulk)),
            icon: const Icon(Icons.add_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

class _WeightedCardControlV2 extends StatelessWidget {
  final Product product;
  final CartLine? line;
  final int selectedWeight;
  final VoidCallback onEdit;
  final ValueChanged<int> onDraftChanged;
  const _WeightedCardControlV2({
    required this.product,
    required this.line,
    required this.selectedWeight,
    required this.onEdit,
    required this.onDraftChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (line == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 38,
            child: OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.scale_outlined, size: 16),
              label: Text(formatWeightV2(selectedWeight)),
            ),
          ),
          const SizedBox(height: 6),
          FilledButton.icon(
            onPressed: market.saving
                ? null
                : () => perform(
                    context,
                    () => market.add(product, quantity: selectedWeight),
                    success: 'اتضاف للسلة',
                  ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('إضافة للسلة'),
          ),
        ],
      );
    }
    final step = product.step;
    final max = product.maxQuantity(false);
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      decoration: BoxDecoration(
        color: MarketColors.primarySurface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: selectedWeight <= step ? 'حذف من السلة' : 'تقليل الوزن',
            onPressed: market.saving
                ? null
                : () => perform(
                    context,
                    () => market.changeCart(
                      product,
                      selectedWeight <= step
                          ? 0
                          : (selectedWeight - step).clamp(1, max),
                    ),
                  ),
            icon: Icon(
              selectedWeight <= step
                  ? Icons.delete_outline_rounded
                  : Icons.remove_rounded,
              size: 18,
            ),
          ),
          Expanded(
            child: TextButton(
              onPressed: onEdit,
              child: Text(
                formatWeightV2(selectedWeight),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          IconButton(
            tooltip: selectedWeight >= max
                ? 'وصلت للوزن المتاح'
                : 'زيادة الوزن',
            onPressed: market.saving || selectedWeight >= max
                ? null
                : () => perform(
                    context,
                    () => market.changeCart(
                      product,
                      (selectedWeight + step).clamp(1, max),
                    ),
                  ),
            icon: const Icon(Icons.add_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

class ProductPageV2 extends StatelessWidget {
  final String id;
  final bool bulk;
  const ProductPageV2(this.id, {super.key, this.bulk = false});

  @override
  Widget build(BuildContext context) => PageFrame(
    bulk ? 'تفاصيل الجملة' : 'تفاصيل المنتج',
    LoadView<List<Product>>(
      load: () => market.catalog(filters: {'p_product_id': id}),
      builder: (items) {
        if (items.isEmpty) {
          return const EmptyView('المنتج غير متاح في فرعك');
        }
        final product = items.first;
        if (bulk && !product.bulk) {
          return const EmptyView('وحدة الجملة مش متاحة حاليًا');
        }
        return ProductDetailsV2(product, initialBulk: bulk);
      },
    ),
  );
}

class ProductDetailsV2 extends StatefulWidget {
  final Product product;
  final bool initialBulk;
  const ProductDetailsV2(this.product, {super.key, required this.initialBulk});

  @override
  State<ProductDetailsV2> createState() => _ProductDetailsV2State();
}

class _ProductDetailsV2State extends State<ProductDetailsV2> {
  late bool bulk;
  int selectedImage = 0;
  int draftQuantity = 1;
  late int draftWeight;

  @override
  void initState() {
    super.initState();
    bulk = widget.initialBulk && widget.product.bulk;
    draftWeight = widget.product.weighted ? widget.product.step : 1;
  }

  CartLine? _line(bool currentBulk) {
    final key = CartLine(widget.product, 1, bulk: currentBulk).key;
    return market.cart.where((item) => item.key == key).firstOrNull;
  }

  List<String> _images() {
    if (bulk) {
      final image = '${widget.product.data['bulk_image_url'] ?? ''}'.trim();
      return image.isEmpty ? const [] : [image];
    }
    final raw = widget.product.data['image_urls'];
    if (raw is! List) return const [];
    return raw.map((e) => '$e'.trim()).where((e) => e.isNotEmpty).toList();
  }

  void _setBulk(bool value) {
    setState(() {
      bulk = value && widget.product.bulk;
      selectedImage = 0;
      draftQuantity = 1;
    });
    unawaited(customerFavoritesV2.ensureLoaded());
  }

  Future<void> _selectWeight(CartLine? line) async {
    final selected = await showWeightSelectorV2(
      context,
      product: widget.product,
      initialWeight: line?.quantity ?? draftWeight,
    );
    if (!mounted || selected == null) return;
    if (line != null) {
      await perform(context, () => market.changeCart(widget.product, selected));
    } else {
      setState(() => draftWeight = selected);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: market,
    builder: (context, _) {
      final p = widget.product;
      final line = _line(bulk);
      final max = p.maxQuantity(bulk);
      final images = _images();
      final selectedWeight = p.weighted
          ? (line?.quantity ?? draftWeight).clamp(1, max > 0 ? max : 1)
          : 0;
      final original = bulk ? 0.0 : number(p.data['price']);
      final offer = bulk ? 0.0 : number(p.data['offer_price']);
      final hasOffer = offer > 0 && offer < original;
      final price = p.weighted
          ? p.unitPrice(false) * selectedWeight / 1000
          : p.unitPrice(bulk);
      final originalPrice = p.weighted
          ? original * selectedWeight / 1000
          : original;
      final pack = number(p.data['bulk_quantity']).round().clamp(1, 999999);
      final bulkType = '${p.data['bulk_variant_type'] ?? ''}'.trim().isEmpty
          ? 'جملة'
          : '${p.data['bulk_variant_type']}';
      final description = '${p.data['description'] ?? ''}'.trim();

      return LayoutBuilder(
        builder: (context, box) {
          final wide = box.maxWidth >= 740;
          final gallery = _ProductGalleryV2(
            product: p,
            bulk: bulk,
            pack: pack,
            images: images,
            selected: selectedImage,
            onSelected: (value) => setState(() => selectedImage = value),
          );
          final purchase = _ProductPurchasePanelV2(
            product: p,
            bulk: bulk,
            bulkType: bulkType,
            pack: pack,
            line: line,
            max: max,
            price: price,
            originalPrice: originalPrice,
            hasOffer: hasOffer,
            selectedWeight: selectedWeight,
            draftQuantity: draftQuantity,
            onDraftQuantity: (value) => setState(() => draftQuantity = value),
            onWeight: () => _selectWeight(line),
          );
          return ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
            children: [
              if (p.bulk && !p.weighted) ...[
                SegmentedButton<bool>(
                  segments: [
                    const ButtonSegment<bool>(
                      value: false,
                      icon: Icon(Icons.sell_outlined),
                      label: Text('بالقطعة'),
                    ),
                    ButtonSegment<bool>(
                      value: true,
                      icon: const Icon(Icons.inventory_2_outlined),
                      label: Text('$bulkType · $pack قطعة'),
                    ),
                  ],
                  selected: {bulk},
                  onSelectionChanged: (value) => _setBulk(value.first),
                ),
                const SizedBox(height: 14),
              ],
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: gallery),
                    const SizedBox(width: 14),
                    Expanded(child: purchase),
                  ],
                )
              else ...[
                gallery,
                const SizedBox(height: 14),
                purchase,
              ],
              if (description.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
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
                        'عن المنتج',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: const TextStyle(
                          height: 1.8,
                          color: MarketColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              const Text(
                'منتجات ذات صلة',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: productCardV2Height(context),
                child: LoadView<List<Product>>(
                  load: () => market.catalog(
                    filters: {
                      'p_main_category_id': p.data['main_category_id'],
                      'p_limit': 12,
                    },
                  ),
                  builder: (related) {
                    final visible = related
                        .where((item) => item.id != p.id)
                        .take(6)
                        .toList();
                    if (visible.isEmpty) return const SizedBox.shrink();
                    return ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: visible.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (_, index) => SizedBox(
                        width: 190,
                        child: ProductCardV2(visible[index]),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

class _ProductGalleryV2 extends StatelessWidget {
  final Product product;
  final bool bulk;
  final int pack;
  final List<String> images;
  final int selected;
  final ValueChanged<int> onSelected;
  const _ProductGalleryV2({
    required this.product,
    required this.bulk,
    required this.pack,
    required this.images,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: MarketColors.surface,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: MarketColors.divider),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: bulk && images.isEmpty
                        ? MarketColors.primarySurface
                        : MarketColors.surfaceSecondary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: bulk && images.isEmpty
                      ? _BulkPlaceholderV2(pack: pack)
                      : photo(
                          images.isEmpty
                              ? ''
                              : images[selected.clamp(0, images.length - 1)],
                        ),
                ),
              ),
              PositionedDirectional(
                top: 8,
                end: 8,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: Color(0xf7ffffff),
                    shape: BoxShape.circle,
                  ),
                  child: ProductFavoriteButtonV2(
                    product: product,
                    bulk: bulk,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!bulk && images.length > 1) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 66,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, index) => InkWell(
                onTap: () => onSelected(index),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 66,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: MarketColors.surfaceSecondary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected == index
                          ? MarketColors.primary
                          : MarketColors.border,
                      width: selected == index ? 2 : 1,
                    ),
                  ),
                  child: photo(images[index]),
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

class _ProductPurchasePanelV2 extends StatelessWidget {
  final Product product;
  final bool bulk;
  final String bulkType;
  final int pack;
  final CartLine? line;
  final int max;
  final double price;
  final double originalPrice;
  final bool hasOffer;
  final int selectedWeight;
  final int draftQuantity;
  final ValueChanged<int> onDraftQuantity;
  final VoidCallback onWeight;
  const _ProductPurchasePanelV2({
    required this.product,
    required this.bulk,
    required this.bulkType,
    required this.pack,
    required this.line,
    required this.max,
    required this.price,
    required this.originalPrice,
    required this.hasOffer,
    required this.selectedWeight,
    required this.draftQuantity,
    required this.onDraftQuantity,
    required this.onWeight,
  });

  @override
  Widget build(BuildContext context) {
    final p = product;
    final unitLabel = p.weighted
        ? 'بالميزان'
        : bulk
        ? bulkType
        : 'بالقطعة';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: MarketColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: MarketColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  p.title(bulk),
                  style: const TextStyle(
                    fontSize: 24,
                    height: 1.45,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: MarketColors.primarySurface,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      p.weighted
                          ? Icons.scale_outlined
                          : bulk
                          ? Icons.inventory_2_outlined
                          : Icons.sell_outlined,
                      size: 15,
                      color: MarketColors.primary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      unitLabel,
                      style: const TextStyle(
                        color: MarketColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (bulk) ...[
            const SizedBox(height: 5),
            Text(
              '$bulkType · $pack قطعة',
              style: const TextStyle(color: MarketColors.textSecondary),
            ),
          ] else if (!p.weighted) ...[
            const SizedBox(height: 5),
            const Text(
              'اختار الكمية المناسبة ليك',
              style: TextStyle(color: MarketColors.textSecondary),
            ),
          ],
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: MarketColors.primarySurface,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (hasOffer)
                  Text(
                    money(originalPrice),
                    style: const TextStyle(
                      color: MarketColors.textTertiary,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 7,
                  children: [
                    Text(
                      money(price),
                      style: const TextStyle(
                        color: MarketColors.primary,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (p.weighted)
                      Text(
                        '/ ${formatWeightV2(selectedWeight)}',
                        style: const TextStyle(
                          color: MarketColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (max <= 0)
            const FilledButton(onPressed: null, child: Text('غير متاح حاليًا'))
          else if (p.weighted)
            _WeightedDetailControlV2(
              product: p,
              line: line,
              selectedWeight: selectedWeight,
              onWeight: onWeight,
            )
          else
            _PieceDetailControlV2(
              product: p,
              bulk: bulk,
              line: line,
              draftQuantity: draftQuantity.clamp(1, max),
              max: max,
              onDraftQuantity: onDraftQuantity,
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => openShellTab(context, 2),
            icon: const Icon(Icons.shopping_cart_outlined, size: 18),
            label: const Text('مراجعة السلة ومتابعة الطلب'),
          ),
        ],
      ),
    );
  }
}

class _PieceDetailControlV2 extends StatelessWidget {
  final Product product;
  final bool bulk;
  final CartLine? line;
  final int draftQuantity;
  final int max;
  final ValueChanged<int> onDraftQuantity;
  const _PieceDetailControlV2({
    required this.product,
    required this.bulk,
    required this.line,
    required this.draftQuantity,
    required this.max,
    required this.onDraftQuantity,
  });

  @override
  Widget build(BuildContext context) {
    if (line != null) {
      return Container(
        constraints: const BoxConstraints(minHeight: 58),
        decoration: BoxDecoration(
          color: MarketColors.primarySurface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: line!.quantity <= 1 ? 'حذف من السلة' : 'تقليل',
              onPressed: market.saving
                  ? null
                  : () => perform(
                      context,
                      () => market.changeCart(
                        product,
                        line!.quantity <= 1 ? 0 : line!.quantity - 1,
                        bulk: bulk,
                      ),
                    ),
              icon: Icon(
                line!.quantity <= 1
                    ? Icons.delete_outline_rounded
                    : Icons.remove_rounded,
              ),
            ),
            Expanded(
              child: Text(
                '${line!.quantity} ${bulk ? 'عبوة' : 'قطعة'}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: MarketColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              tooltip: line!.quantity >= max ? 'وصلت للكمية المتاحة' : 'زيادة',
              onPressed: market.saving || line!.quantity >= max
                  ? null
                  : () =>
                        perform(context, () => market.add(product, bulk: bulk)),
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          constraints: const BoxConstraints(minHeight: 56),
          decoration: BoxDecoration(
            border: Border.all(color: MarketColors.border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: 'تقليل',
                onPressed: draftQuantity > 1
                    ? () => onDraftQuantity(draftQuantity - 1)
                    : null,
                icon: const Icon(Icons.remove_rounded),
              ),
              Expanded(
                child: Text(
                  '$draftQuantity',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: draftQuantity >= max ? 'وصلت للكمية المتاحة' : 'زيادة',
                onPressed: draftQuantity < max
                    ? () => onDraftQuantity(draftQuantity + 1)
                    : null,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        FilledButton(
          onPressed: market.saving
              ? null
              : () => perform(
                  context,
                  () =>
                      market.add(product, bulk: bulk, quantity: draftQuantity),
                  success: 'اتضاف للسلة',
                ),
          child: Row(
            children: [
              const Icon(Icons.add_shopping_cart_rounded, size: 18),
              const SizedBox(width: 8),
              const Expanded(child: Text('إضافة للسلة')),
              Text(
                money(product.unitPrice(bulk) * draftQuantity),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WeightedDetailControlV2 extends StatelessWidget {
  final Product product;
  final CartLine? line;
  final int selectedWeight;
  final VoidCallback onWeight;
  const _WeightedDetailControlV2({
    required this.product,
    required this.line,
    required this.selectedWeight,
    required this.onWeight,
  });

  @override
  Widget build(BuildContext context) {
    final step = product.step;
    final max = product.maxQuantity(false);
    if (line == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            onPressed: onWeight,
            icon: const Icon(Icons.scale_outlined),
            label: Text('الوزن المختار: ${formatWeightV2(selectedWeight)}'),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: market.saving
                ? null
                : () => perform(
                    context,
                    () => market.add(product, quantity: selectedWeight),
                    success: 'اتضاف للسلة',
                  ),
            icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
            label: Text(
              'إضافة ${formatWeightV2(selectedWeight)} • ${money(product.unitPrice(false) * selectedWeight / 1000)}',
            ),
          ),
        ],
      );
    }

    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      decoration: BoxDecoration(
        color: MarketColors.primarySurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: selectedWeight <= step ? 'حذف من السلة' : 'تقليل الوزن',
            onPressed: market.saving
                ? null
                : () => perform(
                    context,
                    () => market.changeCart(
                      product,
                      selectedWeight <= step
                          ? 0
                          : (selectedWeight - step).clamp(1, max),
                    ),
                  ),
            icon: Icon(
              selectedWeight <= step
                  ? Icons.delete_outline_rounded
                  : Icons.remove_rounded,
            ),
          ),
          Expanded(
            child: TextButton(
              onPressed: onWeight,
              child: Text(
                formatWeightV2(selectedWeight),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          IconButton(
            tooltip: selectedWeight >= max
                ? 'وصلت للوزن المتاح'
                : 'زيادة الوزن',
            onPressed: market.saving || selectedWeight >= max
                ? null
                : () => perform(
                    context,
                    () => market.changeCart(
                      product,
                      (selectedWeight + step).clamp(1, max),
                    ),
                  ),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

typedef ProductUnitV2 = ({Product product, bool bulk});

class CatalogV2Page extends StatefulWidget {
  final String title;
  final JsonMap filters;
  final bool bulkOnly;
  final List<String>? productIds;
  const CatalogV2Page({
    super.key,
    required this.title,
    this.filters = const {},
    this.bulkOnly = false,
    this.productIds,
  });

  @override
  State<CatalogV2Page> createState() => _CatalogV2PageState();
}

class _CatalogV2PageState extends State<CatalogV2Page> {
  String sort = 'name';
  bool onlyAvailable = false;
  bool onlyOffers = false;

  Future<List<Product>> _load() async {
    if (widget.productIds != null) {
      return rows(
        await market.rpc('get_customer_branch_products_by_ids', {
          'p_branch_id': market.runtime?['delivery_branch_id'],
          'p_product_ids': widget.productIds,
        }),
      ).map(Product.new).toList();
    }
    return market.catalog(filters: widget.filters);
  }

  List<ProductUnitV2> _units(List<Product> products) {
    final units = <ProductUnitV2>[];
    for (final product in products) {
      if (!widget.bulkOnly) units.add((product: product, bulk: false));
      if (product.bulk) units.add((product: product, bulk: true));
    }
    units.removeWhere((unit) {
      if (widget.bulkOnly && !unit.bulk) {
        return true;
      }
      if (onlyAvailable && unit.product.maxQuantity(unit.bulk) <= 0)
        return true;
      if (onlyOffers) {
        if (unit.bulk) {
          return true;
        }
        final original = number(unit.product.data['price']);
        final offer = number(unit.product.data['offer_price']);
        if (!(offer > 0 && offer < original)) {
          return true;
        }
      }
      return false;
    });
    units.sort((a, b) {
      if (sort == 'low') {
        return a.product
            .unitPrice(a.bulk)
            .compareTo(b.product.unitPrice(b.bulk));
      }
      if (sort == 'high') {
        return b.product
            .unitPrice(b.bulk)
            .compareTo(a.product.unitPrice(a.bulk));
      }
      return a.product.title(a.bulk).compareTo(b.product.title(b.bulk));
    });
    return units;
  }

  @override
  Widget build(BuildContext context) => PageFrame(
    widget.title,
    Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: LayoutBuilder(
            builder: (context, box) {
              final chips = Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  FilterChip(
                    selected: onlyAvailable,
                    label: const Text('المتاح فقط'),
                    onSelected: (value) =>
                        setState(() => onlyAvailable = value),
                  ),
                  if (!widget.bulkOnly)
                    FilterChip(
                      selected: onlyOffers,
                      label: const Text('العروض فقط'),
                      onSelected: (value) => setState(() => onlyOffers = value),
                    ),
                ],
              );
              final dropdown = DropdownButton<String>(
                value: sort,
                underline: const SizedBox.shrink(),
                borderRadius: BorderRadius.circular(14),
                items: const [
                  DropdownMenuItem(value: 'name', child: Text('الاسم')),
                  DropdownMenuItem(value: 'low', child: Text('الأقل سعرًا')),
                  DropdownMenuItem(value: 'high', child: Text('الأعلى سعرًا')),
                ],
                onChanged: (value) => setState(() => sort = value!),
              );
              if (box.maxWidth < 430 ||
                  MediaQuery.textScalerOf(context).scale(14) > 20) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    chips,
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: dropdown,
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: chips),
                  const SizedBox(width: 8),
                  dropdown,
                ],
              );
            },
          ),
        ),
        Expanded(
          child: LoadView<List<Product>>(
            load: _load,
            builder: (products) {
              final units = _units(products);
              if (units.isEmpty) {
                return const EmptyView('مفيش منتجات مطابقة');
              }
              return GridView.builder(
                key: PageStorageKey('catalog-v2-${widget.title}'),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),
                gridDelegate: productGridV2(context),
                itemCount: units.length,
                itemBuilder: (_, index) => ProductCardV2(
                  units[index].product,
                  bulk: units[index].bulk,
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}

class CollectionsSectionV2 extends StatelessWidget {
  const CollectionsSectionV2({super.key});

  @override
  Widget build(BuildContext context) => LoadView<List<JsonMap>>(
    load: () async => await market.db
        .from('product_collections')
        .select()
        .eq('active', true)
        .order('position'),
    builder: (collections) => Column(
      children: collections
          .where(
            (collection) =>
                ((collection['products'] as List?) ?? []).isNotEmpty,
          )
          .map(
            (collection) => Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: LoadView<List<Product>>(
                load: () async => rows(
                  await market.rpc('get_customer_branch_products_by_ids', {
                    'p_branch_id': market.runtime?['delivery_branch_id'],
                    'p_product_ids': collection['products'],
                  }),
                ).map(Product.new).toList(),
                builder: (products) {
                  if (products.isEmpty) return const SizedBox.shrink();
                  final units = <ProductUnitV2>[
                    for (final product in products) ...[
                      (product: product, bulk: false),
                      if (product.bulk) (product: product, bulk: true),
                    ],
                  ];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: MarketColors.surface,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: MarketColors.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${collection['title'] ?? ''}',
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if ('${collection['description'] ?? ''}'
                            .trim()
                            .isNotEmpty)
                          Text(
                            '${collection['description']}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: MarketColors.textSecondary,
                            ),
                          ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: productCardV2Height(context),
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: units.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 10),
                            itemBuilder: (_, index) => SizedBox(
                              width: 190,
                              child: ProductCardV2(
                                units[index].product,
                                bulk: units[index].bulk,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          )
          .toList(),
    ),
  );
}

class ScannerV2Page extends StatefulWidget {
  const ScannerV2Page({super.key});

  @override
  State<ScannerV2Page> createState() => _ScannerV2PageState();
}

class _ScannerV2PageState extends State<ScannerV2Page> {
  final scanner = MobileScannerController();
  final code = TextEditingController();
  bool busy = false;

  @override
  void dispose() {
    scanner.dispose();
    code.dispose();
    super.dispose();
  }

  Future<void> _find(String value) async {
    final barcode = _normalizeDigitsV2(value).trim();
    if (busy || barcode.isEmpty) return;
    setState(() => busy = true);
    await scanner.stop();
    try {
      final found = await market.catalog(
        filters: {'p_barcode': barcode, 'p_limit': 1},
      );
      if (!mounted) return;
      if (found.isEmpty) {
        message(context, 'الباركود مش موجود في فرعك');
      } else {
        final product = found.first;
        await open(
          context,
          ProductPageV2(
            product.id,
            bulk: '${product.data['bulk_barcode'] ?? ''}' == barcode,
          ),
        );
      }
    } catch (error) {
      if (mounted) message(context, friendlyError(error));
    } finally {
      if (mounted) {
        setState(() => busy = false);
        await scanner.start();
      }
    }
  }

  @override
  Widget build(BuildContext context) => PageFrame(
    'مسح الباركود',
    Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: MobileScanner(
                  controller: scanner,
                  onDetect: (capture) {
                    final value = capture.barcodes.firstOrNull?.rawValue;
                    if (value != null) _find(value);
                  },
                  errorBuilder: (context, error) => const Center(
                    child: Text('تعذر فتح الكاميرا. اكتب الباركود بالأسفل'),
                  ),
                ),
              ),
              Center(
                child: IgnorePointer(
                  child: Container(
                    width: 250,
                    height: 150,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
              if (busy)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Color(0x55000000),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(18),
          child: TextField(
            controller: code,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.search,
            onSubmitted: _find,
            decoration: InputDecoration(
              labelText: 'أو اكتب الباركود',
              suffixIcon: IconButton(
                tooltip: 'بحث بالباركود',
                onPressed: () => _find(code.text),
                icon: const Icon(Icons.search_rounded),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
