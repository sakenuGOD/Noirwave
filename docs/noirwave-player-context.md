# Noirwave Player Context

Active repo: `/Users/fsociety/Noirwave`.

## Current Product Direction

- Reference class: Apple Music / Spotify desktop player, with Spotube used only for feature ideas.
- Visual direction: native dark music app, compact hierarchy, liquid-glass mini player, no generic SaaS UI.
- Brand accent: `NoirwaveTheme.primaryAccent` mint is locked for controls, active states, sliders, playlist actions, and panel toggles.
- Artwork palettes may tint backgrounds, shadows, and fallback covers, but they must not replace the system mint controls.

## Current Goal

Bring Noirwave closer to Apple Music / Spotify player behavior while keeping the UI native, minimal, and stable:

- Search lives only in the left sidebar search field.
- Sidebar navigation must keep working after search text is entered.
- Lyrics and queue open inline as a right utility column, not as a modal or overlay that blocks the player.
- Synchronized lyrics lines are clickable and seek playback to the line timestamp.
- Bottom mini-player should be Liquid Glass system chrome with stable Noirwave mint accent.
- Search, artist drill-down, and album drill-down should request full available result sets instead of old preview-sized lists.
- Album cards must not make singles/EPs look like broken studio albums.
- Playlist-like lists should be capped in the visible UI and expand intentionally, never grow as endless sidebar clutter.

## Current Work Items

- Sidebar playlist preview should show five collections, then a manual expand/collapse control.
- Playlist creation should not duplicate identical playlist names forever. Same-title playlist creation merges tracks.
- Catalog requests should stop returning preview-sized results: search, artist pages, and albums should request the full available catalog surface where the provider supports it.
- Search treats `nb` as an expanded result target up to 500 while Deezer public fallback keeps each page at 100 and follows pagination.
- Artist pages should not cap songs at 12. Albums should load the full tracklist, and singles/EPs must not be presented as broken studio albums.
- MCP exposes the local library through resources/tools and must keep destructive operations behind confirmation.

## Design Read

Native dark music app for focused listening. Visual language: Apple Music-style restrained chrome, Spotify-style practical queue/search behavior, fixed Noirwave mint accent, track artwork used as supporting atmosphere only.

## Reference Notes

- Apple Music user guide highlights search by song, artist, album, or lyrics; queue; time-synced lyrics; mini player; favorites; playlists and folders.
- Spotube release notes point to queue add/remove, official synced lyrics, lyric zoom/timing controls, compact collection search, and fixes around search/queue responsiveness.
- Apply the behavior ideas, not the visual skin. Noirwave should feel like its own native macOS player.

## Implementation Notes

- Keep `NoirwaveTheme.primaryAccent` as the UI control accent. Track palette can influence artwork/background only.
- Treat lyrics and queue as inline right-column state.
- Keep backend and Swift request-size constants named, not scattered magic numbers.
- If compaction happens, resume by checking `git status --short --branch`, this file, and the changed files listed in the latest diff.

## Verification Targets

- Backend tests under `NoirwaveBackend/tests`.
- Swift/Xcode tests under `NoirwaveTests`.
- Before commit/push: run relevant backend tests, Swift tests/build if available, inspect `git diff --stat`, then commit and push from `main`.
