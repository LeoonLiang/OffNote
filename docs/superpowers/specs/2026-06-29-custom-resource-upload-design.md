# Custom Resource Upload Design

## Goal

Add a user-facing upload path in the existing resource library so users can add their own image and video files as reusable materials. Uploaded resources should behave like existing saved resources: searchable, taggable, previewable, deletable, and included in backup and restore.

## Scope

- Support manual image upload.
- Support manual video upload as a full video resource, not as a clipped segment.
- Store uploaded files under OffNote-managed `resources/<id>/` directories so resources remain available even if the original picked file moves or is deleted.
- Keep uploaded resources source-less by using an empty `articleId`.
- Reuse the existing resource library grid, filters, tag editor, image preview, video preview, delete flow, and backup path.

Out of scope for this pass:

- Video trimming during upload.
- Automatic video thumbnail extraction.
- Multi-select bulk upload.
- Editing resource title or note after upload.

## User Flow

The resource library app bar gains an upload action. Tapping it opens a small choice menu or sheet with:

- Upload image
- Upload video

After the user chooses a file, OffNote copies it into a new managed resource directory and creates a ready `SavedResource`. The default title comes from the picked file name without its extension. When the upload succeeds, the resource list refreshes and shows a confirmation. If the picker is cancelled, nothing changes. If copying or saving fails, the page shows a snack bar with the failure.

## Data Model

Use the existing `SavedResource` model and table.

Images:

- `type`: `image`
- `articleId`: empty string
- `sourcePath`: copied image path
- `previewPath`: copied image path
- `status`: `ready`

Videos:

- `type`: `video_clip`
- `articleId`: empty string
- `sourcePath`: copied video path
- `previewPath`: null
- `originalSourcePath`: copied video path or null; no retry behavior
- `status`: `ready`
- `start` / `end`: null

The existing `video_clip` type label can continue to read as video material in UI copy where needed. Failed or processing states remain reserved for generated clips.

## Storage

Add store-level helpers to copy uploaded files into the app documents directory:

- `resources/<id>/<safe-file-name>`

Deletion should continue removing the resource row and should delete the managed resource directory for uploaded images and videos. Deleting existing resources created from article images must not delete article-owned files.

## UI Changes

`ResourceLibraryPage` owns the upload action because the action only applies to this tab. The page calls store helpers, refreshes the first page, and invokes `onChanged`.

Video preview should hide the "open source" action when `articleId` is empty. Source opening should continue to work for video clips created from saved articles.

Empty-state copy can mention uploaded materials, for example "还没有收藏或上传的图片、视频".

## Error Handling

- Picker cancel: no feedback.
- Unsupported or inaccessible path: show a snack bar and leave the database unchanged.
- Copy failure: clean up the new resource directory when possible.
- Database insert failure: clean up the copied file directory when possible.

## Testing

Add focused tests for store/database behavior:

- Uploaded image resource is copied into `resources/<id>/`, has empty `articleId`, and uses the copied file as preview.
- Uploaded video resource is copied into `resources/<id>/`, is ready, has empty `articleId`, and has no clip range.
- Deleting an uploaded resource removes its managed resource directory.
- Deleting an article-owned image resource does not remove the article image directory.

Add widget coverage where practical for source-less video preview hiding the "open source" action.
