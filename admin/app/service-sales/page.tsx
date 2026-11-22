'use client';

import {
  CSSProperties,
  FormEvent,
  useCallback,
  useEffect,
  useMemo,
  useState,
} from 'react';

import { DashboardShell } from '../../components/dashboard-shell';
import { useLocale } from '../../components/locale-provider';
import { apiFetch } from '../../lib/api-client';
import {
  AdminTable,
  AdminTableRow,
  Alert,
  Badge,
  Button,
  CellText,
  EmptyState,
  Field,
  Select,
  Textarea,
} from '../../components/ui';
import type { BadgeVariant } from '../../components/ui';

const PURCHASE_STATUSES = [
  'pending_payment',
  'paid',
  'in_progress',
  'delivered',
  'cancelled',
  'refunded',
];

const STATUS_VARIANT: Record<string, BadgeVariant> = {
  pending_payment: 'warning',
  paid: 'success',
  in_progress: 'brand',
  delivered: 'success',
  cancelled: 'danger',
  refunded: 'warning',
};

interface ServicePurchaseItem {
  id: string;
  status: string;
  amountXOF: number;
  /** Prix catalogue avant remise ; absent sur les ventes antérieures. */
  listPriceXOF?: number | null;
  discountPercent?: number;
  discountReason?: string | null;
  source: string;
  internalNotes: string | null;
  createdAt: string;
  deliveredAt: string | null;
  package: {
    code: string;
    nameFr: string;
    category: string;
  };
  user: {
    fullName: string;
    email: string;
  };
  case: {
    id: string;
    referenceCode: string;
    requestedCountryId: string | null;
    source: string;
  } | null;
  paymentIntent: {
    provider: string;
    status: string;
  } | null;
}

interface PurchaseFormState {
  status: string;
  internalNotes: string;
}

const panelCardStyle: CSSProperties = {
  background: 'var(--surface)',
  border: '1px solid var(--border)',
  borderRadius: 16,
  padding: 16,
};

const panelTitleStyle: CSSProperties = {
  margin: 0,
  fontSize: 'var(--text-base)',
  fontWeight: 800,
  color: 'var(--ink)',
};

const metaLabelStyle: CSSProperties = {
  fontSize: 9.5,
  fontWeight: 800,
  letterSpacing: '0.06em',
  textTransform: 'uppercase',
  color: 'var(--text-faint)',
};

const metaValueStyle: CSSProperties = {
  fontSize: 'var(--text-sm)',
  fontWeight: 700,
};

function formatFcfa(value: number) {
  return new Intl.NumberFormat('fr-FR').format(value);
}

