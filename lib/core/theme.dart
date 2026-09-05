import 'package:flutter/material.dart';

abstract final class KokColors {
  static const navy = Color(0xFF071B68);
  static const blue = Color(0xFF1B4F9E);
  static const ink = Color(0xFF173D75);
  static const background = Color(0xFFF4F6FA);
  static const muted = Color(0xFF727782);
  static const pale = Color(0xFFEAF0FB);
  static const red = Color(0xFFC62828);
  static const yellow = Color(0xFFF2B90C);
}

ThemeData kokTheme() => ThemeData(
  useMaterial3: true,
  fontFamily: 'KokSans',
  colorScheme: ColorScheme.fromSeed(
    seedColor: KokColors.blue,
    primary: KokColors.blue,
    surface: Colors.white,
  ),
  scaffoldBackgroundColor: KokColors.background,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.white,
    foregroundColor: KokColors.ink,
    surfaceTintColor: Colors.transparent,
    centerTitle: false,
    titleTextStyle: TextStyle(
      fontFamily: 'KokSans',
      fontSize: 21,
      fontWeight: FontWeight.w700,
      color: Color(0xFF17191D),
    ),
  ),
  textTheme: const TextTheme(
    headlineLarge: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w700,
      color: KokColors.ink,
    ),
    titleLarge: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
    titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    bodyMedium: TextStyle(fontSize: 14, height: 1.4),
    bodySmall: TextStyle(fontSize: 12, height: 1.4, color: KokColors.muted),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFD4D8E0)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFD4D8E0)),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(48, 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(
        fontFamily: 'KokSans',
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    ),
  ),
  navigationBarTheme: const NavigationBarThemeData(
    backgroundColor: Colors.white,
    indicatorColor: KokColors.pale,
    height: 72,
    surfaceTintColor: Colors.transparent,
  ),
);
