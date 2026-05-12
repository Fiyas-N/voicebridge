import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../data/local/database_helper.dart';
import 'firebase_service.dart';

/// Sync Service
/// Listens to connectivity changes and automates flushing offline 
/// usage statistics (scores) up to Firestore once network is verified.
class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final DatabaseHelper _db = DatabaseHelper.instance;
  final FirebaseService _firebase = FirebaseService();
  
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _isSyncing = false;

  /// Instantiates the global network observer loop.
  void initialize() {
    if (_connectivitySub != null) return;

    debugPrint('SyncService: Activating Background Network Observer...');
    
    // Listen to realtime connectivity updates from system
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final isOnline = results.any((r) => r != ConnectivityResult.none);
      if (isOnline) {
        debugPrint('SyncService: Network detected! Flaring synchronization flare.');
        processPendingUploads();
      }
    });

    // Run initial check immediately
    processPendingUploads();
  }

  /// Scans local SQFlite storage for completed but un-synced sessions and
  /// uploads summary metrics to Firebase. Never sends conversations or audio.
  Future<void> processPendingUploads() async {
    if (_isSyncing) return; // debounce overlapping triggers
    final uid = _firebase.currentUserId;
    if (uid == null) return; // wait for authentication

    _isSyncing = true;
    debugPrint('SyncService: Auditing local storage for unsynced session artifacts...');

    try {
      final unsynced = await _db.getUnsyncedSessions(uid);
      
      if (unsynced.isEmpty) {
        debugPrint('SyncService: Verification complete. Zero outstanding queue entries.');
        _isSyncing = false;
        return;
      }

      debugPrint('SyncService: Identified ${unsynced.length} pending records. Initiating push sequence.');

      int successCount = 0;
      for (final row in unsynced) {
        final sessionId = row['session_id'] as String;
        try {
          // Sanitize: filter out sensitive textual and raw audio artifact paths
          final firebaseMap = {
            'userId':              uid,
            'type':                row['type'],
            'promptId':            row['prompt_id'],
            'status':              'completed',
            'audioDuration':       row['audio_duration'],
            'createdAt':           row['created_at'],
            'completedAt':         row['completed_at'],
            // Metrics only (Rule fulfillment: No transcripts, no logs)
            'fluencyScore':        row['fluency_score'],
            'grammarScore':        row['grammar_score'],
            'pronunciationScore':  row['pronunciation_score'],
            'overallScore':        row['composite_score'],
            'estimatedBand':       row['estimated_band'],
          };

          await _firebase.saveSessionData(
            userId: uid,
            sessionId: sessionId,
            sessionData: firebaseMap,
          );

          // Persist final localized success stamp
          await _db.updateSession(sessionId, {
            'synced': 1,
            'last_synced_at': DateTime.now().millisecondsSinceEpoch
          });
          
          successCount++;
        } catch (e) {
          debugPrint('SyncService: Transmission conflict on node $sessionId ($e). Deflecting for retry.');
        }
      }
      debugPrint('SyncService: Sequence complete. $successCount records elevated to registry.');
    } catch (e) {
      debugPrint('SyncService: Engine exception: $e');
    } finally {
      _isSyncing = false;
    }
  }

  void dispose() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
  }
}
