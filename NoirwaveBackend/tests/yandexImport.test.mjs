import test from "node:test";
import assert from "node:assert/strict";
import {
  normalizeYandexToken,
  normalizeYandexTrack,
  parseYandexExport,
} from "../src/yandexImport.mjs";

test("validates yandex oauth token shape without exposing token content", () => {
  assert.equal(normalizeYandexToken("short"), null);
  assert.equal(normalizeYandexToken("abcdefghijklmnopqrstuvwxyz123456"), "abcdefghijklmnopqrstuvwxyz123456");
});

test("normalizes yandex track metadata for matching", () => {
  const track = normalizeYandexTrack({
    id: 101,
    title: "Ai Cowboy",
    artists: [{ name: "Brenno" }, { name: "Matheus" }],
    albums: [{ id: 202, title: "Single", cover_uri: "avatars.yandex.net/get-music-content/%%" }],
    duration_ms: 184000,
  });

  assert.deepEqual(track, {
    id: "101:202",
    title: "Ai Cowboy",
    artist: "Brenno, Matheus",
    album: "Single",
    duration: 184,
    artworkURL: "https://avatars.yandex.net/get-music-content/400x400",
  });
});

test("parses yandex json export with embedded short tracks", () => {
  const tracks = parseYandexExport(JSON.stringify({
    library: {
      tracks: [{
        track: {
          id: "1",
          title: "Come As You Are",
          artists: [{ name: "Nirvana" }],
          albums: [{ title: "Nevermind" }],
        },
      }],
    },
  }));

  assert.equal(tracks.length, 1);
  assert.equal(tracks[0].title, "Come As You Are");
  assert.equal(tracks[0].artist, "Nirvana");
});

test("parses csv export with title and artist headers", () => {
  const tracks = parseYandexExport("artist,title,album,duration\nNirvana,Come As You Are,Nevermind,218");

  assert.equal(tracks.length, 1);
  assert.equal(tracks[0].artist, "Nirvana");
  assert.equal(tracks[0].title, "Come As You Are");
  assert.equal(tracks[0].duration, 218);
});
