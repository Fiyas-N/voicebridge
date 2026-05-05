import 'package:flutter/foundation.dart';
import './auth_provider.dart';
import 'package:uuid/uuid.dart';
import '../data/models/session.dart';
import '../data/models/prompt.dart';
import '../data/local/database_helper.dart';
import '../services/audio_service.dart';
import '../services/ai_pipeline.dart';
import '../services/firebase_service.dart';
import '../services/gamification_service.dart';
import '../services/language_detection_service.dart';
import '../services/local_llm_service.dart';
import '../services/local_stt_service.dart';
import '../core/constants/app_constants.dart';

/// Tracks which phase of the AI pipeline is currently running.
/// The UI uses this to show progressive results rather than a blank spinner.
enum PipelineStage {
  idle,
  transcribing,   // Whisper running
  analyzing,      // Grammar + pronunciation scoring
  generating,     // Gemma writing feedback (slowest step)
  done,
}

class SessionProvider with ChangeNotifier {
  final DatabaseHelper _dbHelper;
  final AudioService _audioService;
  final FirebaseService _firebaseService;

  Session? _currentSession;
  bool _isRecording = false;
  bool _isProcessing = false;
  double _recordingDuration = 0.0;

  /// Transcript available after STT — before Gemma finishes.
  String? earlyTranscript;

  /// Stream of feedback tokens — populated during Gemma generation.
  Stream<String>? feedbackStream;

  /// Which pipeline stage is currently active.
  PipelineStage pipelineStage = PipelineStage.idle;

  /// Set to the detected language name (e.g. 'Malayalam') if the user spoke
  /// in a non-English language. Null when English was detected or per session start.
  /// FeedbackScreen reads this to show a 'Please speak in English' card.
  String? languageWarning;

  SessionProvider(this._dbHelper, this._audioService, this._firebaseService);

  Session? get currentSession => _currentSession;
  bool get isRecording => _isRecording;
  bool get isProcessing => _isProcessing;
  double get recordingDuration => _recordingDuration;

  Future<void> startRecording(Prompt prompt, String userId, {bool isBaseline = false}) async {
    final sessionId = const Uuid().v4();
    
    try {
      final audioPath = await _audioService.startRecording(sessionId);
      
      _currentSession = Session(
        sessionId: sessionId,
        userId: userId,
        type: isBaseline ? 'baseline' : 'daily_practice',
        createdAt: DateTime.now(),
        status: SessionStatus.recording,
        promptId: prompt.promptId,
        promptText: prompt.text,
        audioLocalPath: audioPath,
      );
      
      _isRecording = true;
      _recordingDuration = 0.0;
      notifyListeners();
      
      // Start duration timer
      _startDurationTimer();
    } catch (e) {
      throw Exception('Failed to start recording: $e');
    }
  }

  void _startDurationTimer() {
    Future.doWhile(() async {
      if (!_isRecording) return false;
      
      await Future.delayed(const Duration(milliseconds: 100));
      _recordingDuration += 0.1;
      notifyListeners();
      
      // Auto-stop at max duration
      if (_recordingDuration >= AppConstants.maxRecordingDurationSeconds) {
        await stopRecording();
        return false;
      }
      
      return true;
    });
  }

