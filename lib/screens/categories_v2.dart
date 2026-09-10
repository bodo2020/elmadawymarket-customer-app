import 'package:flutter/material.dart';

import '../core/design.dart';
import '../core/ui.dart';
import 'catalog.dart';

class CategoriesV2Page extends StatelessWidget {
  const CategoriesV2Page({super.key});

  @override
  Widget build(BuildContext context) => LoadView<List<JsonMap>>(
        load: () async => await market.db
            .from('main_categories')
            .select()
            .order('created_at'),
        builder: (categories) {
          if (categories.isEmpty) {
            return const EmptyView('الأقسام غير متاحة حاليًا');
          }
          return LayoutBuilder(
            builder: (context, box) {
              final columns = _columns(box.maxWidth);
              return GridView.builder(
                key: const PageStorageKey('categories-v2'),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 28),
                itemCount: categories.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: .78,
                ),
                itemBuilder: (_, index) =>
                    CustomerCategoryTile(categories[index]),
              );
            },
          );
        },
      );
}

class CustomerCategoryTile extends StatelessWidget {
  final JsonMap category;
  final bool compact;
  const CustomerCategoryTile(this.category, {super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final image = '${category['image_url'] ?? ''}'.trim();
    final name = '${category['name'] ?? ''}'.trim();
    return Semantics(
      button: true,
      label: name,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => open(context, CategoryV2Page(category)),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Column(
            children: [
              Expanded(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: MarketColors.primarySurface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: MarketColors.primaryLight),
                    ),
                    child: image.isEmpty
                        ? Center(
                            child: Text(
                              name.isEmpty ? '؟' : name.characters.first,
                              style: TextStyle(
                                fontSize: compact ? 21 : 25,
                                color: MarketColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        : Image.network(
                            image,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(
                                Icons.category_outlined,
                                color: MarketColors.primary,
                              ),
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 7),
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: compact ? 11 : 12,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: MarketColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CategoryV2Page extends StatelessWidget {
  final JsonMap category;
  const CategoryV2Page(this.category, {super.key});

  @override
  Widget build(BuildContext context) => PageFrame(
        '${category['name'] ?? 'القسم'}',
        LoadView<List<JsonMap>>(
          load: () async => await market.db
              .from('subcategories')
              .select()
              .eq('category_id', category['id'])
              .order('created_at'),
          builder: (subcategories) {
            if (subcategories.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  StatusSurface(
                    title: 'مفيش أقسام فرعية هنا',
                    message: 'تقدر تعرض كل منتجات ${category['name'] ?? 'القسم'} مباشرة.',
                    icon: Icons.grid_view_rounded,
                    action: FilledButton(
                      onPressed: () => open(
                        context,
                        CatalogPage(
                          title: '${category['name'] ?? 'منتجات القسم'}',
                          filters: {'p_main_category_id': category['id']},
                        ),
                      ),
                      child: const Text('عرض كل المنتجات'),
                    ),
                  ),
                ],
              );
            }
            return LayoutBuilder(
              builder: (context, box) {
                final columns = _subColumns(box.maxWidth);
                return CustomScrollView(
                  key: ValueKey('category-v2-${category['id']}'),
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                      sliver: SliverToBoxAdapter(
                        child: OutlinedButton.icon(
                          onPressed: () => open(
                            context,
                            CatalogPage(
                              title: 'كل ${category['name'] ?? 'المنتجات'}',
                              filters: {
                                'p_main_category_id': category['id'],
                              },
                            ),
                          ),
                          icon: const Icon(Icons.inventory_2_outlined, size: 18),
                          label: const Text('كل منتجات القسم'),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 28),
                      sliver: SliverGrid.builder(
                        itemCount: subcategories.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: .78,
                        ),
                        itemBuilder: (_, index) => _SubcategoryTile(
                          subcategories[index],
                          category: category,
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

class _SubcategoryTile extends StatelessWidget {
  final JsonMap subcategory;
  final JsonMap category;
  const _SubcategoryTile(this.subcategory, {required this.category});

  @override
  Widget build(BuildContext context) {
    final image = '${subcategory['image_url'] ?? ''}'.trim();
    final name = '${subcategory['name'] ?? ''}'.trim();
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => open(
        context,
        CatalogPage(
          title: name.isEmpty ? '${category['name']}' : name,
          filters: {'p_subcategory_id': subcategory['id']},
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Column(
          children: [
            Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: MarketColors.surfaceSecondary,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: MarketColors.divider),
                  ),
                  child: image.isEmpty
                      ? const Icon(
                          Icons.shopping_basket_outlined,
                          color: MarketColors.primary,
                        )
                      : Image.network(
                          image,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.shopping_basket_outlined,
                            color: MarketColors.primary,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

int _columns(double width) {
  if (width >= 1100) return 8;
  if (width >= 850) return 6;
  if (width >= 600) return 4;
  return 3;
}

int _subColumns(double width) {
  if (width >= 1100) return 8;
  if (width >= 850) return 6;
  if (width >= 600) return 5;
  return 3;
}
