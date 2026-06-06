import test from "node:test";
import assert from "node:assert/strict";
import {
  albumPayload,
  artistPayload,
  splitArtistReleases,
  sortTracksByAlbumPosition,
  sortTracksByPopularity,
  trackPayload,
} from "../src/catalogMapper.mjs";

test("maps GraphQL track to old-compatible payload", () => {
  const payload = trackPayload({
    id: "13791932",
    title: "Come As You Are",
    duration: 218,
    popularity: 95.4,
    is_explicit: false,
    disk_info: { disk_number: 1, track_number: 3 },
    contributors: { edges: [{ node: { id: "415", name: "Nirvana" } }] },
    album: {
      id: "1262014",
      display_title: "Nevermind (Remastered)",
      cover: { urls: ["small.jpg", "large.jpg"] },
    },
    media: { rights: { sub: { available: true } } },
  });

  assert.equal(payload.id, "13791932");
  assert.equal(payload.artist.name, "Nirvana");
  assert.equal(payload.album.title, "Nevermind (Remastered)");
  assert.equal(payload.album.cover_xl, "large.jpg");
  assert.equal(payload.rank, 954000);
  assert.equal(payload.track_position, 3);
});

test("maps artist and album metadata for cards", () => {
  const artist = artistPayload({
    id: "415",
    name: "Nirvana",
    fans_count: 9999165,
    albums_count: 25,
    picture: { urls: ["artist.jpg"] },
  });
  const album = albumPayload({
    id: "1262014",
    display_title: "Nevermind (Remastered)",
    type_: "ALBUM",
    tracks_count: 13,
    release_date: "2011-09-27",
    contributors: { edges: [{ node: { id: "415", name: "Nirvana" } }] },
    cover: { urls: ["cover.jpg"] },
  });

  assert.equal(artist.nb_fan, 9999165);
  assert.equal(artist.nb_album, 25);
  assert.equal(album.nb_tracks, 13);
  assert.equal(album.record_type, "studio");
});

test("sorts top tracks and album tracklist deterministically", () => {
  assert.deepEqual(sortTracksByPopularity([
    { title: "B", rank: 10 },
    { title: "A", rank: 30 },
  ]).map((item) => item.title), ["A", "B"]);

  assert.deepEqual(sortTracksByAlbumPosition([
    { title: "Two", disk_number: 1, track_position: 2 },
    { title: "One", disk_number: 1, track_position: 1 },
    { title: "Disc Two", disk_number: 2, track_position: 1 },
  ]).map((item) => item.title), ["One", "Two", "Disc Two"]);
});

test("separates studio albums from anniversary live and deluxe reissues", () => {
  const artistContext = { id: "415", name: "Nirvana" };
  const releases = [
    albumPayload({
      id: "30-live",
      display_title: "In Utero 30th Live",
      type_: "ALBUM",
      tracks_count: 4,
      release_date: "2023-10-27",
      contributors: { edges: [{ node: artistContext }] },
      cover: { urls: ["live.jpg"] },
    }),
    albumPayload({
      id: "in-utero",
      display_title: "In Utero",
      type_: "ALBUM",
      tracks_count: 12,
      release_date: "1993-09-21",
      contributors: { edges: [{ node: artistContext }] },
      cover: { urls: ["in-utero.jpg"] },
    }),
    albumPayload({
      id: "nevermind-deluxe",
      display_title: "Nevermind (Deluxe Edition)",
      type_: "ALBUM",
      tracks_count: 42,
      release_date: "2011-09-27",
      contributors: { edges: [{ node: artistContext }] },
      cover: { urls: ["nevermind-deluxe.jpg"] },
    }),
    albumPayload({
      id: "nevermind",
      display_title: "Nevermind",
      type_: "ALBUM",
      tracks_count: 13,
      release_date: "1991-09-24",
      contributors: { edges: [{ node: artistContext }] },
      cover: { urls: ["nevermind.jpg"] },
    }),
  ];

  const grouped = splitArtistReleases(releases);

  assert.equal(releases[0].record_type, "live");
  assert.equal(releases[1].record_type, "studio");
  assert.equal(releases[2].record_type, "reissue");
  assert.deepEqual(grouped.studio.map((album) => album.title), ["In Utero", "Nevermind"]);
  assert.deepEqual(grouped.other.map((album) => album.title), ["In Utero 30th Live", "Nevermind (Deluxe Edition)"]);

  const legacyGrouped = splitArtistReleases(releases.map((release) => ({
    ...release,
    record_type: "album",
  })));
  assert.deepEqual(legacyGrouped.studio.map((album) => album.title), ["In Utero", "Nevermind"]);
  assert.deepEqual(legacyGrouped.other.map((album) => album.title), ["In Utero 30th Live", "Nevermind (Deluxe Edition)"]);
});
