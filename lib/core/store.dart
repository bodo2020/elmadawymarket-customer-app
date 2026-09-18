import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'models.dart';

class MarketStore extends ChangeNotifier {
  final SupabaseClient db;
  final SharedPreferences prefs;
  MarketStore(this.db, this.prefs);
  JsonMap? profile, address, runtime;
  List<CartLine> cart = [];
  bool loading = true, saving = false, cartReady = false;
  String? error;
  int generation = 0;
  StreamSubscription<AuthState>? subscription;
  Future<void> _queue = Future.value();
  User? get user => db.auth.currentUser;
  String get owner => user?.id ?? 'guest';
  String get cartKey => 'cart:$owner';
  Future<dynamic> rpc(String name, [JsonMap args = const {}]) =>
      db.rpc(name, params: args);
  Future<void> start() async {
    subscription = db.auth.onAuthStateChange.listen((event) {
      if (event.event == AuthChangeEvent.signedIn ||
          event.event == AuthChangeEvent.signedOut) {
        unawaited(load());
      }
    });
    await load();
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    final run = ++generation, uid = user?.id;
    loading = true;
    cartReady = false;
    error = null;
    profile = null;
    address = null;
    runtime = null;
    cart = [];
    notifyListeners();
    try {
      await _queue;
      JsonMap? p, a, r;
      if (uid != null) {
        p = await db
            .from('customers')
            .select()
            .eq('user_id', uid)
            .maybeSingle();
        final all = await addresses();
        final valid = all.where(
          (e) =>
              e['is_deliverable'] == true &&
              e['latitude'] != null &&
              e['longitude'] != null,
        );
        if (valid.isNotEmpty) a = valid.first;
      } else {
        final raw = prefs.getString('guest_address');
        if (raw != null) a = row(jsonDecode(raw));
      }
      if (a != null) {
        final match = await resolve(
          number(a['latitude']),
          number(a['longitude']),
        );
        r = row(
          await rpc('get_customer_branch_runtime', {
            'p_branch_id': match['branch_id'],
          }),
        );
      }
      if (run != generation) return;
      profile = p;
      address = a;
      runtime = r;
      List<CartLine> next = [];
      final pending = prefs.getString('cart:${uid ?? 'guest'}');
      if (pending != null) {
        next = decodeCart(pending);
      } else if (uid != null && p != null && r != null) {
        final saved = await db
            .from('cart_items')
            .select()
            .eq('customer_id', p['id']);
        final products = await _restoreCartProducts(saved, r);
        for (final item in saved) {
          final matches = products.where((e) => e['id'] == item['product_id']);
          if (matches.isNotEmpty) {
            next.add(
              CartLine(
                Product(matches.first),
                number(item['quantity']).toInt(),
                bulk: row(item['metadata'])['is_bulk'] == true,
              ),
            );
          }
        }
      }
      if (uid != null && prefs.getString('cart:guest') != null) {
        final guest = decodeCart(prefs.getString('cart:guest'));
        final merged = {for (final e in next) e.key: e};
        for (final e in guest) {
          final old = merged[e.key];
          merged[e.key] = CartLine(
            e.product,
            e.quantity + (old?.quantity ?? 0),
            bulk: e.bulk,
          );
        }
        next = merged.values.toList();
      }
      if (r != null && next.isNotEmpty) {
        final persistedShape = next
            .map(
              (line) => {
                'product_id': line.product.id,
                'metadata': line.persistence()['metadata'],
              },
            )
            .toList();
        final products = (await _restoreCartProducts(persistedShape, r))
            .map(Product.new)
            .toList();
        next = next.expand((line) {
          final found = products.where(
            (product) =>
                product.id == line.product.id &&
                product.sourceKey == line.product.sourceKey,
          );
          if (found.isEmpty) return <CartLine>[];
          final product = found.first;
          final q = line.quantity.clamp(0, product.maxQuantity(line.bulk));
          if (q == 0 || (line.bulk && !product.bulk)) return <CartLine>[];
          return [CartLine(product, q, bulk: line.bulk)];
        }).toList();
      }
      if (run != generation) return;
      cart = next;
      cartReady = true;
      if (uid != null &&
          p != null &&
          r != null &&
          (prefs.getString('cart:guest') != null || pending != null)) {
        // Persist the merged snapshot before consuming the guest cart. A lost
        // server response must not merge the same guest quantities twice.
        final snapshot = jsonEncode(next.map((e) => e.toJson()).toList());
        await prefs.setString('cart:$uid', snapshot);
        await prefs.remove('cart:guest');
        await _persist(next, uid);
        if (prefs.getString('cart:$uid') == snapshot) {
          await prefs.remove('cart:$uid');
        }
      }
    } catch (e) {
      if (run == generation) error = friendlyError(e);
    } finally {
      if (run == generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<List<JsonMap>> addresses() async {
    if (user == null) return [];
    return await db
        .from('customer_addresses')
        .select()
        .eq('user_id', user!.id)
        .order('is_default', ascending: false)
        .order('updated_at', ascending: false);
  }

  Future<JsonMap> resolve(double lat, double lng) async {
    final matches = rows(
      await rpc('find_delivery_branch', {
        'p_latitude': lat,
        'p_longitude': lng,
      }),
    );
    if (matches.isEmpty) throw StateError('DELIVERY_UNAVAILABLE');
    final match = matches.first;
    final route = await road('${match['branch_id']}', lat, lng);
    return {...match, ...route};
  }

  Future<JsonMap> road(String branch, double lat, double lng) async {
    final res = await db.functions.invoke(
      'route-distance',
      body: {'branch_id': branch, 'latitude': lat, 'longitude': lng},
    );
    final route = row(res.data);
    if (route['error'] != null || route['road_distance_km'] == null) {
      throw StateError('ROUTE_DISTANCE_UNAVAILABLE');
    }
    if (route['deliverable'] != true) throw StateError('DELIVERY_UNAVAILABLE');
    return route;
  }

  Future<void> saveAddress(
    String text,
    double lat,
    double lng, {
    String? id,
  }) async {
    final match = await resolve(lat, lng);
    if (user == null) {
      await prefs.setString(
        'guest_address',
        jsonEncode({
          'address': text,
          'latitude': lat,
          'longitude': lng,
          'assigned_branch_id': match['branch_id'],
          'is_deliverable': true,
        }),
      );
    } else {
      final values = {
        'user_id': user!.id,
        'address': text,
        'latitude': lat,
        'longitude': lng,
        'governorate_id': null,
        'city_id': null,
        'area_id': null,
        'neighborhood_id': null,
        'road_distance_km': match['road_distance_km'],
        'road_duration_minutes': match['duration_minutes'],
        'road_distance_checked_at': DateTime.now().toUtc().toIso8601String(),
      };
      if (id != null) {
        await db
            .from('customer_addresses')
            .update(values)
            .eq('id', id)
            .eq('user_id', user!.id);
      } else {
        final existing = await addresses();
        final saved = await db
            .from('customer_addresses')
            .insert({...values, 'is_default': existing.isEmpty})
            .select('id')
            .single();
        await rpc('set_default_customer_address', {
          'p_address_id': saved['id'],
        });
      }
    }
    await load();
  }

  Future<List<JsonMap>> _restoreCartProducts(
    Iterable<dynamic> items,
    JsonMap branchRuntime,
  ) async {
    final values = items.map(row).toList();
    final ownedIds = values
        .where(
          (item) =>
              row(item['metadata'])['source_kind'] != 'marketplace' &&
              item['product_id'] != null,
        )
        .map((item) => item['product_id'])
        .toSet()
        .toList();

    final result = <JsonMap>[];
    if (ownedIds.isNotEmpty) {
      result.addAll(
        rows(
          await rpc('get_customer_branch_products_by_ids', {
            'p_branch_id': branchRuntime['delivery_branch_id'],
            'p_product_ids': ownedIds,
          }),
        ),
      );
    }

    final marketplace = values.where(
      (item) =>
          row(item['metadata'])['source_kind'] == 'marketplace' &&
          item['product_id'] != null &&
          row(item['metadata'])['branch_id'] != null,
    );

    final restored = await Future.wait(
      marketplace.map((item) async {
        final metadata = row(item['metadata']);
        return rows(
          await rpc('get_customer_marketplace_store_catalog_v2', {
            'p_branch_id': metadata['branch_id'],
            'p_product_id': item['product_id'],
            'p_search': null,
            'p_limit': 1,
          }),
        );
      }),
    );
    for (final rowsForItem in restored) {
      result.addAll(rowsForItem);
    }
    return result;
  }

  Future<List<Product>> catalog({JsonMap filters = const {}}) async {
    if (runtime == null || address == null) {
      throw StateError('ADDRESS_REQUIRED');
    }

    final owned = rows(
      await rpc('get_customer_branch_catalog', {
        'p_branch_id': runtime!['delivery_branch_id'],
        'p_limit': 1000,
        ...filters,
      }),
    );

    final productId = '${filters['p_product_id'] ?? ''}'.trim();
    final searchText = '${filters['p_search'] ?? ''}'.trim();
    final barcode = '${filters['p_barcode'] ?? ''}'.trim();
    final hasCategoryFilter =
        filters['p_main_category_id'] != null ||
        filters['p_subcategory_id'] != null ||
        filters['p_company_id'] != null;

    if (hasCategoryFilter && productId.isEmpty) {
      return owned.map(Product.new).toList();
    }

    final stores = rows(
      await rpc('get_customer_marketplace_stores_v1', {
        'p_latitude': address!['latitude'],
        'p_longitude': address!['longitude'],
        'p_branch_id': null,
        'p_limit': 50,
      }),
    );

    final term = barcode.isNotEmpty ? barcode : searchText;
    final marketplaceLists = await Future.wait(
      stores.map((store) async {
        return rows(
          await rpc('get_customer_marketplace_store_catalog_v2', {
            'p_branch_id': store['branch_id'],
            'p_product_id': productId.isEmpty ? null : productId,
            'p_search': term.isEmpty ? null : term,
            'p_limit': productId.isEmpty ? 500 : 1,
          }),
        );
      }),
    );

    final merged = <JsonMap>[...owned];
    final seen = <String>{
      for (final item in owned)
        if ('${item['barcode'] ?? ''}'.trim().isNotEmpty)
          'barcode:${item['barcode']}'
        else
          'id:${item['id']}',
    };

    for (final list in marketplaceLists) {
      for (final item in list) {
        final barcodeValue = '${item['barcode'] ?? ''}'.trim();
        final key = barcodeValue.isNotEmpty
            ? 'barcode:$barcodeValue'
            : 'id:${item['id']}';
        if (seen.add(key)) merged.add(item);
      }
    }

    return merged.map(Product.new).toList();
  }

  Future<void> changeCart(
    Product product,
    int quantity, {
    bool bulk = false,
  }) async {
    if (pending != null) throw StateError('PENDING_CHECKOUT');
    if (!cartReady || saving) throw StateError('CART_NOT_READY');
    if (
      quantity > 0 &&
      cart.isNotEmpty &&
      cart.first.product.sourceKey != product.sourceKey
    ) {
      throw StateError('CART_SOURCE_MIXED');
    }
    if (product.marketplace && bulk) {
      throw StateError('BULK_UNAVAILABLE');
    }
    if (quantity < 0 || quantity > product.maxQuantity(bulk)) {
      throw StateError('INSUFFICIENT_STOCK');
    }
    final line = CartLine(product, quantity, bulk: bulk);
    final next = cart.where((e) => e.key != line.key).toList();
    if (quantity > 0) next.add(line);
    cart = next;
    notifyListeners();
    await persist();
  }

  Future<void> add(Product product, {bool bulk = false, int? quantity}) async {
    final key = CartLine(product, 1, bulk: bulk).key;
    final old = cart.where((e) => e.key == key).firstOrNull;
    await changeCart(
      product,
      (old?.quantity ?? 0) +
          (quantity ?? (product.weighted ? product.step : 1)),
      bulk: bulk,
    );
  }

  Future<void> _persist(List<CartLine> values, String uid) async {
    await rpc('replace_customer_cart', {
      'p_expected_user_id': uid,
      'p_items': values.map((e) => e.persistence()).toList(),
    });
  }

  Future<void> persist() async {
    final uid = user?.id, values = List<CartLine>.from(cart), key = cartKey;
    await prefs.setString(
      key,
      jsonEncode(values.map((e) => e.toJson()).toList()),
    );
    saving = true;
    notifyListeners();
    final operation = _queue.then((_) async {
      if (uid != null && user?.id == uid && profile != null) {
        await _persist(values, uid);
        if (prefs.getString(key) ==
            jsonEncode(values.map((e) => e.toJson()).toList())) {
          await prefs.remove(key);
        }
      }
    });
    _queue = operation.catchError((Object e) {});
    try {
      await operation;
      error = null;
    } catch (e) {
      error = 'تعذر مزامنة السلة. تعديلك محفوظ على الجهاز.';
      rethrow;
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  bool get cartIsMarketplace =>
      cart.isNotEmpty && cart.first.product.marketplace;

  String? get cartMarketplaceBranchId => cartIsMarketplace
      ? cart.first.product.marketplaceBranchId
      : null;

  Future<JsonMap> cartQuote() async {
    if (address == null || cart.isEmpty) {
      throw StateError('ADDRESS_REQUIRED');
    }
    if (cartIsMarketplace) {
      final branchId = cartMarketplaceBranchId;
      if (branchId == null) throw StateError('MARKETPLACE_STORE_UNAVAILABLE');
      return row(
        await rpc('quote_marketplace_cart_v1', {
          'p_branch_id': branchId,
          'p_items': checkoutLines(cart),
          'p_latitude': address!['latitude'],
          'p_longitude': address!['longitude'],
        }),
      );
    }
    return row(
      await rpc('quote_customer_cart', {
        'p_items': checkoutLines(cart),
        'p_latitude': address!['latitude'],
        'p_longitude': address!['longitude'],
      }),
    );
  }

  Future<JsonMap> quote(List<JsonMap> items, String addressId) async {
    final a = await db
        .from('customer_addresses')
        .select('latitude,longitude')
        .eq('id', addressId)
        .eq('user_id', user!.id)
        .single();

    final pendingSource = '${pending?['source_kind'] ?? ''}';
    final marketplace =
        pendingSource == 'marketplace' ||
        (pendingSource.isEmpty && cartIsMarketplace);

    if (marketplace) {
      final branchId =
          '${pending?['p_branch_id'] ?? cartMarketplaceBranchId ?? ''}'.trim();
      if (branchId.isEmpty) throw StateError('MARKETPLACE_STORE_UNAVAILABLE');
      return row(
        await rpc('quote_marketplace_cart_v1', {
          'p_branch_id': branchId,
          'p_items': items,
          'p_latitude': a['latitude'],
          'p_longitude': a['longitude'],
        }),
      );
    }

    final q = row(
      await rpc('quote_customer_order', {
        'p_items': items,
        'p_address_id': addressId,
      }),
    );
    await road(
      '${q['branch_id']}',
      number(a['latitude']),
      number(a['longitude']),
    );
    return q;
  }

  JsonMap? get pending {
    final raw = prefs.getString('checkout:$owner');
    return raw == null ? null : row(jsonDecode(raw));
  }

  Future<JsonMap> reconcile() async {
    final value = pending;
    if (value == null) return {};
    return row(
      await rpc('reconcile_customer_checkout_attempt', {
        'p_request_id': value['p_request_id'],
      }),
    );
  }

  Future<void> forgetPending() async {
    await prefs.remove('checkout:$owner');
    await prefs.remove('checkout-dispatched:$owner');
    await prefs.remove('checkout-rejected:$owner');
    notifyListeners();
  }

  bool get canResetPending =>
      prefs.getBool('checkout-dispatched:$owner') != true ||
      prefs.getBool('checkout-rejected:$owner') == true;
  bool placing = false;
  Future<JsonMap> place(
    JsonMap q, {
    String method = 'cash',
    String notes = '',
    String? voucher,
    double? voucherAmount,
  }) async {
    if (placing) throw StateError('REQUEST_IN_PROGRESS');
    placing = true;
    final expectedUser = user?.id;
    void checkOwner() {
      if (expectedUser == null || user?.id != expectedUser) {
        throw StateError('AUTH_REQUIRED');
      }
    }

    try {
      checkOwner();
      var payload = pending;
      if (payload == null) {
        if (user == null || address?['id'] == null) {
          throw StateError('ADDRESS_REQUIRED');
        }
        if (cartIsMarketplace) {
          if (voucher != null && voucher.trim().isNotEmpty) {
            throw StateError('MARKETPLACE_VOUCHER_UNAVAILABLE');
          }
          final branchId = cartMarketplaceBranchId;
          if (branchId == null) {
            throw StateError('MARKETPLACE_STORE_UNAVAILABLE');
          }
          payload = {
            'source_kind': 'marketplace',
            'p_request_id': const Uuid().v4(),
            'p_branch_id': branchId,
            'p_items': checkoutLines(cart),
            'p_address_id': address!['id'],
            'p_payment_method': method,
            'p_notes': notes,
            'p_quote_token': q['quote_token'],
          };
        } else {
          payload = {
            'source_kind': 'owned',
            'p_request_id': const Uuid().v4(),
            'p_items': checkoutLines(cart),
            'p_address_id': address!['id'],
            'p_payment_method': method,
            'p_notes': notes,
            'p_quote_token': q['quote_token'],
            'p_voucher_code': voucher,
            'p_voucher_amount': voucherAmount,
          };
        }
        await prefs.setString('checkout:$owner', jsonEncode(payload));
      }
      checkOwner();
      final resolution = await reconcile();
      checkOwner();
      if (resolution['exists'] == true) {
        await _placed();
        return resolution;
      }
      final fresh = await quote(
        rows(payload['p_items']),
        '${payload['p_address_id']}',
      );
      checkOwner();
      if (fresh['quote_token'] != payload['p_quote_token']) {
        throw StateError('QUOTE_CHANGED');
      }
      await prefs.setBool('checkout-rejected:$owner', false);
      await prefs.setBool('checkout-dispatched:$owner', true);
      final sourceKind = '${payload['source_kind'] ?? 'owned'}';
      final dispatch = JsonMap.from(payload)..remove('source_kind');
      final result = row(
        await rpc(
          sourceKind == 'marketplace'
              ? 'place_marketplace_order_v1'
              : 'place_customer_order_with_voucher',
          dispatch,
        ),
      );
      checkOwner();
      await _placed();
      return result;
    } on PostgrestException catch (e) {
      if (user?.id != expectedUser) rethrow;
      if (const {
        'QUOTE_CHANGED',
        'INSUFFICIENT_STOCK',
        'PRODUCT_UNAVAILABLE',
        'PRODUCT_UNIT_CHANGED',
        'BULK_UNAVAILABLE',
        'PRICE_UNAVAILABLE',
        'INVALID_QUANTITY',
        'INVALID_CART',
        'CHECKOUT_NOT_READY',
        'ADDRESS_REQUIRED',
        'PROFILE_REQUIRED',
        'DELIVERY_UNAVAILABLE',
        'VOUCHER_NOT_FOUND',
        'VOUCHER_UNAVAILABLE',
        'VOUCHER_CUSTOMER_MISMATCH',
        'INVALID_VOUCHER_AMOUNT',
        'VOUCHER_BALANCE_CHANGED',
      }.contains(e.message)) {
        await prefs.setBool('checkout-rejected:$owner', true);
      }
      rethrow;
    } finally {
      placing = false;
    }
  }

  Future<void> _placed() async {
    cart = [];
    await prefs.setString(cartKey, '[]');
    try {
      if (user != null) await _persist([], user!.id);
    } catch (_) {
      error = 'الطلب اتسجل، لكن تعذر مزامنة تفريغ السلة.';
    }
    await forgetPending();
    notifyListeners();
  }

  Future<void> acceptReconciled() => _placed();
  Future<List<JsonMap>> purchases() async =>
      rows(await rpc('get_my_purchase_history', {'p_limit': 200}));
  Future<void> favorite(Product product, bool bulk, bool selected) async =>
      await rpc('set_customer_favorite_unit', {
        'p_product_id': product.id,
        'p_variant_id': bulk ? product.data['bulk_variant_id'] : null,
        'p_favorite': selected,
      });
}
