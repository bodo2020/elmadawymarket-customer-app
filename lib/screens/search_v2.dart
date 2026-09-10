import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/design.dart';
import '../core/ui.dart';
import 'catalog.dart';

class SearchV2Page extends StatefulWidget {
  final String initialQuery;
  const SearchV2Page({super.key, this.initialQuery = ''});

  @override
  State<SearchV2Page> createState() => _SearchV2PageState();
}

class _SearchV2PageState extends State<SearchV2Page> {
  final controller = TextEditingController();
  final focusNode = FocusNode();
  Timer? timer;
  String query = '';
  String sort = 'relevance';
  bool onlyAvailable = false;
  bool onlyOffers = false;
  int revision = 0;
  List<String> recent = const [];

  @override
  void initState() {
    super.initState();
    query = widget.initialQuery.trim();
    controller.text = query;
    _loadRecent();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && query.isEmpty) {
        focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    controller.dispose();
    focusNode.dispose();
    super.dispose();
  }

  void _loadRecent() {
    try {
      final raw = market.prefs.getString('recent-searches-v2');
      if (raw == null) {
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        recent = decoded
            .whereType<String>()
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .take(5)
            .toList(growable: false);
      }
    } catch (_) {
      recent = const [];
    }
  }

  Future<void> _remember(String value) async {
    final clean = value.trim();
    if (clean.isEmpty) {
      return;
    }
    final next = [
      clean,
      ...recent.where((item) => item != clean),
    ].take(5).toList(growable: false);
    recent = next;
    await market.prefs.setString('recent-searches-v2', jsonEncode(next));
  }

  Future<void> _clearRecent() async {
    await market.prefs.remove('recent-searches-v2');
    if (mounted) {
      setState(() => recent = const []);
    }
  }

  void _schedule(String value) {
    timer?.cancel();
    setState(() {});
    timer = Timer(const Duration(milliseconds: 350), () => _apply(value));
  }

  void _apply(String value) {
    final clean = value.trim();
    if (query == clean) {
      return;
    }
    setState(() {
      query = clean;
      revision++;
    });
    if (clean.isNotEmpty) {
      unawaited(_remember(clean));
    }
  }

  Future<List<Product>> _load() async {
    return market.catalog(
      filters: {
        'p_limit': query.isEmpty ? 24 : 250,
        if (query.isNotEmpty) 'p_search': query,
      },
    );
  }

  List<Product> _visible(List<Product> source) {
    final products = source.where((product) {
      if (onlyAvailable && product.maxQuantity(false) <= 0) {
        return false;
      }
      final original = number(product.data['price']);
      final offer = number(product.data['offer_price']);
      if (onlyOffers && !(offer > 0 && offer < original)) {
        return false;
      }
      return true;
    }).toList();

    if (sort == 'low') {
      products.sort((a, b) => a.unitPrice(false).compareTo(b.unitPrice(false)));
    } else if (sort == 'high') {
      products.sort((a, b) => b.unitPrice(false).compareTo(a.unitPrice(false)));
    }
    return products;
  }

  void _useRecent(String value) {
    controller.text = value;
    controller.selection = TextSelection.collapsed(offset: value.length);
    _apply(value);
  }

  @override
  Widget build(BuildContext context) => PageFrame(
        'البحث',
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                textInputAction: TextInputAction.search,
                onChanged: _schedule,
                onSubmitted: _apply,
                decoration: InputDecoration(
                  hintText: 'دور باسم المنتج أو العلامة التجارية',
                  fillColor: MarketColors.surfaceSecondary,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIconConstraints: const BoxConstraints(minWidth: 92),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (controller.text.isNotEmpty)
                        IconButton(
                          tooltip: 'مسح البحث',
                          onPressed: () {
                            controller.clear();
                            _apply('');
                            focusNode.requestFocus();
                          },
                          icon: const Icon(Icons.close_rounded, size: 19),
                        ),
                      IconButton(
                        tooltip: 'البحث بالباركود',
                        onPressed: () => open(context, const ScannerPage()),
                        icon: const Icon(
                          Icons.qr_code_scanner_rounded,
                          color: MarketColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (query.isEmpty && recent.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'آخر عمليات البحث',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        TextButton(
                          onPressed: _clearRecent,
                          child: const Text('مسح الكل'),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: recent
                          .map(
                            (value) => ActionChip(
                              avatar: const Icon(Icons.history_rounded, size: 16),
                              label: Text(value),
                              onPressed: () => _useRecent(value),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
              child: LayoutBuilder(
                builder: (context, box) {
                  final filters = Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      FilterChip(
                        selected: onlyAvailable,
                        avatar: const Icon(Icons.inventory_2_outlined, size: 16),
                        label: const Text('المتاح فقط'),
                        onSelected: (value) => setState(() {
                          onlyAvailable = value;
                        }),
                      ),
                      FilterChip(
                        selected: onlyOffers,
                        avatar: const Icon(Icons.local_offer_outlined, size: 16),
                        label: const Text('العروض فقط'),
                        onSelected: (value) => setState(() {
                          onlyOffers = value;
                        }),
                      ),
                    ],
                  );
                  final sorter = DropdownButton<String>(
                    value: sort,
                    underline: const SizedBox.shrink(),
                    borderRadius: BorderRadius.circular(14),
                    items: const [
                      DropdownMenuItem(
                        value: 'relevance',
                        child: Text('الأقرب للبحث'),
                      ),
                      DropdownMenuItem(
                        value: 'low',
                        child: Text('الأقل سعرًا'),
                      ),
                      DropdownMenuItem(
                        value: 'high',
                        child: Text('الأعلى سعرًا'),
                      ),
                    ],
                    onChanged: (value) => setState(() => sort = value!),
                  );
                  if (box.maxWidth < 430 ||
                      MediaQuery.textScalerOf(context).scale(14) > 20) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        filters,
                        const SizedBox(height: 8),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: sorter,
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: filters),
                      const SizedBox(width: 8),
                      sorter,
                    ],
                  );
                },
              ),
            ),
            Expanded(
              child: LoadView<List<Product>>(
                key: ValueKey('$revision:$onlyAvailable:$onlyOffers:$sort'),
                load: _load,
                builder: (source) {
                  final products = _visible(source);
                  if (products.isEmpty) {
                    return EmptyView(
                      query.isEmpty
                          ? 'مفيش منتجات مقترحة حاليًا'
                          : 'مفيش نتائج لـ «$query»',
                      actionLabel: 'مسح الفلاتر',
                      onAction: () => setState(() {
                        onlyAvailable = false;
                        onlyOffers = false;
                      }),
                    );
                  }

                  final cards = <({Product product, bool bulk})>[];
                  for (final product in products) {
                    cards.add((product: product, bulk: false));
                    if (product.bulk) {
                      cards.add((product: product, bulk: true));
                    }
                  }

                  return CustomScrollView(
                    key: PageStorageKey('search-v2-$query'),
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
                        sliver: SliverToBoxAdapter(
                          child: Text(
                            query.isEmpty
                                ? 'منتجات مقترحة ليك'
                                : '${products.length} نتيجة',
                            style: const TextStyle(
                              fontSize: 13,
                              color: MarketColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(12, 6, 12, 28),
                        sliver: SliverGrid(
                          gridDelegate: productGrid(context),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final card = cards[index];
                              return ProductCard(
                                card.product,
                                bulk: card.bulk,
                              );
                            },
                            childCount: cards.length,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      );
}
