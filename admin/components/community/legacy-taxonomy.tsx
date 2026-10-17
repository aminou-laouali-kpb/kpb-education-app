'use client';

import { CSSProperties, FormEvent, useEffect, useState } from 'react';

import { useAdminAuth } from '../admin-auth-provider';
import { useLocale } from '../locale-provider';
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
  Input,
  Select,
  Textarea,
} from '../ui';
import type { BadgeVariant } from '../ui';

interface ForumCategoryItem {
  id: string;
  label: { fr: string; en: string };
  description: { fr: string; en: string };
  displayOrder: number;
  status: string;
}

interface ForumTagItem {
  id: string;
  label: { fr: string; en: string };
  description: { fr: string; en: string };
  displayOrder: number;
  status: string;
}

interface ModerationItem {
  id: string;
  subject: string;
  targetType: string;
  reportsCount: number;
  suggestedAction: string;
}

interface TaxonomyFormState {
  labelFr: string;
  labelEn: string;
  descriptionFr: string;
  descriptionEn: string;
  displayOrder: string;
  status: string;
}

const EMPTY_FORM: TaxonomyFormState = {
  labelFr: '',
  labelEn: '',
  descriptionFr: '',
  descriptionEn: '',
  displayOrder: '1',
  status: 'draft',
};

const STATUS_VALUES = ['draft', 'published', 'archived'] as const;

const STATUS_VARIANT: Record<string, BadgeVariant> = {
  draft: 'neutral',
  published: 'success',
  archived: 'neutral',
};

