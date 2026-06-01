import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:media_kit/media_kit.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'app_update.dart';
import 'article_database.dart';
import 'article_filter_panel.dart';
import 'article_snapshot_store.dart';
import 'article_capture_service.dart';
import 'article_display.dart';
import 'article_detail_result.dart';
import 'article_storage_stats.dart';
import 'app_update_dialog.dart';
import 'gallery.dart';
import 'link_parser.dart';
import 'offnote_backup_service.dart';
import 'offnote_link_share.dart';
import 'offnote_video_player.dart';
import 'save_queue.dart';
import 'save_failure_message.dart';
import 'saved_article.dart';
import 'saved_category.dart';
import 'saved_tag.dart';
import 'selection.dart';
import 'tag_editor_sheet.dart';
import 'video_marker.dart';

part 'theme.dart';
part 'pages/home_page.dart';
part 'save_article_dialog.dart';
part 'pages/article_list_page.dart';
part 'pages/gallery_page.dart';
part 'pages/altitude_page.dart';
part 'pages/category_page.dart';
part 'pages/article_detail_page.dart';
part 'pages/storage_stats_page.dart';
part 'pages/save_queue_page.dart';
part 'pages/settings_page.dart';
part 'pages/tag_manager_page.dart';
part 'widgets/article_tile.dart';
part 'widgets/category_tile.dart';
part 'widgets/nav_item.dart';
part 'widgets/empty_states.dart';
part 'date_label.dart';

void main() {
  MediaKit.ensureInitialized();
  runApp(const OffNoteApp());
}

class OffNoteApp extends StatelessWidget {
  const OffNoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ShadApp(
      title: '离线笔记',
      debugShowCheckedModeBanner: false,
      theme: ShadThemeData(
        brightness: Brightness.light,
        colorScheme: const ShadZincColorScheme.light(
          background: _paper,
          foreground: _ink,
          card: Colors.white,
          cardForeground: _ink,
          popover: Colors.white,
          popoverForeground: _ink,
          primary: _accent,
          primaryForeground: Colors.white,
          secondary: Color(0xffeef1e8),
          secondaryForeground: _ink,
          muted: Color(0xffeef1e8),
          mutedForeground: _muted,
          accent: _accentSoft,
          accentForeground: _ink,
          border: Color(0xffdedfd7),
          input: Color(0xffdedfd7),
          ring: _accent,
        ),
      ),
      materialThemeBuilder: (context, theme) => theme.copyWith(
        scaffoldBackgroundColor: _paper,
        appBarTheme: const AppBarTheme(
          backgroundColor: _paper,
          foregroundColor: _ink,
          centerTitle: true,
          elevation: 0,
        ),
      ),
      home: const HomePage(),
    );
  }
}
