import 'dart:ui';
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
      body: Stack(
        children: [
          // Liquid Glass Background
          LiquidGlassContainer(
            height: MediaQuery.of(context).size.height,
            colors: const [
              Color(0xFFe0e0e0), // Light Gray
              Color(0xFF9e9e9e), // Silver
              Color(0xFF616161), // Charcoal
              Color(0xFF212121), // Dark Gray
            ],
            child: const SizedBox.expand(),
          ),
          
          // Content
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                  const SizedBox(height: 60),
                  
                  // App Logo/Icon
                  GlassCard(
                    blur: 15,
                    opacity: 0.25,
                    padding: const EdgeInsets.all(32),
                    borderRadius: BorderRadius.circular(40),
                    child: const Icon(
                      Icons.mic,
                      size: 80,
                      color: Colors.white,
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Title
                  Text(
                    'VoiceBridge',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 48,
                        ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Subtitle
                  Text(
                    'Master English Speaking\nwith AI-Powered Feedback',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white.withOpacity(0.9),
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
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 60),
                  
                  // Buttons
                  GlassButton(
                    blur: 10,
                    opacity: 0.2,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SignupScreen()),
                      );
                    },
                    child: const Text(
                      'Get Started',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  GlassButton(
                    blur: 10,
                    opacity: 0.2,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    child: const Text(
                      'I Already Have an Account',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(IconData icon, String label) {
    return GlassCard(
      blur: 15,
      opacity: 0.2,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 32),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