const ACTION_VARIANT: Record<string, BadgeVariant> = {
  hide: 'danger',
  remove: 'danger',
  ban: 'danger',
  warn: 'warning',
  review: 'warning',
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

const hintStyle: CSSProperties = {
  margin: '4px 0 0',
  fontSize: 'var(--text-xs)',
  color: 'var(--text-muted)',
};

/**
 * Taxonomie historique du forum (catégories, tags) et ancienne file en
 * lecture. Dépréciée par le contrat de la communauté (§13) — les espaces par
 * entité, les trois types et les hashtags la remplacent — mais gardée telle
 * quelle pour les builds installées, dans son propre onglet.
 */
export function LegacyTaxonomy() {
  const { session } = useAdminAuth();
  const { t } = useLocale();
  const [forumCategories, setForumCategories] = useState<ForumCategoryItem[]>(
    [],
  );
  const [forumTags, setForumTags] = useState<ForumTagItem[]>([]);
  const [moderationQueue, setModerationQueue] = useState<ModerationItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [statusMessage, setStatusMessage] = useState<string | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [categoryForm, setCategoryForm] = useState<TaxonomyFormState>(EMPTY_FORM);
  const [tagForm, setTagForm] = useState<TaxonomyFormState>(EMPTY_FORM);
  const [editingCategoryId, setEditingCategoryId] = useState<string | null>(
    null,
  );
  const [editingTagId, setEditingTagId] = useState<string | null>(null);

  function statusLabel(status: string) {
    const key = `community.status_${status}`;
    const label = t(key);
    return label === key ? status.replace(/_/g, ' ') : label;
  }

  async function loadCommunity() {
    setErrorMessage(null);
    try {
      const [categoriesResponse, tagsResponse, moderationResponse] =
        await Promise.all([
          apiFetch<{ items: ForumCategoryItem[] }>('/admin/forum-categories'),
          apiFetch<{ items: ForumTagItem[] }>('/admin/forum-tags'),
          apiFetch<{ items: ModerationItem[] }>('/admin/forum-moderation'),
        ]);
      setForumCategories(categoriesResponse.items);
      setForumTags(tagsResponse.items);
      setModerationQueue(moderationResponse.items);
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : t('community.loadError'),
      );
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    if (!session) {
      return;
    }
    void loadCommunity();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [session]);

  async function submitCategory(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setStatusMessage(null);
    setErrorMessage(null);

    const body = {
      label: { fr: categoryForm.labelFr, en: categoryForm.labelEn },
      description: {
        fr: categoryForm.descriptionFr,
        en: categoryForm.descriptionEn,
      },
      displayOrder: Number(categoryForm.displayOrder),
      status: categoryForm.status,
    };

    try {
      if (editingCategoryId) {
        await apiFetch(`/admin/forum-categories/${editingCategoryId}`, {
          method: 'PATCH',
          body,
        });
        setStatusMessage(t('community.categoryUpdated'));
      } else {
        await apiFetch('/admin/forum-categories', { method: 'POST', body });
        setStatusMessage(t('community.categoryCreated'));
      }

      setCategoryForm(EMPTY_FORM);
      setEditingCategoryId(null);
      await loadCommunity();
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : t('community.categoryError'),
      );
    }
  }

  async function submitTag(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setStatusMessage(null);
    setErrorMessage(null);

    const body = {
      label: { fr: tagForm.labelFr, en: tagForm.labelEn },
      description: { fr: tagForm.descriptionFr, en: tagForm.descriptionEn },
      displayOrder: Number(tagForm.displayOrder),
      status: tagForm.status,
    };

    try {
      if (editingTagId) {
        await apiFetch(`/admin/forum-tags/${editingTagId}`, {
          method: 'PATCH',
          body,
        });
        setStatusMessage(t('community.tagUpdated'));
      } else {
        await apiFetch('/admin/forum-tags', { method: 'POST', body });
        setStatusMessage(t('community.tagCreated'));
      }

      setTagForm(EMPTY_FORM);
      setEditingTagId(null);
      await loadCommunity();
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : t('community.tagError'),
      );
    }
  }

  function renderTaxonomyForm(
    form: TaxonomyFormState,
    setForm: (updater: (current: TaxonomyFormState) => TaxonomyFormState) => void,
    onSubmit: (event: FormEvent<HTMLFormElement>) => void,
    editingId: string | null,
    onCancel: () => void,
    submitLabel: string,
    updateLabel: string,
  ) {
    return (
      <form onSubmit={onSubmit} style={{ display: 'grid', gap: 10 }}>
        <div style={{ display: 'grid', gap: 10, gridTemplateColumns: '1fr 1fr' }}>
          <Field label={t('community.labelFr')}>
            {({ id }) => (
              <Input
                id={id}
                value={form.labelFr}
                onChange={(e) =>
                  setForm((current) => ({ ...current, labelFr: e.target.value }))
                }
              />
            )}
          </Field>
          <Field label={t('community.labelEn')}>
            {({ id }) => (
              <Input
                id={id}
                value={form.labelEn}
                onChange={(e) =>
                  setForm((current) => ({ ...current, labelEn: e.target.value }))
                }
              />
            )}
          </Field>
        </div>
        <Field label={t('community.descriptionFr')}>
          {({ id }) => (
            <Textarea
              id={id}
              value={form.descriptionFr}
              onChange={(e) =>
                setForm((current) => ({
                  ...current,
                  descriptionFr: e.target.value,
                }))
              }
            />
          )}
        </Field>
        <Field label={t('community.descriptionEn')}>
          {({ id }) => (
            <Textarea
              id={id}
              value={form.descriptionEn}
              onChange={(e) =>
                setForm((current) => ({
                  ...current,
                  descriptionEn: e.target.value,
                }))
              }
            />
          )}
        </Field>
        <div style={{ display: 'grid', gap: 10, gridTemplateColumns: '1fr 1fr' }}>
          <Field label={t('community.displayOrderLabel')}>
            {({ id }) => (
              <Input
                id={id}
                value={form.displayOrder}
                onChange={(e) =>
                  setForm((current) => ({
                    ...current,
                    displayOrder: e.target.value,
                  }))
                }
              />
            )}
          </Field>
          <Field label={t('community.statusLabel')}>
            {({ id }) => (
              <Select
                id={id}
                value={form.status}
                onChange={(e) =>
                  setForm((current) => ({ ...current, status: e.target.value }))
                }
              >
                {STATUS_VALUES.map((status) => (
                  <option key={status} value={status}>
                    {statusLabel(status)}
                  </option>
                ))}
              </Select>
            )}
          </Field>
        </div>
        <div style={{ display: 'flex', gap: 8 }}>
          <Button type="submit">{editingId ? updateLabel : submitLabel}</Button>
          {editingId ? (
            <Button variant="secondary" onClick={onCancel}>
              {t('community.cancelCta')}
            </Button>
          ) : null}
        </div>
      </form>
    );
  }

  function renderTaxonomyTable(
    items: Array<ForumCategoryItem | ForumTagItem>,
    editingId: string | null,
    onSelect: (item: ForumCategoryItem | ForumTagItem) => void,
    emptyLabel: string,
  ) {
    return (
      <AdminTable
        columns={[
          t('community.colLabel'),
          t('community.colOrder'),
          t('community.colStatus'),
        ]}
        cols="1.8fr 0.5fr 0.9fr"
        footnote={t('community.editHint')}
      >
        {loading ? (
          <EmptyState title={t('community.loading')} />
        ) : items.length === 0 ? (
          <EmptyState title={emptyLabel} />
        ) : (
          items.map((item) => (
            <AdminTableRow
              key={item.id}
              selected={editingId === item.id}
              onSelect={() => onSelect(item)}
            >
              <CellText primary={item.label.fr} sub={item.description.fr} />
              <CellText primary={String(item.displayOrder)} muted />
              <div>
                <Badge variant={STATUS_VARIANT[item.status] ?? 'neutral'}>
                  {statusLabel(item.status)}
                </Badge>
              </div>
            </AdminTableRow>
          ))
        )}
      </AdminTable>
    );
  }

  function toFormState(item: ForumCategoryItem | ForumTagItem): TaxonomyFormState {
    return {
      labelFr: item.label.fr,
      labelEn: item.label.en,
      descriptionFr: item.description.fr,
      descriptionEn: item.description.en,
      displayOrder: String(item.displayOrder),
      status: item.status,
    };
  }

  return (
    <>
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
              <h3 style={panelTitleStyle}>{t('community.categoriesTitle')}</h3>
              <p style={hintStyle}>{t('community.categoriesHint')}</p>
            </div>
            {renderTaxonomyForm(
              categoryForm,
              setCategoryForm,
              submitCategory,
              editingCategoryId,
              () => {
                setEditingCategoryId(null);
                setCategoryForm(EMPTY_FORM);
              },
              t('community.addCategoryCta'),
              t('community.updateCategoryCta'),
            )}
            {renderTaxonomyTable(
              forumCategories,
              editingCategoryId,
              (item) => {
                setEditingCategoryId(item.id);
                setCategoryForm(toFormState(item));
              },
              t('community.categoriesEmpty'),
            )}
          </section>

          <section style={{ ...panelCardStyle, display: 'grid', gap: 14 }}>
            <div>
              <h3 style={panelTitleStyle}>{t('community.tagsTitle')}</h3>
              <p style={hintStyle}>{t('community.tagsHint')}</p>
            </div>
            {renderTaxonomyForm(
              tagForm,
              setTagForm,
              submitTag,
              editingTagId,
              () => {
                setEditingTagId(null);
                setTagForm(EMPTY_FORM);
              },
              t('community.addTagCta'),
              t('community.updateTagCta'),
            )}
            {renderTaxonomyTable(
              forumTags,
              editingTagId,
              (item) => {
                setEditingTagId(item.id);
                setTagForm(toFormState(item));
              },
              t('community.tagsEmpty'),
            )}
          </section>
        </div>

        <AdminTable
          title={`${t('community.moderationTitle')} — ${moderationQueue.length}`}
          columns={[
            t('community.colContent'),
            t('community.colType'),
            t('community.colReports'),
            t('community.colSuggested'),
          ]}
          cols="2fr 0.9fr 0.7fr 1fr"
          footnote={t('community.moderationNote')}
        >
          {loading ? (
            <EmptyState title={t('community.loading')} />
          ) : moderationQueue.length === 0 ? (
            <EmptyState title={t('community.moderationEmpty')} />
          ) : (
            moderationQueue.map((item) => (
              <AdminTableRow key={item.id}>
                <CellText primary={item.subject} />
                <CellText primary={item.targetType.replace(/_/g, ' ')} muted />
                <div>
                  <Badge variant={item.reportsCount > 1 ? 'danger' : 'warning'}>
                    {item.reportsCount}
                  </Badge>
                </div>
                <div>
                  <Badge
                    variant={
                      ACTION_VARIANT[item.suggestedAction.toLowerCase()] ??
                      'neutral'
                    }
                  >
                    {item.suggestedAction.replace(/_/g, ' ')}
                  </Badge>
                </div>
              </AdminTableRow>
            ))
          )}
        </AdminTable>
      </div>
    </>
  );
}
