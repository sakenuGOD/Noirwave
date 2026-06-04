from __future__ import annotations

import argparse
import asyncio
import json
import os
import sys
from pathlib import Path
from typing import Any

from deezer_python_gql import DeezerGQLClient


def read_arl() -> str:
    from_env = os.environ.get("NOIRWAVE_DEEZER_ARL", "").strip()
    if from_env:
        return from_env

    login_path = Path.home() / "Library" / "Application Support" / "deemix" / "login.json"
    try:
        data = json.loads(login_path.read_text())
        return str(data.get("arl") or "").strip()
    except Exception:
        return ""


def json_default(value: Any) -> str:
    return str(value)


def image_url(image: Any) -> str | None:
    urls = getattr(image, "urls", None)
    return urls[-1] if urls else None


def enum_value(value: Any) -> str | None:
    if value is None:
        return None
    return str(getattr(value, "value", value))


def first_artist(contributors: Any) -> dict[str, Any] | None:
    for edge in getattr(contributors, "edges", []) or []:
        node = getattr(edge, "node", None)
        name = getattr(node, "name", None)
        artist_id = getattr(node, "id", None)
        if name:
            return {"id": artist_id, "name": name}
    return None


def artist_payload(artist: Any, album_count: int | None = None) -> dict[str, Any]:
    artist_id = getattr(artist, "id", None)
    picture = image_url(getattr(artist, "picture", None))
    return {
        "id": artist_id,
        "name": getattr(artist, "name", None) or "Unknown Artist",
        "link": f"https://www.deezer.com/artist/{artist_id}" if artist_id else None,
        "picture": picture,
        "picture_small": picture,
        "picture_medium": picture,
        "picture_big": picture,
        "picture_xl": picture,
        "nb_album": album_count,
        "nb_fan": getattr(artist, "fans_count", None),
        "tracklist": f"https://api.deezer.com/artist/{artist_id}/top?limit=50" if artist_id else None,
    }


def album_payload(album: Any, artist_context: dict[str, Any] | None = None) -> dict[str, Any]:
    album_id = getattr(album, "id", None)
    cover = image_url(getattr(album, "cover", None))
    artist = first_artist(getattr(album, "contributors", None)) or artist_context
    album_type = enum_value(getattr(album, "type_", None) or getattr(album, "type", None))
    return {
        "id": album_id,
        "title": getattr(album, "display_title", None) or getattr(album, "displayTitle", None) or "Unknown Album",
        "link": f"https://www.deezer.com/album/{album_id}" if album_id else None,
        "cover": cover,
        "cover_small": cover,
        "cover_medium": cover,
        "cover_big": cover,
        "cover_xl": cover,
        "artist": {
            "id": artist.get("id"),
            "name": artist.get("name"),
            "link": f"https://www.deezer.com/artist/{artist.get('id')}" if artist.get("id") else None,
        }
        if artist
        else None,
        "nb_tracks": getattr(album, "tracks_count", None),
        "fans": getattr(album, "fans_count", None),
        "release_date": str(getattr(album, "release_date", None) or "") or None,
        "record_type": (album_type or "album").lower(),
        "rank": None,
        "tracklist": f"https://api.deezer.com/album/{album_id}/tracks" if album_id else None,
    }


