import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_theme.dart';
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
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    return Scaffold(
      body: Stack(
        children: [
          // Liquid Glass Background
          LiquidGlassContainer(
            height: MediaQuery.of(context).size.height,
            colors: const [
              Color(0xFF1a1a2e),
              Color(0xFF16213e),
              Color(0xFF0f3460),
              Color(0xFF533483),
            ],
            child: const SizedBox.expand(),
          ),
          
          // Content
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Glass App Bar
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
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.15),
                              Colors.white.withValues(alpha: 0.07),
                            ],
                          ),
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                        ),
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
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$_totalSessions sessions completed',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
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
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: GlassCard(
        blur: 15,
        opacity: 0.25,
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.info_outline,
              size: 64,
              color: Colors.white.withOpacity(0.8),
            ),
            const SizedBox(height: 20),
            Text(
              'No Progress Yet',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Complete practice sessions to see your progress!',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.9),
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
    // SQLite uses flat snake_case columns
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
              _buildStatCard('🔥', 'Streak', '$_currentStreak days', const Color(0xFFff6b35)),
              _buildStatCard('📊', 'Sessions', '$_totalSessions total', const Color(0xFF4ecdc4)),
              _buildStatCard('🏆', 'Best Score', '${bestScore.round()}/100', const Color(0xFFffd166)),
              _buildStatCard('🎯', 'Avg Band', avgBand.toStringAsFixed(1), const Color(0xFFc77dff)),
            ],
          ),
          const SizedBox(height: 24),

          // Trend label
          Row(
            children: [
              const Text(
                'Score Trend',
                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (trend != null) ...
                [
                  Icon(
                    trend > 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                    color: trend > 0 ? const Color(0xFF6bcb77) : const Color(0xFFef233c),
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${trend > 0 ? '+' : ''}${trend.round()} vs last 3',
                    style: TextStyle(
                      color: trend > 0 ? const Color(0xFF6bcb77) : const Color(0xFFef233c),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
            ],
          ),
          const SizedBox(height: 12),
          GlassCard(
            blur: 15,
            opacity: 0.2,
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              height: 200,
              child: _buildScoreTrendChart(),
            ),
          ),
          const SizedBox(height: 24),

          // Skills Breakdown
          const Text(
            'Skills Breakdown',
            style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          GlassCard(
            blur: 15,
            opacity: 0.2,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildSkillCard('Fluency & Coherence', _averageScores['fluency']!.toInt(),
                    Icons.speed_rounded, const Color(0xFF4ecdc4)),
                const SizedBox(height: 18),
                _buildSkillCard('Grammar Range', _averageScores['grammar']!.toInt(),
                    Icons.spellcheck_rounded, const Color(0xFF6bcb77)),
                const SizedBox(height: 18),
                _buildSkillCard('Pronunciation', _averageScores['pronunciation']!.toInt(),
                    Icons.record_voice_over_rounded, const Color(0xFFc77dff)),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  double? _calcTrend() {
    if (_sessions.length < 4) return null;
    final recent = _sessions.take(3).toList();
    final older  = _sessions.skip(3).take(3).toList();
    // SQLite uses flat composite_score column
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
      blur: 15,
      opacity: 0.2,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreTrendChart() {
    if (_sessions.length < 2) {
      return Center(
        child: Text(
          'Complete more sessions to see trends',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
          textAlign: TextAlign.center,
        ),
      );
    }

    final recentSessions = _sessions.take(10).toList().reversed.toList();
    final spots = <FlSpot>[];
    for (int i = 0; i < recentSessions.length; i++) {
      // SQLite uses flat composite_score column
      final overall = (recentSessions[i]['composite_score'] as num?)?.toDouble() ?? 0;
      spots.add(FlSpot(i.toDouble(), overall));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) => FlLine(
            color: Colors.white.withValues(alpha: 0.08),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (v, _) => Text(
                '${v.toInt()}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 10,
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
            gradient: const LinearGradient(
              colors: [Color(0xFF4ecdc4), Color(0xFF667eea)],
            ),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                radius: 5,
                color: const Color(0xFF4ecdc4),
                strokeWidth: 2,
                strokeColor: Colors.white,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF4ecdc4).withValues(alpha: 0.3),
                  Colors.transparent,
                ],
              ),
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
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: accent, size: 22),
        ),
        const SizedBox(width: 14),
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
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '$score/100',
                    style: TextStyle(
                      color: accent,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: score / 100,
                  minHeight: 8,
                  backgroundColor: Colors.white.withValues(alpha: 0.12),
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
