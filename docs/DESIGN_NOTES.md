# Design Notes

## Stabilization Direction

- Loading catalog data must not imply playback. The mini player and now-playing surfaces should stay empty or show the previous real playback state until the user explicitly starts a track.
- Phase 1 design language remains compact premium glass, but loading should be represented with clean skeleton/empty states rather than seed tracks or fake content.
- Skeletons use neutral blocks only: no fake covers, no fake names, no visible placeholder artists.
- Initial catalog surfaces should prefer an honest empty state over recognizable public-track filler. No specific artist/track should appear unless it comes from real library data, search results, navigation context, or explicit playback.
- Artist popular-track counts must describe the source accurately. A Deezer top-track window is not the artist's full discography, so UI copy should avoid implying that "100 tracks" is a total artist track count.
- Sidebar search is the single catalog search control. Catalog is the search/results destination, while Library, Listen Now, and Profile remain navigable even if the sidebar query text is still present.
- Search result playback should behave like native music lists: first click starts the shared player, the active row reflects `currentTrack`, and clicking the active playable item toggles pause instead of restarting the stream.
- Search input should feel local and immediate. Typing must not blank the app, reset playback, or replace the search surface with a large loading wall; remote work is allowed only behind debounce/cache/cancellation, with a small inline spinner in the sidebar/results area.
- Search result display should not wait for playback warmup. Playback prefetch can run in the background after the result payload is ready; the user should see and navigate results first.
- Performance/loading direction is shell-first and data-after: sidebar, navigation, player, and existing content stay usable while search/detail/lyrics/artwork work is pending.
- Slow-network behavior for the native app is verified through delayed-provider regressions rather than browser DevTools throttling. The design contract is still the same: local input response, stable previous content, granular loading, and uninterrupted playback controls.

## Direction

The target direction is premium native music app with liquid-glass surfaces, compact density, and high-contrast media-led hierarchy. The mini player was treated as the quality bar and kept visually intact.

## Sidebar

- The sidebar should read as part of the player chrome, not as admin navigation.
- It uses glass material, soft border highlights, small hover changes, and compact row rhythm.
- The active nav state uses subtle highlight and an accent marker instead of a heavy green filled pill.
- Search is compact and calm; it is a command entry point, not a hero element.
- Playlists use native-list rows instead of isolated cards.
- Phase 9 locks the sidebar to one native-glass palette: app accent for selected/focused affordances, readable inactive labels/icons, and no artwork-driven accent drift in navigation rows.
- Search focus should feel like the same sidebar command field, not a second visual search surface or a gray debug input.
- Sidebar Playlists means real local playlists only. Liked Songs belongs to Library, discovery mixes belong to catalog/listening surfaces, and derived album/artist groupings belong to saved collections, not the bottom sidebar playlist block.
- The empty sidebar playlist state should invite creation with one compact native row; it must not backfill the space with recognizable public artists or generated collection names.
- Phase 11 regression verification preserves the current design boundaries: one sidebar catalog search, native compact Library/playlists, clickable synced lyrics, readable glass mini player, controlled sidebar palette, and no fake loading/library/sidebar playlist content.
- Phase 12 docs audit records these boundaries as stabilization constraints rather than optional visual preferences, so future visual work has to preserve the single-search/player/Library/lyrics/sidebar contracts.
- Phase 13 keeps visual stabilization scoped honestly: the current design contracts are locked, but search input UX, artist header density, popular-track list density, and performance/loading phases still need their own work.
- Phase 14 finishes the search-input part of that contract: one sidebar command field, local typing, compact spinner feedback, cached repeated queries, and no full-panel searching replacement while the user is still typing.

## Library

- Library hierarchy is liked songs first, real playlists below, saved collections last.
- Liked Songs should read as a large primary surface, not as a small synthetic playlist tile.
- Favorite tracks use an adaptive two-column list on wider windows and collapse naturally through the grid minimum width.
- The playlist shelf includes a visible create tile so playlist creation is discoverable even when there are no local playlists yet.
- Library content must come from real liked tracks, saved collections, and local playlists; empty states stay explicit instead of showing recognizable filler artists.

## Right Panel

- Lyrics, Queue, and Sound are a floating utility widget.
- The widget is inset from top, right, and bottom and constrained to about 360-430 px.
- The surface uses glass, border, highlight, and shadow rather than a dark brown gradient wall.
- Tabs are compact controls inside the widget chrome.

## Lyrics

- Synchronized lyrics should behave like native music app lyric readers: the active line is visually prominent, the view scrolls with playback, and clicking a line seeks the same player timeline.
- Unsynced lyrics should be honest text content. The UI marks them as unsynced and does not invent click targets or fake timestamps.
- Loaded lyrics should remain immediately available for repeated playback of the same track. The lyrics panel should not flash a loading state when cached lyrics can be shown synchronously.

## Artist Profile

- The artist page follows the large-player pattern used by Apple Music, Spotify, and Tidal:
  - image-led hero;
  - large artist name;
  - stats and metadata;
  - primary Play action;
  - Shuffle and Follow actions;
  - latest release feature;
  - popular tracks;
  - albums and secondary releases.
- Repeated sections keep existing functional structure but add depth, spacing, hover states, and clearer media hierarchy.
- Phase 15 changes the artist page from oversized hero-banner behavior to dense native music-app behavior. The hero should remain media-led and premium, but it must be short enough that latest release and the start of popular tracks are visible in a 1280x900-style desktop viewport.
- Artist header density is now a design contract, not a one-off visual tweak: `ArtistHeaderLayoutMetrics` owns hero height, artwork scale, title size, action height, latest-release row height, and first-viewport fit.
- Do not reintroduce a giant blurred wall or oversized portrait to compensate for hierarchy. The artist page should feel like a playable catalog surface first, with the hero acting as context and controls.
- Phase 16 keeps popular tracks honest but scannable: the subtitle may describe the full Deezer top-track window, but the page should show only the top five rows until the user asks for more.
- The Show more / Show less control belongs directly under the popular-track rows and should feel like a compact native list affordance, not a separate promo card or modal.
- Do not hide the full list permanently and do not render all 100 rows by default. This page should open as an artist overview, not a long track database.
- Reopening an artist or album already loaded in the current session should feel instant. Do not show an empty/optimistic loading pass when cached detail items can be rendered immediately.
- Loading an artist for the first time may show a scoped artist-detail skeleton when no detail content exists yet, but it must not block the app shell or other destinations.

## Mini Player

- The mini player remains the stable visual anchor.
- Only click affordances were added:
  - artwork and title navigate to album;
  - artist navigates to artist;
  - hover scale/cursor feedback marks interactive metadata.
- Phase 8 keeps the mini player compact and premium, but its glass surface should read as translucent chrome rather than a black pill.
- Inactive controls stay quiet but legible; the primary play/pause button must remain the clearest affordance in the bar.
- Progress uses the track accent with enough rail contrast to read on dark glass.

## Avoided Patterns

- No random blur/gradient decoration was used to fake premium UI.
- No nested-card redesign was added.
- No second search field was kept.
- No 12/24/50 item hardcaps were used for the requested popular-track and catalog surfaces.
- No hardcoded startup catalog seed content is part of the loading experience.
- No visual polish should be used to hide architectural waiting. If a surface can keep stale/cached content and load a small piece in place, prefer that over a blank route or full-screen loader.
