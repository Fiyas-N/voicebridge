import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/haptic_feedback.dart' as haptic;

class AnimatedButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isPrimary;
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
    _controller.forward();
    haptic.HapticFeedback.buttonTap();
  }

  void _handleTapUp(TapUpDetails details) {
    _controller.reverse();
  }

  void _handleTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final Color effectiveBg = widget.isPrimary 
        ? AppColors.primary 
        : (widget.backgroundColor ?? Colors.transparent);
        
    final Color effectiveTextColor = widget.isPrimary 
        ? Colors.black 
        : (widget.textColor ?? AppColors.textPrimary);

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
          height: widget.height ?? 58,
          decoration: BoxDecoration(
            color: effectiveBg,
            borderRadius: BorderRadius.circular(32),
            border: !widget.isPrimary 
                ? Border.all(color: AppColors.borderMedium, width: 1.5)
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: Center(
              child: widget.isLoading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(effectiveTextColor),
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
                          widget.text.toUpperCase(), // Nothing aesthetic uses uppercases for action
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: effectiveTextColor,
                                fontSize: 14,
                                letterSpacing: 1.5,
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
