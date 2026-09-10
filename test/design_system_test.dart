import 'package:elmadawy_market/core/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('theme exposes the approved brand tokens and component sizing', () {
    final theme = marketTheme();

    expect(theme.useMaterial3, isTrue);
    expect(theme.textTheme.bodyMedium?.fontFamily, 'Cairo');
    expect(theme.colorScheme.primary, const Color(0xff005931));
    expect(theme.scaffoldBackgroundColor, const Color(0xfff7f8f7));
    expect(theme.textTheme.headlineLarge?.fontSize, 24);
    expect(theme.textTheme.headlineLarge?.fontWeight, FontWeight.w700);
    expect(
      theme.filledButtonTheme.style?.minimumSize?.resolve(<WidgetState>{}),
      const Size(52, 52),
    );
    expect(theme.navigationBarTheme.height, 72);
    expect(theme.bottomSheetTheme.showDragHandle, isTrue);

    final cardShape = theme.cardTheme.shape! as RoundedRectangleBorder;
    expect(cardShape.borderRadius, BorderRadius.circular(MarketRadius.large));
    final dialogShape = theme.dialogTheme.shape! as RoundedRectangleBorder;
    expect(
      dialogShape.borderRadius,
      BorderRadius.circular(MarketRadius.extraLarge),
    );
  });

  testWidgets('Arabic UI stays RTL and icon buttons keep a 44px touch target', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: marketTheme(),
        locale: const Locale('ar', 'EG'),
        supportedLocales: const [Locale('ar', 'EG')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(
          body: Center(
            child: IconButton(
              onPressed: () {},
              icon: const Icon(Icons.favorite_outline_rounded),
            ),
          ),
        ),
      ),
    );

    expect(
      Directionality.of(tester.element(find.byType(IconButton))),
      TextDirection.rtl,
    );
    final size = tester.getSize(find.byType(IconButton));
    expect(size.width, greaterThanOrEqualTo(44));
    expect(size.height, greaterThanOrEqualTo(44));
  });
}
