import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';

/// Glassmorphic card: ~20 blur, 5% white fill, 1px border, 16px squircle.
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
  /// Left purple accent bar (e.g. live translation).
  final bool showLeadingAccent;

  const GlassCard({
    super.key,
    required this.child,
    this.blur = 20.0,
    this.opacity = 0.05,
    this.borderRadius,
    this.padding,
    this.margin,
    this.gradient,
    this.border,
    this.boxShadow,
    this.backgroundColor,
    this.showLeadingAccent = false,
  });

  @override
  Widget build(BuildContext context) {
    final finalBorderRadius = borderRadius ?? BorderRadius.circular(VbRadii.lg);

    Widget content = ClipRRect(
      borderRadius: finalBorderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding ?? const EdgeInsets.all(VbSpacing.md),
          decoration: BoxDecoration(
            color: backgroundColor ??
                (gradient == null
                    ? Colors.white.withValues(alpha: opacity)
                    : null),
            gradient: gradient,
            borderRadius: finalBorderRadius,
            border: border ??
                Border.all(
                  color: VbColor.borderIdle,
                  width: 1,
                ),
          ),
          child: child,
        ),
      ),
    );

    if (showLeadingAccent) {
      content = Stack(
        children: [
          content,
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 4,
              decoration: BoxDecoration(
                color: VbColor.accentElectric,
                borderRadius: BorderRadius.only(
                  topLeft: finalBorderRadius.topLeft,
                  bottomLeft: finalBorderRadius.bottomLeft,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: finalBorderRadius,
        boxShadow: boxShadow,
      ),
      child: content,
    );
  }
}

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
    this.opacity = 0.05,
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
    final finalRadius = widget.borderRadius ?? BorderRadius.circular(VbRadii.full);

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
              padding: widget.padding ??
                  const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 16,
                  ),
              decoration: BoxDecoration(
                color: widget.backgroundColor ??
                    Colors.white.withValues(alpha: widget.opacity),
                gradient: widget.gradient,
                borderRadius: finalRadius,
                border: Border.all(
                  color: VbColor.outline,
                  width: 1,
                ),
              ),
              child: Center(
                child: DefaultTextStyle.merge(
                  style: TextStyle(
                    color: VbColor.onSurface,
                    fontWeight: FontWeight.w600,
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
        color: VbColor.background,
      ),
      child: child,
    );
  }
}
