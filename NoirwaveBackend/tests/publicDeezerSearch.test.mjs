import test from "node:test";
import assert from "node:assert/strict";
import {
  publicDeezerAlbumDetail,
  publicDeezerArtistDetail,
  publicDeezerArtistTracks,
  publicDeezerSearch,
} from "../src/publicDeezerSearch.mjs";

const jsonResponse = (json, options = {}) => ({
  ok: options.ok ?? true,
  status: options.status ?? 200,
  json: async () => json,
});

test("calls scoped Deezer public search and preserves old-compatible payload shape", async () => {
  let requestedURL;
  const fetchImpl = async (url) => {
    requestedURL = url;
    return jsonResponse({
      data: [{
        id: 13791932,
        title: "Come As You Are",
        artist: { id: 415, name: "Nirvana" },
        album: { id: 1262014, title: "Nevermind (Remastered)" },
      }],
      total: 1,
    });
  };

  const payload = await publicDeezerSearch(
    { query: "nirvana", scope: "track", count: 10 },
    { fetchImpl }
  );

  assert.equal(requestedURL.pathname, "/search/track");
  assert.equal(requestedURL.searchParams.get("q"), "nirvana");
  assert.equal(requestedURL.searchParams.get("limit"), "10");
  assert.equal(payload.type, "track");
  assert.equal(payload.source, "deezer-public-search");
  assert.equal(payload.total, 1);
  assert.equal(payload.data[0].artist.name, "Nirvana");
});

test("allows expanded public search pages for desktop catalog results", async () => {
  let requestedURL;
  const fetchImpl = async (url) => {
    requestedURL = url;
    return jsonResponse({ data: [], total: 0 });
  };

  await publicDeezerSearch(
    { query: "nirvana", scope: "track", count: 80 },
    { fetchImpl }
  );

  assert.equal(requestedURL.searchParams.get("limit"), "80");
});

test("uses 100-item Deezer pages while collecting expanded public search results", async () => {
  const requestedPaths = [];
  const fetchImpl = async (url) => {
    requestedPaths.push(`${url.pathname}?${url.searchParams.toString()}`);
    const index = Number(url.searchParams.get("index") ?? 0);
    const pageStart = index === 0 ? 0 : index;
    const pageSize = 100;
    const data = Array.from({ length: pageSize }, (_, offset) => {
      const id = pageStart + offset;
      return { id, title: `Nirvana Track ${id}`, artist: { id: 415, name: "Nirvana" } };
    });
    const nextIndex = pageStart + pageSize;
    return jsonResponse({
      data,
      total: 260,
      next: nextIndex < 260
        ? `https://api.deezer.com/search/track?q=nirvana&limit=100&index=${nextIndex}`
        : null,
    });
  };

  const payload = await publicDeezerSearch(
    { query: "nirvana", scope: "track", count: 250 },
    { fetchImpl }
  );

  assert.deepEqual(requestedPaths, [
    "/search/track?q=nirvana&limit=100",
    "/search/track?q=nirvana&limit=100&index=100",
    "/search/track?q=nirvana&limit=100&index=200",
  ]);
  assert.equal(payload.data.length, 250);
  assert.equal(payload.total, 260);
});

test("follows paginated public search results until requested count is reached", async () => {
  const requestedPaths = [];
  const fetchImpl = async (url) => {
    requestedPaths.push(`${url.pathname}?${url.searchParams.toString()}`);
    if (url.searchParams.get("index") === "2") {
      return jsonResponse({
        data: [
          { id: 112, title: "Heart-Shaped Box", artist: { id: 415, name: "Nirvana" } },
          { id: 113, title: "Rape Me", artist: { id: 415, name: "Nirvana" } },
        ],
        total: 4,
      });
    }

    return jsonResponse({
      data: [
        { id: 110, title: "Serve The Servants", artist: { id: 415, name: "Nirvana" } },
        { id: 111, title: "Scentless Apprentice", artist: { id: 415, name: "Nirvana" } },
      ],
      total: 4,
      next: "https://api.deezer.com/search/track?q=nirvana&limit=4&index=2",
    });
  };

  const payload = await publicDeezerSearch(
    { query: "nirvana", scope: "track", count: 4 },
    { fetchImpl }
  );

  assert.deepEqual(requestedPaths, [
    "/search/track?q=nirvana&limit=4",
    "/search/track?q=nirvana&limit=4&index=2",
  ]);
  assert.deepEqual(payload.data.map((track) => track.title), [
    "Serve The Servants",
    "Scentless Apprentice",
    "Heart-Shaped Box",
    "Rape Me",
  ]);
});

test("filters weak artist contains and low-audience prefix variants", async () => {
  const fetchImpl = async () => jsonResponse({
    data: [
      { id: 281527041, name: "Nirvana (UK)", nb_fan: 133, nb_album: 5 },
      { id: 1429039, name: "Approaching Nirvana", nb_fan: 9856, nb_album: 113 },
      { id: 900, name: "Nirvana", nb_fan: 15, nb_album: 1 },
      { id: 415, name: "Nirvana", nb_fan: 10_001_396, nb_album: 25 },
    ],
    total: 4,
  });

  const payload = await publicDeezerSearch(
    { query: "nirvana", scope: "artist", count: 10 },
    { fetchImpl }
  );

  assert.deepEqual(payload.data.map((artist) => artist.id), [415]);
});

