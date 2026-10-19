'use client';

import { CSSProperties, FormEvent, useEffect, useState } from 'react';

import { useAdminAuth } from '../../components/admin-auth-provider';
import { DashboardShell } from '../../components/dashboard-shell';
import { useLocale } from '../../components/locale-provider';
import { apiFetch } from '../../lib/api-client';
import {
  CAMPAIGN_PURPOSES,
  type CampaignAudiencePreview,
  type CampaignPurpose,
  channelCountLine,
  DEFAULT_CAMPAIGN_PURPOSE,
  previewBody,
} from '../../lib/campaign-purpose';
import { splitList } from '../../lib/ui';
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
  Select,
  StatusBadge,
  Textarea,
} from '../../components/ui';

/**
 * Les audiences que le backend sait RÉSOUDRE.
 *
 * Ce champ était un texte libre dont le placeholder annonçait
 * `all_users / by_case_status / by_role / specific_users` : trois de ces quatre
 * valeurs n'existent nulle part côté serveur et rendaient 400, tandis que trois
 * audiences réellement implémentées — `account_type`, `study_level`,
 * `country_of_residence` — n'étaient proposées nulle part. Un champ libre ne
 * peut pas se tromper à moitié : soit il documente les valeurs, soit il
 * n'aurait pas dû en suggérer.
 *
 * Reste alignée sur `CreateNotificationCampaignDto.audienceType` et sur les
 * branches de `CampaignExecutorService.resolveRecipients`. L'accord avec cette
 * copie-ci est vérifié par `campaign-audience-contract.spec.ts` (il lit ce
 * fichier) : une audience ajoutée au backend et oubliée ici fait rougir la CI.
 */
const AUDIENCE_REQUIRED_FILTER: Record<string, string | null> = {
  // Diffusions assumées : leur nom dit qu'elles visent tout le monde.
  all_users: null,
  all_students: null,
  // Audiences ciblées : SANS leur filtre, le backend refuse la campagne.
  //
  // Ce n'est pas une coquetterie d'interface. `where: undefined` en Prisma ne
  // veut pas dire « personne » mais « aucun filtre », donc tous les comptes :
  // un filtre oublié transformait un envoi ciblé en diffusion à toute la base.
  // Le serveur échoue désormais fermé ; l'afficher ici évite d'apprendre la
  // règle par un 400.
  country: 'countryId',
  country_of_residence: 'countryCode',
  case_status: 'status',
  account_type: 'accountType',
  study_level: 'levels',
  // Études en France (build 54). `eef_interest` vise les étudiants qui ont
  // déclaré leur intérêt : son ensemble est borné par la table, pas par un filtre.
  // Les DEUX acceptent `exceptCountries` ; `all_students_except_countries`
  // l'EXIGE (sans exclusion, ce serait « tous les étudiants »). Le jeton
  // `eef_suspended` désigne les pays suspendus servis à l'app.
  eef_interest: null,
  all_students_except_countries: 'exceptCountries',
  single_user: 'userId',
};

/** Ce que dit le menu pour une audience sans filtre exigé. */
const UNFILTERED_LABEL: Record<string, string> = {
  all_users: ' — tout le monde',
  all_students: ' — tout le monde',
  eef_interest: ' — déclarants Études en France (filtre facultatif « exceptCountries »)',
};

const AUDIENCE_TYPES = Object.keys(AUDIENCE_REQUIRED_FILTER);

interface NotificationTemplateItem {
  id: string;
  name: string;
  title: { fr: string; en: string };
  body: { fr: string; en: string };
  channels: string[];
  isCritical: boolean;
}

interface NotificationCampaignItem {
  id: string;
  name: string;
  templateId: string | null;
  audienceType: string;
  channels: string[];
  scheduledFor: string | null;
  status: string;
  linkedCaseId: string | null;
  /** Absent d'un serveur antérieur aux correctifs 57. */
  purpose?: CampaignPurpose;
}

