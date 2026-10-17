'use client';

import { CSSProperties, ReactNode, useCallback, useEffect, useRef, useState } from 'react';

import {
  type AdminAuthor,
  type AdminReport,
  communityErrorMessageKey,
  enumMessageKey,
  isNewAccount,
  type Mention,
  rawLabel,
  readCommunityError,
  type Segment,
  STATUS_VARIANT,
  visibleIdentity,
} from '../../lib/community-admin';
import { useLocale } from '../locale-provider';
import { Alert, Badge, EmptyState } from '../ui';

export type Translate = (key: string) => string;

export const panelCardStyle: CSSProperties = {
  background: 'var(--surface)',
  border: '1px solid var(--border)',
  borderRadius: 16,
  padding: 16,
};

export const panelTitleStyle: CSSProperties = {
  margin: 0,
  fontSize: 'var(--text-base)',
  fontWeight: 800,
  color: 'var(--ink)',
};

export const hintStyle: CSSProperties = {
  margin: '4px 0 0',
  fontSize: 'var(--text-xs)',
  color: 'var(--text-muted)',
};

/** Libellé d'une valeur d'énumération ; valeur brute lisible si inconnue. */
export function enumLabel(
  t: Translate,
  group: Parameters<typeof enumMessageKey>[0],
  value: string,
): string {
  const key = enumMessageKey(group, value);
  if (!key) return rawLabel(value);
  const label = t(key);
  return label === key ? rawLabel(value) : label;
}

/** Remplace `{name}` par sa valeur dans un message. */
export function fill(template: string, values: Record<string, string | number>): string {
  return Object.entries(values).reduce(
    (text, [name, value]) => text.split(`{${name}}`).join(String(value)),
    template,
  );
}

export function formatDate(iso: string | null | undefined, locale: 'fr' | 'en'): string {
  if (!iso) return '—';
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return '—';
  return new Intl.DateTimeFormat(locale === 'fr' ? 'fr-FR' : 'en-GB', {
    dateStyle: 'medium',
    timeStyle: 'short',
    timeZone: 'UTC',
  }).format(date);
}

/** Texte d'erreur à afficher (message dédié du contrat, sinon celui du serveur). */
export function errorText(t: Translate, error: unknown): string {
  const info = readCommunityError(error);
  const key = communityErrorMessageKey(info);
  if (key) {
    const label = t(key);
    if (label !== key) return label;
  }
  return info.message || t('communityAdmin.errors.server');
}

/**
 * État « bientôt » : la route n'existe pas encore sur ce serveur. Ton neutre,
 * jamais une alerte rouge — l'équipe n'a rien à corriger.
 */
export function SoonState({ title, description }: Readonly<{ title?: string; description?: string }>) {
  const { t } = useLocale();
  return (
    <div data-state="soon">
      <EmptyState
        title={
          <>
            <Badge variant="info">{t('communityAdmin.soon.badge')}</Badge> {title ?? t('communityAdmin.soon.title')}
          </>
        }
        description={description ?? t('communityAdmin.soon.body')}
      />
    </div>
  );
}

/** Erreur de chargement : « bientôt » si la route manque, sinon alerte. */
export function LoadError({ error }: Readonly<{ error: unknown }>) {
  const { t } = useLocale();
  if (readCommunityError(error).unavailable) return <SoonState />;
  return <Alert variant="danger">{errorText(t, error)}</Alert>;
}

