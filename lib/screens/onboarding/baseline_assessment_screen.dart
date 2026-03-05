import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/prompt.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/glass_card.dart';
import '../practice/recording_screen.dart';

class BaselineAssessmentScreen extends StatelessWidget {
  const BaselineAssessmentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final baselinePrompt = IELTSPrompts.getBaselinePrompt();

    return Scaffold(
      body: Stack(
        children: [
          // Liquid Glass Background
          LiquidGlassContainer(
            height: MediaQuery.of(context).size.height,
            colors: const [
              Color(0xFFe0e0e0),
              Color(0xFF9e9e9e),
              Color(0xFFe0e0e0),
              Color(0xFF616161),
            ],
            child: const SizedBox.expand(),
          ),
          
          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Baseline Assessment',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Before you start practicing, we need to understand your current speaking level',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white.withOpacity(0.9),
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  
                  // Glass Card
                  GlassCard(
                    blur: 15,
                    opacity: 0.25,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'What to expect:',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 20),
                        _buildExpectationItem(context, 'One-time test'),
                        _buildExpectationItem(context, '30-45 seconds'),
                        _buildExpectationItem(context, 'Simple prompt'),
                        _buildExpectationItem(context, 'No interruptions'),
                      ],
                    ),
                  ),
                  
                  const Spacer(),
                  
                  // Glass Button
                  GlassButton(
                    blur: 10,
                    opacity: 0.2,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    onPressed: () {
                      final authProvider = Provider.of<AuthProvider>(context, listen: false);
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => RecordingScreen(
                            prompt: baselinePrompt,
                            userId: authProvider.currentUser!.userId,
                            isBaseline: true,
                          ),
                        ),
                      );
                    },
                    child: const Text(
                      'I\'m Ready to Begin',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpectationItem(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white,
                ),
          ),
        ],
      ),
    );
  }
}

