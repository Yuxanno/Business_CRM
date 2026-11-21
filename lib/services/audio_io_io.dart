import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

Future<String> createTempAudioPath(String ext) async {
  final dir = await getTemporaryDirectory();
  final ts = DateTime.now().millisecondsSinceEpoch;
  return '${dir.path}${Platform.pathSeparator}bizflow_stt_$ts.$ext';
}

Future<Uint8List> readRecordedAudioBytes(String path) async {
  final file = File(path);
  try {
    return await file.readAsBytes();
  } finally {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}

Future<void> deleteRecordedAudio(String path) async {
  try {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  } catch (_) {}
}

