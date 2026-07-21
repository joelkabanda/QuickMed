// lib/features/dashboard/widgets/med_bottom_nav.dart

import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';

class MedBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onScanTap;

  const MedBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onScanTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.home_rounded, "Home", 0),
          _navItem(Icons.local_pharmacy_outlined, "Pharmacy", 1),
          _scanButton(),
          _navItem(Icons.history_rounded, "History", 2),
          _navItem(Icons.more_horiz_rounded, "More", 3),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    final selected = currentIndex == index;
    final color = selected ? Colors.amberAccent : Colors.white70;

    return InkWell(
      onTap: () => onTap(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _scanButton() {
    return Transform.translate(
      offset: const Offset(0, -18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onScanTap,
            borderRadius: BorderRadius.circular(32),
            child: Container(
              height: 58,
              width: 58,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.amberAccent, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary, size: 26),
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            "Scan Rx",
            style: TextStyle(color: Colors.amberAccent, fontSize: 11.5, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}