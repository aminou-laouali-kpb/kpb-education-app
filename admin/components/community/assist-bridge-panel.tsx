'use client';

import { useEffect, useState } from 'react';

import {
  ASSIST_EVENT_STATUSES,
  ASSIST_LIST_STATUSES,
  ASSIST_NEED_IDS,
  ASSIST_SOURCES,
  ASSIST_STATUS_VARIANT,
  type AssistCatalog,
  type AssistEvent,
  type AssistEventFilters,
  type AssistEventPage,
  type AssistListStatus,
  type AssistSource,
  type AssistStats,
  assistExcerpt,
  assistSkippedEntries,
  communityAdminApi,
  rawLabel,
} from '../../lib/community-admin';
import { useLocale } from '../locale-provider';
import { Alert, Badge, Button, EmptyState, Field, Select } from '../ui';
import { errorText, fill, formatDate, hintStyle, LoadError, panelCardStyle, Section, type Translate, useLoader } from './shared';

/** Libellé `communityAdmin.assistBridge.<groupe>.<valeur>`, valeur brute si inconnue. */
function assistLabel(t: Translate, group: string, value: string | null | undefined): string {
  if (!value) return '—';
  const key = `communityAdmin.assistBridge.${group}.${value}`;
  const label = t(key);
  return label === key ? rawLabel(value) : label;
}

export function AssistStatusBadge({ status }: Readonly<{ status: string }>) {
  const { t } = useLocale();
  const known = (ASSIST_EVENT_STATUSES as readonly string[]).includes(status);
  return (
    <Badge variant={ASSIST_STATUS_VARIANT[status] ?? 'neutral'}>
      {known ? t(`communityAdmin.assistBridge.status.${status}`) : rawLabel(status)}
    </Badge>
  );
}

/**
 * Bot « Passerelle » (révision 3 du contrat, §8.10) : la console en LECTURE
 * SEULE — mode courant, statistiques par besoin, derniers événements (sans
 * texte pour la source coach), catalogue des besoins. Le bot n'écrit rien de
 * public : aucune validation à donner ici.
 */
export function AssistBridgePanel({ onOpenPost }: Readonly<{ onOpenPost: (postId: string) => void }>) {
  const { t } = useLocale();
  const [filters, setFilters] = useState<AssistEventFilters>({ status: 'all' });
  const [showCatalog, setShowCatalog] = useState(false);
  const stats = useLoader<AssistStats>(() => communityAdminApi.assistStats(30), []);
  const list = useLoader<AssistEventPage>(
    () => communityAdminApi.assistEvents(filters),
    [filters.status, filters.needId, filters.source],
  );
  const catalog = useLoader<AssistCatalog>(() => communityAdminApi.assistCatalog(), [], showCatalog);
  const [extra, setExtra] = useState<AssistEvent[]>([]);
  const [moreError, setMoreError] = useState<string | null>(null);
  const items = [...(list.data?.items ?? []), ...extra];
  const cursor = extra.length ? undefined : list.data?.nextCursor;

  useEffect(() => setExtra([]), [list.data]);

  async function more() {
    if (!list.data?.nextCursor) return;
    try {
      const page = await communityAdminApi.assistEvents(filters, list.data.nextCursor);
      setExtra((current) => [...current, ...page.items]);
    } catch (e) {
      setMoreError(errorText(t, e));
    }
  }

  return (
    <div style={{ display: 'grid', gap: 12 }}>
      {stats.data ? <AssistStatsView stats={stats.data} /> : stats.error ? <LoadError error={stats.error} /> : null}
      <Section title={t('communityAdmin.assistBridge.eventsTitle')} hint={t('communityAdmin.assistBridge.eventsHint')}>
        <AssistFiltersBar filters={filters} onChange={setFilters} />
        {moreError ? <Alert variant="danger">{moreError}</Alert> : null}
        {list.error ? (
          <LoadError error={list.error} />
        ) : list.loading && !list.data ? (
          <EmptyState title={t('communityAdmin.loading')} />
        ) : (
          <>
            <AssistEventList items={items} onOpenPost={onOpenPost} />
            {cursor ? (
              <div>
                <Button variant="secondary" size="sm" onClick={() => void more()}>
                  {t('communityAdmin.loadMore')}
                </Button>
              </div>
            ) : null}
          </>
        )}
      </Section>
      <Section
        title={t('communityAdmin.assistBridge.catalogTitle')}
        hint={t('communityAdmin.assistBridge.catalogHint')}
        actions={
          <Button variant="secondary" size="sm" aria-expanded={showCatalog} onClick={() => setShowCatalog((v) => !v)}>
            {t(showCatalog ? 'communityAdmin.assistBridge.catalogHide' : 'communityAdmin.assistBridge.catalogShow')}
          </Button>
        }
      >
        {showCatalog ? (
          catalog.error ? (
            <LoadError error={catalog.error} />
          ) : catalog.data ? (
            <AssistCatalogView catalog={catalog.data} />
          ) : (
            <EmptyState title={t('communityAdmin.loading')} />
          )
        ) : null}
      </Section>
    </div>
  );
}

