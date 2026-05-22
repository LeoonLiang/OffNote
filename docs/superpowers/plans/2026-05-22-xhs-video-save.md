# XHS Video Save Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Save XHS video notes as offline playable pages with local MP4, poster, author, title, and body.

**Architecture:** Extend the existing XHS parser and article snapshot model with optional video metadata. Reuse the current save flow and branch only at offline asset download/render time.

**Tech Stack:** Flutter, Dart, Dio, html parser, WebView snapshot HTML.

---

### Task 1: Video Parsing

**Files:**
- Modify: `lib/xhs_note_snapshot.dart`
- Modify: `lib/article_snapshot.dart`
- Test: `test/xhs_note_snapshot_test.dart`

- [ ] Add failing test that a note with `video.media.stream.h264[].masterUrl` returns `videoUrl`, `posterUrl`, and no required images.
- [ ] Run `flutter test test/xhs_note_snapshot_test.dart` and confirm the new test fails because video fields do not exist.
- [ ] Add optional video fields to `XhsNoteSnapshot` and `ArticleSnapshot`.
- [ ] Update `_findNoteMap` so video notes with `desc`, `user`, and `video` are recognized.
- [ ] Extract H.264 MP4 stream URL, falling back to H.265, and normalize it with existing URL normalization.
- [ ] Extract poster URL from rendered poster image, `cover.fileId`-derived rendered HTML, or existing image fields when available.
- [ ] Run `flutter test test/xhs_note_snapshot_test.dart` and confirm it passes.

### Task 2: Readiness Probe

**Files:**
- Modify: `lib/snapshot_readiness.dart`
- Test: `test/snapshot_readiness_test.dart`

- [ ] Add failing test that the readiness script checks for XHS video stream data or rendered video poster.
- [ ] Run `flutter test test/snapshot_readiness_test.dart` and confirm failure.
- [ ] Update the JavaScript probe to accept initial state containing `"stream"` and `"desc"`, and rendered `.video-container` poster/content.
- [ ] Run `flutter test test/snapshot_readiness_test.dart`.

### Task 3: Offline Video HTML

**Files:**
- Modify: `lib/xhs_offline_html.dart`
- Test: `test/xhs_offline_html_test.dart`

- [ ] Add failing test that passing `localVideoUri` and `localPosterUri` emits `<video controls>` with poster and source.
- [ ] Run `flutter test test/xhs_offline_html_test.dart` and confirm failure.
- [ ] Add optional video parameters to `buildXhsOfflineHtml`; render video for video notes, image carousel for image notes.
- [ ] Run `flutter test test/xhs_offline_html_test.dart`.

### Task 4: Asset Download and Save

**Files:**
- Modify: `lib/article_snapshot_store.dart`

- [ ] Add video download helper using Dio with the same mobile user agent and referrer headers.
- [ ] Save videos under `videos/video_0.mp4`.
- [ ] Download poster to `images/poster.jpg` when available.
- [ ] Pass local video/poster URIs into `buildXhsOfflineHtml`.
- [ ] Keep image note download and cover behavior unchanged.

### Task 5: Verification

**Files:**
- Test suite only

- [ ] Run `flutter test`.
- [ ] Run `flutter analyze`.
- [ ] Manually save the provided XHS video link in the app if a simulator/device is available.
