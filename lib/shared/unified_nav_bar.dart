import 'package:flutter/material.dart';

class UnifiedNavBar extends StatelessWidget {
  const UnifiedNavBar({
    Key? key,
    required this.currentIndex,
    required this.isAdmin,
    required this.onTabSelected,
    this.onCameraPressed,
    this.width,
    this.height = 90.0,
  }) : super(key: key);

  final int currentIndex;
  final bool isAdmin;
  final ValueChanged<int> onTabSelected;
  final VoidCallback? onCameraPressed;
  final double? width;
  final double height;

  static const Color cardBg = Color(0xFF1E293B);
  static const Color muted = Color(0xFF94A3B8);
  static const Color accentBlue = Color(0xFF3B82F6);
  static const Color neonAction = Color(0xFFD4FF00);

  @override
  Widget build(BuildContext context) {
    if (isAdmin) {
      return _buildAdminNavBar(context);
    } else {
      return _buildWorkerNavBar(context);
    }
  }

  /// 5-tab layout for Admin / Manager roles
  Widget _buildAdminNavBar(BuildContext context) {
    final double bottomPadding = MediaQuery.of(context).padding.bottom;
    return SizedBox(
      width: width ?? double.infinity,
      height: 65 + bottomPadding,
      child: Container(
        padding: EdgeInsets.only(bottom: bottomPadding),
        decoration: BoxDecoration(
          color: cardBg,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _adminNavItem(context, Icons.home_filled, 'Home', 0),
            _adminNavItem(context, Icons.calendar_month, 'Jobs', 1),
            _adminNavItem(context, Icons.chat_bubble, 'Inbox', 2),
            _adminNavItem(context, Icons.account_balance_wallet, 'Wallet', 3),
            _adminNavItem(context, Icons.grid_view_rounded, 'More', 4),
          ],
        ),
      ),
    );
  }

  Widget _adminNavItem(
      BuildContext context, IconData icon, String label, int index) {
    final bool isSelected = currentIndex == index;
    return GestureDetector(
      onTap: () => onTabSelected(index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color:
                isSelected ? accentBlue.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            icon,
            color: isSelected ? accentBlue : muted,
            size: isSelected ? 26 : 22,
          ),
        ),
      ),
    );
  }

  /// 4-tab layout + center camera button for Worker / Technician roles
  Widget _buildWorkerNavBar(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double itemWidth = (screenWidth - 80) / 4;
    final double bottomPadding = MediaQuery.of(context).padding.bottom;

    return SizedBox(
      width: width ?? double.infinity,
      height: height + bottomPadding,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            width: double.infinity,
            height: 65 + bottomPadding,
            padding: EdgeInsets.only(bottom: bottomPadding),
            decoration: BoxDecoration(
              color: cardBg,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _workerNavItem(context, Icons.home_filled, 0, itemWidth),
                    _workerNavItem(context, Icons.calendar_month, 1, itemWidth),
                  ],
                ),
                Row(
                  children: [
                    _workerNavItem(context, Icons.chat_bubble, 2, itemWidth),
                    _workerNavItem(
                        context, Icons.account_balance_wallet, 3, itemWidth),
                  ],
                ),
              ],
            ),
          ),

          // Central Yellow Camera Evidence FAB
          Positioned(
            top: 0,
            child: GestureDetector(
              onTap: onCameraPressed,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: neonAction,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: neonAction.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.black,
                  size: 28,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _workerNavItem(
      BuildContext context, IconData icon, int index, double itemWidth) {
    final bool isSelected = currentIndex == index;
    return GestureDetector(
      onTap: () => onTabSelected(index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: itemWidth,
        alignment: Alignment.center,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color:
                isSelected ? accentBlue.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            icon,
            color: isSelected ? accentBlue : muted,
            size: isSelected ? 26 : 24,
          ),
        ),
      ),
    );
  }
}