test("maps Deezer public API errors to backend-safe failures", async () => {
  const fetchImpl = async () => jsonResponse({
    error: { type: "Exception", message: "Quota exceeded" },
  });

  await assert.rejects(
    () => publicDeezerSearch({ query: "nirvana", scope: "artist" }, { fetchImpl }),
    { name: "PublicDeezerSearchError", message: "Quota exceeded" }
  );
});

test("maps full public album detail with track metadata", async () => {
  let requestedURL;
  const fetchImpl = async (url) => {
    requestedURL = url;
    return jsonResponse({
      id: 14135832,
      title: "In Utero",
      link: "https://www.deezer.com/album/14135832",
      cover_xl: "https://cdn-images.dzcdn.net/images/cover/in-utero-xl.jpg",
      artist: { id: 415, name: "Nirvana" },
      nb_tracks: 12,
      fans: 221_000,
      release_date: "1993-09-21",
      record_type: "album",
      tracks: {
        data: [
          {
            id: 110,
            readable: true,
            title: "Serve The Servants",
            link: "https://www.deezer.com/track/110",
            duration: 216,
            rank: 500_000,
            explicit_lyrics: false,
            artist: { id: 415, name: "Nirvana" },
            track_position: 1,
            disk_number: 1,
          },
          {
            id: 111,
            readable: true,
            title: "Scentless Apprentice",
            link: "https://www.deezer.com/track/111",
            duration: 228,
            rank: 490_000,
            explicit_lyrics: false,
            artist: { id: 415, name: "Nirvana" },
            track_position: 2,
            disk_number: 1,
          },
        ],
      },
    });
  };

  const payload = await publicDeezerAlbumDetail({ id: 14135832 }, { fetchImpl });

  assert.equal(requestedURL.pathname, "/album/14135832");
  assert.equal(payload.title, "In Utero");
  assert.equal(payload.record_type, "studio");
  assert.equal(payload.nb_tracks, 12);
  assert.equal(payload.tracks.length, 2);
  assert.equal(payload.tracks[0].album.title, "In Utero");
  assert.equal(payload.tracks[0].track_position, 1);
});

test("follows paginated public album tracklists until declared count is reached", async () => {
  const requestedPaths = [];
  const fetchImpl = async (url) => {
    requestedPaths.push(url.pathname);
    if (url.pathname === "/album/14135832") {
      return jsonResponse({
        id: 14135832,
        title: "In Utero",
        link: "https://www.deezer.com/album/14135832",
        cover_xl: "https://cdn-images.dzcdn.net/images/cover/in-utero-xl.jpg",
        artist: { id: 415, name: "Nirvana" },
        nb_tracks: 4,
        release_date: "1993-09-21",
        record_type: "album",
        tracks: {
          data: [
            { id: 110, title: "Serve The Servants", duration: 216, artist: { id: 415, name: "Nirvana" } },
            { id: 111, title: "Scentless Apprentice", duration: 228, artist: { id: 415, name: "Nirvana" } },
          ],
          next: "https://api.deezer.com/album/14135832/tracks?index=2",
        },
      });
    }

    return jsonResponse({
      data: [
        { id: 112, title: "Heart-Shaped Box", duration: 281, artist: { id: 415, name: "Nirvana" } },
        { id: 113, title: "Rape Me", duration: 170, artist: { id: 415, name: "Nirvana" } },
      ],
    });
  };

  const payload = await publicDeezerAlbumDetail({ id: 14135832 }, { fetchImpl });

  assert.deepEqual(requestedPaths, ["/album/14135832", "/album/14135832/tracks"]);
  assert.deepEqual(payload.tracks.map((track) => track.title), [
    "Serve The Servants",
    "Scentless Apprentice",
    "Heart-Shaped Box",
    "Rape Me",
  ]);
});

test("maps public artist detail with top tracks and release groups", async () => {
  const requestedPaths = [];
  const fetchImpl = async (url) => {
    requestedPaths.push(url.pathname);
    if (url.pathname === "/artist/415") {
      return jsonResponse({
        id: 415,
        name: "Nirvana",
        link: "https://www.deezer.com/artist/415",
        picture_xl: "https://cdn-images.dzcdn.net/images/artist/nirvana-xl.jpg",
        nb_album: 25,
        nb_fan: 10_001_682,
      });
    }

    if (url.pathname === "/artist/415/top") {
      return jsonResponse({
        data: [
          {
            id: 13791932,
            readable: true,
            title: "Come As You Are",
            link: "https://www.deezer.com/track/13791932",
            duration: 218,
            rank: 900_000,
            artist: { id: 415, name: "Nirvana" },
            album: { id: 1262014, title: "Nevermind", artist: { id: 415, name: "Nirvana" } },
          },
        ],
      });
    }

    return jsonResponse({
      data: [
        {
          id: 14135832,
          title: "In Utero",
          link: "https://www.deezer.com/album/14135832",
          artist: { id: 415, name: "Nirvana" },
          nb_tracks: 12,
          release_date: "1993-09-21",
          record_type: "album",
        },
        {
          id: 682652511,
          title: "In Utero 30th Live",
          link: "https://www.deezer.com/album/682652511",
          artist: { id: 415, name: "Nirvana" },
          nb_tracks: 4,
          release_date: "2023-10-27",
          record_type: "album",
        },
      ],
    });
  };

  const payload = await publicDeezerArtistDetail({ id: 415 }, { fetchImpl });

  assert.deepEqual(requestedPaths, ["/artist/415", "/artist/415/top", "/artist/415/albums"]);
  assert.equal(payload.name, "Nirvana");
  assert.equal(payload.top_tracks.length, 1);
  assert.equal(payload.releases.studio.length, 1);
  assert.equal(payload.releases.other.length, 1);
  assert.equal(payload.releases.studio[0].title, "In Utero");
  assert.equal(payload.releases.other[0].record_type, "live");
});

