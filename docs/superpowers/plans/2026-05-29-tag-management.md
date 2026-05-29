# Tag Management Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a settings-page tag manager where users can rename and delete tags.

**Architecture:** Keep tag persistence in the existing `ArticleDatabase` and `ArticleSnapshotStore` APIs. Add a `TagManagerPage` in the existing `main.dart` part structure, and add a settings entry that opens it. When tags are renamed or deleted, refresh calling pages through the existing `onChanged` callback.

**Tech Stack:** Flutter/Dart, sqflite, existing Material/Shad UI, `flutter_test`.

---

### Task 1: Tag Rename Coverage

**Files:**
- Modify: `test/article_database_test.dart`

- [ ] Add a failing test that creates a tag, renames it through `renameTag`, and verifies `listTags` returns the new name.
- [ ] Run `flutter test test/article_database_test.dart` and verify it passes or fails for the expected reason.

### Task 2: Tag Manager UI

**Files:**
- Create: `lib/pages/tag_manager_page.dart`
- Modify: `lib/main.dart`
- Modify: `lib/pages/settings_page.dart`
- Test: `test/tag_manager_page_test.dart`

- [ ] Add a failing widget test that expects `TagManagerPage` to list tags, rename a tag, and confirm before deleting one.
- [ ] Implement `TagManagerPage` using `ArticleSnapshotStore.listTags`, `renameTag`, and `deleteTag`.
- [ ] Add a `标签管理` settings tile that opens `TagManagerPage`.
- [ ] Run the focused widget test.

### Task 3: Verification

- [ ] Run `flutter test`.
- [ ] Run `flutter analyze`.
