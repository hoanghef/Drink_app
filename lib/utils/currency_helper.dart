import 'package:intl/intl.dart';

class CurrencyHelper {
  /// Format price to Vietnamese Dong with thousand separators
  /// Example: 25000 -> "25.000đ"
  static String formatPrice(double price) {
    final formatter = NumberFormat('#,###', 'vi_VN');
    return '${formatter.format(price)}đ';
  }

  /// Format price to Vietnamese Dong without separators
  /// Example: 25000 -> "25000đ"
  static String formatPriceSimple(double price) {
    return '${price.toInt()}đ';
  }
}
