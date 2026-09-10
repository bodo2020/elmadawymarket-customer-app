import 'package:flutter/material.dart';
import 'models.dart';
import 'store.dart';
export 'models.dart';
export 'store.dart';

late MarketStore market;
Future<T?> open<T>(BuildContext context, Widget page) =>
    Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => page));
void message(BuildContext context, String text) {
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

Future<bool> perform(
  BuildContext context,
  Future<void> Function() action, {
  String? success,
}) async {
  try {
    await action();
    if (success != null && context.mounted) message(context, success);
    return true;
  } catch (e) {
    if (context.mounted) message(context, friendlyError(e));
    return false;
  }
}

Widget photo(String url, {double? height, double? width}) => url.isEmpty
    ? SizedBox(
        height: height,
        width: width,
        child: const Icon(
          Icons.shopping_basket_outlined,
          size: 48,
          color: Colors.grey,
        ),
      )
    : Image.network(
        url,
        height: height,
        width: width,
        fit: BoxFit.contain,
        frameBuilder: (context, child, frame, sync) => AnimatedOpacity(
          opacity: sync || frame != null ? 1 : 0,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 180),
          child: child,
        ),
        errorBuilder: (_, e, s) => SizedBox(
          height: height,
          width: width,
          child: const Icon(
            Icons.image_not_supported_outlined,
            color: Colors.grey,
          ),
        ),
      );
Widget heading(String text) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 16),
  child: Text(
    text,
    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
  ),
);
Widget panel(Widget child) => Card(
  child: Padding(padding: const EdgeInsets.all(16), child: child),
);

class PageFrame extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget>? actions;
  const PageFrame(this.title, this.child, {super.key, this.actions});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title), actions: actions),
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: child,
        ),
      ),
    ),
  );
}

class LoadView<T> extends StatefulWidget {
  final Future<T> Function() load;
  final Widget Function(T) builder;
  const LoadView({super.key, required this.load, required this.builder});
  @override
  State<LoadView<T>> createState() => _LoadViewState<T>();
}

class _LoadViewState<T> extends State<LoadView<T>> {
  late Future<T> future;
  @override
  void initState() {
    super.initState();
    future = widget.load();
  }

  @override
  void didUpdateWidget(covariant LoadView<T> old) {
    super.didUpdateWidget(old);
    if (old.key != widget.key) future = widget.load();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: future,
    builder: (context, s) {
      if (s.connectionState != ConnectionState.done) {
        return const LoadingSurface();
      }
      if (s.hasError) {
        return StatusSurface(
          title: 'تعذّر تحميل المحتوى',
          message: friendlyError(s.error!),
          icon: Icons.wifi_off_rounded,
          action: TextButton.icon(
            onPressed: () => setState(() {
              future = widget.load();
            }),
            icon: const Icon(Icons.refresh),
            label: const Text('حاول مرة تانية'),
          ),
        );
      }
      return RefreshIndicator(
        onRefresh: () async {
          setState(() {
            future = widget.load();
          });
          await future;
        },
        child: widget.builder(s.data as T),
      );
    },
  );
}

class ActionButton extends StatefulWidget {
  final String label;
  final Future<void> Function() action;
  final IconData? icon;
  final bool enabled;
  const ActionButton(
    this.label,
    this.action, {
    super.key,
    this.icon,
    this.enabled = true,
  });
  @override
  State<ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<ActionButton> {
  bool busy = false;
  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: busy || !widget.enabled
        ? null
        : () async {
            setState(() => busy = true);
            await perform(context, widget.action);
            if (mounted) setState(() => busy = false);
          },
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, size: 18),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(widget.label, textAlign: TextAlign.center),
                ),
              ],
            ),
    ),
  );
}

class EmptyView extends StatelessWidget {
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;
  const EmptyView(this.text, {super.key, this.actionLabel, this.onAction});
  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
    children: [
      StatusSurface(
        title: text,
        message: 'هتلاقي اختياراتك وتحديثاتها هنا.',
        icon: Icons.shopping_bag_outlined,
        action: onAction == null
            ? null
            : FilledButton(
                onPressed: onAction,
                child: Text(actionLabel ?? 'متابعة'),
              ),
      ),
    ],
  );
}

class StatusSurface extends StatelessWidget {
  final String title, message;
  final IconData icon;
  final Widget? action;
  const StatusSurface({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    this.action,
  });
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xffeaf3ed),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Icon(icon, size: 30, color: const Color(0xff005931)),
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xff63736a),
                  ),
                ),
                if (action != null) ...[const SizedBox(height: 16), action!],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class LoadingSurface extends StatelessWidget {
  const LoadingSurface({super.key});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      if (box.hasBoundedHeight && box.maxHeight < 180) {
        return const Center(
          child: SizedBox(
            width: 80,
            child: LinearProgressIndicator(minHeight: 3),
          ),
        );
      }
      return const StatusSurface(
        title: 'لحظة واحدة',
        message: 'بنجهّز المحتوى…',
        icon: Icons.hourglass_top_rounded,
        action: LinearProgressIndicator(minHeight: 3),
      );
    },
  );
}

class AmountRow extends StatelessWidget {
  final String label, value;
  final bool emphasized;
  const AmountRow(this.label, this.value, {super.key, this.emphasized = false});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: emphasized ? const Color(0xffeaf3ed) : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      runSpacing: 6,
      spacing: 18,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: emphasized ? 20 : 15,
            fontWeight: FontWeight.w700,
            color: const Color(0xff005931),
          ),
        ),
      ],
    ),
  );
}

double productCardHeight(BuildContext context) =>
    340 + (MediaQuery.textScalerOf(context).scale(14) - 14) * 13;
SliverGridDelegate productGrid(BuildContext context) =>
    SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: MediaQuery.textScalerOf(context).scale(14) > 21
          ? 400
          : 240,
      mainAxisExtent: productCardHeight(context),
      crossAxisSpacing: 4,
      mainAxisSpacing: 8,
    );
