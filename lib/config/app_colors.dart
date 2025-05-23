import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Màu chủ đạo chính
  static const Color primary = Color(0xFF007BFF);

  // Màu chữ trên nền màu chính (ví dụ: chữ trên button)
  static const Color onPrimary = Colors.white;

  // Màu chữ/icon phụ (ví dụ: màu xám cho label, icon không active)
  static const Color secondaryText = Color(0xFF757575);
  static const Color secondaryIcon = Color(0xFF757575);

  // Màu nền AppBar
  static const Color appBarBackground = Colors.white;
  static const Color appBarForeground = Colors.black87;

  // Các màu khác
  static const Color accent = Color(0xFFFFC107);
  static const Color background = Colors.white;
  static const Color error = Colors.redAccent;
  static const Color success = Colors.green;
}
