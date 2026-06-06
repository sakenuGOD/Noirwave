# Noirwave Player Context

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

## Design Read

Native dark music app for focused listening. Visual language: Apple Music-style restrained chrome, Spotify-style practical queue/search behavior, fixed Noirwave mint accent, track artwork used as supporting atmosphere only.

## Reference Notes

- Apple Music user guide highlights search by song, artist, album, or lyrics; queue; time-synced lyrics; mini player; favorites; playlists and folders.
- Spotube release notes point to queue add/remove, official synced lyrics, lyric zoom/timing controls, compact collection search, and fixes around search/queue responsiveness.
- Apply the behavior ideas, not the visual skin. Noirwave should feel like its own native macOS player.

## Implementation Notes

- Keep `NoirwaveTheme.accent` as the UI control accent. Track palette can influence artwork/background only.
- Treat `UtilityPanelMode.lyrics` and `.queue` as an inline right-column state.
- Keep backend and Swift request-size constants named, not scattered magic numbers.
- If compaction happens, resume by checking `git status --short --branch`, this file, and the changed files listed in the latest diff.
