import 'package:flutter/material.dart';

abstract final class KokColors {
  // --- Palet Warna Resmi (Dokumen Wireframe Slide 10) ---
  /// Hitam (#141414) - Teks utama, judul kartu, garis tegas
  static const textPrimary = Color(0xFF141414);
  /// Alias semantik untuk teks judul pada kartu/baris daftar
  static const cardTitle = textPrimary;

  /// Abu teks (#666666) - Keterangan sekunder, meta
  static const textSecondary = Color(0xFF666666);
  static const muted = Color(0xFF727782);

  /// Biru primer (#1B4FA0 / #1B4F9E) - Warna utama: header, tab aktif, tombol utama
  static const blue = Color(0xFF1B4F9E);
  static const bluePrimary = blue;

  /// Biru tua (#123A75) - Teks di atas biru, label penegas
  static const ink = Color(0xFF173D75);
  static const navy = Color(0xFF071B68);
  static const deepNavy = Color(0xFF0C2464);

  /// Biru sedang (#4D7FC9) - Bar data, ikon, garis aktif
  static const blueMedium = Color(0xFF4D7FC9);

  /// Biru muda (#E9F0FB) - Latar kartu terpilih, panel info
  static const pale = Color(0xFFE9F0FB);
  static const blueLight = pale;

  /// Kuning (#F2B90C) - Sorot pencarian, status perlu dilengkapi
  static const yellow = Color(0xFFF2B90C);

  /// Merah (#C62828) - Kritis: berkas kurang, lisensi kedaluwarsa
  static const red = Color(0xFFC62828);

  /// Latar belakang aplikasi umum (#F4F6FA)
  static const background = Color(0xFFF4F6FA);

  /// Abu garis (#CFCAC0 / #E5E7EB) - Batas kartu, chip pasif, pemisah
  static const borderGray = Color(0xFFE5E7EB);
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
