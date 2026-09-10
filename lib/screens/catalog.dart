import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/design.dart';
import '../core/ui.dart';
import 'address.dart';
import 'auth.dart';

class StoreHome extends StatelessWidget {
  const StoreHome({super.key});
  @override
  Widget build(BuildContext context) => LoadView<List<JsonMap>>(
    load: () async => await market.db
        .from('banners')
        .select()
        .eq('active', true)
        .order('position'),
    builder: (banners) => LayoutBuilder(
      builder: (context, box) => ListView(
        padding: EdgeInsets.symmetric(
          horizontal: box.maxWidth > 1000 ? (box.maxWidth - 1000) / 2 + 16 : 16,
          vertical: 16,
        ),
        key: const PageStorageKey('store-home'),
        children: [
          const HomeWelcome(),
          Card(
            margin: const EdgeInsets.only(bottom: MarketSpace.xl),
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: MarketColors.primarySurface,
                  borderRadius: BorderRadius.circular(MarketRadius.medium),
                ),
                child: const Icon(
                  Icons.location_on_outlined,
                  color: MarketColors.primary,
                  size: 20,
                ),
              ),
              title: const Text(
                'التوصيل إلى',
                style: TextStyle(
                  fontSize: 12,
                  color: MarketColors.textSecondary,
                ),
              ),
              subtitle: Text(
                '${market.address?['address'] ?? 'حدد عنوانك على الخريطة'}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              trailing: const Icon(
                Icons.chevron_left,
                color: MarketColors.primary,
              ),
              onTap: () => open(
                context,
                market.user == null
                    ? const AddressPage()
                    : const AddressesPage(),
              ),
            ),
          ),
          if (banners.isNotEmpty)
            Container(
              height: box.maxWidth >= 1024
                  ? 288
                  : box.maxWidth >= 640
                  ? 240
                  : 176,
              margin: const EdgeInsets.only(bottom: MarketSpace.xl),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(MarketRadius.extraLarge),
                child: PageView(
                  children: banners
                      .map(
                        (b) => InkWell(
                          onTap: () => openBanner(context, b),
                          child: Image.network(
                            '${b['image_url'] ?? ''}',
                            fit: BoxFit.cover,
                            errorBuilder: (_, e, st) => const SizedBox(),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: MarketSpace.xl),
            decoration: BoxDecoration(
              color: MarketColors.surface,
              borderRadius: BorderRadius.circular(MarketRadius.large),
              border: Border.all(color: MarketColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'تسوق حسب القسم',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'وصل للي محتاجه بسرعة',
                            style: TextStyle(
                              fontSize: 12,
                              color: MarketColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => open(
                        context,
                        const PageFrame('الأقسام', CategoriesPage()),
                      ),
                      child: const Text('عرض الكل ‹'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: box.maxWidth >= 768
                      ? 340
                      : 144 +
                            (MediaQuery.textScalerOf(context).scale(12) - 12) *
                                3,
                  child: LoadView<List<JsonMap>>(
                    load: () async =>
                        await market.db.from('main_categories').select(),
                    builder: (cats) => box.maxWidth >= 768
                        ? GridView.count(
                            crossAxisCount: box.maxWidth >= 1024 ? 8 : 6,
                            childAspectRatio: .9,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            children: cats.map((c) => HomeCategory(c)).toList(),
                          )
                        : ListView(
                            scrollDirection: Axis.horizontal,
                            children: cats
                                .map(
                                  (c) => SizedBox(
                                    width: 104,
                                    child: HomeCategory(c),
                                  ),
                                )
                                .toList(),
                          ),
                  ),
                ),
              ],
            ),
          ),
          const Text(
            'مختارات المعداوي',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const Text(
            'منتجات مختارة عشان تسوقك يبقى أسهل',
            style: TextStyle(fontSize: 12, color: MarketColors.textSecondary),
          ),
          const SizedBox(height: 16),
          const CollectionsSection(),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => open(
                  context,
                  const CatalogPage(title: 'عبوات وجملة', bulkOnly: true),
                ),
                icon: const Icon(Icons.inventory_2_outlined, size: 18),
                label: const Text('عبوات وجملة'),
              ),
              OutlinedButton.icon(
                onPressed: () => open(context, const ScannerPage()),
                icon: const Icon(Icons.qr_code_scanner, size: 18),
                label: const Text('مسح باركود'),
              ),
              OutlinedButton.icon(
                onPressed: () => open(context, const CompaniesPage()),
                icon: const Icon(Icons.storefront, size: 18),
                label: const Text('الشركات'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class HomeCategory extends StatelessWidget {
  final JsonMap category;
  const HomeCategory(this.category, {super.key});
  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(16),
    onTap: () => open(context, CategoryPage(category)),
    child: Padding(
      padding: const EdgeInsets.all(4),
      child: Column(
        children: [
          Expanded(
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: MarketColors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(MarketRadius.large),
                  border: Border.all(color: MarketColors.divider),
                ),
                child: '${category['image_url'] ?? ''}'.isEmpty
                    ? Center(
                        child: Text(
                          '${category['name']}'.substring(0, 1),
                          style: const TextStyle(fontSize: 24),
                        ),
                      )
                    : Image.network(
                        '${category['image_url']}',
                        fit: BoxFit.cover,
                      ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${category['name']}',
            maxLines: 2,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    ),
  );
}

Future<void> openBanner(BuildContext context, JsonMap banner) async {
  final ids = banner['products'];
  if (ids is List && ids.isNotEmpty) {
    await open(
      context,
      CatalogPage(
        title: '${banner['title'] ?? 'العرض'}',
        productIds: ids.map((e) => '$e').toList(),
      ),
    );
    return;
  }
  final filters = <String, dynamic>{};
  if (banner['company_id'] != null) {
    filters['p_company_id'] = banner['company_id'];
  }
  if (banner['main_category_id'] != null || banner['category_id'] != null) {
    filters['p_main_category_id'] =
        banner['main_category_id'] ?? banner['category_id'];
  }
  if (filters.isNotEmpty) {
    await open(
      context,
      CatalogPage(title: '${banner['title'] ?? 'العرض'}', filters: filters),
    );
    return;
  }
  final link = '${banner['link'] ?? ''}';
  final segments = Uri.tryParse(link)?.pathSegments ?? <String>[];
  if (link.startsWith('/')) {
    if (segments.length == 2 && segments.first == 'product') {
      await open(context, ProductPage(segments.last));
      return;
    }
    if (segments.length >= 2 && segments.first == 'category') {
      await open(
        context,
        CatalogPage(
          title: 'منتجات القسم',
          filters: {'p_main_category_id': segments[1]},
        ),
      );
      return;
    }
    if (segments.length == 2 && segments.first == 'company') {
      await open(
        context,
        CatalogPage(
          title: 'منتجات الشركة',
          filters: {'p_company_id': segments.last},
        ),
      );
      return;
    }
    if (link == '/bulk-products') {
      await open(
        context,
        const CatalogPage(title: 'عبوات وجملة', bulkOnly: true),
      );
      return;
    }
    if (link == '/search') {
      await open(context, const CatalogPage(title: 'البحث', search: true));
      return;
    }
    if (link == '/categories') {
      await open(context, const PageFrame('الأقسام', CategoriesPage()));
      return;
    }
    if (link == '/') {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }
  }
  final uri = Uri.tryParse('${banner['link'] ?? ''}');
  if (uri != null && {'https', 'http'}.contains(uri.scheme)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});
  @override
  Widget build(BuildContext context) => LoadView<List<JsonMap>>(
    load: () async => await market.db.from('main_categories').select(),
    builder: (data) => data.isEmpty
        ? const EmptyView('الأقسام غير متاحة حاليًا')
        : GridView(
            key: const PageStorageKey('categories'),
            padding: const EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 240,
              mainAxisExtent:
                  190 + (MediaQuery.textScalerOf(context).scale(12) - 12) * 5,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            children: data
                .map(
                  (c) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: HomeCategory(c),
                    ),
                  ),
                )
                .toList(),
          ),
  );
}

class CategoryPage extends StatelessWidget {
  final JsonMap category;
  const CategoryPage(this.category, {super.key});
  @override
  Widget build(BuildContext context) => PageFrame(
    '${category['name']}',
    LoadView<List<JsonMap>>(
      load: () async => await market.db
          .from('subcategories')
          .select()
          .eq('category_id', category['id']),
      builder: (data) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton(
            onPressed: () => open(
              context,
              CatalogPage(
                title: '${category['name']}',
                filters: {'p_main_category_id': category['id']},
              ),
            ),
            child: const Text('كل منتجات القسم'),
          ),
          ...data.map(
            (c) => ListTile(
              leading: photo('${c['image_url'] ?? ''}', width: 55, height: 55),
              title: Text('${c['name']}'),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => open(
                context,
                CatalogPage(
                  title: '${c['name']}',
                  filters: {'p_subcategory_id': c['id']},
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class CompaniesPage extends StatelessWidget {
  const CompaniesPage({super.key});
  @override
  Widget build(BuildContext context) => PageFrame(
    'الشركات',
    LoadView<List<JsonMap>>(
      load: () async =>
          await market.db.from('companies').select().order('name'),
      builder: (data) => ListView(
        children: data
            .map(
              (c) => ListTile(
                leading: photo('${c['logo_url'] ?? ''}', width: 50, height: 50),
                title: Text('${c['name']}'),
                onTap: () => open(
                  context,
                  CatalogPage(
                    title: '${c['name']}',
                    filters: {'p_company_id': c['id']},
                  ),
                ),
              ),
            )
            .toList(),
      ),
    ),
  );
}

class CatalogPage extends StatefulWidget {
  final String title;
  final JsonMap filters;
  final bool search, bulkOnly;
  final List<String>? productIds;
  const CatalogPage({
    super.key,
    required this.title,
    this.filters = const {},
    this.search = false,
    this.bulkOnly = false,
    this.productIds,
  });
  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  final search = TextEditingController();
  String term = '', sort = 'name';
  Timer? searchTimer;
  void applySearch(String value) {
    searchTimer?.cancel();
    if (term == value.trim()) return;
    setState(() {
      term = value.trim();
      revision++;
    });
  }

  int revision = 0;
  @override
  void dispose() {
    searchTimer?.cancel();
    search.dispose();
    super.dispose();
  }

  Future<List<Product>> load() async {
    if (widget.productIds != null) {
      return rows(
        await market.rpc('get_customer_branch_products_by_ids', {
          'p_branch_id': market.runtime?['delivery_branch_id'],
          'p_product_ids': widget.productIds,
        }),
      ).map(Product.new).toList();
    }
    return market.catalog(
      filters: {...widget.filters, if (term.isNotEmpty) 'p_search': term},
    );
  }

  @override
  Widget build(BuildContext context) => PageFrame(
    widget.title,
    Column(
      children: [
        if (widget.search)
          Padding(
            padding: const EdgeInsets.all(MarketSpace.md),
            child: TextField(
              controller: search,
              textInputAction: TextInputAction.search,
              onChanged: (value) {
                searchTimer?.cancel();
                searchTimer = Timer(
                  const Duration(milliseconds: 350),
                  () => applySearch(value),
                );
              },
              onSubmitted: applySearch,
              decoration: InputDecoration(
                hintText: 'دور على منتج أو قسم…',
                fillColor: MarketColors.surfaceSecondary,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  tooltip: 'تنفيذ البحث',
                  onPressed: () => setState(() {
                    term = search.text.trim();
                    revision++;
                  }),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: MarketSpace.md),
          child: DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.sort),
              labelText: "ترتيب المنتجات",
            ),
            value: sort,
            isExpanded: true,
            items: const [
              DropdownMenuItem(value: 'name', child: Text('الاسم')),
              DropdownMenuItem(value: 'low', child: Text('الأقل سعرًا')),
              DropdownMenuItem(value: 'high', child: Text('الأعلى سعرًا')),
            ],
            onChanged: (value) => setState(() => sort = value!),
          ),
        ),
        Expanded(
          child: LoadView<List<Product>>(
            key: ValueKey(revision),
            load: load,
            builder: (data) {
              final products = data
                  .where((p) => !widget.bulkOnly || p.bulk)
                  .toList();
              products.sort(
                (a, b) => sort == 'name'
                    ? a.name.compareTo(b.name)
                    : sort == 'low'
                    ? a
                          .unitPrice(widget.bulkOnly)
                          .compareTo(b.unitPrice(widget.bulkOnly))
                    : b
                          .unitPrice(widget.bulkOnly)
                          .compareTo(a.unitPrice(widget.bulkOnly)),
              );
              if (products.isEmpty) {
                return const EmptyView('مفيش منتجات مطابقة');
              }
              return GridView(
                gridDelegate: productGrid(context),
                padding: const EdgeInsets.all(MarketSpace.md),
                children: products
                    .expand(
                      (p) => [
                        ProductCard(p, bulk: widget.bulkOnly),
                        if (!widget.bulkOnly && p.bulk)
                          ProductCard(p, bulk: true),
                      ],
                    )
                    .toList(),
              );
            },
          ),
        ),
      ],
    ),
  );
}

class ProductCard extends StatelessWidget {
  final Product product;
  final bool bulk;
  const ProductCard(this.product, {super.key, this.bulk = false});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: market,
    builder: (context, _) {
      final line = market.cart
          .where((e) => e.key == CartLine(product, 1, bulk: bulk).key)
          .firstOrNull;
      final originalPrice = bulk ? 0.0 : number(product.data['price']);
      final offerPrice = bulk ? 0.0 : number(product.data['offer_price']);
      final hasOffer = offerPrice > 0 && offerPrice < originalPrice;
      final discount = hasOffer
          ? ((originalPrice - offerPrice) / originalPrice * 100).round()
          : 0;
      return Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(MarketRadius.large),
          onTap: () => open(context, ProductPage(product.id, bulk: bulk)),
          child: Padding(
            padding: const EdgeInsets.all(MarketSpace.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Padding(
                            padding: const EdgeInsets.all(MarketSpace.xs),
                            child: photo(product.picture(bulk)),
                          ),
                        ),
                      ),
                      if (hasOffer)
                        PositionedDirectional(
                          top: MarketSpace.xs,
                          start: MarketSpace.xs,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: MarketSpace.xxs,
                            ),
                            decoration: BoxDecoration(
                              color: MarketColors.discount,
                              borderRadius: BorderRadius.circular(
                                MarketRadius.small,
                              ),
                            ),
                            child: Text(
                              'خصم $discount٪',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: MarketSpace.xs),
                Text(
                  product.title(bulk),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  bulk
                      ? 'عبوة ${product.data['bulk_quantity']} قطعة'
                      : product.weighted
                      ? 'السعر لكل كجم'
                      : 'بالقطعة',
                  style: const TextStyle(
                    color: MarketColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        money(product.unitPrice(bulk)),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          color: MarketColors.primary,
                        ),
                      ),
                    ),
                    if (hasOffer) ...[
                      const SizedBox(width: MarketSpace.xs),
                      Flexible(
                        child: Text(
                          money(originalPrice),
                          style: const TextStyle(
                            color: MarketColors.textTertiary,
                            fontSize: 11,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: MarketSpace.xs),
                AnimatedSwitcher(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 200),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeOut,
                  child: product.maxQuantity(bulk) <= 0
                      ? const FilledButton(
                          key: ValueKey('unavailable'),
                          onPressed: null,
                          child: Text('غير متاح حاليًا'),
                        )
                      : line != null
                      ? Container(
                          key: ValueKey('quantity'),
                          constraints: const BoxConstraints(minHeight: 44),
                          decoration: BoxDecoration(
                            color: MarketColors.primarySurface,
                            borderRadius: BorderRadius.circular(
                              MarketRadius.medium,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                tooltip: 'تقليل',
                                icon: Icon(
                                  line.quantity <=
                                          (product.weighted ? product.step : 1)
                                      ? Icons.delete_outline_rounded
                                      : Icons.remove_rounded,
                                  size: 18,
                                ),
                                onPressed: market.saving
                                    ? null
                                    : () => perform(
                                        context,
                                        () => market.changeCart(
                                          product,
                                          (line.quantity -
                                                  (product.weighted
                                                      ? product.step
                                                      : 1))
                                              .clamp(0, line.quantity),
                                          bulk: bulk,
                                        ),
                                      ),
                              ),
                              Flexible(
                                child: Text(
                                  product.weighted
                                      ? '${line.quantity} جم'
                                      : '${line.quantity}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'زيادة',
                                icon: const Icon(Icons.add_rounded, size: 18),
                                onPressed: market.saving
                                    ? null
                                    : () => perform(
                                        context,
                                        () => market.add(product, bulk: bulk),
                                      ),
                              ),
                            ],
                          ),
                        )
                      : FilledButton.tonalIcon(
                          key: const ValueKey('add'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(44),
                            backgroundColor: MarketColors.primaryLight,
                            foregroundColor: MarketColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                MarketRadius.medium,
                              ),
                            ),
                          ),
                          onPressed: market.saving
                              ? null
                              : () => perform(context, () async {
                                  await market.add(product, bulk: bulk);
                                  if (context.mounted) {
                                    message(context, 'اتضاف للسلة');
                                  }
                                }),
                          icon: const Icon(
                            Icons.add_shopping_cart_rounded,
                            size: 18,
                          ),
                          label: const Text('إضافة للسلة'),
                        ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class ProductPage extends StatelessWidget {
  final String id;
  final bool bulk;
  const ProductPage(this.id, {super.key, this.bulk = false});
  @override
  Widget build(BuildContext context) => PageFrame(
    'تفاصيل المنتج',
    LoadView<List<Product>>(
      load: () => market.catalog(filters: {'p_product_id': id}),
      builder: (items) => items.isEmpty
          ? const EmptyView('المنتج غير متاح في فرعك')
          : ProductDetails(items.first, bulk: bulk),
    ),
  );
}

class ProductDetails extends StatefulWidget {
  final Product product;
  final bool bulk;
  const ProductDetails(this.product, {super.key, required this.bulk});
  @override
  State<ProductDetails> createState() => _ProductDetailsState();
}

class _ProductDetailsState extends State<ProductDetails> {
  late bool bulk;
  late int quantity;
  bool favorite = false;
  @override
  void initState() {
    super.initState();
    bulk = widget.bulk;
    quantity = widget.product.weighted ? widget.product.step : 1;
    perform(context, loadFavorite);
  }

  Future<void> loadFavorite() async {
    if (market.profile == null) return;
    final data = await market.db
        .from('favorites')
        .select('variant_id')
        .eq('customer_id', market.profile!['id'])
        .eq('product_id', widget.product.id);
    if (mounted) {
      setState(
        () => favorite = data.any(
          (e) =>
              e['variant_id'] ==
              (bulk ? widget.product.data['bulk_variant_id'] : null),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(MarketSpace.lg),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(MarketRadius.large),
          child: photo(p.picture(bulk), height: 250),
        ),
        heading(p.title(bulk)),
        Text('${p.data['description'] ?? ''}'),
        if (p.bulk)
          SwitchListTile(
            title: const Text('شراء العبوة / الجملة'),
            value: bulk,
            onChanged: (value) {
              setState(() {
                bulk = value;
                quantity = 1;
              });
              perform(context, loadFavorite);
            },
          ),
        Text(
          money(p.unitPrice(bulk)),
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: MarketColors.primary,
          ),
        ),
        const SizedBox(height: MarketSpace.md),
        Container(
          decoration: BoxDecoration(
            color: MarketColors.primarySurface,
            borderRadius: BorderRadius.circular(MarketRadius.medium),
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: 'تقليل الكمية',
                onPressed: quantity > (p.weighted ? p.step : 1)
                    ? () => setState(() => quantity -= p.weighted ? p.step : 1)
                    : null,
                icon: const Icon(Icons.remove_rounded),
              ),
              Expanded(
                child: Text(
                  '$quantity ${p.weighted
                      ? 'جم'
                      : bulk
                      ? 'عبوة'
                      : 'قطعة'}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                tooltip: 'زيادة الكمية',
                onPressed:
                    quantity + (p.weighted ? p.step : 1) <= p.maxQuantity(bulk)
                    ? () => setState(() => quantity += p.weighted ? p.step : 1)
                    : null,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
        ),
        const SizedBox(height: MarketSpace.sm),
        ActionButton(
          'أضف للسلة • ${money(CartLine(p, quantity, bulk: bulk).total)}',
          () async {
            await market.add(p, bulk: bulk, quantity: quantity);
            if (context.mounted) message(context, 'اتضاف للسلة');
          },
        ),
        TextButton.icon(
          onPressed: () async {
            if (market.user == null) {
              await open(context, const AuthPage());
              return;
            }
            await perform(context, () async {
              await market.favorite(p, bulk, !favorite);
              setState(() => favorite = !favorite);
            });
          },
          icon: AnimatedSwitcher(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: Icon(
              favorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_outline_rounded,
              key: ValueKey(favorite),
              color: favorite
                  ? MarketColors.discount
                  : MarketColors.textSecondary,
            ),
          ),
          label: Text(favorite ? 'إزالة من المفضلة' : 'حفظ في المفضلة'),
        ),
        heading('منتجات مشابهة'),
        SizedBox(
          height: productCardHeight(context),
          child: LoadView<List<Product>>(
            load: () => market.catalog(
              filters: {
                'p_main_category_id': p.data['main_category_id'],
                'p_limit': 12,
              },
            ),
            builder: (related) => ListView(
              scrollDirection: Axis.horizontal,
              children: related
                  .where((e) => e.id != p.id)
                  .take(4)
                  .map((e) => SizedBox(width: 180, child: ProductCard(e)))
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});
  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final controller = MobileScannerController();
  final code = TextEditingController();
  bool busy = false;
  @override
  void dispose() {
    controller.dispose();
    code.dispose();
    super.dispose();
  }

  Future<void> find(String value) async {
    if (busy || value.isEmpty) return;
    setState(() => busy = true);
    await controller.stop();
    try {
      final found = await market.catalog(
        filters: {'p_barcode': value, 'p_limit': 1},
      );
      if (!mounted) return;
      if (found.isEmpty) {
        message(context, 'الباركود مش موجود في فرعك');
      } else {
        await open(
          context,
          ProductPage(
            found.first.id,
            bulk: found.first.data['bulk_barcode'] == value,
          ),
        );
      }
    } catch (e) {
      if (mounted) message(context, friendlyError(e));
    } finally {
      if (mounted) {
        setState(() => busy = false);
        await controller.start();
      }
    }
  }

  @override
  Widget build(BuildContext context) => PageFrame(
    'مسح الباركود',
    Column(
      children: [
        Expanded(
          child: MobileScanner(
            controller: controller,
            onDetect: (capture) {
              final value = capture.barcodes.firstOrNull?.rawValue;
              if (value != null) find(value);
            },
            errorBuilder: (context, error) => const Center(
              child: Text('تعذر فتح الكاميرا. اكتب الباركود بالأسفل'),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: TextField(
            controller: code,
            keyboardType: TextInputType.number,
            onSubmitted: find,
            decoration: InputDecoration(
              labelText: 'أو اكتب الباركود',
              suffixIcon: IconButton(
                tooltip: 'بحث بالباركود',
                onPressed: () => find(code.text.trim()),
                icon: const Icon(Icons.search),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class CollectionsSection extends StatelessWidget {
  const CollectionsSection({super.key});
  @override
  Widget build(BuildContext context) => LoadView<List<JsonMap>>(
    load: () async => await market.db
        .from('product_collections')
        .select()
        .eq('active', true)
        .order('position'),
    builder: (collections) => Column(
      children: collections
          .where((c) => ((c['products'] as List?) ?? []).isNotEmpty)
          .map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: LoadView<List<Product>>(
                load: () async => rows(
                  await market.rpc('get_customer_branch_products_by_ids', {
                    'p_branch_id': market.runtime?['delivery_branch_id'],
                    'p_product_ids': c['products'],
                  }),
                ).map(Product.new).toList(),
                builder: (products) => products.isEmpty
                    ? const SizedBox()
                    : Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(
                            MarketRadius.large,
                          ),
                          border: Border.all(color: MarketColors.divider),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '${c['title']}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (c['description'] != null)
                              Text(
                                '${c['description']}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: MarketColors.textSecondary,
                                ),
                              ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: productCardHeight(context),
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: products
                                    .expand(
                                      (p) => [
                                        SizedBox(
                                          width: 180,
                                          child: ProductCard(p),
                                        ),
                                        if (p.data['bulk_variant_id'] != null)
                                          SizedBox(
                                            width: 180,
                                            child: ProductCard(p, bulk: true),
                                          ),
                                      ],
                                    )
                                    .toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          )
          .toList(),
    ),
  );
}

class HomeWelcome extends StatelessWidget {
  const HomeWelcome({super.key});
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: MarketSpace.md),
        padding: const EdgeInsets.all(MarketSpace.xl),
        decoration: BoxDecoration(
          color: MarketColors.primarySurface,
          borderRadius: BorderRadius.circular(MarketRadius.extraLarge),
          border: Border.all(color: MarketColors.primaryLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.eco_rounded, color: MarketColors.primary, size: 18),
                SizedBox(width: MarketSpace.xs),
                Expanded(
                  child: Text(
                    'المعداوي ماركت • مش مجرد ماركت',
                    style: TextStyle(
                      color: MarketColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: MarketSpace.sm),
            const Text(
              'طلبات البيت، ببساطة.',
              style: TextStyle(
                fontSize: 24,
                height: 1.35,
                fontWeight: FontWeight.w700,
                color: MarketColors.textPrimary,
              ),
            ),
            const SizedBox(height: MarketSpace.xs),
            const Text(
              'اختار اللي ناقصك وسيب الباقي علينا',
              style: TextStyle(fontSize: 14, color: MarketColors.textSecondary),
            ),
            const SizedBox(height: MarketSpace.lg),
            FilledButton.icon(
              onPressed: () => open(
                context,
                const CatalogPage(title: 'تسوق المنتجات', search: true),
              ),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('ابدأ تسوقك'),
            ),
          ],
        ),
      ),
      Row(
        children: [
          Expanded(
            child: _shortcut(
              context,
              'عبوات وجملة',
              'اختيارات أكتر',
              Icons.inventory_2_outlined,
              const CatalogPage(title: 'عبوات وجملة', bulkOnly: true),
            ),
          ),
          const SizedBox(width: MarketSpace.sm),
          Expanded(
            child: _shortcut(
              context,
              'امسح المنتج',
              'وصول أسرع',
              Icons.qr_code_scanner,
              const ScannerPage(),
            ),
          ),
        ],
      ),
      const SizedBox(height: MarketSpace.md),
    ],
  );
  Widget _shortcut(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Widget page,
  ) => Material(
    color: MarketColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(MarketRadius.large),
      side: const BorderSide(color: MarketColors.divider),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(MarketRadius.large),
      onTap: () => open(context, page),
      child: Padding(
        padding: const EdgeInsets.all(MarketSpace.sm),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: MarketColors.primarySurface,
                borderRadius: BorderRadius.circular(MarketRadius.medium),
              ),
              child: Icon(icon, color: MarketColors.primary, size: 21),
            ),
            const SizedBox(width: MarketSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
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
    ),
  );
}
