'use client';

import {
  CSSProperties,
  FormEvent,
  useEffect,
  useMemo,
  useRef,
  useState,
} from 'react';

import { useAdminAuth } from '../../components/admin-auth-provider';
import { DashboardShell } from '../../components/dashboard-shell';
import { useLocale } from '../../components/locale-provider';
import { AdminCapability, hasAdminCapability } from '../../lib/admin-capabilities';
import { apiFetch } from '../../lib/api-client';
import {
  CASE_LIST_SUMMARY_PATH,
  CASE_SEARCH_MAX_LENGTH,
  EMPTY_CASE_LIST_FILTERS,
  EMPTY_CASE_LIST_SUMMARY,
  UNASSIGNED_ADVISOR,
  appendCasePage,
  awaitingSignature,
  caseDetailPath,
  caseListPath,
  displayedAdvisorName,
  hasActiveCaseFilters,
  normalizeCaseListPage,
  normalizeCaseListSummary,
  normalizeCaseSearch,
  patchCaseListItem,
  type AdminCaseDetail,
  type AdminCaseListItem,
  type CaseListFilters,
  type CaseListSummary,
} from '../../lib/case-list';
import {
  applyReplyOverride,
  sortAwaitingReplyFirst,
  type CaseReplyFields,
} from '../../lib/case-messages';
import {
  linkedScholarshipView,
  type LinkedScholarshipView,
} from '../../lib/case-scholarship';
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
import { CaseMessagesThread } from './case-messages-thread';

const allStatuses = [
  'draft', 'submitted', 'under_review', 'documents_needed',
  'counselor_assigned', 'awaiting_student', 'scheduled',
  'in_progress', 'application_submitted', 'waiting_decision',
  'awaiting_payment', 'completed', 'rejected', 'cancelled'
];

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