def track_payload(track: Any, fallback_index: int = 0, album_context: Any | None = None) -> dict[str, Any]:
    track_id = getattr(track, "id", None) or f"fallback-{fallback_index}"
    album = getattr(track, "album", None) or album_context
    artist = first_artist(getattr(track, "contributors", None))
    if artist is None and album_context is not None:
        artist = first_artist(getattr(album_context, "contributors", None))
    disk_info = getattr(track, "disk_info", None)
    popularity = getattr(track, "popularity", None)
    rank = round(float(popularity) * 10000) if popularity is not None else None
    cover = image_url(getattr(album, "cover", None))
    album_id = getattr(album, "id", None)
    album_title = getattr(album, "display_title", None) or getattr(album, "displayTitle", None)
    media = getattr(track, "media", None)
    media_token = getattr(getattr(media, "token", None), "payload", None)
    media_sizes = getattr(media, "estimated_sizes", None)
    media_rights_sub = getattr(getattr(media, "rights", None), "sub", None)

    return {
        "id": track_id,
        "readable": getattr(media_rights_sub, "available", True),
        "title": getattr(track, "title", None) or "Untitled Track",
        "title_short": getattr(track, "title", None) or "Untitled Track",
        "title_version": None,
        "link": f"https://www.deezer.com/track/{track_id}",
        "duration": getattr(track, "duration", None) or 0,
        "rank": rank,
        "explicit_lyrics": getattr(track, "is_explicit", None) or False,
        "preview": None,
        "track_position": getattr(disk_info, "track_number", None),
        "disk_number": getattr(disk_info, "disk_number", None),
        "mediaToken": media_token,
        "mediaVersion": getattr(media, "version", None),
        "estimatedSize128": getattr(media_sizes, "mp_3_128", None),
        "estimatedSize320": getattr(media_sizes, "mp_3_320", None),
        "canStreamSub": getattr(media_rights_sub, "available", True),
        "artist": {
            "id": artist.get("id"),
            "name": artist.get("name"),
            "link": f"https://www.deezer.com/artist/{artist.get('id')}" if artist.get("id") else None,
            "picture": None,
            "picture_small": None,
            "picture_medium": None,
            "picture_big": None,
            "picture_xl": None,
            "nb_album": None,
            "nb_fan": None,
            "tracklist": f"https://api.deezer.com/artist/{artist.get('id')}/top?limit=50" if artist.get("id") else None,
        }
        if artist
        else None,
        "album": {
            "id": album_id,
            "title": album_title or "Unknown Album",
            "link": f"https://www.deezer.com/album/{album_id}" if album_id else None,
            "cover": cover,
            "cover_small": cover,
            "cover_medium": cover,
            "cover_big": cover,
            "cover_xl": cover,
            "artist": artist,
            "nb_tracks": getattr(album, "tracks_count", None),
            "fans": getattr(album, "fans_count", None),
            "release_date": str(getattr(album, "release_date", None) or "") or None,
            "record_type": "album",
            "rank": rank,
            "tracklist": f"https://api.deezer.com/album/{album_id}/tracks" if album_id else None,
        }
        if album
        else None,
    }


async def enrich_artist(client: DeezerGQLClient, artist: Any) -> dict[str, Any]:
    try:
        detail = await client.get_artist(str(artist.id), top_tracks_first=0, albums_first=100)
        album_count = len(getattr(getattr(detail, "albums", None), "edges", []) or []) if detail else None
        return artist_payload(detail or artist, album_count=album_count)
    except Exception:
        return artist_payload(artist)


async def status(client: DeezerGQLClient) -> dict[str, Any]:
    me = await client.get_me()
    return {
        "result": True,
        "deezerAvailable": "yes",
        "autologin": False,
        "currentUser": {
            "id": getattr(me, "id", None),
            "name": getattr(me, "name", None),
            "picture": image_url(getattr(me, "picture", None)),
        },
    }


async def search(client: DeezerGQLClient, query: str, scope: str, limit: int) -> dict[str, Any]:
    result = await client.search(
        query=query,
        tracks_first=limit if scope == "track" else 0,
        albums_first=limit if scope == "album" else 0,
        artists_first=limit if scope == "artist" else 0,
        playlists_first=0,
        livestreams_first=0,
        podcasts_first=0,
    )
    results = result.results

    if scope == "track":
        tracks = [
            track_payload(edge.node, index)
            for index, edge in enumerate(results.tracks.edges)
            if edge.node is not None
        ]
        return {"data": tracks, "total": len(tracks), "type": "track"}

    if scope == "album":
        albums = [
            album_payload(edge.node, index)
            for index, edge in enumerate(results.albums.edges)
            if edge.node is not None
        ]
        return {"data": albums, "total": len(albums), "type": "album"}

    artists = [
        edge.node
        for edge in results.artists.edges
        if edge.node is not None
    ]
    enriched = await asyncio.gather(*(enrich_artist(client, artist) for artist in artists[:limit]))
    return {"data": enriched, "total": len(enriched), "type": "artist"}


