import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/common/glass_card.dart';
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
              curve: Curves.elasticOut,
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
    return Scaffold(
      backgroundColor: AppColors.backgroundOffWhite,
      body: SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                  const SizedBox(height: 60),
                  
                  // App Logo/Icon
                  GlassCard(
                    padding: const EdgeInsets.all(32),
                    borderRadius: BorderRadius.circular(40),
                    child: const Icon(
                      Icons.mic,
                      size: 80,
                      color: AppColors.primary,
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Title
                  const Text(
                    'VoiceBridge',
                    style: TextStyle(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 48,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Subtitle
                  const Text(
                    'Master English Speaking\nwith AI-Powered Feedback',
                    style: TextStyle(
                      color: AppColors.textMedium,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
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
                            Icons.mic_none,
                            'Practice\nSpeaking',
                            AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ScaleTransition(
                          scale: _iconAnimations[1],
                          child: _buildFeatureCard(
                            Icons.analytics_outlined,
                            'Get AI\nFeedback',
                            AppColors.secondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ScaleTransition(
                          scale: _iconAnimations[2],
                          child: _buildFeatureCard(
                            Icons.trending_up,
                            'Track\nProgress',
                            const Color(0xFFFF9600), // Duolingo orange
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 60),
                  
                  // Buttons
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SignupScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Get Started',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textDark,
                      minimumSize: const Size(double.infinity, 56),
                      side: const BorderSide(color: AppColors.borderMedium, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'I Already Have an Account',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
    return GlassCard(
      padding: const EdgeInsets.all(12),
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}
