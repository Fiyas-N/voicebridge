import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/ai_pipeline.dart';
import '../../widgets/common/glass_card.dart';
import '../settings/settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  /// CEFR badge color (matches AIProcessingPipeline.cefrColor)
  Color _cefrColor(String cefr) {
    final map = SessionAnalysis.cefrColor(cefr);
    return Color.fromARGB(
        255, map['r']!, map['g']!, map['b']!);
  }

  String _cefrLabel(String cefr) {
    switch (cefr) {
      case 'C2':
        return 'Mastery';
      case 'C1':
        return 'Advanced';
      case 'B2':
        return 'Upper Intermediate';
      case 'B1':
        return 'Intermediate';
      case 'A2':
        return 'Elementary';
      default:
        return 'Beginner';
    }
  }

  String _avatarInitial(String name) =>
      name.isNotEmpty ? name[0].toUpperCase() : 'U';

  // ── Edit Name Dialog ─────────────────────────────────────────────────────────
  void _showEditNameDialog(BuildContext context, AuthProvider auth) {
    final ctrl =
        TextEditingController(text: auth.currentUser?.displayName ?? '');
    showDialog(
      context: context,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: const Color(0xFF2C2C3E),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Edit Name',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Display Name',
              labelStyle:
                  TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              enabledBorder: OutlineInputBorder(
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: AppColors.primary),
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style:
                      TextStyle(color: Colors.white.withValues(alpha: 0.6))),
            ),
            TextButton(
              onPressed: () async {
                final name = ctrl.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(ctx);
                try {
                  await auth.updateDisplayName(name);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Name updated!'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: AppColors.error),
                    );
                  }
                }
              },
              child: const Text('Save',
                  style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.currentUser;

    // Derive CEFR from baseline scores if available
    final cefrLevel = user?.baselineScores != null
        ? AIProcessingPipeline.mapToCEFR(
            user!.baselineScores!.composite)
        : 'A1';

    return Scaffold(
      body: Stack(
        children: [
          // ── Gradient background ──────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1A1A2E),
                  Color(0xFF16213E),
                  Color(0xFF0F3460),
                ],
              ),
            ),
          ),

          // ── Decorative circles ───────────────────────────────────────────
          Positioned(
            top: -80,
            right: -60,
            child: _glowCircle(200, AppColors.primary, 0.12),
          ),
          Positioned(
            bottom: 100,
            left: -80,
            child: _glowCircle(180, AppColors.accentPurple, 0.10),
          ),

          // ── Content ──────────────────────────────────────────────────────
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // App Bar
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'My Profile',
                            style: Theme.of(context)
                                .textTheme
                                .displayMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          // Settings shortcut
                          GestureDetector(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const SettingsScreen()),
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.settings_outlined,
                                  color: Colors.white, size: 22),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 28)),

                  // ── Avatar + Name Card ──────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: GlassCard(
                        blur: 20,
                        opacity: 0.15,
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            // Avatar
                            Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                Container(
                                  width: 90,
                                  height: 90,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [
                                        AppColors.primary,
                                        AppColors.accentPurple,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.4),
                                        blurRadius: 16,
                                        spreadRadius: 2,
                                      )
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      _avatarInitial(
                                          user?.displayName ?? ''),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 36,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () =>
                                      _showEditNameDialog(context, auth),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: const Color(0xFF1A1A2E),
                                          width: 2),
                                    ),
                                    child: const Icon(Icons.edit,
                                        color: Colors.white, size: 14),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Name
                            Text(
                              user?.displayName.isNotEmpty == true
                                  ? user!.displayName
                                  : 'VoiceBridge User',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user?.email ?? '',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 20),

                            // CEFR Badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 10),
                              decoration: BoxDecoration(
                                color:
                                    _cefrColor(cefrLevel).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color: _cefrColor(cefrLevel)
                                      .withValues(alpha: 0.6),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.school_rounded,
                                      color: _cefrColor(cefrLevel),
                                      size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    '$cefrLevel — ${_cefrLabel(cefrLevel)}',
                                    style: TextStyle(
                                      color: _cefrColor(cefrLevel),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Member since
                            const SizedBox(height: 12),
                            Text(
                              'Member since ${_formatDate(user?.createdAt)}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 24)),

                  // ── Stats Row ──────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          Expanded(
                            child: _statCard(
                              context,
                              icon: Icons.local_fire_department,
                              iconColor: const Color(0xFFFF6B35),
                              value: '${user?.currentStreak ?? 0}',
                              label: 'Day Streak',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _statCard(
                              context,
                              icon: Icons.mic_rounded,
                              iconColor: AppColors.primary,
                              value: '${user?.totalSessions ?? 0}',
                              label: 'Sessions',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _statCard(
                              context,
                              icon: Icons.emoji_events_rounded,
                              iconColor: const Color(0xFFFFD700),
                              value: '${user?.longestStreak ?? 0}',
                              label: 'Best Streak',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 24)),

                  // ── Baseline Scores ────────────────────────────────────
                  if (user?.baselineScores != null) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionHeader('Baseline Assessment'),
                            const SizedBox(height: 12),
                            GlassCard(
                              blur: 15,
                              opacity: 0.12,
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  _scoreBar(context, 'Fluency',
                                      user!.baselineScores!.fluency,
                                      const Color(0xFF4ECDC4)),
                                  const SizedBox(height: 14),
                                  _scoreBar(context, 'Grammar',
                                      user.baselineScores!.grammar,
                                      AppColors.primary),
                                  const SizedBox(height: 14),
                                  _scoreBar(
                                      context,
                                      'Pronunciation',
                                      user.baselineScores!.pronunciation,
                                      AppColors.accentPurple),
                                  const Divider(
                                      color: Colors.white12, height: 28),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Overall',
                                          style: TextStyle(
                                              color: Colors.white
                                                  .withValues(alpha: 0.8),
                                              fontSize: 15,
                                              fontWeight:
                                                  FontWeight.w600)),
                                      Text(
                                        '${user.baselineScores!.composite.toStringAsFixed(1)}%',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ],

                  // ── Weak Areas ─────────────────────────────────────────
                  if (user?.weakAreas.isNotEmpty == true) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionHeader('Areas to Improve'),
                            const SizedBox(height: 12),
                            GlassCard(
                              blur: 15,
                              opacity: 0.12,
                              padding: const EdgeInsets.all(16),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: user!.weakAreas
                                    .map((area) => _weakAreaChip(area))
                                    .toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ],

                  // ── Quick Actions ──────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionHeader('Account'),
                          const SizedBox(height: 12),
                          GlassCard(
                            blur: 15,
                            opacity: 0.12,
                            padding: EdgeInsets.zero,
                            child: Column(
                              children: [
                                _actionTile(
                                  context,
                                  icon: Icons.person_outline,
                                  title: 'Edit Display Name',
                                  subtitle: user?.displayName ?? '',
                                  onTap: () =>
                                      _showEditNameDialog(context, auth),
                                ),
                                _divider(),
                                _actionTile(
                                  context,
                                  icon: Icons.settings_outlined,
                                  title: 'Settings',
                                  subtitle:
                                      'Password, notifications, danger zone',
                                  onTap: () =>
                                      Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const SettingsScreen()),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Private widget helpers ───────────────────────────────────────────────

  Widget _glowCircle(double size, Color color, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: opacity),
      ),
    );
  }

  Widget _statCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return GlassCard(
      blur: 12,
      opacity: 0.12,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 26),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreBar(BuildContext context, String label, double score,
      Color color) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
            ),
            Text(
              '${score.toStringAsFixed(0)}%',
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: score / 100,
            minHeight: 6,
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _weakAreaChip(String area) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: AppColors.error.withValues(alpha: 0.4), width: 1),
      ),
      child: Text(
        area,
        style: const TextStyle(
            color: Colors.white70, fontSize: 13),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _actionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? titleColor,
    Color? iconColor,
  }) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Icon(icon, color: iconColor ?? Colors.white70, size: 22),
      title: Text(
        title,
        style: TextStyle(
          color: titleColor ?? Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      subtitle: subtitle.isNotEmpty
          ? Text(
              subtitle,
              style:
                  TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: Icon(Icons.chevron_right,
          color: Colors.white.withValues(alpha: 0.3), size: 20),
      onTap: onTap,
    );
  }

  Widget _divider() =>
      Divider(height: 1, color: Colors.white.withValues(alpha: 0.08));

  String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month]} ${dt.year}';
  }
}

