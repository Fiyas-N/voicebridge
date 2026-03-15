import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../data/local/database_helper.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/glass_card.dart';
import '../../widgets/common/animated_button.dart';
import 'session_detail_screen.dart';

// ─── Filter / Sort options ─────────────────────────────────────────────────
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

      // Load from local SQLite — has full data (transcript, feedback, scores)
      final sessions = await DatabaseHelper.instance.getUserSessions(userId, limit: 100);

      setState(() {
        _sessions = sessions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load sessions: $e';
        _isLoading = false;
      });
    }
  }

  // ─── Derived list after filter + sort ──────────────────────────────────────
  List<Map<String, dynamic>> get _displayedSessions {
    var list = List<Map<String, dynamic>>.from(_sessions);

    // Filter — SQLite uses snake_case 'type' field (same name)
    if (_filterOption == _FilterOption.baseline) {
      list = list.where((s) => s['type'] == 'baseline').toList();
    } else if (_filterOption == _FilterOption.practice) {
      list = list.where((s) => s['type'] != 'baseline').toList();
    }

    // Sort — SQLite uses snake_case: created_at, composite_score
    switch (_sortOption) {
      case _SortOption.newest:
        list.sort((a, b) =>
            (b['created_at'] as int? ?? 0).compareTo(a['created_at'] as int? ?? 0));
        break;
      case _SortOption.oldest:
        list.sort((a, b) =>
            (a['created_at'] as int? ?? 0).compareTo(b['created_at'] as int? ?? 0));
        break;
      case _SortOption.highestScore:
        list.sort((a, b) {
          final sa = (a['composite_score'] as num? ?? 0);
          final sb = (b['composite_score'] as num? ?? 0);
          return sb.compareTo(sa);
        });
        break;
      case _SortOption.lowestScore:
        list.sort((a, b) {
          final sa = (a['composite_score'] as num? ?? 0);
          final sb = (b['composite_score'] as num? ?? 0);
          return sa.compareTo(sb);
        });
        break;
    }

    return list;
  }

  // ─── Filter / Sort bottom sheet ───────────────────────────────────────────
  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: AppColors.backgroundOffWhite,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AppColors.borderLight, width: 2),
        ),
        padding: const EdgeInsets.all(24),
        child: StatefulBuilder(
          builder: (ctx, setSheet) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Filter & Sort',
                    style: TextStyle(
                        color: AppColors.textDark,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                const Text('FILTER BY',
                    style: TextStyle(
                        color: AppColors.textMedium,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _chip('All', _filterOption == _FilterOption.all,
                        () => setSheet(() => _filterOption = _FilterOption.all)),
                    _chip('Practice', _filterOption == _FilterOption.practice,
                        () => setSheet(() => _filterOption = _FilterOption.practice)),
                    _chip('Baseline', _filterOption == _FilterOption.baseline,
                        () => setSheet(() => _filterOption = _FilterOption.baseline)),
                  ],
                ),
                const SizedBox(height: 24),
                const Text('SORT BY',
                    style: TextStyle(
                        color: AppColors.textMedium,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _chip('Newest', _sortOption == _SortOption.newest,
                        () => setSheet(() => _sortOption = _SortOption.newest)),
                    _chip('Oldest', _sortOption == _SortOption.oldest,
                        () => setSheet(() => _sortOption = _SortOption.oldest)),
                    _chip('Highest Score',
                        _sortOption == _SortOption.highestScore,
                        () => setSheet(
                            () => _sortOption = _SortOption.highestScore)),
                    _chip('Lowest Score',
                        _sortOption == _SortOption.lowestScore,
                        () => setSheet(
                            () => _sortOption = _SortOption.lowestScore)),
                  ],
                ),
                const SizedBox(height: 32),
                AnimatedButton(
                  text: 'Apply',
                  icon: Icons.check,
                  width: double.infinity,
                  onPressed: () {
                    setState(() {}); // Apply to main screen
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(0.15) : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.borderLight, width: 2),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? AppColors.primary : AppColors.textMedium,
                fontWeight: selected ? FontWeight.bold : FontWeight.w600)),
      ),
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
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
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1.0),
                child: Container(
                  color: AppColors.borderLight,
                  height: 1.0,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.tune, color: AppColors.textDark),
                  tooltip: 'Filter & Sort',
                  onPressed: _showFilterSheet,
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: AppColors.textDark),
                  tooltip: 'Refresh',
                  onPressed: _loadSessions,
                ),
              ],
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
                            'History',
                            style: Theme.of(context)
                                .textTheme
                                .displayMedium
                                ?.copyWith(
                                    color: AppColors.textDark,
                                    fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_displayedSessions.length} of ${_sessions.length} sessions',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                    color: AppColors.textMedium,
                                    fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Active filter chips summary bar
            if (!_isLoading && _sessions.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.filter_list,
                          color: AppColors.primary, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        _filterLabel(),
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                      ),
                      const SizedBox(width: 24),
                      const Icon(Icons.sort,
                          color: AppColors.secondary, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        _sortLabel(),
                        style: const TextStyle(
                            color: AppColors.secondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),

            // List
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: _buildContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _filterLabel() {
    switch (_filterOption) {
      case _FilterOption.all:
        return 'All sessions';
      case _FilterOption.baseline:
        return 'Baseline only';
      case _FilterOption.practice:
        return 'Practice only';
    }
  }

  String _sortLabel() {
    switch (_sortOption) {
      case _SortOption.newest:
        return 'Newest first';
      case _SortOption.oldest:
        return 'Oldest first';
      case _SortOption.highestScore:
        return 'Highest score';
      case _SortOption.lowestScore:
        return 'Lowest score';
    }
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(48.0),
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return GlassCard(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Icon(Icons.error_outline,
                size: 64, color: AppColors.error),
            const SizedBox(height: 20),
            Text(
              'Error Loading Sessions',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: AppColors.textDark, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(_errorMessage!,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textMedium),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            AnimatedButton(
              text: 'Retry',
              icon: Icons.refresh,
              onPressed: _loadSessions,
            ),
          ],
        ),
      );
    }

    final displayed = _displayedSessions;

    if (displayed.isEmpty) {
      return GlassCard(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Icon(Icons.history, size: 64, color: AppColors.textLight),
            const SizedBox(height: 20),
            Text(
              _sessions.isEmpty ? 'No Sessions Yet' : 'No Matches',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: AppColors.textDark, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              _sessions.isEmpty
                  ? 'Start practicing to see your session history!'
                  : 'Try changing the filter options.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textMedium),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: displayed
          .map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildSessionCard(s),
              ))
          .toList(),
    );
  }

  Widget _buildSessionCard(Map<String, dynamic> session) {
    final createdAt = DateTime.fromMillisecondsSinceEpoch(
      session['created_at'] as int? ?? 0,
    );
    final overallScore = (session['composite_score'] as num? ?? 0);
    final dateStr  = _formatDate(createdAt);
    final timeAgo  = _formatTimeAgo(createdAt);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SessionDetailScreen(session: session),
          ),
        );
      },
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${overallScore.toInt()}',
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 26,
                          fontWeight: FontWeight.w900)),
                  Text(session['cefr_level'] as String? ?? 'A1',
                      style: const TextStyle(
                          color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dateStr,
                      style: const TextStyle(
                          color: AppColors.textDark,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(timeAgo,
                      style: const TextStyle(
                          color: AppColors.textMedium, fontSize: 13, fontWeight: FontWeight.w600)),
                  if (session['type'] == 'baseline') ...[
                    const SizedBox(height: 8),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('BASELINE',
                          style: TextStyle(
                              color: AppColors.secondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w900)),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textLight, size: 20),
          ],
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

    if (d.inMinutes < 1) return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) {
      return '${d.inHours} hour${d.inHours > 1 ? 's' : ''} ago';
    }
    if (d.inDays < 7) {
      return '${d.inDays} day${d.inDays > 1 ? 's' : ''} ago';
    }
    return DateFormat('MMM d').format(date);
  }
}

