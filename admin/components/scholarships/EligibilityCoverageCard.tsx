'use client';

import { CSSProperties } from 'react';

import { fill } from '../../lib/scholarship-opening';
import { formatPercent } from '../../lib/scholarship-eligibility';
import type { EligibilityCoverageResponse } from '../../lib/scholarship-eligibility-types';
import { useLocale } from '../locale-provider';
import { Badge, Button } from '../ui';

const C = 'scholarships.eligibility.coverage';

/**
 * Compteur de couverture de l'éligibilité structurée, en tête de la file de
 * modération : c'est la porte de lancement du test « Mes 10 bourses » (90 %
 * des bourses publiques structurées et vérifiées depuis moins de 400 jours).
 * Une bourse approuvée reste invisible au test tant qu'elle n'est pas
 * structurée : le compteur le rappelle là où l'on approuve.
 */
export function EligibilityCoverageCard({
  coverage,
  failed,
  filterActive,
  onToggleFilter,
  onOpenPreview,
}: {
  coverage: EligibilityCoverageResponse | null;
  failed: boolean;
  filterActive: boolean;
  onToggleFilter: () => void;
  onOpenPreview: () => void;
}) {
  const { t, locale } = useLocale();
  return (
    <section style={cardStyle} aria-label={t(`${C}.title`)}>
      <div style={rowStyle}>
        <div style={{ display: 'grid', gap: 4 }}>
          <strong style={{ fontSize: 'var(--text-sm)', color: 'var(--ink)' }}>
            {t(`${C}.title`)}
          </strong>
          {coverage ? (
            <span style={{ fontSize: 'var(--text-sm)' }}>
              {fill(t(`${C}.headline`), {
                fresh: coverage.structuredFresh,
                total: coverage.total,
                percent: formatPercent(coverage.coveragePercent, locale),
                gate: coverage.launchGatePercent,
              })}
            </span>
          ) : (
            <span style={mutedText}>{failed ? t(`${C}.loadError`) : t(`${C}.loading`)}</span>
          )}
          {coverage ? (
            <span style={mutedText}>
              {fill(t(`${C}.breakdown`), {
                stale: coverage.stale,
                unstructured: coverage.unstructured,
                notAnalyzed: coverage.notAnalyzed,
                days: coverage.freshnessDays,
              })}
              {coverage.invalidCriteria > 0
                ? ` ${fill(t(`${C}.invalidCriteria`), { count: coverage.invalidCriteria })}`
                : ''}
            </span>
          ) : null}
          <span style={mutedText}>{t(`${C}.moderationNote`)}</span>
        </div>
        <div style={{ display: 'flex', gap: 8, alignItems: 'center', flexWrap: 'wrap' }}>
          {coverage ? (
            <Badge variant={coverage.launchReady ? 'success' : 'warning'}>
              {coverage.launchReady ? t(`${C}.gateReached`) : t(`${C}.gateNotReached`)}
            </Badge>
          ) : null}
          <Button
            size="sm"
            variant={filterActive ? 'primary' : 'secondary'}
            aria-pressed={filterActive}
            onClick={onToggleFilter}
          >
            {t(`${C}.filterCta`)}
          </Button>
          <Button size="sm" variant="secondary" onClick={onOpenPreview}>
            {t('scholarships.eligibility.preview.openCta')}
          </Button>
        </div>
      </div>
    </section>
  );
}

const cardStyle: CSSProperties = {
  background: 'var(--surface)',
  border: '1px solid var(--border)',
  borderRadius: 16,
  padding: 14,
};

const rowStyle: CSSProperties = {
  display: 'flex',
  justifyContent: 'space-between',
  alignItems: 'flex-start',
  gap: 12,
  flexWrap: 'wrap',
};

const mutedText: CSSProperties = { fontSize: 'var(--text-xs)', color: 'var(--text-muted)' };
