import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import 'article_snapshot_store.dart';
import 'js_result_decoder.dart';
import 'link_parser.dart';
import 'save_failure_message.dart';
import 'saved_article.dart';
import 'saved_category.dart';
import 'snapshot_readiness.dart';
import 'web_navigation_policy.dart';

part 'theme.dart';
part 'pages/home_page.dart';
part 'save_article_dialog.dart';
part 'pages/article_list_page.dart';
part 'pages/category_page.dart';
part 'pages/article_detail_page.dart';
part 'widgets/article_tile.dart';
part 'widgets/category_tile.dart';
part 'widgets/nav_item.dart';
part 'widgets/empty_states.dart';
part 'date_label.dart';

void main() {
  runApp(const OffNoteApp());
}

class OffNoteApp extends StatelessWidget {
  const OffNoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ShadApp(
      title: 'OffNote',
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
