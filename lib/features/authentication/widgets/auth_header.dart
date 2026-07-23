// lib/features/authentication/widgets/auth_header.dart

import 'package:flutter/material.dart';
import 'auth_theme.dart';

/// Curved teal header used across Login / Sign Up / Forgot Password,
/// matching the reference design's blob-and-greeting header.
class AuthHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? leading; // e.g. a back button for Sign Up / Forgot Password

  const AuthHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.medical_services_rounded,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _HeaderClipper(),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(
          24,
          MediaQuery.of(context).padding.top + 16,
          24,
          70,
        ),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AuthColors.tealDark, AuthColors.teal],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // Decorative soft blobs, echoing the plant/leaf shapes in the reference
            Positioned(
              top: -30,
              right: -20,
              child: _blob(90, Colors.white.withValues(alpha: 0.06)),
            ),
            Positioned(
              top: 40,
              right: 30,
              child: _blob(50, Colors.white.withValues(alpha: 0.08)),
            ),
            Positioned(
              bottom: -10,
              left: -30,
              child: _blob(70, Colors.white.withValues(alpha: 0.05)),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (leading != null) leading!,
                if (leading != null) const SizedBox(height: 10),
                Icon(icon, color: Colors.white, size: 34),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _blob(double size, Color color) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _HeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 40);
    path.quadraticBezierTo(
      size.width / 2,
      size.height,
      size.width,
      size.height - 40,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}