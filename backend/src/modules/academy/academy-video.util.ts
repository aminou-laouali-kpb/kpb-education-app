import { BadRequestException } from '@nestjs/common';

import {
  extractYoutubeVideoId,
  youtubeVideoUrls,
} from '../scholarships-index/youtube-video.util';

/**
 * Vidéos des leçons Academy : la même règle que les vidéos de bourses (HTTPS,
 * youtube.com ou youtu.be, identifiant de 11 caractères), mais stockée dans la
 * colonne historique `AcademyLesson.videoUrl`.
 *
 * L'API d'administration n'y écrit QUE la forme canonique
 * `https://www.youtube.com/watch?v=<id>` : c'est celle que le lecteur de l'app
 * (`YoutubePlayer.convertUrlToId`) sait lire, et c'est elle qui permet de
 * reconnaître une même vidéo d'un import à l'autre.
 */
export function canonicalLessonVideo(rawUrl: string): {
  youtubeVideoId: string;
  videoUrl: string;
} {
  const youtubeVideoId = extractYoutubeVideoId(rawUrl);
  return {
    youtubeVideoId,
    videoUrl: youtubeVideoUrls(youtubeVideoId).watchUrl,
  };
}

/** Comme [canonicalLessonVideo], en préfixant l'erreur par la leçon fautive. */
export function canonicalImportedVideo(
  rawUrl: string,
  order: number,
): { youtubeVideoId: string; videoUrl: string } {
  try {
    return canonicalLessonVideo(rawUrl);
  } catch (error) {
    if (error instanceof BadRequestException) {
      throw new BadRequestException(`Lesson #${order}: ${error.message}`);
    }
    throw error;
  }
}

/**
 * Identifiant YouTube d'une leçon déjà en base, ou `null`.
 *
 * Tolérant à dessein : des lignes antérieures à l'API d'administration peuvent
 * porter n'importe quelle URL. Une URL illisible ne doit pas faire échouer une
 * lecture ; elle ne correspondra simplement à aucune vidéo importée.
 */
export function lessonYoutubeId(videoUrl: string): string | null {
  try {
    return extractYoutubeVideoId(videoUrl);
  } catch {
    return null;
  }
}

export function lessonThumbnailUrl(youtubeVideoId: string | null): string | null {
  return youtubeVideoId
    ? `https://img.youtube.com/vi/${youtubeVideoId}/hqdefault.jpg`
    : null;
}
