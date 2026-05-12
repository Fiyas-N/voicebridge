import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import '../onboarding/welcome_screen.dart';
import '../../core/theme/app_theme.dart';
import '../../services/tts_service.dart';

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
    if (mounted) {
      setState(() {
        _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
        _soundEnabled = prefs.getBool('audio_feedback_enabled') ?? true;
        _hapticEnabled = prefs.getBool('haptic_output_enabled') ?? true;
        _offlineOnly = prefs.getBool('use_offline_only') ?? false;
        _voiceIsMale = prefs.getBool('tts_voice_is_male') ?? false;
      });
    }
  }

  Future<void> _toggleSetting(String key, bool val, Function(bool) updater) async {
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
    TtsService().setVoice(val); // Updates both runtime and storage
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
          title: const Text('RENAME_IDENTIFIER', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 14)),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'USER_TAG',
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
              child: const Text('COMMIT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
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
          title: const Text('ROTATE_KEYS', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 14)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogField(cCtrl, 'CURRENT_TOKEN', obscure: true),
              const SizedBox(height: 16),
              _dialogField(nCtrl, 'NEW_TOKEN', obscure: true),
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
              child: const Text('ROTATE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
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
          title: const Text('PURGE_DATA', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.accentRed)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Confirm destruction sequence. All recorded logs wiped permanently.', style: TextStyle(color: Colors.white60, fontSize: 13)),
              const SizedBox(height: 20),
              _dialogField(passCtrl, 'AUTH_TOKEN', obscure: true),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ABORT', style: TextStyle(color: Colors.white60, fontFamily: 'monospace'))),
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
              child: const Text('EXECUTE_WIPE', style: TextStyle(color: AppColors.accentRed, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
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
          title: const Text('TERMINATE_SESSION', style: TextStyle(fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.bold)),
          content: const Text('Confirm session termination?', style: TextStyle(color: Colors.white60)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('STAY', style: TextStyle(color: Colors.white60, fontFamily: 'monospace'))),
            TextButton(
              onPressed: () {
                authProvider.signOut();
                Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const WelcomeScreen()), (r) => false);
              },
              child: const Text('EXIT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
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
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              backgroundColor: Colors.transparent, elevation: 0, pinned: true,
              leading: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
              title: const Text('SYSTEM_PREFERENCES', style: TextStyle(fontFamily: 'monospace', fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
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
                                  Text(u.displayName.isNotEmpty ? u.displayName : 'ANONYMOUS', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
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

                    const _Label(txt: 'TELEMETRY'),
                    const SizedBox(height: 12),
                    _TileGroup(children: [
                      _SwitchTile(
                        lbl: 'PUSH_NOTIFICATIONS',
                        sub: 'Daily cycle alerts',
                        val: _notificationsEnabled,
                        fn: (v) => _toggleSetting('notifications_enabled', v, (b) => _notificationsEnabled = b),
                      ),
                      _SwitchTile(
                        lbl: 'AUDIO_FEEDBACK',
                        sub: 'Interface auditory signal',
                        val: _soundEnabled,
                        fn: (v) => _toggleSetting('audio_feedback_enabled', v, (b) => _soundEnabled = b),
                      ),
                      _SwitchTile(
                        lbl: 'HAPTIC_OUTPUT',
                        sub: 'Physical response triggers',
                        val: _hapticEnabled,
                        fn: (v) => _toggleSetting('haptic_output_enabled', v, (b) => _hapticEnabled = b),
                      ),
                    ]),
                    const SizedBox(height: 32),

                    const _Label(txt: 'AI_ENGINE_PREFERENCES'),
                    const SizedBox(height: 12),
                    _TileGroup(children: [
                      _SwitchTile(
                        lbl: 'FULL_OFFLINE_MODE',
                        sub: 'Bypass cloud accelerators entirely',
                        val: _offlineOnly,
                        fn: _setOfflineMode,
                      ),
                      _SwitchTile(
                        lbl: 'SYNTHESIS_GENDER_MALE',
                        sub: 'Toggle default speaker persona',
                        val: _voiceIsMale,
                        fn: _setVoiceGender,
                      ),
                    ]),
                    const SizedBox(height: 32),

                    const _Label(txt: 'AUTHENTICATION'),
                    const SizedBox(height: 12),
                    _TileGroup(children: [
                      _ActionTile(lbl: 'RESET_CREDS', sub: 'Trigger email gateway relay', fn: () async {
                        try { await auth.sendPasswordReset(); } catch (_) {}
                      }),
                      _ActionTile(lbl: 'MANUAL_TOKEN_ROTATION', sub: 'Edit current passphrase', fn: () => _showChangePasswordDialog(context, auth)),
                    ]),
                    const SizedBox(height: 32),

                    const _Label(txt: 'TERMINATION'),
                    const SizedBox(height: 12),
                    _TileGroup(children: [
                      _ActionTile(lbl: 'LOG_OUT', sub: 'Disconnect pipeline stream', fn: () => _showLogoutDialog(context, auth)),
                      _ActionTile(lbl: 'DESTROY_PROFILE', sub: 'Irreversible data deletion', isDanger: true, fn: () => _showDeleteAccountDialog(context, auth)),
                    ]),

                    const SizedBox(height: 40),
                    Center(
                      child: Column(
                        children: [
                          Text('CORE_MODULE_VER // 1.2.0', style: TextStyle(color: Colors.white10, fontFamily: 'monospace', fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                          const SizedBox(height: 4),
                          Text('ANTIGRAVITY_REBOOT_DESIGN', style: TextStyle(color: Colors.white.withValues(alpha: 0.05), fontFamily: 'monospace', fontSize: 9)),
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

