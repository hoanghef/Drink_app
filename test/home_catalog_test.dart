import 'dart:async';
import 'package:coffee_app/models/category_model.dart';
import 'package:coffee_app/models/product_model.dart';
import 'package:coffee_app/providers/category_provider.dart';
import 'package:coffee_app/providers/location_provider.dart';
import 'package:coffee_app/screens/home_screen.dart';
import 'package:coffee_app/services/category_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class TestCategories extends CategoryService {
  TestCategories(this.values);
  final List<CategoryModel> values;

  @override
  Future<List<CategoryModel>> getCategories({
    bool forceRefresh = false,
  }) async => values;
}

class PendingCategories extends CategoryService {
  final requests = <Completer<List<CategoryModel>>>[];

  @override
  Future<List<CategoryModel>> getCategories({bool forceRefresh = false}) {
    final request = Completer<List<CategoryModel>>();
    requests.add(request);
    return request.future;
  }
}

final testProduct = Product(
  id: 'coffee',
  name: 'Cà phê thử',
  description: 'Mẫu',
  price: 25000,
  imageUrl: '',
  rating: 0,
  category: 'traditional',
);

Future<void> showHome(
  WidgetTester tester,
  List<CategoryModel> categories, {
  List<Product>? products,
}) async {
  tester.view.physicalSize = const Size(480, 960);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => CategoryProvider(service: TestCategories(categories)),
        ),
        ChangeNotifierProvider(
          create: (_) => LocationProvider(loadLocations: false),
        ),
      ],
      child: MaterialApp(
        home: HomeScreen(
          productsStream: Stream.value(products ?? [testProduct]),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('legacy category IDs remain readable without duplicate menu chips', () {
    final legacy = CategoryModel(
      id: 'ca-phe-truyen-thong',
      name: 'traditional',
      displayName: 'Truyền thống',
      order: 1,
    );
    expect(CategoryService.visibleCategories([legacy]), [legacy]);

    final canonical = CategoryModel(
      id: 'traditional',
      name: 'traditional',
      displayName: 'Tên mới',
      order: 2,
    );
    expect(CategoryService.visibleCategories([legacy, canonical]), [canonical]);
    final hidden = CategoryModel(
      id: 'traditional',
      name: 'traditional',
      displayName: 'Đã ẩn',
      order: 2,
      isActive: false,
    );
    expect(CategoryService.visibleCategories([legacy, hidden]), isEmpty);
    expect(CategoryService.visibleCategories([legacy, legacy]), isEmpty);
  });

  testWidgets(
    'home explains why an existing product is hidden without categories',
    (tester) async {
      await showHome(tester, []);
      expect(find.textContaining('Chưa có danh mục hoạt động'), findsOneWidget);
      expect(find.text('Cà phê thử'), findsNothing);
    },
  );

  testWidgets('home shows a product when its category is active', (
    tester,
  ) async {
    await showHome(tester, [
      CategoryModel(
        id: 'traditional',
        name: 'traditional',
        displayName: 'Truyền thống',
        order: 1,
      ),
    ]);
    expect(find.text('Cà phê thử'), findsOneWidget);
  });

  testWidgets('home shows a product from a legacy category document', (
    tester,
  ) async {
    await showHome(
      tester,
      CategoryService.visibleCategories([
        CategoryModel(
          id: 'ca-phe-truyen-thong',
          name: 'traditional',
          displayName: 'Truyền thống',
          order: 1,
        ),
      ]),
    );
    expect(find.text('Cà phê thử'), findsOneWidget);
    expect(find.text('Truyền thống'), findsOneWidget);
  });

  testWidgets('home explains when the catalog has no products', (tester) async {
    await showHome(tester, [
      CategoryModel(
        id: 'traditional',
        name: 'traditional',
        displayName: 'Truyền thống',
        order: 1,
      ),
    ], products: []);
    expect(find.textContaining('Chưa có sản phẩm đang bán'), findsOneWidget);
  });

  test('older category request cannot replace a newer result', () async {
    final service = PendingCategories();
    final provider = CategoryProvider(service: service);
    final oldLoad = provider.loadCategories(forceRefresh: true);
    final newLoad = provider.loadCategories(forceRefresh: true);
    final current = CategoryModel(
      id: 'traditional',
      name: 'traditional',
      displayName: 'Truyền thống',
      order: 1,
    );
    service.requests.last.complete([current]);
    await newLoad;
    service.requests.first.complete([]);
    await oldLoad;
    expect(provider.categories.single.name, 'traditional');
    provider.dispose();
  });
}
