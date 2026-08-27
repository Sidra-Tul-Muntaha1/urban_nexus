// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// Web implementation of browser file download using HTML anchor blob.
void downloadFileWeb(String content, String fileName) {
  final bytes = html.Blob([content], 'text/plain;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(bytes);
  html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
}
