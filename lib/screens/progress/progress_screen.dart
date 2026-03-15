import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../data/local/database_helper.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/glass_card.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  List<Map<String, dynamic>> _sessions = [];
  bool _isLoading = true;
  Map<String, double> _averageScores = {};
  int _totalSessions = 0;
  int _currentStreak = 0;

  @override
  void initState() {
    super.initState();
    _loadProgressData();
  }

  Future<void> _loadProgressData() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.currentUser?.userId;

      if (userId == null) return;

      // Load from local SQLite — has full score data in snake_case columns
      final sessions = await DatabaseHelper.instance.getUserSessions(userId, limit: 100);

      // Only count completed sessions with scores
      final completed = sessions
          .where((s) => s['status'] == 'completed' && s['composite_score'] != null)
          .toList();

      _calculateMetrics(completed);

      setState(() {
        _sessions = completed;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _calculateMetrics(List<Map<String, dynamic>> sessions) {
    if (sessions.isEmpty) {
      _averageScores = {'fluency': 0, 'grammar': 0, 'pronunciation': 0, 'overall': 0};
      _totalSessions = 0;
      _currentStreak = 0;
      return;
    }

    _totalSessions = sessions.length;

    // SQLite uses flat snake_case columns for scores
    double totalFluency = 0, totalGrammar = 0, totalPronunciation = 0, totalOverall = 0;
    int count = 0;

    for (var session in sessions) {
      final f = (session['fluency_score']       as num?)?.toDouble();
      final g = (session['grammar_score']        as num?)?.toDouble();
      final p = (session['pronunciation_score']  as num?)?.toDouble();
      final o = (session['composite_score']      as num?)?.toDouble();
      if (f != null) { totalFluency       += f; }
      if (g != null) { totalGrammar        += g; }
      if (p != null) { totalPronunciation  += p; }
      if (o != null) { totalOverall        += o; count++; }
    }

    final n = count > 0 ? count : 1;
    _averageScores = {
      'fluency':       totalFluency      / n,
      'grammar':       totalGrammar      / n,
      'pronunciation': totalPronunciation / n,
      'overall':       totalOverall      / n,
    };

    _currentStreak = _calculateStreak(sessions);
  }

  int _calculateStreak(List<Map<String, dynamic>> sessions) {
    if (sessions.isEmpty) return 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    int streak = 0;
    DateTime checkDate = today;

    // SQLite uses created_at (snake_case)
    for (var session in sessions) {
      final sessionDate = DateTime.fromMillisecondsSinceEpoch(
        session['created_at'] as int? ?? 0,
      );
      final sessionDay =
          DateTime(sessionDate.year, sessionDate.month, sessionDate.day);

      if (sessionDay == checkDate) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else if (sessionDay.isBefore(checkDate)) {
        break;
      }
    }

    return streak;
  }

  @override
  @override
  Widget build(BuildContext context) {
    Provider.of<AuthProvider>(context); // ensures rebuild on auth changes

    return Scaffold(
      backgroundColor: AppColors.backgroundOffWhite,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Solid App Bar
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
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1.0),
                child: Container(
                  color: AppColors.borderLight,
                  height: 1.0,
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  color: AppColors.surface,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Text(
                            'Progress',
                            style: TextStyle(
                              color: AppColors.textDark,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$_totalSessions sessions completed',
                            style: const TextStyle(
                              color: AppColors.textMedium,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Content
            SliverToBoxAdapter(
              child: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(48.0),
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                        ),
                      ),
                    )
                  : _sessions.isEmpty
                      ? _buildEmptyState(context)
                      : _buildProgressContent(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: GlassCard(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Icon(
              Icons.info_outline,
              size: 64,
              color: AppColors.textLight,
            ),
            const SizedBox(height: 20),
            Text(
              'No Progress Yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Complete practice sessions to see your progress!',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textMedium,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressContent(BuildContext context) {
    // Calculate best score and average band
    double bestScore = 0;
    double totalBand = 0;
    for (final s in _sessions) {
      final comp = (s['composite_score'] as num?)?.toDouble() ?? 0;
      final band = (s['estimated_band']  as num?)?.toDouble() ?? 0;
      if (comp > bestScore) bestScore = comp;
      totalBand += band;
    }
    final avgBand = _sessions.isNotEmpty ? totalBand / _sessions.length : 0;
    final trend = _calcTrend();

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 4-stat grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: [
              _buildStatCard('🔥', 'Streak', '$_currentStreak days', const Color(0xFFFF9600)), // Duolingo orange
              _buildStatCard('📊', 'Sessions', '$_totalSessions total', AppColors.primary),
              _buildStatCard('🏆', 'Best Score', '${bestScore.round()}/100', const Color(0xFFFFC800)), // Star gold
              _buildStatCard('🎯', 'Avg Band', avgBand.toStringAsFixed(1), AppColors.secondary),
            ],
          ),
          const SizedBox(height: 32),

          // Trend label
          Row(
            children: [
              const Text(
                'Score Trend',
                style: TextStyle(color: AppColors.textDark, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (trend != null) ...
                [
                  Icon(
                    trend > 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                    color: trend > 0 ? AppColors.success : AppColors.error,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${trend > 0 ? '+' : ''}${trend.round()} vs last 3',
                    style: TextStyle(
                      color: trend > 0 ? AppColors.success : AppColors.error,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
            ],
          ),
          const SizedBox(height: 16),
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              height: 200,
              child: _buildScoreTrendChart(),
            ),
          ),
          const SizedBox(height: 32),

          // Skills Breakdown
          const Text(
            'Skills Breakdown',
            style: TextStyle(color: AppColors.textDark, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildSkillCard('Fluency & Coherence', _averageScores['fluency']!.toInt(),
                    Icons.speed_rounded, AppColors.primary),
                const SizedBox(height: 24),
                _buildSkillCard('Grammar Range', _averageScores['grammar']!.toInt(),
                    Icons.spellcheck_rounded, AppColors.secondary),
                const SizedBox(height: 24),
                _buildSkillCard('Pronunciation', _averageScores['pronunciation']!.toInt(),
                    Icons.record_voice_over_rounded, const Color(0xFFFF9600)),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  double? _calcTrend() {
    if (_sessions.length < 4) return null;
    final recent = _sessions.take(3).toList();
    final older  = _sessions.skip(3).take(3).toList();
    double recentAvg = 0, olderAvg = 0;
    for (final s in recent) {
      recentAvg += (s['composite_score'] as num?)?.toDouble() ?? 0;
    }
    for (final s in older) {
      olderAvg += (s['composite_score'] as num?)?.toDouble() ?? 0;
    }
    return (recentAvg / recent.length) - (olderAvg / older.length);
  }

  Widget _buildStatCard(
    String emoji,
    String label,
    String value,
    Color accent,
  ) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Text(
                value,
                style: TextStyle(
                  color: AppColors.textDark,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: accent,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreTrendChart() {
    if (_sessions.length < 2) {
      return const Center(
        child: Text(
          'Complete more sessions to see trends',
          style: TextStyle(color: AppColors.textMedium, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
      );
    }

    final recentSessions = _sessions.take(10).toList().reversed.toList();
    final spots = <FlSpot>[];
    for (int i = 0; i < recentSessions.length; i++) {
      final overall = (recentSessions[i]['composite_score'] as num?)?.toDouble() ?? 0;
      spots.add(FlSpot(i.toDouble(), overall));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) => FlLine(
            color: AppColors.borderLight,
            strokeWidth: 2,
            dashArray: [5, 5],
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (v, _) => Text(
                '${v.toInt()}',
                style: const TextStyle(
                  color: AppColors.textMedium,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
              interval: 25,
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (recentSessions.length - 1).toDouble(),
        minY: 0,
        maxY: 100,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.primary,
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                radius: 6,
                color: AppColors.primary,
                strokeWidth: 3,
                strokeColor: Colors.white,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.primary.withOpacity(0.15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillCard(String label, int score, IconData icon, Color accent) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: accent.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accent.withOpacity(0.5), width: 2),
          ),
          child: Icon(icon, color: accent, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '$score/100',
                    style: TextStyle(
                      color: accent,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: score / 100,
                  minHeight: 10,
                  backgroundColor: AppColors.borderLight,
                  valueColor: AlwaysStoppedAnimation<Color>(accent),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

