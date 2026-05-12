import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/utils/ui_feedback.dart';

class AnimatedButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool isLoading;
  /// Filled white pill + dark label (Nothing primary).
  final bool isPrimary;
  /// When true, filled electric purple (legacy “accent” CTAs).
  final bool useAccentFill;
  final Color? backgroundColor;
  final Color? textColor;
  final double? width;
  final double? height;

  const AnimatedButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isPrimary = true,
    this.useAccentFill = false,
    this.backgroundColor,
    this.textColor,
    this.width,
    this.height,
  });

  @override
  State<AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<AnimatedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _pressed = false;

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

  void _handleTapDown(TapDownDetails details) {
    setState(() => _pressed = true);
    _controller.forward();
    UiTapFeedback.play();
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _pressed = false);
    _controller.reverse();
  }

  void _handleTapCancel() {
    setState(() => _pressed = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final bool primary = widget.isPrimary;
    final Color effectiveBg = widget.backgroundColor != null
        ? widget.backgroundColor!
        : primary
            ? (widget.useAccentFill
                ? VbColor.accentElectric
                : VbColor.inverseSurface)
            : Colors.transparent;

    final Color effectiveTextColor = widget.textColor != null
        ? widget.textColor!
        : primary
            ? (widget.useAccentFill
                ? Colors.white
                : VbColor.inverseOnSurface)
            : VbColor.onSurface;

    final List<BoxShadow>? glow = (!primary && _pressed)
        ? [
            BoxShadow(
              color: VbColor.accentElectric.withValues(alpha: 0.35),
              blurRadius: 15,
              spreadRadius: 0,
            ),
          ]
        : null;

    return GestureDetector(
      onTapDown: widget.isLoading ? null : _handleTapDown,
      onTapUp: widget.isLoading ? null : _handleTapUp,
      onTapCancel: widget.isLoading ? null : _handleTapCancel,
      onTap: widget.isLoading ? null : widget.onPressed,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: AppAnimations.fast,
          width: widget.width,
          height: widget.height ?? 52,
          decoration: BoxDecoration(
            color: effectiveBg,
            borderRadius: BorderRadius.circular(VbRadii.full),
            border: !primary
                ? Border.all(color: VbColor.outline, width: 1)
                : null,
            boxShadow: glow,
          ),
          child: Material(
            color: Colors.transparent,
            child: Center(
              child: widget.isLoading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(effectiveTextColor),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (widget.icon != null) ...[
                          Icon(
                            widget.icon,
                            color: effectiveTextColor,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                        ],
                        Text(
                          widget.text.toUpperCase(),
                          style:
                              Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: effectiveTextColor,
                                    fontSize: 12,
                                    letterSpacing: 1.2,
                                    fontWeight: FontWeight.w600,
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
