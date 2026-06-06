export const artworkURL = (image) => image?.urls?.at(-1) ?? null;

export const firstArtist = (contributors) => {
  const edge = contributors?.edges?.find((item) => item?.node?.name);
  return edge?.node ?? null;
};

const normalizeReleaseText = (value) =>
  String(value ?? "")
    .normalize("NFKD")
    .replace(/\p{Diacritic}/gu, "")
    .toLocaleLowerCase()
    .replace(/[^\p{L}\p{N}]+/gu, " ")
    .trim()
    .replace(/\s+/g, " ");

const hasReleaseMarker = (title, markers) => {
  const normalized = ` ${normalizeReleaseText(title)} `;
  return markers.some((marker) => marker.test(normalized));
};

const liveReleaseMarkers = [
  /\blive\b/u,
  /\bunplugged\b/u,
  /\bsession(s)?\b/u,
  /\blive at\b/u,
  /\blive in\b/u,
  /\blive on\b/u,
];

const reissueReleaseMarkers = [
  /\bdeluxe\b/u,
  /\bsuper deluxe\b/u,
  /\bexpanded\b/u,
  /\banniversary\b/u,
  /\bedition\b/u,
  /\bbonus\b/u,
  /\bdemo(s)?\b/u,
  /\bouttake(s)?\b/u,
  /\b\d+(st|nd|rd|th)\b/u,
];

const compilationReleaseMarkers = [
  /\bbest of\b/u,
  /\bgreatest hits\b/u,
  /\bcollection\b/u,
  /\banthology\b/u,
  /\brarities\b/u,
];

export const canonicalReleaseKey = (title) => {
  const stripped = String(title ?? "")
    .replace(/\([^)]*\)/gu, " ")
    .replace(/\[[^\]]*\]/gu, " ");
  return normalizeReleaseText(stripped)
    .replace(/\b(remaster(ed)?|deluxe|edition|anniversary|expanded|bonus|live|super|special|explicit|clean|version|demo(s)?|outtake(s)?)\b/gu, " ")
    .replace(/\b\d+(st|nd|rd|th)\b/gu, " ")
    .trim()
    .replace(/\s+/g, " ");
};

export const recordTypeLabel = (type, title = "") => {
  const value = String(type ?? "").toLowerCase();
  if (value.includes("studio")) return "studio";
  if (value.includes("live")) return "live";
  if (value.includes("reissue")) return "reissue";
  if (value.includes("single")) return "single";
  if (value.includes("ep")) return "ep";
  if (value.includes("compilation")) return "compilation";

  if (hasReleaseMarker(title, liveReleaseMarkers)) return "live";
  if (hasReleaseMarker(title, compilationReleaseMarkers)) return "compilation";
  if (hasReleaseMarker(title, reissueReleaseMarkers)) return "reissue";
  return "studio";
};

export const releaseRecordType = (album) =>
  recordTypeLabel(
    album?.type_ ?? album?.type ?? album?.record_type,
    album?.display_title ?? album?.displayTitle ?? album?.title
  );

const releaseVariantPenalty = (album) => {
  const title = album?.title ?? album?.display_title ?? album?.displayTitle;
  let penalty = 0;
  if (/\([^)]*\)|\[[^\]]*\]/u.test(String(title ?? ""))) penalty += 2;
  if (hasReleaseMarker(title, reissueReleaseMarkers)) penalty += 4;
  if (hasReleaseMarker(title, liveReleaseMarkers)) penalty += 8;
  return penalty;
};

const prefersStudioRelease = (candidate, current) => {
  const candidatePenalty = releaseVariantPenalty(candidate);
  const currentPenalty = releaseVariantPenalty(current);
  if (candidatePenalty !== currentPenalty) return candidatePenalty < currentPenalty;

  const candidateDate = String(candidate?.release_date ?? "");
  const currentDate = String(current?.release_date ?? "");
  if (candidateDate && currentDate && candidateDate !== currentDate) {
    return candidateDate < currentDate;
  }

  const candidateTracks = Number(candidate?.nb_tracks ?? 0);
  const currentTracks = Number(current?.nb_tracks ?? 0);
  if (candidateTracks !== currentTracks) return candidateTracks > currentTracks;

  return String(candidate?.title ?? "").localeCompare(String(current?.title ?? "")) < 0;
};

export const splitArtistReleases = (releases) => {
  const studioByKey = new Map();
  const studioKeys = [];
  const other = [];

  for (const release of releases ?? []) {
    const key = canonicalReleaseKey(release?.title);
    const recordType = recordTypeLabel(release?.record_type, release?.title);
    const isStudio = recordType === "studio" || recordType === "album";

    if (!key || !isStudio) {
      other.push(release);
      continue;
    }

    const current = studioByKey.get(key);
    if (!current) {
      studioByKey.set(key, release);
      studioKeys.push(key);
      continue;
    }

    if (prefersStudioRelease(release, current)) {
      studioByKey.set(key, release);
      other.push(current);
    } else {
      other.push(release);
    }
  }

  const studio = studioKeys
    .map((key) => studioByKey.get(key))
    .filter(Boolean);

  return { studio, other };
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
          record_type: releaseRecordType(album),
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
    record_type: releaseRecordType(album),
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
