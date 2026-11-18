import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coffee_app/models/product_model.dart';
import 'package:coffee_app/models/user_model.dart';
import 'package:coffee_app/providers/cart_provider.dart';
import 'package:coffee_app/widgets/custom_button.dart';
import 'package:coffee_app/utils/size_pricing.dart';
import 'package:coffee_app/providers/location_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(SizePricing.load);
  test('Size prices share the catalog base and offsets', () {
    expect(SizePricing.price(25000, 'S'), 25000);
    expect(SizePricing.price(25000, 'M'), 30000);
    expect(SizePricing.price(25000, 'L'), 35000);
    expect(() => SizePricing.price(25000, 'XL'), throwsArgumentError);
  });
  test('Addresses are isolated by UID and default follows deletion', () async {
    SharedPreferences.setMockInitialValues({});
    final location = LocationProvider(loadLocations: false);
    await location.bindUser('u1');
    await location.saveAddress('Ha Noi', '12 Street');
    await location.saveAddress('Da Nang', '15 Road');
    final second = location.addresses.last.id;
    await location.setDefault(second);
    expect(location.defaultAddress?.city, 'Da Nang');
    await location.bindUser('u2');
    expect(location.addresses, isEmpty);
    await location.saveAddress('Hue', '1 Lane');
    await location.bindUser('u1');
    expect(location.addresses.length, 2);
    expect(location.defaultAddress?.city, 'Da Nang');
    await location.deleteAddress(second);
    expect(location.defaultAddress?.city, 'Ha Noi');
  });
  test('Cart is in memory and clears when account changes', () {
    final cart = CartProvider();
    final product = Product(
      id: 'p',
      name: 'Coffee',
      description: '',
      price: 25000,
      imageUrl: '',
      rating: 0,
      category: 'traditional',
    );
    cart.bindUser('u1');
    cart.addToCart(product, 'M');
    cart.bindUser('u2');
    expect(cart.items, isEmpty);
  });
  group('Product Model Tests', () {
    test('Product serialization toMap and fromMap works correctly', () {
      final product = Product(
        id: 'test-1',
        name: 'Cà phê sữa đá',
        description: 'Đậm đà hương vị',
        price: 25000,
        imageUrl: 'assets/images/cafesuada.jpg',
        rating: 4.8,
        category: 'traditional',
      );

      final map = product.toMap();
      expect(map['name'], 'Cà phê sữa đá');
      expect(map['price'], 25000.0);
      expect(map['price'], isA<int>());
      expect(map['imageUrl'], 'assets/images/cafesuada.jpg');
      expect(map['imageURL'], 'assets/images/cafesuada.jpg');

      final fromMapProduct = Product.fromMap(map, 'test-1');
      expect(fromMapProduct.id, 'test-1');
      expect(fromMapProduct.name, 'Cà phê sữa đá');
      expect(fromMapProduct.price, 25000.0);
      expect(fromMapProduct.imageUrl, 'assets/images/cafesuada.jpg');
      expect(fromMapProduct.rating, 4.8);
      expect(fromMapProduct.category, 'traditional');
    });
    test('Product serialization rejects fractional VND price', () {
      final product = Product(
        id: 'fractional',
        name: 'Sample',
        description: '',
        price: 25000.5,
        imageUrl: 'assets/images/cafesuada.jpg',
        rating: 0,
        category: 'traditional',
      );
      expect(product.toMap, throwsArgumentError);
    });

    test('Product.fromMap handles legacy imageURL key correctly', () {
      final legacyMap = {
        'name': 'Bạc xỉu',
        'description': 'Béo ngọt',
        'price': 30000,
        'imageURL': 'assets/images/bacxiu.jpg',
        'rating': 4.5,
        'category': 'milk',
      };

      final product = Product.fromMap(legacyMap, 'legacy-1');
      expect(product.imageUrl, 'assets/images/bacxiu.jpg');
    });
  });

  group('CartProvider Tests', () {
    late CartProvider cartProvider;
    late Product sampleProduct1;
    late Product sampleProduct2;

    setUp(() {
      cartProvider = CartProvider();
      sampleProduct1 = Product(
        id: 'p1',
        name: 'Đen đá',
        description: 'Đậm vị',
        price: 20000,
        imageUrl: 'assets/images/cafedenda.png',
        rating: 4.5,
        category: 'traditional',
      );
      sampleProduct2 = Product(
        id: 'p2',
        name: 'Sữa đá',
        description: 'Thơm béo',
        price: 25000,
        imageUrl: 'assets/images/cafesuada.jpg',
        rating: 4.7,
        category: 'traditional',
      );
    });

    test('Initial cart is empty', () {
      expect(cartProvider.itemCount, 0);
      expect(cartProvider.totalAmount, 0.0);
      expect(cartProvider.items.isEmpty, true);
    });

    test('addToCart adds new item and calculates total correctly', () {
      cartProvider.addToCart(sampleProduct1, 'M');

      expect(cartProvider.itemCount, 1);
      expect(cartProvider.totalAmount, 25000.0);

      // Add same product with same size increases quantity
      cartProvider.addToCart(sampleProduct1, 'M');
      expect(cartProvider.itemCount, 1);
      expect(cartProvider.items['p1M']!.quantity, 2);
      expect(cartProvider.totalAmount, 50000.0);

      // Add same product with different size creates separate item
      cartProvider.addToCart(sampleProduct1, 'L');
      expect(cartProvider.itemCount, 2);
      expect(cartProvider.totalAmount, 80000.0);
    });

    test('decreaseQuantity decrements and removes when quantity reaches 0', () {
      cartProvider.addToCart(sampleProduct1, 'M');
      cartProvider.addToCart(sampleProduct1, 'M');
      expect(cartProvider.items['p1M']!.quantity, 2);

      cartProvider.decreaseQuantity('p1', 'M');
      expect(cartProvider.items['p1M']!.quantity, 1);
      expect(cartProvider.totalAmount, 25000.0);

      cartProvider.decreaseQuantity('p1', 'M');
      expect(cartProvider.items.containsKey('p1M'), false);
      expect(cartProvider.itemCount, 0);
      expect(cartProvider.totalAmount, 0.0);
    });

    test('removeItem removes item directly', () {
      cartProvider.addToCart(sampleProduct1, 'M');
      cartProvider.addToCart(sampleProduct2, 'L');
      expect(cartProvider.itemCount, 2);

      cartProvider.removeItem('p1', 'M');
      expect(cartProvider.itemCount, 1);
      expect(cartProvider.items.containsKey('p1M'), false);
      expect(cartProvider.totalAmount, 35000.0);
    });

    test('clearCart empties all items', () {
      cartProvider.addToCart(sampleProduct1, 'M');
      cartProvider.addToCart(sampleProduct2, 'L');
      expect(cartProvider.itemCount, 2);

      cartProvider.clearCart();
      expect(cartProvider.itemCount, 0);
      expect(cartProvider.totalAmount, 0.0);
    });
  });

  group('UserModel Tests', () {
    test('UserModel serialization with String createdAt', () {
      final now = DateTime(2026, 1, 1, 10, 0, 0);
      final user = UserModel(
        uid: 'user-123',
        email: 'test@example.com',
        name: 'Nguyen Van A',
        role: 'user',
        createdAt: now,
      );

      final map = user.toMap();
      final fromMapUser = UserModel.fromMap(map);

      expect(fromMapUser.uid, 'user-123');
      expect(fromMapUser.email, 'test@example.com');
      expect(fromMapUser.name, 'Nguyen Van A');
      expect(fromMapUser.role, 'user');
      expect(fromMapUser.createdAt.isAtSameMomentAs(now), true);
    });
  });

  group('Widget Tests', () {
    testWidgets('CustomButton renders text and triggers callback', (
      WidgetTester tester,
    ) async {
      bool pressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomButton(
              text: 'Bắt đầu ngay',
              onPressed: () {
                pressed = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('Bắt đầu ngay'), findsOneWidget);

      await tester.tap(find.byType(CustomButton));
      await tester.pump();

      expect(pressed, true);
    });
  });
}
