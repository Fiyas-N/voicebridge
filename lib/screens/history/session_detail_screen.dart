import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../../core/theme/app_theme.dart';
import '../../services/local_stt_service.dart';
import '../../widgets/common/word_highlight_widget.dart';

class SessionDetailScreen extends StatelessWidget {
  final Map<String, dynamic> session;

  const SessionDetailScreen({
    super.key,
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    final createdAt = DateTime.fromMillisecondsSinceEpoch(session['created_at'] as int? ?? 0);
    final fluency = (session['fluency_score'] as num? ?? 0).toDouble();
    final grammar = (session['grammar_score'] as num? ?? 0).toDouble();
    final pronunciation = (session['pronunciation_score'] as num? ?? 0).toDouble();
    final overall = (session['composite_score'] as num? ?? 0).toDouble();
    final band = (session['estimated_band'] as num? ?? 0).toDouble();
    final transcript = session['transcript'] as String? ?? '';
    final feedback = session['feedback'] as String? ?? '';
    final promptText = session['prompt_text'] as String? ?? '';
    List<String> grammarCorrections = [];
    List<String> improvementTips = [];
    List<String> advancedVocabulary = [];
    List<WordInfo> wordResults = [];

    try {
      if (session['grammar_corrections'] != null) {
        grammarCorrections = (jsonDecode(session['grammar_corrections'] as String) as List).cast<String>();
      }
      if (session['improvement_tips'] != null) {
        improvementTips = (jsonDecode(session['improvement_tips'] as String) as List).cast<String>();
      }
      if (session['advanced_vocabulary'] != null) {
        advancedVocabulary = (jsonDecode(session['advanced_vocabulary'] as String) as List).cast<String>();
      }
      if (session['word_results'] != null) {
        wordResults = (jsonDecode(session['word_results'] as String) as List)
            .map((w) => WordInfo.fromJson(w as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('Error: $e');
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          'Session details',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Center(
              child: Text(
                DateFormat('MMM dd, HH:mm').format(createdAt).toUpperCase(),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: AppColors.textTertiary),
              ),
            ),
          )
        ],
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _bigScore('Score', overall.toInt().toString()),
                    _bigScore('IELTS band', band.toStringAsFixed(1)),
                    _bigScore('CEFR', session['cefr_level'] as String? ?? 'A1'),
                  ],
                ),
                const SizedBox(height: 32),
                _scoreLine('Fluency', fluency),
                const SizedBox(height: 16),
                _scoreLine('Grammar', grammar),
                const SizedBox(height: 16),
                _scoreLine('Pronunciation', pronunciation),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (promptText.isNotEmpty)
            _dataCard('Prompt', Icons.short_text, Text(promptText, style: const TextStyle(color: Colors.white, height: 1.4))),
          if (transcript.isNotEmpty)
            _dataCard(
              'Transcript',
              Icons.description_outlined,
              wordResults.isNotEmpty
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        WordHighlightWidget(words: wordResults),
                        const SizedBox(height: 16),
                        const WordHighlightLegend(),
                      ],
                    )
                  : Text(transcript, style: const TextStyle(color: Colors.white, height: 1.4)),
            ),
          if (feedback.isNotEmpty) _dataCard('Feedback', Icons.insights_rounded, Text(feedback, style: const TextStyle(color: AppColors.textSecondary, height: 1.5, fontSize: 13))),
          if (grammarCorrections.isNotEmpty)
            _dataCard(
              'Grammar notes',
              Icons.edit_note_rounded,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: grammarCorrections.map((e) => _listEntry(e)).toList(),
              ),
            ),
          if (improvementTips.isNotEmpty)
            _dataCard(
              'Fluency tips',
              Icons.bolt_rounded,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: improvementTips.map((e) => _listEntry(e)).toList(),
              ),
            ),
          if (advancedVocabulary.isNotEmpty)
            _dataCard(
              'Vocabulary ideas',
              Icons.menu_book_rounded,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: advancedVocabulary.map((e) => _listEntry(e)).toList(),
              ),
            ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _bigScore(String label, String val) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: AppColors.textTertiary, fontWeight: FontWeight.bold, letterSpacing: 1)),
        const SizedBox(height: 6),
        Text(val, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
      ],
    );
  }

  Widget _scoreLine(String lbl, double val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(lbl, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textTertiary)),
            Text('${val.toInt()}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: (val / 100).clamp(0.0, 1.0),
            minHeight: 4,
            backgroundColor: Colors.white.withValues(alpha: 0.05),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _dataCard(String title, IconData icon, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: AppColors.textTertiary),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1, color: AppColors.textTertiary, fontSize: 10)),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _listEntry(String txt) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('» ', style: TextStyle(color: AppColors.textTertiary, fontWeight: FontWeight.bold)),
          Expanded(child: Text(txt, style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.textSecondary))),
        ],
      ),
    );
  }
}

