import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/common/glass_card.dart';

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

    return Scaffold(
      body: Stack(
        children: [
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
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // App Bar
                SliverAppBar(
                  expandedHeight: 120,
                  floating: false,
                  pinned: true,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  flexibleSpace: ClipRRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                        ),
                        child: SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 64, vertical: 16),
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
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                Text(
                                  DateFormat('MMMM d, yyyy · h:mm a')
                                      .format(createdAt),
                                  style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 13),
                                ),
                              ],
                            ),
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
                          blur: 15,
                          opacity: 0.25,
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              // Overall + Band
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _bigScore(context, overall.toInt().toString(),
                                      'Overall'),
                                  const SizedBox(width: 32),
                                  _bigScore(context, band.toStringAsFixed(1),
                                      'Speaking Band'),
                                ],
                              ),
                              const SizedBox(height: 24),
                              // Category bars
                              _scorebar(context, 'Fluency', fluency),
                              const SizedBox(height: 12),
                              _scorebar(context, 'Grammar', grammar),
                              const SizedBox(height: 12),
                              _scorebar(context, 'Pronunciation', pronunciation),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ── Prompt ─────────────────────────────────────────
                        if (promptText.isNotEmpty) ...[
                          _sectionCard(
                            context,
                            icon: Icons.chat_bubble_outline,
                            title: 'Prompt',
                            body: promptText,
                          ),
                          const SizedBox(height: 16),
                        ],

                        // ── Transcript ────────────────────────────────────
                        if (transcript.isNotEmpty) ...[
                          _sectionCard(
                            context,
                            icon: Icons.text_snippet_outlined,
                            title: 'Your Transcript',
                            body: transcript,
                          ),
                          const SizedBox(height: 16),
                        ] else ...[
                          _sectionCard(
                            context,
                            icon: Icons.text_snippet_outlined,
                            title: 'Transcript',
                            body: 'No transcript available for this session.',
                          ),
                          const SizedBox(height: 16),
                        ],

                        // ── Feedback ───────────────────────────────────────
                        if (feedback.isNotEmpty) ...[
                          _sectionCard(
                            context,
                            icon: Icons.lightbulb_outline,
                            title: 'AI Feedback',
                            body: feedback,
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
        ],
      ),
    );
  }

  Widget _bigScore(BuildContext context, String value, String label) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 48,
                fontWeight: FontWeight.bold)),
        Text(label,
            style: TextStyle(
                color: Colors.white.withOpacity(0.7), fontSize: 13)),
      ],
    );
  }

  Widget _scorebar(BuildContext context, String label, double score) {
    final pct = (score / 100).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
            Text('${score.toInt()}',
                style: const TextStyle(
                    color: Colors.white,
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
            backgroundColor: Colors.white.withOpacity(0.15),
            valueColor:
                const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _sectionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String body,
  }) {
    return GlassCard(
      blur: 15,
      opacity: 0.2,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Text(body,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                  height: 1.5)),
        ],
      ),
    );
  }
}
