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
          padding: const EdgeInsets.all(7),
          child: Image.asset('assets/logo.png'),
        ),
        title: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () =>
              open(context, const CatalogPage(title: 'البحث', search: true)),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xfff3f4f6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: brandBorder),
            ),
            child: const Row(
              children: [
                Icon(Icons.search, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'دور على منتج أو قسم…',
                    style: TextStyle(fontSize: 13, color: Color(0xff6b7280)),
                  ),
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
                      MaterialBanner(
                        content: Text(market.error!),
                        actions: [
                          TextButton(
                            onPressed: market.load,
                            child: const Text('إعادة المحاولة'),
                          ),
                        ],
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
        child: Container(
          height: 68 + (MediaQuery.textScalerOf(context).scale(11) - 11) * 6,
          margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: brandBorder),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1400321c),
                blurRadius: 35,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: List.generate(4, (i) {
              final selected = index == i;
              final icons = [
                Icons.home_outlined,
                Icons.grid_view,
                Icons.shopping_cart_outlined,
                Icons.person_outline,
              ];
              final labels = ['الرئيسية', 'الأقسام', 'السلة', 'الحساب'];
              return Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => index = i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        width: selected ? 56 : 44,
                        height: 32,
                        decoration: BoxDecoration(
                          color: selected ? brandTint : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Badge(
                          isLabelVisible: i == 2 && market.cart.isNotEmpty,
                          backgroundColor: brandGreen,
                          label: Text('${market.cart.length}'),
                          child: Icon(
                            icons[i],
                            size: 21,
                            color: selected
                                ? brandGreen
                                : const Color(0xff6b7280),
                          ),
                        ),
                      ),
                      Text(
                        labels[i],
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: selected
                              ? brandGreen
                              : const Color(0xff6b7280),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    ),
  );
}
