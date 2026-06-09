# Changelog

## 2026-06-07

### Changed

- Prevented featured/catalog loading from auto-selecting the first track as now playing. Loading seed/catalog data no longer fabricates `currentTrack`, queue, playback progress, or lyrics state before the user starts playback.
- Restored the Swift search/cache test double needed for the current regression tests to compile.
- Added explicit skeleton loading surfaces for `Listen Now` and `Catalog` while featured catalog data is pending.
- Removed hardcoded Deezer startup seed searches. The initial catalog now stays empty/clean until real data is available, and radio recommendations no longer fall back to generic seed queries without an explicit track.
- Removed the hidden 100-item cap from backend public artist-detail pagination. The backend now follows Deezer `next` links for artist top tracks and albums until upstream data ends or the named page-count guard is reached.
- Clarified artist popular-track subtitle copy so a 100-item Deezer top-track window is not presented as a generic full artist track total.
- Scoped catalog search results to the Catalog destination. Sidebar search still owns the query, but Library/Listen Now/Profile can render while a query remains in the sidebar field.
- Fixed repeated activation of the current search result so it toggles play/pause instead of replaying the provider, and added coverage for search-result queue context.
- Scoped catalog artist/album detail screens and the Back button to the Catalog destination, so other navigation targets are not blocked after opening a search result.
- Back from catalog detail now cancels the active detail load and stale detail responses are ignored if that context is no longer active.
- Reworked Library around real user data: Liked Songs is now a prominent top block with adaptive favorite-track rows, local playlists are separated into "Мои плейлисты", and saved collections sit below.
- Added a create-playlist tile to the Library playlist shelf and removed the synthetic Liked Songs playlist item from that shelf.
- Made synchronized lyrics lines clickable so they seek the shared player to the line timestamp, and added explicit unsynced lyrics rendering for plain text lyrics.
- Split absolute-time seeking from fraction-based progress seeking so lyric clicks and sliders no longer fight over the same ambiguous API.
- Lightened the mini player glass treatment, raised inactive control contrast, strengthened the primary play/pause button, and thickened the progress rail with locked visual tokens.
- Brought sidebar navigation, search, and playlist rows back to the controlled app palette with `SidebarVisualStyle` tokens, accent-led focus, and native glass active/hover states.
- Pinned sidebar playlist-row accent color to the app accent so rows no longer drift based on the current track or collection artwork palette.
- Rebuilt the bottom sidebar Playlists block around real local playlists only. It no longer synthesizes Liked Songs, discovery mixes, top albums, or top artists into the playlist list.
- Added a compact create-playlist action and empty state to the sidebar playlist block instead of placeholder rows.
- Ran the Phase 11 mandatory regression checklist across loading, 100-track handling, single search, search playback/navigation, Library, lyrics, mini player, sidebar, and sidebar playlists.
- Completed the Phase 12 mandatory docs audit and added an explicit requirement-to-documentation coverage map.
- Completed the Phase 13 no-fake-completion audit; durable docs continue to show phases 14-18 as remaining and the pre-existing unmerged repo state as unresolved.
- Completed Phase 14 search input UX: remote catalog search now waits for a 300ms debounce, cancels superseded requests, ignores stale responses, serves repeated normalized queries from an in-memory cache, resets empty queries immediately, and keeps loading feedback local to the sidebar/results area instead of replacing the whole search surface.
- Completed Phase 15 artist header density: the artist hero now uses `ArtistHeaderLayoutMetrics`, with a shorter header, smaller foreground/background artwork, tighter title/action sizing, reduced section spacing, and a more compact latest-release row so latest release and the start of popular tracks can appear in the first 900px desktop viewport.
- Completed Phase 16 popular-track density: artist popular tracks now render through `ArtistPopularTracksSection`, show the top 5 rows by default, keep the Deezer top-track total in the subtitle, and provide Show more / Show less expand-collapse behavior for the full received list.
- Completed Phase 17 subtask 1: backend track search responses no longer await startup prefetch before returning payloads. Search now caches returned media metadata and schedules priority background startup prefetch, reducing search result latency under slow playback-cache/network conditions.
- Completed Phase 17 subtask 2: lyrics now use an in-memory `PlayerStore` cache by track ID, so replaying a track applies loaded lyrics immediately instead of flashing `.loading` and calling the provider again.
- Completed Phase 17 subtask 3: artist/album catalog detail results now use an in-memory `PlayerStore` cache by kind/catalog ID, so repeated drill-in renders the loaded detail immediately without a provider round trip or loading state.
- Completed Phase 17 subtask 4 acceptance audit: source scans and focused suites confirm the implemented search/detail/lyrics/popular-track performance guards, but Phase 17 remains open pending explicit native slow-network verification or a documented equivalent.
- Completed Phase 17 subtask 5: added native synthetic slow-network coverage for the macOS SwiftUI app. A 3.5s delayed provider search now verifies local query updates, previous results retention, stable current playback, usable player controls, and delayed result application.
- Completed Phase 18 root-cause performance investigation: documented the true wait-on-network causes, blocking components, unnecessary/sequential requests, loading-wall removal, cache/stale-response guards, native slow-network verification, and remaining potentially heavy areas.
- Preserved the existing bottom mini player visual structure and upgraded its interactive behavior only.
- Redesigned the left sidebar as a compact premium native glass navigation surface.
- Moved Lyrics, Queue, and Sound into a floating right-side glass widget with inset top, right, and bottom spacing.
- Replaced the right-panel segmented control with compact native-style tabs.
- Unified the search flow around the sidebar search field and changed the empty search destination copy to a passive Catalog landing view.
- Rebuilt the artist profile surface with a media-led hero, stats, Play, Shuffle, Follow, latest release, popular tracks, and album sections.
- Made mini-player artwork/title/artist clickable, with album and artist navigation targets.
- Removed the 12-track popular-track truncation path and replaced hidden request windows with named catalog request limits.
- Replaced card artwork loading with the unified `ArtworkImagePipeline`.
- Added backend and Swift regression coverage for artist popular tracks not being truncated.

