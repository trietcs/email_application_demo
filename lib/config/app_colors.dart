import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF007BFF);
  static const Color accent = Color(0xFFFFC107);
  static const Color error = Colors.redAccent;
  static const Color success = Colors.green;

  // LIGHT THEME
  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFFFFFFF); // Card, Drawer, Dialog

  static const Color lightOnPrimary =
      Colors.white; // Chữ/icon trên nền màu Primary
  static const Color lightOnBackground = Colors.black87; // Chữ/nội dung chính
  static const Color lightOnSurface =
      Colors.black87; // Chữ/icon trên nền Surface (Card, Drawer)

  static const Color lightSecondaryText = Color(
    0xFF757575,
  ); // Chữ phụ, hint text
  static const Color lightBorder = Color(0xFFE0E0E0); // Màu viền, đường kẻ
  static const Color lightUnreadBackground = Color(
    0xFFE9F2FF,
  ); // Màu nền của email chưa đọc

  // DARK THEME
  // Nền chính của ứng dụng
  static const Color darkBackground = Color(0xFF252525);
  // Nền cho Card, Drawer, Dialog
  static const Color darkSurface = Color(0xFF303030);

  // Chữ/icon trên nền màu Primary
  static const Color darkOnPrimary = Colors.white;
  // Chữ chính
  static const Color darkOnBackground = Color(0xFFF5F5F5);
  static const Color darkOnSurface = Color(0xFFF5F5F5);

  // Chữ phụ, hint text
  static const Color darkSecondaryText = Color(0xFFBDBDBD);
  // Màu viền, đường kẻ
  static const Color darkBorder = Color(0xFF424242);
  // Màu nền cho email chưa đọc
  static const Color darkUnreadBackground = Color(0xFF3D3D3D);
}
