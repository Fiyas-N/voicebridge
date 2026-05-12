import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Authentic Futuristic Glass Card
class GlassCard extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Gradient? gradient;
  final Border? border;
  final List<BoxShadow>? boxShadow;
  final Color? backgroundColor;

  const GlassCard({
    super.key,
    required this.child,
    this.blur = 12.0, // Re-enable and default to futuristic blur
    this.opacity = 0.6, 
    this.borderRadius,
    this.padding,
    this.margin,
    this.gradient,
    this.border,
    this.boxShadow,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final finalBorderRadius = borderRadius ?? BorderRadius.circular(28);
    
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: finalBorderRadius,
        boxShadow: boxShadow, // Allow explicit shadow if needed
      ),
      child: ClipRRect(
        borderRadius: finalBorderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding ?? const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: backgroundColor ?? (gradient == null 
                  ? AppColors.surfaceVariant.withValues(alpha: opacity) 
                  : null),
              gradient: gradient,
              borderRadius: finalBorderRadius,
              border: border ?? Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1.0,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Futuristic Dark Blur Button
class GlassButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final double blur;
  final double opacity;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final Gradient? gradient;
  final Color? backgroundColor;

  const GlassButton({
    super.key,
    required this.child,
    this.onPressed,
    this.blur = 8.0,
    this.opacity = 0.7,
    this.borderRadius,
    this.padding,
    this.gradient,
    this.backgroundColor,
  });

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton> 
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppAnimations.fast,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final finalRadius = widget.borderRadius ?? BorderRadius.circular(32);

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onPressed?.call();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: ClipRRect(
          borderRadius: finalRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: widget.blur, sigmaY: widget.blur),
            child: Container(
              padding: widget.padding ?? const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 18,
              ),
              decoration: BoxDecoration(
                color: widget.backgroundColor ?? Colors.white.withValues(alpha: 0.1),
                gradient: widget.gradient,
                borderRadius: finalRadius,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 1.0,
                ),
              ),
              child: Center(
                child: DefaultTextStyle.merge(
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Minimal Dark Container replacement for animated liquid effect
class LiquidGlassContainer extends StatelessWidget {
  final Widget child;
  final double height;
  final List<Color> colors;

  const LiquidGlassContainer({
    super.key,
    required this.child,
    required this.height,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: AppColors.background,
      ),
      child: child,
    );
  }
}
