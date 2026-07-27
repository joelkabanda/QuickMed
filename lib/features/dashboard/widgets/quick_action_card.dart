import 'package:flutter/material.dart';

class DashboardActionTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool enabled;

  const DashboardActionTile({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Opacity(
      opacity: enabled ? 1 : .45,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            decoration: BoxDecoration(
              color: dark ? color.withOpacity(.14) : color.withOpacity(.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(.55), width: 1.4),
              boxShadow: [
                BoxShadow(color: color.withOpacity(.09), blurRadius: 14, offset: const Offset(0, 6)),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    height: 42,
                    width: 42,
                    decoration: BoxDecoration(color: color.withOpacity(.16), shape: BoxShape.circle),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
