'use client';

import { CSSProperties, FormEvent, useEffect, useMemo, useState } from 'react';

import { useAdminAuth } from '../../components/admin-auth-provider';
import { DashboardShell } from '../../components/dashboard-shell';
import { useLocale } from '../../components/locale-provider';
import { apiFetch } from '../../lib/api-client';
import {
  AdminTable,
  AdminTableRow,
  Alert,
  Button,
  CellText,
  EmptyState,
  Field,
  Input,
  Select,
  StatusBadge,
  Textarea,
} from '../../components/ui';

interface CaseTaskItem {
  id: string;
  title: string;
  assigneeName: string | null;
  status: string;
  dueAt: string | null;
}

interface CaseNoteItem {
  id: string;
  authorName: string;
  authorRole: string;
  body: string;
  createdAt: string;
}

interface CaseTimelineItem {
  id: string;
  title: string;
  description: string;
  status: string;
  createdAt: string;
}

interface AdminCaseItem {
  id: string;
  referenceCode: string;
  studentName: string;
  studentEmail: string;
  preferredLanguage: string;
  type: string;
  status: string;
  contextLabel: string;
  assignedAdvisorName: string | null;
  nextStepTitle: string;
  nextStepDescription: string;
  tasks: CaseTaskItem[];
  internalNotes: CaseNoteItem[];
  timeline: CaseTimelineItem[];
}

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
  const { t } = useLocale();
  const [cases, setCases] = useState<AdminCaseItem[]>([]);
  const [selectedCaseId, setSelectedCaseId] = useState<string | null>(null);
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

  async function loadCases() {
    setErrorMessage(null);
    try {
      const response = await apiFetch<AdminCaseItem[]>('/admin/cases');
      setCases(response);
      if (!selectedCaseId && response[0]) {
        setSelectedCaseId(response[0].id);
      }
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : t('cases.loadError'),
      );
    }
  }

  useEffect(() => {
    // Don't fire authenticated admin requests until a session exists,
    // otherwise the page issues token-less calls while unauthenticated.
    if (!session) {
      return;
    }
    void loadCases();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [session]);

  const selectedCase = useMemo(
    () => cases.find((item) => item.id === selectedCaseId) ?? null,
    [cases, selectedCaseId],
  );

  useEffect(() => {
    if (!selectedCase) {
      return;
    }
    setAssignForm({
      assignedAdvisorName: selectedCase.assignedAdvisorName ?? '',
      nextStepTitle: selectedCase.nextStepTitle,
      nextStepDescription: selectedCase.nextStepDescription,
      scheduledAt: '',
    });
    setStatusForm({
      status: selectedCase.status,
    });
  }, [selectedCase]);

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
      await loadCases();
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
      await loadCases();
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
      await loadCases();
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
      await loadCases();
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
          {cases.length === 0 ? (
            <EmptyState title={t('cases.empty')} />
          ) : (
            cases.map((item) => (
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
                <CellText primary={item.type} sub={item.contextLabel} muted />
                <div>
                  <StatusBadge status={item.status} />
                </div>
                <CellText
                  primary={item.assignedAdvisorName ?? t('cases.unassigned')}
                  muted={!item.assignedAdvisorName}
                />
                <CellText
                  primary={item.nextStepTitle}
                  sub={item.nextStepDescription}
                />
              </AdminTableRow>
            ))
          )}
        </AdminTable>

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
              </div>
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
