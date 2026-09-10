import 'package:flutter/material.dart';
import 'design.dart';
import 'models.dart';
import 'store.dart';
export 'models.dart';
export 'store.dart';

late MarketStore market;
final ValueNotifier<int> shellTabIndex = ValueNotifier<int>(0);

void openShellTab(BuildContext context, int index) {
  shellTabIndex.value = index;
  Navigator.of(context).popUntil((route) => route.isFirst);
}

Future<T?> open<T>(BuildContext context, Widget page) =>
    Navigator.of(context).push<T>(
      PageRouteBuilder<T>(
        pageBuilder: (_, animation, secondaryAnimation) => page,
        transitionDuration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 220),
        reverseTransitionDuration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 200),
        transitionsBuilder: (_, animation, secondaryAnimation, child) {
          final eased = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: eased,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(-.025, .015),
                end: Offset.zero,
              ).animate(eased),
              child: child,
            ),
          );
        },
      ),
    );
void message(BuildContext context, String text) {
  if (context.mounted) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.info_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: MarketSpace.sm),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
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

Widget photo(String url, {double? height, double? width}) => Container(
  height: height,
  width: width,
  color: MarketColors.background,
  alignment: Alignment.center,
  child: url.isEmpty
      ? const Icon(
          Icons.shopping_basket_outlined,
          size: 44,
          color: MarketColors.textTertiary,
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
                : const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: child,
          ),
          errorBuilder: (_, e, s) => const Icon(
            Icons.image_not_supported_outlined,
            size: 36,
            color: MarketColors.textTertiary,
          ),
        ),
);
Widget heading(String text) => Padding(
  padding: const EdgeInsets.only(top: MarketSpace.xl, bottom: MarketSpace.sm),
  child: Builder(
    builder: (context) =>
        Text(text, style: Theme.of(context).textTheme.headlineSmall),
  ),
);
Widget panel(Widget child) => Card(
  child: Padding(padding: const EdgeInsets.all(MarketSpace.md), child: child),
);

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  const SectionHeader(
    this.title, {
    super.key,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: MarketSpace.xl, bottom: MarketSpace.sm),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              if (subtitle != null) ...[
                const SizedBox(height: MarketSpace.xxs),
                Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
        if (onAction != null)
          TextButton(
            onPressed: onAction,
            child: Text(actionLabel ?? 'عرض الكل'),
          ),
      ],
    ),
  );
}

class PageFrame extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget>? actions;
  final Widget? bottom;
  const PageFrame(
    this.title,
    this.child, {
    super.key,
    this.actions,
    this.bottom,
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(title),
      actions: actions,
      leading: Navigator.of(context).canPop()
          ? Padding(
              padding: const EdgeInsets.all(6),
              child: IconButton.filledTonal(
                tooltip: 'رجوع',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
            )
          : null,
    ),
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: child,
        ),
      ),
    ),
    bottomNavigationBar: bottom ?? const MarketRouteBottomBar(),
  );
}

