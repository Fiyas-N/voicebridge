import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';
import 'baseline_assessment_screen.dart';
import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      await auth.signUp(_emailController.text.trim(), _passwordController.text, _nameController.text.trim());
      if (mounted) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const BaselineAssessmentScreen()));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('REGISTRATION_ERR: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
              const SizedBox(height: 20),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.borderLight)),
                  child: const Icon(Icons.person_add_alt_1_outlined, size: 36, color: Colors.white),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'REGISTER_NEW_UNIT'.toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2),
              ),
              const SizedBox(height: 8),
              const Text(
                'PROVISIONING USER CREDENTIALS',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textTertiary, fontSize: 10, fontFamily: 'monospace', letterSpacing: 1),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface, borderRadius: BorderRadius.circular(28), border: Border.all(color: AppColors.borderLight),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildInput(
                        ctrl: _nameController,
                        lbl: 'DISPLAY_NAME',
                        ht: 'ENTER NAME',
                        icon: Icons.badge_outlined,
                        val: Validators.validateName,
                      ),
                      const SizedBox(height: 16),
                      _buildInput(
                        ctrl: _emailController,
                        lbl: 'EMAIL_ADDRESS',
                        ht: 'VALID EMAIL',
                        icon: Icons.alternate_email,
                        val: Validators.validateEmail,
                      ),
                      const SizedBox(height: 16),
                      _buildInput(
                        ctrl: _passwordController,
                        lbl: 'SECRET_TOKEN',
                        ht: 'CREATE PASSKEY',
                        icon: Icons.lock_outline,
                        obsc: true,
                        val: Validators.validatePassword,
                        sub: (_) => _handleSignup(),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleSignup,
                          child: _isLoading
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                              : const Text('CREATE_PROFILE'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('ALREADY_PROVISIONED? ', style: TextStyle(color: Colors.white38, fontFamily: 'monospace', fontSize: 11)),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen())),
                    child: const Text('SIGN_IN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, decoration: TextDecoration.underline, fontFamily: 'monospace', fontSize: 11)),
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


