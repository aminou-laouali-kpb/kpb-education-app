'use client';

import { useRouter, useSearchParams } from 'next/navigation';
import { useCallback, useEffect, useState } from 'react';

import { AdminCapability, hasAdminCapability } from '../../lib/admin-capabilities';
import {
  buildCampaignPayload,
  type Campaign,
  type CampaignFormInput,
  campaignsApi,
  NOVEMBER_2026_DEFAULTS,
  STATUS_VARIANT,
} from '../../lib/referral-campaigns';
import { useAdminAuth } from '../admin-auth-provider';
import { DashboardShell } from '../dashboard-shell';
import { useLocale } from '../locale-provider';
import {
  AdminTable,
  AdminTableRow,
  Alert,
  Badge,
  Button,
  CellText,
  EmptyState,
  Field,
  Input,
  Modal,
  Textarea,
} from '../ui';
import { CampaignDetail } from './campaign-detail';

/**
 * Compétition ambassadeurs — liste des campagnes et création.
 *
 * La campagne ouverte est dans l'URL (`/parrainage?c=<id>`) : un lien partagé
 * entre deux personnes de l'équipe ouvre la même campagne.
 */
export function CampaignsHub() {
  const { session } = useAdminAuth();
  const { t } = useLocale();
  const router = useRouter();
  const params = useSearchParams();
  const selectedId = params.get('c');
  const canManage = hasAdminCapability(session?.user.role, AdminCapability.ManageReferralCampaigns);

  const [items, setItems] = useState<Campaign[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [creating, setCreating] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      setItems((await campaignsApi.list()).items ?? []);
    } catch (e) {
      setError(e instanceof Error ? e.message : t('parrainage.loadError'));
    } finally {
      setLoading(false);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    if (session) void load();
  }, [load, session]);

  const open = (id: string | null) => router.push(id ? `/parrainage?c=${encodeURIComponent(id)}` : '/parrainage');

  return (
    <DashboardShell title={t('parrainage.title')} subtitle={t('parrainage.subtitle')}>
      <div style={{ display: 'grid', gap: 14 }}>
        {error ? <Alert variant="danger">{error}</Alert> : null}
        {selectedId ? (
          <>
            <div>
              <Button variant="ghost" size="sm" onClick={() => open(null)}>
                ← {t('parrainage.backToList')}
              </Button>
            </div>
            <CampaignDetail campaignId={selectedId} canManage={canManage} onChanged={load} />
          </>
        ) : (
          <>
            <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
              {canManage ? (
                <Button onClick={() => setCreating(true)}>{t('parrainage.create')}</Button>
              ) : null}
            </div>
            {loading ? (
              <p style={{ margin: 0 }}>{t('parrainage.loading')}</p>
            ) : items.length === 0 ? (
              <EmptyState title={t('parrainage.emptyTitle')} description={t('parrainage.emptyBody')} />
            ) : (
              <AdminTable
                cols="1.6fr 1fr 0.7fr 0.7fr 0.7fr"
                columns={[
                  t('parrainage.colName'),
                  t('parrainage.colDates'),
                  t('parrainage.colStatus'),
                  t('parrainage.colParticipants'),
                  t('parrainage.colReferrals'),
                ]}
              >
                {items.map((c) => (
                  <AdminTableRow key={c.id} onSelect={() => open(c.id)}>
                    <CellText primary={c.nameFr} sub={c.slug} />
                    <CellText primary={`${c.startDate} → ${c.endDate}`} sub={c.timeZone} />
                    <div>
                      <Badge variant={STATUS_VARIANT[c.status]}>{t(`parrainage.status.${c.status}`)}</Badge>
                    </div>
                    <CellText primary={String(c.counts?.participants ?? 0)} />
                    <CellText primary={String(c.counts?.referrals ?? 0)} />
                  </AdminTableRow>
                ))}
              </AdminTable>
            )}
          </>
        )}
      </div>
      <CreateCampaignModal
        open={creating}
        onClose={() => setCreating(false)}
        onCreated={(c) => {
          setCreating(false);
          void load();
          open(c.id);
        }}
      />
    </DashboardShell>
  );
}

