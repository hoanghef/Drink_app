import '../models/product_model.dart';

List<String> categories = ['Cappuccino', 'Machiato', 'Latte', 'Americano'];

List<Product> products = [
  Product(
    id: '1',
    name: 'Caffe Mocha',
    description: 'Deep Foam',
    price: 4.53,
    imageUrl: 'assets/images/coffee1.png',
    rating: 4.8,
    category: 'Cappuccino',
  ),
  Product(
    id: '2',
    name: 'Flat White',
    description: 'Espresso',
    price: 3.53,
    imageUrl: 'assets/images/coffee2.png',
    rating: 4.5,
    category: 'Cappuccino',
  ),
  Product(
    id: '3',
    name: 'Latte Art',
    description: 'Milk Foam',
    price: 4.00,
    imageUrl: 'assets/images/coffee3.png',
    rating: 4.7,
    category: 'Latte',
  ),
  Product(
    id: '4',
    name: 'Americano',
    description: 'Black Coffee',
    price: 3.00,
    imageUrl: 'assets/images/coffee4.png',
    rating: 4.2,
    category: 'Americano',
  ),
];
