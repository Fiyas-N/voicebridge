import 'package:flutter_test/flutter_test.dart';
import 'package:voicebridge_final/services/feedback_service.dart';
import 'package:voicebridge_final/services/grammar_service.dart';

void main() {
  group('FeedbackService tests', () {
    test('buildPrompt formats grammar errors and mispronounced words correctly', () {
      final feedbackService = FeedbackService();

      final prompt = feedbackService.buildPrompt(
        fluencyScore: 85.0,
        grammarScore: 70.0,
        pronunciationScore: 60.0,
        grammarErrors: [
          GrammarError(
            original: "he go",
            correction: "he goes",
            explanation: "Third-person singular verb agreement",
            type: "agreement",
          ),
        ],
        mispronounced: ["schedule", "February"],
      );

      print('--- Generated Prompt ---');
      print(prompt);
      print('------------------------');

      expect(prompt.contains('• "he go" → "he goes": Third-person singular verb agreement'), isTrue);
      expect(prompt.contains('• schedule'), isTrue);
      expect(prompt.contains('• February'), isTrue);
      expect(prompt.contains('Fluency: 85.0'), isTrue);
      expect(prompt.contains('Grammar: 70.0'), isTrue);
      expect(prompt.contains('Pronunciation: 60.0'), isTrue);
    });
  });
}
