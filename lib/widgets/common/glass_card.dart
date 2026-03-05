import 'dart:ui';
import 'package:flutter/material.dart';

/// Glass Card Widget with Liquid Glass Effect
/// Features: Frosted glass blur, transparency, border glow
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

  const GlassCard({
    super.key,
    required this.child,
    this.blur = 10.0,
    this.opacity = 0.15,
    this.borderRadius,
    this.padding,
    this.margin,
    this.gradient,
    this.border,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? BorderRadius.circular(24),
        boxShadow: boxShadow ?? [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding ?? const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: gradient ?? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(opacity),
                  Colors.white.withOpacity(opacity * 0.5),
                ],
              ),
              borderRadius: borderRadius ?? BorderRadius.circular(24),
              border: border ?? Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Glass Button with Liquid Effect
class GlassButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final double blur;
  final double opacity;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final Gradient? gradient;

  const GlassButton({
    super.key,
    required this.child,
    this.onPressed,
    this.blur = 10.0,
    this.opacity = 0.2,
    this.borderRadius,
    this.padding,
    this.gradient,
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
      duration: const Duration(milliseconds: 150),
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
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onPressed?.call();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: widget.blur * 2, // Double the blur for stronger effect
                sigmaY: widget.blur * 2,
              ),
              child: Container(
                padding: widget.padding ?? const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  gradient: widget.gradient ?? LinearGradient(
                    colors: [
                      Colors.white.withOpacity(widget.opacity),
                      Colors.white.withOpacity(widget.opacity * 0.5),
                    ],
                  ),
                  borderRadius: widget.borderRadius ?? BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.4), // Stronger border
                    width: 2.0, // Thicker border
                  ),
                ),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Liquid Glass Container with Animated Gradient
class LiquidGlassContainer extends StatefulWidget {
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
  State<LiquidGlassContainer> createState() => _LiquidGlassContainerState();
}

class _LiquidGlassContainerState extends State<LiquidGlassContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          height: widget.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.colors,
              stops: [
                _controller.value * 0.2,
                0.3 + (_controller.value * 0.2),
                0.6 + (_controller.value * 0.2),
                1.0 - (_controller.value * 0.1),
              ],
            ),
          ),
          child: widget.child,
        );
      },
    );
  }
}
