# Implementation Notes

## Stabilization Phase 1

- `PlayerStore.applyFeaturedTracks(_:)` now updates `featuredTracks`, `visibleTracks`, catalog title/context, and prewarm candidates only.
- Featured loading no longer assigns `currentTrack = tracks.first`, no longer preloads lyrics for the first featured track, and no longer creates a queue before playback.
- Root cause for this subtask: featured/catalog seed data was being treated as playback state, which made loaded catalog items look like actual now-playing content.
- Verification: the bootstrap no-auto-current test failed before the store change and passed afterward with the visible-context prewarm test.
- `ListenNowView` and `CatalogLandingView` now route pending-empty featured data through `CatalogLoadingSkeletonView`.
- `CatalogLoadingSkeletonView` uses neutral hero, shelf, and track-list skeleton blocks and does not render artist, album, or track names as placeholders.
- `DeemixAPIProvider.featuredTracks()` now returns `[]` instead of issuing default Deezer searches for specific public tracks.
- `DeemixAPIProvider.radioTracks(seed:)` now builds recommendations only from an explicit seed track. Without a seed, it returns `[]` instead of falling back to generic "electronic" catalog search.
- README documents the clean initial catalog behavior: no default Daft Punk/Nirvana/electronic seed content, no fake home catalog, and user action or real library data drives results.

## UI Shell

- `PlayerShellView` now uses a `ZStack` shell so the right panel floats above the main content instead of consuming half of the layout.
- The floating panel width is clamped to the requested range: about 360 to 430 px depending on window width.
- The mini player remains the bottom anchor. Its container, density, and visual hierarchy were not simplified.
- `SidebarView`, `SidebarItem`, and `SidebarPlaylistRow` were redesigned around glass material, subtle borders, compact row heights, hover states, and native-list playlist rows.
- `NowPlayingPanel`, `NowPlayingPanelTabs`, and `NowPlayingPanelTabButton` replace the old heavy right-side panel treatment.

## Navigation And Search

- `MiniPlayerTrackSummary` now exposes separate click targets:
  - artwork opens the album target;
  - track title opens the album target;
  - artist name opens the artist target.
- `MiniPlayerCatalogTarget` parses Deezer artist and album IDs from the stored catalog URLs and creates navigation tracks.
- `NoirwaveDiagnostics` logs missing or malformed mini-player navigation metadata in DEBUG builds.
- `ShellDestination.search` was renamed in display copy to `Catalog`.
- `CatalogLandingView` is passive and uses the sidebar `store.searchQuery`; it does not create a second independent search input.

## Search Input UX

- Phase 14 root cause: the sidebar search path had debounce/cancellation guards, but it still started remote work too aggressively for fast typing, had no real query result cache, and could swap an empty result area into a bulky searching surface.
- `PlayerStore.scheduleSearch()` now treats `PlayerStore.searchQuery` as local controlled state first:
  - empty queries reset catalog state immediately;
  - cached normalized queries apply immediately without another provider request;
  - uncached remote search waits for a 300ms debounce before touching the provider;
  - every new query cancels the previous search task.
- `PlayerStore.runSearch()` caches successful results by `SearchScope` plus normalized term and still checks the active query before applying results. Cancelled or stale provider responses do not overwrite the current query's visible results or error state.
- The cache is intentionally in-memory and scoped to the current `PlayerStore` session. Phase 17/18 can broaden this into stale-while-revalidate for artist/album/lyrics without changing the Phase 14 search contract.
- `SearchResultsView` no longer replaces an empty search state with a full `CatalogLoadingView(title: "Searching")` wall. Loading is local:
  - `SidebarSearchField` shows a small inline spinner while a remote search is active;
  - `EmptySearchView(isSearching:)` shows compact searching copy only when there are no results yet.
