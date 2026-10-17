'use client';

import { FormEvent, useState } from 'react';

import {
  type CommunityPermissions,
  communityAdminApi,
  type FilterEntry,
  type FiltersConfig,
  normalizeDomainInput,
  normalizeTermInput,
  SERVER_FIXED_SETTINGS,
} from '../../lib/community-admin';
import { useLocale } from '../locale-provider';
import { Alert, Badge, Button, ConfirmDialog, EmptyState, Field, Input, Textarea } from '../ui';
import { enumLabel, errorText, fill, formatDate, hintStyle, LoadError, Section, useLoader } from './shared';

/**
 * Réglages du filtre (§8.8) : liste blanche des liens, termes filtrés, essai
 * du filtre. Les seuils et la version de la charte sont fixés côté serveur
 * (§4.3, §9.3, §9.4) : affichés en lecture, « bientôt modifiables ».
 */
export function SettingsPanel({ permissions }: Readonly<{ permissions: CommunityPermissions }>) {
  const { t } = useLocale();
  const filters = useLoader<FiltersConfig>(() => communityAdminApi.filters(), []);
  const [notice, setNotice] = useState<string | null>(null);
  const [removing, setRemoving] = useState<FilterEntry | null>(null);
  const [removeBusy, setRemoveBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function add(kind: 'allowed_domain' | 'blocked_term', value: string) {
    setError(null);
    setNotice(null);
    await communityAdminApi.addFilter(kind, value);
    setNotice(t('communityAdmin.settings.added'));
    await filters.reload();
  }

  async function remove() {
    if (!removing) return;
    setRemoveBusy(true);
    setError(null);
    try {
      await communityAdminApi.removeFilter(removing.id);
      setRemoving(null);
      setNotice(t('communityAdmin.settings.removed'));
      await filters.reload();
    } catch (e) {
      setError(errorText(t, e));
    } finally {
      setRemoveBusy(false);
    }
  }

  return (
    <div style={{ display: 'grid', gap: 12 }}>
      {notice ? <Alert variant="success">{notice}</Alert> : null}
      {error ? <Alert variant="danger">{error}</Alert> : null}
      {filters.error ? (
        <LoadError error={filters.error} />
      ) : !filters.data ? (
        <EmptyState title={t('communityAdmin.loading')} />
      ) : (
        <FiltersView config={filters.data} canEdit={permissions.configureFilters} onAdd={add} onRemove={setRemoving} />
      )}
      <FilterTester />
      <FixedSettings />
      <ConfirmDialog
        open={removing !== null}
        title={t('communityAdmin.settings.removeTitle')}
        description={removing?.value}
        confirmLabel={t('communityAdmin.settings.removeCta')}
        cancelLabel={t('communityAdmin.cancel')}
        variant="danger"
        loading={removeBusy}
        onConfirm={() => void remove()}
        onCancel={() => setRemoving(null)}
      />
    </div>
  );
}

export function FiltersView({
  config,
  canEdit,
  onAdd,
  onRemove,
}: Readonly<{
  config: FiltersConfig;
  canEdit: boolean;
  onAdd: (kind: 'allowed_domain' | 'blocked_term', value: string) => Promise<void>;
  onRemove: (entry: FilterEntry) => void;
}>) {
  const { t } = useLocale();
  return (
    <>
      <Section
        title={t('communityAdmin.settings.domainsTitle')}
        hint={fill(t('communityAdmin.settings.domainsHint'), { n: config.allowedDomains.catalogHostsCount })}
      >
        <details>
          <summary style={{ cursor: 'pointer', fontSize: 'var(--text-sm)' }}>
            {fill(t('communityAdmin.settings.builtin'), { n: config.allowedDomains.builtin.length })}
          </summary>
          <p style={{ ...hintStyle, overflowWrap: 'anywhere' }}>{config.allowedDomains.builtin.join(' · ')}</p>
        </details>
        <EntryList entries={config.allowedDomains.custom} canEdit={canEdit} onRemove={onRemove} />
        {canEdit ? <AddEntryForm kind="allowed_domain" onAdd={onAdd} /> : <ReadOnlyNote />}
      </Section>
      <Section
        title={t('communityAdmin.settings.termsTitle')}
        hint={fill(t('communityAdmin.settings.termsHint'), { n: config.blockedTerms.builtinCount })}
      >
        <EntryList entries={config.blockedTerms.custom} canEdit={canEdit} onRemove={onRemove} />
        {canEdit ? <AddEntryForm kind="blocked_term" onAdd={onAdd} /> : <ReadOnlyNote />}
      </Section>
    </>
  );
}

function ReadOnlyNote() {
  const { t } = useLocale();
  return <p style={hintStyle}>{t('communityAdmin.settings.readOnly')}</p>;
}

function EntryList({
  entries,
  canEdit,
  onRemove,
}: Readonly<{ entries: readonly FilterEntry[]; canEdit: boolean; onRemove: (entry: FilterEntry) => void }>) {
  const { t, locale } = useLocale();
  if (entries.length === 0) return <p style={hintStyle}>{t('communityAdmin.settings.noCustom')}</p>;
  return (
    <ul style={{ listStyle: 'none', margin: 0, padding: 0, display: 'flex', gap: 6, flexWrap: 'wrap' }}>
      {entries.map((entry) => (
        <li
          key={entry.id}
          title={`${entry.createdBy ?? '—'} · ${formatDate(entry.createdAt, locale)}`}
          style={{ display: 'inline-flex', gap: 4, alignItems: 'center', border: '1px solid var(--border)', borderRadius: 999, padding: '2px 4px 2px 10px', fontSize: 'var(--text-sm)' }}
        >
          {entry.value}
          {canEdit ? (
            <Button size="sm" variant="ghost" aria-label={`${t('communityAdmin.settings.removeCta')} ${entry.value}`} onClick={() => onRemove(entry)}>
              ×
            </Button>
          ) : null}
        </li>
      ))}
    </ul>
  );
}

function AddEntryForm({
  kind,
  onAdd,
}: Readonly<{ kind: 'allowed_domain' | 'blocked_term'; onAdd: (kind: 'allowed_domain' | 'blocked_term', value: string) => Promise<void> }>) {
  const { t } = useLocale();
  const [value, setValue] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const normalized = kind === 'allowed_domain' ? normalizeDomainInput(value) : normalizeTermInput(value);
    if (!normalized) {
      setError(t(kind === 'allowed_domain' ? 'communityAdmin.errors.domainInvalid' : 'communityAdmin.errors.termInvalid'));
      return;
    }
    setBusy(true);
    setError(null);
    try {
      await onAdd(kind, normalized);
      setValue('');
    } catch (e) {
      setError(errorText(t, e));
    } finally {
      setBusy(false);
    }
  }

  return (
    <form onSubmit={submit} style={{ display: 'flex', gap: 8, alignItems: 'flex-end', flexWrap: 'wrap' }}>
      <div style={{ flex: '1 1 240px' }}>
        <Field label={t(`communityAdmin.settings.add_${kind}`)} error={error ?? undefined}>
          {({ id, invalid }) => (
            <Input
              id={id}
              invalid={invalid}
              value={value}
              placeholder={kind === 'allowed_domain' ? 'univ-lyon1.fr, *.univ-lyon1.fr' : t('communityAdmin.settings.termPlaceholder')}
              onChange={(e) => setValue(e.target.value)}
            />
          )}
        </Field>
      </div>
      <Button type="submit" loading={busy} disabled={!value.trim()}>
        {t('communityAdmin.settings.addCta')}
      </Button>
    </form>
  );
}

