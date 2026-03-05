import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../data/local/database_helper.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/glass_card.dart';
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
      builder: (_) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
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
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    const Text('FILTER BY',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            letterSpacing: 1.2)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        _chip('All', _filterOption == _FilterOption.all,
                            () => setSheet(() => _filterOption = _FilterOption.all)),
                        _chip('Practice', _filterOption == _FilterOption.practice,
                            () => setSheet(() => _filterOption = _FilterOption.practice)),
                        _chip('Baseline', _filterOption == _FilterOption.baseline,
                            () => setSheet(() => _filterOption = _FilterOption.baseline)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text('SORT BY',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            letterSpacing: 1.2)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
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
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.25),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () {
                          setState(() {}); // Apply to main screen
                          Navigator.pop(ctx);
                        },
                        child: const Text('Apply',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white.withOpacity(0.35) : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? Colors.white : Colors.white.withOpacity(0.2)),
        ),
        child: Text(label,
            style: TextStyle(
                color: Colors.white,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
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
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.tune, color: Colors.white),
                      tooltip: 'Filter & Sort',
                      onPressed: _showFilterSheet,
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      tooltip: 'Refresh',
                      onPressed: _loadSessions,
                    ),
                  ],
                  flexibleSpace: ClipRRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            Colors.white.withOpacity(0.2),
                            Colors.white.withOpacity(0.1),
                          ]),
                        ),
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
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_displayedSessions.length} of ${_sessions.length} sessions',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                          color: Colors.white.withOpacity(0.9)),
                                ),
                              ],
                            ),
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
                          horizontal: 24, vertical: 8),
                      child: Row(
                        children: [
                          Icon(Icons.filter_list,
                              color: Colors.white.withOpacity(0.7), size: 16),
                          const SizedBox(width: 6),
                          Text(
                            _filterLabel(),
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 13),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.sort,
                              color: Colors.white.withOpacity(0.7), size: 16),
                          const SizedBox(width: 6),
                          Text(
                            _sortLabel(),
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 13),
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
        ],
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
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return GlassCard(
        blur: 15,
        opacity: 0.25,
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.error_outline,
                size: 64, color: Colors.white.withOpacity(0.8)),
            const SizedBox(height: 20),
            Text(
              'Error Loading Sessions',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(_errorMessage!,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.white.withOpacity(0.9)),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            GlassButton(
              onPressed: _loadSessions,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final displayed = _displayedSessions;

    if (displayed.isEmpty) {
      return GlassCard(
        blur: 15,
        opacity: 0.25,
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.history, size: 64, color: Colors.white.withOpacity(0.8)),
            const SizedBox(height: 20),
            Text(
              _sessions.isEmpty ? 'No Sessions Yet' : 'No Matches',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
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
                  ?.copyWith(color: Colors.white.withOpacity(0.9)),
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
                padding: const EdgeInsets.only(bottom: 12),
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
    final speakingBand = (session['estimated_band'] as num? ?? 0);
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
        blur: 15,
        opacity: 0.2,
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${overallScore.toInt()}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold)),
                  Text('Level ${speakingBand.toStringAsFixed(1)}',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7), fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dateStr,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(timeAgo,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7), fontSize: 14)),
                  if (session['type'] == 'baseline') ...[
                    const SizedBox(height: 4),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('BASELINE',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.6)),
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
