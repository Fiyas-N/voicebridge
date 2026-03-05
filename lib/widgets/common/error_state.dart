import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Error State Widget
/// Displays helpful error messages with retry actions
class ErrorState extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onRetry;

  const ErrorState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.error_outline,
    this.actionLabel,
    this.onRetry,
  });

  /// Network error state
  factory ErrorState.network({VoidCallback? onRetry}) {
    return ErrorState(
      title: 'No Internet Connection',
      message: 'Please check your connection and try again.',
      icon: Icons.wifi_off,
      actionLabel: 'Retry',
      onRetry: onRetry,
    );
  }

  /// Server error state
  factory ErrorState.server({VoidCallback? onRetry}) {
    return ErrorState(
      title: 'Something Went Wrong',
      message: 'We\'re having trouble connecting to our servers. Please try again later.',
      icon: Icons.cloud_off,
      actionLabel: 'Retry',
      onRetry: onRetry,
    );
  }

  /// Not found error state
  factory ErrorState.notFound({String? itemName}) {
    return ErrorState(
      title: '${itemName ?? 'Content'} Not Found',
      message: 'The ${itemName?.toLowerCase() ?? 'content'} you\'re looking for doesn\'t exist.',
      icon: Icons.search_off,
    );
  }

  /// Permission error state
  factory ErrorState.permission({required String permission, VoidCallback? onRetry}) {
    return ErrorState(
      title: 'Permission Required',
      message: 'We need $permission permission to continue. Please grant access in settings.',
      icon: Icons.lock_outline,
      actionLabel: 'Open Settings',
      onRetry: onRetry,
    );
  }

  /// Generic error state
  factory ErrorState.generic({String? message, VoidCallback? onRetry}) {
    return ErrorState(
      title: 'Oops!',
      message: message ?? 'Something unexpected happened. Please try again.',
      icon: Icons.error_outline,
      actionLabel: 'Try Again',
      onRetry: onRetry,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Error icon with animation
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: AppAnimations.medium,
              curve: AppAnimations.bounceCurve,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: child,
                );
              },
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.errorRed.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 50,
                  color: AppColors.errorRed,
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Title
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkText,
                  ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 12),
            
            // Message
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.mediumGray,
                  ),
              textAlign: TextAlign.center,
            ),
            
            // Retry button
            if (onRetry != null && actionLabel != null) ...[
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(actionLabel!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
