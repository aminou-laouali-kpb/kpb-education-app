import type { AppVersionReading } from './app-version-headers';

export interface AppBuildThrottleOptions {
  /** Plafond mémoire : au-delà, le compte le moins récemment vu est oublié. */
  maxEntries: number;
  /** Un compte déjà écrit n'est réécrit qu'après ce délai… */
  refreshIntervalMs: number;
  /**
   * …sauf si sa build ou sa version a changé (une mise à jour), mais jamais
   * plus d'une fois par ce délai : un client qui alternerait deux valeurs ne
   * transforme pas chaque requête en écriture.
   */
  changeMinIntervalMs: number;
}

export const DEFAULT_APP_BUILD_THROTTLE: AppBuildThrottleOptions = {
  maxEntries: 50_000,
  refreshIntervalMs: 6 * 60 * 60 * 1000,
  changeMinIntervalMs: 60 * 1000,
};

interface TrackedEntry {
  version: string | null;
  build: number | null;
  writtenAt: number;
}

/**
 * Décide, en mémoire et sans base, si la requête d'un compte mérite une
 * écriture. Une `Map` sert de LRU : l'ordre d'insertion est l'ordre d'usage,
 * puisque chaque accès retire puis réinsère la clé.
 *
 * L'entrée est posée AVANT l'écriture et n'est pas retirée si celle-ci échoue :
 * les dix requêtes parallèles d'un démarrage d'app ne déclenchent qu'une
 * écriture, et une base qui refuse l'écriture n'est pas resollicitée à chaque
 * requête — au pire la fraîcheur recule de 6 h, sur une fenêtre de 30 jours.
 *
 * Mémoire par processus : un redémarrage oublie tout, et chaque compte est
 * simplement réécrit à sa requête suivante.
 */
export class AppBuildThrottle {
  private readonly entries = new Map<string, TrackedEntry>();

  constructor(
    private readonly options: AppBuildThrottleOptions = DEFAULT_APP_BUILD_THROTTLE,
  ) {}

  get size(): number {
    return this.entries.size;
  }

  shouldWrite(
    profileId: string,
    reading: AppVersionReading,
    now: number,
  ): boolean {
    const previous = this.entries.get(profileId);
    if (previous) {
      this.entries.delete(profileId);
      this.entries.set(profileId, previous);
      if (!this.isDue(previous, reading, now)) return false;
    }

    // Même règle que le `COALESCE` de l'écriture : une valeur absente ou
    // illisible ne remplace jamais une valeur connue.
    this.entries.set(profileId, {
      version: reading.version ?? previous?.version ?? null,
      build: reading.build ?? previous?.build ?? null,
      writtenAt: now,
    });
    this.evictOverflow();
    return true;
  }

  private isDue(
    previous: TrackedEntry,
    reading: AppVersionReading,
    now: number,
  ): boolean {
    const elapsed = now - previous.writtenAt;
    // Horloge reculée (resynchronisation NTP) : une écriture, puis la règle
    // normale reprend depuis la nouvelle heure.
    if (elapsed < 0 || elapsed >= this.options.refreshIntervalMs) return true;
    const changed =
      (reading.version !== null && reading.version !== previous.version) ||
      (reading.build !== null && reading.build !== previous.build);
    return changed && elapsed >= this.options.changeMinIntervalMs;
  }

  private evictOverflow(): void {
    while (this.entries.size > this.options.maxEntries) {
      const oldest = this.entries.keys().next();
      if (oldest.done) return;
      this.entries.delete(oldest.value);
    }
  }
}
