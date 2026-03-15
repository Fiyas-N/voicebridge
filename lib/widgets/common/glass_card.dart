import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Gamified Solid Card Widget (Replaces GlassCard)
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

  // Added flat background color for solid card
  final Color? backgroundColor;

  const GlassCard({
    super.key,
    required this.child,
    this.blur = 0.0, // Unused now
    this.opacity = 1.0, 
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
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surface,
        borderRadius: borderRadius ?? BorderRadius.circular(24),
        border: border ?? Border.all(color: AppColors.borderLight, width: 2),
        // A rigid bottom shadow for a 3D effect, typical in gamified apps
        boxShadow: boxShadow ?? [
          BoxShadow(
            color: border?.top.color ?? AppColors.borderMedium,
            offset: const Offset(0, 4),
            blurRadius: 0,
          ),
        ],
        gradient: gradient,
      ),
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(24),
        child: Container(
          padding: padding ?? const EdgeInsets.all(20),
          child: child,
        ),
      ),
    );
  }
}

/// Gamified Solid Button (Replaces GlassButton)
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
    this.blur = 0.0, // Unused
    this.opacity = 1.0,
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
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppAnimations.fast,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.backgroundColor ?? AppColors.primary;
    final shadowColor = bgColor.computeLuminance() > 0.5 
        ? AppColors.borderMedium 
        : _darken(bgColor, 0.2);

    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        _controller.forward();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        _controller.reverse();
        widget.onPressed?.call();
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
        _controller.reverse();
      },
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 50),
          transform: Matrix4.translationValues(0, _isPressed ? 4 : 0, 0),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: widget.borderRadius ?? BorderRadius.circular(16),
            gradient: widget.gradient,
            boxShadow: _isPressed 
                ? [] 
                : [
                    BoxShadow(
                      color: shadowColor,
                      offset: const Offset(0, 5),
                      blurRadius: 0,
                    ),
                  ],
          ),
          child: Container(
            padding: widget.padding ?? const EdgeInsets.symmetric(
              horizontal: 32,
              vertical: 16,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }

  Color _darken(Color color, [double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(color);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}

/// Solid Background Container (Replaces LiquidGlassContainer)
class LiquidGlassContainer extends StatelessWidget {
  final Widget child;
  final double height;
  final List<Color> colors; // Kept to avoid breaking existing signatures, but we will ignore it or just use the first color if needed.

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
      color: AppColors.backgroundOffWhite, // Force clean background
      child: child,
    );
  }
}
