import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/ui.dart';
import 'core/design.dart';
import 'screens/catalog.dart';
import 'screens/categories_v2.dart';
import 'screens/auth.dart';
import 'screens/account_v2.dart';
import 'screens/address.dart';
import 'screens/home_v2.dart';
import 'screens/cart_v2.dart';
import 'screens/notifications_v2.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://qzvpayjaadbmpayeglon.supabase.co',
  );
  const key = String.fromEnvironment('SUPABASE_ANON_KEY');
  if (key.isEmpty) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('شغّل التطبيق بملف config.json حسب README')),
        ),
      ),
    );
    return;
  }
  await Supabase.initialize(url: url, anonKey: key);
  market = MarketStore(
    Supabase.instance.client,
    await SharedPreferences.getInstance(),
  );
  notificationsPageBuilder = (_) => const NotificationsV2Page();
  runApp(const MarketApp());
  await market.start();
}

class MarketApp extends StatelessWidget {
  const MarketApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'المعداوي ماركت',
    debugShowCheckedModeBanner: false,
    locale: const Locale('ar', 'EG'),
    supportedLocales: const [Locale('ar', 'EG')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: marketTheme(),
    home: const HomeShell(),
  );
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;
  StreamSubscription<AuthState>? authSubscription;
  @override
  void initState() {
    super.initState();
    index = shellTabIndex.value;
    shellTabIndex.addListener(_handleShellTab);
    authSubscription = market.db.auth.onAuthStateChange.listen((event) {
      if (event.event == AuthChangeEvent.passwordRecovery && mounted) {
        open(context, const ProfilePage());
      }
    });
  }

  @override
  void dispose() {
    shellTabIndex.removeListener(_handleShellTab);
    authSubscription?.cancel();
    super.dispose();
  }

  void _handleShellTab() {
    if (mounted && index != shellTabIndex.value) {
      setState(() => index = shellTabIndex.value);
    }
  }

  PreferredSizeWidget _appBar(BuildContext context) {
    if (index == 2) {
      return AppBar(
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.all(7),
          child: Image.asset('assets/logo.png'),
        ),
        title: const Text('السلة'),
        actions: const [CustomerNotificationBellV2()],
      );
    }
    if (index == 3) {
      return AppBar(
        centerTitle: true,
        title: const Text('حسابي'),
        actions: const [
          CustomerNotificationBellV2(color: MarketColors.primary),
        ],
      );
    }
    return AppBar(
      leading: Padding(
        padding: const EdgeInsets.all(7),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => shellTabIndex.value = 0,
          child: Image.asset('assets/logo.png'),
        ),
      ),
      titleSpacing: 4,
      title: _CustomerSearchBar(
        onSearch: () => open(
          context,
          const CatalogPage(title: 'البحث', search: true),
        ),
        onBarcode: () => open(context, const ScannerPage()),
      ),
      actions: const [CustomerNotificationBellV2()],
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: market,
    builder: (context, _) => Scaffold(
      appBar: _appBar(context),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: market.loading
              ? const LoadingSurface()
              : Column(
                  children: [
                    if (market.error != null)
                      Container(
                        margin: const EdgeInsets.fromLTRB(
                          MarketSpace.md,
                          MarketSpace.xs,
                          MarketSpace.md,
                          0,
                        ),
                        padding: const EdgeInsets.all(MarketSpace.sm),
                        decoration: BoxDecoration(
                          color: MarketColors.errorSurface,
                          borderRadius: BorderRadius.circular(
                            MarketRadius.medium,
                          ),
                          border: Border.all(
                            color: MarketColors.error.withValues(alpha: .18),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: MarketColors.error,
                            ),
                            const SizedBox(width: MarketSpace.sm),
                            Expanded(child: Text(market.error!)),
                            TextButton(
                              onPressed: market.load,
                              child: const Text('إعادة المحاولة'),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: market.runtime == null && index < 2
                          ? AddressPage(requiredAddress: true)
                          : switch (index) {
                              0 => const StoreHomeV2(),
                              1 => const CategoriesV2Page(),
                              2 => const CartV2Page(),
                              _ => const AccountV2Page(),
                            },
                    ),
                  ],
                ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(10, 0, 10, 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: MarketColors.surface,
              border: Border.fromBorderSide(
                BorderSide(color: MarketColors.divider),
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0x16000000),
                  blurRadius: 18,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: NavigationBar(
              height:
                  66 + (MediaQuery.textScalerOf(context).scale(12) - 12) * 4,
              selectedIndex: index,
              onDestinationSelected: (value) => shellTabIndex.value = value,
              animationDuration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 220),
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'الرئيسية',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.grid_view_outlined),
                  selectedIcon: Icon(Icons.grid_view_rounded),
                  label: 'الأقسام',
                ),
                NavigationDestination(
                  icon: Badge(
                    isLabelVisible: market.cart.isNotEmpty,
                    backgroundColor: MarketColors.discount,
                    label: Text('${market.cart.length}'),
                    child: const Icon(Icons.shopping_cart_outlined),
                  ),
                  selectedIcon: Badge(
                    isLabelVisible: market.cart.isNotEmpty,
                    backgroundColor: MarketColors.discount,
                    label: Text('${market.cart.length}'),
                    child: const Icon(Icons.shopping_cart_rounded),
                  ),
                  label: 'السلة',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.person_outline_rounded),
                  selectedIcon: Icon(Icons.person_rounded),
                  label: 'حسابي',
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _CustomerSearchBar extends StatelessWidget {
  final VoidCallback onSearch;
  final VoidCallback onBarcode;
  const _CustomerSearchBar({required this.onSearch, required this.onBarcode});

  @override
  Widget build(BuildContext context) => Container(
        height: 48,
        decoration: BoxDecoration(
          color: MarketColors.surfaceSecondary,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: MarketColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: onSearch,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: MarketColors.textTertiary,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'دور على منتج أو قسم…',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: MarketColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(width: 1, height: 28, color: MarketColors.border),
            IconButton(
              tooltip: 'البحث بالباركود',
              onPressed: onBarcode,
              icon: const Icon(
                Icons.qr_code_scanner_rounded,
                size: 20,
                color: MarketColors.primary,
              ),
            ),
          ],
        ),
      );
}