- Previous visible results are preserved until a valid fresh result set, cached result set, or explicit empty-query reset is applied. Search loading no longer resets player state, queue, navigation destination, or catalog detail routing.
- Phase 14 tests lock the behavior with:
  - `testSearchDebouncesRemoteRequestAndKeepsTypingLocal`;
  - `testSearchUsesCachedResultsWithoutRepeatingRemoteQuery`;
  - `testCancelledSearchDoesNotSurfaceProviderError`;
  - the existing search routing/playback/catalog navigation slice.

## Production Performance And Loading

- Phase 17 subtask 1 root cause: backend `/api/search` waited for `warmForegroundPrefetch(...)` before `response.json(payload)` for catalog track search results. This meant search result delivery could wait on playback startup-cache work that is not required to render the results list.
- `NoirwaveBackend/src/searchResponsePrefetch.mjs` now owns the search response prefetch contract:
  - non-track searches do nothing;
  - track searches cache returned media metadata immediately;
  - public Deezer fallback track searches stay cache-only because startup prefetch depends on backend media resolution;
  - catalog track searches schedule priority background startup prefetch and return synchronously.
- `/api/search` now calls `applySearchResponsePrefetch(...)` after `searchCatalog(...)` and before `response.json(payload)`, but it does not await startup prefetch. Result payload delivery is no longer coupled to playback warmup.
- Verification:
  - `test("track search schedules startup prefetch without awaiting response delivery")` failed as the intended module-missing RED before the helper existed;
  - `tests/searchResponsePrefetch.test.mjs` passed after implementation;
  - backend suite passed 39/39;
  - source scan found no `await warmForegroundPrefetch` path in `server.mjs`.
- Phase 17 subtask 2 root cause: `PlayerStore.loadLyrics(for:)` fetched lyrics from the provider every time a playable track was started, even when the same track's lyrics had already been loaded. Replaying a track could flash `.loading` and wait on a slow lyrics response again.
- `PlayerStore` now keeps an in-memory `lyricsCache` keyed by track ID. Cached lyrics are applied synchronously with `applyLyrics(_:)`; fresh provider lyrics populate the cache only after cancellation/stale-current-track guards pass.
- Cached unavailable lyrics are also represented by the cached `TrackLyrics` value, preserving honest unavailable state without a repeat request.
- Verification:
  - `testLyricsCacheReusesLoadedLyricsForRepeatedPlayback` failed as the intended RED because repeat playback returned to `.loading` and made a second provider lyrics request;
  - the focused lyrics-cache test passed after implementation;
  - the broader lyrics/playback Swift slice passed 7 tests.
- Phase 17 subtask 3 root cause: `PlayerStore.drillIntoCatalog(from:)` always started a provider `catalogItems(for:)` request for artist/album detail, even when the same detail had already been loaded. Reopening the same artist/album could show optimistic/empty content and a loading state again.
- `PlayerStore` now keeps an in-memory `catalogItemsCache` keyed by `Track.kind` and normalized `catalogID`/ID. A cached artist/album detail applies immediately, keeps `isSearching = false`, and avoids another provider round trip.
- Fresh catalog detail responses populate the cache only after cancellation and active-context stale guards pass. Stale artist/album responses still cannot overwrite the active catalog context.
- Verification:
  - `testCatalogDetailCacheReusesLoadedItemsWithoutProviderRoundTrip` failed as the intended RED because repeat drill-in showed loading and called `catalogItems(for:)` twice;
  - the focused catalog-cache test passed after implementation;
  - the broader search/catalog/lyrics Swift slice passed 8 tests.
- Phase 17 subtask 4 acceptance audit:
  - source scans found no old full `CatalogLoadingView(title: "Searching")` path;
  - backend `/api/search` no longer has an `await warmForegroundPrefetch` path;
  - artist Popular Tracks no longer has a direct full-list `TrackListSection(title: "Popular Tracks")` path;
  - `PlayerStore` now has search, lyrics, and catalog-detail in-memory caches with cancellation/stale guards;
  - app/backend/artwork sources expose request timeouts, `AbortController` for public Deezer fetches, Swift task cancellation guards, URLSession timeouts, and artwork cache/cancellation paths;
  - combined Swift Phase 17 acceptance slice passed 16 focused tests;
  - backend suite passed 39/39.
