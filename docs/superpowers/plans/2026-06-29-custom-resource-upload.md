# Custom Resource Upload Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add image and video upload actions to the resource library, storing picked files as managed OffNote resources.

**Architecture:** Reuse `SavedResource` and the existing resource library UI. Add a small Dart picker wrapper around a native MethodChannel, store-level helpers that copy selected files into `resources/<id>/`, and UI actions on `ResourceLibraryPage`.

**Tech Stack:** Flutter/Dart, sqflite, MethodChannel, Android Kotlin `ACTION_OPEN_DOCUMENT`, iOS Swift `UIDocumentPickerViewController`, Flutter widget/unit tests.

---

### Task 1: Store Helpers For Uploaded Resources

**Files:**
- Modify: `lib/article_snapshot_store.dart`
- Modify: `lib/article_database.dart`
- Test: `test/article_snapshot_store_test.dart`

- [ ] **Step 1: Write failing store tests**

Add `test/article_snapshot_store_test.dart` with tests that construct `ArticleSnapshotStore` using a temporary sqflite database and a temporary documents directory, then assert:

```dart
test('imports image resources into a managed resource directory', () async {
  final source = File('${temp.path}/picked/photo one.jpg')
    ..createSync(recursive: true)
    ..writeAsStringSync('image-bytes');

  final resource = await store.importImageResource(source.path);

  expect(resource.type, SavedResourceType.image);
  expect(resource.articleId, '');
  expect(resource.title, 'photo one');
  expect(resource.previewPath, resource.sourcePath);
  expect(resource.sourcePath, isNot(source.path));
  expect(File(resource.sourcePath).readAsStringSync(), 'image-bytes');
  expect(p.basename(p.dirname(resource.sourcePath)), resource.id);
  expect(p.basename(p.dirname(p.dirname(resource.sourcePath))), 'resources');
});

test('imports video resources as ready source-less video materials', () async {
  final source = File('${temp.path}/picked/clip.mp4')
    ..createSync(recursive: true)
    ..writeAsStringSync('video-bytes');

  final resource = await store.importVideoResource(source.path);

  expect(resource.type, SavedResourceType.videoClip);
  expect(resource.articleId, '');
  expect(resource.status, SavedResourceStatus.ready);
  expect(resource.start, isNull);
  expect(resource.end, isNull);
  expect(resource.previewPath, isNull);
  expect(File(resource.sourcePath).readAsStringSync(), 'video-bytes');
});

test('deleting imported resources removes their managed directory only', () async {
  final uploaded = File('${temp.path}/picked/upload.png')
    ..createSync(recursive: true)
    ..writeAsStringSync('upload');
  final uploadedResource = await store.importImageResource(uploaded.path);
  final uploadedDir = Directory(p.dirname(uploadedResource.sourcePath));

  final articleImage = File('${docs.path}/articles/a1/images/image_0.jpg')
    ..createSync(recursive: true)
    ..writeAsStringSync('article');
  final articleResource = await store.createImageResource(
    articleId: 'a1',
    imagePath: articleImage.path,
    title: 'Article image',
  );

  await store.deleteResource(uploadedResource);
  await store.deleteResource(articleResource);

  expect(uploadedDir.existsSync(), isFalse);
  expect(articleImage.existsSync(), isTrue);
});
```

- [ ] **Step 2: Run tests and verify RED**

Run: `flutter test test/article_snapshot_store_test.dart`

Expected: FAIL because `importImageResource` and `importVideoResource` do not exist.

- [ ] **Step 3: Implement store/database helpers**

Add to `ArticleSnapshotStore`:

```dart
Future<SavedResource> importImageResource(String sourcePath) =>
    _importPickedResource(sourcePath, type: SavedResourceType.image);

Future<SavedResource> importVideoResource(String sourcePath) =>
    _importPickedResource(sourcePath, type: SavedResourceType.videoClip);
```

Add private helpers that create `resources/<id>/`, sanitize the picked filename, copy the file, insert the proper `SavedResource`, and clean up on failure.

Add `ArticleDatabase.createUploadedVideoResource(...)` or use `upsertResource` directly for a ready `videoClip` with empty `articleId`, null preview, and null clip range.

Update `ArticleSnapshotStore.deleteResource` so it deletes `resources/<id>/` only when the resource source path is inside the managed `resources` directory.

- [ ] **Step 4: Run tests and verify GREEN**

Run: `flutter test test/article_snapshot_store_test.dart`

Expected: PASS.

### Task 2: Native File Picker Wrapper

