'use client';

import { CSSProperties, FormEvent, useCallback, useEffect, useState } from 'react';

import { DashboardShell } from '../../components/dashboard-shell';
import { useLocale } from '../../components/locale-provider';
import {
  AdminTable,
  AdminTableRow,
  Alert,
  Badge,
  Button,
  CellText,
  ConfirmDialog,
  EmptyState,
  Field,
  Input,
  Select,
  type BadgeVariant,
} from '../../components/ui';
import {
  DURATION_PRESETS,
  EMPTY_PASS_DRAFT,
  PassDraftError,
  fetchPassGrants,
  formatDay,
  grantPass,
  revokePass,
  toPassGrantInput,
  type PassDraft,
  type PassGrantResult,
  type PassGrantRow,
  type PassGrantState,
} from '../../lib/pass';
import { fill } from '../../lib/scholarship-opening';

const formStyle: CSSProperties = {
  display: 'grid',
  gap: 12,
  padding: 16,
  border: '1px solid var(--border)',
  borderRadius: 12,
  background: 'var(--surface)',
  marginBottom: 20,
};

const gridStyle: CSSProperties = {
  display: 'grid',
  gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))',
  gap: 10,
};

const STATE_BADGE: Record<PassGrantState, BadgeVariant> = {
  active: 'success',
  upcoming: 'info',
  expired: 'neutral',
  revoked: 'danger',
};

function messageOf(error: unknown, fallback: string): string {
  if (error instanceof PassDraftError) return error.message;
  if (error instanceof Error) return error.message;
  return fallback;
}