function AssistFiltersBar({
  filters,
  onChange,
}: Readonly<{ filters: AssistEventFilters; onChange: (next: AssistEventFilters) => void }>) {
  const { t } = useLocale();
  return (
    <div style={{ display: 'grid', gap: 8, gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))' }}>
      <Field label={t('communityAdmin.assistBridge.filterStatus')}>
        {({ id }) => (
          <Select
            id={id}
            value={filters.status ?? 'all'}
            onChange={(e) => onChange({ ...filters, status: e.target.value as AssistListStatus })}
          >
            {ASSIST_LIST_STATUSES.map((s) => (
              <option key={s} value={s}>
                {s === 'all' ? t('communityAdmin.all') : t(`communityAdmin.assistBridge.status.${s}`)}
              </option>
            ))}
          </Select>
        )}
      </Field>
      <Field label={t('communityAdmin.assistBridge.filterNeed')}>
        {({ id }) => (
          <Select id={id} value={filters.needId ?? ''} onChange={(e) => onChange({ ...filters, needId: e.target.value || undefined })}>
            <option value="">{t('communityAdmin.all')}</option>
            {ASSIST_NEED_IDS.map((n) => (
              <option key={n} value={n}>
                {t(`communityAdmin.assistBridge.need.${n}`)}
              </option>
            ))}
          </Select>
        )}
      </Field>
      <Field label={t('communityAdmin.assistBridge.filterSource')}>
        {({ id }) => (
          <Select
            id={id}
            value={filters.source ?? ''}
            onChange={(e) => onChange({ ...filters, source: (e.target.value || undefined) as AssistSource | undefined })}
          >
            <option value="">{t('communityAdmin.all')}</option>
            {ASSIST_SOURCES.map((s) => (
              <option key={s} value={s}>
                {t(`communityAdmin.assistBridge.source.${s}`)}
              </option>
            ))}
          </Select>
        )}
      </Field>
    </div>
  );
}

