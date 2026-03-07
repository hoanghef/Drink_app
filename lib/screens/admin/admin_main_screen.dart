import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';

import 'admin_dashboard_screen.dart';
import 'admin_order_list_screen.dart';
import 'admin_product_list_screen.dart';
import 'admin_settings_screen.dart';
import '../../themes.dart';

class AdminMainScreen extends StatefulWidget {
  const AdminMainScreen({super.key});

  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const AdminDashboardScreen(),
    const AdminOrderListScreen(),
    const AdminProductListScreen(),
    const AdminSettingsScreen(),
  ];

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
            label: 'Tổng quan',
          ),
          BottomNavigationBarItem(
            icon: Icon(IconlyLight.document),
            activeIcon: Icon(IconlyBold.document),
            label: 'Đơn hàng',
          ),
          BottomNavigationBarItem(
            icon: Icon(IconlyLight.category),
            activeIcon: Icon(IconlyBold.category),
            label: 'Sản phẩm',
          ),
          BottomNavigationBarItem(
            icon: Icon(IconlyLight.setting),
            activeIcon: Icon(IconlyBold.setting),
            label: 'Cài đặt',
          ),
        ],
      ),
    );
  }
}
