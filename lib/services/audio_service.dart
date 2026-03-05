import 'dart:io';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// Audio Service
/// Handles audio recording and playback functionality
class AudioService {
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();
  
  bool _isRecording = false;
  String? _currentRecordingPath;

  bool get isRecording => _isRecording;
  String? get currentRecordingPath => _currentRecordingPath;
  
  /// Check and request microphone permission
  Future<bool> checkPermission() async {
    final status = await Permission.microphone.status;
    
    if (status.isGranted) {
      return true;
    }
    
    if (status.isDenied) {
      final result = await Permission.microphone.request();
      return result.isGranted;
    }
    
    if (status.isPermanentlyDenied) {
      await openAppSettings();
      return false;
    }
    
    return false;
  }

  /// Start recording audio
  Future<String?> startRecording(String sessionId) async {
    try {
      // Check permission first
      final hasPermission = await checkPermission();
      if (!hasPermission) {
        throw Exception('Microphone permission denied');
      }
      
      // Get temp directory
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/recordings/$sessionId.m4a';
      
      // Create recordings directory if it doesn't exist
      final recordingsDir = Directory('${directory.path}/recordings');
      if (!await recordingsDir.exists()) {
        await recordingsDir.create(recursive: true);
      }
      
      // Start recording with v5 API
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );
      
      _isRecording = true;
      _currentRecordingPath = path;
      
      return path;
    } catch (e) {
      _isRecording = false;
      throw Exception('Failed to start recording: $e');
    }
  }

  /// Stop recording and return the file path
  Future<String?> stopRecording() async {
    try {
      if (!_isRecording) return null;
      
      final path = await _recorder.stop();
      _isRecording = false;
      
      return path;
    } catch (e) {
      _isRecording = false;
      throw Exception('Failed to stop recording: $e');
    }
  }

  /// Pause recording
  Future<void> pauseRecording() async {
    if (_isRecording) {
      await _recorder.pause();
    }
  }

  /// Resume recording
  Future<void> resumeRecording() async {
    if (_isRecording) {
      await _recorder.resume();
    }
  }

  /// Play recorded audio
  Future<void> playRecording(String path) async {
    try {
      await _player.play(DeviceFileSource(path));
    } catch (e) {
      throw Exception('Failed to play recording: $e');
    }
  }

  /// Stop playback
  Future<void> stopPlayback() async {
    await _player.stop();
  }

  /// Pause playback
  Future<void> pausePlayback() async {
    await _player.pause();
  }

  /// Resume playback
  Future<void> resumePlayback() async {
    await _player.resume();
  }

  /// Get playback position
  Stream<Duration> get onPositionChanged => _player.onPositionChanged;

  /// Get playback state
  Stream<PlayerState> get onPlayerStateChanged => _player.onPlayerStateChanged;

  /// Get recording duration
  Future<double> getRecordingDuration(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return 0.0;
      
      await _player.setSourceDeviceFile(path);
      final duration = await _player.getDuration();
      
      return duration?.inSeconds.toDouble() ?? 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  /// Delete recording file
  Future<void> deleteRecording(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      throw Exception('Failed to delete recording: $e');
    }
  }

  /// Check if recording exists
  Future<bool> recordingExists(String path) async {
    final file = File(path);
    return await file.exists();
  }

  /// Get recording file size in bytes
  Future<int> getRecordingSize(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        return await file.length();
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  /// Dispose resources
  void dispose() {
    _recorder.dispose();
    _player.dispose();
  }
}