/** Essai du filtre (§8.8, rôle R) : colle un texte, vois les drapeaux. */
function FilterTester() {
  const { t } = useLocale();
  const [text, setText] = useState('');
  const [result, setResult] = useState<{ flags: string[]; wouldHide: boolean } | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!text.trim()) return;
    setBusy(true);
    setError(null);
    try {
      setResult(await communityAdminApi.testFilter(text));
    } catch (e) {
      setError(errorText(t, e));
      setResult(null);
    } finally {
      setBusy(false);
    }
  }

  return (
    <Section title={t('communityAdmin.settings.testTitle')} hint={t('communityAdmin.settings.testHint')}>
      <form onSubmit={submit} style={{ display: 'grid', gap: 8 }}>
        <Field label={t('communityAdmin.settings.testLabel')}>
          {({ id }) => <Textarea id={id} maxLength={5000} value={text} onChange={(e) => setText(e.target.value)} />}
        </Field>
        <div>
          <Button type="submit" variant="secondary" loading={busy} disabled={!text.trim()}>
            {t('communityAdmin.settings.testCta')}
          </Button>
        </div>
        {error ? <Alert variant="danger">{error}</Alert> : null}
        {result ? (
          <Alert variant={result.wouldHide ? 'warning' : 'success'}>
            {result.wouldHide ? t('communityAdmin.settings.wouldHide') : t('communityAdmin.settings.wouldPass')}{' '}
            {result.flags.map((flag) => (
              <Badge key={flag} variant="danger">
                {enumLabel(t, 'flag', flag)}
              </Badge>
            ))}
          </Alert>
        ) : null}
      </form>
    </Section>
  );
}

/** Seuils et charte : fixés par le serveur (pas de route), affichés pour mémoire. */
export function FixedSettings() {
  const { t } = useLocale();
  const s = SERVER_FIXED_SETTINGS;
  const rows: Array<[string, string]> = [
    ['reportsBeforeHide', String(s.reportsBeforeHide)],
    ['newAccount', fill(t('communityAdmin.settings.days'), { n: s.newAccountDays })],
    ['postsPerDay', `${s.postsPerDayNew} / ${s.postsPerDayEstablished}`],
    ['repliesPerHour', `${s.repliesPerHourNew} / ${s.repliesPerHourEstablished}`],
    ['reportsPerDay', String(s.reportsPerDay)],
    ['editWindow', `${s.editWindowMinutes} min`],
    ['charterVersion', s.charterVersion],
  ];
  return (
    <Section
      title={t('communityAdmin.settings.fixedTitle')}
      hint={t('communityAdmin.settings.fixedHint')}
      actions={<Badge variant="info">{t('communityAdmin.soon.badge')}</Badge>}
    >
      <dl style={{ margin: 0, display: 'grid', gridTemplateColumns: 'minmax(200px, 1fr) auto', gap: '6px 16px', fontSize: 'var(--text-sm)' }}>
        {rows.map(([key, value]) => (
          <div key={key} style={{ display: 'contents' }}>
            <dt style={{ color: 'var(--text-muted)' }}>{t(`communityAdmin.settings.fixed.${key}`)}</dt>
            <dd style={{ margin: 0, fontWeight: 700 }}>{value}</dd>
          </div>
        ))}
      </dl>
    </Section>
  );
}
