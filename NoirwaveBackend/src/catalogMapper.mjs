export const artworkURL = (image) => image?.urls?.at(-1) ?? null;

export const firstArtist = (contributors) => {
  const edge = contributors?.edges?.find((item) => item?.node?.name);
  return edge?.node ?? null;
};

export const recordTypeLabel = (type) => {
  const value = String(type ?? "").toLowerCase();
  if (value.includes("single")) return "single";
  if (value.includes("ep")) return "ep";
  if (value.includes("compilation")) return "compilation";
  return "album";
};

export const trackPayload = (track, fallbackIndex = 0, albumContext = null) => {
  const artist = firstArtist(track?.contributors) ?? firstArtist(albumContext?.contributors);
  const album = track?.album ?? albumContext;
  const diskInfo = track?.disk_info ?? track?.diskInfo ?? {};
  const rank = Number.isFinite(track?.popularity) ? Math.round(track.popularity * 10000) : null;

  return {
    id: track?.id ?? `fallback-${fallbackIndex}`,
    readable: track?.media?.rights?.sub?.available ?? true,
    title: track?.title ?? "Untitled Track",
    title_short: track?.title ?? "Untitled Track",
    title_version: null,
    link: `https://www.deezer.com/track/${track?.id ?? fallbackIndex}`,
    duration: track?.duration ?? 0,
    rank,
    explicit_lyrics: track?.is_explicit ?? false,
    preview: null,
    track_position: diskInfo.track_number ?? diskInfo.trackNumber ?? null,
    disk_number: diskInfo.disk_number ?? diskInfo.diskNumber ?? null,
    artist: {
      id: artist?.id ?? null,
      name: artist?.name ?? "Unknown Artist",
      link: artist?.id ? `https://www.deezer.com/artist/${artist.id}` : null,
      picture: null,
      picture_small: null,
      picture_medium: null,
      picture_big: null,
      picture_xl: null,
      nb_album: null,
      nb_fan: null,
      tracklist: artist?.id ? `https://api.deezer.com/artist/${artist.id}/top?limit=50` : null,
    },
    album: album
      ? {
          id: album.id,
          title: album.display_title ?? album.displayTitle ?? "Unknown Album",
          link: `https://www.deezer.com/album/${album.id}`,
          cover: artworkURL(album.cover),
          cover_small: artworkURL(album.cover),
          cover_medium: artworkURL(album.cover),
          cover_big: artworkURL(album.cover),
          cover_xl: artworkURL(album.cover),
          artist: artist
            ? {
                id: artist.id,
                name: artist.name,
                link: `https://www.deezer.com/artist/${artist.id}`,
              }
            : null,
          nb_tracks: album.tracks_count ?? album.tracksCount ?? null,
          fans: album.fans_count ?? album.fansCount ?? null,
          release_date: album.release_date ?? album.releaseDate ?? null,
          record_type: recordTypeLabel(album.type_ ?? album.type),
          rank,
          tracklist: `https://api.deezer.com/album/${album.id}/tracks`,
        }
      : null,
  };
};

export const artistPayload = (artist, fallbackIndex = 0) => ({
  id: artist?.id ?? `fallback-${fallbackIndex}`,
  name: artist?.name ?? "Unknown Artist",
  link: artist?.id ? `https://www.deezer.com/artist/${artist.id}` : null,
  picture: artworkURL(artist?.picture),
  picture_small: artworkURL(artist?.picture),
  picture_medium: artworkURL(artist?.picture),
  picture_big: artworkURL(artist?.picture),
  picture_xl: artworkURL(artist?.picture),
  nb_album: artist?.albums_count ?? artist?.album_count ?? artist?.albumCount ?? null,
  nb_fan: artist?.fans_count ?? artist?.fansCount ?? null,
  tracklist: artist?.id ? `https://api.deezer.com/artist/${artist.id}/top?limit=50` : null,
});

export const albumPayload = (album, fallbackIndex = 0, artistContext = null) => {
  const artist = firstArtist(album?.contributors) ?? artistContext;

  return {
    id: album?.id ?? `fallback-${fallbackIndex}`,
    title: album?.display_title ?? album?.displayTitle ?? "Unknown Album",
    link: album?.id ? `https://www.deezer.com/album/${album.id}` : null,
    cover: artworkURL(album?.cover),
    cover_small: artworkURL(album?.cover),
    cover_medium: artworkURL(album?.cover),
    cover_big: artworkURL(album?.cover),
    cover_xl: artworkURL(album?.cover),
    artist: artist
      ? {
          id: artist.id,
          name: artist.name,
          link: `https://www.deezer.com/artist/${artist.id}`,
          picture: artworkURL(artist.picture),
        }
      : null,
    nb_tracks: album?.tracks_count ?? album?.tracksCount ?? null,
    fans: album?.fans_count ?? album?.fansCount ?? null,
    release_date: album?.release_date ?? album?.releaseDate ?? null,
    record_type: recordTypeLabel(album?.type_ ?? album?.type),
    rank: null,
    tracklist: album?.id ? `https://api.deezer.com/album/${album.id}/tracks` : null,
  };
};

export const sortTracksByPopularity = (tracks) =>
  [...tracks].sort((lhs, rhs) => {
    const lhsRank = lhs.rank ?? 0;
    const rhsRank = rhs.rank ?? 0;
    if (lhsRank === rhsRank) return String(lhs.title).localeCompare(String(rhs.title));
    return rhsRank - lhsRank;
  });

export const sortTracksByAlbumPosition = (tracks) =>
  [...tracks].sort((lhs, rhs) => {
    const lhsDisk = lhs.disk_number ?? 0;
    const rhsDisk = rhs.disk_number ?? 0;
    if (lhsDisk !== rhsDisk) return lhsDisk - rhsDisk;

    const lhsPosition = lhs.track_position ?? Number.MAX_SAFE_INTEGER;
    const rhsPosition = rhs.track_position ?? Number.MAX_SAFE_INTEGER;
    if (lhsPosition !== rhsPosition) return lhsPosition - rhsPosition;

    return String(lhs.title).localeCompare(String(rhs.title));
  });

export const sortAlbumsByReleaseDate = (albums) =>
  [...albums].sort((lhs, rhs) => String(rhs.release_date ?? "").localeCompare(String(lhs.release_date ?? "")));
