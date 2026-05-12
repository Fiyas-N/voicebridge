import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/ai_pipeline.dart';
import '../settings/settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _cefrLabel(String cefr) {
    switch (cefr) {
      case 'C2': return 'MASTERY';
      case 'C1': return 'ADVANCED';
      case 'B2': return 'HIGH_INTER';
      case 'B1': return 'INTERMEDIATE';
      case 'A2': return 'ELEMENTARY';
      default: return 'BEGINNER';
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.currentUser;
    final cefr = user?.baselineScores != null ? AIProcessingPipeline.mapToCEFR(user!.baselineScores!.composite) : 'A1';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              backgroundColor: Colors.transparent, elevation: 0, pinned: true,
              title: const Text('USER_PROFILE', style: TextStyle(fontFamily: 'monospace', fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings_outlined, color: Colors.white),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Identity Header
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 80, height: 80,
                            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white24, width: 2)),
                            alignment: Alignment.center,
                            child: Text(user?.displayName.isNotEmpty == true ? user!.displayName[0].toUpperCase() : '?', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(height: 16),
                          Text(user?.displayName.isNotEmpty == true ? user!.displayName : 'ANONYMOUS_U', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1)),
                          const SizedBox(height: 4),
                          Text(user?.email ?? 'NOT_LINKED', style: const TextStyle(color: AppColors.textTertiary, fontSize: 12, fontFamily: 'monospace')),
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(border: Border.all(color: Colors.white), borderRadius: BorderRadius.circular(8)),
                            child: Text('RANK // $cefr ${_cefrLabel(cefr)}', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 11)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Activity Grid
                    Row(
                      children: [
                        Expanded(child: _statBox('STREAK', '${user?.currentStreak ?? 0}', 'DAYS')),
                        const SizedBox(width: 12),
                        Expanded(child: _statBox('TESTS', '${user?.totalSessions ?? 0}', 'RUNS')),
                        const SizedBox(width: 12),
                        Expanded(child: _statBox('RECORD', '${user?.longestStreak ?? 0}', 'MAX')),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Baseline Data
                    if (user?.baselineScores != null) ...[
                      const Text('BASELINE_METRICS', style: TextStyle(fontFamily: 'monospace', fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2, color: AppColors.textTertiary)),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.borderLight)),
                        child: Column(
                          children: [
                            _miniBar('FLUENCY', user!.baselineScores!.fluency),
                            const SizedBox(height: 16),
                            _miniBar('GRAMMAR', user.baselineScores!.grammar),
                            const SizedBox(height: 16),
                            _miniBar('PRONUNCIATION', user.baselineScores!.pronunciation),
                            const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(color: AppColors.borderLight)),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('COMPOSITE_INDEX', style: TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textTertiary)),
                                Text('${user.baselineScores!.composite.toStringAsFixed(1)}%', style: const TextStyle(fontFamily: 'monospace', fontSize: 14, fontWeight: FontWeight.bold)),
                              ],
                            )
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],

                    // Improvement Flags
                    if (user?.weakAreas.isNotEmpty == true) ...[
                      const Text('FLAGGED_VULNERABILITIES', style: TextStyle(fontFamily: 'monospace', fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2, color: AppColors.accentRed)),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.accentRed.withValues(alpha: 0.2))),
                        child: Wrap(
                          spacing: 8, runSpacing: 8,
                          children: user!.weakAreas.map((area) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(border: Border.all(color: AppColors.accentRed.withValues(alpha: 0.4)), borderRadius: BorderRadius.circular(6)),
                            child: Text(area.toUpperCase(), style: const TextStyle(fontSize: 10, color: AppColors.accentRed, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                          )).toList(),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],

                    const Text('OPERATIONS', style: TextStyle(fontFamily: 'monospace', fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2, color: AppColors.textTertiary)),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.borderLight)),
                      child: ListTile(
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
                        leading: const Icon(Icons.settings_applications, color: Colors.white70),
                        title: const Text('LAUNCH_SETTINGS', style: TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold)),
                        trailing: const Icon(Icons.chevron_right, size: 16, color: Colors.white24),
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statBox(String lbl, String val, String unit) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.borderLight)),
      child: Column(
        children: [
          Text(lbl, style: const TextStyle(fontFamily: 'monospace', fontSize: 9, color: AppColors.textTertiary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(val, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
          const SizedBox(height: 2),
          Text(unit, style: const TextStyle(fontSize: 8, color: AppColors.textTertiary, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _miniBar(String label, double val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: AppColors.textTertiary, fontWeight: FontWeight.bold)),
            Text('${val.toStringAsFixed(0)}%', style: const TextStyle(fontFamily: 'monospace', fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: val / 100, minHeight: 2,
            backgroundColor: Colors.white.withValues(alpha: 0.05),
            valueColor: const AlwaysStoppedAnimation(Colors.white70),
          ),
        )
      ],
    );
  }
}

