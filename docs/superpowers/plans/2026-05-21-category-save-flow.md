# Category Save Flow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the design-driven save dialog, folder categories, category assignment, and redesigned navigation for OffNote.

**Architecture:** Extend the SQLite schema with categories and nullable article category assignment. Keep extraction/snapshot storage in `ArticleSnapshotStore`, and move UI toward small screens/widgets in `main.dart` while preserving the existing app shell.

**Tech Stack:** Flutter, Material 3, WebView, sqflite, Dio, html parser.

---

### Task 1: Category Data Model

**Files:**
- Create: `lib/category.dart`
- Modify: `lib/article_database.dart`
- Modify: `lib/saved_article.dart`
- Test: `test/article_database_test.dart`

- [ ] Add `SavedCategory` model with `id`, `name`, `color`, `createdAt`.
- [ ] Add SQLite `categories` table and migrate `articles.category_id`.
- [ ] Add database APIs: list/create/rename/delete categories, assign article category.
- [ ] Add tests using an in-memory database-friendly constructor.

### Task 2: Save Dialog Flow

**Files:**
- Modify: `lib/article_snapshot_store.dart`
- Modify: `lib/main.dart`
- Test: existing parser and snapshot tests

- [ ] Replace the current paste/load/save panel with a floating plus button.
- [ ] Add dialog text field for pasted share text.
- [ ] On submit: parse URL, load hidden/in-dialog WebView, extract HTML, save snapshot.
- [ ] Show progress messages for parse, load, extract, image download, saved.
- [ ] Open `ArticleDetailPage` after save succeeds.

### Task 3: Category UI

**Files:**
- Modify: `lib/main.dart`

- [ ] Add bottom nav tabs matching design: Home, Categories, Search, Mine placeholder.
- [ ] Add `CategoryPage` folder list with create, rename, delete.
- [ ] Add category-filtered article list when opening a folder.
- [ ] Add category picker action in article detail.

### Task 4: Design Polish

**Files:**
- Modify: `lib/main.dart`

- [ ] Update colors, list cards, folder rows, bottom nav, and dialogs to match `design.png`.
- [ ] Keep cards compact and readable; no marketing hero or nested cards.

### Task 5: Verification

**Commands:**
- `dart format lib test`
- `flutter test`
- `flutter analyze`
- `flutter build apk --debug`
- `flutter run -d afe039ce` when Android device is online

---

Self-review: This plan covers the confirmed folder-only category scope, the plus-dialog one-step save flow, post-save detail opening, detail category assignment, category management, and design polish. Tags and multi-category assignment are intentionally out of scope.
