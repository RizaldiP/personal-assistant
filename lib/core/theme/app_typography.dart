import 'package:flutter/material.dart';

/// Skala tipografi aplikasi.
///
/// Gaya dasar diambil dari [TextTheme] hasil [AppTheme]; helper di sini hanya
/// untuk variasi yang sering dipakai lintas layar.
abstract final class AppTypography {
  static TextStyle? sectionLabel(TextTheme theme) => theme.labelLarge?.copyWith(
    letterSpacing: 1.2,
    fontWeight: FontWeight.w600,
  );

  static TextStyle? titleOnSurface(TextTheme theme) =>
      theme.titleMedium?.copyWith(fontWeight: FontWeight.w600);
}
