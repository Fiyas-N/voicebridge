import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import '../../services/notification_service.dart';
import '../onboarding/welcome_screen.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../services/tts_service.dart';
import '../../widgets/common/ai_voice_gender_toggle.dart';
import '../../widgets/common/dot_grid_background.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _hapticEnabled = true;
  bool _offlineOnly = false; // Default: Cloud Hybrid
  bool _voiceIsMale = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    var notifications = prefs.getBool('notifications_enabled') ?? true;
    final sound = prefs.getBool('audio_feedback_enabled') ?? true;
    final haptic = prefs.getBool('haptic_output_enabled') ?? true;
    final offline = prefs.getBool('use_offline_only') ?? false;
    final voiceMale = prefs.getBool('tts_voice_is_male') ?? false;

    if (mounted) {
      setState(() {
        _notificationsEnabled = notifications;
        _soundEnabled = sound;
        _hapticEnabled = haptic;
        _offlineOnly = offline;
        _voiceIsMale = voiceMale;
      });
    }

    if (mounted && notifications) {
      if (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) {
        final granted = await NotificationService.instance.isNotificationPermissionGranted();
        if (!granted) {
          await prefs.setBool('notifications_enabled', false);
          if (mounted) {
            setState(() => _notificationsEnabled = false);
          }
        }
      }
    }
  }

  Future<void> _onNotificationsToggle(bool v) async {
    if (!v) {
      setState(() => _notificationsEnabled = false);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', false);
      await NotificationService.instance.cancelDailyReminder();
      return;
    }
    final granted = await NotificationService.instance.requestNotificationPermission();
    if (!granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Notification permission denied. Enable notifications in system settings for daily cycle alerts.',
            ),
          ),
        );
      }
      setState(() => _notificationsEnabled = false);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', false);
      return;
    }
    setState(() => _notificationsEnabled = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', true);
    await NotificationService.instance.scheduleDailyReminder();
  }

  Future<void> _toggleSetting(String key, bool val, void Function(bool) updater) async {
    setState(() => updater(val));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, val);
  }

  Future<void> _setOfflineMode(bool val) async {
    setState(() => _offlineOnly = val);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_offline_only', val);
  }

  Future<void> _setVoiceGender(bool val) async {
    setState(() => _voiceIsMale = val);
    await TtsService().setVoice(val);
  }

  void _showEditProfileDialog(BuildContext context, AuthProvider auth) {
    final controller = TextEditingController(text: auth.currentUser?.displayName ?? '');
    showDialog(
      context: context,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: AppColors.borderLight)),
          title: const Text('Edit display name', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 14)),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Name',
              labelStyle: const TextStyle(color: AppColors.textTertiary, fontFamily: 'monospace', fontSize: 12),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.borderLight)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL', style: TextStyle(color: Colors.white38, fontFamily: 'monospace'))),
            TextButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(ctx);
                try { await auth.updateDisplayName(name); } catch (_) {}
              },
              child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context, AuthProvider auth) {
    final cCtrl = TextEditingController();
    final nCtrl = TextEditingController();
    final cfCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: AppColors.borderLight)),
          title: const Text('Change password', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 14)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogField(cCtrl, 'Current password', obscure: true),
              const SizedBox(height: 16),
              _dialogField(nCtrl, 'New password', obscure: true),
              const SizedBox(height: 16),
              _dialogField(cfCtrl, 'CONFIRM_NEW', obscure: true),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL', style: TextStyle(color: Colors.white38, fontFamily: 'monospace'))),
            TextButton(
              onPressed: () async {
                if (nCtrl.text != cfCtrl.text) return;
                Navigator.pop(ctx);
                try { await auth.changePassword(currentPassword: cCtrl.text, newPassword: nCtrl.text); } catch (_) {}
              },
              child: const Text('Update password', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context, AuthProvider auth) {
    final passCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: AppColors.accentRed)),
          title: const Text('Delete account', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.accentRed)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('This permanently deletes your account and saved practice data.', style: TextStyle(color: Colors.white60, fontSize: 13)),
              const SizedBox(height: 20),
              _dialogField(passCtrl, 'Your password', obscure: true),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white60, fontFamily: 'monospace'))),
            TextButton(
              onPressed: () async {
                if (passCtrl.text.isEmpty) return;
                Navigator.pop(ctx);
                try {
                  await auth.deleteAccount(passCtrl.text);
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const WelcomeScreen()), (r) => false);
                  }
                } catch (_) {}
              },
              child: const Text('Delete forever', style: TextStyle(color: AppColors.accentRed, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: AppColors.borderLight)),
          title: const Text('Sign out', style: TextStyle(fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.bold)),
          content: const Text('You can sign back in any time.', style: TextStyle(color: Colors.white60)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('STAY', style: TextStyle(color: Colors.white60, fontFamily: 'monospace'))),
            TextButton(
              onPressed: () {
                authProvider.signOut();
                Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const WelcomeScreen()), (r) => false);
              },
              child: const Text('Sign out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogField(TextEditingController ctrl, String tag, {bool obscure = false}) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: tag,
        labelStyle: const TextStyle(color: AppColors.textTertiary, fontFamily: 'monospace', fontSize: 12),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.borderLight)),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final u = auth.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: DotGridBackground(
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                backgroundColor: Colors.transparent, elevation: 0, pinned: true,
                leading: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
                title: Text(
                  'Settings',
                  style: GoogleFonts.spaceMono(
                    fontSize: 11,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: Text(
                    'Voice, notifications, privacy, and how much runs on your device.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      height: 1.5,
                      color: VbColor.onSurfaceVariant,
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
                    if (u != null) ...[
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.borderLight),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 60, height: 60,
                              decoration: BoxDecoration(color: Colors.white10, shape: BoxShape.circle, border: Border.all(color: AppColors.borderLight)),
                              alignment: Alignment.center,
                              child: Text(u.displayName.isNotEmpty ? u.displayName[0].toUpperCase() : '?', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(u.displayName.isNotEmpty ? u.displayName : 'Guest', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
                                  const SizedBox(height: 4),
                                  Text(u.email, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.white54, size: 20),
                              onPressed: () => _showEditProfileDialog(context, auth),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],

                    const _Label(txt: 'NOTIFICATIONS & SOUNDS'),
                    const SizedBox(height: 12),
                    _TileGroup(children: [
                      _SwitchTile(
                        lbl: 'Push notifications',
                        sub: 'Daily practice reminder',
                        val: _notificationsEnabled,
                        fn: _onNotificationsToggle,
                      ),
                      _SwitchTile(
                        lbl: 'Sound effects',
                        sub: 'Light tap sounds for buttons',
                        val: _soundEnabled,
                        fn: (v) => _toggleSetting('audio_feedback_enabled', v, (b) => _soundEnabled = b),
                      ),
                      _SwitchTile(
                        lbl: 'Vibration',
                        sub: 'Haptic feedback on taps',
                        val: _hapticEnabled,
                        fn: (v) => _toggleSetting('haptic_output_enabled', v, (b) => _hapticEnabled = b),
                      ),
                    ]),
                    const SizedBox(height: 32),

                    const _Label(txt: 'AI & OFFLINE'),
                    const SizedBox(height: 12),
                    _TileGroup(children: [
                      _SwitchTile(
                        lbl: 'Offline only',
                        sub: 'Use your device only, no cloud helpers',
                        val: _offlineOnly,
                        fn: _setOfflineMode,
                      ),
                    ]),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Coach voice',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                  letterSpacing: 2,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Applies to read-aloud feedback, conversation mode, and practice audio.',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 11, height: 1.35),
                              ),
                              const SizedBox(height: 14),
                              Center(
                                child: AiVoiceGenderToggle(
                                  isMale: _voiceIsMale,
                                  onChanged: (male) => _setVoiceGender(male),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    const _Label(txt: 'ACCOUNT'),
                    const SizedBox(height: 12),
                    _TileGroup(children: [
                      _ActionTile(lbl: 'Forgot password', sub: 'Send a reset link to your email', fn: () async {
                        try { await auth.sendPasswordReset(); } catch (_) {}
                      }),
                      _ActionTile(lbl: 'Change password', sub: 'Update the password for this account', fn: () => _showChangePasswordDialog(context, auth)),
                    ]),
                    const SizedBox(height: 32),

                    const _Label(txt: 'SIGN OUT & DELETE'),
                    const SizedBox(height: 12),
                    _TileGroup(children: [
                      _ActionTile(lbl: 'Sign out', sub: 'Leave this account on this device', fn: () => _showLogoutDialog(context, auth)),
                      _ActionTile(lbl: 'Delete account', sub: 'Remove your account and saved data', isDanger: true, fn: () => _showDeleteAccountDialog(context, auth)),
                    ]),

                    const SizedBox(height: 40),
                    Center(
                      child: Column(
                        children: [
                          Text('VoiceBridge 1.2.0', style: TextStyle(color: Colors.white10, fontFamily: 'monospace', fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                        ],
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
    ),
    );
  }
}

class _Label extends StatelessWidget {
  final String txt;
  const _Label({required this.txt});
  @override
  Widget build(BuildContext context) => Text(txt, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textTertiary, letterSpacing: 2));
}

class _TileGroup extends StatelessWidget {
  final List<Widget> children;
  const _TileGroup({required this.children});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.borderLight)),
      child: Column(children: children),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final String lbl;
  final String sub;
  final bool val;
  final ValueChanged<bool> fn;
  const _SwitchTile({required this.lbl, required this.sub, required this.val, required this.fn});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(lbl, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white70)),
      subtitle: Text(sub, style: const TextStyle(color: Colors.white38, fontSize: 11)),
      trailing: Switch(value: val, onChanged: fn, activeColor: Colors.white, activeTrackColor: Colors.white24),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final String lbl;
  final String sub;
  final VoidCallback fn;
  final bool isDanger;
  const _ActionTile({required this.lbl, required this.sub, required this.fn, this.isDanger = false});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: fn,
      title: Text(lbl, style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 11, color: isDanger ? AppColors.accentRed : Colors.white70)),
      subtitle: Text(sub, style: const TextStyle(color: Colors.white38, fontSize: 11)),
      trailing: Icon(Icons.chevron_right, size: 16, color: isDanger ? AppColors.accentRed.withValues(alpha: 0.5) : Colors.white24),
    );
  }
}

