import 'package:flutter/material.dart';

abstract final class MarketColors {
  static const primary = Color(0xff005931);
  static const primaryPressed = Color(0xff004825);
  static const primaryDark = Color(0xff003d22);
  static const primaryLight = Color(0xffe6f2ec);
  static const primarySurface = Color(0xfff1f8f4);
  static const background = Color(0xfff7f8f7);
  static const surface = Colors.white;
  static const surfaceSecondary = Color(0xfff3f5f4);
  static const textPrimary = Color(0xff171a18);
  static const textSecondary = Color(0xff626862);
  static const textTertiary = Color(0xff8a908b);
  static const textDisabled = Color(0xffb7bcb8);
  static const border = Color(0xffe4e7e4);
  static const borderStrong = Color(0xffd1d6d2);
  static const divider = Color(0xffeceeec);
  static const success = Color(0xff15803d);
  static const successSurface = Color(0xffecfdf3);
  static const warning = Color(0xffd97706);
  static const warningSurface = Color(0xfffff7e8);
  static const error = Color(0xffd92d20);
  static const errorSurface = Color(0xfffff1f0);
  static const info = Color(0xff2563eb);
  static const infoSurface = Color(0xffeff6ff);
  static const discount = Color(0xffe53935);
  static const discountSurface = Color(0xfffff0ef);
}

abstract final class MarketSpace {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

abstract final class MarketRadius {
  static const xxs = 4.0;
  static const small = 8.0;
  static const medium = 12.0;
  static const large = 16.0;
  static const extraLarge = 20.0;
}

const brandGreen = MarketColors.primary;
const brandBackground = MarketColors.background;
const brandTint = MarketColors.primaryLight;
const brandBorder = MarketColors.border;

TextStyle _text(
  double size,
  FontWeight weight, {
  Color? color,
  double? height,
}) => TextStyle(
  fontFamily: 'Cairo',
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: height ?? 1.45,
);

ThemeData marketTheme() {
  final base = ThemeData(useMaterial3: true, fontFamily: 'Cairo');
  final colorScheme = const ColorScheme.light(
    primary: MarketColors.primary,
    onPrimary: Colors.white,
    primaryContainer: MarketColors.primaryLight,
    onPrimaryContainer: MarketColors.primaryDark,
    secondary: MarketColors.primary,
    onSecondary: Colors.white,
    secondaryContainer: MarketColors.primarySurface,
    onSecondaryContainer: MarketColors.primary,
    error: MarketColors.error,
    onError: Colors.white,
    errorContainer: MarketColors.errorSurface,
    onErrorContainer: MarketColors.error,
    surface: MarketColors.surface,
    onSurface: MarketColors.textPrimary,
    onSurfaceVariant: MarketColors.textSecondary,
    outline: MarketColors.border,
    outlineVariant: MarketColors.divider,
    surfaceTint: Colors.transparent,
    shadow: Color(0x0d000000),
  );
  final shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(MarketRadius.large),
  );

