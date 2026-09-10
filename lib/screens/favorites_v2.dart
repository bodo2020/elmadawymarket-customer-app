import 'package:flutter/material.dart';

import '../core/design.dart';
import '../core/ui.dart';
import 'auth.dart';
import 'product_v2.dart';

class FavoritesV2Page extends StatefulWidget {
  const FavoritesV2Page({super.key});

  @override
  State<FavoritesV2Page> createState() => _FavoritesV2PageState();
}

class _FavoritesV2PageState extends State<FavoritesV2Page> {
  int revision = 0;

  @override
  void initState() {
    super.initState();
    customerFavoritesV2.addListener(_changed);
  }

  @override
  void dispose() {
    customerFavoritesV2.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() => revision++);
  }

  Future<List<JsonMap>> _loadFavorites() async {
    if (market.profile == null) return [];
    await customerFavoritesV2.ensureLoaded();
    return await market.db
        .from('favorites')
        .select('product_id,variant_id')
        .eq('customer_id', market.profile!['id']);
  }

  @override
  Widget build(BuildContext context) {
    if (market.user == null) {
      return PageFrame(
        'المفضلة',
        ListView(
          padding: const EdgeInsets.all(22),
          children: [
            const StatusSurface(
              title: 'سجّل دخولك عشان تحفظ المفضلة',
              message: 'بعد تسجيل الدخول، منتجاتك المفضلة هتفضل محفوظة في حسابك.',
              icon: Icons.favorite_border_rounded,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => open(context, const AuthPage()),
              icon: const Icon(Icons.phone_android_rounded),
              label: const Text('تسجيل الدخول'),
            ),
          ],
        ),
      );
    }

    return PageFrame(
      'المفضلة',
      LoadView<List<JsonMap>>(
        key: ValueKey(revision),
        load: _loadFavorites,
        builder: (favorites) {
          if (favorites.isEmpty) {
            return EmptyView(
              'مفيش منتجات محفوظة لسه',
              actionLabel: 'ابدأ التسوق',
              onAction: () => openShellTab(context, 0),
            );
          }
          return LoadView<List<Product>>(
            load: () async => rows(
              await market.rpc('get_customer_branch_products_by_ids', {
                'p_branch_id': market.runtime?['delivery_branch_id'],
                'p_product_ids': favorites
                    .map((item) => item['product_id'])
                    .toSet()
                    .toList(),
              }),
            ).map(Product.new).toList(),
            builder: (products) {
              final units = <ProductUnitV2>[];
              for (final favorite in favorites) {
                final found = products.where(
                  (product) => product.id == '${favorite['product_id']}',
                );
                if (found.isEmpty) continue;
                final product = found.first;
                final bulk = favorite['variant_id'] != null && product.bulk;
                units.add((product: product, bulk: bulk));
              }
              if (units.isEmpty) {
                return const EmptyView('المنتجات المحفوظة مش متاحة في فرعك حاليًا');
              }
              return CustomScrollView(
                key: const PageStorageKey('favorites-v2'),
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                    sliver: SliverToBoxAdapter(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: MarketColors.primarySurface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: MarketColors.primaryLight),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.favorite_rounded,
                              color: MarketColors.success,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${units.length} منتجات محفوظة عندك',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: MarketColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 28),
                    sliver: SliverGrid.builder(
                      itemCount: units.length,
                      gridDelegate: productGridV2(context),
                      itemBuilder: (_, index) => ProductCardV2(
                        units[index].product,
                        bulk: units[index].bulk,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
