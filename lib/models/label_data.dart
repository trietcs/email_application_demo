import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LabelData {
  final String id;
  final String name;
  final Color color;

  LabelData({required this.id, required this.name, required this.color});

  static Color colorFromHex(
    String hexColor, {
    Color defaultColor = Colors.grey,
  }) {
    try {
      final String formattedHexColor = hexColor.toUpperCase().replaceAll(
        "#",
        "",
      );
      if (formattedHexColor.length == 6) {
        return Color(int.parse("FF$formattedHexColor", radix: 16));
      } else if (formattedHexColor.length == 8) {
        return Color(int.parse(formattedHexColor, radix: 16));
      }
      return defaultColor;
    } catch (e) {
      print('Error parsing hex color "$hexColor": $e');
      return defaultColor;
    }
  }

  static String colorToHex(
    Color color, {
    bool leadingHashSign = true,
    bool includeAlpha = false,
  }) {
    String hex = '';
    if (leadingHashSign) {
      hex += '#';
    }
    if (includeAlpha || color.alpha != 255) {
      hex += color.alpha.toRadixString(16).padLeft(2, '0');
    }
    hex += color.red.toRadixString(16).padLeft(2, '0');
    hex += color.green.toRadixString(16).padLeft(2, '0');
    hex += color.blue.toRadixString(16).padLeft(2, '0');
    return hex.toUpperCase();
  }

  factory LabelData.fromMap(Map<String, dynamic> map, String id) {
    return LabelData(
      id: id,
      name: map['name'] as String? ?? 'Unnamed Label',
      color: colorFromHex(map['color'] as String? ?? '#808080'),
    );
  }

  Map<String, dynamic> toMap() {
    return {'name': name, 'color': colorToHex(color, includeAlpha: false)};
  }

  LabelData copyWith({String? id, String? name, Color? color}) {
    return LabelData(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
    );
  }
}
