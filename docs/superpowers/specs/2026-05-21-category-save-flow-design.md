# Category Save Flow Design

## Goal

Rework OffNote around the design reference: a clean article list, folder-based category management, one-step link save flow, offline reading detail, and local search.

## User Flow

The home screen shows all saved articles. The center plus button opens a paste-link dialog. The user pastes a share text or URL, taps save, and the app performs parsing, page loading, extraction, image download, and local persistence in one flow with visible progress. When save succeeds, the app opens the article detail page.

The article detail page provides offline reading and lets the user assign the article to one folder category. Existing articles without a category remain uncategorized.

The category tab shows folders. Users can create, rename, and delete folders. Opening a folder shows articles assigned to it.

## Data Model

Add a `categories` table:

- `id`
- `name`
- `color`
- `created_at`

Extend `articles` with nullable `category_id`. Existing rows migrate with `category_id = null`.

## UI

Follow the visual direction in `design.png`: soft white surfaces, green accent, compact cards, bottom navigation, and the center floating plus action.

Screens:

- Home: article list, top filter/search controls, bottom navigation.
- Save dialog: paste field and progress checklist.
- Categories: folder list, create/rename/delete actions.
- Detail: offline WebView plus category picker.
- Search: searchable article list using existing title/content search.

## Scope

This version implements folder categories only. Tags and multi-category assignment are out of scope.

## Verification

Add focused tests for category persistence, article category assignment, and link parsing/save-flow helpers where practical. Run `flutter test`, `flutter analyze`, and `flutter build apk --debug`.
