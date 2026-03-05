import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/session_provider.dart';
import 'data/local/database_helper.dart';
import 'services/audio_service.dart';
import 'services/firebase_service.dart';
import 'screens/onboarding/welcome_screen.dart';
import 'widgets/common/main_navigation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Load environment variables
    await dotenv.load(fileName: '.env');

    // Initialize Firebase
    await Firebase.initializeApp();
    debugPrint('Firebase initialized successfully');

    // Initialize local SQLite database
    await DatabaseHelper.instance.database;
    debugPrint('Local database initialized');
  } catch (e) {
    debugPrint('Initialization error: $e');
    // Continue anyway for development
  }

  runApp(
    MultiProvider(
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
      child: const VoiceBridgeApp(),
    ),
  );
}

class VoiceBridgeApp extends StatelessWidget {
  const VoiceBridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VoiceBridge',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: Consumer<AuthProvider>(
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
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
