import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../data/local/database_helper.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/animated_button.dart';
import 'session_detail_screen.dart';

enum _SortOption { newest, oldest, highestScore, lowestScore }
enum _FilterOption { all, baseline, practice }

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _sessions = [];
  bool _isLoading = true;
  String? _errorMessage;

  _SortOption _sortOption = _SortOption.newest;
  _FilterOption _filterOption = _FilterOption.all;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.currentUser?.userId;
      if (userId == null) throw Exception('User not logged in');

      final sessions = await DatabaseHelper.instance.getUserSessions(userId, limit: 100);

      setState(() {
        _sessions = sessions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _displayedSessions {
    var list = List<Map<String, dynamic>>.from(_sessions);

    if (_filterOption == _FilterOption.baseline) {
      list = list.where((s) => s['type'] == 'baseline').toList();
    } else if (_filterOption == _FilterOption.practice) {
      list = list.where((s) => s['type'] != 'baseline').toList();
    }

    switch (_sortOption) {
      case _SortOption.newest:
        list.sort((a, b) => (b['created_at'] as int? ?? 0).compareTo(a['created_at'] as int? ?? 0));
        break;
      case _SortOption.oldest:
        list.sort((a, b) => (a['created_at'] as int? ?? 0).compareTo(b['created_at'] as int? ?? 0));
        break;
      case _SortOption.highestScore:
        list.sort((a, b) => (b['composite_score'] as num? ?? 0).compareTo(a['composite_score'] as num? ?? 0));
        break;
      case _SortOption.lowestScore:
        list.sort((a, b) => (a['composite_score'] as num? ?? 0).compareTo(b['composite_score'] as num? ?? 0));
        break;
    }

    return list;
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A0A),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: const Border(top: BorderSide(color: AppColors.borderLight, width: 1)),
        ),
        padding: const EdgeInsets.all(28),
        child: StatefulBuilder(
          builder: (ctx, setSheet) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('CONFIGURATION',
                    style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 12, color: Colors.white)),
                const SizedBox(height: 24),
                const Text('FILTERING', style: TextStyle(color: AppColors.textTertiary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _chip('ALL', _filterOption == _FilterOption.all, () => setSheet(() => _filterOption = _FilterOption.all)),
                    _chip('PRACTICE', _filterOption == _FilterOption.practice, () => setSheet(() => _filterOption = _FilterOption.practice)),
                    _chip('BASELINE', _filterOption == _FilterOption.baseline, () => setSheet(() => _filterOption = _FilterOption.baseline)),
                  ],
                ),
                const SizedBox(height: 24),
                const Text('ORDERING', style: TextStyle(color: AppColors.textTertiary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _chip('NEWEST', _sortOption == _SortOption.newest, () => setSheet(() => _sortOption = _SortOption.newest)),
                    _chip('OLDEST', _sortOption == _SortOption.oldest, () => setSheet(() => _sortOption = _SortOption.oldest)),
                    _chip('MAX SCORE', _sortOption == _SortOption.highestScore, () => setSheet(() => _sortOption = _SortOption.highestScore)),
                    _chip('MIN SCORE', _sortOption == _SortOption.lowestScore, () => setSheet(() => _sortOption = _SortOption.lowestScore)),
                  ],
                ),
                const SizedBox(height: 32),
                AnimatedButton(
                  text: 'CONFIRM',
                  onPressed: () {
                    setState(() {}); 
                    Navigator.pop(ctx);
                  },
                ),
                const SizedBox(height: 8),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? Colors.white : AppColors.borderLight),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : AppColors.textSecondary,
            fontWeight: FontWeight.bold,
            fontSize: 11,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          'SESSION ARCHIVE'.toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune, color: Colors.white, size: 20),
            onPressed: _showFilterSheet,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
            onPressed: _loadSessions,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.warning_amber_rounded, size: 48, color: AppColors.accentRed),
              const SizedBox(height: 16),
              Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 24),
              AnimatedButton(text: 'RETRY', onPressed: _loadSessions, width: 120),
            ],
          ),
        ),
      );
    }

    final displayed = _displayedSessions;

    if (displayed.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.storage_outlined, size: 64, color: Colors.white.withValues(alpha: 0.1)),
              const SizedBox(height: 24),
              const Text(
                'ARCHIVE EMPTY',
                style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      physics: const BouncingScrollPhysics(),
      itemCount: displayed.length,
      itemBuilder: (ctx, i) => _buildSessionCard(displayed[i]),
    );
  }

  Widget _buildSessionCard(Map<String, dynamic> session) {
    final createdAt = DateTime.fromMillisecondsSinceEpoch(session['created_at'] as int? ?? 0);
    final overallScore = (session['composite_score'] as num? ?? 0);
    final dateStr  = _formatDate(createdAt);
    final timeAgo  = _formatTimeAgo(createdAt);
    final bool isBaseline = session['type'] == 'baseline';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => SessionDetailScreen(session: session)),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${overallScore.toInt()}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                    ),
                    Text(
                      session['cefr_level'] as String? ?? 'A1',
                      style: const TextStyle(fontSize: 9, color: AppColors.textTertiary, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          dateStr.toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                        ),
                        if (isBaseline) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.accentRed.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'CORE',
                              style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: AppColors.accentRed, letterSpacing: 0.5),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeAgo.toUpperCase(),
                      style: const TextStyle(color: AppColors.textTertiary, fontSize: 11, fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final sessionDate = DateTime(date.year, date.month, date.day);

    if (sessionDate == today) return 'Today';
    if (sessionDate == yesterday) return 'Yesterday';
    return DateFormat('MMM d, yyyy').format(date);
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final d = now.difference(date);
    if (d.inMinutes < 1) return 'Now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays}d ago';
    return DateFormat('MMM d').format(date);
  }
}

