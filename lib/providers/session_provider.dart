import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../data/models/session.dart';
import '../data/models/prompt.dart';
import '../data/local/database_helper.dart';
import '../services/audio_service.dart';
import '../services/ai_pipeline.dart';
import '../services/firebase_service.dart';
import '../core/constants/app_constants.dart';

class SessionProvider with ChangeNotifier {
  final DatabaseHelper _dbHelper;
  final AudioService _audioService;
  final FirebaseService _firebaseService;

  Session? _currentSession;
  bool _isRecording = false;
  bool _isProcessing = false;
  double _recordingDuration = 0.0;

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
      final path = await _audioService.stopRecording();
      
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

  Future<void> submitRecording() async {
    if (_currentSession == null) return;

    _isProcessing = true;
    notifyListeners();

    try {
      // Process recording through AI pipeline
      final aiPipeline = AIProcessingPipeline();
      
      final analysis = await aiPipeline.processRecording(
        audioPath: _currentSession!.audioLocalPath!,
        promptText: _currentSession!.promptText ?? '',
      );
      
      // Create scores from AI analysis
      final scores = SessionScores(
        fluency: analysis.fluencyScore,
        grammar: analysis.grammarScore,
        pronunciation: analysis.pronunciationScore,
        composite: analysis.overallScore,
        estimatedIELTSBand: analysis.ieltsBand,
      );
      
      _currentSession = _currentSession!.copyWith(
        status: SessionStatus.completed,
        completedAt: DateTime.now(),
        scores: scores,
        transcript: analysis.transcription,
        feedback: analysis.feedback,
        synced: false, // Mark as not synced initially
      );
      
      // Save to local database first
      await _dbHelper.updateSession(_currentSession!.sessionId, _currentSession!.toDbMap());
      
      // Try to sync to Firebase
      try {
        await _syncToFirebase();
      } catch (e) {
        debugPrint('Firebase sync failed, will retry later: $e');
        // Don't fail the whole operation if Firebase sync fails
      }
      
      _isProcessing = false;
      notifyListeners();
      
    } catch (e) {
      _isProcessing = false;
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
    notifyListeners();
  }

  Future<List<Session>> getUserSessions(String userId) async {
    final sessionsData = await _dbHelper.getUserSessions(userId);
    return sessionsData.map((data) => Session.fromJson(data)).toList();
  }
}
