import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../core/design.dart';
import '../core/ui.dart';
import 'account.dart';

class ReturnsPage extends StatelessWidget {
  const ReturnsPage({super.key});
  @override
  Widget build(BuildContext context) => PageFrame(
    'طلبات الاسترجاع',
    LoadView<List<JsonMap>>(
      load: () async => await market.db
          .from('return_requests')
          .select()
          .eq('user_id', market.user!.id)
          .order('created_at', ascending: false),
      builder: (data) => data.isEmpty
          ? const EmptyView('مفيش طلبات استرجاع')
          : ListView(
              padding: const EdgeInsets.all(MarketSpace.md),
              children: data
                  .map(
                    (r) => panel(
                      ExpansionTile(
                        title: Text(
                          statusLabels['${r['status']}'] ?? '${r['status']}',
                        ),
                        subtitle: Text('${r['reason']}'),
                        children: [
                          Text(displayDate(r['created_at'])),
                          if (r['admin_notes'] != null)
                            Text('${r['admin_notes']}'),
                          LoadView<List<JsonMap>>(
                            load: () async => await market.db
                                .from('return_request_items')
                                .select('*,products(name)')
                                .eq('return_request_id', r['id']),
                            builder: (items) => Column(
                              children: items
                                  .map(
                                    (i) => ListTile(
                                      title: Text(
                                        '${row(i['products'])['name'] ?? 'منتج'}',
                                      ),
                                      trailing: Text('${i['quantity']}'),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                          ...((r['images'] as List?) ?? []).map(
                            (url) => photo('$url', height: 180),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
    ),
  );
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