- Phase 17 subtask 5 native slow-network verification:
  - Browser DevTools/Playwright Slow 3G throttling is not directly applicable to this native macOS SwiftUI app shell.
  - The accepted substitute is a native synthetic slow-network regression test, `testSlowNetworkSearchKeepsShellPlaybackAndPreviousResultsUsable`, using a 3.5s delayed `MusicProviding.search(...)` response.
  - During that delayed response, the test verifies `searchQuery` updates locally, previous visible tracks remain on screen, `currentTrack` remains stable, playback controls still toggle pause, only one remote search is recorded, and the delayed result replaces the visible list after completion.
  - The focused native slow-network regression passed on 2026-06-07 at 19:51 MSK. Phase 17 is closed for this stabilization pass.

## Root-Cause Performance Investigation

- Phase 18 root cause summary: the app felt like it waited for network because several independent surfaces were coupled to remote work or long lists. The largest confirmed backend cause was `/api/search` awaiting playback startup prefetch before returning track search payloads. On the client, fast typing had no useful query-result cache, artist/album details and lyrics were refetched on repeat navigation/playback, artist pages rendered the full popular-track list by default, and search/detail loading states could dominate the visible surface.
- Components that blocked or appeared to block UI before this pass:
  - backend `/api/search` blocked result delivery on `warmForegroundPrefetch(...)`;
  - `PlayerStore.scheduleSearch()` let remote work start too quickly and had no normalized result cache;
  - `SearchResultsView` could swap an empty search into a large searching surface rather than a local indicator;
  - `PlayerStore.drillIntoCatalog(from:)` refetched already opened artist/album detail data;
  - `PlayerStore.loadLyrics(for:)` refetched lyrics for already played tracks;
  - `ArtistDetailView` rendered all received popular tracks through a general list section by default.
- Requests that were unnecessary or overly sequential:
  - search response delivery was sequentially coupled to playback prefetch;
  - repeated normalized search queries could issue another provider request;
  - repeated lyrics opens and repeated artist/album drill-in could issue duplicate provider/backend requests;
  - backend public artist detail now requests artist, top tracks, and albums concurrently, then follows available pagination behind named page guards.
- Global/loading wall behavior removed or scoped:
  - sidebar search is local controlled state first and remote work starts after a 300ms debounce;
  - empty query resets immediately without provider work;
  - search loading is a sidebar spinner plus compact empty-result state, not a full app blocker;
  - catalog detail loading is scoped to the Catalog destination and empty detail content only;
  - Listen Now/Catalog bootstrap use skeleton/empty states without fabricating playback content;
  - player/sidebar/navigation are separate from page loading flags and remain interactive while search/detail/lyrics work is pending.
- Cache and stale-while-revalidate behavior added:
  - search results cache by normalized query and scope for immediate repeat-query reuse;
  - lyrics cache by track ID for synchronous repeated playback/lyrics panel reuse;
  - catalog detail cache by kind and normalized catalog ID for instant repeated artist/album drill-in;
  - artwork memory/disk/URLCache pipeline with downsampling, cancellation, priority, retry cooldown, and prefetch support;
  - stale search, lyrics, and catalog detail responses are guarded by active query/current track/current catalog context before they can update UI state.
- Heavy content and long-list controls:
  - artist Popular Tracks defaults to five rows and expands only on explicit user action;
  - Library favorite tracks and repeated shelves use lazy grids/stacks instead of forcing all card surfaces into eager layout;
  - raw `AsyncImage` is not used for app artwork cards; image work flows through the app-owned pipeline.
- Slow-network verification:
  - native synthetic slow-network test covered a 3.5s delayed search provider response because Browser DevTools throttling does not apply to the macOS SwiftUI app shell;
  - backend `searchResponsePrefetch` tests verify search response handling schedules startup prefetch without awaiting it;
  - source scans verified timeout/cancellation/cache paths across app/backend/artwork code.