  return base.copyWith(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: MarketColors.background,
    canvasColor: MarketColors.background,
    splashFactory: InkRipple.splashFactory,
    highlightColor: MarketColors.primaryLight.withValues(alpha: .45),
    textTheme: base.textTheme
        .copyWith(
          displayLarge: _text(24, FontWeight.w700, height: 1.35),
          headlineLarge: _text(24, FontWeight.w700, height: 1.35),
          headlineMedium: _text(22, FontWeight.w700, height: 1.35),
          headlineSmall: _text(18, FontWeight.w700),
          titleLarge: _text(18, FontWeight.w700),
          titleMedium: _text(16, FontWeight.w600),
          titleSmall: _text(14, FontWeight.w600),
          bodyLarge: _text(14, FontWeight.w400),
          bodyMedium: _text(14, FontWeight.w400),
          bodySmall: _text(
            13,
            FontWeight.w400,
            color: MarketColors.textSecondary,
          ),
          labelLarge: _text(15, FontWeight.w600),
          labelMedium: _text(13, FontWeight.w600),
          labelSmall: _text(12, FontWeight.w400),
        )
        .apply(
          bodyColor: MarketColors.textPrimary,
          displayColor: MarketColors.textPrimary,
        ),
    appBarTheme: AppBarTheme(
      backgroundColor: MarketColors.background,
      foregroundColor: MarketColors.textPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      toolbarHeight: 64,
      iconTheme: const IconThemeData(size: 22, color: MarketColors.textPrimary),
      actionsIconTheme: const IconThemeData(size: 22),
      titleTextStyle: _text(20, FontWeight.w700, height: 1.35),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(44, 44),
        iconSize: 22,
        foregroundColor: MarketColors.textSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MarketRadius.medium),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(52, 52)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(
            horizontal: MarketSpace.lg,
            vertical: MarketSpace.sm,
          ),
        ),
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return const Color(0xffd8ddda);
          }
          if (states.contains(WidgetState.pressed)) {
            return MarketColors.primaryPressed;
          }
          return MarketColors.primary;
        }),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? const Color(0xff969c98)
              : Colors.white,
        ),
        overlayColor: const WidgetStatePropertyAll(Color(0x14ffffff)),
        shape: WidgetStatePropertyAll(shape),
        textStyle: WidgetStatePropertyAll(_text(15, FontWeight.w600)),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: MarketColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xffd8ddda),
        disabledForegroundColor: const Color(0xff969c98),
        minimumSize: const Size(52, 52),
        padding: const EdgeInsets.symmetric(horizontal: MarketSpace.lg),
        elevation: 0,
        shape: shape,
        textStyle: _text(15, FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: MarketColors.primary,
        minimumSize: const Size(48, 50),
        padding: const EdgeInsets.symmetric(horizontal: MarketSpace.md),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: const BorderSide(color: Color(0xffd9deda)),
        textStyle: _text(14, FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: MarketColors.primary,
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: MarketSpace.sm),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MarketRadius.medium),
        ),
        textStyle: _text(14, FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: MarketColors.surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: MarketSpace.md,
        vertical: 15,
      ),
      hintStyle: _text(14, FontWeight.w400, color: const Color(0xff7b817c)),
      labelStyle: _text(14, FontWeight.w400, color: MarketColors.textSecondary),
      floatingLabelStyle: _text(
        13,
        FontWeight.w600,
        color: MarketColors.primary,
      ),
      errorStyle: _text(12, FontWeight.w400, color: MarketColors.error),
      prefixIconColor: MarketColors.textSecondary,
      suffixIconColor: MarketColors.primary,
      border: _inputBorder(MarketColors.border),
      enabledBorder: _inputBorder(const Color(0xffe1e5e2)),
      focusedBorder: _inputBorder(MarketColors.primary, width: 1.5),
      errorBorder: _inputBorder(MarketColors.error),
      focusedErrorBorder: _inputBorder(MarketColors.error, width: 1.5),
      disabledBorder: _inputBorder(MarketColors.divider),
    ),
    cardTheme: CardThemeData(
      color: MarketColors.surface,
      surfaceTintColor: Colors.transparent,
      shadowColor: const Color(0x0d000000),
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MarketRadius.large),
        side: const BorderSide(color: MarketColors.divider),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: MarketColors.surface,
      selectedColor: MarketColors.primaryLight,
      disabledColor: MarketColors.surfaceSecondary,
      side: const BorderSide(color: Color(0xffe1e5e2)),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: MarketSpace.sm),
      labelStyle: _text(13, FontWeight.w500, color: MarketColors.textSecondary),
      secondaryLabelStyle: _text(
        13,
        FontWeight.w600,
        color: MarketColors.primary,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      backgroundColor: MarketColors.surface,
      elevation: 0,
      shadowColor: const Color(0x0d000000),
      indicatorColor: MarketColors.primaryLight,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 23,
          color: states.contains(WidgetState.selected)
              ? MarketColors.primary
              : MarketColors.textTertiary,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => _text(
          12,
          states.contains(WidgetState.selected)
              ? FontWeight.w600
              : FontWeight.w400,
          color: states.contains(WidgetState.selected)
              ? MarketColors.primary
              : MarketColors.textTertiary,
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: MarketColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MarketRadius.extraLarge),
      ),
      titleTextStyle: _text(18, FontWeight.w700),
      contentTextStyle: _text(
        14,
        FontWeight.w400,
        color: MarketColors.textSecondary,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: MarketColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 3,
      modalElevation: 3,
      showDragHandle: true,
      dragHandleColor: Color(0xffd5d9d6),
      dragHandleSize: Size(40, 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xff242724),
      elevation: 2,
      insetPadding: const EdgeInsets.all(MarketSpace.md),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      contentTextStyle: _text(13, FontWeight.w500, color: Colors.white),
      actionTextColor: const Color(0xffb9e3c9),
    ),
    dividerTheme: const DividerThemeData(
      color: MarketColors.divider,
      thickness: 1,
      space: 1,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: MarketColors.primary,
      linearTrackColor: Color(0xffeceeec),
      circularTrackColor: MarketColors.primaryLight,
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: MarketSpace.md,
        vertical: MarketSpace.xxs,
      ),
      minTileHeight: 56,
      iconColor: MarketColors.primary,
      textColor: MarketColors.textPrimary,
      titleTextStyle: _text(14, FontWeight.w600),
      subtitleTextStyle: _text(
        12,
        FontWeight.w400,
        color: MarketColors.textSecondary,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MarketRadius.large),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Colors.white
            : MarketColors.textTertiary,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? MarketColors.primary
            : MarketColors.borderStrong,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? MarketColors.primary
            : Colors.transparent,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MarketRadius.xxs),
      ),
    ),
  );
}

OutlineInputBorder _inputBorder(Color color, {double width = 1}) =>
    OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color, width: width),
    );
