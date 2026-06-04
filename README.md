# Noirwave

Native SwiftUI macOS music player MVP with a local Deezer stream backend.

## Run

Start the headless backend:

```sh
cd /Users/fsociety/Developer/Noirwave/NoirwaveBackend
npm install
npm start
```

Or install it as a macOS LaunchAgent:

```sh
cd /Users/fsociety/Developer/Noirwave/NoirwaveBackend
chmod +x scripts/install-launch-agent.sh
scripts/install-launch-agent.sh
```

Open the macOS app:

```sh
cd /Users/fsociety/Developer/Noirwave
xcodegen generate
open Noirwave.xcodeproj
```

Noirwave talks to `http://127.0.0.1:6605` by default. Override it with:

```sh
NOIRWAVE_BACKEND_API_BASE=http://127.0.0.1:6605 open Noirwave.xcodeproj
```

## Session

Full-track playback needs a Deezer ARL session. Use `Stream Session` in the app
sidebar:

- `Connect ARL` sends the pasted ARL to the local backend for the current
  process and saves it in the macOS Keychain for the next launch.
- `Use Saved ARL` refreshes the source and lets the app restore the backend
  session from Keychain automatically.

Noirwave restores ARL in this order:

1. ARL connected from the app and saved in Keychain.
2. `NOIRWAVE_DEEZER_ARL`.
3. Backend-readable `~/Library/Application Support/deemix/login.json`.

Noirwave does not write ARL into the Swift app bundle or source tree.

Use `NoirwaveBackend/.env.example` as a local environment template. Keep real
ARL values in `.env`, shell environment, or the app session sheet; `.env` files
are ignored by Git.

## Backend

The backend is a local headless service. It uses:

- `deezer-python-gql` through `scripts/catalog_cli.py` for search, artists,
  albums, catalog metadata, and lyrics.
- `deezer-sdk` from the modified Deemix package for playback media tokens,
  media URLs, and stream helper crypto.

Visible app flow does not use the Deemix WebUI. Playback resolves a Deezer track
id, requests MP3 320 kbps first, falls back to MP3 128 kbps for free sessions,
and streams the audio directly through:

- `GET /api/stream/:trackId`

Noirwave does not fall back to 30-second previews. If the current ARL cannot
stream MP3 320, the backend retries MP3 128 and returns the playable stream URL
from the same stream request.

Useful backend endpoints:

- `GET /health`
- `GET /api/connect`
- `POST /api/loginArl`
- `GET /api/search?term=<query>&type=track|artist|album&nb=30`
- `GET /api/getTracklist?type=artist|album&id=<id>`
- `GET /api/lyrics/:trackId`
- `GET /api/playback/:trackId`
- `GET /api/stream/:trackId`

Backend format defaults to MP3 320:

```sh
NOIRWAVE_DEEZER_FORMAT=MP3_320 npm start
```

## Test Seeds

The first screen loads two catalog seed searches:

- `Daft Punk Around the World`
- `Nirvana Come As You Are`
