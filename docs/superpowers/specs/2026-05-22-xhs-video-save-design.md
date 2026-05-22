# XHS Video Save Design

## Goal

Support 小红书 video notes in the existing save flow. When a shared XHS note is a video, OffNote stores the MP4, poster image, author, title, and body locally, then opens an offline page with a native video player.

## Design

Use the existing WebView snapshot flow. The WebView continues to load the shared URL and returns `document.documentElement.outerHTML`; the parser extends the current XHS initial-state extraction to recognize `note.video.media.stream`. Prefer H.264 MP4 streams for compatibility, fall back to H.265 if no H.264 stream exists, and choose the largest available stream within that codec family.

Keep image notes unchanged. The common `ArticleSnapshot` model gains optional `videoUrl` and `posterUrl` fields. `ArticleSnapshotStore` downloads image notes exactly as before; for video notes it downloads the video to `videos/video_0.mp4`, downloads the poster/cover into `images/poster.jpg`, and passes those local URIs into the offline HTML builder.

## Error Handling

If a video URL is present but download fails, saving should still produce a readable offline page with the poster and text when possible. If no media can be extracted, the parser returns `null` and the generic fallback remains available.

## Testing

Add parser tests for real XHS video initial-state shape, readiness tests for `stream`, offline HTML tests for `<video controls>`, and store-level tests where practical through existing pure functions.
