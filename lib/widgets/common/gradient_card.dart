import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class GradientCard extends StatelessWidget {
  final Widget child;
  final Gradient? gradient;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final bool withGlass;
  final VoidCallback? onTap;

  const GradientCard({
    super.key,
    required this.child,
    this.gradient,
    this.backgroundColor,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.withGlass = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null ? (backgroundColor ?? (withGlass 
            ? Colors.white.withValues(alpha: 0.05)
            : AppColors.surfaceVariant)) : null,
        borderRadius: BorderRadius.circular(28),
        boxShadow: null, // NO Shadow design policy
        border: Border.all(
          color: withGlass ? Colors.white.withValues(alpha: 0.1) : AppColors.borderLight,
          width: 1.0,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: withGlass 
              ? ImageFilter.blur(sigmaX: 15, sigmaY: 15)
              : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(24),
            child: child,
          ),
        ),
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          splashColor: Colors.white.withValues(alpha: 0.05),
          highlightColor: Colors.white.withValues(alpha: 0.02),
          child: content,
        ),
      );
    }

    return content;
  }
}
