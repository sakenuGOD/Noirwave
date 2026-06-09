# Bugs And Regressions

## Fixed

- Featured/catalog loading selected the first loaded track as `currentTrack`, populated the queue, reset progress, and loaded lyrics. This made seed/catalog items appear as now-playing content before explicit playback. `applyFeaturedTracks(_:)` now keeps catalog loading separate from playback state.
- `Listen Now` and `Catalog` could render partial blank surfaces while featured tracks were still loading. They now show explicit skeleton loading states.
- Startup catalog data came from hardcoded Deezer seed searches, including specific public tracks and a generic fallback. `featuredTracks()` now returns a clean empty catalog state, and `radioTracks(seed:)` requires an explicit seed.
- Public artist detail had an internal 100-item cap applied after pagination. This could make backend data stop at 100 even if upstream `next` pages provided more items. The page collector now follows available pages behind a named page-count guard instead.
- Artist popular tracks displayed the received count as generic `N tracks`, making a Deezer top-track window look like a full artist track total. The subtitle now describes Deezer top tracks explicitly.
- Search results were rendered globally whenever the sidebar query was non-empty, before the destination switch. This meant Library/Listen Now/Profile could appear dead after a search. Search results are now scoped to the Catalog destination.
- Re-activating the currently playing search result restarted provider playback instead of toggling pause. `PlayerStore.activate(_:in:)` now routes same-track activation through `togglePlayPause()`.
- Catalog artist/album details were still rendered globally whenever `catalogContext` was set. Library/Listen Now/Profile could still appear dead after drilling into a search result. Catalog details and the Back button are now scoped to the Catalog destination.
- Leaving a catalog detail with an empty query did not cancel the active detail request, allowing a late provider response to overwrite the restored catalog landing data. Back now cancels the active task and late detail responses are ignored unless the same context is still active.
- Library mixed Liked Songs into the playlist shelf and put collections above the liked-track surface. The Library now promotes Liked Songs as the first large block, renders favorite tracks in an adaptive two-column list, keeps the playlist shelf for real local playlists, and provides a create-playlist tile.
- Lyrics rows were rendered as passive text. Synchronized lines now click through to the shared player seek path, and unsynced lyrics are explicitly marked instead of pretending timestamps exist.
- `PlayerStore.seek(to:)` mixed fraction seeking and absolute-time seeking. It now represents absolute seconds, while progress controls use `seek(toFraction:)`.
- Mini player visual treatment had drifted too dark. The glass tint/fill is lighter, inactive controls are more legible, the play/pause control is visibly outlined/glowing, and the progress rail reads against the glass.
- Sidebar palette had drifted into scattered green/gray/white states, and playlist rows could inherit unrelated current-track or collection artwork accents. Sidebar navigation, search, hover, active states, and playlist rows now use controlled native glass/app-accent tokens.
- The bottom sidebar Playlists block mixed real playlists with Liked Songs, discovery mixes, and derived album/artist collections. It now shows only real local playlists, with create-playlist controls and an honest empty state.
- Search input remote work could start before the user finished typing, repeated queries were not cached, and empty-result loading could become a large search loading wall. Search now debounces remote work for 300ms, cancels superseded tasks, caches successful normalized queries, ignores stale responses, resets empty queries immediately, and shows only compact local loading indicators.
- Artist header consumed too much of the first viewport with oversized hero height, artwork, title, padding, and latest-release row. The header is now governed by `ArtistHeaderLayoutMetrics` and uses a denser hero/latest-release stack that leaves room for the start of popular tracks in a 900px desktop viewport.
- Artist popular tracks rendered the full received list by default, so a 100-track Deezer top window became a long page immediately. Artist pages now show the top 5 by default and provide Show more / Show less controls for the full received list.
- Backend track search responses waited for startup playback prefetch before returning the search payload. `/api/search` now caches media metadata and schedules priority background prefetch without awaiting it, so search results are not blocked by playback warmup.
- Replaying a track fetched lyrics from the provider again and flashed lyrics loading even when the same track's lyrics were already loaded. `PlayerStore` now caches lyrics by track ID and applies cached lyrics synchronously on repeated playback.
- Reopening an already loaded artist/album detail started another provider catalog request and showed loading/optimistic content again. `PlayerStore` now caches catalog detail items by kind/catalog ID and reuses them immediately on repeat drill-in.
- Slow-network search behavior for the native macOS app is now covered by a synthetic delayed-provider regression. During a 3.5s delayed search, query text updates immediately, previous results remain visible, current playback stays intact, playback controls remain usable, and the delayed result applies after completion.
- Phase 18 root-cause investigation found the main wait-on-network causes in backend search prefetch coupling, uncached repeated search/detail/lyrics requests, oversized artist popular-track rendering, and loading surfaces that were too broad for the specific work. These are now documented and covered by focused regressions/source scans.
- Right panel behaved like a permanent app column instead of a floating widget.
- Lyrics button did not act as a clean toggle. The shared utility toggle now opens a closed panel, switches to a different panel, or closes the active panel.
- Queue and Sound controls now use the same toggle behavior.
- Mini-player artist/title/artwork looked clickable only as static metadata. Each target now has hover feedback and cursor behavior.
- Missing mini-player artist or album IDs previously failed silently. DEBUG builds now log the missing or malformed target.
- Artist popular tracks were truncated by UI/provider paths and by backend pagination behavior. The frontend no longer applies a 12-track cap, backend top tracks follow Deezer `next` pages, and fallback artist track lookup uses the named 500-item request window.
- Duplicate search UI came back as a regression. The app now has one search query/state path from the sidebar; the Catalog page no longer has a second independent search field.
- Artist card/profile looked like a plain card. It now has a media-led profile treatment and structured music-app sections.
- Artwork loading was too close to the old request pipeline. App artwork now goes through the unified `ArtworkImagePipeline`.
- Swift tests had duplicate test method names and outdated `MusicProviding` test doubles. These blocked `xcodebuild test` and were fixed.

