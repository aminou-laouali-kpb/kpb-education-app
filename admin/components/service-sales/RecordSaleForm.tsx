'use client';

import { CSSProperties, FormEvent, useEffect, useState } from 'react';

import { apiFetch } from '../../lib/api-client';
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

  async function submit(event: FormEvent) {
    event.preventDefault();
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
    try {
      const sale = await apiFetch<RecordedSale>('/admin/service-packages/purchases', {
        method: 'POST',
        body: {
          email: email.trim(),
          packageCode,
          status,
          ...(note.trim() ? { note: note.trim() } : {}),
        },
      });
      onRecorded(sale);
    } catch (exception) {
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
