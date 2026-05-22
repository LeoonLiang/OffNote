# OffNote

OffNote is an offline-first Flutter app for saving Xiaohongshu notes and web
articles locally. It can receive shared text on Android, detect Xiaohongshu
links from the clipboard, render the page in a WebView, extract the note
snapshot, download media, and save a local HTML copy for offline reading.

## Current Features

- Save Xiaohongshu share links and web URLs.
- Receive Android `text/plain` shares from the system share sheet.
- Detect Xiaohongshu links from the clipboard when the app resumes.
- Save note title, content, author, images, posters, and videos when available.
- Browse saved articles, assign categories, and search title/content locally.
- Store article metadata in SQLite and article media/HTML in app documents.

## Development

Install dependencies:

```sh
flutter pub get
```

Run static analysis:

```sh
flutter analyze
```

Run tests:

```sh
flutter test
```

Build an Android debug APK:

```sh
flutter build apk --debug
```

## Notes

- iOS Share Extension support is not implemented yet.
- Search uses SQLite FTS with a short-query fallback so Chinese two-character
  searches still work.
- Offline media availability depends on whether the source page exposes
  downloadable image/video URLs at save time.
