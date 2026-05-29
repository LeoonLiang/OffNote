# Tag System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a multi-tag system for saved articles with filtering, batch editing, detail editing, and backup restore support.

**Architecture:** Tags live beside categories as a separate many-to-many relation, keeping the existing single category field intact. The database owns tag persistence and AND-style tag filtering; `ArticleSnapshotStore` exposes thin wrappers; UI pages load tag metadata and pass selected tag ids through the existing filter panel pattern.

**Tech Stack:** Flutter/Dart, sqflite, existing ShadCN UI components, `flutter_test`.

---

### Task 1: Database And Backup

**Files:**
- Create: `lib/saved_tag.dart`
- Modify: `lib/article_database.dart`
- Modify: `lib/offnote_backup_service.dart`
- Test: `test/article_database_test.dart`
- Test: `test/offnote_backup_service_test.dart`

- [ ] Write failing tests for tag CRUD, assigning multiple tags, AND filtering, relation cleanup, and backup import/export.
- [ ] Run `flutter test test/article_database_test.dart test/offnote_backup_service_test.dart` and verify the tests fail because tag APIs do not exist.
- [ ] Implement `SavedTag`, schema version 9, `tags` and `article_tags`, query filters, and backup manifest fields.
- [ ] Re-run the two test files and verify they pass.

### Task 2: Store And Filter Panel

**Files:**
- Modify: `lib/article_snapshot_store.dart`
- Modify: `lib/article_filter_panel.dart`
- Modify: `lib/main.dart`

- [ ] Add store wrappers for tag CRUD, article tag lookup, and batch add/remove operations.
- [ ] Extend `ArticleFilterSettings` with `tagIds` and render a multi-select `标签` section in `ArticleFilterPanel`.
- [ ] Import `SavedTag` at the app entry point.

### Task 3: List, Gallery, And Detail UI

**Files:**
- Modify: `lib/pages/article_list_page.dart`
- Modify: `lib/pages/gallery_page.dart`
- Modify: `lib/pages/article_detail_page.dart`
- Modify: `lib/widgets/article_tile.dart`

- [ ] Load tags together with categories in list and gallery pages.
- [ ] Pass selected tag ids into list/gallery queries and show tag summary text.
- [ ] Show up to two tag chips on article tiles.
- [ ] Add detail-page tag editor with multi-select and quick creation.
- [ ] Add batch add/remove tag actions for selected articles.

### Task 4: Verification

- [ ] Run focused tests for database and backup.
- [ ] Run `flutter test`.
- [ ] Run `flutter analyze`.
