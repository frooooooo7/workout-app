import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

/// Nazwa pliku obrazka gotowa do wysyłki. Web często podaje `blob` bez
/// rozszerzenia (albo HEIC itp.), a backend i wykrywanie MIME potrzebują
/// jednego z obsługiwanych rozszerzeń.
String normalizeImageFilename(String filename, {required String fallback}) {
  var name = filename.trim();
  if (name.isEmpty || name.toLowerCase() == 'blob') name = fallback;
  final lower = name.toLowerCase();
  const allowed = ['.jpg', '.jpeg', '.png', '.webp'];
  if (!allowed.any(lower.endsWith)) name = '$name.jpg';
  return name;
}

/// Typ MIME obrazka po nazwie pliku (domyślnie JPEG).
MediaType imageMediaType(String filename) {
  final typed = lookupMimeType(filename);
  if (typed != null && typed.startsWith('image/')) {
    return MediaType.parse(typed);
  }
  final lower = filename.toLowerCase();
  if (lower.endsWith('.png')) return MediaType('image', 'png');
  if (lower.endsWith('.webp')) return MediaType('image', 'webp');
  return MediaType('image', 'jpeg');
}

/// Część multipart z obrazkiem: znormalizowana nazwa i właściwy typ MIME.
http.MultipartFile imageMultipartFile(
  String field,
  Uint8List bytes,
  String filename, {
  required String fallbackName,
}) {
  final name = normalizeImageFilename(filename, fallback: fallbackName);
  return http.MultipartFile.fromBytes(
    field,
    bytes,
    filename: name,
    contentType: imageMediaType(name),
  );
}