- Remaining potentially heavy pieces:
  - expanded artist Popular Tracks can still render the full received list after the user clicks Show more; if upstream windows grow substantially beyond the current Deezer top-track behavior, add list windowing/virtualization for the expanded state;
  - backend catalog CLI calls are still external-process/network bound and need continued timeout/retry monitoring under real Deezer/Yandex service failures;
  - visual blur/material effects should be watched on older Macs if profiling later shows GPU cost;
  - the current caches are in-memory per `PlayerStore` session except artwork disk cache, so cold app launches still depend on provider/backend latency.
- Phase 18 final verification:
  - focused Swift Phase 17/18 acceptance slice passed 17 tests after the native slow-network test wait was made scheduler-safe;
  - backend `npm test` passed 39/39;
  - `git diff --check` passed for docs plus touched Swift/backend task files;
  - conflict-marker scan found no markers in docs plus touched Swift/backend task files;
  - Debug app bundle size checked at 43M;
  - source scans found no production full search loading wall, no awaited foreground search prefetch in `/api/search`, no direct full-list artist Popular Tracks path, no raw app `AsyncImage`, and no old task-scope display/request caps. Remaining scan matches were test fixture waits/copy and backend readiness polling, not the search/performance production paths.

## Artist Catalog Data

- `Track` now carries `artistCatalogID` and `albumCatalogID`.
- `DeemixAPITrackMapper.map` fills artist and album catalog IDs from Deezer payload links or IDs.
- `DeemixAPICatalogRequestLimits` centralizes client request windows:
  - `searchWindow = 180`
  - `artistTrackWindow = 500`
  - `smartArtistWindow = 20`
  - `smartAlbumWindow = 80`
  - `catalogArtistWindow = 20`
- `DeemixAPIArtistCatalogComposer.items(popularTracks:albums:)` keeps all popular tracks and appends albums after popularity sorting.
- `SmartSearchRanker.ranked` no longer defaults to an internal 50-item result cap.
- Backend public artist detail follows paginated Deezer `next` links for top tracks via `collectPublicDataPages`.
- Backend `/api/search` uses `normalizeCatalogLimit`, with default 80 and max 500.
- Phase 2 trace found the visible "100 tracks" value coming from Deezer artist top-track data plus the old backend `publicArtistDetailItemLimit = 100` cap.
- Live public endpoint checks on June 7, 2026 showed Deezer `/artist/{id}/top` currently returning at most 100 top tracks for several major artists, while artist albums can exceed 100 items.
- Backend public artist detail no longer imposes a hidden 100-item cap. `collectPublicDataPages(...)` now follows `next` links until upstream stops, an explicit optional item limit is reached, or the named `publicArtistDetailMaxPages = 20` guard is hit.
- `ArtistPopularTracksCopy.subtitle(count:)` centralizes artist popular-track subtitle text. The artist page now says `100 Deezer top tracks` instead of a generic `100 tracks`, making the value a source-specific top-track window rather than a claimed full artist track count.
- Phase 3 trace found one catalog search state path: `SidebarSearchField` binds to `PlayerStore.searchQuery`, `PlayerStore.runSearch()` writes `visibleTracks`, and `SearchResultsView` renders those shared results. `CatalogLandingView` remains passive and does not own a second input.
- `ContentDeckRouting.showsSearchResults(...)` now scopes result rendering to the Catalog destination with no active catalog detail context. This prevents a non-empty sidebar query from blocking Library/Listen Now/Profile navigation.
- Phase 4 trace found search playback already enters the shared player store through `BestMatchCard`, `EntityCard`, and `TrackRowView`, all of which call `PlayerStore.activate(...)`.
- `PlayerStore.activate(_:in:)` now detects `currentTrack?.id == item.id` for playable items and calls `togglePlayPause()` instead of rebuilding context and replaying the provider.
- Multi-result search activation continues to use `store.visibleTracks` as playback context, so the queue is built from the visible search result order.
- Phase 5 trace found `ContentDeckView` still rendered `CatalogDetailContent` before checking the selected destination. That left Library/Listen Now/Profile visually blocked after artist/album clicks from search.
- `ContentDeckRouting.showsCatalogDetail(...)` now scopes detail rendering to the Catalog destination, mirroring the existing search-result scoping helper.
- `TopBarView` uses the same helper, so Back only appears when the current destination is actually showing a catalog detail.
- `PlayerStore.leaveCatalogContext()` now cancels the active catalog detail task and clears `isSearching` before restoring featured tracks or scheduling a fresh search.
- Catalog detail task completion now checks `catalogContext == item` before writing `visibleTracks`, title, subtitle, or errors. This prevents stale artist/album responses from reviving an old detail after Back or query updates.
- Phase 6 trace found Library already used real persisted data sources: `store.likedTracks(limit:)`, `store.savedCollections(limit:)`, and `store.localPlaylists`. No app-source hardcoded Nirvana/Daft Punk Library filler was found.
- `LibrarySurfaceLayout.sections(...)` now orders Library as liked songs first, playlists below, saved collections last.
- `LibraryPlaylistShelfBuilder.items(...)` now returns only real local playlists. Liked Songs is no longer synthesized into the playlist shelf.
- `LikedSongsFeatureBlock` gives "Мне нравится" a prominent first block with real mosaic artwork, count copy, and shared play/shuffle/queue actions.
- `FavoriteTracksLibrarySection` now renders favorite tracks through an adaptive two-column `LazyVGrid`, using the existing real `TrackRowView` rows and playback context.
- `LibraryPlaylistsShelf` now always includes `LibraryCreatePlaylistTile` when the playlists section is shown, giving users a visible create playlist tile instead of only a header button.
- `LibraryCollectionsShelf` now renders saved artist/album collections only, avoiding duplicate derived liked-track cards above the primary liked-song surface.