export function AssistStatsView({ stats }: Readonly<{ stats: AssistStats }>) {
  const { t } = useLocale();
  const tot = stats.totals;
  const tiles: Array<[string, string]> = [
    [t('communityAdmin.assistBridge.stats.detected'), String(tot.detected)],
    [t('communityAdmin.assistBridge.stats.sent'), String(tot.sent)],
    [t('communityAdmin.assistBridge.stats.wouldSend'), String(tot.wouldSend)],
    [t('communityAdmin.assistBridge.stats.openedFeature'), String(tot.openedFeature)],
    [t('communityAdmin.assistBridge.stats.openedWhatsapp'), String(tot.openedWhatsapp)],
    [t('communityAdmin.assistBridge.stats.dismissed'), String(tot.dismissed)],
  ];
  return (
    <section style={{ ...panelCardStyle, display: 'grid', gap: 10 }} aria-label={t('communityAdmin.assistBridge.stats.title')}>
      <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', alignItems: 'center' }}>
        <strong>{t('communityAdmin.assistBridge.modeLabel')}</strong>
        <Badge variant={stats.mode === 'on' ? 'success' : stats.mode === 'off' ? 'neutral' : 'info'}>
          {assistLabel(t, 'mode', stats.mode)}
        </Badge>
        <Badge variant={stats.coachSource ? 'warning' : 'neutral'}>
          {t(stats.coachSource ? 'communityAdmin.assistBridge.coachOn' : 'communityAdmin.assistBridge.coachOff')}
        </Badge>
        <span style={hintStyle}>{fill(t('communityAdmin.assistBridge.rulesVersion'), { version: stats.rulesVersion })}</span>
      </div>
      <p style={{ ...hintStyle, margin: 0 }}>{assistLabel(t, 'modeHint', stats.mode)}</p>
      <div style={{ display: 'grid', gap: 8, gridTemplateColumns: 'repeat(auto-fit, minmax(130px, 1fr))' }}>
        {tiles.map(([label, value]) => (
          <div key={label} data-tile={label} style={{ display: 'grid', gap: 2 }}>
            <span style={{ fontSize: 'var(--text-xs)', color: 'var(--text-muted)', fontWeight: 700 }}>{label}</span>
            <span style={{ fontSize: 22, fontWeight: 800, fontVariantNumeric: 'tabular-nums' }}>{value}</span>
          </div>
        ))}
      </div>
      <div style={{ overflowX: 'auto' }}>
        <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 'var(--text-sm)' }}>
          <caption style={{ ...hintStyle, textAlign: 'left', paddingBottom: 6 }}>
            {fill(t('communityAdmin.assistBridge.stats.window'), { days: stats.window.days })}
          </caption>
          <thead>
            <tr>
              {['need', 'detected', 'sent', 'wouldSend', 'openedFeature', 'openedWhatsapp', 'dismissed', 'skipped'].map((col) => (
                <th key={col} scope="col" style={{ textAlign: 'left', padding: '4px 8px', color: 'var(--text-muted)', fontSize: 'var(--text-xs)' }}>
                  {t(`communityAdmin.assistBridge.stats.${col}`)}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {stats.needs.map((need) => (
              <tr key={need.needId} data-need={need.needId} style={{ borderTop: '1px solid var(--border)' }}>
                <th scope="row" style={{ textAlign: 'left', padding: '6px 8px', fontWeight: 700 }}>
                  {assistLabel(t, 'need', need.needId)}
                </th>
                {[need.detected, need.sent, need.wouldSend, need.openedFeature, need.openedWhatsapp, need.dismissed].map((n, i) => (
                  <td key={i} style={{ padding: '6px 8px', fontVariantNumeric: 'tabular-nums' }}>
                    {n}
                  </td>
                ))}
                <td style={{ padding: '6px 8px' }}>
                  {assistSkippedEntries(need.skipped)
                    .map(([reason, n]) => `${assistLabel(t, 'reason', reason)} : ${n}`)
                    .join(' · ') || '—'}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </section>
  );
}

export function AssistEventList({
  items,
  onOpenPost,
}: Readonly<{ items: readonly AssistEvent[]; onOpenPost: (postId: string) => void }>) {
  const { t, locale } = useLocale();
  if (items.length === 0) {
    return <EmptyState title={t('communityAdmin.assistBridge.emptyTitle')} description={t('communityAdmin.assistBridge.emptyBody')} />;
  }
  return (
    <ul style={{ listStyle: 'none', margin: 0, padding: 0, display: 'grid', gap: 6 }}>
      {items.map((event) => {
        const excerpt = assistExcerpt(event);
        const isCoach = event.source === 'coach_message';
        return (
          <li key={event.id} data-event-id={event.id} style={{ ...panelCardStyle, padding: 12, display: 'grid', gap: 4 }}>
            <span style={{ display: 'flex', gap: 6, flexWrap: 'wrap', alignItems: 'center' }}>
              <AssistStatusBadge status={event.status} />
              <Badge variant="brand">{assistLabel(t, 'need', event.needId)}</Badge>
              <Badge variant={isCoach ? 'warning' : 'neutral'}>{assistLabel(t, 'source', event.source)}</Badge>
              {event.statusReason ? <span style={hintStyle}>{assistLabel(t, 'reason', event.statusReason)}</span> : null}
            </span>
            {isCoach ? (
              <span style={hintStyle}>{t('communityAdmin.assistBridge.coachPrivate')}</span>
            ) : excerpt ? (
              <span style={{ fontSize: 'var(--text-sm)' }}>« {excerpt} »</span>
            ) : (
              <span style={hintStyle}>{t('communityAdmin.assistBridge.noExcerpt')}</span>
            )}
            <span style={hintStyle}>
              {[
                fill(t('communityAdmin.assistBridge.detectedAt'), { date: formatDate(event.createdAt, locale) }),
                event.sentAt ? fill(t('communityAdmin.assistBridge.sentAt'), { date: formatDate(event.sentAt, locale) }) : null,
                event.ruleId,
              ]
                .filter(Boolean)
                .join(' · ')}
            </span>
            {!isCoach && event.postId ? (
              <div>
                <Button variant="ghost" size="sm" onClick={() => onOpenPost(event.postId!)}>
                  {t('communityAdmin.assistBridge.openPost')}
                </Button>
              </div>
            ) : null}
          </li>
        );
      })}
    </ul>
  );
}

export function AssistCatalogView({ catalog }: Readonly<{ catalog: AssistCatalog }>) {
  const { t, locale } = useLocale();
  return (
    <div style={{ display: 'grid', gap: 8 }}>
      <p style={{ ...hintStyle, margin: 0 }}>
        {fill(t('communityAdmin.assistBridge.catalogMeta'), { version: catalog.version, words: catalog.minWords })}
      </p>
      <ul style={{ listStyle: 'none', margin: 0, padding: 0, display: 'grid', gap: 8 }}>
        {catalog.needs.map((need) => (
          <li key={need.id} data-catalog-need={need.id} style={{ ...panelCardStyle, padding: 12, display: 'grid', gap: 4 }}>
            <strong>{locale === 'en' ? need.label.en : need.label.fr}</strong>
            <span style={hintStyle}>
              {fill(t('communityAdmin.assistBridge.catalogTarget'), {
                feature: locale === 'en' ? need.featureLabel.en : need.featureLabel.fr,
                route: need.route,
              })}
            </span>
            <div style={{ display: 'grid', gap: 2, fontSize: 'var(--text-sm)' }}>
              <span>
                <strong>FR</strong> — {need.title.fr} : {need.body.fr}
              </span>
              <span>
                <strong>EN</strong> — {need.title.en}: {need.body.en}
              </span>
            </div>
            <span style={hintStyle}>{need.rules.map((r) => r.id).join(' · ')}</span>
          </li>
        ))}
      </ul>
    </div>
  );
}
