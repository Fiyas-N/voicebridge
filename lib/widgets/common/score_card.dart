import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class ScoreCard extends StatefulWidget {
  final String label;
  final double score;
  final double maxScore;
  final bool animate;
  final IconData? icon;

  const ScoreCard({
    super.key,
    required this.label,
    required this.score,
    this.maxScore = 100,
    this.animate = true,
    this.icon,
  });

  @override
  State<ScoreCard> createState() => _ScoreCardState();
}

class _ScoreCardState extends State<ScoreCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppAnimations.slow,
      vsync: this,
    );
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: widget.score / widget.maxScore,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: AppAnimations.smoothCurve,
    ));

    if (widget.animate) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _controller.forward();
      });
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getScoreColor() {
    final percentage = widget.score / widget.maxScore;
    if (percentage >= 0.85) return AppColors.successGreen;
    if (percentage >= 0.70) return AppColors.accentTeal;
    if (percentage >= 0.50) return AppColors.primaryBlue;
    if (percentage >= 0.35) return AppColors.warningAmber;
    return AppColors.errorRed;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                if (widget.icon != null) ...[
                  Icon(
                    widget.icon,
                    size: 20,
                    color: _getScoreColor(),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  widget.label,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            AnimatedBuilder(
              animation: _progressAnimation,
              builder: (context, child) {
                return Text(
                  '${(widget.score * _progressAnimation.value).toStringAsFixed(0)}',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _getScoreColor(),
                      ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, child) {
              return LinearProgressIndicator(
                value: _progressAnimation.value,
                minHeight: 10,
                backgroundColor: AppColors.lightGray,
                valueColor: AlwaysStoppedAnimation<Color>(_getScoreColor()),
              );
            },
          ),
        ),
      ],
    );
  }
}

// Circular Score Display
class CircularScoreCard extends StatefulWidget {
  final String label;
  final double score;
  final double maxScore;
  final bool animate;

  const CircularScoreCard({
    super.key,
    required this.label,
    required this.score,
    this.maxScore = 100,
    this.animate = true,
  });

  @override
  State<CircularScoreCard> createState() => _CircularScoreCardState();
}

class _CircularScoreCardState extends State<CircularScoreCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppAnimations.slow,
      vsync: this,
    );
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: widget.score / widget.maxScore,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: AppAnimations.smoothCurve,
    ));

    if (widget.animate) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _controller.forward();
      });
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getScoreColor() {
    final percentage = widget.score / widget.maxScore;
    if (percentage >= 0.85) return AppColors.successGreen;
    if (percentage >= 0.70) return AppColors.accentTeal;
    if (percentage >= 0.50) return AppColors.primaryBlue;
    if (percentage >= 0.35) return AppColors.warningAmber;
    return AppColors.errorRed;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: CircularProgressIndicator(
                      value: _progressAnimation.value,
                      strokeWidth: 10,
                      backgroundColor: AppColors.lightGray,
                      valueColor: AlwaysStoppedAnimation<Color>(_getScoreColor()),
                    ),
                  ),
                  Text(
                    '${(widget.score * _progressAnimation.value).toStringAsFixed(0)}',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _getScoreColor(),
                        ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Text(
          widget.label,
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
