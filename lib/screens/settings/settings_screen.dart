import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/glass_card.dart';
import '../onboarding/welcome_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _hapticEnabled = true;

  // ─── Edit Profile Dialog ───────────────────────────────────────────────────
  void _showEditProfileDialog(BuildContext context, AuthProvider auth) {
    final controller = TextEditingController(
      text: auth.currentUser?.displayName ?? '',
    );
    showDialog(
      context: context,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: const Color(0xFF424242),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Edit Name',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Display Name',
              labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.white),
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.white.withOpacity(0.1),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: TextStyle(color: Colors.white.withOpacity(0.7))),
            ),
            TextButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(ctx);
                try {
                  await auth.updateDisplayName(name);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Name updated successfully!'),
                          backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Save',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Change Password Dialog ────────────────────────────────────────────────
  void _showChangePasswordDialog(BuildContext context, AuthProvider auth) {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AlertDialog(
            backgroundColor: const Color(0xFF424242),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: const Text('Change Password',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogTextField(currentCtrl, 'Current Password',
                    obscure: true),
                const SizedBox(height: 12),
                _dialogTextField(newCtrl, 'New Password', obscure: true),
                const SizedBox(height: 12),
                _dialogTextField(confirmCtrl, 'Confirm New Password',
                    obscure: true),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel',
                    style:
                        TextStyle(color: Colors.white.withOpacity(0.7))),
              ),
              TextButton(
                onPressed: () async {
                  if (newCtrl.text != confirmCtrl.text) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Passwords do not match'),
                          backgroundColor: Colors.orange),
                    );
                    return;
                  }
                  if (newCtrl.text.length < 6) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Password must be at least 6 characters'),
                          backgroundColor: Colors.orange),
                    );
                    return;
                  }
                  Navigator.pop(ctx);
                  try {
                    await auth.changePassword(
                      currentPassword: currentCtrl.text,
                      newPassword: newCtrl.text,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Password changed successfully!'),
                            backgroundColor: Colors.green),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: Colors.red),
                      );
                    }
                  }
                },
                child: const Text('Change',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Delete Account Dialog ─────────────────────────────────────────────────
  void _showDeleteAccountDialog(BuildContext context, AuthProvider auth) {
    final passwordCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: const Color(0xFF424242),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Delete Account',
              style: TextStyle(
                  color: Colors.redAccent, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'This will permanently delete your account and all session data. This cannot be undone.',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              _dialogTextField(passwordCtrl, 'Enter Your Password',
                  obscure: true),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: TextStyle(color: Colors.white.withOpacity(0.7))),
            ),
            TextButton(
              onPressed: () async {
                if (passwordCtrl.text.isEmpty) return;
                Navigator.pop(ctx);
                try {
                  await auth.deleteAccount(passwordCtrl.text);
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                          builder: (_) => const WelcomeScreen()),
                      (route) => false,
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Delete Account',
                  style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Logout Dialog ────────────────────────────────────────────────────────
  void _showLogoutDialog(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: const Color(0xFF424242),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Log Out',
              style: TextStyle(color: Colors.white)),
          content: const Text('Are you sure you want to log out?',
              style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel',
                  style:
                      TextStyle(color: Colors.white.withOpacity(0.7))),
            ),
            TextButton(
              onPressed: () {
                authProvider.signOut();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                  (route) => false,
                );
              },
              child: const Text('Log Out',
                  style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Helper Widgets ───────────────────────────────────────────────────────
  TextField _dialogTextField(TextEditingController ctrl, String label,
      {bool obscure = false}) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.white),
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
      ),
    );
  }

  Widget _buildGlassSwitchTile(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Icon(icon, color: Colors.white),
      title: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .bodyLarge
            ?.copyWith(fontWeight: FontWeight.w600, color: Colors.white),
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: Colors.white.withOpacity(0.8)),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: Colors.white,
        activeTrackColor: Colors.white.withOpacity(0.5),
      ),
    );
  }

  Widget _buildGlassActionTile(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap, {
    Color? iconColor,
    Color? titleColor,
  }) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Icon(icon, color: iconColor ?? Colors.white),
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: titleColor ?? Colors.white,
            ),
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: Colors.white.withOpacity(0.8)),
      ),
      trailing:
          Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.5)),
      onTap: onTap,
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.currentUser;

    return Scaffold(
      body: Stack(
        children: [
          // Background
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
                                  'Profile & Settings',
                                  style: Theme.of(context)
                                      .textTheme
                                      .displayMedium
                                      ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Manage your account and preferences',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                          color:
                                              Colors.white.withOpacity(0.9)),
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
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Profile Card ────────────────────────────────────
                        if (user != null) ...[
                          GlassCard(
                            blur: 15,
                            opacity: 0.25,
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                Container(
                                  width: 70,
                                  height: 70,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.3),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      user.displayName.isNotEmpty
                                          ? user.displayName[0].toUpperCase()
                                          : 'U',
                                      style: Theme.of(context)
                                          .textTheme
                                          .displayMedium
                                          ?.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user.displayName.isNotEmpty
                                            ? user.displayName
                                            : 'User',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        user.email,
                                        style: TextStyle(
                                            color: Colors.white
                                                .withOpacity(0.8),
                                            fontSize: 14),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          _statChip(
                                              '🔥 ${user.currentStreak}d'),
                                          const SizedBox(width: 8),
                                          _statChip(
                                              '📝 ${user.totalSessions}'),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit,
                                      color: Colors.white),
                                  onPressed: () =>
                                      _showEditProfileDialog(context, auth),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),
                        ],

                        // ── Practice Preferences ────────────────────────────
                        _sectionLabel(context, 'Practice Preferences'),
                        const SizedBox(height: 12),
                        GlassCard(
                          blur: 15,
                          opacity: 0.2,
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              _buildGlassSwitchTile(
                                context,
                                Icons.notifications_outlined,
                                'Daily Reminders',
                                'Get notified to practice each day',
                                _notificationsEnabled,
                                (v) => setState(
                                    () => _notificationsEnabled = v),
                              ),
                              Divider(
                                  height: 1,
                                  color: Colors.white.withOpacity(0.1)),
                              _buildGlassSwitchTile(
                                context,
                                Icons.volume_up_outlined,
                                'Sound Effects',
                                'Play sounds on interactions',
                                _soundEnabled,
                                (v) => setState(() => _soundEnabled = v),
                              ),
                              Divider(
                                  height: 1,
                                  color: Colors.white.withOpacity(0.1)),
                              _buildGlassSwitchTile(
                                context,
                                Icons.vibration_outlined,
                                'Haptic Feedback',
                                'Vibrate on button presses',
                                _hapticEnabled,
                                (v) => setState(() => _hapticEnabled = v),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),

                        // ── Account Management ──────────────────────────────
                        _sectionLabel(context, 'Account'),
                        const SizedBox(height: 12),
                        GlassCard(
                          blur: 15,
                          opacity: 0.2,
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              _buildGlassActionTile(
                                context,
                                Icons.person_outline,
                                'Edit Display Name',
                                'Change how your name appears',
                                () => _showEditProfileDialog(context, auth),
                              ),
                              Divider(
                                  height: 1,
                                  color: Colors.white.withOpacity(0.1)),
                              _buildGlassActionTile(
                                context,
                                Icons.lock_outline,
                                'Change Password',
                                'Update your sign-in password',
                                () =>
                                    _showChangePasswordDialog(context, auth),
                              ),
                              Divider(
                                  height: 1,
                                  color: Colors.white.withOpacity(0.1)),
                              _buildGlassActionTile(
                                context,
                                Icons.email_outlined,
                                'Reset Password via Email',
                                'Send a password reset link to ${auth.currentUser?.email ?? ''}',
                                () async {
                                  try {
                                    await auth.sendPasswordReset();
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                        content: Text(
                                            'Password reset email sent!'),
                                        backgroundColor: Colors.green,
                                      ));
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                        content: Text('Error: $e'),
                                        backgroundColor: Colors.red,
                                      ));
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),

                        // ── Danger Zone ─────────────────────────────────────
                        _sectionLabel(context, 'Danger Zone'),
                        const SizedBox(height: 12),
                        GlassCard(
                          blur: 15,
                          opacity: 0.2,
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              _buildGlassActionTile(
                                context,
                                Icons.logout,
                                'Log Out',
                                'Sign out of your account',
                                () => _showLogoutDialog(context, auth),
                                iconColor: Colors.orange,
                                titleColor: Colors.orange,
                              ),
                              Divider(
                                  height: 1,
                                  color: Colors.white.withOpacity(0.1)),
                              _buildGlassActionTile(
                                context,
                                Icons.delete_forever_outlined,
                                'Delete Account',
                                'Permanently remove your account and data',
                                () => _showDeleteAccountDialog(context, auth),
                                iconColor: Colors.redAccent,
                                titleColor: Colors.redAccent,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),

                        // ── App Info ─────────────────────────────────────────
                        Center(
                          child: Text(
                            'VoiceBridge v1.0.0',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.4),
                                fontSize: 13),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            'Your Speaking Practice Partner',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.3),
                                fontSize: 12),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String label) {
    return Text(
      label,
      style: Theme.of(context).textTheme.displaySmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
    );
  }

  Widget _statChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child:
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 12)),
    );
  }
}