/** Pass Karatou : ouvrir un accès après un paiement vérifié, suivre, révoquer. */
export default function PassPage() {
  const { t } = useLocale();
  const [draft, setDraft] = useState<PassDraft>(EMPTY_PASS_DRAFT);
  const [grants, setGrants] = useState<PassGrantRow[]>([]);
  const [search, setSearch] = useState('');
  const [loading, setLoading] = useState(true);
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [granted, setGranted] = useState<PassGrantResult | null>(null);
  const [revoking, setRevoking] = useState<PassGrantRow | null>(null);
  const [reason, setReason] = useState('');

  const load = useCallback(async (q?: string) => {
    setGrants(await fetchPassGrants(q));
  }, []);

  useEffect(() => {
    load()
      .catch((exception) => setError(messageOf(exception, t('pass.loadError'))))
      .finally(() => setLoading(false));
  }, [load, t]);

  function patch(next: Partial<PassDraft>) {
    setDraft((current) => ({ ...current, ...next }));
  }

  async function submit(event: FormEvent) {
    event.preventDefault();
    setPending(true);
    setError(null);
    setGranted(null);
    try {
      const result = await grantPass(toPassGrantInput(draft));
      setGranted(result);
      setDraft(EMPTY_PASS_DRAFT);
      await load(search);
    } catch (exception) {
      setError(messageOf(exception, t('pass.saveError')));
    } finally {
      setPending(false);
    }
  }

  const presetValue = DURATION_PRESETS.map(String).includes(draft.durationDays)
    ? draft.durationDays
    : 'custom';

  return (
    <DashboardShell title={t('pass.title')} subtitle={t('pass.subtitle')}>
      {error ? <Alert variant="danger">{error}</Alert> : null}
      {granted ? (
        <Alert variant="success">
          {fill(
            granted.status === 'granted' ? t('pass.grantedOk') : t('pass.alreadyGranted'),
            {
              name: granted.account.fullName,
              email: granted.account.email,
              until: formatDay(granted.activeUntil),
            },
          )}
        </Alert>
      ) : null}

      <form style={formStyle} onSubmit={(event) => void submit(event)}>
        <h3 style={{ margin: 0 }}>{t('pass.formTitle')}</h3>
        <p style={{ margin: 0, color: 'var(--text-muted)', fontSize: 'var(--text-sm)' }}>
          {t('pass.formHint')}
        </p>
        <div style={gridStyle}>
          <Field label={t('pass.emailLabel')}>
            {({ id }) => (
              <Input
                id={id}
                type="email"
                required
                value={draft.email}
                placeholder="eleve@exemple.com"
                onChange={(event) => patch({ email: event.target.value })}
              />
            )}
          </Field>
          <Field label={t('pass.referenceLabel')}>
            {({ id }) => (
              <Input
                id={id}
                required
                value={draft.paymentReference}
                placeholder="OM-2611-4455"
                onChange={(event) => patch({ paymentReference: event.target.value })}
              />
            )}
          </Field>
          <Field label={t('pass.durationLabel')}>
            {({ id }) => (
              <Select
                id={id}
                value={presetValue}
                onChange={(event) =>
                  patch({
                    durationDays: event.target.value === 'custom' ? '' : event.target.value,
                  })
                }
              >
                {DURATION_PRESETS.map((days) => (
                  <option key={days} value={String(days)}>
                    {fill(t('pass.durationDays'), { n: days })}
                  </option>
                ))}
                <option value="custom">{t('pass.durationCustom')}</option>
              </Select>
            )}
          </Field>
          {presetValue === 'custom' ? (
            <Field label={t('pass.durationCustomLabel')}>
              {({ id }) => (
                <Input
                  id={id}
                  type="number"
                  min={1}
                  max={730}
                  required
                  value={draft.durationDays}
                  onChange={(event) => patch({ durationDays: event.target.value })}
                />
              )}
            </Field>
          ) : null}
          <Field label={t('pass.amountLabel')}>
            {({ id }) => (
              <Input
                id={id}
                inputMode="numeric"
                value={draft.amountXof}
                placeholder="15000"
                onChange={(event) => patch({ amountXof: event.target.value })}
              />
            )}
          </Field>
          <Field label={t('pass.noteLabel')}>
            {({ id }) => (
              <Input
                id={id}
                maxLength={500}
                value={draft.note}
                onChange={(event) => patch({ note: event.target.value })}
              />
            )}
          </Field>
        </div>
        <div>
          <Button type="submit" loading={pending}>
            {t('pass.grantCta')}
          </Button>
        </div>
      </form>

      <div style={{ display: 'flex', gap: 8, marginBottom: 12, flexWrap: 'wrap' }}>
        <Input
          aria-label={t('pass.searchLabel')}
          placeholder={t('pass.searchLabel')}
          value={search}
          onChange={(event) => setSearch(event.target.value)}
          style={{ maxWidth: 360 }}
        />
        <Button
          variant="secondary"
          onClick={() =>
            load(search).catch((exception) => setError(messageOf(exception, t('pass.loadError'))))
          }
        >
          {t('pass.searchCta')}
        </Button>
      </div>

      {loading ? (
        <EmptyState title={t('pass.loading')} />
      ) : grants.length === 0 ? (
        <EmptyState title={t('pass.empty')} />
      ) : (
        <AdminTable
          columns={[
            t('pass.columns.student'),
            t('pass.columns.period'),
            t('pass.columns.payment'),
            t('pass.columns.grantedBy'),
            t('pass.columns.state'),
            t('pass.columns.actions'),
          ]}
          cols="1.6fr 1.2fr 1.2fr 1.2fr 0.8fr auto"
        >
          {grants.map((grant) => (
            <AdminTableRow key={grant.id}>
              <CellText primary={grant.account.fullName} sub={grant.account.email} />
              <CellText
                primary={`${formatDay(grant.startsAt)} → ${formatDay(grant.endsAt)}`}
                sub={fill(t('pass.durationDays'), { n: grant.durationDays })}
              />
              <CellText
                primary={grant.paymentReference}
                sub={grant.amountXof != null ? `${grant.amountXof.toLocaleString('fr-FR')} FCFA` : undefined}
              />
              <CellText
                primary={grant.grantedBy}
                sub={grant.source === 'webhook' ? t('pass.sourceWebhook') : t('pass.sourceAdmin')}
              />
              <div>
                <Badge variant={STATE_BADGE[grant.state]}>{t(`pass.state.${grant.state}`)}</Badge>
              </div>
              <div>
                {grant.state === 'revoked' || grant.state === 'expired' ? null : (
                  <Button
                    size="sm"
                    variant="dangerOutline"
                    disabled={pending}
                    onClick={() => {
                      setReason('');
                      setRevoking(grant);
                    }}
                  >
                    {t('pass.revokeCta')}
                  </Button>
                )}
              </div>
            </AdminTableRow>
          ))}
        </AdminTable>
      )}

      {revoking ? (
        <ConfirmDialog
          open
          title={fill(t('pass.revokeTitle'), { name: revoking.account.fullName })}
          description={t('pass.revokeBody')}
          confirmLabel={t('pass.revokeCta')}
          cancelLabel={t('pass.cancelCta')}
          confirmDisabled={reason.trim().length < 3}
          onCancel={() => setRevoking(null)}
          onConfirm={() => {
            const target = revoking;
            setRevoking(null);
            setPending(true);
            setError(null);
            revokePass(target.id, reason.trim())
              .then(() => load(search))
              .catch((exception) => setError(messageOf(exception, t('pass.saveError'))))
              .finally(() => setPending(false));
          }}
        >
          <Field label={t('pass.revokeReasonLabel')}>
            {({ id }) => (
              <Input id={id} value={reason} onChange={(event) => setReason(event.target.value)} />
            )}
          </Field>
        </ConfirmDialog>
      ) : null}
    </DashboardShell>
  );
}
