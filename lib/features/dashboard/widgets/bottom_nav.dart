// lib/features/dashboard/widgets/bottom_nav.dart

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
    return LayoutBuilder(
      builder: (context, constraints) {
        // Scale factor: 375 is a typical baseline phone width.
        final scale = (constraints.maxWidth / 375).clamp(0.85, 1.25);
        final iconSize = 24.0 * scale;
        final fontSize = 11.5 * scale;
        final scanSize = 58.0 * scale;

        return Container(
          padding: EdgeInsets.symmetric(
            vertical: 10 * scale,
            horizontal: 8,
          ),
          decoration: BoxDecoration(
            color: AppColors.primaryDark,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _navItem(Icons.home_rounded, "Home", 0, iconSize, fontSize),
              _navItem(Icons.local_pharmacy_outlined, "Pharmacy", 1, iconSize, fontSize),
              _scanButton(scanSize, fontSize),
              _navItem(Icons.history_rounded, "History", 2, iconSize, fontSize),
              _navItem(Icons.more_horiz_rounded, "More", 3, iconSize, fontSize),
            ],
          ),
        );
      },
    );
  }

  Widget _navItem(
    IconData icon,
    String label,
    int index,
    double iconSize,
    double fontSize,
  ) {
    final selected = currentIndex == index;
    final color = selected ? Colors.amberAccent : Colors.white70;

    return Expanded(
      child: InkWell(
        onTap: () => onTap(index),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: iconSize),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  color: color,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scanButton(double scanSize, double fontSize) {
    return Expanded(
      child: Transform.translate(
        offset: Offset(0, -scanSize * 0.3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: onScanTap,
              borderRadius: BorderRadius.circular(scanSize),
              child: Container(
                height: scanSize,
                width: scanSize,
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
                child: Icon(
                  Icons.qr_code_scanner_rounded,
                  color: AppColors.primary,
                  size: scanSize * 0.45,
                ),
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                "Scan Rx",
                maxLines: 1,
                style: TextStyle(
                  color: Colors.amberAccent,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}