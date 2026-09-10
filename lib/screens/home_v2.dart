import 'dart:async';

import 'package:flutter/material.dart';

import '../core/design.dart';
import '../core/ui.dart';
import 'address.dart';
import 'catalog.dart';
import 'categories_v2.dart';

class StoreHomeV2 extends StatelessWidget {
  const StoreHomeV2({super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, box) => ListView(
          key: const PageStorageKey('store-home-v2'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            box.maxWidth > 1000 ? (box.maxWidth - 1000) / 2 + 16 : 16,
            14,
            box.maxWidth > 1000 ? (box.maxWidth - 1000) / 2 + 16 : 16,
            32,
          ),
          children: [
            _DeliveryAddressCard(onTap: () {
              open(
                context,
                market.user == null
                    ? const AddressPage()
                    : const AddressesPage(),
              );
            }),
            const SizedBox(height: 18),
            const _HomeBanners(),
            const SizedBox(height: 24),
            _CategorySection(maxWidth: box.maxWidth),
            const SizedBox(height: 28),
            const Text(
              'مختارات المعداوي',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w700,
                color: MarketColors.textPrimary,
              ),
            ),
            const SizedBox(height: 3),
            const Text(
              'منتجات مختارة عشان تسوقك يبقى أسهل',
              style: TextStyle(
                fontSize: 12,
                color: MarketColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            const CollectionsSection(),
          ],
        ),
      );
}

class _DeliveryAddressCard extends StatelessWidget {
  final VoidCallback onTap;
  const _DeliveryAddressCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final text = '${market.address?['address'] ?? ''}'.trim();
    final distance = number(
      market.address?['road_distance_km'] ?? market.runtime?['road_distance_km'],
    );
    return Material(
      color: MarketColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 68),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: MarketColors.primaryLight),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0C000000),
                blurRadius: 16,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: MarketColors.primarySurface,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.location_on_outlined,
                  color: MarketColors.primary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'التوصيل إلى',
                      style: TextStyle(
                        fontSize: 11,
                        color: MarketColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      text.isEmpty ? 'حدد عنوانك على الخريطة' : text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (market.user == null && text.isNotEmpty && distance > 0)
                      Text(
                        'ضيف · ${distance.toStringAsFixed(1)} كم من الفرع',
                        style: const TextStyle(
                          fontSize: 10,
                          color: MarketColors.primary,
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_left_rounded,
                color: MarketColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeBanners extends StatefulWidget {
  const _HomeBanners();

  @override
  State<_HomeBanners> createState() => _HomeBannersState();
}

class _HomeBannersState extends State<_HomeBanners> {
  final controller = PageController();
  Timer? timer;
  int index = 0;
  int count = 0;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || count < 2 || !controller.hasClients) return;
      final next = (index + 1) % count;
      controller.animateToPage(
        next,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LoadView<List<JsonMap>>(
        load: () async => await market.db
            .from('banners')
            .select()
            .eq('active', true)
            .order('position'),
        builder: (banners) {
          count = banners.length;
          if (banners.isEmpty) return const SizedBox.shrink();
          return Column(
            children: [
              AspectRatio(
                aspectRatio: MediaQuery.sizeOf(context).width >= 700 ? 2.7 : 1.85,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: PageView.builder(
                    controller: controller,
                    itemCount: banners.length,
                    onPageChanged: (value) => setState(() => index = value),
                    itemBuilder: (context, i) {
                      final banner = banners[i];
                      return InkWell(
                        onTap: () => openBanner(context, banner),
                        child: Image.network(
                          '${banner['image_url'] ?? ''}',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: MarketColors.surfaceSecondary,
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.image_outlined,
                              color: MarketColors.textTertiary,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              if (banners.length > 1) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    banners.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: i == index ? 20 : 7,
                      height: 7,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: i == index
                            ? MarketColors.primary
                            : MarketColors.border,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      );
}

class _CategorySection extends StatelessWidget {
  final double maxWidth;
  const _CategorySection({required this.maxWidth});

  Widget _title() => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'تسوق حسب القسم',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 2),
          Text(
            'وصل للي محتاجه بسرعة',
            style: TextStyle(fontSize: 11, color: MarketColors.textSecondary),
          ),
        ],
      );

  Widget _allButton(BuildContext context) => TextButton.icon(
        onPressed: () => open(
          context,
          const PageFrame('الأقسام', CategoriesV2Page()),
        ),
        iconAlignment: IconAlignment.end,
        icon: const Icon(Icons.chevron_left_rounded, size: 18),
        label: const Text('عرض الكل'),
      );

  @override
  Widget build(BuildContext context) {
    final compactHeader = maxWidth < 420 ||
        MediaQuery.textScalerOf(context).scale(14) > 20;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MarketColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: MarketColors.divider),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 18,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          if (compactHeader)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _title(),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: _allButton(context),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(child: _title()),
                _allButton(context),
              ],
            ),
          const SizedBox(height: 12),
          LoadView<List<JsonMap>>(
            load: () async => await market.db.from('main_categories').select(),
            builder: (cats) {
              if (maxWidth >= 700) {
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: cats.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: maxWidth >= 1000 ? 8 : 6,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: .76,
                  ),
                  itemBuilder: (_, i) =>
                      CustomerCategoryTile(cats[i], compact: true),
                );
              }
              return SizedBox(
                height: 146 +
                    (MediaQuery.textScalerOf(context).scale(12) - 12)
                        .clamp(0, 18) *
                        2,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: cats.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) => SizedBox(
                    width: 98 +
                        (MediaQuery.textScalerOf(context).scale(12) - 12)
                            .clamp(0, 16),
                    child: CustomerCategoryTile(cats[i], compact: true),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