### Files Touched

- `Noirwave/Views/PlayerShellView.swift`
- `Noirwave/Core/ArtworkImagePipeline.swift`
- `Noirwave/Core/Track.swift`
- `Noirwave/Core/DeemixAPIProvider.swift`
- `NoirwaveTests/DeemixAPITrackMapperTests.swift`
- `README.md`
- `NoirwaveBackend/src/publicDeezerSearch.mjs`
- `NoirwaveBackend/src/server.mjs`
- `NoirwaveBackend/src/searchResponsePrefetch.mjs`
- `NoirwaveBackend/tests/publicDeezerSearch.test.mjs`
- `NoirwaveBackend/tests/searchResponsePrefetch.test.mjs`
- `docs/CHANGELOG.md`
- `docs/IMPLEMENTATION_NOTES.md`
- `docs/BUGS_AND_REGRESSIONS.md`
- `docs/DESIGN_NOTES.md`
- `docs/STABILIZATION_PROGRESS.md`
- `docs/HANDOFF.md`

### Validation

- `npm test` in `NoirwaveBackend`: 36 tests passed.
- `xcodebuild -project Noirwave.xcodeproj -scheme Noirwave -destination 'platform=macOS' test`: 73 tests passed.
- Focused Phase 5 search/navigation regression slice: 9 tests passed.
- Focused Phase 6 Library/playlist regression slice: 19 tests passed.
- Focused Phase 7 lyrics regression slice: 4 tests passed.
- Focused Phase 8 mini player visual-token regression: 1 test passed.
- Focused Phase 9 sidebar visual-token regression: 1 test passed.
- Combined Phase 7/8/9 focused slice: 6 tests passed.
- Focused Phase 10 sidebar-playlist regression: 1 test passed.
- Focused Phase 10 playlist/sidebar regression slice: 4 tests passed.
- Phase 11 focused Swift regression checklist: 20 tests passed.
- Phase 11 backend regression checklist: 37 tests passed.
- Phase 11 source scans found no hardcoded Nirvana/Daft Punk/fake app content, no synthetic sidebar playlist rows, no old public artist 100-item cap, and no task-scope conflict markers.
- Phase 12 docs audit: `git diff --check -- docs` passed before the final documentation mapping update.
- Phase 13 no-fake-completion audit: docs scan found no premature claim that all 18 phases were complete at that checkpoint; progress and handoff then kept phases 14-18 open.
- Phase 14 focused search/navigation slice: 9 tests passed, covering debounce/cache, cancellation stale-error safety, search routing, search playback, catalog detail routing, album drill-in, and query update recovery.
- Phase 14 source checks: `git diff --check` passed for touched Swift/docs files; conflict-marker scan found no markers in touched task files; source scan confirmed the 300ms debounce/cache path and no old full-panel `CatalogLoadingView(title: "Searching")` path.
- Phase 15 focused artist header regression: `testArtistHeaderLayoutKeepsFirstViewportDense` passed after locking compact hero metrics.
- Phase 15 artist/catalog slice: 7 tests passed, covering artist header metrics, top-track copy, artist catalog composition/request windows, catalog detail routing, album drill-in, and query update recovery.
- Phase 15 source checks: `git diff --check` passed for touched Swift/docs files; conflict-marker scan found no markers in touched task files; source scan found no old oversized artist-hero literals.
- Phase 16 focused popular-tracks regression: `testArtistPopularTracksPresentationDefaultsToTopFiveAndCanExpand` passed after the presentation helper and UI section were added.
- Phase 16 artist/header/popular-tracks/catalog slice: 8 tests passed, covering top-5 collapse/expand, header metrics, top-track copy, artist catalog composition/request windows, catalog detail routing, album drill-in, and query update recovery.
- Phase 16 source checks: `git diff --check` passed for touched Swift/docs files; conflict-marker scan found no markers in touched task files; source scan confirmed `ArtistPopularTracksSection` and no direct full-list `TrackListSection(title: "Popular Tracks")` path.
- Phase 17 subtask 1 focused backend regression: `tests/searchResponsePrefetch.test.mjs` passed, covering non-awaiting background prefetch scheduling and public fallback cache-only behavior.
- Phase 17 subtask 1 backend suite: `npm test` passed 39 tests.
- Phase 17 subtask 1 source checks: `git diff --check` passed for touched backend/docs files; conflict-marker scan found no markers in touched task files; source scan found no remaining `await warmForegroundPrefetch` path.
- Phase 17 subtask 2 focused Swift regression: `testLyricsCacheReusesLoadedLyricsForRepeatedPlayback` passed after failing on a repeated provider lyrics request and `.loading` flash.
- Phase 17 subtask 2 lyrics/playback slice: 7 tests passed, covering lyrics cache, synchronized-line selection, backend lyrics decoding, lyric seek, progress fraction seek, and search playback activation context.
- Phase 17 subtask 2 source checks: `git diff --check` passed for touched Swift/docs files; conflict-marker scan found no markers in touched task files; source scan confirmed `lyricsCache` and `applyLyrics`.
- Phase 17 subtask 3 focused Swift regression: `testCatalogDetailCacheReusesLoadedItemsWithoutProviderRoundTrip` passed after failing on a repeated detail provider call/loading state.
- Phase 17 subtask 3 search/catalog/lyrics slice: 8 tests passed, covering detail cache, catalog drill-in, album drill-in, optimistic artist tracks, query recovery, Back cancellation, search routing, and lyrics cache.
- Phase 17 subtask 3 source checks: `git diff --check` passed for touched Swift/docs files; conflict-marker scan found no markers in touched task files; source scan confirmed `catalogItemsCache` and `catalogItemsCacheKey`.
- Phase 17 subtask 4 combined Swift acceptance slice: 16 tests passed, covering search debounce/cache/cancellation, catalog detail cache/navigation, lyrics cache/seek, artist header density, and top-5 popular-track presentation.
- Phase 17 subtask 4 backend acceptance suite: `npm test` passed 39 tests.
- Phase 17 subtask 4 source scans found no old full search loading wall, no awaited foreground search prefetch, no direct full-list artist Popular Tracks section, and confirmed timeout/cancellation/cache paths across app/backend/artwork code.
- Phase 17 subtask 5 native synthetic slow-network regression: `testSlowNetworkSearchKeepsShellPlaybackAndPreviousResultsUsable` passed with a 3.5s delayed provider response.
- Phase 18 docs verification: root-cause performance report added to `docs/IMPLEMENTATION_NOTES.md` and mirrored in `docs/BUGS_AND_REGRESSIONS.md`.
- Phase 18 final Swift acceptance slice: 17 focused tests passed, including the native synthetic slow-network regression.
- Phase 18 final backend suite: `npm test` passed 39 tests.
- Phase 18 final source checks: `git diff --check` passed for docs and touched task files, conflict-marker scan found no markers in touched task files/docs, Debug app bundle size was 43M, and source scans found no old production full search loading wall, awaited search prefetch, direct full-list Popular Tracks path, raw app `AsyncImage`, or old task-scope display/request caps.
- Checked for raw `AsyncImage` usage in app sources.
- Checked for `count: 12`, `count: 24`, `count: 50`, `prefix(12)`, `prefix(24)`, and `prefix(50)` in app/backend task scope.
