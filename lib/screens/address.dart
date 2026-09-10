import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
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
    final a = widget.existing;
    if (a != null) {
      details.text = '${a['address'] ?? ''}';
      if (a['latitude'] != null) {
        point = LatLng(number(a['latitude']), number(a['longitude']));
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
      if (mounted) message(context, 'تقدر تحدد مكانك بالضغط على الخريطة');
      return;
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        timeLimit: Duration(seconds: 20),
      ),
    );
    if (!mounted) return;
    setState(() => point = LatLng(position.latitude, position.longitude));
    controller.move(point!, 16);
  }

  @override
  Widget build(BuildContext context) {
    final mapPanel = panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'حدد موقعك على الخريطة',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const Text(
            'نطاق التوصيل بيتحسب بالطريق الفعلي من الفرع، مش بخط مستقيم.',
            style: TextStyle(fontSize: 13, color: MarketColors.textSecondary),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 320,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: FlutterMap(
                mapController: controller,
                options: MapOptions(
                  initialCenter: point ?? const LatLng(31.256622, 31.168264),
                  initialZoom: 14,
                  onTap: (tap, p) => setState(() => point = p),
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
                            size: 44,
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
          TextButton.icon(
            onPressed: () => perform(context, locate),
            icon: const Icon(Icons.my_location),
            label: const Text('استخدم موقعي الحالي'),
          ),

          const Text(
            'الخريطة بدأت من فرع المعداوي الأساسي. مش هنطلب صلاحية موقعك إلا لو ضغطت «استخدم موقعي».',
            style: TextStyle(fontSize: 12, color: MarketColors.textSecondary),
          ),
        ],
      ),
    );
    final detailsPanel = panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'تفاصيل العنوان',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const Text(
            'اكتب التفاصيل يدويًا حتى لو استخدمت الخريطة.',
            style: TextStyle(fontSize: 13, color: MarketColors.textSecondary),
          ),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: MarketColors.primarySurface,
              borderRadius: BorderRadius.circular(MarketRadius.large),
              border: Border.all(color: MarketColors.primaryLight),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'التحقق من التوصيل',
                  style: TextStyle(
                    color: MarketColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'عند الحفظ بنحسب مسافة القيادة الفعلية من الفرع.',
                  style: TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
          TextField(
            controller: details,
            maxLines: 5,
            maxLength: 1000,
            decoration: const InputDecoration(
              labelText: 'الشارع، البيت، الدور والشقة',
            ),
          ),
          const SizedBox(height: 12),
          ActionButton('استخدام العنوان وابدأ التسوق', () async {
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
            if (context.mounted && !widget.requiredAddress) {
              Navigator.pop(context, true);
            }
          }),

          const SizedBox(height: 12),
          if (market.user == null)
            const Text(
              'هنحفظ العنوان على الجهاز مؤقتًا. تقدر تسجّل دخولك بعدين لإكمال الطلب وحفظه في حسابك.',
              style: TextStyle(fontSize: 12, color: MarketColors.textSecondary),
            ),
        ],
      ),
    );
    final content = LayoutBuilder(
      builder: (context, box) => ListView(
        padding: EdgeInsets.symmetric(
          horizontal: box.maxWidth > 1100 ? (box.maxWidth - 1100) / 2 + 16 : 16,
          vertical: 24,
        ),
        children: [
          Text(
            widget.requiredAddress
                ? 'حدد عنوانك قبل ما تبدأ التسوق'
                : 'عنوان التوصيل',
            style: TextStyle(
              fontSize: box.maxWidth > 768 ? 34 : 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'حدد باب البيت على الخريطة، وبعدها اكتب التفاصيل اللي تساعد المندوب. مش لازم تسمح بالموقع — الخريطة بتبدأ من فرع المعداوي الأساسي.',
            style: TextStyle(color: MarketColors.textSecondary),
          ),
          const SizedBox(height: 24),
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

class AddressesPage extends StatefulWidget {
  const AddressesPage({super.key});
  @override
  State<AddressesPage> createState() => _AddressesPageState();
}

class _AddressesPageState extends State<AddressesPage> {
  int refresh = 0;
  Future<void> edit([JsonMap? a]) async {
    await open(context, AddressPage(existing: a));
    if (mounted) setState(() => refresh++);
  }

  @override
  Widget build(BuildContext context) => PageFrame(
    'عناوين التوصيل',
    LoadView<List<JsonMap>>(
      key: ValueKey(refresh),
      load: market.addresses,
      builder: (data) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton.icon(
            onPressed: () => edit(),
            icon: const Icon(Icons.add_location_alt),
            label: const Text('إضافة عنوان'),
          ),
          ...data.map(
            (a) => panel(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${a['address']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (a['is_default'] == true)
                    const Chip(label: Text('عنوان التوصيل الحالي')),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: () => edit(a),
                        child: const Text('تعديل'),
                      ),
                      ActionButton('اختيار للتوصيل', () async {
                        await market.rpc('set_default_customer_address', {
                          'p_address_id': a['id'],
                        });
                        await market.load();
                        if (mounted) setState(() => refresh++);
                      }),
                      IconButton(
                        tooltip: 'حذف العنوان',
                        onPressed: () async {
                          final yes = await showDialog<bool>(
                            context: context,
                            builder: (c) => AlertDialog(
                              title: const Text('حذف العنوان؟'),
                              content: Text('${a['address']}'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(c, false),
                                  child: const Text('رجوع'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(c, true),
                                  child: const Text('حذف'),
                                ),
                              ],
                            ),
                          );
                          if (yes == true && context.mounted) {
                            await perform(context, () async {
                              await market.db
                                  .from('customer_addresses')
                                  .delete()
                                  .eq('id', a['id'])
                                  .eq('user_id', market.user!.id);
                              await market.load();
                              if (mounted) setState(() => refresh++);
                            });
                          }
                        },
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
