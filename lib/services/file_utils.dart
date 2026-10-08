import 'dart:io';

/// Atomic write (temp file first, then rename) so the native side never sees a half-written file.
Future<void> writeFileAtomic(File file, String content) async {
  final tmp = File('${file.path}.tmp');
  await tmp.writeAsString(content, flush: true);
  await tmp.rename(file.path);
}
