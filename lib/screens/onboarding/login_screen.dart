import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/main_navigation.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      await auth.signIn(_emailController.text.trim(), _passwordController.text);
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Sign-in failed: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: AppColors.error,
        ));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleForgotPassword() async {
    final e = _emailController.text.trim();
    if (e.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter your email first.'), backgroundColor: AppColors.warning));
      return;
    }
    try {
      await Provider.of<AuthProvider>(context, listen: false).sendPasswordResetForEmail(e);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('If an account exists, we sent a reset link to your email.'), backgroundColor: AppColors.success));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle, border: Border.all(color: AppColors.borderLight),
                  ),
                  child: const Icon(Icons.vpn_key_outlined, size: 36, color: Colors.white),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Log in',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter your email and password',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textTertiary, fontSize: 10, fontFamily: 'monospace', letterSpacing: 1),
              ),
              const SizedBox(height: 48),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildInput(
                        ctrl: _emailController,
                        lbl: 'Email',
                        ht: 'you@example.com',
                        icon: Icons.alternate_email,
                        val: Validators.validateEmail,
                      ),
                      const SizedBox(height: 20),
                      _buildInput(
                        ctrl: _passwordController,
                        lbl: 'Password',
                        ht: '••••••••',
                        icon: Icons.lock_outline,
                        obsc: true,
                        val: Validators.validatePassword,
                        sub: (_) => _handleLogin(),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          child: _isLoading
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                              : const Text('Log in'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: _handleForgotPassword,
                child: const Text('Forgot password?', style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppColors.textTertiary, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('No account? ', style: TextStyle(color: Colors.white38, fontFamily: 'monospace', fontSize: 11)),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const SignupScreen())),
                    child: const Text('Create one', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, decoration: TextDecoration.underline, fontFamily: 'monospace', fontSize: 11)),
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController ctrl,
    required String lbl,
    required String ht,
    required IconData icon,
    bool obsc = false,
    String? Function(String?)? val,
    void Function(String)? sub,
  }) {
    return TextFormField(
      controller: ctrl,
      obscureText: obsc,
      validator: val,
      onFieldSubmitted: sub,
      style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 13),
      decoration: InputDecoration(
        labelText: lbl,
        hintText: ht,
        hintStyle: const TextStyle(color: Colors.white24),
        labelStyle: const TextStyle(fontFamily: 'monospace', color: AppColors.textTertiary, fontSize: 11),
        prefixIcon: Icon(icon, color: Colors.white38, size: 18),
        filled: true,
        fillColor: Colors.black45,
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.borderLight)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.white)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.accentRed)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.accentRed)),
      ),
    );
  }
}