## Artist Header Density

- Phase 15 root cause: `ArtistHeroView` used oversized hardcoded values (`minHeight: 340`, 58pt title, 184pt foreground artwork, 420pt blurred background artwork, 28pt padding, and a 74pt latest-release row). The result consumed too much vertical space before latest release and popular tracks.
- `ArtistHeaderLayoutMetrics` is the tested density contract for the artist header:
  - `heroMinHeight = 272`;
  - `foregroundArtworkSize = 148`;
  - `titleFontSize = 46`;
  - `detailSectionSpacing = 18`;
  - `aboveFoldStackHeight` must fit inside `availableDesktopContentHeight` for a 900px desktop viewport reservation.
- `ArtistDetailView` now uses the shared section spacing token, so the hero, latest release, and popular tracks read as one compact artist page rather than isolated large blocks.
- `ArtistHeroView` keeps the media-led premium treatment but reduces the blurred background art, foreground artist image, title size, padding, gradient weight, and action button heights.
- `ArtistLatestReleaseFeature` uses smaller artwork, tighter vertical padding, and smaller text while keeping the same click target behavior and album navigation.
- Verification:
  - `testArtistHeaderLayoutKeepsFirstViewportDense` failed as the intended compile-time RED before the metrics contract existed;
  - the focused Phase 15 test passed after implementation;
  - the broader artist/catalog slice passed 7 tests, covering header metrics plus existing artist catalog/navigation behavior.

## Artist Popular Tracks Default Limit

- Phase 16 root cause: `ArtistDetailView` passed the full artist `tracks` array directly into `TrackListSection(title: "Popular Tracks", ...)`, so an artist with 100 Deezer top tracks rendered a long page by default.
- `ArtistPopularTracksPresentation` is the tested presentation contract:
  - `defaultVisibleCount = 5`;
  - collapsed state returns only the first five tracks;
  - expanded state returns the full received track list;
  - the expand/collapse toggle appears only when the total count is greater than five.
