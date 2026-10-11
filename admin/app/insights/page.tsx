'use client';

import { CSSProperties, useEffect, useState } from 'react';

import { useAdminAuth } from '../../components/admin-auth-provider';
import { DashboardShell } from '../../components/dashboard-shell';
import { useLocale } from '../../components/locale-provider';
import {
  AdminTable,
  AdminTableRow,
  Alert,
  Button,
  CellText,
  EmptyState,
  Field,
  Input,
} from '../../components/ui';
import { apiFetch } from '../../lib/api-client';

interface InsightsResponse {
  range: { from: string; to: string };
  totals: {
    totalUsers: number;
    activeLast24h: number;
    activeLast48h: number;
    activeLast7d: number;
    activeLast30d: number;
    signupsLast7d: number;
  };
  period: { signups: number; active: number };
  daily: { date: string; signups: number; active: number }[];
  generatedAt: string;
}

const cardStyle: CSSProperties = {
  background: 'var(--surface)',
  border: '1px solid var(--border)',
  borderRadius: 16,
  padding: 16,
};

function isoDay(offsetDays: number): string {
  return new Date(Date.now() + offsetDays * 86_400_000)
    .toISOString()
    .slice(0, 10);
}

function Kpi({ label, value }: Readonly<{ label: string; value: number }>) {
  return (
    <div
      style={{
        background: 'var(--bg)',
        border: '1px solid var(--border-soft)',
        borderRadius: 12,
        padding: '11px 12px',
      }}
    >
      <p
        style={{
          margin: 0,
          fontSize: 9.5,
          fontWeight: 800,
          letterSpacing: '0.06em',
          textTransform: 'uppercase',
          color: 'var(--text-faint)',
        }}
      >
        {label}
      </p>
      <p
        style={{
          margin: '6px 0 0',
          fontSize: 24,
          fontWeight: 800,
          letterSpacing: '-0.5px',
          color: 'var(--ink)',
        }}
      >
        {new Intl.NumberFormat('fr-FR').format(value)}
      </p>
    </div>
  );
}

const gridStyle: CSSProperties = {
  display: 'grid',
  gap: 10,
  marginTop: 14,
  gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))',
};

export default function InsightsPage() {
  const { session } = useAdminAuth();
  const { t } = useLocale();
  const [from, setFrom] = useState(() => isoDay(-29));
  const [to, setTo] = useState(() => isoDay(0));
  const [data, setData] = useState<InsightsResponse | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  function load(nextFrom: string, nextTo: string) {
    setLoading(true);
    apiFetch<InsightsResponse>(
      `/admin/insights?from=${encodeURIComponent(nextFrom)}&to=${encodeURIComponent(nextTo)}`,
    )
      .then((response) => {
        setData(response);
        setErrorMessage(null);
      })
      .catch((error) =>
        setErrorMessage(
          error instanceof Error ? error.message : t('insights.loadError'),
        ),
      )
      .finally(() => setLoading(false));
  }

  useEffect(() => {
    if (session) {
      load(from, to);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [session]);

  function applyPreset(days: number) {
    const nextFrom = isoDay(-(days - 1));
    const nextTo = isoDay(0);
    setFrom(nextFrom);
    setTo(nextTo);
    load(nextFrom, nextTo);
  }

  const invalidRange = from === '' || to === '' || from > to;
  const maxDaily = Math.max(
    1,
    ...(data?.daily ?? []).map((d) => Math.max(d.signups, d.active)),
  );

  return (
    <DashboardShell
      title={t('insights.title')}
      subtitle={t('insights.subtitle')}
    >
      <div style={{ display: 'grid', gap: 14 }}>
        {errorMessage ? <Alert variant="danger">{errorMessage}</Alert> : null}

        <section style={cardStyle} aria-label={t('insights.overviewTitle')}>
          <h3 style={{ margin: 0, fontSize: 'var(--text-base)', fontWeight: 800 }}>
            {t('insights.overviewTitle')}
          </h3>
          <div style={gridStyle}>
            <Kpi label={t('insights.totalUsers')} value={data?.totals.totalUsers ?? 0} />
            <Kpi label={t('insights.active24h')} value={data?.totals.activeLast24h ?? 0} />
            <Kpi label={t('insights.active48h')} value={data?.totals.activeLast48h ?? 0} />
            <Kpi label={t('insights.active7d')} value={data?.totals.activeLast7d ?? 0} />
            <Kpi label={t('insights.active30d')} value={data?.totals.activeLast30d ?? 0} />
            <Kpi label={t('insights.signups7d')} value={data?.totals.signupsLast7d ?? 0} />
          </div>
          <p style={{ margin: '10px 0 0', fontSize: 'var(--text-xs)', color: 'var(--text-muted)' }}>
            {t('insights.activeDefinition')}
          </p>
        </section>

        <section style={cardStyle} aria-label={t('insights.periodTitle')}>
          <h3 style={{ margin: 0, fontSize: 'var(--text-base)', fontWeight: 800 }}>
            {t('insights.periodTitle')}
          </h3>
          <div
            style={{
              display: 'flex',
              flexWrap: 'wrap',
              gap: 10,
              alignItems: 'flex-end',
              marginTop: 12,
            }}
          >
            <Field label={t('insights.from')}>
              {({ id }) => (
                <Input id={id} type="date" value={from} max={to} onChange={(e) => setFrom(e.target.value)} />
              )}
            </Field>
            <Field label={t('insights.to')}>
              {({ id }) => (
                <Input id={id} type="date" value={to} min={from} onChange={(e) => setTo(e.target.value)} />
              )}
            </Field>
            <Button onClick={() => load(from, to)} disabled={invalidRange || loading}>
              {t('insights.apply')}
            </Button>
            <Button variant="ghost" onClick={() => applyPreset(2)} disabled={loading}>
              {t('insights.preset48h')}
            </Button>
            <Button variant="ghost" onClick={() => applyPreset(7)} disabled={loading}>
              {t('insights.preset7d')}
            </Button>
            <Button variant="ghost" onClick={() => applyPreset(30)} disabled={loading}>
              {t('insights.preset30d')}
            </Button>
          </div>
          <div style={gridStyle}>
            <Kpi label={t('insights.periodSignups')} value={data?.period.signups ?? 0} />
            <Kpi label={t('insights.periodActive')} value={data?.period.active ?? 0} />
          </div>
        </section>

        <AdminTable
          title={t('insights.dailyTitle')}
          columns={[t('insights.colDate'), t('insights.colSignups'), t('insights.colActive')]}
          cols="1fr 1.4fr 1.4fr"
        >
          {!data || data.daily.length === 0 ? (
            <EmptyState title={t('insights.empty')} />
          ) : (
            [...data.daily].reverse().map((row) => (
              <AdminTableRow key={row.date}>
                <CellText primary={row.date} />
                <Bar value={row.signups} max={maxDaily} color="var(--sky)" />
                <Bar value={row.active} max={maxDaily} color="var(--brand)" />
              </AdminTableRow>
            ))
          )}
        </AdminTable>
      </div>
    </DashboardShell>
  );
}

function Bar({
  value,
  max,
  color,
}: Readonly<{ value: number; max: number; color: string }>) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
      <div
        aria-hidden="true"
        style={{
          height: 8,
          width: `${Math.max(value > 0 ? 2 : 0, (value / max) * 100)}%`,
          maxWidth: '70%',
          borderRadius: 4,
          background: color,
        }}
      />
      <span style={{ fontSize: 'var(--text-sm)', fontWeight: 700 }}>{value}</span>
    </div>
  );
}