**Files:**
- Create: `lib/resource_file_picker.dart`
- Modify: `lib/main.dart`
- Modify: `android/app/src/main/kotlin/com/leoon/offnote/offnote/MainActivity.kt`
- Modify: `ios/Runner/AppDelegate.swift`
- Test: `test/resource_file_picker_test.dart`

- [ ] **Step 1: Write failing Dart picker tests**

Create `test/resource_file_picker_test.dart` with MethodChannel mock handlers:

```dart
test('pickImageResourceFile invokes native image picker', () async {
  final picker = ResourceFilePicker();
  String? method;
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(ResourceFilePicker.channel, (call) async {
    method = call.method;
    return '/tmp/image.png';
  });

  expect(await picker.pickImageResourceFilePath(), '/tmp/image.png');
  expect(method, 'pickImageResourceFile');
});

test('pickVideoResourceFile invokes native video picker', () async {
  final picker = ResourceFilePicker();
  String? method;
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(ResourceFilePicker.channel, (call) async {
    method = call.method;
    return '/tmp/video.mp4';
  });

  expect(await picker.pickVideoResourceFilePath(), '/tmp/video.mp4');
  expect(method, 'pickVideoResourceFile');
});
```

- [ ] **Step 2: Run tests and verify RED**

Run: `flutter test test/resource_file_picker_test.dart`

Expected: FAIL because `ResourceFilePicker` does not exist.

- [ ] **Step 3: Implement picker wrapper and native methods**

Add `ResourceFilePicker` with channel `offnote/resource_files` and methods:

```dart
Future<String?> pickImageResourceFilePath()
Future<String?> pickVideoResourceFilePath()
```

Add `part 'resource_file_picker.dart';` to `lib/main.dart` only if the UI needs it through main parts; otherwise import it where used.

Android:
- Add a pending result/request kind for resource picking.
- For images use `ACTION_OPEN_DOCUMENT` with `image/*`.
- For videos use `ACTION_OPEN_DOCUMENT` with `video/*`.
- Copy selected content URI into `cacheDir/resource-imports/` and return the cache file path.

iOS:
- Register `offnote/resource_files`.
- Present `UIDocumentPickerViewController` with image or movie UTTypes.
- Copy the selected security-scoped URL into `temporaryDirectory/resource-imports/` and return the copied path.

- [ ] **Step 4: Run tests and verify GREEN**

Run: `flutter test test/resource_file_picker_test.dart`

Expected: PASS.

### Task 3: Resource Library Upload UI

**Files:**
- Modify: `lib/pages/resource_library_page.dart`
- Modify: `lib/main.dart`
- Test: `test/resource_library_page_test.dart`

- [ ] **Step 1: Write failing widget tests for source-less video preview**

Create or extend `test/resource_library_page_test.dart` with a test that pumps `_ResourceVideoPreview` or a public wrapper in the same library context and asserts a source-less resource does not show tooltip `打开来源`, while a resource with an `articleId` does.

- [ ] **Step 2: Run test and verify RED**

Run: `flutter test test/resource_library_page_test.dart`

Expected: FAIL because `_ResourceVideoPreview` always renders the open-source action.

- [ ] **Step 3: Implement UI**

In `ResourceLibraryPage`:
- Add a `ResourceFilePicker` field.
- Add an upload `IconButton` to the app bar before shared actions.
- Show a bottom sheet with two actions: `上传图片`, `上传视频`.
- Pick the selected file, call `store.importImageResource` or `store.importVideoResource`, refresh the first page, call `onChanged`, and show success/failure snack bars.
- Update empty state text to mention upload.

In `_ResourceVideoPreview`:
- Change `onOpenSource` to nullable.
- Render the app bar source action only when `onOpenSource != null`.
- Pass `null` for resources with empty `articleId`.

- [ ] **Step 4: Run tests and verify GREEN**

Run: `flutter test test/resource_library_page_test.dart`

Expected: PASS.

### Task 4: Integration Verification

**Files:**
- Any files changed above

- [ ] **Step 1: Run targeted tests**

Run:

```bash
flutter test test/article_snapshot_store_test.dart test/resource_file_picker_test.dart test/resource_library_page_test.dart
```

Expected: PASS.

- [ ] **Step 2: Run full test suite**

Run:

```bash
flutter test
```

Expected: PASS.

- [ ] **Step 3: Run static analysis**

Run:

```bash
flutter analyze
```

Expected: No issues.

- [ ] **Step 4: Commit implementation**

Run:

```bash
git status --short
git add lib test android ios docs/superpowers/plans/2026-06-29-custom-resource-upload.md
git commit -m "feat: upload custom resources"
```

Expected: Commit succeeds with only planned files.