async def artist_detail(client: DeezerGQLClient, artist_id: str) -> dict[str, Any]:
    artist = await client.get_artist(artist_id, top_tracks_first=50, albums_first=100)
    if artist is None:
        raise ValueError("Artist not found")

    artist_data = artist_payload(artist, album_count=len(artist.albums.edges))
    albums = [album_payload(edge.node, artist_context={"id": artist.id, "name": artist.name}) for edge in artist.albums.edges if edge.node]
    top_tracks = [track_payload(edge.node, index) for index, edge in enumerate(artist.top_tracks.edges if artist.top_tracks else []) if edge.node]
    return {
        **artist_data,
        "releases": {"all": albums},
        "top_tracks": top_tracks,
    }


async def album_detail(client: DeezerGQLClient, album_id: str) -> dict[str, Any]:
    album = await client.get_album(album_id, tracks_first=100)
    if album is None:
        raise ValueError("Album not found")

    data = album_payload(album)
    tracks = [track_payload(edge.node, index, album_context=album) for index, edge in enumerate(album.tracks.edges) if edge.node]
    return {
        **data,
        "tracks": tracks,
    }


async def track_media(client: DeezerGQLClient, track_id: str) -> dict[str, Any]:
    track = await client.get_track(track_id)
    if track is None:
        raise ValueError("Track not found")
    if track.media is None:
        raise ValueError("Track has no media token")

    return {
        "id": track.id,
        "title": track.title,
        "duration": track.duration,
        "mediaToken": track.media.token.payload,
        "mediaVersion": track.media.version,
        "estimatedSize320": track.media.estimated_sizes.mp_3_320,
        "canStreamSub": getattr(track.media.rights.sub, "available", False) if track.media.rights.sub else False,
    }


async def track_lyrics(client: DeezerGQLClient, track_id: str) -> dict[str, Any]:
    track = await client.get_track(track_id)
    if track is None:
        raise ValueError("Track not found")

    lyrics = getattr(track, "lyrics", None)
    if lyrics is None:
        return {
            "id": track_id,
            "available": False,
            "hasSynced": False,
            "text": "",
            "lines": [],
            "copyright": None,
            "writers": None,
        }

    lines = []
    for line in getattr(lyrics, "synchronized_lines", None) or []:
        text = str(getattr(line, "line", "") or "").strip()
        milliseconds = getattr(line, "milliseconds", None)
        if not text or milliseconds is None:
            continue
        lines.append({
            "milliseconds": milliseconds,
            "duration": getattr(line, "duration", None),
            "text": text,
            "lrcTimestamp": getattr(line, "lrc_timestamp", None),
        })

    text = str(getattr(lyrics, "text", "") or "").strip()
    return {
        "id": getattr(track, "id", track_id),
        "available": bool(text or lines),
        "hasSynced": bool(lines),
        "text": text,
        "lines": lines,
        "copyright": getattr(lyrics, "copyright", None),
        "writers": getattr(lyrics, "writers", None),
    }


async def main() -> None:
    parser = argparse.ArgumentParser()
    subcommands = parser.add_subparsers(dest="command", required=True)

    subcommands.add_parser("status")

    search_parser = subcommands.add_parser("search")
    search_parser.add_argument("--query", required=True)
    search_parser.add_argument("--scope", choices=["track", "artist", "album"], required=True)
    search_parser.add_argument("--limit", type=int, default=30)

    artist_parser = subcommands.add_parser("artist")
    artist_parser.add_argument("--id", required=True)

    album_parser = subcommands.add_parser("album")
    album_parser.add_argument("--id", required=True)

    media_parser = subcommands.add_parser("track-media")
    media_parser.add_argument("--id", required=True)

    lyrics_parser = subcommands.add_parser("lyrics")
    lyrics_parser.add_argument("--id", required=True)

    args = parser.parse_args()
    arl = read_arl()
    if not arl:
        raise RuntimeError("NOIRWAVE_DEEZER_ARL is required")

    async with DeezerGQLClient(arl=arl) as client:
        if args.command == "status":
            payload = await status(client)
        elif args.command == "search":
            payload = await search(client, args.query, args.scope, args.limit)
        elif args.command == "artist":
            payload = await artist_detail(client, args.id)
        elif args.command == "album":
            payload = await album_detail(client, args.id)
        elif args.command == "track-media":
            payload = await track_media(client, args.id)
        elif args.command == "lyrics":
            payload = await track_lyrics(client, args.id)
        else:
            raise RuntimeError(f"Unsupported command: {args.command}")

    print(json.dumps(payload, default=json_default, ensure_ascii=False))


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        raise SystemExit(1)
