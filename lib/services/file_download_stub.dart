import 'package:flutter/foundation.dart';

/// Non-web fallback for file downloads.
void downloadFileWeb(String content, String fileName) {
  debugPrint('[FileDownloadService] Export report ($fileName): ${content.length} bytes generated.');
}
