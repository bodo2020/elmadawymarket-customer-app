import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';
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
          horizontal: box.maxWidth > 1000 ? (box.maxWidth - 1000) / 2 + 16 : 12,
          vertical: 16,
        ),
        key: const PageStorageKey('store-home'),
        children: [
          const HomeWelcome(),
          Card(
            margin: const EdgeInsets.only(bottom: 20),
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xfff0fdf4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.location_on_outlined,
                  color: Color(0xff005931),
                  size: 20,
                ),
              ),
              title: const Text(
                'التوصيل إلى',
                style: TextStyle(fontSize: 12, color: Color(0xff6b7280)),
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
                color: Color(0xff005931),
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
              margin: const EdgeInsets.only(bottom: 28),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
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
            margin: const EdgeInsets.only(bottom: 28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
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
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'وصل للي محتاجه بسرعة',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xff6b7280),
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
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const Text(
            'منتجات مختارة عشان تسوقك يبقى أسهل',
            style: TextStyle(fontSize: 12, color: Color(0xff6b7280)),
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
                  color: const Color(0xfff0fdf4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xffdcfce7)),
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
            padding: const EdgeInsets.all(16),
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
                labelText: 'ابحث باسم المنتج',
                suffixIcon: IconButton(
                  tooltip: 'بحث',
                  onPressed: () => setState(() {
                    term = search.text.trim();
                    revision++;
                  }),
                  icon: const Icon(Icons.search),
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
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
                padding: const EdgeInsets.all(12),
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
      return Card(
        child: InkWell(
          onTap: () => open(context, ProductPage(product.id, bulk: bulk)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xfff6f8f7),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: photo(product.picture(bulk)),
                  ),
                ),
                const SizedBox(height: 8),
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
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
                Text(
                  money(product.unitPrice(bulk)),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Color(0xff005931),
                  ),
                ),
                const SizedBox(height: 8),
                product.maxQuantity(bulk) <= 0
                    ? const FilledButton(
                        onPressed: null,
                        child: Text('غير متاح حاليًا'),
                      )
                    : line != null
                    ? Container(
                        constraints: const BoxConstraints(minHeight: 48),
                        decoration: BoxDecoration(
                          color: const Color(0xfff0fdf4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              tooltip: 'تقليل',
                              icon: Icon(
                                line.quantity <=
                                        (product.weighted ? product.step : 1)
                                    ? Icons.delete_outline
                                    : Icons.remove,
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
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'زيادة',
                              icon: const Icon(Icons.add, size: 18),
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
                    : ActionButton('إضافة للسلة', () async {
                        await market.add(product, bulk: bulk);
                        if (context.mounted) message(context, 'اتضاف للسلة');
                      }),
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
      padding: const EdgeInsets.all(20),
      children: [
        photo(p.picture(bulk), height: 250),
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
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            IconButton(
              tooltip: 'تقليل الكمية',
              onPressed: quantity > (p.weighted ? p.step : 1)
                  ? () => setState(() => quantity -= p.weighted ? p.step : 1)
                  : null,
              icon: const Icon(Icons.remove),
            ),
            Expanded(
              child: Text(
                '$quantity ${p.weighted
                    ? 'جم'
                    : bulk
                    ? 'عبوة'
                    : 'قطعة'}',
                textAlign: TextAlign.center,
              ),
            ),
            IconButton(
              tooltip: 'زيادة الكمية',
              onPressed:
                  quantity + (p.weighted ? p.step : 1) <= p.maxQuantity(bulk)
                  ? () => setState(() => quantity += p.weighted ? p.step : 1)
                  : null,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
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
          icon: Icon(favorite ? Icons.favorite : Icons.favorite_outline),
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
                          borderRadius: BorderRadius.circular(24),
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
                                  color: Color(0xff6b7280),
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
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xff004d2c), Color(0xff08734a)],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x18005931),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.eco_outlined, color: Color(0xffcfedaf), size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'المعداوي • كل يوم معاك',
                    style: TextStyle(
                      color: Color(0xffd8eddf),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'طلبات البيت، ببساطة.',
              style: TextStyle(
                fontSize: 26,
                height: 1.35,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'اختار اللي ناقصك وسيب الباقي علينا',
              style: TextStyle(fontSize: 13, color: Color(0xffd8eddf)),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xffd8efa9),
                foregroundColor: const Color(0xff17472e),
              ),
              onPressed: () => open(
                context,
                const CatalogPage(title: 'تسوق المنتجات', search: true),
              ),
              icon: const Icon(Icons.arrow_back, size: 18),
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
          const SizedBox(width: 10),
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
      const SizedBox(height: 16),
    ],
  );
  Widget _shortcut(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Widget page,
  ) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => open(context, page),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xff005931), size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xff728078),
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
