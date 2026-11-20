import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../themes.dart';
import '../providers/user_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/location_provider.dart';
import '../providers/favorites_provider.dart';
import 'home_screen.dart';
import 'favorite_screen.dart';
import 'order_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const FavoriteScreen(),
    const OrderScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Load user data from Firestore
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final cart = context.read<CartProvider>();
      final favorites = context.read<FavoritesProvider>();
      final locations = context.read<LocationProvider>();
      final profile = context.read<UserProvider>();
      cart.bindUser(user.uid);
      final shouldLoadFavorites = favorites.uid != user.uid;
      favorites.bindUser(user.uid);
      await locations.bindUser(user.uid);
      if (shouldLoadFavorites) await favorites.loadFavorites(user.uid);
      try {
        await profile.loadUserData(user.uid);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Không thể làm mới quyền tài khoản. Vui lòng thử đăng nhập lại.',
              ),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppThemes.primaryColor,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(IconlyLight.home),
            activeIcon: Icon(IconlyBold.home),
            label: 'Trang chủ',
          ),
          BottomNavigationBarItem(
            icon: Icon(IconlyLight.heart),
            activeIcon: Icon(IconlyBold.heart),
            label: 'Yêu thích',
          ),
          BottomNavigationBarItem(
            icon: Icon(IconlyLight.bag),
            activeIcon: Icon(IconlyBold.bag),
            label: 'Đơn hàng',
          ),
          BottomNavigationBarItem(
            icon: Icon(IconlyLight.profile),
            activeIcon: Icon(IconlyBold.profile),
            label: 'Hồ sơ',
          ),
        ],
      ),
    );
  }
}
