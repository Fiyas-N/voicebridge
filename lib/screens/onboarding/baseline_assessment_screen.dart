import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/prompt.dart';
import '../../providers/auth_provider.dart';
import '../practice/recording_screen.dart';

class BaselineAssessmentScreen extends StatelessWidget {
  const BaselineAssessmentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final baselinePrompt = IELTSPrompts.getBaselinePrompt();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Center(
                child: Icon(Icons.biotech_outlined, size: 64, color: Colors.white),
              ),
              const SizedBox(height: 32),
              const Text(
                'Quick baseline',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'monospace', fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2),
              ),
              const SizedBox(height: 12),
              const Text(
                'One short recording helps us tailor feedback to your level.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textTertiary, fontSize: 11, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 48),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('What to expect', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.textTertiary)),
                    const SizedBox(height: 20),
                    _buildItem('One guided recording'),
                    _buildItem('About 30–45 seconds of speaking'),
                    _buildItem('Follow the on-screen prompt'),
                    _buildItem('Instant feedback after you finish'),
                  ],
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  final auth = Provider.of<AuthProvider>(context, listen: false);
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => RecordingScreen(
                        prompt: baselinePrompt,
                        userId: auth.currentUser!.userId,
                        isBaseline: true,
                      ),
                    ),
                  );
                },
                child: const Text('Start baseline'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        children: [
          const Icon(Icons.radar, color: Colors.white70, size: 16),
          const SizedBox(width: 14),
          Expanded(
            child: Text(text, style: const TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          ),
        ],
      ),
    );
  }
}


