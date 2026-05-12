import 'dart:async';

import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../services/local_llm_service.dart';
import '../../core/theme/app_theme.dart';

/// Shown on first launch when the local AI model needs to be downloaded.
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
  String _channelLabel = '…';
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutCubic),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();

    _refreshConnectivity();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((_) {
      _refreshConnectivity();
    });

    // Begin download immediately
    _startDownload();
  }

  Future<void> _refreshConnectivity() async {
    try {
      final results = await Connectivity().checkConnectivity();
      if (!mounted) return;
      final online = results.any((r) => r != ConnectivityResult.none);
      setState(() {
        _channelLabel = online ? 'Online' : 'Offline';
      });
    } catch (_) {
      if (mounted) setState(() => _channelLabel = 'Unknown');
    }
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _startDownload() async {
    setState(() {
      _error = null;
      _progress = 0;
      _isDone = false;
    });

    try {
      await for (final p in LocalLlmService().downloadWithProgress()) {
        if (!mounted) return;
        setState(() => _progress = p);
      }
      if (!mounted) return;
      setState(() => _isDone = true);

      // Short pause so users see the 100% completion state
      await Future.delayed(const Duration(milliseconds: 1500));
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
      backgroundColor: AppColors.background,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                _buildVisualCore(),
                const SizedBox(height: 56),
                _buildStatusText(),
                const SizedBox(height: 64),
                _buildActiveModule(),
                const Spacer(),
                _buildFooterTelemetry(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Functional Modules
  // --------------------------------------------------------------------------

  Widget _buildVisualCore() {
    return Center(
      child: AnimatedBuilder(
        animation: _pulseAnim,
        builder: (context, child) {
          return Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
            alignment: Alignment.center,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15 + (0.2 * (1 - _pulseAnim.value))),
                  width: 1,
                ),
              ),
              alignment: Alignment.center,
              child: Transform.scale(
                scale: _pulseAnim.value,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Icon(
                    _isDone ? Icons.check : Icons.blur_on_sharp,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusText() {
    return Column(
      children: [
        Text(
          _isDone ? 'Ready' : 'Downloading model…',
          style: const TextStyle(
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
            fontSize: 12,
            letterSpacing: 2.0,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _isDone ? 'Coaching model installed' : 'Fetching on-device AI',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildActiveModule() {
    if (_error != null) return _buildErrorBox();
    if (_isDone) return _buildSuccessSequence();
    return _buildDownloadingMatrix();
  }

  Widget _buildDownloadingMatrix() {
    final double fraction = _progress / 100.0;
    final bool indeterminate = _progress <= 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Progress',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: AppColors.textTertiary,
              ),
            ),
            Text(
              '${_progress.toString().padLeft(2, '0')}%',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: SizedBox(
            height: 8,
            width: double.infinity,
            child: LinearProgressIndicator(
              value: indeterminate ? null : fraction.clamp(0.0, 1.0),
              backgroundColor: AppColors.surface,
              color: AppColors.primary,
              minHeight: 8,
            ),
          ),
        ),
        const SizedBox(height: 40),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            _techChip('Size · 614 MB'),
            _techChip('Network · $_channelLabel'),
            _techChip('Status · In progress'),
          ],
        ),
      ],
    );
  }

  Widget _buildSuccessSequence() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: const [
          Text(
            'Almost ready…',
            style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBox() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.accentRed.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Text(
            'Download failed',
            style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, color: AppColors.accentRed, letterSpacing: 1.5, fontSize: 10),
          ),
          const SizedBox(height: 12),
          Text(
            _error ?? 'Something went wrong. Check your connection and try again.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _startDownload,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: const Text(
                'Try again',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontFamily: 'monospace', fontSize: 11, letterSpacing: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _techChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.borderLight),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontWeight: FontWeight.bold,
          fontSize: 9,
          color: Colors.white54,
        ),
      ),
    );
  }

  Widget _buildFooterTelemetry() {
    return Center(
      child: Column(
        children: [
          const Text(
            'Your practice stays on this device.',
            style: TextStyle(
              fontSize: 9,
              color: Colors.white10,
              letterSpacing: 1,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'VoiceBridge',
            style: TextStyle(
              fontSize: 8,
              color: Colors.white.withValues(alpha: 0.05),
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
