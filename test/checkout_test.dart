import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:elmadawy_market/core/store.dart';
import 'package:elmadawy_market/core/models.dart';

class FakeStore extends MarketStore {
  FakeStore(super.db, super.prefs);
  @override
  User? get user => User.fromJson({
    'id': 'user-a',
    'aud': 'authenticated',
    'app_metadata': <String, dynamic>{},
    'user_metadata': <String, dynamic>{},
    'created_at': '2026-09-09T00:00:00Z',
  });
  bool fail = true, exists = false;
  String token = 'reviewed';
  final attempts = <String>[];
  Completer<void>? gate;
  @override
  Future<JsonMap> quote(List<JsonMap> items, String addressId) async => {
    'quote_token': token,
  };
  @override
  Future<dynamic> rpc(String name, [JsonMap args = const {}]) async {
    if (name == 'reconcile_customer_checkout_attempt') {
      return {'exists': exists, if (exists) 'id': 'saved-order'};
    }
    if (name == 'place_customer_order_with_voucher') {
      attempts.add(args['p_request_id']);
      if (gate != null) await gate!.future;
      if (fail) throw TimeoutException('response lost');
      return {'id': 'saved-order'};
    }
    return null;
  }
}

void main() {
  late FakeStore store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = FakeStore(
      SupabaseClient('https://example.supabase.co', 'test-key'),
      await SharedPreferences.getInstance(),
    );
    store.address = {'id': 'address-a'};
    store.cart = [
      CartLine(Product({'id': 'product-a', 'price': 10, 'quantity': 10}), 1),
    ];
  });
  test('uncertain dispatch retains UUID and cannot be reset', () async {
    await expectLater(
      store.place({'quote_token': 'reviewed'}),
      throwsA(isA<TimeoutException>()),
    );
    final first = store.pending!['p_request_id'];
    expect(store.canResetPending, false);
    store.fail = false;
    await store.place({'quote_token': 'reviewed'});
    expect(store.attempts, [first, first]);
    expect(store.pending, isNull);
    expect(store.cart, isEmpty);
  });
  test('changed quote never dispatches an unreviewed amount', () async {
    store.token = 'changed';
    await expectLater(
      store.place({'quote_token': 'reviewed'}),
      throwsStateError,
    );
    expect(store.attempts, isEmpty);
    expect(store.canResetPending, true);
  });
  test(
    'reconciliation recovers a successful lost response without placing twice',
    () async {
      await expectLater(
        store.place({'quote_token': 'reviewed'}),
        throwsA(isA<TimeoutException>()),
      );
      store.exists = true;
      final result = await store.place({'quote_token': 'reviewed'});
      expect(result['id'], 'saved-order');
      expect(store.attempts.length, 1);
      expect(store.pending, isNull);
    },
  );
  test('concurrent button calls cannot allocate two request ids', () async {
    store.fail = false;
    store.gate = Completer<void>();
    final first = store.place({'quote_token': 'reviewed'});
    await Future<void>.delayed(Duration.zero);
    await expectLater(
      store.place({'quote_token': 'reviewed'}),
      throwsStateError,
    );
    store.gate!.complete();
    await first;
    expect(store.attempts.length, 1);
  });
}
