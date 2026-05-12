import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

/// Decimates 16-bit mono PCM from a WAV file into [barCount] normalized peaks (0–1).
Future<List<double>> loadWavPeaks(String filePath, {int barCount = 48}) async {
  final file = File(filePath);
  if (!await file.exists()) return List<double>.filled(barCount, 0.06);

  final bytes = await file.readAsBytes();
  if (bytes.length < 44) return List<double>.filled(barCount, 0.06);

  final dataRange = _findPcmDataRange(bytes);
  if (dataRange == null) return List<double>.filled(barCount, 0.06);

  final start = dataRange.$1;
  final length = dataRange.$2;
  if (length < 4) return List<double>.filled(barCount, 0.06);

  final sampleCount = length ~/ 2;
  if (sampleCount <= 0) return List<double>.filled(barCount, 0.06);

  final samplesPerBar = math.max(1, sampleCount ~/ barCount);
  final peaks = List<double>.filled(barCount, 0.0);

  final slice = bytes.sublist(start, start + length);
  final bd = ByteData.sublistView(slice);
  for (var b = 0; b < barCount; b++) {
    final from = b * samplesPerBar;
    final to = math.min(from + samplesPerBar, sampleCount);
    var sumSq = 0.0;
    var n = 0;
    for (var i = from; i < to; i++) {
      final v = bd.getInt16(i * 2, Endian.little) / 32768.0;
      sumSq += v * v;
      n++;
    }
    final rms = n > 0 ? math.sqrt(sumSq / n) : 0.0;
    peaks[b] = rms;
  }

  var maxP = 1e-6;
  for (final p in peaks) {
    if (p > maxP) maxP = p;
  }
  for (var i = 0; i < peaks.length; i++) {
    peaks[i] = (0.06 + 0.94 * (peaks[i] / maxP)).clamp(0.06, 1.0);
  }
  return peaks;
}

/// Returns (offset, length) of PCM data chunk.
(int, int)? _findPcmDataRange(Uint8List bytes) {
  if (bytes.length < 12) return null;
  if (String.fromCharCodes(bytes.sublist(0, 4)) != 'RIFF') return null;

  var i = 12;
  while (i + 8 <= bytes.length) {
    final id = String.fromCharCodes(bytes.sublist(i, i + 4));
    final size = ByteData.sublistView(bytes, i + 4, i + 8).getUint32(0, Endian.little);
    i += 8;
    final chunkEnd = i + size;
    if (chunkEnd > bytes.length) return null;
    if (id == 'data') {
      return (i, size);
    }
    i = chunkEnd + (size & 1);
  }
  return null;
}
