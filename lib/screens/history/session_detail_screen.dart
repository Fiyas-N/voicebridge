import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../../core/theme/app_theme.dart';
import '../../services/local_stt_service.dart';
import '../../widgets/common/glass_card.dart';
import '../../widgets/common/word_highlight_widget.dart';

class SessionDetailScreen extends StatelessWidget {
  final Map<String, dynamic> session;

  const SessionDetailScreen({
    super.key,
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    // SQLite uses snake_case column names
    final createdAt = DateTime.fromMillisecondsSinceEpoch(
      session['created_at'] as int? ?? 0,
    );
    final fluency      = (session['fluency_score']      as num? ?? 0).toDouble();
    final grammar      = (session['grammar_score']      as num? ?? 0).toDouble();
    final pronunciation= (session['pronunciation_score'] as num? ?? 0).toDouble();
    final overall      = (session['composite_score']    as num? ?? 0).toDouble();
    final band         = (session['estimated_band']     as num? ?? 0).toDouble();
    final transcript   = session['transcript']  as String? ?? '';
    final feedback     = session['feedback']    as String? ?? '';
    final promptText   = session['prompt_text'] as String? ?? '';
    final type         = session['type']        as String? ?? 'practice';

    // Parse granular feedback
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
      debugPrint('Error parsing granular feedback: $e');
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundOffWhite,
      body: SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // App Bar
                SliverAppBar(
                  expandedHeight: 120,
                  floating: false,
                  pinned: true,
                  backgroundColor: AppColors.surface,
                  elevation: 0,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
                    onPressed: () => Navigator.pop(context),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      color: AppColors.surface,
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                type == 'baseline'
                                    ? 'Baseline Session'
                                    : 'Practice Session',
                                style: Theme.of(context)
                                    .textTheme
                                    .displaySmall
                                    ?.copyWith(
                                      color: AppColors.textDark,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 24,
                                    ),
                              ),
                              Text(
                                DateFormat('MMMM d, yyyy · h:mm a')
                                    .format(createdAt),
                                style: const TextStyle(
                                    color: AppColors.textMedium,
                                    fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Score Summary ──────────────────────────────────
                        GlassCard(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              // Overall + Band
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _bigScore(context, overall.toInt().toString(),
                                      'Overall', AppColors.primary),
                                  const SizedBox(width: 32),
                                  _bigScore(context, band.toStringAsFixed(1),
                                      'Band', AppColors.secondary),
                                  const SizedBox(width: 32),
                                  _bigScore(context,
                                    session['cefr_level'] as String? ?? 'A1',
                                    'CEFR', AppColors.accentPurple),
                                ],
                              ),
                              const SizedBox(height: 24),
                              // Category bars
                              _scorebar(context, 'Fluency', fluency, AppColors.primary),
                              const SizedBox(height: 12),
                              _scorebar(context, 'Grammar', grammar, AppColors.secondary),
                              const SizedBox(height: 12),
                              _scorebar(context, 'Pronunciation', pronunciation, const Color(0xFFFF9600)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ── Prompt ─────────────────────────────────────────
                        if (promptText.isNotEmpty) ...[
                          _sectionCard(
                            context,
                            icon: Icons.chat_bubble_outline,
                            title: 'Prompt',
                            body: promptText,
                            iconColor: AppColors.secondary,
                          ),
                          const SizedBox(height: 16),
                        ],

                        // ── Transcript ────────────────────────────────────
                        if (transcript.isNotEmpty) ...[
                          _sectionCard(
                            context,
                            icon: Icons.text_snippet_outlined,
                            title: 'Your Transcription',
                            bodyWidget: wordResults.isNotEmpty
                                ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      WordHighlightWidget(words: wordResults),
                                      const SizedBox(height: 12),
                                      const WordHighlightLegend(),
                                    ],
                                  )
                                : Text(transcript,
                                    style: const TextStyle(
                                        color: AppColors.textMedium,
                                        fontSize: 14,
                                        height: 1.6)),
                            iconColor: AppColors.primary,
                          ),
                          const SizedBox(height: 16),
                        ],

                        // ── Feedback ───────────────────────────────────────
                        if (feedback.isNotEmpty) ...[
                          _sectionCard(
                            context,
                            icon: Icons.lightbulb_outline,
                            title: 'AI Insights',
                            body: feedback,
                            iconColor: const Color(0xFFFF9600),
                          ),
                        ],

                        // ── Grammar Fixes ──────────────────────────────────
                        if (grammarCorrections.isNotEmpty) ...[
                          _sectionCard(
                            context,
                            icon: Icons.spellcheck_rounded,
                            title: 'Grammar Corrections',
                            bodyWidget: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: grammarCorrections.map((e) => _listItem(e)).toList(),
                            ),
                            iconColor: AppColors.secondary,
                          ),
                          const SizedBox(height: 16),
                        ],

                        // ── Native Tips ────────────────────────────────────
                        if (improvementTips.isNotEmpty) ...[
                          _sectionCard(
                            context,
                            icon: Icons.auto_awesome_rounded,
                            title: 'Native-Level Tips',
                            bodyWidget: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: improvementTips.map((e) => _listItem(e)).toList(),
                            ),
                            iconColor: const Color(0xFF6bcb77),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // ── Advanced Vocabulary ─────────────────────────────
                        if (advancedVocabulary.isNotEmpty) ...[
                          _sectionCard(
                            context,
                            icon: Icons.style_rounded,
                            title: 'Power Vocabulary',
                            bodyWidget: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: advancedVocabulary.map((e) => _listItem(e)).toList(),
                            ),
                            iconColor: AppColors.accentPurple,
                          ),
                          const SizedBox(height: 24),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _bigScore(BuildContext context, String value, String label, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: 32,
                fontWeight: FontWeight.bold)),
        Text(label,
            style: const TextStyle(
                color: AppColors.textMedium, fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _scorebar(BuildContext context, String label, double score, Color color) {
    final pct = (score / 100).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppColors.textDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            Text('${score.toInt()}',
                style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 8,
            backgroundColor: AppColors.borderLight,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _sectionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? body,
    Widget? bodyWidget,
    required Color iconColor,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 10),
              Text(title,
                  style: const TextStyle(
                      color: AppColors.textDark,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          bodyWidget ?? Text(body!,
              style: const TextStyle(
                  color: AppColors.textMedium,
                  fontSize: 14,
                  height: 1.6)),
        ],
      ),
    );
  }

  Widget _listItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: AppColors.textMedium, fontSize: 16)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  color: AppColors.textMedium, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

