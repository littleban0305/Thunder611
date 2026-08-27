import 'package:flutter/material.dart';

class SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius radius;
  final VoidCallback? onTap;

  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = const BorderRadius.all(Radius.circular(22)),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.94),
        borderRadius: radius,
        border: Border.all(color: scheme.primary.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.24), blurRadius: 22, offset: const Offset(0, 10)),
        ],
      ),
      padding: padding,
      child: onTap == null ? child : InkWell(onTap: onTap, borderRadius: radius, child: child),
    );
  }
}

class Pill extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color? color;

  const Pill({super.key, required this.text, this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final tint = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tint.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: tint),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: tint),
          ),
        ],
      ),
    );
  }
}
