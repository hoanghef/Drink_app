import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/product_model.dart';
import '../themes.dart';
import '../widgets/custom_button.dart';
import '../providers/cart_provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/user_provider.dart';

class DetailScreen extends StatefulWidget {
  final Product product;

  const DetailScreen({super.key, required this.product});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  String selectedSize = 'M';

  // Helper to get category display name
  String getCategoryDisplayName(String category) {
    const categoryMap = {
      'traditional': 'Cà phê truyền thống',
      'milk': 'Cà phê sữa & béo',
      'espresso': 'Cà phê Ý (Espresso)',
      'special': 'Cà phê đặc biệt',
    };
    return categoryMap[category] ?? category;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background/Hero Image
          Container(
            height: MediaQuery.of(context).size.height * 0.5,
            width: double.infinity,
            color: AppThemes.secondaryColor, // Fallback color
            child: Hero(
              tag: widget.product.id,
              child: Image.asset(
                widget.product.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Icon(
                    Icons.coffee,
                    size: 50,
                    color: AppThemes.primaryColor,
                  ),
                ),
              ),
            ),
          ),

          // Back & Favorite Icons
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    IconlyLight.arrow_left_2,
                    color: Colors.white,
                  ),
                ),
                Consumer<FavoritesProvider>(
                  builder: (context, favProvider, _) {
                    final isFav = favProvider.isFavorite(widget.product.id);
                    return IconButton(
                      onPressed: () {
                        final userId = Provider.of<UserProvider>(
                          context,
                          listen: false,
                        ).currentUser?.uid;
                        if (userId != null) {
                          favProvider.toggleFavorite(widget.product.id, userId);
                        }
                      },
                      icon: Icon(
                        isFav ? Icons.favorite : IconlyLight.heart,
                        color: isFav ? Colors.red : Colors.white,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Content Sheet
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.6,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & Rating
                  Text(
                    widget.product.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        getCategoryDisplayName(widget.product.category),
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const Spacer(),
                      const Icon(
                        IconlyBold.star,
                        color: Colors.amber,
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.product.rating}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const Divider(height: 32),

                  // Description
                  const Text(
                    'Mô tả',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.product.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),

                  // Size Selector
                  const Text(
                    'Size',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: ['S', 'M', 'L'].map((size) {
                      final isSelected = selectedSize == size;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedSize = size;
                          });
                        },
                        child: Container(
                          width: 100,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isSelected
                                  ? AppThemes.primaryColor
                                  : Colors.grey[300]!,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            color: isSelected
                                ? AppThemes.primaryColor.withOpacity(0.1)
                                : Colors.white,
                          ),
                          child: Text(
                            size,
                            style: TextStyle(
                              color: isSelected
                                  ? AppThemes.primaryColor
                                  : Colors.black,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const Spacer(),

                  // Bottom Bar
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Giá',
                            style: TextStyle(color: Colors.grey),
                          ),
                          Text(
                            '${NumberFormat('#,###', 'vi_VN').format(widget.product.price)}đ',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: AppThemes.primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: CustomButton(
                          text: 'Thêm Giỏ Hàng',
                          onPressed: () {
                            Provider.of<CartProvider>(
                              context,
                              listen: false,
                            ).addToCart(widget.product, selectedSize);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Thêm ${widget.product.name} ($selectedSize) vào giỏ hàng',
                                ),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                            Navigator.pop(context);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
