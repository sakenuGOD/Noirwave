# Stabilization Progress

Source of truth: `docs/STABILIZATION_MASTER_PLAN.md`.

Status legend:
- `[ ]` not started
- `[~]` in progress
- `[x]` completed
- `[!]` blocked or needs follow-up

## Checklist

1. `[x]` Loading states / podzagruzka
2. `[x]` Limit 100 tracks
3. `[x]` Single Search flow
4. `[x]` Playback from Search
5. `[x]` Search buttons / navigation bug
6. `[x]` Library reference pattern
7. `[x]` Lyrics interactivity
8. `[x]` Player redesign
9. `[x]` Sidebar redesign / colors
10. `[x]` Playlists block in sidebar
11. `[x]` Regression checklist
12. `[x]` Mandatory docs
13. `[x]` No fake completion
14. `[x]` Search input UX
15. `[x]` Artist header density
16. `[x]` Popular tracks default limit
17. `[x]` Production-grade performance/loading
18. `[x]` Root-cause performance investigation

## Current Subtask

All stabilization phases in `docs/STABILIZATION_MASTER_PLAN.md` are complete for the current pass. Post-plan panel glass correction is complete for the current pass. Remaining non-plan issue: the repository still has a pre-existing unmerged git index state.

## Notes

- 2026-06-07 resume checkpoint: re-read `docs/STABILIZATION_MASTER_PLAN.md`, confirmed Phase 5 was the next active work item, and kept `docs/HANDOFF.md` as the compact recovery source.
- 2026-06-07 17:57 MSK resume checkpoint: re-read `docs/STABILIZATION_MASTER_PLAN.md`, `docs/STABILIZATION_PROGRESS.md`, and `docs/HANDOFF.md`; Phase 7 lyrics interactivity remains the next active work item.
- `docs/STABILIZATION_MASTER_PLAN.md` was created from the available root-level `/Users/fsociety/TABILIZATION_MASTER_PLAN.md` because the requested docs path did not exist at session start.
- Repository started with unresolved merge conflicts and existing uncommitted changes. Work must preserve them and not revert unrelated changes.
- Phase 1 subtask 1 complete: bootstrap no longer turns featured/catalog seed tracks into `currentTrack`, queue, playback, progress, or lyrics state.
- Test harness compile blocker fixed by restoring `SearchCacheRecordingProvider` in `NoirwaveTests/DeemixAPITrackMapperTests.swift`.
- Phase 1 subtask 2 complete: `ListenNowView` and `CatalogLandingView` now show explicit skeleton loading surfaces while featured catalog data is pending.
- Phase 1 subtask 3 complete: `DeemixAPIProvider.featuredTracks()` now returns a clean empty catalog state, `radioTracks(seed:)` no longer falls back to generic seed searches, and README now documents that initial catalog state does not use hardcoded Deezer seed searches.
- Phase 2 subtask 1 complete: traced "100 tracks" to backend public artist detail pagination (`publicArtistDetailItemLimit = 100`) plus the artist UI subtitle rendering the received popular-track count. Live Deezer checks on June 7, 2026 showed `/artist/{id}/top` currently returns at most 100 top tracks for major artists, while `/artist/{id}/albums` can return more than 100; the app still should not impose its own hidden 100-item cap.
- Phase 2 subtask 2 complete: added backend regression test `does not impose an internal 100 item cap on paginated public artist top tracks`; RED failed for the intended reason with `100 !== 120`.
- Phase 2 subtask 3 complete: removed `publicArtistDetailItemLimit`, changed public artist detail page collection to follow Deezer `next` links without a hidden 100-item limit, and bounded collection by named page count `publicArtistDetailMaxPages = 20`. Backend tests pass: 37/37.
- Phase 2 subtask 4 complete: added `ArtistPopularTracksCopy`, changed the artist popular-tracks subtitle from generic `N tracks` to Deezer top-track copy, and verified the helper with focused Swift RED/GREEN.
- Phase 3 subtask 1 complete: traced catalog search to one shared `PlayerStore.searchQuery` and one `SidebarSearchField`; `CatalogLandingView` has no second text field. Regression found: `ContentDeckView` shows `SearchResultsView` whenever `searchQuery` is non-empty, before switching on destination, so clicking Library/Listen Now after a search cannot display that destination until search is cleared.
- Phase 3 subtask 2 complete: added Swift regression test `testSearchResultsStayScopedToCatalogDestination`; RED failed for the intended compile-time reason because `ContentDeckRouting` did not exist yet.
- Phase 3 subtask 3 complete: added `ContentDeckRouting`, scoped search results to the Catalog destination, and verified Library/Listen Now/Profile are not hidden by a non-empty sidebar query.
- Phase 4 subtask 1 complete: traced search playback to shared `PlayerStore.activate(_:in:)` through `BestMatchCard`, `EntityCard`, and `TrackRowView`; existing RED `testActivatingCurrentSearchTrackTogglesPlaybackInsteadOfRestarting` confirms first activation starts playback but repeated activation restarts playback instead of pausing.
- Phase 4 subtask 2 complete: `PlayerStore.activate(_:in:)` now toggles play/pause when the activated playable item is already `currentTrack`, avoiding provider replay. Added `testActivatingSearchResultUsesVisibleResultsForPlaybackContext` to lock search queue/context. Phase 4 focused tests pass: 2/2.
- Phase 5 subtask 1 complete: catalog detail rendering and the Back button are now scoped to the Catalog destination, so Library/Listen Now/Profile do not appear dead after opening an artist/album from search. Leaving a catalog detail now cancels the active detail task and ignores late provider responses for stale contexts.
- Phase 6 subtask 1 complete: Library now prioritizes a large real liked-songs block with an adaptive two-column favorite-track list, keeps liked songs out of the real playlist shelf, shows a create-playlist tile under "Мои плейлисты", and moves saved collections below. App-source scan found no hardcoded Nirvana/Daft Punk Library filler.
- Phase 7 subtask 1 complete: synchronized lyric rows are clickable and seek through the shared `PlayerStore`, active-line highlighting and scroll sync continue to use playback progress, unsynced text renders with an explicit unsynced state, and progress controls now use a separate fraction seek API.
- Phase 8 subtask 1 complete: mini player glass darkening was reduced, inactive controls were raised to readable opacity, the play/pause button got stronger stroke/glow, and the progress rail is thicker/brighter behind a token-level regression test.
- Phase 9 subtask 1 complete: sidebar navigation/search/playlist rows now use controlled `SidebarVisualStyle` tokens, active states use a restrained app-accent glass treatment, search focus is accent-led, and sidebar playlist rows no longer inherit drifting current-track/collection colors.
- Phase 10 subtask 1 complete: chose master-plan path B and rebuilt the bottom sidebar playlist block to show only real local playlists, compact native rows, a create-playlist empty state/action, and no Liked Songs/discovery/album/artist synthesized filler.
- Phase 11 subtask 1 complete: mandatory regression checklist passed with 20 focused Swift tests, backend suite 37/37, and source scans for duplicate catalog search, fake content, sidebar playlist filler, old 100-track caps, and conflict markers.
- Phase 12 subtask 1 complete: mandatory docs were audited and mapped explicitly to master-plan requirements for regressions found/fixed, files touched, verification, single-search lock, and 100-track origin.
- Phase 13 subtask 1 complete: no-fake-completion audit found docs/progress/handoff clearly show only phases 1-13 complete, phases 14-18 remaining, and the pre-existing unmerged git index still unresolved.
- Phase 14 subtask 1 complete: search input now uses a 300ms debounce, keeps typing local/non-blocking, cancels previous search tasks, ignores stale responses, reuses an in-memory query cache, resets empty queries immediately, and uses local spinner states instead of a full search loading wall. Focused Phase 14 search/navigation tests passed at 2026-06-07 19:09 MSK.
- Phase 15 subtask 1 complete: artist header density is now tokenized through `ArtistHeaderLayoutMetrics`, reducing hero height, artwork, title, padding, action controls, latest-release row, and section spacing so a 900px desktop viewport can include the header, latest release, and start of popular tracks. Focused Phase 15 artist/catalog tests passed at 2026-06-07 19:15 MSK.
- Phase 16 subtask 1 complete: artist popular tracks now render through `ArtistPopularTracksSection`, default to the top 5 rows, and expose Show more / Show less expand-collapse behavior without changing the received Deezer top-track count copy. Focused Phase 16 artist tests passed at 2026-06-07 19:20 MSK.
- Phase 17 subtask 1 complete: backend `/api/search` no longer awaits startup prefetch before returning track search payloads. `applySearchResponsePrefetch` now caches media metadata synchronously and schedules priority background prefetch for catalog track search results. Backend suite passed 39/39 at 2026-06-07 19:24 MSK.
- Phase 17 subtask 2 complete: `PlayerStore` now caches loaded `TrackLyrics` by track ID and applies cached lyrics synchronously on repeated playback, avoiding a repeat provider lyrics request and loading flash. Focused lyrics/playback Swift slice passed at 2026-06-07 19:31 MSK.
- Phase 17 subtask 3 complete: `PlayerStore` now caches catalog detail items by kind/catalog ID, so repeated artist/album drill-in reuses loaded items immediately without a provider round trip or loading state. Focused search/catalog/lyrics Swift slice passed at 2026-06-07 19:37 MSK.
- Phase 17 subtask 4 complete: remaining acceptance audit found no old full search loading wall, no awaited foreground prefetch in backend search, no direct full-list artist Popular Tracks path, request timeouts/cancellation/cache paths present in app/backend/artwork code, combined Swift Phase 17 slice passed, and backend suite passed 39/39. Phase 17 remains open because explicit slow-network/native-app verification still needs to be performed or scoped honestly.
- Phase 17 subtask 5 complete: added and passed native synthetic slow-network regression `testSlowNetworkSearchKeepsShellPlaybackAndPreviousResultsUsable`, using a 3.5s delayed provider search to confirm the query updates locally, prior results remain visible, playback controls stay usable, and final results apply after the delayed response. This is the documented macOS-native substitute for Browser DevTools Slow 3G throttling.
- Phase 18 subtask 1 complete: mandatory root-cause performance investigation report added to `docs/IMPLEMENTATION_NOTES.md`, mandatory docs updated, final Swift Phase 17/18 slice passed 17 focused tests, backend suite passed 39/39, `git diff --check` passed for touched task files/docs, conflict-marker scan found no markers in touched task files/docs, Debug app bundle size checked at 43M, and source scans found no old full search loading wall, awaited search prefetch, direct full-list Popular Tracks path, raw app `AsyncImage`, or old task-scope display/request caps.
- 2026-06-07 20:42 MSK post-plan UI correction complete: left sidebar and right now-playing/sound panel use mini-player-style black glass tokens, equalizer is embedded in the panel glass, mini-player progress/play visuals are smaller, the panel glass was lightened twice after user feedback that it looked too murky, and then split so the left sidebar is clearer while the right now-playing/sound widget is darker.
