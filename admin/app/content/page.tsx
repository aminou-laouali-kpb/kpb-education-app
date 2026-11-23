'use client';

import { CSSProperties, FormEvent, useEffect, useState } from 'react';

import { useAdminAuth } from '../../components/admin-auth-provider';
import { DashboardShell } from '../../components/dashboard-shell';
import { DeleteParcoursDialog } from '../../components/content/delete-parcours-dialog';
import { useLocale } from '../../components/locale-provider';
import { apiFetch } from '../../lib/api-client';
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

interface ServiceOfferItem {
  id: string;
  name: { fr: string; en: string };
  offerType: string;
  destinationIds: string[];
  studyLevels: string[];
  priceLabel: { fr: string; en: string };
  benefits?: { fr?: string[]; en?: string[] };
  ctaLabel?: { fr?: string; en?: string };
  status: string;
}

interface SupportDestinationItem {
  id: string;
  countryId?: string;
  countryName: { fr: string; en: string };
  supportLanguages: string[];
  availableServiceTypes: string[];
  conditions?: { fr?: string[]; en?: string[] };
  counselorNames: string[];
  isVisible: boolean;
  status: string;
}

interface ArticleItem {
  id: string;
  slug?: string;
  title: { fr: string; en: string };
  category: string;
  summary?: { fr?: string; en?: string };
  content?: { fr?: string; en?: string };
  tags?: string[];
  authorName: string;
  status: string;
}

interface ParcoursQa {
  question: string;
  answer: string;
}

interface ParcoursItem {
  id: string;
  slug: string;
  kind: 'video' | 'text';
  fieldId: string | null;
  tags: string[];
  personName: string;
  role: { fr: string; en: string };
  title: { fr: string; en: string };
  hook?: { fr?: string; en?: string };
  summary?: { fr?: string; en?: string };
  thumbnailUrl?: string;
  photoUrl?: string;
  youtubeId: string | null;
  durationMinutes: number | null;
  interview?: { fr?: ParcoursQa[] | null; en?: ParcoursQa[] | null };
  status: string;
  featured: boolean;
  displayOrder: number;
}

// Catalog field domains (d01..d12) — kept in sync with the backend
// orientation-fields taxonomy so the theme filter matches the mobile app.
const PARCOURS_FIELD_OPTIONS: { id: string; label: string }[] = [
  { id: '', label: '— Unmapped (no theme)' },
  { id: 'd01', label: 'Informatique & IA' },
  { id: 'd02', label: 'Commerce & Management' },
  { id: 'd03', label: 'Ingénierie & Sciences' },
  { id: 'd04', label: 'Santé & Sciences de la Vie' },
  { id: 'd05', label: 'Architecture & BTP' },
  { id: 'd06', label: 'Design, Médias & Communication' },
  { id: 'd07', label: 'Droit & Relations Internationales' },
  { id: 'd08', label: 'Environnement & Agriculture' },
  { id: 'd09', label: 'Sciences Humaines & Éducation' },
  { id: 'd10', label: 'Hôtellerie & Tourisme' },
  { id: 'd11', label: 'Arts & Culture' },
  { id: 'd12', label: 'Logistique & Supply Chain' },
];

const EMPTY_OFFER_FORM = {
  nameFr: '',
  nameEn: '',
  offerType: 'consultation',
  destinationIds: '',
  studyLevels: '',
  priceFr: 'Sur devis',
  priceEn: 'Quoted on request',
  benefitsFr: '',
  benefitsEn: '',
  ctaFr: 'En savoir plus',
  ctaEn: 'Learn more',
  status: 'draft',
};

const EMPTY_DESTINATION_FORM = {
  countryId: '',
  countryFr: '',
  countryEn: '',
  supportLanguages: 'fr,en',
  serviceTypes: 'consultation',
  conditionsFr: '',
  conditionsEn: '',
  counselors: '',
  isVisible: true,
  status: 'draft',
};

const EMPTY_ARTICLE_FORM = {
  slug: '',
  category: 'guides',
  titleFr: '',
  titleEn: '',
  summaryFr: '',
  summaryEn: '',
  contentFr: '',
  contentEn: '',
  tags: '',
  authorName: 'KPB Editorial',
  status: 'draft',
};

const EMPTY_PARCOURS_FORM = {
  slug: '',
  kind: 'video',
  fieldId: 'd01',
  youtubeId: '',
  personName: '',
  roleFr: '',
  roleEn: '',
  titleFr: '',
  titleEn: '',
  hookFr: '',
  hookEn: '',
  summaryFr: '',
  summaryEn: '',
  tags: '',
  durationMinutes: '',
  thumbnailUrl: '',
  photoUrl: '',
  interviewFr: '',
  interviewEn: '',
  status: 'published',
  featured: false,
};

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

const panelSubtitleStyle: CSSProperties = {
  margin: '4px 0 0',
  fontSize: 'var(--text-xs)',
  color: 'var(--text-muted)',
  lineHeight: 1.5,
};

const formGridStyle: CSSProperties = {
  display: 'grid',
  gap: 12,
  gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))',
};

const fullRowStyle: CSSProperties = { gridColumn: '1 / -1' };

const checkboxLabelStyle: CSSProperties = {
  display: 'flex',
  alignItems: 'center',
  gap: 8,
  fontSize: 'var(--text-sm)',
  fontWeight: 600,
};