test("follows paginated public artist albums for full release groups", async () => {
  const requestedPaths = [];
  const fetchImpl = async (url) => {
    requestedPaths.push(`${url.pathname}?${url.searchParams.toString()}`);

    if (url.pathname === "/artist/415") {
      return jsonResponse({
        id: 415,
        name: "Nirvana",
        link: "https://www.deezer.com/artist/415",
        nb_album: 4,
        nb_fan: 10_001_682,
      });
    }

    if (url.pathname === "/artist/415/top") {
      return jsonResponse({ data: [] });
    }

    if (url.searchParams.get("index") === "2") {
      return jsonResponse({
        data: [
          { id: 3, title: "MTV Unplugged", artist: { id: 415, name: "Nirvana" }, nb_tracks: 14, record_type: "album" },
          { id: 4, title: "Bleach", artist: { id: 415, name: "Nirvana" }, nb_tracks: 13, record_type: "album" },
        ],
      });
    }

    return jsonResponse({
      data: [
        { id: 1, title: "Nevermind", artist: { id: 415, name: "Nirvana" }, nb_tracks: 12, record_type: "album" },
        { id: 2, title: "In Utero", artist: { id: 415, name: "Nirvana" }, nb_tracks: 12, record_type: "album" },
      ],
      next: "https://api.deezer.com/artist/415/albums?limit=100&index=2",
    });
  };

  const payload = await publicDeezerArtistDetail({ id: 415 }, { fetchImpl });

  assert.deepEqual(requestedPaths, [
    "/artist/415?",
    "/artist/415/top?limit=100",
    "/artist/415/albums?limit=100",
    "/artist/415/albums?limit=100&index=2",
  ]);
  assert.equal(payload.releases.studio.length + payload.releases.other.length, 4);
});

test("collects all public artist tracks from release albums", async () => {
  const requestedPaths = [];
  const fetchImpl = async (url) => {
    requestedPaths.push(url.pathname);

    if (url.pathname === "/artist/415") {
      return jsonResponse({
        id: 415,
        name: "Nirvana",
        link: "https://www.deezer.com/artist/415",
        nb_album: 2,
        nb_fan: 10_001_682,
      });
    }

    if (url.pathname === "/artist/415/albums") {
      return jsonResponse({
        data: [
          { id: 1262014, title: "Nevermind", artist: { id: 415, name: "Nirvana" }, nb_tracks: 2 },
          { id: 14135832, title: "In Utero", artist: { id: 415, name: "Nirvana" }, nb_tracks: 3 },
        ],
      });
    }

    if (url.pathname === "/album/1262014") {
      return jsonResponse({
        id: 1262014,
        title: "Nevermind",
        artist: { id: 415, name: "Nirvana" },
        tracks: {
          data: [
            { id: 13791932, title: "Come As You Are", artist: { id: 415, name: "Nirvana" } },
            { id: 13791931, title: "Smells Like Teen Spirit", artist: { id: 415, name: "Nirvana" } },
          ],
        },
      });
    }

    if (url.pathname === "/album/14135832") {
      return jsonResponse({
        id: 14135832,
        title: "In Utero",
        artist: { id: 415, name: "Nirvana" },
        tracks: {
          data: [
            { id: 112, title: "Heart-Shaped Box", artist: { id: 415, name: "Nirvana" } },
            { id: 113, title: "Rape Me", artist: { id: 415, name: "Nirvana" } },
            { id: 114, title: "Compilation Guest", artist: { id: 999, name: "Other Artist" } },
          ],
        },
      });
    }

    return jsonResponse({ data: [] });
  };

  const payload = await publicDeezerArtistTracks({ id: 415 }, { fetchImpl });

  assert.deepEqual(requestedPaths, [
    "/artist/415",
    "/artist/415/albums",
    "/album/1262014",
    "/album/14135832",
  ]);
  assert.equal(payload.type, "artist-tracks");
  assert.equal(payload.total, 4);
  assert.deepEqual(payload.data.map((track) => track.title), [
    "Come As You Are",
    "Smells Like Teen Spirit",
    "Heart-Shaped Box",
    "Rape Me",
  ]);
});
