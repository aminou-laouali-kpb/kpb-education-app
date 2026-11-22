'use client';

import { CSSProperties, FormEvent, useEffect, useState } from 'react';

import { apiFetch, type ApiError } from '../../lib/api-client';
import { useLocale } from '../locale-provider';
import { Alert, Button, Field, Input, Select, Textarea } from '../ui';

interface PackageOption {
  code: string;
  nameFr: string;
  priceXOF: number;
  isActive: boolean;
}

export interface RecordedSale {
  id: string;
  amountXOF: number;
  listPriceXOF: number | null;
  discountPercent: number;
  user: { fullName: string; email: string };
  package: { nameFr: string };
}

const formStyle: CSSProperties = {
  display: 'grid',
  gap: 12,
  padding: 16,
  border: '1px solid var(--border)',
  borderRadius: 12,
  background: 'var(--surface)',
};

const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export interface OpenSale {
  id: string;
  status: string;
  amountXOF: number;
  createdAt: string;
  source: string;
}

/** La vente ouverte jointe à un refus 409 `DUPLICATE_OPEN_SALE`, ou `null`. */
export function duplicateFromError(error: unknown): OpenSale | null {
  const apiError = error as ApiError | undefined;
  if (!apiError || apiError.status !== 409 || !apiError.body) return null;
  try {
    const body = JSON.parse(apiError.body) as {
      code?: string;
      details?: { existing?: OpenSale };
    };
    return body.code === 'DUPLICATE_OPEN_SALE' && body.details?.existing
      ? body.details.existing
      : null;
  } catch {
    return null;
  }
}

function fcfa(value: number) {
  return new Intl.NumberFormat('fr-FR').format(value);
}

/**
 * Vente saisie par l'équipe, pour un élève passé par WhatsApp sans le bouton
 * de l'app. Le serveur retrouve le compte par e-mail et calcule lui-même la
 * remise du Pass Karatou : la console ne saisit jamais de montant.
 */
