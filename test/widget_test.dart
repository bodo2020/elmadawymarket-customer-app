import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elmadawy_market/core/ui.dart';

void main() {
  test('250 grams uses a kilogram price and integer grams in checkout', () {
    final p = Product({
      'id': 'a',
      'price': 80,
      'quantity': 2,
      'unit_of_measure': 'kg',
    });
    final line = CartLine(p, 250);
    expect(line.total, 20);
    expect(line.checkout()['quantity'], 250);
    expect(line.checkout()['unit_of_measure'], 'weight');
    expect(p.maxQuantity(false), 2000);
  });
  test('bulk units stay distinct and use pack stock', () {
    final p = Product({
      'id': 'p',
      'price': 12,
      'offer_price': 10,
      'bulk_enabled': true,
      'bulk_price': 55,
      'bulk_quantity': 6,
      'quantity': 13,
    });
    expect(p.bulk, true);
    expect(p.maxQuantity(true), 2);
    expect(CartLine(p, 2, bulk: true).total, 110);
    expect(CartLine(p, 1).key, isNot(CartLine(p, 1, bulk: true).key));
    expect(
      checkoutLines([CartLine(p, 2, bulk: true), CartLine(p, 1)]).length,
      2,
    );
  });
  test('invalid cached quantity is rejected', () {
    expect(
      () => CartLine.fromJson({
        'product': {'id': 'p'},
        'quantity': 0,
      }),
      throwsFormatException,
    );
    expect(
      () => CartLine.fromJson({
        'product': {'id': 'p'},
        'quantity': 1.5,
      }),
      throwsFormatException,
    );
  });
  test('Egypt phone normalization retains international numbers', () {
    expect(phoneNumber('01005245096'), '+201005245096');
    expect(phoneNumber('+44 12345'), '+4412345');
  });
  testWidgets('action button blocks repeated submissions while pending', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ActionButton('تأكيد', () async {
            calls++;
            await Future<void>.delayed(const Duration(seconds: 1));
          }),
        ),
      ),
    );
    await tester.tap(find.text('تأكيد'));
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.pump(const Duration(seconds: 1));
    expect(calls, 1);
  });
}