export default function CasesPage() {
  const { session } = useAdminAuth();
  const { t, locale } = useLocale();
  // La file des bourses n'est ouverte qu'aux éditeurs de contenu : un
  // conseiller suit plutôt le lien vers la page officielle (s'il est servi).
  const canOpenScholarship = hasAdminCapability(
    session?.user.role,
    AdminCapability.ManageScholarshipContent,
  );
  const linkedScholarship = (
    item: AdminCaseListItem,
  ): LinkedScholarshipView | null =>
    linkedScholarshipView(item, locale, canOpenScholarship);
  // Un conseiller ne voit que ses dossiers : le filtre par conseiller ne lui
  // apprendrait rien.
  const isCounselor = session?.user.role === 'counselor';
  // La page chargée, pas tous les dossiers : le serveur filtre, cherche et
  // pagine (50 par page). Les tâches, notes et historique ne sont lus que
  // pour le dossier ouvert (`detail`).
  const [cases, setCases] = useState<AdminCaseListItem[]>([]);
  const [nextCursor, setNextCursor] = useState<string | null>(null);
  const [filters, setFilters] = useState<CaseListFilters>(
    EMPTY_CASE_LIST_FILTERS,
  );
  const [searchDraft, setSearchDraft] = useState('');
  const [listLoading, setListLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [summary, setSummary] = useState<CaseListSummary>(
    EMPTY_CASE_LIST_SUMMARY,
  );
  const [selectedCaseId, setSelectedCaseId] = useState<string | null>(null);
  const [detail, setDetail] = useState<AdminCaseDetail | null>(null);
  const [detailLoading, setDetailLoading] = useState(false);
  // Une réponse arrivée après un changement de filtre ou de dossier est
  // ignorée : sans ce compteur, la page lente d'avant écraserait la bonne.
  const listRequest = useRef(0);
  const detailRequest = useRef(0);
  const [statusMessage, setStatusMessage] = useState<string | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  // No advisor phone/WhatsApp fields on purpose: students and parents only
  // ever see the official KPB line, so per-counsellor numbers stored on a
  // case would never reach them (anti-fraud, Item 12).
  const [assignForm, setAssignForm] = useState({
    assignedAdvisorName: '',
    nextStepTitle: '',
    nextStepDescription: '',
    scheduledAt: '',
  });
  const [taskForm, setTaskForm] = useState({
    title: '',
    assigneeName: '',
    assigneeRole: 'counselor',
    dueAt: '',
    status: 'open',
  });
  const [noteForm, setNoteForm] = useState({
    body: '',
  });
  const [statusForm, setStatusForm] = useState({
    status: '',
  });
  // Ce que le fil ouvert a vu (réponse attendue, dernier message), sans
  // toucher à `cases` : le modifier recréerait le dossier sélectionné et
  // remettrait à zéro les formulaires en cours de saisie à chaque relève.
  const [replyOverrides, setReplyOverrides] = useState<
    Record<string, CaseReplyFields>
  >({});

  async function loadFirstPage(next: CaseListFilters) {
    const request = ++listRequest.current;
    setListLoading(true);
    setErrorMessage(null);
    try {
      const page = normalizeCaseListPage<AdminCaseListItem>(
        await apiFetch<unknown>(caseListPath(next)),
      );
      if (request !== listRequest.current) return;
      setCases(page.items);
      setNextCursor(page.nextCursor);
      // Le dossier ouvert suit la liste : s'il n'y figure plus, le premier.
      setSelectedCaseId((current) =>
        current && page.items.some((item) => item.id === current)
          ? current
          : (page.items[0]?.id ?? null),
      );
    } catch (error) {
      if (request !== listRequest.current) return;
      setErrorMessage(
        error instanceof Error ? error.message : t('cases.loadError'),
      );
    } finally {
      if (request === listRequest.current) setListLoading(false);
    }
  }

  async function loadMore() {
    if (!nextCursor || loadingMore) return;
    const request = listRequest.current;
    setLoadingMore(true);
    setErrorMessage(null);
    try {
      const page = normalizeCaseListPage<AdminCaseListItem>(
        await apiFetch<unknown>(caseListPath(filters, nextCursor)),
      );
      // Les filtres ont changé entre-temps : cette page n'est plus la suite.
      if (request !== listRequest.current) return;
      setCases((current) => appendCasePage(current, page.items));
      setNextCursor(page.nextCursor);
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : t('cases.loadError'),
      );
    } finally {
      setLoadingMore(false);
    }
  }

  async function loadSummary() {
    try {
      setSummary(
        normalizeCaseListSummary(
          await apiFetch<unknown>(CASE_LIST_SUMMARY_PATH),
        ),
      );
    } catch {
      // Le compteur et la liste des conseillers sont un confort : sans eux, la
      // liste reste utilisable, on garde les dernières valeurs connues.
    }
  }

  async function loadDetail(caseId: string): Promise<AdminCaseDetail | null> {
    const request = ++detailRequest.current;
    setDetailLoading(true);
    try {
      const loaded = await apiFetch<AdminCaseDetail>(caseDetailPath(caseId));
      if (request !== detailRequest.current) return null;
      setDetail(loaded);
      return loaded;
    } catch (error) {
      if (request !== detailRequest.current) return null;
      setDetail(null);
      setErrorMessage(
        error instanceof Error ? error.message : t('cases.detailError'),
      );
      return null;
    } finally {
      if (request === detailRequest.current) setDetailLoading(false);
    }
  }

  /**
   * Après une action sur le dossier ouvert : on relit CE dossier et on met sa
   * ligne à jour, sans recharger la liste (les pages déjà chargées et la
   * position de lecture restent).
   */
  async function refreshSelectedCase() {
    if (!selectedCaseId) return;
    const loaded = await loadDetail(selectedCaseId);
    if (loaded) setCases((current) => patchCaseListItem(current, loaded));
    void loadSummary();
  }

  function submitSearch(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setFilters((current) => ({
      ...current,
      q: normalizeCaseSearch(searchDraft),
    }));
  }

  function resetFilters() {
    setSearchDraft('');
    setFilters(EMPTY_CASE_LIST_FILTERS);
  }

  function renderLinkedScholarship(view: LinkedScholarshipView | null) {
    if (!view) {
      return null;
    }
    return (
      <p style={{ margin: 0, fontSize: 'var(--text-sm)' }}>
        <strong style={{ color: 'var(--ink)' }}>
          {t('cases.linkedScholarshipLabel')}
        </strong>{' '}
        {view.href ? (
          <a
            href={view.href}
            style={{ color: 'var(--brand)' }}
            {...(view.external ? { target: '_blank', rel: 'noreferrer' } : {})}
          >
            {view.label}
            {view.external ? ' ↗' : ''}
          </a>
        ) : (
          <span>{view.label}</span>
        )}
        {view.nameMissing ? (
          <span style={{ color: 'var(--text-muted)' }}>
            {' '}
            ({t('cases.linkedScholarshipNameMissing')})
          </span>
        ) : null}
      </p>
    );
  }

  useEffect(() => {
    // Don't fire authenticated admin requests until a session exists,
    // otherwise the page issues token-less calls while unauthenticated.
    if (!session) {
      return;
    }
    void loadFirstPage(filters);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [session, filters]);

  const visibleCases = useMemo(() => {
    const merged = cases.map((item) =>
      applyReplyOverride(item, replyOverrides[item.id]),
    );
    // « Réponses attendues » : celui qui attend depuis le plus longtemps en
    // tête, parmi les dossiers que le serveur a rendus.
    return filters.awaiting ? sortAwaitingReplyFirst(merged) : merged;
  }, [cases, replyOverrides, filters.awaiting]);

  // Le compteur vient du serveur (tous les dossiers visibles, pas la page
  // chargée). Il est relu quand le fil ouvert voit « réponse attendue »
  // changer : l'équipe vient de répondre, ou l'élève d'écrire.
  const replySignature = useMemo(
    () => awaitingSignature(replyOverrides),
    [replyOverrides],
  );
  useEffect(() => {
    if (!session) {
      return;
    }
    void loadSummary();
  }, [session, replySignature]);

  useEffect(() => {
    if (!session || !selectedCaseId) {
      detailRequest.current += 1;
      setDetail(null);
      setDetailLoading(false);
      return;
    }
    void loadDetail(selectedCaseId);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [session, selectedCaseId]);

  const advisorOptions = useMemo(() => {
    const selected =
      filters.advisor && filters.advisor !== UNASSIGNED_ADVISOR
        ? [filters.advisor]
        : [];
    const known = new Set(summary.advisors.map((name) => name.toLowerCase()));
    return [
      ...summary.advisors,
      ...selected.filter((name) => !known.has(name.toLowerCase())),
    ];
  }, [summary.advisors, filters.advisor]);

  const filtersActive = hasActiveCaseFilters(filters);

  function handleReplyFieldsChange(caseId: string, fields: CaseReplyFields) {
    setReplyOverrides((current) => {
      const previous = current[caseId];
      if (
        previous &&
        previous.awaitingReply === fields.awaitingReply &&
        previous.lastMessageAt === fields.lastMessageAt
      ) {
        return current;
      }
      return { ...current, [caseId]: fields };
    });
  }

  // Le panneau n'affiche le détail que du dossier sélectionné : pendant le
  // chargement d'un autre dossier, jamais celui d'avant sous le nouveau nom.
  const selectedCase = detail && detail.id === selectedCaseId ? detail : null;

  useEffect(() => {
    if (!detail) {
      return;
    }
    setAssignForm({
      assignedAdvisorName: detail.assignedAdvisorName ?? '',
      nextStepTitle: detail.nextStepTitle,
      nextStepDescription: detail.nextStepDescription,
      scheduledAt: '',
    });
    setStatusForm({
      status: detail.status,
    });
  }, [detail]);

  async function submitAssignment(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!selectedCase) {
      return;
    }

    setStatusMessage(null);
    setErrorMessage(null);
    try {
      await apiFetch(`/admin/cases/${selectedCase.id}/assign`, {
        method: 'POST',
        body: {
          assignedAdvisorName: assignForm.assignedAdvisorName,
          nextStepTitle: assignForm.nextStepTitle || undefined,
          nextStepDescription: assignForm.nextStepDescription || undefined,
          scheduledAt: assignForm.scheduledAt
            ? new Date(assignForm.scheduledAt).toISOString()
            : undefined,
        },
      });
      setStatusMessage(t('cases.assignSuccess'));
      await refreshSelectedCase();
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : t('cases.assignError'),
      );
    }
  }

  async function submitStatus(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!selectedCase) {
      return;
    }

    setStatusMessage(null);
    setErrorMessage(null);
    try {
      await apiFetch(`/admin/cases/${selectedCase.id}`, {
        method: 'PATCH',
        body: {
          status: statusForm.status,
        },
      });
      setStatusMessage(t('cases.statusSuccess'));
      await refreshSelectedCase();
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : t('cases.statusError'),
      );
    }
  }

  async function submitTask(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!selectedCase) {
      return;
    }

    setStatusMessage(null);
    setErrorMessage(null);
    try {
      await apiFetch(`/admin/cases/${selectedCase.id}/tasks`, {
        method: 'POST',
        body: {
          title: taskForm.title,
          assigneeName: taskForm.assigneeName || undefined,
          assigneeRole: taskForm.assigneeRole || undefined,
          dueAt: taskForm.dueAt
            ? new Date(taskForm.dueAt).toISOString()
            : undefined,
          status: taskForm.status,
        },
      });
      setTaskForm({
        title: '',
        assigneeName: '',
        assigneeRole: 'counselor',
        dueAt: '',
        status: 'open',
      });
      setStatusMessage(t('cases.taskSuccess'));
      await refreshSelectedCase();
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : t('cases.taskError'),
      );
    }
  }

  async function submitNote(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!selectedCase || !session) {
      return;
    }

    setStatusMessage(null);
    setErrorMessage(null);
    try {
      await apiFetch(`/admin/cases/${selectedCase.id}/internal-notes`, {
        method: 'POST',
        body: {
          authorName: session.user.fullName,
          authorRole: session.user.role,
          body: noteForm.body,
        },
      });
      setNoteForm({ body: '' });
      setStatusMessage(t('cases.noteSuccess'));
      await refreshSelectedCase();
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : t('cases.noteError'),
      );
    }
  }

  return (
    <DashboardShell title={t('cases.title')} subtitle={t('cases.subtitle')}>
      <div style={{ display: 'grid', gap: 14 }}>
        {statusMessage ? <Alert variant="success">{statusMessage}</Alert> : null}
        {errorMessage ? <Alert variant="danger">{errorMessage}</Alert> : null}

        <form
          onSubmit={submitSearch}
          style={{
            display: 'grid',
            gap: 10,
            gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))',
            alignItems: 'end',
          }}
        >
          <Field label={t('cases.searchLabel')}>
            {({ id }) => (
              <Input
                id={id}
                type="search"
                value={searchDraft}
                maxLength={CASE_SEARCH_MAX_LENGTH}
                placeholder={t('cases.searchPlaceholder')}
                onChange={(event) => setSearchDraft(event.target.value)}
              />
            )}
          </Field>
          <Field label={t('cases.filterStatusLabel')}>
            {({ id }) => (
              <Select
                id={id}
                value={filters.status}
                onChange={(event) =>
                  setFilters((current) => ({
                    ...current,
                    status: event.target.value,
                  }))
                }
              >
                <option value="">{t('cases.filterStatusAll')}</option>
                {allStatuses.map((s) => (
                  <option key={s} value={s}>
                    {s.replaceAll('_', ' ')}
                  </option>
                ))}
              </Select>
            )}
          </Field>
          {isCounselor ? null : (
            <Field label={t('cases.filterAdvisorLabel')}>
              {({ id }) => (
                <Select
                  id={id}
                  value={filters.advisor}
                  onChange={(event) =>
                    setFilters((current) => ({
                      ...current,
                      advisor: event.target.value,
                    }))
                  }
                >
                  <option value="">{t('cases.filterAdvisorAll')}</option>
                  <option value={UNASSIGNED_ADVISOR}>
                    {t('cases.filterAdvisorNone')}
                  </option>
                  {advisorOptions.map((name) => (
                    <option key={name} value={name}>
                      {name}
                    </option>
                  ))}
                </Select>
              )}
            </Field>
          )}
          <Button type="submit" variant="secondary" loading={listLoading}>
            {t('cases.searchCta')}
          </Button>
        </form>

        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'flex-end',
            gap: 10,
            flexWrap: 'wrap',
          }}
        >
          {filtersActive ? (
            <Button variant="ghost" size="sm" onClick={resetFilters}>
              {t('cases.resetFilters')}
            </Button>
          ) : null}
          <Button
            variant={filters.awaiting ? 'primary' : 'secondary'}
            size="sm"
            aria-pressed={filters.awaiting}
            onClick={() =>
              setFilters((current) => ({
                ...current,
                awaiting: !current.awaiting,
              }))
            }
          >
            {t('cases.awaitingOnlyToggle')} ({summary.awaitingCount})
          </Button>
        </div>

        <AdminTable
          aria-label={t('cases.title')}
          columns={[
            t('cases.colReference'),
            t('cases.colStudent'),
            t('cases.colType'),
            t('cases.colStatus'),
            t('cases.colAdvisor'),
            t('cases.colNextStep'),
          ]}
          cols="0.9fr 1.3fr 1fr 1fr 1fr 1.4fr"
          footnote={t('cases.tableNote')}
        >
          {visibleCases.length === 0 ? (
            <EmptyState
              title={
                listLoading
                  ? t('cases.loading')
                  : filtersActive
                    ? t('cases.emptyFiltered')
                    : t('cases.empty')
              }
            />
          ) : (
            visibleCases.map((item) => (
              <AdminTableRow
                key={item.id}
                selected={selectedCaseId === item.id}
                onSelect={() => setSelectedCaseId(item.id)}
              >
                <CellText
                  primary={item.referenceCode}
                  sub={item.preferredLanguage.toUpperCase()}
                />
                <CellText primary={item.studentName} sub={item.studentEmail} />
                <CellText
                  primary={item.type}
                  sub={linkedScholarship(item)?.label ?? item.contextLabel}
                  muted
                />
                <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, alignItems: 'center' }}>
                  <StatusBadge status={item.status} />
                  {item.awaitingReply ? (
                    <Badge variant="warning">{t('cases.awaitingReplyBadge')}</Badge>
                  ) : null}
                </div>
                <CellText
                  primary={
                    displayedAdvisorName(item.assignedAdvisorName) ??
                    t('cases.unassigned')
                  }
                  muted={!displayedAdvisorName(item.assignedAdvisorName)}
                />
                <CellText
                  primary={item.nextStepTitle}
                  sub={item.nextStepDescription}
                />
              </AdminTableRow>
            ))
          )}
        </AdminTable>

        {nextCursor ? (
          <div style={{ display: 'flex', justifyContent: 'center' }}>
            <Button
              variant="secondary"
              loading={loadingMore}
              onClick={() => void loadMore()}
            >
              {loadingMore ? t('cases.loadingMore') : t('cases.loadMore')}
            </Button>
          </div>
        ) : null}

        {selectedCaseId && !selectedCase && detailLoading ? (
          <p
            role="status"
            style={{ margin: 0, fontSize: 'var(--text-sm)', color: 'var(--text-muted)' }}
          >
            {t('cases.detailLoading')}
          </p>
        ) : null}

        {selectedCase ? (
          <div style={{ display: 'grid', gap: 14, gridTemplateColumns: '1.15fr 0.85fr' }}>
            <section style={{ ...panelCardStyle, display: 'grid', gap: 16, alignContent: 'start' }}>
              <div style={{ display: 'grid', gap: 6 }}>
                <h3 style={panelTitleStyle}>{selectedCase.referenceCode}</h3>
                <p style={{ margin: 0, fontSize: 'var(--text-sm)', color: 'var(--text-muted)' }}>
                  {selectedCase.studentName} • {selectedCase.studentEmail}
                </p>
                <div>
                  <StatusBadge status={selectedCase.status} />
                </div>
                {renderLinkedScholarship(linkedScholarship(selectedCase))}
              </div>
              <CaseMessagesThread
                key={selectedCase.id}
                caseId={selectedCase.id}
                locale={locale}
                t={t}
                onReplyFieldsChange={handleReplyFieldsChange}
              />
              <div>
                <strong style={{ fontSize: 'var(--text-sm)', color: 'var(--ink)' }}>
                  {t('cases.nextStepHeading')}
                </strong>
                <p style={{ margin: '8px 0 0', fontSize: 'var(--text-sm)', color: 'var(--text-muted)' }}>
                  {selectedCase.nextStepTitle} — {selectedCase.nextStepDescription}
                </p>
              </div>
              <div>
                <strong style={{ fontSize: 'var(--text-sm)', color: 'var(--ink)' }}>
                  {t('cases.timelineHeading')}
                </strong>
                {selectedCase.timelineTruncated ? (
                  <p style={{ margin: '8px 0 0', fontSize: 'var(--text-sm)', color: 'var(--text-muted)' }}>
                    {t('cases.timelineTruncated')}
                  </p>
                ) : null}
                <div style={{ display: 'grid', gap: 12, marginTop: 10 }}>
                  {selectedCase.timeline.map((item) => (
                    <div
                      key={item.id}
                      style={{ borderTop: '1px solid var(--border-soft)', paddingTop: 12 }}
                    >
                      <strong style={{ fontSize: 'var(--text-sm)' }}>{item.title}</strong>
                      <p style={{ margin: '6px 0', fontSize: 'var(--text-sm)', color: 'var(--text-muted)' }}>
                        {item.description}
                      </p>
                      <StatusBadge status={item.status} />
                    </div>
                  ))}
                </div>
              </div>
              <div>
                <strong style={{ fontSize: 'var(--text-sm)', color: 'var(--ink)' }}>
                  {t('cases.notesHeading')}
                </strong>
                <div style={{ display: 'grid', gap: 12, marginTop: 10 }}>
                  {selectedCase.internalNotes.map((item) => (
                    <div
                      key={item.id}
                      style={{ borderTop: '1px solid var(--border-soft)', paddingTop: 12 }}
                    >
                      <strong style={{ fontSize: 'var(--text-sm)' }}>
                        {item.authorName} • {item.authorRole}
                      </strong>
                      <p style={{ margin: '6px 0 0', fontSize: 'var(--text-sm)', color: 'var(--text-muted)' }}>
                        {item.body}
                      </p>
                    </div>
                  ))}
                </div>
              </div>
            </section>

            <div style={{ display: 'grid', gap: 14, alignContent: 'start' }}>
              <section style={{ ...panelCardStyle, display: 'grid', gap: 12 }}>
                <h3 style={panelTitleStyle}>{t('cases.updateStatusTitle')}</h3>
                <form onSubmit={submitStatus} style={{ display: 'grid', gap: 12 }}>
                  <Field label={t('cases.statusLabel')}>
                    {({ id }) => (
                      <Select
                        id={id}
                        value={statusForm.status}
                        onChange={(event) =>
                          setStatusForm({ status: event.target.value })
                        }
                      >
                        {allStatuses.map((s) => (
                          <option key={s} value={s}>
                            {s.replaceAll('_', ' ')}
                          </option>
                        ))}
                      </Select>
                    )}
                  </Field>
                  <Button type="submit">{t('cases.updateStatusCta')}</Button>
                </form>
              </section>

              {/* L'affectation est réservée à l'équipe (le serveur refuse un
                  conseiller) : inutile de lui montrer un formulaire voué au 403. */}
              {session?.user.role !== 'counselor' && (
              <section style={{ ...panelCardStyle, display: 'grid', gap: 12 }}>
                <h3 style={panelTitleStyle}>{t('cases.assignTitle')}</h3>
                <form onSubmit={submitAssignment} style={{ display: 'grid', gap: 12 }}>
                  <Field label={t('cases.advisorNameLabel')}>
                    {({ id }) => (
                      <Input
                        id={id}
                        value={assignForm.assignedAdvisorName}
                        onChange={(event) =>
                          setAssignForm((current) => ({
                            ...current,
                            assignedAdvisorName: event.target.value,
                          }))
                        }
                      />
                    )}
                  </Field>
                  <Field label={t('cases.nextStepTitleLabel')}>
                    {({ id }) => (
                      <Input
                        id={id}
                        value={assignForm.nextStepTitle}
                        onChange={(event) =>
                          setAssignForm((current) => ({
                            ...current,
                            nextStepTitle: event.target.value,
                          }))
                        }
                      />
                    )}
                  </Field>
                  <Field label={t('cases.nextStepDescriptionLabel')}>
                    {({ id }) => (
                      <Textarea
                        id={id}
                        value={assignForm.nextStepDescription}
                        onChange={(event) =>
                          setAssignForm((current) => ({
                            ...current,
                            nextStepDescription: event.target.value,
                          }))
                        }
                      />
                    )}
                  </Field>
                  <Field label={t('cases.scheduledAtLabel')}>
                    {({ id }) => (
                      <Input
                        id={id}
                        type="datetime-local"
                        value={assignForm.scheduledAt}
                        onChange={(event) =>
                          setAssignForm((current) => ({
                            ...current,
                            scheduledAt: event.target.value,
                          }))
                        }
                      />
                    )}
                  </Field>
                  <Button type="submit">{t('cases.saveAssignmentCta')}</Button>
                </form>
              </section>
              )}

              <section style={{ ...panelCardStyle, display: 'grid', gap: 12 }}>
                <h3 style={panelTitleStyle}>{t('cases.createTaskTitle')}</h3>
                <form onSubmit={submitTask} style={{ display: 'grid', gap: 12 }}>
                  <Field label={t('cases.taskTitleLabel')}>
                    {({ id }) => (
                      <Input
                        id={id}
                        value={taskForm.title}
                        onChange={(event) =>
                          setTaskForm((current) => ({
                            ...current,
                            title: event.target.value,
                          }))
                        }
                      />
                    )}
                  </Field>
                  <Field label={t('cases.assigneeNameLabel')}>
                    {({ id }) => (
                      <Input
                        id={id}
                        value={taskForm.assigneeName}
                        onChange={(event) =>
                          setTaskForm((current) => ({
                            ...current,
                            assigneeName: event.target.value,
                          }))
                        }
                      />
                    )}
                  </Field>
                  <Field label={t('cases.assigneeRoleLabel')}>
                    {({ id }) => (
                      <Input
                        id={id}
                        value={taskForm.assigneeRole}
                        onChange={(event) =>
                          setTaskForm((current) => ({
                            ...current,
                            assigneeRole: event.target.value,
                          }))
                        }
                      />
                    )}
                  </Field>
                  <Field label={t('cases.dueAtLabel')}>
                    {({ id }) => (
                      <Input
                        id={id}
                        type="datetime-local"
                        value={taskForm.dueAt}
                        onChange={(event) =>
                          setTaskForm((current) => ({
                            ...current,
                            dueAt: event.target.value,
                          }))
                        }
                      />
                    )}
                  </Field>
                  <Button type="submit">{t('cases.addTaskCta')}</Button>
                </form>
                <div style={{ display: 'grid', gap: 12 }}>
                  {selectedCase.tasks.map((task) => (
                    <div
                      key={task.id}
                      style={{ borderTop: '1px solid var(--border-soft)', paddingTop: 12 }}
                    >
                      <strong style={{ fontSize: 'var(--text-sm)' }}>{task.title}</strong>
                      <p style={{ margin: '6px 0 0', fontSize: 'var(--text-sm)', color: 'var(--text-muted)' }}>
                        {task.assigneeName ?? t('cases.unassigned')} • {task.status}
                      </p>
                    </div>
                  ))}
                </div>
              </section>

              <section style={{ ...panelCardStyle, display: 'grid', gap: 12 }}>
                <h3 style={panelTitleStyle}>{t('cases.addNoteTitle')}</h3>
                <form onSubmit={submitNote} style={{ display: 'grid', gap: 12 }}>
                  <Field label={t('cases.noteLabel')}>
                    {({ id }) => (
                      <Textarea
                        id={id}
                        value={noteForm.body}
                        onChange={(event) =>
                          setNoteForm({ body: event.target.value })
                        }
                      />
                    )}
                  </Field>
                  <Button type="submit">{t('cases.saveNoteCta')}</Button>
                </form>
              </section>
            </div>
          </div>
        ) : null}
      </div>
    </DashboardShell>
  );
}
