import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' show getDatabasesPath;

/// Obrazek z sieci, który zostaje na dysku — miniatury ćwiczeń i awatary
/// widać także bez internetu. Na webie cache'uje przeglądarka, więc tam to
/// zwykły [NetworkImage].
ImageProvider offlineNetworkImage(String url) =>
    kIsWeb ? NetworkImage(url) : OfflineNetworkImage(url);

@immutable
class OfflineNetworkImage extends ImageProvider<OfflineNetworkImage> {
  const OfflineNetworkImage(this.url, {this.scale = 1.0});

  final String url;
  final double scale;

  @override
  Future<OfflineNetworkImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<OfflineNetworkImage>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    OfflineNetworkImage key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _loadCodec(key, decode),
      scale: key.scale,
      debugLabel: key.url,
    );
  }

  static Future<ui.Codec> _loadCodec(
    OfflineNetworkImage key,
    ImageDecoderCallback decode,
  ) async {
    try {
      final bytes = await OfflineImageStore.instance.load(key.url);
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      // `await` — błąd dekodowania też ma trafić do catch poniżej.
      return await decode(buffer);
    } catch (_) {
      // Jak NetworkImage: nieudany obrazek nie może utknąć w ImageCache —
      // po powrocie internetu ma się dać wczytać ponownie.
      scheduleMicrotask(() {
        PaintingBinding.instance.imageCache.evict(key);
      });
      rethrow;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is OfflineNetworkImage && other.url == url && other.scale == scale;

  @override
  int get hashCode => Object.hash(url, scale);

  @override
  String toString() => 'OfflineNetworkImage("$url", scale: $scale)';
}

/// Pliki obrazków w katalogu aplikacji. Najpierw dysk, potem sieć; plik
/// starszy niż [_refreshAfter] odświeżamy w tle.
class OfflineImageStore {
  OfflineImageStore._();

  static final instance = OfflineImageStore._();

  static const _maxFiles = 300;
  static const _timeout = Duration(seconds: 20);
  static const _refreshAfter = Duration(days: 7);

  final Map<String, Future<Uint8List>> _inFlight = {};
  Future<Directory>? _directory;
  http.Client? _client;

  Future<Uint8List> load(String url) {
    return _inFlight[url] ??= _load(url).whenComplete(() {
      _inFlight.remove(url);
    });
  }

  Future<Uint8List> _load(String url) async {
    final file = await _fileFor(url);
    if (file != null) {
      try {
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          if (bytes.isNotEmpty) {
            final age = DateTime.now().difference(await file.lastModified());
            if (age > _refreshAfter) {
              unawaited(_download(url, file).then((_) {}, onError: (_) {}));
            }
            return bytes;
          }
        }
      } catch (_) {
        /* uszkodzony plik — pobierz od nowa */
      }
    }
    return _download(url, file);
  }

  Future<Uint8List> _download(String url, File? file) async {
    final uri = Uri.parse(url);
    final response = await (_client ??= http.Client())
        .get(uri)
        .timeout(_timeout);
    if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
      throw NetworkImageLoadException(
        statusCode: response.statusCode,
        uri: uri,
      );
    }
    if (file != null) unawaited(_write(file, response.bodyBytes));
    return response.bodyBytes;
  }

  Future<void> _write(File file, Uint8List bytes) async {
    try {
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsBytes(bytes, flush: true);
      await tmp.rename(file.path);
      await _prune(file.parent);
    } catch (_) {
      /* cache jest opcjonalny */
    }
  }

  Future<void> _prune(Directory directory) async {
    final files = await directory
        .list()
        .where((entry) => entry is File && !entry.path.endsWith('.tmp'))
        .cast<File>()
        .toList();
    if (files.length <= _maxFiles) return;
    final stamped = <(File, DateTime)>[
      for (final file in files) (file, await file.lastModified()),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    for (final (file, _) in stamped.take(files.length - _maxFiles)) {
      await file.delete();
    }
  }

  Future<File?> _fileFor(String url) async {
    try {
      final directory = await (_directory ??= _openDirectory());
      return File(p.join(directory.path, _fileName(url)));
    } catch (_) {
      _directory = null;
      return null;
    }
  }

  Future<Directory> _openDirectory() async {
    final base = await getDatabasesPath();
    final directory = Directory(p.join(base, 'image_cache'));
    await directory.create(recursive: true);
    return directory;
  }

  /// Stabilna nazwa pliku z adresu (dwa 32-bitowe FNV-1a + długość).
  static String _fileName(String url) {
    var a = 0x811c9dc5;
    var b = 0x050c5d1f;
    for (final unit in url.codeUnits) {
      a = ((a ^ unit) * 0x01000193) & 0xFFFFFFFF;
      b = ((b ^ unit) * 0x01000193) & 0xFFFFFFFF;
    }
    final hashA = a.toRadixString(16).padLeft(8, '0');
    final hashB = b.toRadixString(16).padLeft(8, '0');
    return '$hashA${hashB}_${url.length}';
  }
}
