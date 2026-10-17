'use client';

import { useState } from 'react';

import { type CommunityStats, communityAdminApi, formatHours, MODERATION_SLA_HOURS } from '../../lib/community-admin';
import { useLocale } from '../locale-provider';
import { Button, EmptyState } from '../ui';
import { enumLabel, fill, hintStyle, LoadError, panelCardStyle, Section, useLoader } from './shared';

const WINDOWS = [7, 30, 90] as const;

/** Tableau de bord (§8.7) : volumes, file, délai de traitement. */
export function DashboardPanel({ onOpenQueue }: Readonly<{ onOpenQueue: () => void }>) {
  const { t } = useLocale();
  const [days, setDays] = useState<number>(30);
  const stats = useLoader<CommunityStats>(() => communityAdminApi.stats(days), [days]);
  return (
    <div style={{ display: 'grid', gap: 12 }}>
      <div style={{ display: 'flex', gap: 6 }} role="group" aria-label={t('communityAdmin.dashboard.window')}>
        {WINDOWS.map((d) => (
          <Button key={d} size="sm" variant={days === d ? 'primary' : 'secondary'} aria-pressed={days === d} onClick={() => setDays(d)}>
            {fill(t('communityAdmin.dashboard.days'), { n: d })}
          </Button>
        ))}
      </div>
      {stats.error ? (
        <LoadError error={stats.error} />
      ) : !stats.data ? (
        <EmptyState title={t('communityAdmin.loading')} />
      ) : (
        <StatsView stats={stats.data} onOpenQueue={onOpenQueue} />
      )}
    </div>
  );
}

