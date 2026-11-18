import 'package:flutter_test/flutter_test.dart';
import 'package:coffee_app/utils/admin_metrics.dart';

void main() {
  test('counts periods and statuses, collected money only after paid', () {
    final now = DateTime(2026, 11, 18, 10);
    final metrics = AdminMetrics.fromOrders([
      {
        'createdAt': DateTime(2026, 11, 18),
        'orderStatus': 'Hoàn thành',
        'paymentMethod': 'COD',
        'paymentStatus': 'unpaid',
        'amount': 10000,
      },
      {
        'createdAt': DateTime(2026, 11, 18),
        'status': 'Hoàn thành',
        'paymentMethod': 'COD',
        'paymentStatus': 'paid',
        'amount': 20000,
      },
      {
        'createdAt': DateTime(2026, 11, 2),
        'status': 'Đang giao',
        'paymentMethod': 'VNPAY',
        'paymentStatus': 'paid',
        'amount': 30000,
      },
      {
        'createdAt': DateTime(2026, 10, 1),
        'status': 'Hủy',
        'paymentStatus': 'paid',
        'amount': 40000,
      },
      {
        'createdAt': DateTime(2026, 11, 18),
        'status': 'processing',
        'amount': 5000,
      },
    ], now);
    expect(metrics.totalOrders, 5);
    expect(metrics.today, 3);
    expect(metrics.thisMonth, 4);
    expect(metrics.collected, 50000);
    expect(metrics.orderValue, 65000);
    expect(metrics.unknownPayment, 1);
    expect(metrics.byStatus['Chờ xác nhận'], 1);
  });
}
