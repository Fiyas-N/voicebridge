import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// Audio Service
/// Handles audio recording and playback functionality
class AudioService {
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();

  /// Reflects preview playback state for UI (e.g. recording review waveform).
  final ValueNotifier<bool> previewPlaying = ValueNotifier(false);
  
  bool _isRecording = false;
  String? _currentRecordingPath;

  bool get isRecording => _isRecording;
  String? get currentRecordingPath => _currentRecordingPath;

  AudioService() {
    _player.onPlayerStateChanged.listen((state) {
      previewPlaying.value = state == PlayerState.playing;
    });
  }

  /// After [AudioRecorder] stops, Android often stays in voice/communication
  /// routing; preview must request media playback + speaker so WAV is audible.
  static const AudioContext _previewPlaybackContext = AudioContext(
    android: AudioContextAndroid(
      isSpeakerphoneOn: true,
      audioMode: AndroidAudioMode.normal,
      contentType: AndroidContentType.speech,
      usageType: AndroidUsageType.media,
      audioFocus: AndroidAudioFocus.gain,
    ),
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.playback,
    ),
  );
  
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
      final path = '${directory.path}/recordings/$sessionId.wav';
      
      // Create recordings directory if it doesn't exist
      final recordingsDir = Directory('${directory.path}/recordings');
      if (!await recordingsDir.exists()) {
        await recordingsDir.create(recursive: true);
      }
      
      // Start recording with v5 API (Whisper expects 16kHz PCM WAV)
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          bitRate: 256000,
          sampleRate: 16000,
          numChannels: 1,
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
      if (path != null && path.isNotEmpty) {
        _currentRecordingPath = path;
      }
      return path ?? _currentRecordingPath;
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

  /// Play recorded audio (WAV). Stops any current preview first.
  Future<void> playRecording(String path) async {
    try {
      await stopPlayback();
      final file = File(path);
      if (!await file.exists()) {
        throw Exception('Recording file not found');
      }
      final size = await file.length();
      if (size < 64) {
        throw Exception('Recording file is empty or too small');
      }
      final absolute = file.absolute.path;

      await _player.setVolume(1.0);
      await _player.play(
        DeviceFileSource(absolute),
        ctx: _previewPlaybackContext,
        mode: PlayerMode.mediaPlayer,
      );
    } catch (e) {
      throw Exception('Failed to play recording: $e');
    }
  }

  /// Stop playback
  Future<void> stopPlayback() async {
    await _player.stop();
    previewPlaying.value = false;
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

      await stopPlayback();
      final absolute = file.absolute.path;
      await _player.setSourceDeviceFile(absolute);
      final duration = await _player.getDuration();
      await _player.stop();
      previewPlaying.value = false;

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