- `ArtistPopularTracksSection` owns the SwiftUI expanded/collapsed state for artist pages only. Other `TrackListSection` usages keep their existing behavior.
- The section subtitle still uses `ArtistPopularTracksCopy.subtitle(count: tracks.count)`, so the UI can honestly say `100 Deezer top tracks` while only rendering the first five rows by default.
- The toggle copy is `Show more` / `Show less`, with a compact native button below the visible rows. The button reveals the full received list and can collapse back to the top-five view.
- Verification:
  - `testArtistPopularTracksPresentationDefaultsToTopFiveAndCanExpand` failed as the intended compile-time RED before the helper existed;
  - the focused Phase 16 test passed after implementation;
  - the broader artist/header/popular-tracks/catalog slice passed 8 tests.

## Lyrics Interactivity

- Phase 7 trace found synced lyrics already had timestamped `TrackLyricsLine` values and active-line selection through `TrackLyrics.activeLineIndex(at:)`.
- Root cause for the click-to-seek gap was that `LyricsLineView` rendered text only, with no action wired to `PlayerStore`.
- A second root cause was the ambiguous `PlayerStore.seek(to:)` API: tests and lyrics need absolute seconds, while progress sliders were passing a 0...1 fraction.
- `PlayerStore.seek(to:)` now accepts absolute playback seconds and clamps to the current track duration.
- `PlayerStore.seek(toFraction:)` is the dedicated slider/progress API and converts a fraction into absolute seconds before using the shared seek path.
- `LyricsReaderContentView` now renders synchronized lines as plain-styled buttons that call `store.seek(to: line.startTime)`.
- Active-line highlighting and `ScrollViewReader` sync still derive from `store.progress`, so lyric clicks update the same state used for playback progress and active-line movement.
- Plain lyrics without timestamped lines now show an explicit `Unsynced` state and remain text-only; no fake seek targets are generated.

## Mini Player Contrast

- Phase 8 trace found the mini player was darkened twice: native glass/material plus an additional black tint/fill. That made controls and mint/accent elements feel submerged.
- `MiniPlayerVisualStyle` now centralizes the contrast-sensitive player tokens so the readable treatment is regression-testable.
- macOS 26 glass tint and legacy fallback black fill were reduced to `0.06` opacity.
- Inactive player controls now use `0.68` opacity at rest and `0.88` on hover instead of sitting near half-white.
- Active mode/panel fills and strokes use shared tokens for a clearer glass/accent state.
- The primary play/pause button keeps the compact circular form but now has a stronger white stroke and a subtle accent glow.
- The mini progress rail is thicker and brighter, with a small accent glow on the filled segment so mint/accent progress remains readable.
- Layout, widths, compact breakpoints, metadata navigation, queue/lyrics/sound toggles, and playback behavior were preserved.

## Sidebar Palette

- Phase 9 trace found sidebar color drift in raw white/green opacity values, gray search focus, and playlist-row accent derived from current track or collection palettes.
- `SidebarVisualStyle` now centralizes sidebar material dimming, brand mark, active marker, active fill/stroke, inactive text/icon, hover, and search focus tokens.
- Sidebar search focus now uses the app primary accent instead of an unrelated gray/white stroke, while keeping a compact native search-field shape.
- Active sidebar items use a narrow accent marker plus subtle glass fill/stroke rather than a heavy debug-style filled state.
- `SidebarPlaylistRow.accent` now returns `NoirwaveTheme.primaryAccent`, preventing current-track artwork or playlist artwork palettes from changing sidebar navigation color.
- The existing sidebar structure and destination behavior were preserved; this phase only stabilized palette, active/hover treatment, and native music-app composition.

## Sidebar Playlists

