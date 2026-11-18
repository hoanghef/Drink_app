import 'dart:convert';
import 'package:flutter/services.dart';

class SizePricing {
  static Map<String, int>? _offsets;

  static Future<void> load() async {
    final text = await rootBundle.loadString('functions/size_pricing.json');
    _offsets = (jsonDecode(text) as Map<String, dynamic>).map(
      (key, value) => MapEntry(key, (value as num).toInt()),
    );
  }

  static int price(num basePrice, String size) {
    final offset = _offsets?[size];
    if (offset == null) throw ArgumentError.value(size, 'size');
    final base = basePrice.toInt();
    if (base <= 0 || base != basePrice) throw ArgumentError.value(basePrice);
    return base + offset;
  }
}