// Parse the admin interview textarea (JSON array of {question, answer}).
// Returns null for empty input; throws a readable error for invalid JSON so
// submitParcours can surface it instead of silently dropping the content.
function parseInterview(
  raw: string,
  label: string,
  t: (key: string) => string,
): ParcoursQa[] | null {
  const trimmed = raw.trim();
  if (trimmed === '') return null;
  let parsed: unknown;
  try {
    parsed = JSON.parse(trimmed);
  } catch {
    throw new Error(`Interview ${label}: ${t('content.interviewInvalidJson')}`);
  }
  if (!Array.isArray(parsed)) {
    throw new Error(`Interview ${label}: ${t('content.interviewNotArray')}`);
  }
  return parsed.map((item, index) => {
    if (!item || typeof item !== 'object') {
      throw new Error(
        `Interview ${label}: ${t('content.interviewItemInvalid')} (#${index + 1})`,
      );
    }
    const record = item as Record<string, unknown>;
    return {
      question: String(record.question ?? ''),
      answer: String(record.answer ?? ''),
    };
  });
}

export default function ContentPage() {
  const { session } = useAdminAuth();
  const { t } = useLocale();
  const [serviceOffers, setServiceOffers] = useState<ServiceOfferItem[]>([]);
  const [supportDestinations, setSupportDestinations] = useState<
    SupportDestinationItem[]
  >([]);
  const [articles, setArticles] = useState<ArticleItem[]>([]);
  const [statusMessage, setStatusMessage] = useState<string | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [offerForm, setOfferForm] = useState({ ...EMPTY_OFFER_FORM });
  const [destinationForm, setDestinationForm] = useState({
    ...EMPTY_DESTINATION_FORM,
  });
  const [articleForm, setArticleForm] = useState({ ...EMPTY_ARTICLE_FORM });
  const [parcours, setParcours] = useState<ParcoursItem[]>([]);
  const [parcoursForm, setParcoursForm] = useState({ ...EMPTY_PARCOURS_FORM });
  const [editingOfferId, setEditingOfferId] = useState<string | null>(null);
  const [editingDestinationId, setEditingDestinationId] = useState<string | null>(null);
  const [editingArticleId, setEditingArticleId] = useState<string | null>(null);
  const [editingParcoursId, setEditingParcoursId] = useState<string | null>(null);
  const [deletingParcours, setDeletingParcours] = useState<ParcoursItem | null>(
    null,
  );
  const [deletingBusy, setDeletingBusy] = useState(false);

  function patchOffer(patch: Partial<typeof EMPTY_OFFER_FORM>) {
    setOfferForm((current) => ({ ...current, ...patch }));
  }
  function patchDestination(patch: Partial<typeof EMPTY_DESTINATION_FORM>) {
    setDestinationForm((current) => ({ ...current, ...patch }));
  }
  function patchArticle(patch: Partial<typeof EMPTY_ARTICLE_FORM>) {
    setArticleForm((current) => ({ ...current, ...patch }));
  }
  function patchParcours(patch: Partial<typeof EMPTY_PARCOURS_FORM>) {
    setParcoursForm((current) => ({ ...current, ...patch }));
  }

  function statusOptions() {
    return (
      <>
        <option value="draft">{t('content.statusDraft')}</option>
        <option value="published">{t('content.statusPublished')}</option>
        <option value="archived">{t('content.statusArchived')}</option>
      </>
    );
  }

  async function loadContent() {
    setErrorMessage(null);
    try {
      const [
        offersResponse,
        destinationsResponse,
        articlesResponse,
        parcoursResponse,
      ] = await Promise.all([
        apiFetch<{ items: ServiceOfferItem[] }>('/admin/service-offers'),
        apiFetch<{ items: SupportDestinationItem[] }>(
          '/admin/support-destinations',
        ),
        apiFetch<{ items: ArticleItem[] }>('/admin/articles'),
        apiFetch<{ items: ParcoursItem[] }>('/admin/parcours'),
      ]);
      setServiceOffers(offersResponse.items);
      setSupportDestinations(destinationsResponse.items);
      setArticles(articlesResponse.items);
      setParcours(parcoursResponse.items);
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : t('content.loadError'),
      );
    }
  }

  useEffect(() => {
    if (!session) {
      return;
    }
    void loadContent();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [session]);

  async function submitOffer(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setStatusMessage(null);
    setErrorMessage(null);

    const body = {
      name: { fr: offerForm.nameFr, en: offerForm.nameEn },
      offerType: offerForm.offerType,
      destinationIds: splitList(offerForm.destinationIds),
      studyLevels: splitList(offerForm.studyLevels),
      priceLabel: { fr: offerForm.priceFr, en: offerForm.priceEn },
      benefits: {
        fr: offerForm.benefitsFr
          .split('\n')
          .map((item) => item.trim())
          .filter(Boolean),
        en: offerForm.benefitsEn
          .split('\n')
          .map((item) => item.trim())
          .filter(Boolean),
      },
      ctaLabel: { fr: offerForm.ctaFr, en: offerForm.ctaEn },
      status: offerForm.status,
    };

    try {
      if (editingOfferId) {
        await apiFetch(`/admin/service-offers/${editingOfferId}`, {
          method: 'PATCH',
          body,
        });
        setStatusMessage(t('content.offerUpdated'));
      } else {
        await apiFetch('/admin/service-offers', { method: 'POST', body });
        setStatusMessage(t('content.offerCreated'));
      }

      setOfferForm({ ...EMPTY_OFFER_FORM });
      setEditingOfferId(null);
      await loadContent();
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : t('content.offerError'),
      );
    }
  }

  async function submitDestination(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setStatusMessage(null);
    setErrorMessage(null);

    const body = {
      countryId: destinationForm.countryId,
      countryName: {
        fr: destinationForm.countryFr,
        en: destinationForm.countryEn,
      },
      supportLanguages: splitList(destinationForm.supportLanguages),
      availableServiceTypes: splitList(destinationForm.serviceTypes),
      conditions: {
        fr: destinationForm.conditionsFr
          .split('\n')
          .map((item) => item.trim())
          .filter(Boolean),
        en: destinationForm.conditionsEn
          .split('\n')
          .map((item) => item.trim())
          .filter(Boolean),
      },
      counselorNames: splitList(destinationForm.counselors),
      isVisible: destinationForm.isVisible,
      status: destinationForm.status,
    };

    try {
      if (editingDestinationId) {
        await apiFetch(`/admin/support-destinations/${editingDestinationId}`, {
          method: 'PATCH',
          body,
        });
        setStatusMessage(t('content.destinationUpdated'));
      } else {
        await apiFetch('/admin/support-destinations', { method: 'POST', body });
        setStatusMessage(t('content.destinationCreated'));
      }

      setDestinationForm({ ...EMPTY_DESTINATION_FORM });
      setEditingDestinationId(null);
      await loadContent();
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : t('content.destinationError'),
      );
    }
  }

  async function submitArticle(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setStatusMessage(null);
    setErrorMessage(null);

    const body = {
      slug: articleForm.slug,
      category: articleForm.category,
      title: { fr: articleForm.titleFr, en: articleForm.titleEn },
      summary: { fr: articleForm.summaryFr, en: articleForm.summaryEn },
      content: { fr: articleForm.contentFr, en: articleForm.contentEn },
      tags: splitList(articleForm.tags),
      authorName: articleForm.authorName,
      status: articleForm.status,
      publishedAt:
        articleForm.status === 'published' ? new Date().toISOString() : null,
    };

    try {
      if (editingArticleId) {
        await apiFetch(`/admin/articles/${editingArticleId}`, {
          method: 'PATCH',
          body,
        });
        setStatusMessage(t('content.articleUpdated'));
      } else {
        await apiFetch('/admin/articles', { method: 'POST', body });
        setStatusMessage(t('content.articleCreated'));
      }

      setArticleForm({ ...EMPTY_ARTICLE_FORM });
      setEditingArticleId(null);
      await loadContent();
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : t('content.articleError'),
      );
    }
  }

  async function submitParcours(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setStatusMessage(null);
    setErrorMessage(null);

    const durationRaw = parcoursForm.durationMinutes.trim();
    const duration = durationRaw === '' ? null : Number(durationRaw);

    let interviewFr: ParcoursQa[] | null;
    let interviewEn: ParcoursQa[] | null;
    try {
      interviewFr = parseInterview(parcoursForm.interviewFr, 'FR', t);
      interviewEn = parseInterview(parcoursForm.interviewEn, 'EN', t);
    } catch (error) {
      setErrorMessage(
        error instanceof Error
          ? error.message
          : t('content.interviewInvalidJson'),
      );
      return;
    }

    // Shared body — NOTE: `source` is intentionally omitted so an edit never
    // clobbers the provenance ('excel'/'legacy_db') of an imported story.
    const body: Record<string, unknown> = {
      slug:
        parcoursForm.slug.trim() ||
        `parcours-${parcoursForm.titleFr
          .toLowerCase()
          .replace(/[^a-z0-9]+/g, '-')
          .replace(/(^-|-$)/g, '')
          .slice(0, 48)}`,
      kind: parcoursForm.kind,
      fieldId: parcoursForm.fieldId || null,
      youtubeId: parcoursForm.youtubeId.trim() || null,
      durationMinutes:
        duration !== null && Number.isFinite(duration) ? duration : null,
      personName: parcoursForm.personName,
      role: { fr: parcoursForm.roleFr, en: parcoursForm.roleEn },
      title: { fr: parcoursForm.titleFr, en: parcoursForm.titleEn },
      hook: { fr: parcoursForm.hookFr, en: parcoursForm.hookEn },
      summary: { fr: parcoursForm.summaryFr, en: parcoursForm.summaryEn },
      thumbnailUrl: parcoursForm.thumbnailUrl.trim(),
      photoUrl: parcoursForm.photoUrl.trim(),
      interview: { fr: interviewFr, en: interviewEn },
      tags: splitList(parcoursForm.tags),
      status: parcoursForm.status,
      featured: parcoursForm.featured,
    };

    try {
      if (editingParcoursId) {
        await apiFetch(`/admin/parcours/${editingParcoursId}`, {
          method: 'PATCH',
          body,
        });
        setStatusMessage(t('content.parcoursUpdated'));
      } else {
        // Only new rows are stamped as manually authored.
        await apiFetch('/admin/parcours', {
          method: 'POST',
          body: { ...body, source: 'manual' },
        });
        setStatusMessage(t('content.parcoursCreated'));
      }
      setParcoursForm({ ...EMPTY_PARCOURS_FORM });
      setEditingParcoursId(null);
      await loadContent();
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : t('content.parcoursError'),
      );
    }
  }

  // Appelée uniquement depuis la confirmation (suppression physique côté API).
  async function deleteParcours() {
    const target = deletingParcours;
    if (!target || deletingBusy) {
      return;
    }
    const { id } = target;
    setStatusMessage(null);
    setErrorMessage(null);
    setDeletingBusy(true);
    try {
      await apiFetch(`/admin/parcours/${id}`, { method: 'DELETE' });
      if (editingParcoursId === id) {
        setEditingParcoursId(null);
        setParcoursForm({ ...EMPTY_PARCOURS_FORM });
      }
      setStatusMessage(t('content.parcoursDeleted'));
      await loadContent();
    } catch (error) {
      setErrorMessage(
        error instanceof Error
          ? error.message
          : t('content.parcoursDeleteError'),
      );
    } finally {
      setDeletingBusy(false);
      setDeletingParcours(null);
    }
  }

  function selectOffer(offer: ServiceOfferItem) {
    setEditingOfferId(offer.id);
    setOfferForm({
      nameFr: offer.name.fr,
      nameEn: offer.name.en,
      offerType: offer.offerType,
      destinationIds: offer.destinationIds.join(','),
      studyLevels: offer.studyLevels.join(','),
      priceFr: offer.priceLabel.fr,
      priceEn: offer.priceLabel.en,
      benefitsFr: offer.benefits?.fr?.join('\n') ?? '',
      benefitsEn: offer.benefits?.en?.join('\n') ?? '',
      ctaFr: offer.ctaLabel?.fr ?? '',
      ctaEn: offer.ctaLabel?.en ?? '',
      status: offer.status,
    });
  }

  function selectDestination(destination: SupportDestinationItem) {
    setEditingDestinationId(destination.id);
    setDestinationForm({
      countryId: destination.countryId ?? '',
      countryFr: destination.countryName.fr,
      countryEn: destination.countryName.en,
      supportLanguages: destination.supportLanguages.join(','),
      serviceTypes: destination.availableServiceTypes.join(','),
      conditionsFr: destination.conditions?.fr?.join('\n') ?? '',
      conditionsEn: destination.conditions?.en?.join('\n') ?? '',
      counselors: destination.counselorNames.join(','),
      isVisible: destination.isVisible,
      status: destination.status,
    });
  }

  function selectArticle(article: ArticleItem) {
    setEditingArticleId(article.id);
    setArticleForm({
      slug: article.slug ?? '',
      category: article.category,
      titleFr: article.title.fr,
      titleEn: article.title.en,
      summaryFr: article.summary?.fr ?? '',
      summaryEn: article.summary?.en ?? '',
      contentFr: article.content?.fr ?? '',
      contentEn: article.content?.en ?? '',
      tags: article.tags?.join(',') ?? '',
      authorName: article.authorName,
      status: article.status,
    });
  }

  function selectParcours(story: ParcoursItem) {
    setEditingParcoursId(story.id);
    setParcoursForm({
      slug: story.slug,
      kind: story.kind,
      fieldId: story.fieldId ?? '',
      youtubeId: story.youtubeId ?? '',
      personName: story.personName ?? '',
      roleFr: story.role?.fr ?? '',
      roleEn: story.role?.en ?? '',
      titleFr: story.title?.fr ?? '',
      titleEn: story.title?.en ?? '',
      hookFr: story.hook?.fr ?? '',
      hookEn: story.hook?.en ?? '',
      summaryFr: story.summary?.fr ?? '',
      summaryEn: story.summary?.en ?? '',
      tags: story.tags?.join(',') ?? '',
      durationMinutes:
        story.durationMinutes != null ? String(story.durationMinutes) : '',
      thumbnailUrl: story.thumbnailUrl ?? '',
      photoUrl: story.photoUrl ?? '',
      interviewFr: story.interview?.fr
        ? JSON.stringify(story.interview.fr, null, 2)
        : '',
      interviewEn: story.interview?.en
        ? JSON.stringify(story.interview.en, null, 2)
        : '',
      status: story.status,
      featured: story.featured,
    });
  }

  return (
    <DashboardShell title={t('content.title')} subtitle={t('content.subtitle')}>
      <div style={{ display: 'grid', gap: 14 }}>
        {statusMessage ? <Alert variant="success">{statusMessage}</Alert> : null}
        {errorMessage ? <Alert variant="danger">{errorMessage}</Alert> : null}

        {/* ── Service offers ─────────────────────────────────────────── */}
        <AdminTable
          title={t('content.offersTitle')}
          columns={[
            t('content.colName'),
            t('content.colType'),
            t('content.colDestinations'),
            t('content.colStatus'),
          ]}
          cols="1.6fr 0.9fr 1.1fr 0.8fr"
          footnote={t('content.offersSubtitle')}
        >
          {serviceOffers.length === 0 ? (
            <EmptyState title={t('content.offersEmpty')} />
          ) : (
            serviceOffers.map((offer) => (
              <AdminTableRow
                key={offer.id}
                selected={editingOfferId === offer.id}
                onSelect={() => selectOffer(offer)}
              >
                <CellText primary={offer.name.fr} sub={offer.name.en} />
                <CellText primary={offer.offerType} muted />
                <CellText
                  primary={
                    offer.destinationIds.join(', ') || t('content.global')
                  }
                  muted
                />
                <div>
                  <StatusBadge status={offer.status} />
                </div>
              </AdminTableRow>
            ))
          )}
        </AdminTable>

        <section style={{ ...panelCardStyle, display: 'grid', gap: 12 }}>
          <div>
            <h3 style={panelTitleStyle}>
              {editingOfferId
                ? t('content.updateOfferCta')
                : t('content.addOfferCta')}
            </h3>
            <p style={panelSubtitleStyle}>{t('content.offersSubtitle')}</p>
          </div>
          <form onSubmit={submitOffer} style={formGridStyle}>
            <Field label={t('content.offerNameFr')}>
              {({ id }) => (
                <Input
                  id={id}
                  value={offerForm.nameFr}
                  onChange={(e) => patchOffer({ nameFr: e.target.value })}
                />
              )}
            </Field>
            <Field label={t('content.offerNameEn')}>
              {({ id }) => (
                <Input
                  id={id}
                  value={offerForm.nameEn}
                  onChange={(e) => patchOffer({ nameEn: e.target.value })}
                />
              )}
            </Field>
            <Field label={t('content.offerType')}>
              {({ id }) => (
                <Input
                  id={id}
                  value={offerForm.offerType}
                  onChange={(e) => patchOffer({ offerType: e.target.value })}
                />
              )}
            </Field>
            <Field label={t('content.statusLabel')}>
              {({ id }) => (
                <Select
                  id={id}
                  value={offerForm.status}
                  onChange={(e) => patchOffer({ status: e.target.value })}
                >
                  {statusOptions()}
                </Select>
              )}
            </Field>
            <Field label={t('content.destinationIds')}>
              {({ id }) => (
                <Input
                  id={id}
                  value={offerForm.destinationIds}
                  onChange={(e) => patchOffer({ destinationIds: e.target.value })}
                  placeholder="canada,france,germany"
                />
              )}
            </Field>
            <Field label={t('content.studyLevels')}>
              {({ id }) => (
                <Input
                  id={id}
                  value={offerForm.studyLevels}
                  onChange={(e) => patchOffer({ studyLevels: e.target.value })}
                  placeholder="high_school,bachelor,master"
                />
              )}
            </Field>
            <Field label={t('content.priceFr')}>
              {({ id }) => (
                <Input
                  id={id}
                  value={offerForm.priceFr}
                  onChange={(e) => patchOffer({ priceFr: e.target.value })}
                />
              )}
            </Field>
            <Field label={t('content.priceEn')}>
              {({ id }) => (
                <Input
                  id={id}
                  value={offerForm.priceEn}
                  onChange={(e) => patchOffer({ priceEn: e.target.value })}
                />
              )}
            </Field>
            <div style={fullRowStyle}>
              <Field label={t('content.benefitsFr')}>
                {({ id }) => (
                  <Textarea
                    id={id}
                    value={offerForm.benefitsFr}
                    onChange={(e) => patchOffer({ benefitsFr: e.target.value })}
                  />
                )}
              </Field>
            </div>
            <div style={fullRowStyle}>
              <Field label={t('content.benefitsEn')}>
                {({ id }) => (
                  <Textarea
                    id={id}
                    value={offerForm.benefitsEn}
                    onChange={(e) => patchOffer({ benefitsEn: e.target.value })}
                  />
                )}
              </Field>
            </div>
            <Field label={t('content.ctaFr')}>
              {({ id }) => (
                <Input
                  id={id}
                  value={offerForm.ctaFr}
                  onChange={(e) => patchOffer({ ctaFr: e.target.value })}
                />
              )}
            </Field>
            <Field label={t('content.ctaEn')}>
              {({ id }) => (
                <Input
                  id={id}
                  value={offerForm.ctaEn}
                  onChange={(e) => patchOffer({ ctaEn: e.target.value })}
                />
              )}
            </Field>
            <div style={{ ...fullRowStyle, display: 'flex', gap: 8 }}>
              <Button type="submit">
                {editingOfferId
                  ? t('content.updateOfferCta')
                  : t('content.addOfferCta')}
              </Button>
              {editingOfferId ? (
                <Button
                  variant="secondary"
                  onClick={() => {
                    setEditingOfferId(null);
                    setOfferForm({ ...EMPTY_OFFER_FORM });
                  }}
                >
                  {t('content.cancelCta')}
                </Button>
              ) : null}
            </div>
          </form>
        </section>

        {/* ── Support destinations ───────────────────────────────────── */}
        <AdminTable
          title={t('content.destinationsTitle')}
          columns={[
            t('content.colCountry'),
            t('content.colServices'),
            t('content.colVisibility'),
            t('content.colStatus'),
          ]}
          cols="1.3fr 1.4fr 0.8fr 0.8fr"
          footnote={t('content.destinationsSubtitle')}
        >
          {supportDestinations.length === 0 ? (
            <EmptyState title={t('content.destinationsEmpty')} />
          ) : (
            supportDestinations.map((destination) => (
              <AdminTableRow
                key={destination.id}
                selected={editingDestinationId === destination.id}
                onSelect={() => selectDestination(destination)}
              >
                <CellText
                  primary={destination.countryName.fr}
                  sub={destination.countryId}
                />
                <CellText
                  primary={destination.availableServiceTypes.join(', ')}
                  muted
                />
                <div>
                  <Badge variant={destination.isVisible ? 'info' : 'neutral'}>
                    {destination.isVisible
                      ? t('content.visible')
                      : t('content.hidden')}
                  </Badge>
                </div>
                <div>
                  <StatusBadge status={destination.status} />
                </div>
              </AdminTableRow>
            ))
          )}
        </AdminTable>

        <section style={{ ...panelCardStyle, display: 'grid', gap: 12 }}>
          <div>
            <h3 style={panelTitleStyle}>
              {editingDestinationId
                ? t('content.updateDestinationCta')
                : t('content.addDestinationCta')}
            </h3>
            <p style={panelSubtitleStyle}>{t('content.destinationsSubtitle')}</p>
          </div>
          <form onSubmit={submitDestination} style={formGridStyle}>
            <Field label={t('content.countryId')}>
              {({ id }) => (
                <Input
                  id={id}
                  value={destinationForm.countryId}
                  onChange={(e) => patchDestination({ countryId: e.target.value })}
                />
              )}
            </Field>
            <Field label={t('content.statusLabel')}>
              {({ id }) => (
                <Select
                  id={id}
                  value={destinationForm.status}
                  onChange={(e) => patchDestination({ status: e.target.value })}
                >
                  {statusOptions()}
                </Select>
              )}
            </Field>
            <Field label={t('content.countryFr')}>
              {({ id }) => (
                <Input
                  id={id}
                  value={destinationForm.countryFr}
                  onChange={(e) => patchDestination({ countryFr: e.target.value })}
                />
              )}
            </Field>
            <Field label={t('content.countryEn')}>
              {({ id }) => (
                <Input
                  id={id}
                  value={destinationForm.countryEn}
                  onChange={(e) => patchDestination({ countryEn: e.target.value })}
                />
              )}
            </Field>
            <Field label={t('content.supportLanguages')}>
              {({ id }) => (
                <Input
                  id={id}
                  value={destinationForm.supportLanguages}
                  onChange={(e) =>
                    patchDestination({ supportLanguages: e.target.value })
                  }
                />
              )}
            </Field>
            <Field label={t('content.serviceTypes')}>
              {({ id }) => (
                <Input
                  id={id}
                  value={destinationForm.serviceTypes}
                  onChange={(e) =>
                    patchDestination({ serviceTypes: e.target.value })
                  }
                />
              )}
            </Field>
            <div style={fullRowStyle}>
              <Field label={t('content.conditionsFr')}>
                {({ id }) => (
                  <Textarea
                    id={id}
                    value={destinationForm.conditionsFr}
                    onChange={(e) =>
                      patchDestination({ conditionsFr: e.target.value })
                    }
                  />
                )}
              </Field>
            </div>
            <div style={fullRowStyle}>
              <Field label={t('content.conditionsEn')}>
                {({ id }) => (
                  <Textarea
                    id={id}
                    value={destinationForm.conditionsEn}
                    onChange={(e) =>
                      patchDestination({ conditionsEn: e.target.value })
                    }
                  />
                )}
              </Field>
            </div>
            <Field label={t('content.counselors')}>
              {({ id }) => (
                <Input
                  id={id}
                  value={destinationForm.counselors}
                  onChange={(e) => patchDestination({ counselors: e.target.value })}
                  placeholder="Amina KPB,Fatou Admin"
                />
              )}
            </Field>
            <label style={{ ...checkboxLabelStyle, alignSelf: 'end' }}>
              <input
                type="checkbox"
                checked={destinationForm.isVisible}
                onChange={(e) =>
                  patchDestination({ isVisible: e.target.checked })
                }
              />
              {t('content.visibleLabel')}
            </label>
            <div style={{ ...fullRowStyle, display: 'flex', gap: 8 }}>
              <Button type="submit">
                {editingDestinationId
                  ? t('content.updateDestinationCta')
                  : t('content.addDestinationCta')}
              </Button>
              {editingDestinationId ? (
                <Button
                  variant="secondary"
                  onClick={() => {
                    setEditingDestinationId(null);
                    setDestinationForm({ ...EMPTY_DESTINATION_FORM });
                  }}
                >
                  {t('content.cancelCta')}
                </Button>
              ) : null}
            </div>
          </form>
        </section>

        {/* ── Editorial content ──────────────────────────────────────── */}
        <AdminTable
          title={t('content.articlesTitle')}
          columns={[
            t('content.colTitle'),
            t('content.colCategory'),
            t('content.colAuthor'),
            t('content.colStatus'),
          ]}
          cols="1.8fr 0.9fr 1fr 0.8fr"
          footnote={t('content.articlesSubtitle')}
        >
          {articles.length === 0 ? (
            <EmptyState title={t('content.articlesEmpty')} />
          ) : (
            articles.map((article) => (
              <AdminTableRow
                key={article.id}
                selected={editingArticleId === article.id}
                onSelect={() => selectArticle(article)}
              >
                <CellText primary={article.title.fr} sub={article.slug} />
                <CellText primary={article.category} muted />
                <CellText primary={article.authorName} muted />
                <div>
                  <StatusBadge status={article.status} />
                </div>
              </AdminTableRow>
            ))
          )}
        </AdminTable>

        <section style={{ ...panelCardStyle, display: 'grid', gap: 12 }}>
          <div>
            <h3 style={panelTitleStyle}>
              {editingArticleId
                ? t('content.updateArticleCta')
                : t('content.addArticleCta')}
            </h3>
            <p style={panelSubtitleStyle}>{t('content.articlesSubtitle')}</p>
          </div>
          <form onSubmit={submitArticle} style={formGridStyle}>
            <Field label={t('content.slug')}>
              {({ id }) => (
                <Input
                  id={id}
                  value={articleForm.slug}
                  onChange={(e) => patchArticle({ slug: e.target.value })}
                />
              )}
            </Field>
            <Field label={t('content.category')}>
              {({ id }) => (
                <Input
                  id={id}
                  value={articleForm.category}
                  onChange={(e) => patchArticle({ category: e.target.value })}
                />
              )}
            </Field>
            <Field label={t('content.titleFr')}>
              {({ id }) => (
                <Input
                  id={id}
                  value={articleForm.titleFr}
                  onChange={(e) => patchArticle({ titleFr: e.target.value })}
                />
              )}
            </Field>
            <Field label={t('content.titleEn')}>
              {({ id }) => (
                <Input
                  id={id}
                  value={articleForm.titleEn}
                  onChange={(e) => patchArticle({ titleEn: e.target.value })}
                />
              )}
            </Field>
            <div style={fullRowStyle}>
              <Field label={t('content.summaryFr')}>
                {({ id }) => (
                  <Textarea
                    id={id}
                    value={articleForm.summaryFr}
                    onChange={(e) => patchArticle({ summaryFr: e.target.value })}
                  />
                )}
              </Field>
            </div>
            <div style={fullRowStyle}>
              <Field label={t('content.summaryEn')}>
                {({ id }) => (
                  <Textarea
                    id={id}
                    value={articleForm.summaryEn}
                    onChange={(e) => patchArticle({ summaryEn: e.target.value })}
                  />
                )}
              </Field>
            </div>
            <div style={fullRowStyle}>
              <Field label={t('content.contentFr')}>
                {({ id }) => (
                  <Textarea
                    id={id}
                    value={articleForm.contentFr}
                    onChange={(e) => patchArticle({ contentFr: e.target.value })}
                  />
                )}
              </Field>
            </div>
            <div style={fullRowStyle}>
              <Field label={t('content.contentEn')}>
                {({ id }) => (
                  <Textarea
                    id={id}
                    value={articleForm.contentEn}
                    onChange={(e) => patchArticle({ contentEn: e.target.value })}
                  />
                )}
              </Field>
            </div>
            <Field label={t('content.tags')}>
              {({ id }) => (
                <Input
                  id={id}
                  value={articleForm.tags}
                  onChange={(e) => patchArticle({ tags: e.target.value })}
                  placeholder="scholarships,canada,bachelor"
                />
              )}
            </Field>
            <Field label={t('content.author')}>
              {({ id }) => (
                <Input
                  id={id}
                  value={articleForm.authorName}
                  onChange={(e) => patchArticle({ authorName: e.target.value })}
                />
              )}
            </Field>
            <Field label={t('content.statusLabel')}>
              {({ id }) => (
                <Select
                  id={id}
                  value={articleForm.status}
                  onChange={(e) => patchArticle({ status: e.target.value })}
                >
                  {statusOptions()}
                </Select>
              )}
            </Field>
            <div style={{ ...fullRowStyle, display: 'flex', gap: 8 }}>
              <Button type="submit">
                {editingArticleId
                  ? t('content.updateArticleCta')
                  : t('content.addArticleCta')}
              </Button>
              {editingArticleId ? (
                <Button
                  variant="secondary"
                  onClick={() => {
                    setEditingArticleId(null);
                    setArticleForm({ ...EMPTY_ARTICLE_FORM });
                  }}
                >
                  {t('content.cancelCta')}
                </Button>
              ) : null}
            </div>
          </form>
        </section>

        {/* ── Parcours & testimonials ────────────────────────────────── */}
        <AdminTable
          title={t('content.parcoursTitle')}
          columns={[
            t('content.colStory'),
            t('content.colKind'),
            t('content.colTheme'),
            t('content.colStatus'),
            t('content.colActions'),
          ]}
          cols="1.7fr 0.8fr 0.6fr 0.9fr 1fr"
          footnote={t('content.parcoursSubtitle')}
        >
          {parcours.length === 0 ? (
            <EmptyState title={t('content.parcoursEmpty')} />
          ) : (
            parcours.map((story) => (
              <AdminTableRow
                key={story.id}
                selected={editingParcoursId === story.id}
              >
                <CellText primary={story.title.fr} sub={story.personName} />
                <CellText
                  primary={
                    story.kind === 'video'
                      ? t('content.kindVideo')
                      : t('content.kindText')
                  }
                  muted
                />
                <CellText primary={story.fieldId ?? '—'} muted />
                <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
                  <StatusBadge status={story.status} />
                  {story.featured ? (
                    <Badge variant="brand">{t('content.featuredBadge')}</Badge>
                  ) : null}
                </div>
                <div style={{ display: 'flex', gap: 6 }}>
                  <Button
                    size="sm"
                    variant={
                      editingParcoursId === story.id ? 'primary' : 'secondary'
                    }
                    onClick={() => selectParcours(story)}
                  >
                    {t('content.editCta')}
                  </Button>
                  <Button
                    size="sm"
                    variant="dangerOutline"
                    disabled={deletingBusy}
                    onClick={() => setDeletingParcours(story)}
                  >
                    {t('content.deleteCta')}
                  </Button>
                </div>
              </AdminTableRow>
            ))
          )}
        </AdminTable>

        <section style={{ ...panelCardStyle, display: 'grid', gap: 12 }}>
          <div>
            <h3 style={panelTitleStyle}>
              {editingParcoursId
                ? t('content.updateStoryCta')
                : t('content.addStoryCta')}
            </h3>
            <p style={panelSubtitleStyle}>{t('content.parcoursSubtitle')}</p>
          </div>
          <form onSubmit={submitParcours} style={formGridStyle}>
            <Field label={t('content.kind')}>
              {({ id }) => (
                <Select
                  id={id}
                  value={parcoursForm.kind}
                  onChange={(e) => patchParcours({ kind: e.target.value })}
                >
                  <option value="video">{t('content.kindVideo')}</option>
                  <option value="text">{t('content.kindText')}</option>
                </Select>
              )}
            </Field>
            <Field label={t('content.fieldDomain')}>
              {({ id }) => (
                <Select
                  id={id}
                  value={parcoursForm.fieldId}
                  onChange={(e) => patchParcours({ fieldId: e.target.value })}
                >
                  {PARCOURS_FIELD_OPTIONS.map((f) => (
                    <option key={f.id} value={f.id}>
                      {f.id ? `${f.id} — ${f.label}` : f.label}
                    </option>
                  ))}
                </Select>
              )}
            </Field>
            <Field label={t('content.youtubeId')}>
              {({ id }) => (
                <Input
                  id={id}
                  value={parcoursForm.youtubeId}
                  onChange={(e) => patchParcours({ youtubeId: e.target.value })}
                  placeholder="l_0UPSeH5sU"
                />
              )}
            </Field>
            <Field label={t('content.duration')}>
              {({ id }) => (
                <Input
                  id={id}
                  value={parcoursForm.durationMinutes}
                  onChange={(e) =>
                    patchParcours({ durationMinutes: e.target.value })
                  }
                  inputMode="numeric"
                />
              )}
            </Field>
            <Field label={t('content.personName')}>
              {({ id }) => (
                <Input
                  id={id}
                  value={parcoursForm.personName}
                  onChange={(e) => patchParcours({ personName: e.target.value })}
                />
              )}
            </Field>
            <Field label={t('content.slugOptional')}>
              {({ id }) => (
                <Input
                  id={id}
                  value={parcoursForm.slug}
                  onChange={(e) => patchParcours({ slug: e.target.value })}
                  placeholder={t('content.slugAutoHint')}
                />
              )}
            </Field>
            <Field label={t('content.roleFr')}>
              {({ id }) => (
                <Input
                  id={id}
                  value={parcoursForm.roleFr}
                  onChange={(e) => patchParcours({ roleFr: e.target.value })}
                />
              )}
            </Field>
            <Field label={t('content.roleEn')}>
              {({ id }) => (
                <Input
                  id={id}
                  value={parcoursForm.roleEn}
                  onChange={(e) => patchParcours({ roleEn: e.target.value })}
                />
              )}
            </Field>
            <Field label={t('content.titleFr')}>
              {({ id }) => (
                <Input
                  id={id}
                  value={parcoursForm.titleFr}
                  onChange={(e) => patchParcours({ titleFr: e.target.value })}
                />
              )}
            </Field>
            <Field label={t('content.titleEn')}>
              {({ id }) => (
                <Input
                  id={id}
                  value={parcoursForm.titleEn}
                  onChange={(e) => patchParcours({ titleEn: e.target.value })}
                />
              )}
            </Field>
            <div style={fullRowStyle}>
              <Field label={t('content.hookFr')}>
                {({ id }) => (
                  <Input
                    id={id}
                    value={parcoursForm.hookFr}
                    onChange={(e) => patchParcours({ hookFr: e.target.value })}
                  />
                )}
              </Field>
            </div>
            <div style={fullRowStyle}>
              <Field label={t('content.hookEn')}>
                {({ id }) => (
                  <Input
                    id={id}
                    value={parcoursForm.hookEn}
                    onChange={(e) => patchParcours({ hookEn: e.target.value })}
                  />
                )}
              </Field>
            </div>
            <div style={fullRowStyle}>
              <Field label={t('content.summaryFr')}>
                {({ id }) => (
                  <Textarea
                    id={id}
                    value={parcoursForm.summaryFr}
                    onChange={(e) => patchParcours({ summaryFr: e.target.value })}
                  />
                )}
              </Field>
            </div>
            <div style={fullRowStyle}>
              <Field label={t('content.summaryEn')}>
                {({ id }) => (
                  <Textarea
                    id={id}
                    value={parcoursForm.summaryEn}
                    onChange={(e) => patchParcours({ summaryEn: e.target.value })}
                  />
                )}
              </Field>
            </div>
            <Field label={t('content.thumbnailUrl')}>
              {({ id }) => (
                <Input
                  id={id}
                  value={parcoursForm.thumbnailUrl}
                  onChange={(e) => patchParcours({ thumbnailUrl: e.target.value })}
                />
              )}
            </Field>
            <Field label={t('content.photoUrl')}>
              {({ id }) => (
                <Input
                  id={id}
                  value={parcoursForm.photoUrl}
                  onChange={(e) => patchParcours({ photoUrl: e.target.value })}
                />
              )}
            </Field>
            <div style={fullRowStyle}>
              <Field label={t('content.interviewFr')}>
                {({ id }) => (
                  <Textarea
                    id={id}
                    value={parcoursForm.interviewFr}
                    onChange={(e) => patchParcours({ interviewFr: e.target.value })}
                    placeholder={'[\n  { "question": "…", "answer": "…" }\n]'}
                    style={{ minHeight: 120, fontFamily: 'monospace' }}
                  />
                )}
              </Field>
            </div>
            <div style={fullRowStyle}>
              <Field label={t('content.interviewEn')}>
                {({ id }) => (
                  <Textarea
                    id={id}
                    value={parcoursForm.interviewEn}
                    onChange={(e) => patchParcours({ interviewEn: e.target.value })}
                    placeholder={'[\n  { "question": "…", "answer": "…" }\n]'}
                    style={{ minHeight: 120, fontFamily: 'monospace' }}
                  />
                )}
              </Field>
            </div>
            <Field label={t('content.tags')}>
              {({ id }) => (
                <Input
                  id={id}
                  value={parcoursForm.tags}
                  onChange={(e) => patchParcours({ tags: e.target.value })}
                  placeholder="Google,Tech,Témoignage"
                />
              )}
            </Field>
            <Field label={t('content.statusLabel')}>
              {({ id }) => (
                <Select
                  id={id}
                  value={parcoursForm.status}
                  onChange={(e) => patchParcours({ status: e.target.value })}
                >
                  {statusOptions()}
                </Select>
              )}
            </Field>
            <label style={{ ...checkboxLabelStyle, alignSelf: 'end' }}>
              <input
                type="checkbox"
                checked={parcoursForm.featured}
                onChange={(e) => patchParcours({ featured: e.target.checked })}
              />
              {t('content.featured')}
            </label>
            <div style={{ ...fullRowStyle, display: 'flex', gap: 8 }}>
              <Button type="submit">
                {editingParcoursId
                  ? t('content.updateStoryCta')
                  : t('content.addStoryCta')}
              </Button>
              {editingParcoursId ? (
                <Button
                  variant="secondary"
                  onClick={() => {
                    setEditingParcoursId(null);
                    setParcoursForm({ ...EMPTY_PARCOURS_FORM });
                  }}
                >
                  {t('content.cancelCta')}
                </Button>
              ) : null}
            </div>
          </form>
        </section>
      </div>
      <DeleteParcoursDialog
        target={deletingParcours}
        loading={deletingBusy}
        onConfirm={() => void deleteParcours()}
        onCancel={() => setDeletingParcours(null)}
      />
    </DashboardShell>
  );
}
