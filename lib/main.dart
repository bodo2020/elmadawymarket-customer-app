import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/ui.dart';
import 'core/design.dart';
import 'screens/catalog.dart';
import 'screens/auth.dart';
import 'screens/account.dart';
import 'screens/address.dart';
import 'screens/checkout.dart';

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
    authSubscription = market.db.auth.onAuthStateChange.listen((event) {
      if (event.event == AuthChangeEvent.passwordRecovery && mounted) {
        open(context, const ProfilePage());
      }
    });
  }

  @override
  void dispose() {
    authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: market,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(6),
          child: Image.asset('assets/logo.png'),
        ),
        title: InkWell(
          borderRadius: BorderRadius.circular(MarketRadius.large),
          onTap: () =>
              open(context, const CatalogPage(title: 'البحث', search: true)),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: MarketSpace.md),
            decoration: BoxDecoration(
              color: MarketColors.surfaceSecondary,
              borderRadius: BorderRadius.circular(MarketRadius.large),
              border: Border.all(color: MarketColors.border),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.search_rounded,
                  size: 21,
                  color: MarketColors.textSecondary,
                ),
                SizedBox(width: MarketSpace.sm),
                Expanded(
                  child: Text(
                    'دور على منتج أو قسم…',
                    style: TextStyle(fontSize: 13, color: Color(0xff7b817c)),
                  ),
                ),
                Icon(
                  Icons.qr_code_scanner_rounded,
                  size: 21,
                  color: MarketColors.primary,
                ),
              ],
            ),
          ),
        ),
        actions: [
          if (market.user != null)
            IconButton(
              tooltip: 'الإشعارات',
              onPressed: () => open(context, const NotificationsPage()),
              icon: const Icon(Icons.notifications_outlined),
            ),
        ],
      ),
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
                              0 => const StoreHome(),
                              1 => const CategoriesPage(),
                              2 => const CartPage(),
                              _ => const AccountPage(),
                            },
                    ),
                  ],
                ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: MarketColors.surface,
            border: Border(top: BorderSide(color: MarketColors.divider)),
            boxShadow: [
              BoxShadow(
                color: Color(0x0a000000),
                blurRadius: 12,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: NavigationBar(
            height: 72 + (MediaQuery.textScalerOf(context).scale(12) - 12) * 4,
            selectedIndex: index,
            onDestinationSelected: (value) => setState(() => index = value),
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
  );
}