## Regressions Found During This Work

- Catalog loading and playback state were coupled: bootstrap displayed a loaded seed track as current playback.
- Featured loading in top-level catalog surfaces did not reserve intentional content structure before the data arrived.
- Deezer startup content was still seeded with hardcoded public searches instead of real user/catalog state.
- Duplicate `Search` surfaces with different behavior.
- Popular tracks collapsing to a small fixed count.
- Right panel occupying app layout width instead of behaving like a widget.
- Hardcoded API request windows, including a fallback `count: 50` for artist top tracks.
- Shared public artist detail cap of 100 items for both top tracks and albums.
- Generic artist popular-track subtitle copy that made `100 tracks` look like a full catalog total.
- Non-empty sidebar search query overriding destination navigation.
- Search-result repeated activation replaying the provider instead of behaving like play/pause.
- Non-nil catalog detail context overriding destination navigation after search-result artist/album clicks.
- Late catalog detail responses overwriting the Back-restored surface.
- Liked Songs represented as a synthetic playlist item instead of a dedicated Library surface.
- Library collections displayed before the primary liked-song experience.
- Lyrics click-to-seek missing despite timestamped lyrics being available in the model.
- Ambiguous seek API caused absolute lyric/test seeks to jump to the end of the current track.
- Mini player contrast drifted below the intended premium-glass direction because black tint/fill and low-opacity controls stacked together.
- Sidebar color/composition drifted because individual controls owned their own opacity/accent decisions instead of sharing one palette contract.
- Sidebar playlist content had no clear data boundary; it pulled liked, featured, album, and artist groupings into a block labeled Playlists.
- Search UX still treated a fast typing sequence too much like a sequence of remote searches: the old 180ms debounce was below the requested 250-350ms window, no query-result cache was applied, and the loading state could dominate an empty search view.
- Artist profile hero looked like a giant media banner rather than a dense music-app header: old hardcoded dimensions pushed latest release and popular-track context too far down the page.
- Artist popular tracks were still rendered as a full list by default after the backend/UI stopped hiding the total. That fixed honesty but made the artist page too long and expensive to scan.
- Backend `/api/search` coupled result delivery to foreground startup prefetch for track results, adding unnecessary latency under slow playback-cache or network conditions.
- Lyrics loading had no in-memory reuse path, so slow lyrics provider responses could be repeated for the same track and make the lyrics panel feel blocked.
- Artist/album detail loading had no client-side reuse path, so repeated navigation could wait on the provider/backend again even when the detail was already known in the current store session.
- Native slow-network verification was missing until Phase 17 subtask 5; the app is not browser-hosted, so DevTools Slow 3G was not a valid direct verification method for the SwiftUI shell.
- The broader performance root cause was architectural coupling, not lack of visual loaders: remote search, playback prefetch, page detail loading, lyrics loading, and long-list rendering had to be separated so the shell could stay interactive while data arrives.
- Test target compile break from duplicated smart-search tests and missing `radioTracks(seed:)` stubs.

