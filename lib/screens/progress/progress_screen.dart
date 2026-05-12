import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../data/local/database_helper.dart';
import '../../providers/auth_provider.dart';

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

      final sessions = await DatabaseHelper.instance.getUserSessions(userId, limit: 100);
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
    double totalFluency = 0, totalGrammar = 0, totalPronunciation = 0, totalOverall = 0;
    int count = 0;

    for (var session in sessions) {
      final f = (session['fluency_score']       as num?)?.toDouble();
      final g = (session['grammar_score']        as num?)?.toDouble();
      final p = (session['pronunciation_score']  as num?)?.toDouble();
      final o = (session['composite_score']      as num?)?.toDouble();
      if (f != null) totalFluency += f;
      if (g != null) totalGrammar += g;
      if (p != null) totalPronunciation += p;
      if (o != null) { totalOverall += o; count++; }
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

    for (var session in sessions) {
      final sessionDate = DateTime.fromMillisecondsSinceEpoch(session['created_at'] as int? ?? 0);
      final sessionDay = DateTime(sessionDate.year, sessionDate.month, sessionDate.day);

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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          'Your progress',
          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 16),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _sessions.isEmpty
              ? _buildEmptyState(context)
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  physics: const BouncingScrollPhysics(),
                  child: _buildProgressContent(context),
                ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.analytics_outlined, size: 64, color: AppColors.textTertiary),
            const SizedBox(height: 24),
            const Text(
              'Not enough data yet',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Complete a few practice sessions to see trends and averages.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressContent(BuildContext context) {
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Stat block
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.3,
          children: [
            _buildStatCard('🔥', 'Streak', '$_currentStreak'),
            _buildStatCard('📊', 'Sessions', '$_totalSessions'),
            _buildStatCard('🏆', 'Best score', '${bestScore.round()}'),
            _buildStatCard('🎯', 'Avg IELTS band', avgBand.toStringAsFixed(1)),
          ],
        ),
        const SizedBox(height: 32),

        // Charts
        Container(
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Score trend',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontFamily: 'monospace'),
                  ),
                  if (trend != null)
                    Text(
                      '${trend > 0 ? '+' : ''}${trend.round()}%',
                      style: TextStyle(fontWeight: FontWeight.bold, color: trend > 0 ? AppColors.accentRed : AppColors.textSecondary, fontSize: 11),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 180,
                child: _buildScoreTrendChart(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Breakdown
        const Text(
          'Averages',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: AppColors.textTertiary),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Column(
            children: [
              _buildSkillCard('Fluency', _averageScores['fluency']!.toInt(), Icons.speed_rounded),
              const SizedBox(height: 24),
              _buildSkillCard('Grammar', _averageScores['grammar']!.toInt(), Icons.data_object_rounded),
              const SizedBox(height: 24),
              _buildSkillCard('Pronunciation', _averageScores['pronunciation']!.toInt(), Icons.record_voice_over_outlined),
            ],
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  double? _calcTrend() {
    if (_sessions.length < 4) return null;
    final recent = _sessions.take(3).toList();
    final older  = _sessions.skip(3).take(3).toList();
    double recentAvg = 0, olderAvg = 0;
    for (final s in recent) recentAvg += (s['composite_score'] as num?)?.toDouble() ?? 0;
    for (final s in older) olderAvg += (s['composite_score'] as num?)?.toDouble() ?? 0;
    return (recentAvg / recent.length) - (olderAvg / older.length);
  }

  Widget _buildStatCard(String emoji, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.0, color: AppColors.textTertiary)),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Text(
                value,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScoreTrendChart() {
    if (_sessions.length < 2) {
      return const Center(child: Text('Add at least two sessions to see a chart', style: TextStyle(fontFamily: 'monospace', fontSize: 10)));
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
          getDrawingHorizontalLine: (v) => const FlLine(color: AppColors.borderLight, strokeWidth: 1, dashArray: [4, 4]),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (v, _) => Text('${v.toInt()}', style: const TextStyle(color: AppColors.textTertiary, fontSize: 9, fontFamily: 'monospace')),
              interval: 25,
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        minY: 0, maxY: 100,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.white,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillCard(String label, int score, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textPrimary, size: 20),
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
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                  Text(
                    '$score',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: score / 100,
                  minHeight: 4,
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

