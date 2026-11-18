import 'dart:convert';
import 'dart:math';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/cart_provider.dart';
import '../providers/location_provider.dart';
import '../themes.dart';
import '../widgets/custom_button.dart';
import 'main_screen.dart';
import 'address_book_screen.dart';

class OrderScreen extends StatefulWidget {
  const OrderScreen({super.key});

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  bool isDelivery = true; // Toggle state
  bool _isLoading = false;
  bool _vnpayEnabled = false;
  bool _vnpayChecking = true;
  String _paymentMethod = 'COD';
  String? _pendingRequestId;
  String? _pendingSignature;
  @override
  void initState() {
    super.initState();
    _loadPaymentOptions();
  }

  Future<void> _loadPaymentOptions() async {
    try {
      final result = await FirebaseFunctions.instanceFor(
        region: 'asia-southeast1',
      ).httpsCallable('vnpayAvailability').call();
      if (mounted) {
        setState(() => _vnpayEnabled = result.data['enabled'] == true);
      }
    } catch (_) {
      if (mounted) setState(() => _vnpayEnabled = false);
    } finally {
      if (mounted) setState(() => _vnpayChecking = false);
    }
  }

  void _showPaymentStatus(
    BuildContext context,
    String orderId,
    CartProvider cart,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Trạng thái thanh toán VNPay'),
        content: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('orders')
              .doc(orderId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Text(
                'Không tải được trạng thái. Kiểm tra lịch sử đơn hàng.',
              );
            }
            final status =
                snapshot.data?.data()?['paymentStatus'] as String? ?? 'pending';
            if (status == 'paid' && cart.items.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => cart.clearCart(),
              );
            }
            if (status == 'failed' || status == 'canceled') {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _pendingRequestId = null;
                _pendingSignature = null;
              });
            }
            final label = switch (status) {
              'paid' => 'Đã thanh toán',
              'canceled' => 'Thanh toán đã hủy',
              'failed' => 'Thanh toán thất bại',
              _ =>
                'Đang chờ VNPay xác nhận. Bạn có thể xem lại trong lịch sử đơn hàng.',
            };
            return Text(label);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  String _newRequestId() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  void _showSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Thành công!'),
        content: const Text('Đơn hàng của bạn đã được đặt.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop(); // Close dialog
              // Go back to Home Screen (which is MainScreen at index 0)
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const MainScreen()),
                (route) => false,
              );
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitOrder(BuildContext context, CartProvider cart) async {
    if (_isLoading || cart.items.isEmpty) return;
    if (cart.items.values.any(
          (item) =>
              !item.product.isAvailable ||
              item.quantity < 1 ||
              item.quantity > 99 ||
              item.product.priceForSize(item.size) <= 0,
        ) ||
        cart.totalAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Giỏ hàng có sản phẩm hoặc số lượng không hợp lệ'),
        ),
      );
      return;
    }
    if (FirebaseAuth.instance.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để đặt hàng')),
      );
      return;
    }
    final location = context.read<LocationProvider>();
    if (isDelivery && location.defaultAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập địa chỉ giao hàng')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final items = cart.items.values
          .map(
            (item) => {
              'productId': item.product.id,
              'size': item.size,
              'quantity': item.quantity,
            },
          )
          .toList();
      final address = isDelivery
          ? {
              'city': location.currentCity,
              'detailedAddress': location.detailedAddress,
            }
          : null;
      final signature = jsonEncode([
        items,
        isDelivery,
        address,
        cart.totalAmount,
        _paymentMethod,
      ]);
      if (_pendingSignature != signature) {
        _pendingSignature = signature;
        _pendingRequestId = _newRequestId();
      }
      final result =
          await FirebaseFunctions.instanceFor(region: 'asia-southeast1')
              .httpsCallable(
                _paymentMethod == 'VNPAY' ? 'createVnpayPayment' : 'placeOrder',
              )
              .call({
                'requestId': _pendingRequestId,
                'expectedAmount': cart.totalAmount.toInt(),
                'items': items,
                'isDelivery': isDelivery,
                'deliveryAddress': address,
              });
      if (!context.mounted) return;
      if (_paymentMethod == 'COD') {
        cart.clearCart();
        _pendingRequestId = null;
        _pendingSignature = null;
        _showSuccessDialog(context);
      } else {
        final data = Map<String, dynamic>.from(result.data as Map);
        final orderId = data['orderId'] as String;
        final payUrl = data['payUrl'] as String?;
        if (payUrl != null) {
          final opened = await launchUrl(
            Uri.parse(payUrl),
            mode: LaunchMode.externalApplication,
          );
          if (!opened) throw StateError('Cannot open VNPay payment page');
        }
        if (context.mounted) _showPaymentStatus(context, orderId, cart);
      }
    } on FirebaseFunctionsException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Không thể đặt hàng')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể đặt hàng. Vui lòng thử lại.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Đơn hàng',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Toggle Switch
          Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => isDelivery = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isDelivery
                            ? AppThemes.primaryColor
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Giao hàng',
                        style: TextStyle(
                          color: isDelivery ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => isDelivery = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: !isDelivery
                            ? AppThemes.primaryColor
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Tự đến lấy',
                        style: TextStyle(
                          color: !isDelivery ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Address
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isDelivery ? 'Địa chỉ giao hàng' : 'Địa chỉ lấy hàng',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AddressBookScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Thay đổi'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppThemes.primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Consumer<LocationProvider>(
                  builder: (context, locationProvider, _) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (locationProvider.detailedAddress.isNotEmpty)
                          Text(
                            locationProvider.detailedAddress,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        Text(
                          locationProvider.currentCity,
                          style: TextStyle(
                            color: locationProvider.detailedAddress.isEmpty
                                ? Colors.black
                                : Colors.grey,
                            fontSize: locationProvider.detailedAddress.isEmpty
                                ? 14
                                : 12,
                            fontWeight: locationProvider.detailedAddress.isEmpty
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                const Divider(),
              ],
            ),
          ),

          // Cart Items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: cart.items.length,
              itemBuilder: (ctx, i) {
                final cartItem = cart.items.values.toList()[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: cartItem.product.imageUrl.isNotEmpty
                            ? (cartItem.product.imageUrl.startsWith('http')
                                  ? Image.network(
                                      cartItem.product.imageUrl,
                                      width: 54,
                                      height: 54,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              Container(
                                                width: 54,
                                                height: 54,
                                                color: Colors.grey[200],
                                                child: const Icon(Icons.coffee),
                                              ),
                                    )
                                  : Image.asset(
                                      cartItem.product.imageUrl,
                                      width: 54,
                                      height: 54,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              Container(
                                                width: 54,
                                                height: 54,
                                                color: Colors.grey[200],
                                                child: const Icon(Icons.coffee),
                                              ),
                                    ))
                            : Container(
                                width: 54,
                                height: 54,
                                color: Colors.grey[200],
                                child: const Icon(Icons.coffee),
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cartItem.product.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${cartItem.product.category} | Size: ${cartItem.size}',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '${NumberFormat('#,###', 'vi_VN').format(cartItem.product.priceForSize(cartItem.size))}đ / ly',
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.remove_circle_outline,
                              size: 20,
                            ),
                            onPressed: () {
                              cart.decreaseQuantity(
                                cartItem.product.id,
                                cartItem.size,
                              );
                            },
                          ),
                          Text(
                            'x ${cartItem.quantity}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.add_circle_outline,
                              size: 20,
                            ),
                            onPressed: () =>
                                cart.addToCart(cartItem.product, cartItem.size),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          const Divider(),

          RadioGroup<String>(
            groupValue: _paymentMethod,
            onChanged: (value) {
              if (!_isLoading && value != null) {
                setState(() => _paymentMethod = value);
              }
            },
            child: Column(
              children: [
                RadioListTile<String>(
                  title: const Text('Thanh toán khi nhận hàng (COD)'),
                  value: 'COD',
                  enabled: !_isLoading,
                ),
                RadioListTile<String>(
                  title: const Text('VNPay Sandbox'),
                  subtitle: Text(
                    _vnpayChecking
                        ? 'Đang kiểm tra cấu hình'
                        : _vnpayEnabled
                        ? 'Thanh toán qua VNPay'
                        : 'Chưa cấu hình VNPay Sandbox',
                  ),
                  value: 'VNPAY',
                  enabled: _vnpayEnabled && !_isLoading,
                ),
              ],
            ),
          ),
          const Divider(height: 32),
          // Payment Summary
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Chi tiết thanh toán',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '${NumberFormat('#,###', 'vi_VN').format(cart.totalAmount)}đ',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                CustomButton(
                  text: 'Đặt hàng',
                  onPressed: _isLoading
                      ? () {} // Do nothing if loading
                      : () => _submitOrder(context, cart),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
