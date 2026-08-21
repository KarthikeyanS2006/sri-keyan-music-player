import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class WidgetHelper {
  static const _prefKeyTitle = 'widget_title';
  static const _prefKeyArtist = 'widget_artist';
  static const _prefKeyIsPlaying = 'widget_is_playing';
  static const _prefKeyArtUri = 'widget_art_uri';

  static Future<void> updateWidget({
    required String title,
    required String artist,
    required bool isPlaying,
    String? imageUrl,
  }) async {
    if (kIsWeb) return;

    try {
      String? localArtUri;
      if (imageUrl != null && imageUrl.isNotEmpty) {
        localArtUri = await _downloadAndCacheImage(imageUrl);
      }

      await HomeWidget.saveWidgetData(_prefKeyTitle, title);
      await HomeWidget.saveWidgetData(_prefKeyArtist, artist);
      await HomeWidget.saveWidgetData(_prefKeyIsPlaying, isPlaying.toString());
      if (localArtUri != null) {
        await HomeWidget.saveWidgetData(_prefKeyArtUri, localArtUri);
      }

      await HomeWidget.updateWidget(
        name: 'MusicWidgetProvider',
        androidName: 'MusicWidgetProvider',
      );
    } catch (e) {
      debugPrint('Widget update error: $e');
    }
  }

  static Future<String?> _downloadAndCacheImage(String imageUrl) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/widget_album_art.jpg');
      if (!await file.exists()) {
        final response = await http.get(Uri.parse(imageUrl));
        if (response.statusCode == 200) {
          await file.writeAsBytes(response.bodyBytes);
        } else {
          return null;
        }
      }
      return file.path;
    } catch (e) {
      debugPrint('Widget image cache error: $e');
      return null;
    }
  }

  static void registerInteractedCallback() {
    if (kIsWeb) return;

    HomeWidget.widgetClicked.listen((Uri? uri) {
      debugPrint('Widget tapped: $uri');
    });
  }
}