interface NotificationDeliveryItem {
  id: string;
  recipientName: string;
  channel: string;
  status: string;
  deliveredAt: string | null;
  /** Tap de l'élève, signalé par l'app (push seulement). */
  openedAt: string | null;
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

const hintStyle: CSSProperties = {
  margin: '4px 0 0',
  fontSize: 'var(--text-xs)',
  color: 'var(--text-muted)',
};

const checkboxLabelStyle: CSSProperties = {
  display: 'flex',
  alignItems: 'center',
  gap: 8,
  fontSize: 'var(--text-sm)',
  fontWeight: 600,
};

export default function NotificationsPage() {
  const { session } = useAdminAuth();
  const { t, locale } = useLocale();
  const [templates, setTemplates] = useState<NotificationTemplateItem[]>([]);
  const [campaigns, setCampaigns] = useState<NotificationCampaignItem[]>([]);
  const [deliveries, setDeliveries] = useState<NotificationDeliveryItem[]>([]);
  const [selectedCampaignId, setSelectedCampaignId] = useState<string | null>(
    null,
  );
  const [loading, setLoading] = useState(true);
  const [statusMessage, setStatusMessage] = useState<string | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [templateForm, setTemplateForm] = useState({
    name: '',
    titleFr: '',
    titleEn: '',
    bodyFr: '',
    bodyEn: '',
    channels: 'push,email',
    isCritical: false,
  });
  const [campaignForm, setCampaignForm] = useState({
    name: '',
    templateId: '',
    audienceType: 'all_users',
    filtersJson: '{}',
    channels: 'push',
    scheduledFor: '',
    linkedCaseId: '',
    purpose: DEFAULT_CAMPAIGN_PURPOSE as CampaignPurpose,
  });
  const [preview, setPreview] = useState<CampaignAudiencePreview | null>(null);
  const [previewing, setPreviewing] = useState(false);

  function formatDateTime(value: string | null) {
    if (!value) return '—';
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return '—';
    return new Intl.DateTimeFormat(locale === 'fr' ? 'fr-FR' : 'en-GB', {
      day: '2-digit',
      month: 'short',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    }).format(date);
  }

  async function loadNotifications() {
    setErrorMessage(null);
    try {
      const [templatesResponse, campaignsResponse] = await Promise.all([
        apiFetch<{ items: NotificationTemplateItem[] }>(
          '/admin/notifications/templates',
        ),
        apiFetch<{ items: NotificationCampaignItem[] }>(
          '/admin/notifications/campaigns',
        ),
      ]);

      setTemplates(templatesResponse.items);
      setCampaigns(campaignsResponse.items);
      setSelectedCampaignId(
        (current) => current ?? campaignsResponse.items[0]?.id ?? null,
      );
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : t('notifications.loadError'),
      );
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    if (!session) {
      return;
    }
    void loadNotifications();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [session]);

  useEffect(() => {
    if (!session) {
      return;
    }
    if (!selectedCampaignId) {
      setDeliveries([]);
      return;
    }

    // Guard against an out-of-order resolution overwriting deliveries with
    // stale data when the user switches campaigns quickly.
    let cancelled = false;
    void apiFetch<{ items: NotificationDeliveryItem[] }>(
      `/admin/notifications/campaigns/${selectedCampaignId}/deliveries`,
    )
      .then((response) => {
        if (!cancelled) setDeliveries(response.items);
      })
      .catch((error) => {
        if (!cancelled)
          setErrorMessage(
            error instanceof Error
              ? error.message
              : t('notifications.deliveriesError'),
          );
      });
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [selectedCampaignId, session]);

  async function submitTemplate(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setStatusMessage(null);
    setErrorMessage(null);

    try {
      await apiFetch('/admin/notifications/templates', {
        method: 'POST',
        body: {
          name: templateForm.name,
          title: { fr: templateForm.titleFr, en: templateForm.titleEn },
          body: { fr: templateForm.bodyFr, en: templateForm.bodyEn },
          channels: splitList(templateForm.channels),
          isCritical: templateForm.isCritical,
        },
      });
      setTemplateForm({
        name: '',
        titleFr: '',
        titleEn: '',
        bodyFr: '',
        bodyEn: '',
        channels: 'push,email',
        isCritical: false,
      });
      setStatusMessage(t('notifications.templateCreated'));
      await loadNotifications();
    } catch (error) {
      setErrorMessage(
        error instanceof Error
          ? error.message
          : t('notifications.templateError'),
      );
    }
  }

  /**
   * Le nombre RÉEL de destinataires, canal par canal, après les filtres de
   * consentement d'une campagne promotionnelle (même règle que l'envoi).
   */
  async function previewCampaign() {
    setErrorMessage(null);
    let parsedFilters: unknown;
    try {
      parsedFilters = JSON.parse(campaignForm.filtersJson);
    } catch {
      setErrorMessage(t('notifications.filtersJsonError'));
      return;
    }
    setPreviewing(true);
    try {
      setPreview(
        await apiFetch<CampaignAudiencePreview>(
          '/admin/notifications/campaigns/preview',
          {
            method: 'POST',
            body: previewBody({
              audienceType: campaignForm.audienceType,
              filters: parsedFilters,
              channels: splitList(campaignForm.channels),
              purpose: campaignForm.purpose,
            }),
          },
        ),
      );
    } catch (error) {
      setPreview(null);
      setErrorMessage(
        error instanceof Error ? error.message : t('notifications.previewError'),
      );
    } finally {
      setPreviewing(false);
    }
  }

  async function submitCampaign(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setStatusMessage(null);
    setErrorMessage(null);

    try {
      let parsedFilters: unknown;
      try {
        parsedFilters = JSON.parse(campaignForm.filtersJson);
      } catch {
        setErrorMessage(t('notifications.filtersJsonError'));
        return;
      }
      await apiFetch('/admin/notifications/campaigns', {
        method: 'POST',
        body: {
          name: campaignForm.name,
          templateId: campaignForm.templateId || null,
          audienceType: campaignForm.audienceType,
          filters: parsedFilters,
          channels: splitList(campaignForm.channels),
          scheduledFor: campaignForm.scheduledFor
            ? new Date(campaignForm.scheduledFor).toISOString()
            : null,
          linkedCaseId: campaignForm.linkedCaseId || null,
          purpose: campaignForm.purpose,
        },
      });
      setCampaignForm({
        name: '',
        templateId: '',
        audienceType: 'all_users',
        filtersJson: '{}',
        channels: 'push',
        scheduledFor: '',
        linkedCaseId: '',
        purpose: DEFAULT_CAMPAIGN_PURPOSE,
      });
      setPreview(null);
      setStatusMessage(t('notifications.campaignCreated'));
      await loadNotifications();
    } catch (error) {
      setErrorMessage(
        error instanceof Error
          ? error.message
          : t('notifications.campaignError'),
      );
    }
  }

  return (
    <DashboardShell title={t('notifications.title')} subtitle={t('notifications.subtitle')}>
      <div style={{ display: 'grid', gap: 14 }}>
        {statusMessage ? <Alert variant="success">{statusMessage}</Alert> : null}
        {errorMessage ? <Alert variant="danger">{errorMessage}</Alert> : null}

        <div
          style={{
            display: 'grid',
            gap: 14,
            gridTemplateColumns: 'repeat(auto-fit, minmax(340px, 1fr))',
            alignItems: 'start',
          }}
        >
          <section style={{ ...panelCardStyle, display: 'grid', gap: 14 }}>
            <div>
              <h3 style={panelTitleStyle}>{t('notifications.templatesTitle')}</h3>
              <p style={hintStyle}>{t('notifications.templatesHint')}</p>
            </div>
            <form onSubmit={submitTemplate} style={{ display: 'grid', gap: 10 }}>
              <Field label={t('notifications.templateNameLabel')}>
                {({ id }) => (
                  <Input
                    id={id}
                    value={templateForm.name}
                    onChange={(e) =>
                      setTemplateForm((current) => ({
                        ...current,
                        name: e.target.value,
                      }))
                    }
                  />
                )}
              </Field>
              <div
                style={{ display: 'grid', gap: 10, gridTemplateColumns: '1fr 1fr' }}
              >
                <Field label={t('notifications.titleFrLabel')}>
                  {({ id }) => (
                    <Input
                      id={id}
                      value={templateForm.titleFr}
                      onChange={(e) =>
                        setTemplateForm((current) => ({
                          ...current,
                          titleFr: e.target.value,
                        }))
                      }
                    />
                  )}
                </Field>
                <Field label={t('notifications.titleEnLabel')}>
                  {({ id }) => (
                    <Input
                      id={id}
                      value={templateForm.titleEn}
                      onChange={(e) =>
                        setTemplateForm((current) => ({
                          ...current,
                          titleEn: e.target.value,
                        }))
                      }
                    />
                  )}
                </Field>
              </div>
              <Field label={t('notifications.bodyFrLabel')}>
                {({ id }) => (
                  <Textarea
                    id={id}
                    value={templateForm.bodyFr}
                    onChange={(e) =>
                      setTemplateForm((current) => ({
                        ...current,
                        bodyFr: e.target.value,
                      }))
                    }
                  />
                )}
              </Field>
              <Field label={t('notifications.bodyEnLabel')}>
                {({ id }) => (
                  <Textarea
                    id={id}
                    value={templateForm.bodyEn}
                    onChange={(e) =>
                      setTemplateForm((current) => ({
                        ...current,
                        bodyEn: e.target.value,
                      }))
                    }
                  />
                )}
              </Field>
              <Field label={t('notifications.channelsLabel')}>
                {({ id }) => (
                  <Input
                    id={id}
                    value={templateForm.channels}
                    placeholder="push,email"
                    onChange={(e) =>
                      setTemplateForm((current) => ({
                        ...current,
                        channels: e.target.value,
                      }))
                    }
                  />
                )}
              </Field>
              <label style={checkboxLabelStyle}>
                <input
                  type="checkbox"
                  checked={templateForm.isCritical}
                  onChange={(e) =>
                    setTemplateForm((current) => ({
                      ...current,
                      isCritical: e.target.checked,
                    }))
                  }
                />
                {t('notifications.criticalLabel')}
              </label>
              <div>
                <Button type="submit">{t('notifications.addTemplateCta')}</Button>
              </div>
            </form>
            <AdminTable
              columns={[
                t('notifications.colTemplate'),
                t('notifications.colChannels'),
                t('notifications.colType'),
              ]}
              cols="1.5fr 1.2fr 0.8fr"
            >
              {loading ? (
                <EmptyState title={t('notifications.loading')} />
              ) : templates.length === 0 ? (
                <EmptyState title={t('notifications.templatesEmpty')} />
              ) : (
                templates.map((template) => (
                  <AdminTableRow key={template.id}>
                    <CellText primary={template.name} sub={template.title.fr} />
                    <CellText
                      primary={template.channels.join(', ')}
                      muted
                    />
                    <div>
                      <Badge variant={template.isCritical ? 'danger' : 'neutral'}>
                        {template.isCritical
                          ? t('notifications.critical')
                          : t('notifications.standard')}
                      </Badge>
                    </div>
                  </AdminTableRow>
                ))
              )}
            </AdminTable>
          </section>

          <section style={{ ...panelCardStyle, display: 'grid', gap: 14 }}>
            <div>
              <h3 style={panelTitleStyle}>{t('notifications.campaignsTitle')}</h3>
              <p style={hintStyle}>{t('notifications.campaignsHint')}</p>
            </div>
            <form onSubmit={submitCampaign} style={{ display: 'grid', gap: 10 }}>
              <Field label={t('notifications.campaignNameLabel')}>
                {({ id }) => (
                  <Input
                    id={id}
                    value={campaignForm.name}
                    onChange={(e) =>
                      setCampaignForm((current) => ({
                        ...current,
                        name: e.target.value,
                      }))
                    }
                  />
                )}
              </Field>
              <div
                style={{ display: 'grid', gap: 10, gridTemplateColumns: '1fr 1fr' }}
              >
                <Field label={t('notifications.templateLabel')}>
                  {({ id }) => (
                    <Select
                      id={id}
                      value={campaignForm.templateId}
                      onChange={(e) =>
                        setCampaignForm((current) => ({
                          ...current,
                          templateId: e.target.value,
                        }))
                      }
                    >
                      <option value="">{t('notifications.noTemplate')}</option>
                      {templates.map((template) => (
                        <option key={template.id} value={template.id}>
                          {template.name}
                        </option>
                      ))}
                    </Select>
                  )}
                </Field>
                <Field label={t('notifications.channelsLabel')}>
                  {({ id }) => (
                    <Input
                      id={id}
                      value={campaignForm.channels}
                      onChange={(e) =>
                        setCampaignForm((current) => ({
                          ...current,
                          channels: e.target.value,
                        }))
                      }
                    />
                  )}
                </Field>
              </div>
              <Field label={t('notifications.purposeLabel')}>
                {({ id }) => (
                  <Select
                    id={id}
                    value={campaignForm.purpose}
                    onChange={(e) => {
                      setPreview(null);
                      setCampaignForm((current) => ({
                        ...current,
                        purpose: e.target.value as CampaignPurpose,
                      }));
                    }}
                  >
                    {CAMPAIGN_PURPOSES.map((value) => (
                      <option key={value} value={value}>
                        {t(`notifications.purpose_${value}`)}
                      </option>
                    ))}
                  </Select>
                )}
              </Field>
              <p style={hintStyle}>
                {t(`notifications.purposeHint_${campaignForm.purpose}`)}
              </p>
              <Field label={t('notifications.audienceLabel')}>
                {({ id }) => (
                  <Select
                    id={id}
                    value={campaignForm.audienceType}
                    onChange={(e) =>
                      setCampaignForm((current) => ({
                        ...current,
                        audienceType: e.target.value,
                      }))
                    }
                  >
                    {AUDIENCE_TYPES.map((value) => (
                      <option key={value} value={value}>
                        {value}
                        {AUDIENCE_REQUIRED_FILTER[value]
                          ? ` — exige « ${AUDIENCE_REQUIRED_FILTER[value]} »`
                          : (UNFILTERED_LABEL[value] ?? '')}
                      </option>
                    ))}
                  </Select>
                )}
              </Field>
              <Field label={t('notifications.filtersLabel')}>
                {({ id }) => (
                  <Textarea
                    id={id}
                    value={campaignForm.filtersJson}
                    onChange={(e) =>
                      setCampaignForm((current) => ({
                        ...current,
                        filtersJson: e.target.value,
                      }))
                    }
                  />
                )}
              </Field>
              <div
                style={{ display: 'grid', gap: 10, gridTemplateColumns: '1fr 1fr' }}
              >
                <Field label={t('notifications.scheduledForLabel')}>
                  {({ id }) => (
                    <Input
                      id={id}
                      type="datetime-local"
                      value={campaignForm.scheduledFor}
                      onChange={(e) =>
                        setCampaignForm((current) => ({
                          ...current,
                          scheduledFor: e.target.value,
                        }))
                      }
                    />
                  )}
                </Field>
                <Field label={t('notifications.linkedCaseLabel')}>
                  {({ id }) => (
                    <Input
                      id={id}
                      value={campaignForm.linkedCaseId}
                      onChange={(e) =>
                        setCampaignForm((current) => ({
                          ...current,
                          linkedCaseId: e.target.value,
                        }))
                      }
                    />
                  )}
                </Field>
              </div>
              {preview ? (
                <Alert variant="info">
                  <div>
                    {t('notifications.previewAudience').replace(
                      '{n}',
                      String(preview.recipients),
                    )}
                    {preview.reachable !== undefined
                      ? ` · ${t('notifications.previewReachable').replace(
                          '{n}',
                          String(preview.reachable),
                        )}`
                      : ''}
                  </div>
                  {(preview.byChannel ?? []).map((count) => (
                    <div key={count.channel}>
                      {channelCountLine(
                        count,
                        {
                          push_opted_out: t('notifications.blocked_push_opted_out'),
                          email_no_consent: t('notifications.blocked_email_no_consent'),
                          email_minor_without_guardian: t(
                            'notifications.blocked_email_minor_without_guardian',
                          ),
                        },
                        t('notifications.previewFiltered'),
                      )}
                    </div>
                  ))}
                  {preview.filterMissing || preview.filterInvalid ? (
                    <div>{preview.filterInvalid ?? t('notifications.previewFilterMissing')}</div>
                  ) : null}
                </Alert>
              ) : null}
              <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                <Button
                  type="button"
                  variant="secondary"
                  loading={previewing}
                  onClick={() => void previewCampaign()}
                >
                  {t('notifications.previewCta')}
                </Button>
                <Button type="submit">{t('notifications.launchCta')}</Button>
              </div>
            </form>
            <AdminTable
              columns={[
                t('notifications.colCampaign'),
                t('notifications.colChannels'),
                t('notifications.colScheduled'),
                t('notifications.colStatus'),
              ]}
              cols="1.5fr 0.9fr 1fr 0.8fr"
              footnote={t('notifications.campaignsNote')}
            >
              {loading ? (
                <EmptyState title={t('notifications.loading')} />
              ) : campaigns.length === 0 ? (
                <EmptyState title={t('notifications.campaignsEmpty')} />
              ) : (
                campaigns.map((campaign) => (
                  <AdminTableRow
                    key={campaign.id}
                    selected={selectedCampaignId === campaign.id}
                    onSelect={() => setSelectedCampaignId(campaign.id)}
                  >
                    <CellText
                      primary={campaign.name}
                      sub={`${campaign.audienceType.replace(/_/g, ' ')} · ${t(
                        `notifications.purpose_${campaign.purpose ?? DEFAULT_CAMPAIGN_PURPOSE}`,
                      )}`}
                    />
                    <CellText primary={campaign.channels.join(', ')} muted />
                    <CellText
                      primary={formatDateTime(campaign.scheduledFor)}
                      muted
                    />
                    <div>
                      <StatusBadge status={campaign.status} />
                    </div>
                  </AdminTableRow>
                ))
              )}
            </AdminTable>
          </section>
        </div>

        <AdminTable
          title={t('notifications.deliveriesTitle')}
          columns={[
            t('notifications.colRecipient'),
            t('notifications.colChannel'),
            t('notifications.colStatus'),
            t('notifications.colDeliveredAt'),
            t('notifications.colOpenedAt'),
          ]}
          cols="1.6fr 0.8fr 0.8fr 1fr 1fr"
          footnote={t('notifications.deliveriesHint')}
        >
          {deliveries.length === 0 ? (
            <EmptyState title={t('notifications.deliveriesEmpty')} />
          ) : (
            deliveries.map((delivery) => (
              <AdminTableRow key={delivery.id}>
                <CellText primary={delivery.recipientName} />
                <CellText primary={delivery.channel.replace(/_/g, ' ')} muted />
                <div>
                  <StatusBadge status={delivery.status} />
                </div>
                <CellText primary={formatDateTime(delivery.deliveredAt)} muted />
                <CellText primary={formatDateTime(delivery.openedAt)} muted />
              </AdminTableRow>
            ))
          )}
        </AdminTable>
      </div>
    </DashboardShell>
  );
}
