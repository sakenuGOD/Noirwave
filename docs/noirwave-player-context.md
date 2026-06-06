# Noirwave Player Context

Active repo: `/Users/fsociety/Developer/Noirwave`.

Do not work in `/Users/fsociety/Noirwave` right now: that copy is detached and has unmerged files.

## Current Product Direction

- Reference class: Apple Music / Spotify desktop player, with Spotube used only for feature ideas.
- Visual direction: native dark music app, compact hierarchy, liquid-glass mini player, no generic SaaS UI.
- Brand accent: `NoirwaveTheme.primaryAccent` mint is locked for controls, active states, sliders, playlist actions, and panel toggles.
- Artwork palettes may still tint backgrounds, shadows, and fallback covers, but they must not replace the system mint controls.

## Current Work Items

- Search should live in the left sidebar mini bar. No global top search field.
- Sidebar playlist preview should show five collections, then a manual expand/collapse control.
- Playlist creation should not duplicate identical playlist names forever. Same-title playlist creation merges tracks.
- Lyrics and queue must open inline on the right side of the main content, not as a modal/sheet over the UI.
- Synchronized lyrics lines should be clickable and seek to the matching track timestamp.
- Mini player should read as liquid glass and remain visually stable after UI interactions.
- Catalog requests should stop returning preview-sized results: search, artist pages, and albums should request the full available catalog surface where the provider supports it.
- Search now treats `nb` as an expanded result target up to 500 while Deezer public fallback keeps each page at 100 and follows pagination.
- Artist pages should not cap songs at 12. Albums should load the full tracklist, and singles/EPs must not be presented as broken studio albums.

## Verification Targets

- Backend tests under `NoirwaveBackend/tests`.
- Swift/Xcode tests under `NoirwaveTests`.
- Before commit/push: run relevant backend tests, Swift tests/build if available, inspect `git diff --stat`, then commit and push from `main`.