- Phase 10 chose master-plan path B: keep the sidebar playlist block, but make it production-ready instead of leaving a mixed placeholder/synthetic collection shelf.
- Root cause: `SidebarPlaylistPreview` mixed real `LocalPlaylist` rows with `liked.songs`, `discovery.mix`, top album, and top artist rows, all under a `Playlists` heading. That made non-playlist data look like sidebar playlists and could surface filler/discovery content.
- `SidebarPlaylistPreviewBuilder` now exposes the sidebar playlist contract: it accepts only `[LocalPlaylist]` plus a track resolver and emits `SidebarPlaylistPreviewItem` rows for real local playlists.
- `SidebarPlaylistPreview` now uses `store.localPlaylists` and `store.playlistTracks(playlistID:)` only. It no longer reads liked tracks, featured tracks, or saved collection groupings.
- Empty sidebar playlist state is an explicit create-playlist button/row. The header also has an icon-only create button wired to the existing playlist editor sheet.
- Clicking a sidebar playlist selects the Library destination and the matching local playlist selection; no non-playlist row calls `playAll(...)` from the sidebar block anymore.

## Regression Checklist

- Phase 11 covered the master-plan regression lock with a 20-test Swift slice spanning bootstrap/loading, artist top-count copy, single-search routing, search playback, catalog navigation, Library playlist data boundaries, lyrics seek, mini-player contrast tokens, sidebar palette tokens, and sidebar playlist data boundaries.
- Backend regression coverage was rerun through the test suite and passed 37/37, including the no-internal-100-cap public artist pagination test.
- Source scans confirmed:
  - only one catalog search input exists: `SidebarSearchField` with `Search catalog`;
  - other `TextField`s are playlist naming, Library/playlist filters, or queue filtering;
  - app sources no longer contain hardcoded Nirvana/Daft Punk/fake content in the checked scope;
  - sidebar playlist synthetic rows (`discovery.mix`, `Noirwave Mix`, derived album/artist rows) are gone;
  - `publicArtistDetailItemLimit` and old public artist `limit = 100` cap patterns are absent;
  - touched task files and docs have no real conflict markers.
- The mini-player contrast check is token-driven through `MiniPlayerVisualStyle`; remaining raw opacity literals from the broader scan are in Library/search filters, the floating panel, queue/settings/import surfaces, not the mini-player contrast path.

## Mandatory Documentation Coverage

- Regressions found are recorded in `docs/BUGS_AND_REGRESSIONS.md` under "Regressions Found During This Work".
- Regressions fixed are recorded in `docs/BUGS_AND_REGRESSIONS.md` under "Fixed" and summarized in `docs/CHANGELOG.md`.
- Files touched are listed in `docs/CHANGELOG.md` under "Files Touched"; durable stabilization state files are also tracked in `docs/STABILIZATION_PROGRESS.md` and `docs/HANDOFF.md`.
- Verification coverage is recorded in `docs/BUGS_AND_REGRESSIONS.md` under "Checks Passed" and in this file under "Regression Checklist".
- Search verification:
  - `testSearchResultsStayScopedToCatalogDestination`;
  - source scan showed one catalog search field: `SidebarSearchField` / `Search catalog`;
  - non-catalog text fields are playlist naming, Library/playlist filters, or queue filtering.
- Playback verification:
  - `testActivatingCurrentSearchTrackTogglesPlaybackInsteadOfRestarting`;
  - `testActivatingSearchResultUsesVisibleResultsForPlaybackContext`;
  - same-track search activation now toggles shared playback instead of replaying provider playback.
- Library verification:
  - `testLibrarySurfaceLayoutPlacesPlaylistsAtBottom`;
  - `testLibraryPlaylistShelfBuilderKeepsLikedSongsOutOfPlaylistShelf`;
  - `testLibraryPlaylistShelfBuilderFiltersOnlyRealLocalPlaylists`;
  - app-source scan found no hardcoded Nirvana/Daft Punk/fake Library filler.
- Lyrics verification:
  - `testTrackLyricsSelectsActiveSynchronizedLine`;
  - `testLyricsSeekUpdatesProgressAndForwardsToProvider`;
  - `testProgressSliderSeekUsesFractionOfCurrentTrackDuration`;
  - synced lyric rows seek by absolute timestamp while unsynced lyrics remain text-only.
- Sidebar/player verification:
  - `testMiniPlayerVisualStyleKeepsGlassReadable`;
  - `testSidebarVisualStyleUsesControlledNativePalette`;
  - `testSidebarPlaylistPreviewBuilderUsesOnlyRealLocalPlaylists`;
  - source scans removed synthetic sidebar playlist rows and confirmed mini-player contrast is locked by tokens.