function Tile({
  label,
  value,
  sub,
  tone = 'neutral',
}: Readonly<{ label: string; value: string; sub?: string; tone?: 'neutral' | 'warning' | 'danger' | 'success' }>) {
  const color =
    tone === 'danger' ? 'var(--danger-fg)' : tone === 'warning' ? 'var(--warning-fg)' : tone === 'success' ? 'var(--success-fg)' : 'var(--ink)';
  return (
    <div style={{ ...panelCardStyle, display: 'grid', gap: 4 }} data-tile={label}>
      <span style={{ fontSize: 'var(--text-xs)', color: 'var(--text-muted)', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.04em' }}>
        {label}
      </span>
      <span style={{ fontSize: 26, fontWeight: 800, color, fontVariantNumeric: 'tabular-nums' }}>{value}</span>
      {sub ? <span style={hintStyle}>{sub}</span> : null}
    </div>
  );
}

export function StatsView({ stats, onOpenQueue }: Readonly<{ stats: CommunityStats; onOpenQueue: () => void }>) {
  const { t, locale } = useLocale();
  const nf = new Intl.NumberFormat(locale === 'fr' ? 'fr-FR' : 'en-GB');
  const median = stats.reports.medianResolutionHours;
  // Révision 1 : délai médian des contenus masqués automatiquement et
  // questions sans réponse depuis plus de 48 h. Absents d'un serveur plus
  // ancien : tuile omise, ou repli sur le total sans réponse.
  const autoMedian = stats.autoHiddenMedianHandlingHours;
  const hasOver48 = typeof stats.unansweredOver48h === 'number';
  const over = (h: number | null | undefined) => h !== null && h !== undefined && h > MODERATION_SLA_HOURS;
  const maxDaily = Math.max(1, ...stats.daily.map((d) => d.posts + d.replies));
  const pending = stats.posts.byStatus.pending_review ?? 0;
  return (
    <div style={{ display: 'grid', gap: 12 }}>
      <div style={{ display: 'grid', gap: 10, gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))' }}>
        <Tile
          label={t('communityAdmin.dashboard.openReports')}
          value={nf.format(stats.reports.open)}
          sub={fill(t('communityAdmin.dashboard.openedResolved'), { opened: stats.reports.opened, resolved: stats.reports.resolved })}
          tone={stats.reports.open > 0 ? 'warning' : 'success'}
        />
        {autoMedian !== undefined ? (
          <Tile
            label={t('communityAdmin.dashboard.moderationDelay')}
            value={formatHours(autoMedian, locale)}
            sub={fill(t('communityAdmin.dashboard.moderationDelayHint'), { h: MODERATION_SLA_HOURS })}
            tone={over(autoMedian) ? 'danger' : 'neutral'}
          />
        ) : null}
        <Tile
          label={t('communityAdmin.dashboard.medianDelay')}
          value={formatHours(median, locale)}
          sub={fill(t('communityAdmin.dashboard.sla'), { h: MODERATION_SLA_HOURS })}
          tone={over(median) ? 'danger' : 'neutral'}
        />
        <Tile
          label={t('communityAdmin.dashboard.autoHidden')}
          value={nf.format(stats.autoHidden)}
          sub={fill(t('communityAdmin.dashboard.pendingNow'), { n: pending })}
        />
        {hasOver48 ? (
          <Tile
            label={t('communityAdmin.dashboard.unansweredOver48h')}
            value={nf.format(stats.unansweredOver48h as number)}
            sub={fill(t('communityAdmin.dashboard.unansweredTotal'), { n: stats.unansweredQuestions })}
            tone={(stats.unansweredOver48h as number) > 0 ? 'warning' : 'success'}
          />
        ) : (
          <Tile
            label={t('communityAdmin.dashboard.unanswered')}
            value={nf.format(stats.unansweredQuestions)}
            sub={t('communityAdmin.dashboard.unansweredHint')}
            tone={stats.unansweredQuestions > 0 ? 'warning' : 'success'}
          />
        )}
        <Tile
          label={t('communityAdmin.dashboard.posts')}
          value={nf.format(stats.posts.total)}
          sub={Object.entries(stats.posts.byType)
            .map(([type, n]) => `${enumLabel(t, 'postType', type)} ${n ?? 0}`)
            .join(' · ')}
        />
        <Tile
          label={t('communityAdmin.dashboard.replies')}
          value={nf.format(stats.replies.total)}
          sub={fill(t('communityAdmin.dashboard.byTeam'), { n: stats.replies.byTeam })}
        />
        <Tile label={t('communityAdmin.dashboard.verified')} value={nf.format(stats.verifiedAnswers)} tone="success" />
        <Tile
          label={t('communityAdmin.dashboard.members')}
          value={nf.format(stats.activeMembers)}
          sub={fill(t('communityAdmin.dashboard.newMembers'), { n: stats.newMembers })}
        />
        <Tile
          label={t('communityAdmin.dashboard.sanctions')}
          value={nf.format(stats.activeSanctions)}
          sub={fill(t('communityAdmin.dashboard.helpful'), { n: stats.helpfulReactions })}
        />
      </div>
      <div>
        <Button size="sm" onClick={onOpenQueue}>
          {t('communityAdmin.dashboard.toQueue')}
        </Button>
      </div>
      <Section title={t('communityAdmin.dashboard.dailyTitle')} hint={t('communityAdmin.dashboard.dailyHint')}>
        {stats.daily.length === 0 ? (
          <p style={hintStyle}>{t('communityAdmin.dashboard.noActivity')}</p>
        ) : (
          <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 'var(--text-xs)' }}>
            <caption style={{ textAlign: 'left', ...hintStyle }}>{t('communityAdmin.dashboard.dailyCaption')}</caption>
            <thead>
              <tr>
                <th scope="col" style={{ textAlign: 'left' }}>{t('communityAdmin.dashboard.colDate')}</th>
                <th scope="col" style={{ textAlign: 'right' }}>{t('communityAdmin.dashboard.posts')}</th>
                <th scope="col" style={{ textAlign: 'right' }}>{t('communityAdmin.dashboard.replies')}</th>
                <th scope="col" aria-hidden="true" style={{ width: '50%' }} />
              </tr>
            </thead>
            <tbody>
              {stats.daily.map((day) => (
                <tr key={day.date}>
                  <td style={{ padding: '2px 0' }}>{day.date}</td>
                  <td style={{ textAlign: 'right', fontVariantNumeric: 'tabular-nums' }}>{day.posts}</td>
                  <td style={{ textAlign: 'right', fontVariantNumeric: 'tabular-nums' }}>{day.replies}</td>
                  <td aria-hidden="true" style={{ paddingLeft: 10 }}>
                    <div style={{ display: 'flex', height: 8, gap: 2 }}>
                      <span style={{ width: `${(day.posts / maxDaily) * 100}%`, background: 'var(--brand)', borderRadius: 4 }} />
                      <span style={{ width: `${(day.replies / maxDaily) * 100}%`, background: 'var(--sky)', borderRadius: 4 }} />
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Section>
    </div>
  );
}