export function RecordSaleForm({
  onRecorded,
  onCancel,
}: {
  onRecorded: (sale: RecordedSale) => void;
  onCancel: () => void;
}) {
  const { t } = useLocale();
  const [packages, setPackages] = useState<PackageOption[]>([]);
  const [email, setEmail] = useState('');
  const [packageCode, setPackageCode] = useState('');
  const [status, setStatus] = useState<'pending_payment' | 'paid'>('pending_payment');
  const [note, setNote] = useState('');
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [duplicate, setDuplicate] = useState<OpenSale | null>(null);

  useEffect(() => {
    apiFetch<{ items: PackageOption[] }>('/admin/service-packages')
      .then((response) => {
        const active = (response?.items ?? []).filter((item) => item.isActive);
        setPackages(active);
        setPackageCode((current) => current || active[0]?.code || '');
      })
      .catch((exception) =>
        setError(exception instanceof Error ? exception.message : t('serviceSales.loadError')),
      );
  }, [t]);

  async function submit(event: FormEvent | null, allowDuplicate = false) {
    event?.preventDefault();
    if (!EMAIL.test(email.trim())) {
      setError(t('serviceSales.recordEmailInvalid'));
      return;
    }
    if (!packageCode) {
      setError(t('serviceSales.recordPackageMissing'));
      return;
    }
    setPending(true);
    setError(null);
    if (!allowDuplicate) setDuplicate(null);
    try {
      const sale = await apiFetch<RecordedSale>('/admin/service-packages/purchases', {
        method: 'POST',
        body: {
          email: email.trim(),
          packageCode,
          status,
          ...(note.trim() ? { note: note.trim() } : {}),
          ...(allowDuplicate ? { allowDuplicate: true } : {}),
        },
      });
      setDuplicate(null);
      onRecorded(sale);
    } catch (exception) {
      const open = duplicateFromError(exception);
      if (open) {
        setDuplicate(open);
        return;
      }
      setError(exception instanceof Error ? exception.message : t('serviceSales.updateError'));
    } finally {
      setPending(false);
    }
  }

  return (
    <form style={formStyle} onSubmit={(event) => void submit(event)}>
      <h3 style={{ margin: 0 }}>{t('serviceSales.recordTitle')}</h3>
      <p style={{ margin: 0, color: 'var(--text-muted)', fontSize: 'var(--text-sm)' }}>
        {t('serviceSales.recordHint')}
      </p>
      {error ? <Alert variant="danger">{error}</Alert> : null}
      {duplicate ? (
        <Alert variant="warning">
          <div style={{ display: 'grid', gap: 8 }}>
            <strong>{t('serviceSales.duplicateTitle')}</strong>
            <span>
              {t('serviceSales.duplicateBody')
                .replace('{status}', t(`serviceSales.status_${duplicate.status}`))
                .replace('{amount}', fcfa(duplicate.amountXOF))
                .replace(
                  '{date}',
                  new Intl.DateTimeFormat('fr-FR').format(new Date(duplicate.createdAt)),
                )}
            </span>
            <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
              <Button
                type="button"
                size="sm"
                variant="secondary"
                loading={pending}
                onClick={() => void submit(null, true)}
              >
                {t('serviceSales.duplicateConfirmCta')}
              </Button>
              <Button type="button" size="sm" variant="ghost" onClick={onCancel}>
                {t('serviceSales.duplicateCancelCta')}
              </Button>
            </div>
          </div>
        </Alert>
      ) : null}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: 10 }}>
        <Field label={t('serviceSales.recordEmailLabel')}>
          {({ id }) => (
            <Input
              id={id}
              type="email"
              required
              value={email}
              placeholder="eleve@exemple.com"
              onChange={(event) => setEmail(event.target.value)}
            />
          )}
        </Field>
        <Field label={t('serviceSales.recordPackageLabel')}>
          {({ id }) => (
            <Select id={id} value={packageCode} onChange={(event) => setPackageCode(event.target.value)}>
              {packages.map((item) => (
                <option key={item.code} value={item.code}>
                  {item.nameFr} — {fcfa(item.priceXOF)} FCFA
                </option>
              ))}
            </Select>
          )}
        </Field>
        <Field label={t('serviceSales.recordStatusLabel')}>
          {({ id }) => (
            <Select
              id={id}
              value={status}
              onChange={(event) => setStatus(event.target.value as 'pending_payment' | 'paid')}
            >
              <option value="pending_payment">{t('serviceSales.status_pending_payment')}</option>
              <option value="paid">{t('serviceSales.status_paid')}</option>
            </Select>
          )}
        </Field>
      </div>
      <Field label={t('serviceSales.recordNoteLabel')}>
        {({ id }) => (
          <Textarea id={id} rows={2} maxLength={1000} value={note} onChange={(event) => setNote(event.target.value)} />
        )}
      </Field>
      <div style={{ display: 'flex', gap: 8 }}>
        <Button type="submit" loading={pending}>
          {t('serviceSales.recordCta')}
        </Button>
        <Button type="button" variant="ghost" disabled={pending} onClick={onCancel}>
          {t('serviceSales.recordCancel')}
        </Button>
      </div>
    </form>
  );
}

/** Message de confirmation, remise comprise (pur, testé). */
export function recordedSaleMessage(
  sale: RecordedSale,
  templates: { plain: string; discounted: string },
): string {
  const base = (sale.discountPercent > 0 ? templates.discounted : templates.plain)
    .replace('{name}', sale.user.fullName)
    .replace('{email}', sale.user.email)
    .replace('{service}', sale.package.nameFr)
    .replace('{amount}', fcfa(sale.amountXOF));
  return base
    .replace('{percent}', String(sale.discountPercent))
    .replace('{list}', fcfa(sale.listPriceXOF ?? sale.amountXOF));
}
