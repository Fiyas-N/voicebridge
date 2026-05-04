import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/local_llm_service.dart';

/// Shown on first launch when the Gemma 3 1B model needs to be downloaded.
/// Displays real-time download progress and auto-navigates when complete.
class ModelSetupScreen extends StatefulWidget {
  /// Called when setup is complete (model installed + ready).
  final VoidCallback onComplete;

  const ModelSetupScreen({super.key, required this.onComplete});

  @override
  State<ModelSetupScreen> createState() => _ModelSetupScreenState();
}

class _ModelSetupScreenState extends State<ModelSetupScreen>
    with TickerProviderStateMixin {
  // Animation controllers
  late final AnimationController _pulseController;
  late final AnimationController _fadeController;
  late final Animation<double> _pulseAnim;
  late final Animation<double> _fadeAnim;

  // Download state
  int _progress = 0;
  bool _isDone = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();

    // Begin download immediately
    _startDownload();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _startDownload() async {
    setState(() => _error = null);

    try {
      await for (final p in LocalLlmService().downloadWithProgress()) {
        if (!mounted) return;
        setState(() => _progress = p);
      }
      if (!mounted) return;
      setState(() => _isDone = true);

      // Short pause so users see the 100% completion state
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) widget.onComplete();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  // --------------------------------------------------------------------------
  // Build
  // --------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                _buildLogo(),
                const SizedBox(height: 40),
                _buildTitle(),
                const SizedBox(height: 16),
                _buildSubtitle(),
                const SizedBox(height: 56),
                _buildProgressSection(),
                const Spacer(),
                _buildFootnote(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Sections
  // --------------------------------------------------------------------------

  Widget _buildLogo() {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (context, child) => Transform.scale(
        scale: _pulseAnim.value,
        child: child,
      ),
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.4),
              blurRadius: 32,
              spreadRadius: 4,
            ),
          ],
        ),
        child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 52),
      ),
    );
  }

  Widget _buildTitle() {
    return Text(
      'Setting up AI Engine',
      style: GoogleFonts.outfit(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: Colors.white,
        letterSpacing: -0.5,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildSubtitle() {
    return Text(
      'Preparing Gemma 3 1B — your private, on-device language model.\nThis one-time setup takes about a minute.',
      style: GoogleFonts.outfit(
        fontSize: 14,
        color: Colors.white.withValues(alpha: 0.55),
        height: 1.6,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildProgressSection() {
    if (_error != null) return _buildErrorState();
    if (_isDone) return _buildDoneState();
    return _buildDownloadProgress();
  }

  Widget _buildDownloadProgress() {
    final double fraction = _progress / 100.0;
    return Column(
      children: [
        // Percent label
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Preparing…',
              style: GoogleFonts.outfit(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 13,
              ),
            ),
            Text(
              '$_progress%',
              style: GoogleFonts.outfit(
                color: const Color(0xFF7C3AED),
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 10,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7C3AED)),
          ),
        ),
        const SizedBox(height: 28),
        // Stats row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _statChip(Icons.storage_rounded, '~529 MB'),
            const SizedBox(width: 12),
            _statChip(Icons.wifi_off_rounded, '100% Offline'),
            const SizedBox(width: 12),
            _statChip(Icons.lock_rounded, 'On-device'),
          ],
        ),
      ],
    );
  }

  Widget _buildDoneState() {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.green.withValues(alpha: 0.15),
          ),
          child: const Icon(Icons.check_circle_rounded,
              color: Colors.greenAccent, size: 42),
        ),
        const SizedBox(height: 16),
        Text(
          'Gemma 3 1B Ready!',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Starting VoiceBridge…',
          style: GoogleFonts.outfit(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Column(
      children: [
        const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
        const SizedBox(height: 16),
        Text(
          'Setup failed',
          style: GoogleFonts.outfit(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Colors.redAccent,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Could not prepare the AI model.\nPlease try again.',
          style: GoogleFonts.outfit(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.5),
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _startDownload,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Try Again'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7C3AED),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFootnote() {
    return Text(
      '🔒 Your audio never leaves your device.\nGemma runs 100% offline — no internet needed.',
      style: GoogleFonts.outfit(
        fontSize: 12,
        color: Colors.white.withValues(alpha: 0.35),
        height: 1.6,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _statChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF7C3AED)),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