/** Chargement asynchrone minimal (données, chargement, erreur, recharger). */
export function useLoader<T>(loader: () => Promise<T>, deps: readonly unknown[], enabled = true) {
  const [data, setData] = useState<T | null>(null);
  const [error, setError] = useState<unknown>(null);
  const [loading, setLoading] = useState(enabled);
  const counter = useRef(0);

  const reload = useCallback(async () => {
    const ticket = ++counter.current;
    setLoading(true);
    setError(null);
    try {
      const value = await loader();
      if (ticket === counter.current) setData(value);
    } catch (e) {
      if (ticket === counter.current) setError(e);
    } finally {
      if (ticket === counter.current) setLoading(false);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, deps);

  // Nouvelle cible (autre membre, autre filtre) : on oublie l'ancienne donnée
  // pour ne pas l'afficher pendant le chargement. Un rechargement après une
  // action (appel direct de `reload`) garde l'affichage en place.
  useEffect(() => {
    setData(null);
    if (enabled) void reload();
  }, [enabled, reload]);

  return { data, setData, error, loading, reload };
}

export function ContentStatusBadge({ status }: Readonly<{ status: string }>) {
  const { t } = useLocale();
  return <Badge variant={STATUS_VARIANT[status] ?? 'neutral'}>{enumLabel(t, 'status', status)}</Badge>;
}

export function FlagBadges({ flags }: Readonly<{ flags: readonly string[] | undefined }>) {
  const { t } = useLocale();
  if (!flags || flags.length === 0) return null;
  return (
    <span style={{ display: 'inline-flex', gap: 4, flexWrap: 'wrap' }} aria-label={t('communityAdmin.flagsLabel')}>
      {flags.map((flag) => (
        <Badge key={flag} variant="danger">
          {enumLabel(t, 'flag', flag)}
        </Badge>
      ))}
    </span>
  );
}

/**
 * Rendu des segments servis par le serveur (§5.3). Aucun parsing côté
 * console ; un segment inconnu est rendu comme texte s'il en porte un. Les
 * liens ne sont pas cliquables : un modérateur ne doit pas ouvrir par
 * mégarde un lien d'arnaque — l'URL est affichée en clair.
 */
export function SegmentsView({
  segments,
  fallback,
}: Readonly<{ segments: readonly Segment[] | undefined; fallback?: string }>) {
  if (!segments || segments.length === 0) {
    return <p style={{ margin: 0, whiteSpace: 'pre-wrap' }}>{fallback ?? ''}</p>;
  }
  return (
    <p style={{ margin: 0, whiteSpace: 'pre-wrap', overflowWrap: 'anywhere' }}>
      {segments.map((segment, index) => {
        if (segment.kind === 'mention') {
          return (
            <mark
              key={index}
              data-segment="mention"
              title={`${String(segment.type)}:${String(segment.id)}`}
              style={{ background: 'var(--brand-soft, rgba(56,189,248,0.16))', borderRadius: 6, padding: '0 3px' }}
            >
              @{String(segment.label)}
            </mark>
          );
        }
        if (segment.kind === 'hashtag') {
          return (
            <span key={index} data-segment="hashtag" style={{ color: 'var(--brand)', fontWeight: 700 }}>
              #{String(segment.display ?? segment.tag)}
            </span>
          );
        }
        if (segment.kind === 'link') {
          return (
            <code key={index} data-segment="link">
              {String(segment.text ?? segment.url)}
            </code>
          );
        }
        return typeof segment.text === 'string' ? <span key={index}>{segment.text}</span> : null;
      })}
    </p>
  );
}

export function MentionList({ mentions }: Readonly<{ mentions: readonly Mention[] | undefined }>) {
  const { t } = useLocale();
  if (!mentions || mentions.length === 0) return null;
  return (
    <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', alignItems: 'center' }}>
      <span style={hintStyle}>{t('communityAdmin.mentions')}</span>
      {mentions.map((m) => (
        <Badge key={`${m.type}:${m.id}`} variant="brand">
          {m.label} · {rawLabel(String(m.type))}
        </Badge>
      ))}
    </div>
  );
}

/**
 * Ligne d'auteur : nom public, pays, badges, indicateurs dérivés (mineur,
 * compte récent). L'identité réelle n'apparaît qu'avec le droit dédié.
 */
export function AuthorLine({
  author,
  canViewIdentity,
  onOpenMember,
}: Readonly<{ author: AdminAuthor; canViewIdentity: boolean; onOpenMember?: (memberId: string) => void }>) {
  const { t, locale } = useLocale();
  const identity = visibleIdentity(author, canViewIdentity);
  const name =
    author.memberId && onOpenMember ? (
      <button
        type="button"
        onClick={() => onOpenMember(author.memberId as string)}
        style={{ border: 'none', background: 'none', padding: 0, color: 'var(--brand)', fontWeight: 800, cursor: 'pointer' }}
      >
        {author.displayName}
      </button>
    ) : (
      <strong>{author.displayName}</strong>
    );
  return (
    <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', alignItems: 'center', fontSize: 'var(--text-sm)' }}>
      {name}
      {author.countryName ? <span style={{ color: 'var(--text-muted)' }}>· {author.countryName}</span> : null}
      {author.badges?.map((badge) => (
        <Badge key={badge} variant="info">
          {enumLabel(t, 'badge', badge)}
        </Badge>
      ))}
      {author.isMinor ? <Badge variant="warning">{t('communityAdmin.minor')}</Badge> : null}
      {isNewAccount(author) ? <Badge variant="neutral">{t('communityAdmin.newAccount')}</Badge> : null}
      {identity.fullName || identity.email ? (
        <span data-identity="real" style={{ color: 'var(--text-muted)' }}>
          · {[identity.fullName, identity.email].filter(Boolean).join(' · ')}
          {identity.accountCreatedAt
            ? ` · ${t('communityAdmin.accountSince')} ${formatDate(identity.accountCreatedAt, locale)}`
            : ''}
        </span>
      ) : null}
    </div>
  );
}

export function ReportsList({ reports }: Readonly<{ reports: readonly AdminReport[] }>) {
  const { t, locale } = useLocale();
  if (reports.length === 0) return <p style={hintStyle}>{t('communityAdmin.noReports')}</p>;
  return (
    <ul style={{ margin: 0, paddingLeft: 18, display: 'grid', gap: 4, fontSize: 'var(--text-sm)' }}>
      {reports.map((report) => (
        <li key={report.id}>
          <Badge variant={report.reason === 'scam' || report.reason === 'personal_info' ? 'danger' : 'warning'}>
            {enumLabel(t, 'reportReason', report.reason)}
          </Badge>{' '}
          <span style={{ color: 'var(--text-muted)' }}>
            {report.reporter?.displayName ?? t('communityAdmin.reporterDeleted')} · {formatDate(report.createdAt, locale)}
          </span>
          {report.details ? <div style={{ whiteSpace: 'pre-wrap' }}>« {report.details} »</div> : null}
        </li>
      ))}
    </ul>
  );
}

export function Section({
  title,
  hint,
  actions,
  children,
}: Readonly<{ title: string; hint?: string; actions?: ReactNode; children: ReactNode }>) {
  return (
    <section style={{ ...panelCardStyle, display: 'grid', gap: 12 }}>
      <div style={{ display: 'flex', gap: 10, alignItems: 'flex-start', justifyContent: 'space-between', flexWrap: 'wrap' }}>
        <div>
          <h3 style={panelTitleStyle}>{title}</h3>
          {hint ? <p style={hintStyle}>{hint}</p> : null}
        </div>
        {actions}
      </div>
      {children}
    </section>
  );
}