- The two-search regression should not return because `CatalogLandingView` is passive, `SidebarSearchField` owns `PlayerStore.searchQuery`, and `ContentDeckRouting.showsSearchResults(...)` only shows results when Catalog is active and no catalog detail is open.
- The "100 tracks" value came from Deezer public artist top-track data plus the old backend `publicArtistDetailItemLimit = 100` cap. The backend no longer imposes that hidden cap, but docs and UI copy now treat `100 Deezer top tracks` as an upstream top-track window, not a full artist track total.

## No Fake Completion

- Phase 13 checked durable docs for overbroad completion claims.
- `docs/STABILIZATION_PROGRESS.md` is the canonical status: phases 1-13 are complete, Phase 14 is active, and phases 15-18 remain not started.
- `docs/HANDOFF.md` records the same active phase and keeps the pre-existing unmerged git index as a remaining issue.
- Changelog/notes describe completed phase slices, not the entire stabilization plan as complete.

## Artwork Pipeline

- Raw `AsyncImage` is not used for app artwork cards.
- `ArtworkTile` routes all artwork requests through `ArtworkImagePipeline`.
- `ArtworkImagePipeline` includes:
  - in-memory `NSCache`;
  - manual disk cache keyed by stable normalized URL and target size;
  - Apple `URLCache` backed by `URLSessionConfiguration`;
  - stable SHA-256 cache keys;
  - downsampling via ImageIO before rendering;
  - retry cooldown for failed URLs;
  - in-flight request coalescing;
  - cancellable offscreen consumers;
  - priority scheduling for high, visible, and low artwork requests;
  - prefetch cancellation and priority upgrade;
  - DEBUG logging for memory/disk/URLCache hits, misses, network responses, HTTP cache headers, failures, cooldowns, cancellations, and priority upgrades.
- Nuke/NukeUI and Kingfisher best-practice review was applied as local pipeline behavior: hybrid memory/disk caching, downsampling, prefetching, task cancellation, request priority, retry control, and cache-key stability. No external image package was added so the app keeps one `ArtworkPipeline` and avoids dependency churn.

## Tests Added Or Updated

- Backend:
  - `follows paginated public artist top tracks beyond the first page`.
  - `does not impose an internal 100 item cap on paginated public artist top tracks`.
- Swift:
  - `testArtistPopularTracksSubtitleDescribesDeezerTopWindow`.
  - `testSearchResultsStayScopedToCatalogDestination`.
  - `testCatalogDetailStaysScopedToCatalogDestination`.
  - `testLeavingCatalogDetailWithEmptyQueryCancelsLateDetailResponse`.
  - `testLibrarySurfaceLayoutPlacesPlaylistsAtBottom`.
  - `testLibraryPlaylistShelfBuilderKeepsLikedSongsOutOfPlaylistShelf`.
  - `testLibraryPlaylistShelfBuilderFiltersOnlyRealLocalPlaylists`.
  - `testActivatingCurrentSearchTrackTogglesPlaybackInsteadOfRestarting`.
  - `testActivatingSearchResultUsesVisibleResultsForPlaybackContext`.
  - `testLyricsSeekUpdatesProgressAndForwardsToProvider`.
  - `testProgressSliderSeekUsesFractionOfCurrentTrackDuration`.
  - `testMiniPlayerVisualStyleKeepsGlassReadable`.
  - `testSidebarVisualStyleUsesControlledNativePalette`.
  - `testSidebarPlaylistPreviewBuilderUsesOnlyRealLocalPlaylists`.
  - `testArtistCatalogComposerDoesNotTruncatePopularTracks`.
  - `testCatalogRequestWindowsAreExpandedPastPreviewLimits`.
  - track mapper assertions for `artistCatalogID` and `albumCatalogID`.
  - test doubles updated for `MusicProviding.radioTracks(seed:)`.
