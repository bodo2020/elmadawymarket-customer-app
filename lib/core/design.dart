import 'package:flutter/material.dart';

const brandGreen = Color(0xff005931);
const brandBackground = Color(0xfff4f7f5);
const brandTint = Color(0xfff0fdf4);
const brandBorder = Color(0xffe5e7eb);

ThemeData marketTheme() {
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
  final base = ThemeData(useMaterial3: true, fontFamily: 'Cairo');
  return base.copyWith(
    colorScheme: const ColorScheme.light(
      primary: brandGreen,
      onPrimary: Colors.white,
      secondary: brandGreen,
      onSecondary: Colors.white,
      secondaryContainer: brandTint,
      onSecondaryContainer: brandGreen,
      surface: Colors.white,
      onSurface: Color(0xff192b23),
      surfaceTint: Colors.transparent,
      outline: Color(0xffcbdcd1),
    ),
    scaffoldBackgroundColor: brandBackground,
    textTheme: base.textTheme.apply(
      bodyColor: const Color(0xff192b23),
      displayColor: const Color(0xff192b23),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: brandGreen,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      toolbarHeight: 68,
      titleTextStyle: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: brandGreen,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xfffbfdfc),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xffcbdcd1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xffcbdcd1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: brandGreen, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: brandGreen,
        foregroundColor: Colors.white,
        minimumSize: const Size(44, 48),
        shape: shape,
        textStyle: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: brandGreen,
        minimumSize: const Size(44, 48),
        shape: shape,
        side: const BorderSide(color: brandBorder),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: brandGreen,
        shape: shape,
        textStyle: const TextStyle(
          fontFamily: 'Cairo',
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.all(4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: Color(0xfff1f5f3)),
      ),
    ),
    splashFactory: InkSparkle.splashFactory,
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xff173d2b),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentTextStyle: const TextStyle(
        fontFamily: 'Cairo',
        color: Colors.white,
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: brandGreen,
      linearTrackColor: brandTint,
    ),
    dividerTheme: const DividerThemeData(color: brandBorder, thickness: 1),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: Colors.white,
      selectedColor: brandTint,
      side: const BorderSide(color: brandBorder),
      shape: shape,
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: brandTint,
    ),
  );
}
