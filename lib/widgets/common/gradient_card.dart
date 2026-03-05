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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    Widget content = Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null ? (backgroundColor ?? (withGlass 
            ? (isDark ? AppColors.darkSurface.withValues(alpha: 0.6) : AppColors.white.withValues(alpha: 0.7))
            : (isDark ? AppColors.darkSurface : AppColors.white))) : null,
        borderRadius: BorderRadius.circular(20),
        boxShadow: withGlass ? null : AppShadows.medium,
        border: withGlass ? Border.all(
          color: isDark 
              ? AppColors.white.withValues(alpha: 0.1) 
              : AppColors.white.withValues(alpha: 0.5),
          width: 1.5,
        ) : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: withGlass 
              ? ImageFilter.blur(sigmaX: 10, sigmaY: 10)
              : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(20),
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
          borderRadius: BorderRadius.circular(20),
          child: content,
        ),
      );
    }

    return content;
  }
}
