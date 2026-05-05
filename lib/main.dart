import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:async';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/session_provider.dart';
import 'data/local/database_helper.dart';
import 'services/audio_service.dart';
import 'services/tts_service.dart';
import 'services/local_stt_service.dart';
import 'services/local_llm_service.dart';
import 'services/firebase_service.dart';
import 'services/language_detection_service.dart';
import 'screens/onboarding/welcome_screen.dart';
import 'screens/setup/model_setup_screen.dart';
import 'widgets/common/main_navigation.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Init offline language detection (one-time, ~instant, no network)
    await LanguageDetectionService().init();

    // Global Flutter error catcher
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('Fatal Flutter Error: ${details.exception}');
    };

    runApp(const VoiceBridgeApp());
  }, (error, stack) {
    debugPrint('Fatal Unhandled Error: $error');
    debugPrint(stack.toString());
  });
}

class VoiceBridgeApp extends StatefulWidget {
  const VoiceBridgeApp({super.key});

  @override
  State<VoiceBridgeApp> createState() => _VoiceBridgeAppState();
}

class _VoiceBridgeAppState extends State<VoiceBridgeApp> {
  bool _isInitialized = false;
  String? _initError;
  String? _errorDetails;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      debugPrint('Starting VoiceBridge initialization...');
      
      // 1. Load environment variables
      try {
        await dotenv.load(fileName: '.env');
        debugPrint('Environment loaded');
      } catch (e) {
        debugPrint('Warning: .env failed to load, using defaults: $e');
      }

      // 2. Initialize Firebase
      await Firebase.initializeApp();
      debugPrint('Firebase initialized');

      // 3. Initialize local database
      await DatabaseHelper.instance.database;
      debugPrint('Database ready');

      // 4. AI Services (Lazy Init - don't crash the app if these fail)
      // We don't await these here anymore to prevent startup hangups
      _safeInitAi();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e, stack) {
      debugPrint('CRITICAL INIT ERROR: $e');
      debugPrint(stack.toString());
      if (mounted) {
        setState(() {
          _initError = e.toString();
          _errorDetails = stack.toString();
        });
      }
    }
  }

  void _safeInitAi() {
    // Fire and forget, but with individual catch blocks
    TtsService().init().catchError((e) => debugPrint('Non-fatal: TTS Init Fail: $e'));
    LocalSttService().init().catchError((e) => debugPrint('Non-fatal: STT Init Fail: $e'));
    LocalLlmService().init().catchError((e) => debugPrint('Non-fatal: LLM Init Fail: $e'));
  }

  @override
  Widget build(BuildContext context) {
    if (_initError != null) {
      return MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          backgroundColor: const Color(0xFF1A1A1A),
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.report_problem, color: Colors.orange, size: 80),
                  const SizedBox(height: 24),
                  const Text(
                    'VoiceBridge encountered an issue',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _initError!,
                      style: const TextStyle(color: Colors.redAccent, fontFamily: 'monospace'),
                      textAlign: TextAlign.start,
                    ),
                  ),
                  if (_errorDetails != null) ...[
                    const SizedBox(height: 16),
                    const Text('Stack trace available in logs.', style: TextStyle(color: Colors.grey)),
                  ],
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _initError = null;
                        _errorDetails = null;
                        _initializeApp();
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: AppColors.primary),
                SizedBox(height: 24),
                Text('Starting VoiceBridge...', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      );
    }

    // Wrap in ErrorBoundary to catch provider-level crashes
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(
          create: (_) => SessionProvider(
            DatabaseHelper.instance,
            AudioService(),
            FirebaseService(),
          ),
        ),
      ],
      child: const VoiceBridgeMainApp(),
    );
  }
}

class VoiceBridgeMainApp extends StatelessWidget {
  const VoiceBridgeMainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VoiceBridge',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: const ModelGateScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// Checks whether Gemma is already installed.
/// Routes to [ModelSetupScreen] on first launch, or directly to auth flow.
class ModelGateScreen extends StatefulWidget {
  const ModelGateScreen({super.key});

  @override
  State<ModelGateScreen> createState() => _ModelGateScreenState();
}

class _ModelGateScreenState extends State<ModelGateScreen> {
  bool _checking = true;
  bool _needsSetup = false;

  @override
  void initState() {
    super.initState();
    _checkModel();
  }

  Future<void> _checkModel() async {
    final installed = await LocalLlmService().isModelInstalled();
    if (!mounted) return;
    setState(() {
      _needsSetup = !installed;
      _checking = false;
    });
  }

  void _onSetupComplete() {
    if (!mounted) return;
    setState(() {
      _needsSetup = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0F1A),
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_needsSetup) {
      return ModelSetupScreen(onComplete: _onSetupComplete);
    }

    // Model ready — show normal auth flow.
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (authProvider.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (authProvider.isAuthenticated) {
          return const MainNavigationScreen();
        }
        return const WelcomeScreen();
      },
    );
  }
}
