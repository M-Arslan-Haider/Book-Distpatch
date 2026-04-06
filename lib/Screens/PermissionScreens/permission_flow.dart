

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../AppColors.dart';
import 'camera_screen.dart';
import 'location_screen.dart';
import 'notification_screen.dart';

class PermissionsFlow extends StatefulWidget {
  const PermissionsFlow({super.key});

  @override
  State<PermissionsFlow> createState() => _PermissionsFlowState();
}

class _PermissionsFlowState extends State<PermissionsFlow> {
  int _currentIndex = 0;
  late PageController _pageController;

  final List<Widget> _screens = [
    const LocationScreen(),
    const CameraScreen(),
    const NotificationScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentIndex < _screens.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // All permissions done, go to login
      Get.offAllNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            children: [
              LocationScreen(onNext: _nextPage),
              CameraScreen(onNext: _nextPage),
              NotificationScreen(onNext: _nextPage),
            ],
          ),
          // ── Dot Indicator at bottom ─────────────────────────────
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (index) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  width: _currentIndex == index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: _currentIndex == index
                        ? AppColors.cyan
                        : Colors.white.withOpacity(0.5),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}