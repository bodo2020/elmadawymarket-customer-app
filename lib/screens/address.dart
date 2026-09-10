import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/design.dart';
import '../core/ui.dart';

class AddressPage extends StatefulWidget {
  final JsonMap? existing;
  final bool requiredAddress;
  const AddressPage({super.key, this.existing, this.requiredAddress = false});

  @override
  State<AddressPage> createState() => _AddressPageState();
}

class _AddressPageState extends State<AddressPage> {
  final details = TextEditingController();
  final controller = MapController();
  LatLng? point;

  @override
  void initState() {
    super.initState();
    final address = widget.existing;
    if (address != null) {
      details.text = '${address['address'] ?? ''}';
      if (address['latitude'] != null && address['longitude'] != null) {
        point = LatLng(
          number(address['latitude']),
          number(address['longitude']),
        );
      }
    }
  }

  @override
  void dispose() {
    details.dispose();
    controller.dispose();
    super.dispose();
  }

  Future<void> locate() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('LOCATION_DISABLED');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted) {
        message(context, 'تقدر تحدد مكانك بالضغط على الخريطة');
      }
      return;
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        timeLimit: Duration(seconds: 20),
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() => point = LatLng(position.latitude, position.longitude));
    controller.move(point!, 16);
  }

  Future<void> save() async {
    if (point == null || details.text.trim().isEmpty) {
      message(context, 'حدد نقطة على الخريطة واكتب تفاصيل العنوان');
      return;
    }
    await market.saveAddress(
      details.text.trim(),
      point!.latitude,
      point!.longitude,
      id: widget.existing?['id'],
    );
    if (!mounted) {
      return;
    }
    if (!widget.requiredAddress) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mapPanel = panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              _StepBadge('١'),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'حدد باب البيت على الخريطة',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'نطاق التوصيل بيتحسب بالطريق الفعلي من الفرع، مش بخط مستقيم.',
            style: TextStyle(fontSize: 13, color: MarketColors.textSecondary),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, box) => SizedBox(
              height: box.maxWidth < 420 ? 280 : 340,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: FlutterMap(
                  mapController: controller,
                  options: MapOptions(
                    initialCenter: point ?? const LatLng(31.256622, 31.168264),
                    initialZoom: 14,
                    onTap: (_, selected) => setState(() => point = selected),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.elmadawy.elmadawy_market',
                    ),
                    if (point != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: point!,
                            child: const Icon(
                              Icons.location_pin,
                              color: MarketColors.primary,
                              size: 46,
                            ),
                          ),
                        ],
                      ),
                    RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution(
                          'OpenStreetMap contributors',
                          onTap: () => launchUrl(
                            Uri.parse('https://www.openstreetmap.org/copyright'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => perform(context, locate),
            icon: const Icon(Icons.my_location_rounded),
            label: const Text('استخدم موقعي الحالي'),
          ),
          const SizedBox(height: 8),
          const Text(
            'مش هنطلب صلاحية موقعك إلا لو ضغطت «استخدم موقعي». وتقدر تختار النقطة يدويًا في أي وقت.',
            style: TextStyle(fontSize: 11, color: MarketColors.textTertiary),
          ),
        ],
      ),
    );

    final detailsPanel = panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              _StepBadge('٢'),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'كمّل تفاصيل العنوان',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'اكتب الشارع والبيت والدور والشقة وأي علامة مميزة تساعد المندوب.',
            style: TextStyle(fontSize: 13, color: MarketColors.textSecondary),
          ),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 18),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: MarketColors.primarySurface,
              borderRadius: BorderRadius.circular(MarketRadius.large),
              border: Border.all(color: MarketColors.primaryLight),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.route_outlined,
                  color: MarketColors.primary,
                  size: 21,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'هنراجع التوصيل قبل الحفظ',
                        style: TextStyle(
                          color: MarketColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'بنحسب مسافة القيادة الفعلية ونربط العنوان بفرع التوصيل المناسب.',
                        style: TextStyle(fontSize: 12, height: 1.55),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          TextField(
            controller: details,
            maxLines: 4,
            maxLength: 1000,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'تفاصيل العنوان',
              hintText: 'مثال: شارع… بيت… الدور… الشقة…',
              prefixIcon: Icon(Icons.home_outlined),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          ActionButton(
            widget.existing == null
                ? 'استخدام العنوان وابدأ التسوق'
                : 'حفظ تعديلات العنوان',
            save,
            icon: Icons.check_circle_outline_rounded,
          ),
          const SizedBox(height: 12),
          if (market.user == null)
            const Text(
              'هنحفظ العنوان على الجهاز مؤقتًا. تقدر تسجّل دخولك بعدين لإكمال الطلب وحفظ بياناتك في حسابك.',
              style: TextStyle(fontSize: 12, color: MarketColors.textSecondary),
            ),
        ],
      ),
    );

    final content = LayoutBuilder(
      builder: (context, box) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(
          horizontal: box.maxWidth > 1100 ? (box.maxWidth - 1100) / 2 + 16 : 16,
          vertical: 22,
        ),
        children: [
          Text(
            widget.existing != null
                ? 'تعديل عنوان التوصيل'
                : widget.requiredAddress
                    ? 'حدد عنوانك قبل ما تبدأ التسوق'
                    : 'عنوان التوصيل',
            style: TextStyle(
              fontSize: box.maxWidth > 768 ? 32 : 23,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'حدد موقعك بدقة واكتب التفاصيل. هنستخدم الطريق الفعلي عشان نعرف الفرع المناسب والتوصيل المتاح.',
            style: TextStyle(
              height: 1.65,
              color: MarketColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          if (box.maxWidth >= 850)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: mapPanel),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: detailsPanel),
              ],
            )
          else ...[
            mapPanel,
            const SizedBox(height: 16),
            detailsPanel,
          ],
        ],
      ),
    );
    return widget.requiredAddress ? content : PageFrame('العنوان', content);
  }
}