## Known Issues

- The repository was already in a git unmerged state before this work. Current `git status` still reports `UU` on several files, including core Swift files and backend files. I did not resolve or revert unrelated merge/index state.
- The app is a native macOS SwiftUI app, so browser screenshot and DevTools throttling verification are not direct equivalents for the shell. Verification was done through Xcode build/test, native delayed-provider slow-network coverage, backend tests, and source checks.
- No external Nuke or Kingfisher package was added. The implemented local pipeline applies the relevant caching, downsampling, priority, prefetch, cancellation, and retry patterns while preserving a single app-owned `ArtworkImagePipeline`.

## Documentation Audit

- Phase 12 confirmed the mandatory docs now explicitly cover regressions found, regressions fixed, files touched, verification for search/playback/library/lyrics/sidebar/player, the single-search guard, and the source of the 100-track count.
- No completion claim should ignore the remaining master-plan phases or the pre-existing unmerged git index state.
- Phase 13 confirmed durable docs did not claim all 18 phases were complete at that checkpoint; later Phase 14-18 work is now recorded in progress and handoff.

## Checks Passed

- `xcodebuild -project Noirwave.xcodeproj -scheme Noirwave -destination 'platform=macOS' -only-testing:NoirwaveTests/DeemixAPITrackMapperTests/testBootstrapPreparesVisiblePlaybackContextForFastSkipping -only-testing:NoirwaveTests/DeemixAPITrackMapperTests/testBootstrapDoesNotSelectFeaturedTrackAsCurrentPlayback test`: 2 passed, 0 failed.
- `npm test` in `NoirwaveBackend`: 36 passed, 0 failed.
- `npm test` in `NoirwaveBackend`: 37 passed, 0 failed.
- `xcodebuild -project Noirwave.xcodeproj -scheme Noirwave -destination 'platform=macOS' test`: 73 passed, 0 failed.
- Focused Phase 5 search/navigation regression slice: 9 passed, 0 failed.
- Focused Phase 6 Library/playlist regression slice: 19 passed, 0 failed.
- Focused Phase 7 lyrics regression slice: 4 passed, 0 failed.
- Focused Phase 8 mini player visual-token regression: 1 passed, 0 failed.
- Focused Phase 9 sidebar visual-token regression: 1 passed, 0 failed.
- Combined Phase 7/8/9 focused slice: 6 passed, 0 failed.
- Focused Phase 10 sidebar-playlist regression: 1 passed, 0 failed.
- Focused Phase 10 playlist/sidebar regression slice: 4 passed, 0 failed.
- Phase 11 focused Swift regression checklist: 20 passed, 0 failed.
- Phase 11 backend regression checklist: 37 passed, 0 failed.
- Phase 11 source scans passed for duplicate catalog search, fake app content, sidebar playlist filler, old public artist 100-item cap patterns, and task-scope conflict markers.
- Phase 12 docs audit: mandatory documentation coverage map added.
- Phase 13 no-fake-completion audit: progress and handoff kept phases 14-18 open at that checkpoint and preserved the unresolved git index warning.
- Phase 14 focused search/navigation slice: 9 passed, 0 failed, covering debounce/cache, cancellation stale-error safety, search destination routing, search playback, catalog detail routing, album drill-in, and query update recovery.
- Phase 14 source checks passed: `git diff --check` for touched Swift/docs files, no conflict markers in touched task files, and no old full-panel `CatalogLoadingView(title: "Searching")` path.
- Phase 15 focused artist header regression: `testArtistHeaderLayoutKeepsFirstViewportDense` passed after a compile-time RED.
- Phase 15 artist/catalog slice: 7 passed, 0 failed, covering header metrics, artist top-track copy, catalog composition/request windows, catalog detail routing, album drill-in, and query update recovery.
- Phase 15 source checks passed: `git diff --check` for touched Swift/docs files, no conflict markers in touched task files, and no old oversized artist-hero literals.
- Phase 16 focused popular-tracks regression: `testArtistPopularTracksPresentationDefaultsToTopFiveAndCanExpand` passed after a compile-time RED.
- Phase 16 artist/header/popular-tracks/catalog slice: 8 passed, 0 failed, covering default top-5 display, expand/collapse, header metrics, artist top-track copy, catalog composition/request windows, catalog detail routing, album drill-in, and query update recovery.
- Phase 16 source checks passed: `git diff --check` for touched Swift/docs files, no conflict markers in touched task files, and no direct full-list `TrackListSection(title: "Popular Tracks")` path.
- Phase 17 subtask 1 focused backend regression: `node --test tests/searchResponsePrefetch.test.mjs` passed 2 tests, 0 failed after a module-missing RED.
- Phase 17 subtask 1 backend suite: `npm test` passed 39 tests, 0 failed.
- Phase 17 subtask 1 source checks passed: `git diff --check` for touched backend/docs files, no conflict markers in touched task files, and no `await warmForegroundPrefetch` path.
- Phase 17 subtask 2 focused Swift regression: `testLyricsCacheReusesLoadedLyricsForRepeatedPlayback` passed after a runtime RED.
- Phase 17 subtask 2 lyrics/playback slice: 7 passed, 0 failed, covering lyrics cache, synchronized-line selection, backend lyrics decoding, lyric seek, progress fraction seek, and search playback activation context.
- Phase 17 subtask 2 source checks passed: `git diff --check` for touched Swift/docs files, no conflict markers in touched task files, and source scan confirmed `lyricsCache` / `applyLyrics`.
- Phase 17 subtask 3 focused Swift regression: `testCatalogDetailCacheReusesLoadedItemsWithoutProviderRoundTrip` passed after a runtime RED.
- Phase 17 subtask 3 search/catalog/lyrics slice: 8 passed, 0 failed, covering detail cache, catalog drill-in, album drill-in, optimistic artist tracks, query recovery, Back cancellation, search routing, and lyrics cache.
- Phase 17 subtask 3 source checks passed: `git diff --check` for touched Swift/docs files, no conflict markers in touched task files, and source scan confirmed `catalogItemsCache` / `catalogItemsCacheKey`.
- Phase 17 subtask 4 combined Swift acceptance slice: 16 passed, 0 failed, covering search debounce/cache/cancellation, catalog detail cache/navigation, lyrics cache/seek, artist header density, and popular-track top-5 presentation.
- Phase 17 subtask 4 backend acceptance suite: `npm test` passed 39 tests, 0 failed.
- Phase 17 subtask 4 source scans found no old full search loading wall, no awaited foreground search prefetch, no direct full-list artist Popular Tracks path, and confirmed app/backend/artwork timeout, cancellation, and cache paths.
- Phase 17 subtask 5 native synthetic slow-network regression: `testSlowNetworkSearchKeepsShellPlaybackAndPreviousResultsUsable` passed with a 3.5s delayed provider search and verified local query update, previous results retention, playback usability, and delayed result application.
- Phase 18 root-cause performance report added to `docs/IMPLEMENTATION_NOTES.md`, covering true hang causes, blocking components, unnecessary/sequential requests, loading-wall removal, cache/stale-response guards, slow-network verification, and remaining heavy areas.
- Phase 18 final Swift acceptance slice: 17 focused tests passed, including search debounce/cache/cancellation, native slow-network delayed search, catalog detail cache/navigation, lyrics cache/seek, artist header density, and popular-track top-5 presentation.
- Phase 18 final backend suite: `npm test` passed 39 tests, 0 failed.
- Phase 18 final source checks: `git diff --check` passed for docs and touched task files; conflict-marker scan found no markers in touched task files/docs; Debug app bundle size checked at 43M; source scans found no old production full search loading wall, awaited search prefetch, direct full-list Popular Tracks path, raw app `AsyncImage`, or old task-scope display/request caps.
- Source check for raw `AsyncImage`: no app artwork usage found.

## Residual Notes

- Source check for old 12/24/50 display/request caps: no task-scope cap remains; only test fixture metadata such as `tracks_count: 12` and scoring constants remain.
- The only remaining known non-plan issue is the pre-existing unmerged git index state.