  Future<void> stopRecording() async {
    if (!_isRecording || _currentSession == null) return;

    try {
      await _audioService.stopRecording();
      
      // Use the actual recorded duration from the timer
      final duration = _recordingDuration;
      
      if (duration < AppConstants.minRecordingDurationSeconds) {
        _isRecording = false;
        notifyListeners();
        throw Exception('Recording too short. Please speak for at least ${AppConstants.minRecordingDurationSeconds} seconds.');
      }

      _currentSession = _currentSession!.copyWith(
        status: SessionStatus.pendingUpload,
        audioDuration: duration,
      );
      
      _isRecording = false;
      notifyListeners();
      
      // Save to local database
      await _dbHelper.insertSession(_currentSession!.toDbMap());
      
    } catch (e) {
      _isRecording = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> submitRecording(AuthProvider authProvider) async {
    if (_currentSession == null) return;

    _isProcessing = true;
    earlyTranscript = null;
    feedbackStream = null;
    languageWarning = null; // reset per session
    pipelineStage = PipelineStage.transcribing;
    notifyListeners();

    try {
      final sttService = LocalSttService();
      final llm = LocalLlmService();

      // ── Step 1: Transcribe ──────────────────────────────────────────────
      // Whisper runs first. The moment we have text, show it to the user.
      debugPrint('Provider: Starting STT…');
      final transcription = await sttService.transcribe(_currentSession!.audioLocalPath!);

      if (transcription.transcript.trim().isEmpty) {
        throw Exception('No speech detected — please try again.');
      }

      // Publish transcript immediately so the UI can navigate forward NOW.
      earlyTranscript = transcription.transcript;
      pipelineStage = PipelineStage.analyzing;
      notifyListeners(); // ← UI navigates to FeedbackScreen with transcript

      // ── Step 1.5: Language detection (instant, offline, no model) ────────
      // Check BEFORE running grammar or loading Gemma so we waste zero resources
      // when the user speaks in Malayalam, Hindi, Tamil, etc.
      final langResult =
          LanguageDetectionService().detect(transcription.transcript);

      if (!langResult.isEnglish) {
        languageWarning = langResult.detectedLanguageName ?? 'a non-English language';
        pipelineStage = PipelineStage.done;
        _isProcessing = false;
        notifyListeners(); // FeedbackScreen shows the warning card
        debugPrint('Provider: Non-English detected (${langResult.detectedCode}) — pipeline stopped.');
        return; // ← Gemma and grammar never run — RAM saved
      }

      // ── Step 2: Grammar + Pronunciation (no LLM) ────────────────────────
      debugPrint('Provider: Running grammar + pronunciation…');
      final aiPipeline = AIProcessingPipeline();
      final grammarFuture = aiPipeline.grammarService.analyzeGrammar(transcription.transcript);
      final pronunciationFuture = aiPipeline.pronunciationService.assessPronunciation(
        audioPath: _currentSession!.audioLocalPath!,
        referenceText: _currentSession!.promptText ?? '',
      );
      final grammar = await grammarFuture;
      final pronunciation = await pronunciationFuture;


      final overallScore = aiPipeline.calcOverallScore(
        fluency: pronunciation.fluencyScore,
        grammar: grammar.score,
        pronunciation: pronunciation.overallScore,
      );
      final ieltsBand = aiPipeline.calcBand(overallScore);
      final cefr = AIProcessingPipeline.mapToCEFR(overallScore);

      // ── Step 3: Stream Gemma feedback ───────────────────────────────────
      pipelineStage = PipelineStage.generating;
      notifyListeners();

      debugPrint('Provider: Loading Gemma for streamed feedback…');
      await llm.loadModel();

      final errorTypes = grammar.errors.map((e) => e.type).toSet().toList();
      final feedbackPrompt = aiPipeline.feedbackService.buildPrompt(
        fluencyScore: pronunciation.fluencyScore,
        grammarScore: grammar.score,
        pronunciationScore: pronunciation.overallScore,
        grammarErrors: errorTypes,
        correctedSentence: grammar.correctedText,
      );

      // generateResponseStream returns a stream of tokens — UI renders each one.
      feedbackStream = await llm.generateResponseStream(feedbackPrompt);
      notifyListeners(); // FeedbackScreen subscribes to feedbackStream

      // Collect full feedback string while stream is consumed by the UI.
      final feedbackBuffer = StringBuffer();
      await for (final token in feedbackStream!) {
        feedbackBuffer.write(token);
      }
      final fullFeedback = feedbackBuffer.toString().trim();

      await llm.unloadModel();

      // ── Step 4: Persist complete session ────────────────────────────────
      pipelineStage = PipelineStage.done;

      final scores = SessionScores(
        fluency: pronunciation.fluencyScore,
        grammar: grammar.score,
        pronunciation: pronunciation.overallScore,
        composite: overallScore,
        estimatedIELTSBand: ieltsBand,
        cefrLevel: cefr,
      );

      _currentSession = _currentSession!.copyWith(
        status: SessionStatus.completed,
        completedAt: DateTime.now(),
        scores: scores,
        transcript: transcription.transcript,
        feedback: fullFeedback,
        wordResults: transcription.words,
        synced: false,
      );

      await _dbHelper.updateSession(_currentSession!.sessionId, _currentSession!.toDbMap());

      // Award XP and update gamification stats
      try {
        final profile = await _dbHelper.getUserProfile(_currentSession!.userId);
        if (profile != null) {
          await GamificationService().completeSession(
            userId: _currentSession!.userId,
            compositeScore: overallScore,
            cefrLevel: cefr,
            currentStreak: profile['current_streak'] as int? ?? 0,
            totalSessions: profile['total_sessions'] as int? ?? 0,
          );
          final updatedLocal = await _dbHelper.getUserProfile(_currentSession!.userId);
          if (updatedLocal != null && authProvider.currentUser != null) {
            final updatedCloud = authProvider.currentUser!.copyWith(
              currentStreak: updatedLocal['current_streak'] as int? ?? 0,
              longestStreak: updatedLocal['longest_streak'] as int? ?? 0,
              totalSessions: updatedLocal['total_sessions'] as int? ?? 0,
              xp: updatedLocal['xp'] as int? ?? 0,
              dailyGoal: updatedLocal['daily_goal'] as int? ?? 3,
            );
            await _firebaseService.updateUserProfile(updatedCloud);
          }
        }
      } catch (e) {
        debugPrint('Gamification update failed: $e');
      }

      try {
        await _syncToFirebase();
      } catch (e) {
        debugPrint('Firebase sync failed, will retry later: $e');
      }

      _isProcessing = false;
      notifyListeners();
      await authProvider.refreshUserProfile();
    } catch (e) {
      _isProcessing = false;
      pipelineStage = PipelineStage.idle;
      notifyListeners();
      throw Exception('Failed to process recording: $e');
    }
  }
  
  /// Sync current session to Firebase — only uploads summary metrics, never raw
  /// transcript or audio. Raw data stays on the user's device only.
  Future<void> _syncToFirebase() async {
    if (_currentSession == null) return;

    // Only send quantitative summary metrics — no transcript, feedback, or audio
    final firebaseData = {
      'userId':              _currentSession!.userId,
      'type':                _currentSession!.type,
      'promptId':            _currentSession!.promptId,
      'status':              _currentSession!.statusString,
      'audioDuration':       _currentSession!.audioDuration,
      'createdAt':           _currentSession!.createdAt.millisecondsSinceEpoch,
      'completedAt':         _currentSession!.completedAt?.millisecondsSinceEpoch,
      // Summary scores only — detailed grammar/pronunciation artifacts stay local
      'fluencyScore':        _currentSession!.scores?.fluency,
      'grammarScore':        _currentSession!.scores?.grammar,
      'pronunciationScore':  _currentSession!.scores?.pronunciation,
      'overallScore':        _currentSession!.scores?.composite,
      'estimatedBand':       _currentSession!.scores?.estimatedIELTSBand,
    };

    await _firebaseService.saveSessionData(
      userId: _currentSession!.userId,
      sessionId: _currentSession!.sessionId,
      sessionData: firebaseData,
    );

    // Mark as synced locally
    _currentSession = _currentSession!.copyWith(synced: true);
    await _dbHelper.updateSession(
        _currentSession!.sessionId, _currentSession!.toDbMap());
  }


  Future<void> playCurrentRecording() async {
    if (_currentSession?.audioLocalPath != null) {
      await _audioService.playRecording(_currentSession!.audioLocalPath!);
    }
  }

  Future<void> stopPlayback() async {
    await _audioService.stopPlayback();
  }

  void clearCurrentSession() {
    _currentSession = null;
    _isRecording = false;
    _isProcessing = false;
    _recordingDuration = 0.0;
    // Free LLM RAM whenever the user navigates away from a session
    LocalLlmService().unloadModel();
    notifyListeners();
  }

  /// Saves a pre-analyzed session (like from Live Conversation)
  Future<void> saveCompletedSession({
    required AuthProvider authProvider,
    required String userId,
    required String type,
    required String? promptText,
    required double duration,
    required double compositeScore,
    required String cefrLevel,
    required String feedback,
    required String transcript,
    List<String> grammarCorrections = const [],
    List<String> improvementTips = const [],
    List<String> advancedVocabulary = const [],
    List<WordInfo> wordResults = const [],
  }) async {
    final sessionId = const Uuid().v4();
    
    final scores = SessionScores(
      fluency: compositeScore * 0.9, 
      grammar: compositeScore, 
      pronunciation: compositeScore * 0.95,
      composite: compositeScore,
      estimatedIELTSBand: (compositeScore / 10).clamp(0, 9),
      cefrLevel: cefrLevel,
    );

    final session = Session(
      sessionId: sessionId,
      userId: userId,
      type: type,
      createdAt: DateTime.now().subtract(Duration(seconds: duration.toInt())),
      completedAt: DateTime.now(),
      status: SessionStatus.completed,
      promptText: promptText,
      audioDuration: duration,
      transcript: transcript,
      scores: scores,
      feedback: feedback,
      grammarCorrections: grammarCorrections,
      improvementTips: improvementTips,
      advancedVocabulary: advancedVocabulary,
      wordResults: wordResults,
      synced: false,
    );

    await _dbHelper.insertSession(session.toDbMap());

    // Award XP
    try {
      final profile = await _dbHelper.getUserProfile(userId);
      if (profile != null) {
        await GamificationService().completeSession(
          userId: userId,
          compositeScore: compositeScore,
          cefrLevel: cefrLevel,
          currentStreak: profile['current_streak'] as int? ?? 0,
          totalSessions: profile['total_sessions'] as int? ?? 0,
        );

        // Sync updated local profile to Firestore
        final updatedLocal = await _dbHelper.getUserProfile(userId);
        if (updatedLocal != null && authProvider.currentUser != null) {
          final updatedCloud = authProvider.currentUser!.copyWith(
            currentStreak: updatedLocal['current_streak'] as int? ?? 0,
            longestStreak: updatedLocal['longest_streak'] as int? ?? 0,
            totalSessions: updatedLocal['total_sessions'] as int? ?? 0,
            xp: updatedLocal['xp'] as int? ?? 0,
            dailyGoal: updatedLocal['daily_goal'] as int? ?? 3,
          );
          await _firebaseService.updateUserProfile(updatedCloud);
        }
      }
    } catch (e) {
      debugPrint('Gamification update failed: $e');
    }

    // Try sync
    try {
      _currentSession = session;
      await _syncToFirebase();
      _currentSession = null;
    } catch (_) {}

    // Refresh AuthProvider to update Home Screen stats
    await authProvider.refreshUserProfile();
  }

  Future<List<Session>> getUserSessions(String userId) async {
    final sessionsData = await _dbHelper.getUserSessions(userId);
    return sessionsData.map((data) => Session.fromJson(data)).toList();
  }
}