class _StepBadge extends StatelessWidget {
  final String value;
  const _StepBadge(this.value);

  @override
  Widget build(BuildContext context) => Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: MarketColors.primarySurface,
          shape: BoxShape.circle,
        ),
        child: Text(
          value,
          style: const TextStyle(
            color: MarketColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

class AddressesPage extends StatefulWidget {
  const AddressesPage({super.key});

  @override
  State<AddressesPage> createState() => _AddressesPageState();
}

class _AddressesPageState extends State<AddressesPage> {
  int refresh = 0;

  Future<void> edit([JsonMap? address]) async {
    await open(context, AddressPage(existing: address));
    if (mounted) {
      setState(() => refresh++);
    }
  }

  bool ready(JsonMap address) =>
      address['latitude'] != null &&
      address['longitude'] != null &&
      address['is_deliverable'] != false;

  Future<void> setDefault(JsonMap address) async {
    if (!ready(address)) {
      message(
        context,
        'حدد موقع العنوان على الخريطة وتأكد إنه داخل نطاق التوصيل الأول',
      );
      return;
    }
    await market.rpc('set_default_customer_address', {
      'p_address_id': address['id'],
    });
    await market.load();
    if (mounted) {
      setState(() => refresh++);
      message(context, 'تم تحديث عنوان التوصيل الافتراضي');
    }
  }

  Future<void> deleteAddress(JsonMap address) async {
    if (address['is_default'] == true) {
      message(context, 'اختار عنوان افتراضي تاني قبل حذف العنوان الحالي');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف العنوان؟'),
        content: Text('${address['address']}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('رجوع'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    final ok = await perform(context, () async {
      await market.db
          .from('customer_addresses')
          .delete()
          .eq('id', address['id'])
          .eq('user_id', market.user!.id);
      await market.load();
    }, success: 'تم حذف العنوان');
    if (ok && mounted) {
      setState(() => refresh++);
    }
  }

  @override
  Widget build(BuildContext context) => PageFrame(
        'عناوينك',
        LoadView<List<JsonMap>>(
          key: ValueKey(refresh),
          load: market.addresses,
          builder: (data) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            children: [
              const Text(
                'عناوين التوصيل',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 5),
              const Text(
                'كل عنوان لازم يكون محدد على الخريطة. اختار عنوانك الافتراضي عشان نستخدمه تلقائيًا في الطلبات.',
                style: TextStyle(
                  color: MarketColors.textSecondary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 18),
              if (data.isEmpty)
                StatusSurface(
                  title: 'مفيش عناوين محفوظة',
                  message: 'ضيف عنوانك على الخريطة عشان نحدد فرع التوصيل المناسب.',
                  icon: Icons.location_on_outlined,
                  action: FilledButton.icon(
                    onPressed: () => edit(),
                    icon: const Icon(Icons.add_location_alt_outlined),
                    label: const Text('إضافة عنوان'),
                  ),
                )
              else ...[
                ...data.map((address) {
                  final isDefault = address['is_default'] == true;
                  final hasPoint = address['latitude'] != null &&
                      address['longitude'] != null;
                  final isReady = ready(address);
                  final distance = number(
                    address['road_distance_km'] ?? address['distance_km'],
                  );
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: MarketColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDefault
                            ? MarketColors.primary
                            : MarketColors.divider,
                        width: isDefault ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Icon(
                              isDefault
                                  ? Icons.home_rounded
                                  : Icons.location_on_outlined,
                              color: MarketColors.primary,
                              size: 20,
                            ),
                            Text(
                              isDefault ? 'العنوان الافتراضي' : 'عنوان توصيل',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            _AddressStatusChip(
                              ready: isReady,
                              hasPoint: hasPoint,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${address['address']}',
                          style: const TextStyle(height: 1.6),
                        ),
                        if (hasPoint) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.route_outlined,
                                size: 16,
                                color: MarketColors.textTertiary,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  distance > 0
                                      ? 'يبعد ${distance.toStringAsFixed(1)} كم عن فرع التوصيل'
                                      : 'الموقع محدد على الخريطة',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: MarketColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => edit(address),
                              icon: const Icon(Icons.edit_outlined, size: 17),
                              label: Text(hasPoint ? 'تعديل' : 'حدد على الخريطة'),
                            ),
                            if (!isDefault && isReady)
                              FilledButton.tonalIcon(
                                onPressed: () => perform(
                                  context,
                                  () => setDefault(address),
                                ),
                                icon: const Icon(Icons.check_rounded, size: 17),
                                label: const Text('تعيين كافتراضي'),
                              ),
                            if (!isDefault)
                              TextButton.icon(
                                onPressed: () => deleteAddress(address),
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 17,
                                  color: MarketColors.error,
                                ),
                                label: const Text(
                                  'حذف',
                                  style: TextStyle(color: MarketColors.error),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 6),
                FilledButton.icon(
                  onPressed: () => edit(),
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text('إضافة عنوان جديد على الخريطة'),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
}

class _AddressStatusChip extends StatelessWidget {
  final bool ready;
  final bool hasPoint;
  const _AddressStatusChip({required this.ready, required this.hasPoint});

  @override
  Widget build(BuildContext context) {
    final label = ready
        ? 'داخل نطاق التوصيل'
        : hasPoint
            ? 'راجع نطاق التوصيل'
            : 'يحتاج تحديد موقع';
    final color = ready ? MarketColors.primary : const Color(0xff996400);
    final background = ready
        ? MarketColors.primarySurface
        : const Color(0xfffff7df);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ready
                ? Icons.check_circle_outline_rounded
                : Icons.warning_amber_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
