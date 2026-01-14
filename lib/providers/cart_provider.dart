import 'package:flutter/foundation.dart';
import '../models/product_model.dart';

class CartItem {
  final String id;
  final Product product;
  final String size;
  int quantity;

  CartItem({
    required this.id,
    required this.product,
    required this.size,
    required this.quantity,
  });
}

class CartProvider with ChangeNotifier {
  final Map<String, CartItem> _items = {};

  Map<String, CartItem> get items {
    return {..._items};
  }

  int get itemCount {
    return _items.length;
  }

  double get totalAmount {
    var total = 0.0;
    _items.forEach((key, cartItem) {
      total += cartItem.product.price * cartItem.quantity;
    });
    return total;
  }

  void addToCart(Product product, String size) {
    if (_items.containsKey(product.id + size)) {
      // Update quantity for existing item with same ID and Size
      _items.update(
        product.id + size,
        (existingCartItem) => CartItem(
          id: existingCartItem.id,
          product: existingCartItem.product,
          size: existingCartItem.size,
          quantity: existingCartItem.quantity + 1,
        ),
      );
    } else {
      // Add new item
      _items.putIfAbsent(
        product.id + size,
        () => CartItem(
          id: DateTime.now().toString(),
          product: product,
          size: size,
          quantity: 1,
        ),
      );
    }
    notifyListeners();
  }

  void removeItem(String productId, String size) {
    _items.remove(productId + size);
    notifyListeners();
  }

  void decreaseQuantity(String productId, String size) {
    if (!_items.containsKey(productId + size)) return;

    if (_items[productId + size]!.quantity > 1) {
      // Decrease quantity
      _items.update(
        productId + size,
        (existingCartItem) => CartItem(
          id: existingCartItem.id,
          product: existingCartItem.product,
          size: existingCartItem.size,
          quantity: existingCartItem.quantity - 1,
        ),
      );
    } else {
      // Remove item if quantity is 1
      _items.remove(productId + size);
    }
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }
}
