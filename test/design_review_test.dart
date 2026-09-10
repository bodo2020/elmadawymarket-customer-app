import 'package:elmadawy_market/main.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:elmadawy_market/core/ui.dart';
import 'package:elmadawy_market/core/design.dart';
import 'package:elmadawy_market/screens/catalog.dart';
import 'package:elmadawy_market/screens/auth.dart';
import 'package:elmadawy_market/screens/address.dart';
import 'package:elmadawy_market/screens/account.dart';
import 'package:elmadawy_market/screens/returns.dart';
import 'package:elmadawy_market/screens/checkout.dart';

class LayoutStore extends MarketStore {
  LayoutStore(super.db, super.prefs);
  final searches = <String>[];
  @override
  User? get user => User.fromJson({
    'id': 'fixture-user',
    'aud': 'authenticated',
    'app_metadata': <String, dynamic>{},
    'user_metadata': <String, dynamic>{},
    'created_at': '2026-09-10T00:00:00Z',
  });
  @override
  Future<List<Product>> catalog({JsonMap filters = const {}}) async {
    searches.add('${filters['p_search'] ?? ''}');
    return [
      Product({
        'id': 'p',
        'name': 'منتج للاختبار',
        'price': 25,
        'quantity': 10,
      }),
    ];
  }

  @override
  Future<dynamic> rpc(String name, [JsonMap args = const {}]) async =>
      name == 'get_my_loyalty_card'
      ? {
          'name': 'بطاقة المعداوي',
          'membership_number': '1234567890',
          'points_balance': 1000,
          'redeemable_credit_egp': 50,
          'redemption_points': 100,
          'redemption_value_egp': 5,
        }
      : <JsonMap>[];
  @override
  Future<JsonMap> quote(List<JsonMap> items, String addressId) async => {
    'items': [
      {
        'name': 'منتج باسم طويل لاختبار مراجعة الطلب',
        'quantity': 2,
        'total': 50,
      },
    ],
    'subtotal': 50,
    'shipping_cost': 15,
    'total': 65,
    'quote_token': 'fixture',
  };
}

void main() {
  late LayoutStore store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = LayoutStore(
      SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        httpClient: MockClient((request) async {
          final table = request.url.pathSegments.last;
          final fixtures = <String, List<JsonMap>>{
            'main_categories': [
              {
                'id': 'category',
                'name': 'قسم باسم طويل جدًا لمنتجات المنزل والمطبخ',
                'image_url': '',
              },
            ],
            'subcategories': [
              {'id': 'sub', 'name': 'قسم فرعي طويل'},
            ],
            'companies': [
              {'id': 'company', 'name': 'شركة منتجات منزلية وأغذية'},
            ],
            'customer_addresses': [
              {
                'id': 'address',
                'address': 'شارع طويل، بيت ١٢، الدور الرابع، بجوار المدرسة',
                'is_default': true,
              },
            ],
            'order_status_history': [
              {'new_status': 'confirmed', 'created_at': '2026-09-10T10:00:00Z'},
            ],
          };
          return http.Response(
            jsonEncode(fixtures[table] ?? []),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
      await SharedPreferences.getInstance(),
    );
    market = store;
    store.loading = false;
    store.runtime = {'delivery_branch_id': 'fixture-branch'};
    store.cartReady = true;
    store.profile = {
      'id': 'fixture-user',
      'name': 'اسم مستخدم طويل لاختبار صفحة الحساب',
    };
    store.cart = [
      CartLine(
        Product({
          'id': 'p',
          'name': 'منتج للسلة باسم طويل',
          'price': 25,
          'quantity': 10,
        }),
        2,
      ),
    ];
  });
  tearDown(() {
    store.db.dispose();
    store.dispose();
  });
  Future<void> show(
    WidgetTester tester,
    Widget child,
    double width,
    double scale,
  ) async {
    tester.view.physicalSize = Size(width, 850);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(
        theme: marketTheme(),
        locale: const Locale('ar', 'EG'),
        supportedLocales: const [Locale('ar', 'EG')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(body: child),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  for (final width in [320.0, 390.0, 768.0, 1280.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('layout $width / text $scale has no overflow', (
        tester,
      ) async {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final p = Product({
          'id': 'p',
          'name': 'منتج عربي باسم طويل جدًا لاختبار المسافات والكميات',
          'price': 135.5,
          'quantity': 50,
        });
        final widgets = <Widget>[
          const SingleChildScrollView(child: HomeWelcome()),
          const AuthPage(),
          const AccountPage(),
          const HomeShell(),
          ReturnFormPage({
            'id': 'fixture',
            'items': [
              {
                'product_id': 'p',
                'name': 'اسم منتج طويل لاختبار الاسترجاع',
                'quantity': 2,
              },
            ],
          }),
          const CheckoutPage(),
          const CartPage(),
          const CatalogPage(title: 'المنتجات', search: true),
          const FavoritesPage(),
          const ReturnsPage(),
          ProductDetails(p, bulk: false),
          const CategoriesPage(),
          const CompaniesPage(),
          const ProfilePage(),
          const LoyaltyPage(),
          CategoryPage({'id': 'category', 'name': 'قسم المنتجات'}),
          const SingleChildScrollView(
            child: OrderTimeline('confirmed', orderId: 'fixture'),
          ),
          const AddressesPage(),
          const EmptyView('لا توجد نتائج مطابقة لبحثك الحالي'),
          const SizedBox(height: 70, child: LoadingSurface()),
          AmountRow(
            'الإجمالي النهائي شامل التوصيل',
            money(12345.5),
            emphasized: true,
          ),
          Builder(
            builder: (context) => SizedBox(
              width: 180,
              height: productCardHeight(context),
              child: ProductCard(p),
            ),
          ),
        ];
        for (final widget in widgets) {
          await show(tester, widget, width, scale);
          expect(
            tester.takeException(),
            isNull,
            reason: '${widget.runtimeType} at $width/$scale',
          );
          final vertical = find.byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          );
          for (
            var step = 0;
            step < 6 && vertical.evaluate().isNotEmpty;
            step++
          ) {
            await tester.drag(vertical.first, const Offset(0, -550));
            await tester.pump(const Duration(milliseconds: 400));
            expect(
              tester.takeException(),
              isNull,
              reason: '${widget.runtimeType} scrolled $step at $width/$scale',
            );
          }
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
        }
      });
    }
  }
  testWidgets('error surface recovers when retry succeeds', (tester) async {
    var count = 0;
    await show(
      tester,
      LoadView<String>(
        load: () async {
          if (count++ == 0) throw Exception('offline');
          return 'عاد المحتوى';
        },
        builder: (value) => Text(value),
      ),
      320,
      1,
    );
    await tester.tap(find.text('حاول مرة تانية'));
    await tester.pump();
    await tester.pump();
    expect(find.text('عاد المحتوى'), findsOneWidget);
  });
  testWidgets(
    'search waits for typing to pause and cancels intermediate text',
    (tester) async {
      await show(tester, const CatalogPage(title: 'بحث', search: true), 390, 1);
      store.searches.clear();
      await tester.enterText(find.byType(TextField), 'لب');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byType(TextField), 'لبن');
      await tester.pump(const Duration(milliseconds: 300));
      expect(store.searches, isEmpty);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
      expect(store.searches, ['لبن']);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
