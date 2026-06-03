import test from "node:test";
import assert from "node:assert/strict";
import {
  albumPayload,
  artistPayload,
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
  assert.equal(album.record_type, "album");
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
