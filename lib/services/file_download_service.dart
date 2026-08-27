import 'file_download_stub.dart'
    if (dart.library.html) 'file_download_web.dart' as download_impl;

/// Cross-platform file download utility for UrbanNexus.
class FileDownloadService {
  FileDownloadService._();

  /// Triggers a download of [content] with name [fileName] in the browser
  /// or handles it safely on desktop/mobile.
  static void downloadTextFile(String content, String fileName) {
    download_impl.downloadFileWeb(content, fileName);
  }
}