function CreateCampaignModal({
  open,
  onClose,
  onCreated,
}: Readonly<{ open: boolean; onClose: () => void; onCreated: (c: Campaign) => void }>) {
  const { t } = useLocale();
  const [form, setForm] = useState<CampaignFormInput>(NOVEMBER_2026_DEFAULTS);
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [busy, setBusy] = useState(false);
  const [serverError, setServerError] = useState<string | null>(null);
  const set = (key: keyof CampaignFormInput) => (value: string) => setForm((f) => ({ ...f, [key]: value }));
  const err = (key: string) => (errors[key] ? t(`parrainage.form.${errors[key]}`) : undefined);

  async function submit() {
    const built = buildCampaignPayload(form);
    if (!built.ok) {
      setErrors(built.errors);
      return;
    }
    setErrors({});
    setBusy(true);
    setServerError(null);
    try {
      onCreated(await campaignsApi.create(built.body));
    } catch (e) {
      setServerError(e instanceof Error ? e.message : t('parrainage.saveError'));
    } finally {
      setBusy(false);
    }
  }

  return (
    <Modal
      open={open}
      title={t('parrainage.create')}
      onClose={onClose}
      busy={busy}
      size="lg"
      footer={
        <>
          <Button variant="secondary" onClick={onClose} disabled={busy}>
            {t('parrainage.cancel')}
          </Button>
          <Button onClick={submit} loading={busy}>
            {t('parrainage.createSubmit')}
          </Button>
        </>
      }
    >
      <div style={{ display: 'grid', gap: 12 }}>
        {serverError ? <Alert variant="danger">{serverError}</Alert> : null}
        <Alert variant="info">{t('parrainage.form.windowHint')}</Alert>
        <CampaignFields form={form} set={set} err={err} editable={null} />
      </div>
    </Modal>
  );
}

/** Champs communs à la création et à l'édition (`editable` null = tout). */
export function CampaignFields({
  form,
  set,
  err,
  editable,
}: Readonly<{
  form: CampaignFormInput;
  set: (key: keyof CampaignFormInput) => (value: string) => void;
  err: (key: string) => string | undefined;
  editable: readonly string[] | null;
}>) {
  const { t } = useLocale();
  const can = (field: string) => editable === null || editable.includes(field);
  const text = (key: keyof CampaignFormInput, label: string, field: string = key, type = 'text') => (
    <Field label={label} error={err(key)}>
      {({ id, invalid }) => (
        <Input
          id={id}
          type={type}
          invalid={invalid}
          value={form[key]}
          disabled={!can(field)}
          onChange={(e) => set(key)(e.target.value)}
        />
      )}
    </Field>
  );
  return (
    <div style={{ display: 'grid', gap: 12, gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))' }}>
      {text('slug', t('parrainage.form.slug'), editable === null ? 'slug' : '__never__')}
      {text('nameFr', t('parrainage.form.nameFr'))}
      {text('nameEn', t('parrainage.form.nameEn'))}
      {text('startDate', t('parrainage.form.startDate'), 'startDate', 'date')}
      {text('endDate', t('parrainage.form.endDate'), 'endDate', 'date')}
      {text('timeZone', t('parrainage.form.timeZone'))}
      {text('prizesText', t('parrainage.form.prizes'), 'prizes')}
      {text('citiesText', t('parrainage.form.cities'), 'eligibleCities')}
      {text('countriesText', t('parrainage.form.countries'), 'eligibleCountries')}
      {text('rulesUrl', t('parrainage.form.rulesUrl'))}
      <div style={{ gridColumn: '1 / -1' }}>
        <Field label={t('parrainage.form.rulesText')} error={err('rulesText')}>
          {({ id }) => (
            <Textarea
              id={id}
              value={form.rulesText}
              disabled={!can('rulesText')}
              onChange={(e) => set('rulesText')(e.target.value)}
            />
          )}
        </Field>
      </div>
    </div>
  );
}
