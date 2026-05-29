# Video Markers Design

## Goal

Add learning notes tied to specific positions in saved video articles. A user can mark the current video time, write a short note about what is worth learning there, see all marks in order, and tap any mark to jump back to that point.

## User Experience

Video articles show a timeline entry button inside the video player, positioned above the left side of the video controls. Tapping it slides a marker list in from the right side of the video. The same entry point and side panel are available in normal playback and fullscreen playback.

The side panel contains a button for adding a marker at the current playback position. Choosing it opens a small note editor. Saved markers appear sorted by time, with a formatted timestamp and the note text. Tapping a marker seeks the player to that position and starts playback. Each marker can be edited or deleted from the panel.

Only video articles show this feature. Image articles keep their current detail experience.

## Architecture

`ArticleDatabase` owns persistence with a new `video_markers` table. A new `VideoMarker` model represents one marker with `id`, `articleId`, `position`, `note`, `createdAt`, and `updatedAt`.

`ArticleDetailPage` loads markers for the current article and passes them into `OffNoteVideoPlayer`. It also provides callbacks for create, update, and delete operations. The player stays responsible for playback state, current position, seeking, fullscreen rendering, the marker entry button, and the right-side marker panel. It does not talk directly to SQLite.

## Data Model

Add database version 10 and create `video_markers`:

- `id TEXT PRIMARY KEY`
- `article_id TEXT NOT NULL`
- `position_ms INTEGER NOT NULL`
- `note TEXT NOT NULL`
- `created_at INTEGER NOT NULL`
- `updated_at INTEGER NOT NULL`

Markers are queried by `article_id` and ordered by `position_ms ASC, created_at ASC`. Deleting an article is not currently part of the app flow, so marker cleanup is out of scope for this first version.

## Error Handling

Empty marker notes are allowed only while editing is open; saving trims whitespace and ignores blank notes. If a database operation fails, the detail page keeps the previous marker list and shows a snack bar. If a seek target is outside the known duration, the player clamps it to the valid range when possible.

## Testing

Add focused tests for:

- `VideoMarker` map serialization.
- Database create, list, update, delete, and sorted listing.
- Timestamp formatting helpers for seconds, minutes, and hour-length videos.
- Player helper behavior that clamps seek targets.

Widget tests for the full video player panel are optional in this first pass because `media_kit` player rendering is heavier than the business logic. Keep the UI implementation small and verify with existing Flutter tests plus targeted pure/unit tests.
