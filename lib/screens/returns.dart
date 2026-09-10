import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../core/design.dart';
import '../core/ui.dart';
import 'account.dart';

class ReturnsPage extends StatefulWidget {
  const ReturnsPage({super.key});

  @override
  State<ReturnsPage> createState() => _ReturnsPageState();
}

class _ReturnsPageState extends State<ReturnsPage> {
  int revision = 0;
  String filter = 'all';

  String _state(JsonMap request) => '${request['status'] ?? 'pending'}';

  @override
  Widget build(BuildContext context) => PageFrame(
    'طلبات الاسترجاع',
    LoadView<List<JsonMap>>(
      key: ValueKey(revision),
      load: () async => await market.db
          .from('return_requests')
          .select()
          .eq('user_id', market.user!.id)
          .order('created_at', ascending: false),
      builder: (data) {
        final pending = data.where((r) => _state(r) == 'pending').length;
        final approved = data
            .where((r) => ['approved', 'accepted'].contains(_state(r)))
            .length;
        final rejected = data
            .where((r) => ['rejected', 'declined'].contains(_state(r)))
            .length;
        final visible = filter == 'all'
            ? data
            : data.where((r) {
                final value = _state(r);
                if (filter == 'approved') {
                  return ['approved', 'accepted'].contains(value);
                }
                if (filter == 'rejected') {
                  return ['rejected', 'declined'].contains(value);
                }
                return value == 'pending';
              }).toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: MarketColors.primarySurface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: MarketColors.primaryLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.assignment_return_outlined,
                        color: MarketColors.primary,
                        size: 31,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'طلبات الاسترجاع',
                              style: TextStyle(
                                color: MarketColors.primary,
                                fontSize: 23,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'تابع طلباتك من وقت الإرسال لحد قرار المراجعة، وشوف المنتجات والملاحظات والصور في مكان واحد.',
                              style: TextStyle(
                                color: MarketColors.textSecondary,
                                height: 1.7,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => setState(() => revision++),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('تحديث'),
                      ),
                      OutlinedButton(
                        onPressed: () {},
                        child: const Text('طلباتي'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _ReturnStat(
                          'قيد المراجعة',
                          '$pending',
                          MarketColors.warning,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ReturnStat(
                          'مقبولة',
                          '$approved',
                          MarketColors.success,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ReturnStat(
                          'مرفوضة',
                          '$rejected',
                          MarketColors.error,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('الكل'),
                  selected: filter == 'all',
                  onSelected: (_) => setState(() => filter = 'all'),
                ),
                ChoiceChip(
                  label: const Text('قيد المراجعة'),
                  selected: filter == 'pending',
                  onSelected: (_) => setState(() => filter = 'pending'),
                ),
                ChoiceChip(
                  label: const Text('مقبولة'),
                  selected: filter == 'approved',
                  onSelected: (_) => setState(() => filter = 'approved'),
                ),
                ChoiceChip(
                  label: const Text('مرفوضة'),
                  selected: filter == 'rejected',
                  onSelected: (_) => setState(() => filter = 'rejected'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (visible.isEmpty)
              const StatusSurface(
                title: 'مفيش طلبات استرجاع في القسم ده',
                message: 'طلبات الاسترجاع وحالتها هتظهر هنا.',
                icon: Icons.assignment_return_outlined,
              )
            else
              ...visible.map((request) => _ReturnRequestCard(request)),
          ],
        );
      },
    ),
  );
}

class _ReturnStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _ReturnStat(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: [
        Icon(Icons.circle_outlined, color: color, size: 19),
        const SizedBox(height: 5),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 10,
            color: MarketColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _ReturnRequestCard extends StatelessWidget {
  final JsonMap request;
  const _ReturnRequestCard(this.request);

  @override
  Widget build(BuildContext context) {
    final rawStatus = '${request['status'] ?? 'pending'}';
    final rejected = ['rejected', 'declined'].contains(rawStatus);
    final approved = ['approved', 'accepted'].contains(rawStatus);
    final color = rejected
        ? MarketColors.error
        : approved
        ? MarketColors.success
        : MarketColors.warning;
    final label = rejected
        ? 'مرفوضة'
        : approved
        ? 'مقبولة'
        : 'قيد المراجعة';
    final id = '${request['id'] ?? ''}';
    final shortId = id.length > 8
        ? id.substring(0, 8).toUpperCase()
        : id.toUpperCase();
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'طلب استرجاع',
              style: TextStyle(fontSize: 12, color: MarketColors.textTertiary),
            ),
            SelectableText(
              '#$shortId',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            Text(
              displayDate(request['created_at']),
              style: const TextStyle(
                fontSize: 11,
                color: MarketColors.textSecondary,
              ),
            ),
            const SizedBox(height: 13),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withValues(alpha: .16)),
              ),
              child: Row(
                children: [
                  Icon(
                    rejected
                        ? Icons.cancel_outlined
                        : approved
                        ? Icons.check_circle_outline
                        : Icons.schedule_rounded,
                    color: color,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          approved
                              ? 'تمت الموافقة على طلب الاسترجاع.'
                              : rejected
                              ? 'تعذر قبول طلب الاسترجاع.'
                              : 'استلمنا طلبك وفريقنا يراجع المنتجات والسبب.',
                          style: TextStyle(color: color, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 13),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: MarketColors.surfaceSecondary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'سبب الاسترجاع',
                    style: TextStyle(
                      fontSize: 11,
                      color: MarketColors.textTertiary,
                    ),
                  ),
                  Text(
                    '${request['reason'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (request['admin_notes'] != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'ملاحظة المراجعة: ${request['admin_notes']}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: MarketColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text(
                'عرض المنتجات والصور',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              children: [
                LoadView<List<JsonMap>>(
                  load: () async => await market.db
                      .from('return_request_items')
                      .select('*,products(name)')
                      .eq('return_request_id', request['id']),
                  builder: (items) => Column(
                    children: items
                        .map(
                          (item) => ListTile(
                            leading: const Icon(Icons.inventory_2_outlined),
                            title: Text(
                              '${row(item['products'])['name'] ?? 'منتج'}',
                            ),
                            trailing: Text('× ${item['quantity']}'),
                          ),
                        )
                        .toList(),
                  ),
                ),
                ...((request['images'] as List?) ?? []).map(
                  (url) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: photo('$url', height: 180),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ReturnFormPage extends StatefulWidget {
  final JsonMap order;
  const ReturnFormPage(this.order, {super.key});
  @override
  State<ReturnFormPage> createState() => _ReturnFormPageState();
}

class _ReturnFormPageState extends State<ReturnFormPage> {
  final reason = TextEditingController();
  final selected = <String, TextEditingController>{};
  final images = <XFile>[];
  bool submitted = false;
  @override
  void dispose() {
    reason.dispose();
    for (final c in selected.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> pick(ImageSource source) async {
    if (images.length >= 5) {
      message(context, 'الحد الأقصى ٥ صور');
      return;
    }
    final file = await ImagePicker().pickImage(source: source);
    if (file == null) return;
    final ext = file.name.split('.').last.toLowerCase();
    if (!{'jpg', 'jpeg', 'png', 'webp', 'gif'}.contains(ext) ||
        await file.length() > 5 * 1024 * 1024) {
      if (mounted) {
        message(
          context,
          'استخدم صورة JPG أو PNG أو WEBP أو GIF أقل من ٥ ميجابايت',
        );
      }
      return;
    }
    if (mounted) setState(() => images.add(file));
  }

  Future<void> submit() async {
    if (submitted) return;
    if (reason.text.trim().length < 3 || selected.isEmpty) {
      message(context, 'حدد منتج واحد على الأقل واكتب سبب الاسترجاع');
      return;
    }
    final source = normalizeOrderItems(widget.order['items']);
    final payload = <JsonMap>[];
    for (final entry in selected.entries) {
      final value = double.tryParse(entry.value.text);
      final item = source.firstWhere(
        (e) => '${e['product_id'] ?? e['id']}' == entry.key,
      );
      if (value == null || value <= 0 || value > number(item['quantity'])) {
        message(context, 'راجع كمية الاسترجاع');
        return;
      }
      payload.add({'product_id': entry.key, 'quantity': value, 'reason': ''});
    }
    final urls = <String>[], paths = <String>[];
    bool dispatched = false;
    try {
      for (final file in images) {
        final ext = file.name.split('.').last.toLowerCase();
        final contentType = 'image/${ext == 'jpg' ? 'jpeg' : ext}';
        final path =
            '${market.user!.id}/${widget.order['id']}/${const Uuid().v4()}.$ext';
        await market.db.storage
            .from('returns')
            .uploadBinary(
              path,
              await file.readAsBytes(),
              fileOptions: FileOptions(contentType: contentType),
            );
        paths.add(path);
        urls.add(market.db.storage.from('returns').getPublicUrl(path));
      }
      dispatched = true;
      await market.rpc('create_customer_return_request', {
        'p_order_id': widget.order['id'],
        'p_reason': reason.text.trim(),
        'p_items': payload,
        'p_images': urls,
      });
      submitted = true;
      if (mounted) {
        message(context, 'طلب الاسترجاع اتبعت');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ReturnsPage()),
        );
      }
    } catch (e) {
      if (!dispatched && paths.isNotEmpty) {
        await market.db.storage.from('returns').remove(paths);
      }
      if (dispatched) {
        submitted = true;
        if (mounted) {
          message(
            context,
            'راجع طلبات الاسترجاع قبل الإرسال مرة أخرى؛ ممكن الطلب يكون اتسجل.',
          );
        }
      }
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) => PageFrame(
    'طلب استرجاع',
    ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(MarketSpace.lg),
      children: [
        heading('اختار المنتجات والكميات'),
        ...normalizeOrderItems(widget.order['items']).map((item) {
          final id = '${item['product_id'] ?? item['id']}';
          return panel(
            Column(
              children: [
                CheckboxListTile(
                  value: selected.containsKey(id),
                  title: Text('${item['name']}'),
                  subtitle: Text('كمية الطلب: ${item['quantity']}'),
                  onChanged: submitted
                      ? null
                      : (value) => setState(() {
                          if (value == true) {
                            selected[id] = TextEditingController(
                              text: number(item['quantity']) < 1
                                  ? '${item['quantity']}'
                                  : '1',
                            );
                          } else {
                            selected.remove(id)?.dispose();
                          }
                        }),
                ),
                if (selected.containsKey(id))
                  TextField(
                    controller: selected[id],
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'كمية الاسترجاع',
                    ),
                  ),
              ],
            ),
          );
        }),
        TextField(
          controller: reason,
          maxLines: 3,
          maxLength: 1000,
          decoration: const InputDecoration(labelText: 'سبب الاسترجاع'),
        ),
        Wrap(
          children: [
            TextButton.icon(
              onPressed: () =>
                  perform(context, () => pick(ImageSource.gallery)),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('إضافة صورة'),
            ),
            TextButton.icon(
              onPressed: () => perform(context, () => pick(ImageSource.camera)),
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('التقاط صورة'),
            ),
          ],
        ),
        ...images.map(
          (file) => ListTile(
            title: Text(file.name),
            trailing: IconButton(
              tooltip: 'إزالة الصورة',
              onPressed: () => setState(() => images.remove(file)),
              icon: const Icon(Icons.close),
            ),
          ),
        ),
        ActionButton('إرسال طلب الاسترجاع', submit),
        if (submitted)
          TextButton(
            onPressed: () => open(context, const ReturnsPage()),
            child: const Text('مراجعة طلبات الاسترجاع'),
          ),
      ],
    ),
  );
}
