import 'dart:typed_data';
import 'package:http/http.dart' as http;

Future<String> createTempAudioPath(String ext) async => '';

Future<Uint8List> readRecordedAudioBytes(String path) async {
  final response = await http.get(Uri.parse(path));
  if (response.statusCode == 200) {
    return response.bodyBytes;
  }
  throw Exception('Failed to read recorded audio (${response.statusCode})');
}

Future<void> deleteRecordedAudio(String path) async {}

