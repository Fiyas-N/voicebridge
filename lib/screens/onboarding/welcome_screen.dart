import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'signup_screen.dart';
import 'login_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with TickerProviderStateMixin {
  late List<AnimationController> _iconControllers;
  late List<Animation<double>> _iconAnimations;

  @override
  void initState() {
    super.initState();
    _iconControllers = List.generate(
      3,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      ),
    );

    _iconAnimations = _iconControllers
        .map((controller) => CurvedAnimation(
              parent: controller,
              curve: Curves.easeOutBack,
            ))
        .toList();

    // Stagger animations
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _iconControllers[0].forward();
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _iconControllers[1].forward();
    });
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) _iconControllers[2].forward();
    });
  }

  @override
  void dispose() {
    for (var controller in _iconControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(28.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                  const SizedBox(height: 60),
                  
                  // App Logo/Icon
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.borderLight, width: 1.5),
                    ),
                    child: const Icon(
                      Icons.mic,
                      size: 64,
                      color: AppColors.primary,
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Title
                  Text(
                    'VoiceBridge'.toUpperCase(),
                    style: theme.textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.0,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Subtitle
                  Text(
                    'ADVANCED ENGLISH SPEAKING\nAI-POWERED FEEDBACK',
                    style: theme.textTheme.bodySmall?.copyWith(
                      letterSpacing: 1.2,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 60),
                  
                  // Feature Cards
                  Row(
                    children: [
                      Expanded(
                        child: ScaleTransition(
                          scale: _iconAnimations[0],
                          child: _buildFeatureCard(
                            Icons.graphic_eq,
                            'PRACTICE',
                            AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ScaleTransition(
                          scale: _iconAnimations[1],
                          child: _buildFeatureCard(
                            Icons.auto_awesome,
                            'ANALYZE',
                            AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ScaleTransition(
                          scale: _iconAnimations[2],
                          child: _buildFeatureCard(
                            Icons.insights,
                            'TRACK',
                            AppColors.accentRed, // Distinct Red Dot Element
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 60),
                  
                  // Buttons using theme extensions automatically
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SignupScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 60),
                    ),
                    child: const Text('GET STARTED'),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 60),
                    ),
                    child: const Text('I HAVE AN ACCOUNT'),
                  ),
                  
                  const SizedBox(height: 40),
                ],
                ),
              ),
            ),
          ),
    );
  }

  Widget _buildFeatureCard(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
