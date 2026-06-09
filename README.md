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
id, requests MP3 320 kbps, preloads the startup segment for visible/queued
tracks, and streams the audio directly through:

- `GET /api/stream/:trackId`

Noirwave does not fall back to 30-second previews or MP3 128 for playback. If
the current ARL cannot stream MP3 320, the backend returns a playback error.

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

## AI / MCP

Noirwave exposes the app library through a local stdio MCP server. Start it as a
separate command from the backend directory:

```sh
cd /Users/fsociety/Noirwave/NoirwaveBackend
npm run mcp
```

For an agent that runs on another server, use the token-protected Streamable
HTTP MCP server instead:

```sh
cd /Users/fsociety/Noirwave/NoirwaveBackend
export NOIRWAVE_MCP_HTTP_TOKEN="$(openssl rand -hex 32)"
export NOIRWAVE_MCP_HTTP_HOST=127.0.0.1
export NOIRWAVE_MCP_HTTP_PORT=6615
npm run mcp:http
```

Local endpoint:

```sh
http://127.0.0.1:6615/mcp
```

Expose only that endpoint to a remote agent through a private network or HTTPS
tunnel, for example Tailscale Funnel, Tailscale Serve, or Cloudflare Tunnel.
Keep the MCP server bound to `127.0.0.1` unless you intentionally protect it
behind a firewall or reverse proxy. Do not expose it without HTTPS and the
Bearer token.

If the tunnel forwards the public domain in the `Host` header, allow that
hostname explicitly:

```sh
export NOIRWAVE_MCP_HTTP_ALLOWED_HOSTS=your-tunnel.example,127.0.0.1,localhost
```

Generic remote MCP client configuration:

```json
{
  "mcpServers": {
    "noirwave": {
      "url": "https://your-tunnel.example/mcp",
      "headers": {
        "Authorization": "Bearer <NOIRWAVE_MCP_HTTP_TOKEN>"
      }
    }
  }
}
```

The app writes the MCP bridge files under:

```sh
~/Library/Application Support/Noirwave/MCP
```

Set `NOIRWAVE_MCP_ROOT` only if you intentionally want a different bridge
directory. The MCP server only reads and writes this bridge directory; it does
not expose arbitrary local filesystem access. MCP clients should use the command
shown in Settings -> AI / MCP for local stdio access, or the HTTPS tunnel URL for
remote HTTP access.

Resources:

- `library://tracks`
- `library://artists`
- `library://albums`
- `library://playlists`
- `library://playlist/{id}`
- `library://track/{id}`

Tools include track search, playlist create/rename/delete, add/remove/reorder,
smart playlist preview/apply, similar-track lookup, stats, tags, and metadata
updates. Destructive and mass operations return a preview first and require the
returned confirmation phrase before applying.

## Initial Catalog State

The first screen does not issue hardcoded catalog seed searches. If no real
library or featured data is available yet, Noirwave shows a clean empty state and
waits for an explicit search or playback action.
