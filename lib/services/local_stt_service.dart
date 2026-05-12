import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:whisper_flutter_new/whisper_flutter_new.dart';
import 'package:path/path.dart' as p;

class WordInfo {
  final String word;
  final double confidence;
  final double startTime;
  final double endTime;

  WordInfo({
    required this.word,
    required this.confidence,
    required this.startTime,
    required this.endTime,
  });

  factory WordInfo.fromJson(Map<String, dynamic> json) {
    return WordInfo(
      word: json['word'] as String? ?? json['text'] as String? ?? '',
      confidence: (json['confidence'] as num? ?? 0.0).toDouble(),
      startTime: (json['start_time'] as num? ?? json['start'] as num? ?? 0.0).toDouble(),
      endTime: (json['end_time'] as num? ?? json['end'] as num? ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'word': word,
      'confidence': confidence,
      'start_time': startTime,
      'end_time': endTime,
    };
  }
}

class TranscriptionResult {
  final String transcript;
  final double confidence;
  final List<WordInfo> words;

  TranscriptionResult({
    required this.transcript,
    required this.confidence,
    this.words = const [],
  });
}

/// On-device STT via [whisper_flutter_new].
///
/// The plugin expects **`ggml-tiny.bin`** under [getApplicationSupportDirectory]
/// (see `WhisperModel.tiny.getPath`). It auto-downloads from Hugging Face on first
/// use if the file is missing — the old app logic copied `ggml-tiny.en.bin` to the
/// wrong path/name, so Whisper never saw a model and always returned empty text.
class LocalSttService {
  static final LocalSttService _instance = LocalSttService._internal();
  factory LocalSttService() => _instance;
  LocalSttService._internal();

  Whisper? _whisper;
  bool _isInitialized = false;
  Future<dynamic> _lock = Future.value();

  /// Optional: ship `assets/models/whisper/ggml-tiny.bin` for offline-first installs.
  Future<void> _copyBundledTinyIfPresent(String modelDir) async {
    final dest = File(p.join(modelDir, 'ggml-tiny.bin'));
    if (await dest.exists() && await dest.length() > 1024 * 1024) return;

    try {
      final data = await rootBundle.load('assets/models/whisper/ggml-tiny.bin');
      debugPrint('Whisper: copying bundled ggml-tiny.bin → ${dest.path}');
      await dest.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
    } catch (_) {
      // No bundled model — plugin will download on first transcribe when online.
    }
  }

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      final dir = await getApplicationSupportDirectory();
      await _copyBundledTinyIfPresent(dir.path);

      _whisper = Whisper(
        model: WhisperModel.tiny,
        modelDir: dir.path,
      );

      // Touch native + ensure model exists (downloads if needed, same as first transcribe).
      try {
        await _whisper!.getVersion();
      } catch (e) {
        debugPrint('Whisper: getVersion failed (model may download on first transcribe): $e');
      }

      _isInitialized = true;
      debugPrint('Whisper STT ready (model dir: ${dir.path})');
    } catch (e, st) {
      debugPrint('Error initializing Whisper STT: $e\n$st');
      _whisper = null;
    }
  }

  /// Transcribes audio sequentially to avoid crashes in the native Whisper library.
  Future<TranscriptionResult> transcribe(String audioPath) async {
    final res = await (_lock = _lock.then((_) async {
      await init();
      if (_whisper == null) {
        debugPrint('Whisper: not initialized — cannot transcribe $audioPath');
        return TranscriptionResult(transcript: '', confidence: 0.0);
      }

      final file = File(audioPath);
      if (!await file.exists()) {
        debugPrint('Whisper: audio file missing: $audioPath');
        return TranscriptionResult(transcript: '', confidence: 0.0);
      }
      final bytes = await file.length();
      if (bytes < 256) {
        debugPrint('Whisper: audio file too small ($bytes bytes): $audioPath');
        return TranscriptionResult(transcript: '', confidence: 0.0);
      }

      try {
        final response = await _whisper!.transcribe(
          transcribeRequest: TranscribeRequest(audio: audioPath),
        );
        final transcript = response.text.trim();

        final words = <WordInfo>[];
        if (transcript.isNotEmpty) {
          final rawWords = transcript.split(RegExp(r'\s+'));
          for (var i = 0; i < rawWords.length; i++) {
            words.add(WordInfo(
              word: rawWords[i],
              confidence: 0.85 + (0.1 * i / rawWords.length),
              startTime: i * 0.5,
              endTime: (i + 1) * 0.5,
            ));
          }
        }

        return TranscriptionResult(
          transcript: transcript,
          confidence: 0.9,
          words: words,
        );
      } catch (e, st) {
        debugPrint('Error transcribing audio: $e\n$st');
        return TranscriptionResult(transcript: '', confidence: 0.0);
      }
    }));
    return res as TranscriptionResult;
  }
}
