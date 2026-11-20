import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:provider/provider.dart';
import '../models/product_model.dart';
import '../services/product_service.dart';
import '../themes.dart';
import '../widgets/product_card.dart';
import '../widgets/location_bottom_sheet.dart';
import '../providers/location_provider.dart';
import '../providers/category_provider.dart';
import 'detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.productsStream});

  final Stream<List<Product>>? productsStream;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? selectedCategory;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late Stream<List<Product>> _productsStream;

  @override
  void initState() {
    super.initState();
    _productsStream = widget.productsStream ?? ProductService.getProducts();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<CategoryProvider>().loadCategories(forceRefresh: true);
      }
    });
  }

  void _retryCatalog() {
    setState(() {
      _productsStream = widget.productsStream ?? ProductService.getProducts();
    });
    context.read<CategoryProvider>().loadCategories(forceRefresh: true);
  }

  Widget _catalogMessage(String message) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message, textAlign: TextAlign.center),
        TextButton(onPressed: _retryCatalog, child: const Text('Thử lại')),
      ],
    ),
  );

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double blackBackgroundHeight = 280.0;
    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              Container(
                height: blackBackgroundHeight,
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF313131), Color(0xFF131313)],
                  ),
                ),
              ),
              Expanded(child: Container(color: const Color(0xFFF9F9F9))),
            ],
          ),

          SafeArea(
            child: Column(
              children: [
                // 1. Header (Location & Avatar)
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => LocationBottomSheet.show(context),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Địa điểm',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.grey),
                            ),
                            Consumer<LocationProvider>(
                              builder: (context, locationProvider, _) {
                                return Row(
                                  children: [
                                    Text(
                                      locationProvider.currentAddress,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      IconlyBold.arrow_down_2,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.toLowerCase();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm cà phê...',
                      prefixIcon: const Icon(
                        IconlyLight.search,
                        color: Colors.white,
                      ),
                      filled: true,
                      fillColor: const Color(0xFF313131),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      hintStyle: const TextStyle(color: Colors.grey),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),

                const SizedBox(height: 24),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    height: 140, // Chiều cao tổng của banner
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppThemes.primaryColor,
                      borderRadius: BorderRadius.circular(16),
                      image: const DecorationImage(
                        image: AssetImage('assets/images/banner.png.jpg'),
                        fit: BoxFit.cover,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Promo',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const Positioned(
                          bottom: 15,
                          left: 15,
                          child: Text(
                            'Buy one get one FREE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(color: Colors.black45, blurRadius: 2),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // 4. Categories
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Consumer<CategoryProvider>(
                    builder: (context, categoryProvider, _) {
                      if (categoryProvider.isLoading) {
                        return const SizedBox(
                          height: 40,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final categories = categoryProvider.categories;

                      selectedCategory ??= 'all';
                      if (selectedCategory != 'all' &&
                          !categories.any(
                            (item) => item.name == selectedCategory,
                          )) {
                        selectedCategory = 'all';
                      }

                      return SizedBox(
                        height: 40,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: categories.length + 1, // +1 for "Tất cả"
                          itemBuilder: (context, index) {
                            // First item is "Tất cả"
                            if (index == 0) {
                              final isSelected = selectedCategory == 'all';
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    selectedCategory = 'all';
                                  });
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(right: 12),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppThemes.primaryColor
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      if (!isSelected)
                                        BoxShadow(
                                          color: Colors.grey.withValues(
                                            alpha: 0.1,
                                          ),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Tất cả',
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.black,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }

                            // Regular categories
                            final category = categories[index - 1];
                            final isSelected =
                                category.name == selectedCategory;
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  selectedCategory = category.name;
                                });
                              },
                              child: Container(
                                margin: const EdgeInsets.only(right: 12),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppThemes.primaryColor
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    if (!isSelected)
                                      BoxShadow(
                                        color: Colors.grey.withValues(
                                          alpha: 0.1,
                                        ),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    category.displayName,
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.black,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 24),

                // 5. Product Grid
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: StreamBuilder<List<Product>>(
                      stream: _productsStream,
                      builder: (context, snapshot) {
                        final categoryProvider = context
                            .watch<CategoryProvider>();
                        if (categoryProvider.isLoading) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (categoryProvider.errorMessage != null) {
                          return _catalogMessage(
                            'Không thể tải danh mục. Kiểm tra kết nối và thử lại.',
                          );
                        }
                        if (categoryProvider.categories.isEmpty) {
                          return _catalogMessage(
                            'Chưa có danh mục hoạt động. Quản trị viên cần tạo danh mục hoặc chạy seed catalog.',
                          );
                        }
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snapshot.hasError) {
                          return _catalogMessage(
                            'Không thể tải sản phẩm. Kiểm tra kết nối và thử lại.',
                          );
                        }
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return _catalogMessage(
                            'Chưa có sản phẩm đang bán. Quản trị viên cần thêm sản phẩm hoặc chạy seed catalog.',
                          );
                        }

                        final productsList = snapshot.data!;
                        // Filter by search query
                        final activeKeys = categoryProvider.categories
                            .map((category) => category.name)
                            .toSet();
                        final filteredProducts = productsList.where((product) {
                          return activeKeys.contains(product.category) &&
                              (selectedCategory == 'all' ||
                                  product.category == selectedCategory) &&
                              product.name.toLowerCase().contains(_searchQuery);
                        }).toList();

                        if (filteredProducts.isEmpty) {
                          if (_searchQuery.isEmpty &&
                              selectedCategory == 'all') {
                            return _catalogMessage(
                              'Sản phẩm chưa thuộc danh mục đang hoạt động. Kiểm tra key danh mục và dữ liệu seed.',
                            );
                          }
                          return const Center(
                            child: Text('Không tìm thấy sản phẩm'),
                          );
                        }

                        return GridView.builder(
                          padding: const EdgeInsets.only(bottom: 20),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.70,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                          itemCount: filteredProducts.length,
                          itemBuilder: (context, index) {
                            final product = filteredProducts[index];
                            return ProductCard(
                              product: product,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        DetailScreen(product: product),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
