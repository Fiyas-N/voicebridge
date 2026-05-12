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
                'CALIBRATION_REQUIRED',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'monospace', fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2),
              ),
              const SizedBox(height: 12),
              const Text(
                'ESTABLISHING PERFORMANCE BASELINE',
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
                    const Text('PROCEDURE_PARAMETERS:', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.textTertiary)),
                    const SizedBox(height: 20),
                    _buildItem('SINGLE_INSTANCE RUN'),
                    _buildItem('INTERVAL: 30-45 SECONDS'),
                    _buildItem('PROMPT_DRIVEN SPEECH'),
                    _buildItem('REALTIME_ANALYSIS ENGINE'),
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
                child: const Text('INITIALIZE_SEQUENCE'),
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