export default function ServiceSalesPage() {
  const { t, locale } = useLocale();
  const [items, setItems] = useState<ServicePurchaseItem[]>([]);
  const [filter, setFilter] = useState('');
  const [forms, setForms] = useState<Record<string, PurchaseFormState>>({});
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [statusMessage, setStatusMessage] = useState<string | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  const selected = useMemo(
    () => items.find((item) => item.id === selectedId) ?? null,
    [items, selectedId],
  );

  function statusLabel(status: string) {
    const key = `serviceSales.status_${status}`;
    const label = t(key);
    return label === key ? status.replace(/_/g, ' ') : label;
  }

  function formatDate(value: string | null) {
    if (!value) return '—';
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return '—';
    return new Intl.DateTimeFormat(locale === 'fr' ? 'fr-FR' : 'en-GB', {
      day: '2-digit',
      month: 'short',
      year: 'numeric',
    }).format(date);
  }

  const loadPurchases = useCallback(async () => {
    setLoading(true);
    setErrorMessage(null);
    try {
      const response = await apiFetch<{ items: ServicePurchaseItem[] }>(
        `/admin/service-packages/purchases/list${filter ? `?status=${filter}` : ''}`,
      );
      setItems(response.items);
      setForms(
        Object.fromEntries(
          response.items.map((item) => [
            item.id,
            {
              status: item.status,
              internalNotes: item.internalNotes ?? '',
            },
          ]),
        ),
      );
      setSelectedId((current) =>
        current && response.items.some((item) => item.id === current)
          ? current
          : (response.items[0]?.id ?? null),
      );
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : t('serviceSales.loadError'),
      );
    } finally {
      setLoading(false);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [filter]);

  useEffect(() => {
    void loadPurchases();
  }, [loadPurchases]);

  async function submitUpdate(
    event: FormEvent<HTMLFormElement>,
    purchaseId: string,
  ) {
    event.preventDefault();
    const form = forms[purchaseId];
    if (!form) return;

    setSaving(true);
    setStatusMessage(null);
    setErrorMessage(null);
    try {
      await apiFetch(`/admin/service-packages/purchases/${purchaseId}`, {
        method: 'PATCH',
        body: {
          status: form.status,
          internalNotes: form.internalNotes || undefined,
        },
      });
      setStatusMessage(t('serviceSales.updated'));
      await loadPurchases();
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : t('serviceSales.updateError'),
      );
    } finally {
      setSaving(false);
    }
  }

  function renderDetail(item: ServicePurchaseItem) {
    const form = forms[item.id] ?? {
      status: item.status,
      internalNotes: item.internalNotes ?? '',
    };

    return (
      <section style={{ ...panelCardStyle, display: 'grid', gap: 14 }}>
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            gap: 12,
            flexWrap: 'wrap',
          }}
        >
          <h3 style={panelTitleStyle}>{item.package.nameFr}</h3>
          <Badge variant={STATUS_VARIANT[item.status] ?? 'neutral'}>
            {statusLabel(item.status)}
          </Badge>
        </div>

        <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
          <Badge variant="brand">{item.package.code}</Badge>
          <Badge variant="neutral">{item.source.replace(/_/g, ' ')}</Badge>
          <Badge variant="neutral">{item.package.category.replace(/_/g, ' ')}</Badge>
        </div>

        <div style={{ display: 'flex', gap: 24, flexWrap: 'wrap' }}>
          <div style={{ display: 'grid', gap: 2 }}>
            <span style={metaLabelStyle}>{t('serviceSales.clientLabel')}</span>
            <span style={metaValueStyle}>{item.user.fullName}</span>
            <span style={{ fontSize: 'var(--text-xs)', color: 'var(--text-muted)' }}>
              {item.user.email}
            </span>
          </div>
          <div style={{ display: 'grid', gap: 2 }}>
            <span style={metaLabelStyle}>{t('serviceSales.amountLabel')}</span>
            <span style={metaValueStyle}>{formatFcfa(item.amountXOF)} FCFA</span>
            {item.discountPercent ? (
              <span style={{ fontSize: 'var(--text-xs)', color: 'var(--text-muted)' }}>
                {t('serviceSales.passDiscountDetail')
                  .replace('{percent}', String(item.discountPercent))
                  .replace('{list}', formatFcfa(item.listPriceXOF ?? item.amountXOF))}
              </span>
            ) : null}
          </div>
          <div style={{ display: 'grid', gap: 2 }}>
            <span style={metaLabelStyle}>{t('serviceSales.dateLabel')}</span>
            <span style={metaValueStyle}>{formatDate(item.createdAt)}</span>
          </div>
        </div>

        <div style={{ display: 'flex', gap: 24, flexWrap: 'wrap' }}>
          <div style={{ display: 'grid', gap: 2 }}>
            <span style={metaLabelStyle}>{t('serviceSales.caseLabel')}</span>
            <span style={metaValueStyle}>
              {item.case
                ? `${item.case.referenceCode} · ${
                    item.case.requestedCountryId ??
                    t('serviceSales.unknownDestination')
                  }`
                : t('serviceSales.noCase')}
            </span>
          </div>
          <div style={{ display: 'grid', gap: 2 }}>
            <span style={metaLabelStyle}>{t('serviceSales.paymentLabel')}</span>
            <span style={metaValueStyle}>
              {item.paymentIntent
                ? `${item.paymentIntent.provider} · ${item.paymentIntent.status.replace(/_/g, ' ')}`
                : t('serviceSales.manualPayment')}
            </span>
          </div>
        </div>

        <form
          onSubmit={(event) => submitUpdate(event, item.id)}
          style={{ display: 'grid', gap: 10 }}
        >
          <Field label={t('serviceSales.lifecycleLabel')}>
            {({ id }) => (
              <Select
                id={id}
                value={form.status}
                onChange={(event) =>
                  setForms((current) => ({
                    ...current,
                    [item.id]: { ...form, status: event.target.value },
                  }))
                }
              >
                {PURCHASE_STATUSES.map((status) => (
                  <option key={status} value={status}>
                    {statusLabel(status)}
                  </option>
                ))}
              </Select>
            )}
          </Field>
          <Field label={t('serviceSales.notesLabel')}>
            {({ id }) => (
              <Textarea
                id={id}
                value={form.internalNotes}
                onChange={(event) =>
                  setForms((current) => ({
                    ...current,
                    [item.id]: { ...form, internalNotes: event.target.value },
                  }))
                }
              />
            )}
          </Field>
          <div>
            <Button type="submit" loading={saving}>
              {t('serviceSales.saveCta')}
            </Button>
          </div>
        </form>
      </section>
    );
  }

  return (
    <DashboardShell title={t('serviceSales.title')} subtitle={t('serviceSales.subtitle')}>
      <div style={{ display: 'grid', gap: 14 }}>
        {statusMessage ? <Alert variant="success">{statusMessage}</Alert> : null}
        {errorMessage ? <Alert variant="danger">{errorMessage}</Alert> : null}

        <div
          style={{
            display: 'flex',
            gap: 12,
            justifyContent: 'space-between',
            alignItems: 'flex-end',
            flexWrap: 'wrap',
          }}
        >
          <div style={{ width: 260 }}>
            <Field label={t('serviceSales.statusFilterLabel')}>
              {({ id }) => (
                <Select
                  id={id}
                  value={filter}
                  onChange={(event) => setFilter(event.target.value)}
                >
                  <option value="">{t('serviceSales.allPurchases')}</option>
                  {PURCHASE_STATUSES.map((status) => (
                    <option key={status} value={status}>
                      {statusLabel(status)}
                    </option>
                  ))}
                </Select>
              )}
            </Field>
          </div>
          <Button
            size="sm"
            variant="secondary"
            onClick={() => void loadPurchases()}
          >
            {t('serviceSales.refreshCta')}
          </Button>
        </div>

        <div
          style={{
            display: 'grid',
            gap: 14,
            gridTemplateColumns: 'minmax(0, 1.1fr) minmax(0, 0.9fr)',
            alignItems: 'start',
          }}
        >
          <AdminTable
            aria-label={t('serviceSales.title')}
            columns={[
              t('serviceSales.colService'),
              t('serviceSales.colAmount'),
              t('serviceSales.colDate'),
              t('serviceSales.colStatus'),
            ]}
            cols="1.7fr 0.8fr 0.7fr 0.9fr"
            footnote={t('serviceSales.tableNote')}
          >
            {loading ? (
              <EmptyState title={t('serviceSales.loading')} />
            ) : items.length === 0 ? (
              <EmptyState title={t('serviceSales.empty')} />
            ) : (
              items.map((item) => (
                <AdminTableRow
                  key={item.id}
                  selected={selectedId === item.id}
                  onSelect={() => setSelectedId(item.id)}
                >
                  <CellText
                    primary={item.package.nameFr}
                    sub={item.user.fullName}
                  />
                  <CellText
                    primary={`${formatFcfa(item.amountXOF)} FCFA`}
                    sub={
                      item.discountPercent
                        ? t('serviceSales.passDiscountBadge').replace(
                            '{percent}',
                            String(item.discountPercent),
                          )
                        : undefined
                    }
                  />
                  <CellText primary={formatDate(item.createdAt)} muted />
                  <div>
                    <Badge variant={STATUS_VARIANT[item.status] ?? 'neutral'}>
                      {statusLabel(item.status)}
                    </Badge>
                  </div>
                </AdminTableRow>
              ))
            )}
          </AdminTable>

          {selected ? (
            renderDetail(selected)
          ) : (
            <section style={panelCardStyle}>
              <EmptyState title={t('serviceSales.selectHint')} />
            </section>
          )}
        </div>
      </div>
    </DashboardShell>
  );
}
