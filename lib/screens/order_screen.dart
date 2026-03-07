import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/cart_provider.dart';
import '../providers/location_provider.dart';
import '../widgets/delivery_address_dialog.dart';
import '../themes.dart';
import '../widgets/custom_button.dart';
import '../services/momo_payment_service.dart';
import 'main_screen.dart';

class OrderScreen extends StatefulWidget {
  const OrderScreen({super.key});

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  bool isDelivery = true; // Toggle state
  String _selectedPaymentMethod = 'COD'; // Default: Cash on Delivery
  bool _isLoading = false;

  void _showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );
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
    if (cart.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Giỏ hàng trống. Vui lòng thêm sản phẩm.'),
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please login to order')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      _showLoadingDialog(context);

      final orderRef = FirebaseFirestore.instance.collection('orders').doc();
      final orderId = orderRef.id;

      // Prepare order data
      final orderData = {
        'userId': user.uid,
        'userEmail': user.email,
        'amount': cart.totalAmount,
        'items': cart.items.values
            .map(
              (item) => {
                'productId': item.product.id,
                'productName': item.product.name,
                'price': item.product.price,
                'size': item.size,
                'quantity': item.quantity,
              },
            )
            .toList(),
        'status': 'Processing', // default status
        'isDelivery': isDelivery,
        'createdAt': FieldValue.serverTimestamp(),
        'paymentMethod': _selectedPaymentMethod,
        'isPaid': false, // initially false
      };

      if (_selectedPaymentMethod == 'COD') {
        // Proceed directly with COD
        await orderRef.set(orderData);
        if (!context.mounted) return;
        Navigator.of(context).pop(); // Close loading
        cart.clearCart();
        _showSuccessDialog(context);
      } else if (_selectedPaymentMethod == 'MOMO') {
        // Handle MoMo Sandbox Payment Flow
        final payUrl = await MoMoPaymentService.createMoMoPaymentResult(
          cart.totalAmount,
          orderId,
        );

        if (!context.mounted) return;
        Navigator.of(context).pop(); // Close loading

        if (payUrl != null) {
          // Open MoMo Sandbox Payment Page
          await MoMoPaymentService.launchPaymentUrl(payUrl);

          if (!context.mounted) return;

          // We prompt the user to simulate payment success since we are in sandbox and no true deep-link callback is setup
          _showSimulateSimulatePaymentDialog(
            context,
            orderRef,
            orderData,
            cart,
          );
        } else {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to generate MoMo Payment URL.'),
            ),
          );
        }
      }
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop(); // close loading
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSimulateSimulatePaymentDialog(
    BuildContext context,
    DocumentReference orderRef,
    Map<String, dynamic> orderData,
    CartProvider cart,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Giả lập Thanh toán MoMo'),
        content: const Text(
          'Trong môi trường thử nghiệm (Sandbox), sau khi bạn hoàn tất trên app/web MoMo, xin hãy nhấn "Đã thanh toán thành công" để tiếp tục.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop(); // Cancel
            },
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppThemes.primaryColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              _showLoadingDialog(context);

              // Update orderData to reflect paid status
              orderData['isPaid'] = true;
              await orderRef.set(orderData);

              if (!context.mounted) return;
              Navigator.of(context).pop(); // Close loading
              cart.clearCart();
              _showSuccessDialog(context);
            },
            child: const Text('Đã thanh toán thành công'),
          ),
        ],
      ),
    );
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
                      onPressed: () => DeliveryAddressDialog.show(context),
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
                        child: cartItem.product.imageUrl.startsWith('http')
                            ? Image.network(
                                cartItem.product.imageUrl,
                                width: 54,
                                height: 54,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                      width: 54,
                                      height: 54,
                                      color: Colors.grey,
                                    ),
                              )
                            : Image.asset(
                                cartItem.product.imageUrl,
                                width: 54,
                                height: 54,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                      width: 54,
                                      height: 54,
                                      color: Colors.grey,
                                    ),
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

          // Payment Methods UI
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Phương thức thanh toán',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),

                // COD Option
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedPaymentMethod = 'COD';
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _selectedPaymentMethod == 'COD'
                          ? AppThemes.primaryColor.withValues(alpha: 0.1)
                          : Colors.transparent,
                      border: Border.all(
                        color: _selectedPaymentMethod == 'COD'
                            ? AppThemes.primaryColor
                            : Colors.grey[300]!,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.money,
                          color: _selectedPaymentMethod == 'COD'
                              ? AppThemes.primaryColor
                              : Colors.grey[600],
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Thanh toán khi nhận hàng (COD)',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (_selectedPaymentMethod == 'COD')
                          const Icon(
                            Icons.check_circle,
                            color: AppThemes.primaryColor,
                          ),
                      ],
                    ),
                  ),
                ),

                // MoMo Option
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedPaymentMethod = 'MOMO';
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _selectedPaymentMethod == 'MOMO'
                          ? Colors.pink.withValues(alpha: 0.1)
                          : Colors.transparent,
                      border: Border.all(
                        color: _selectedPaymentMethod == 'MOMO'
                            ? Colors.pink
                            : Colors.grey[300]!,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.pink,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Center(
                            child: Text(
                              'M',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Qua ví điện tử MoMo',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (_selectedPaymentMethod == 'MOMO')
                          const Icon(Icons.check_circle, color: Colors.pink),
                      ],
                    ),
                  ),
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