class MarketRouteBottomBar extends StatelessWidget {
  const MarketRouteBottomBar({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <({IconData icon, String label})>[
      (icon: Icons.home_outlined, label: 'الرئيسية'),
      (icon: Icons.grid_view_outlined, label: 'الأقسام'),
      (icon: Icons.shopping_cart_outlined, label: 'السلة'),
      (icon: Icons.person_outline_rounded, label: 'حسابي'),
    ];
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: Container(
        constraints: BoxConstraints(
          minHeight: 66 + (MediaQuery.textScalerOf(context).scale(12) - 12) * 4,
        ),
        decoration: BoxDecoration(
          color: MarketColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: MarketColors.divider),
          boxShadow: const [
            BoxShadow(
              color: Color(0x16000000),
              blurRadius: 18,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: InkWell(
                  onTap: () => openShellTab(context, i),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Badge(
                          isLabelVisible: i == 2 && market.cart.isNotEmpty,
                          backgroundColor: MarketColors.primary,
                          label: Text('${market.cart.length}'),
                          child: Icon(
                            items[i].icon,
                            color: MarketColors.textSecondary,
                            size: 23,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          items[i].label,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: MarketColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
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
  final bool danger;
  const ActionButton(
    this.label,
    this.action, {
    super.key,
    this.icon,
    this.enabled = true,
    this.danger = false,
  });
  @override
  State<ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<ActionButton> {
  bool busy = false;
  @override
  Widget build(BuildContext context) => FilledButton(
    style: widget.danger
        ? FilledButton.styleFrom(
            backgroundColor: MarketColors.error,
            foregroundColor: Colors.white,
          )
        : null,
    onPressed: busy || !widget.enabled
        ? null
        : () async {
            setState(() => busy = true);
            await perform(context, widget.action);
            if (mounted) setState(() => busy = false);
          },
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: MarketSpace.xs),
      child: busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
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
    padding: const EdgeInsets.symmetric(
      vertical: 40,
      horizontal: MarketSpace.lg,
    ),
    children: [
      StatusSurface(
        title: text,
        message: 'ابدأ اختار اللي محتاجه وهتلاقيه هنا.',
        icon: Icons.shopping_basket_outlined,
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
            padding: const EdgeInsets.all(MarketSpace.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: MarketColors.primarySurface,
                    borderRadius: BorderRadius.circular(
                      MarketRadius.extraLarge,
                    ),
                  ),
                  child: Icon(icon, size: 32, color: MarketColors.primary),
                ),
                const SizedBox(height: MarketSpace.md),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: MarketSpace.xs),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (action != null) ...[
                  const SizedBox(height: MarketSpace.md),
                  action!,
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class LoadingSurface extends StatefulWidget {
  const LoadingSurface({super.key});
  @override
  State<LoadingSurface> createState() => _LoadingSurfaceState();
}

class _LoadingSurfaceState extends State<LoadingSurface>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      lowerBound: .45,
      upperBound: 1,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      if (box.hasBoundedHeight && box.maxHeight < 180) {
        return const Padding(
          padding: EdgeInsets.all(MarketSpace.md),
          child: _Skeleton(height: 44, radius: MarketRadius.medium),
        );
      }
      return FadeTransition(
        opacity: MediaQuery.disableAnimationsOf(context)
            ? const AlwaysStoppedAnimation(1)
            : controller,
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(MarketSpace.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: const [
                _Skeleton(height: 54, radius: MarketRadius.large),
                SizedBox(height: MarketSpace.md),
                _Skeleton(height: 176, radius: MarketRadius.extraLarge),
                SizedBox(height: MarketSpace.xl),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: _Skeleton(
                    height: 24,
                    width: 150,
                    radius: MarketRadius.small,
                  ),
                ),
                SizedBox(height: MarketSpace.md),
                Row(
                  children: [
                    Expanded(
                      child: _Skeleton(height: 180, radius: MarketRadius.large),
                    ),
                    SizedBox(width: MarketSpace.sm),
                    Expanded(
                      child: _Skeleton(height: 180, radius: MarketRadius.large),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _Skeleton extends StatelessWidget {
  final double height;
  final double? width;
  final double radius;
  const _Skeleton({required this.height, this.width, required this.radius});
  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: const Color(0xffeceeec),
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

class StickyBottomCTA extends StatelessWidget {
  final Widget child;
  const StickyBottomCTA({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(
      MarketSpace.md,
      MarketSpace.sm,
      MarketSpace.md,
      MarketSpace.sm,
    ),
    decoration: const BoxDecoration(
      color: MarketColors.surface,
      border: Border(top: BorderSide(color: MarketColors.divider)),
    ),
    child: SafeArea(top: false, child: child),
  );
}

class AmountRow extends StatelessWidget {
  final String label, value;
  final bool emphasized;
  const AmountRow(this.label, this.value, {super.key, this.emphasized = false});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: MarketSpace.md,
      vertical: MarketSpace.sm,
    ),
    decoration: BoxDecoration(
      color: emphasized ? MarketColors.primarySurface : Colors.transparent,
      borderRadius: BorderRadius.circular(MarketRadius.large),
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
            color: MarketColors.primary,
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
      crossAxisSpacing: MarketSpace.sm,
      mainAxisSpacing: MarketSpace.sm,
    );
