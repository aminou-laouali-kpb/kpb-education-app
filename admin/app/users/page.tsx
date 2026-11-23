'use client';

import { CSSProperties, FormEvent, useEffect, useMemo, useState } from 'react';

import { useAdminAuth } from '../../components/admin-auth-provider';
import { DashboardShell } from '../../components/dashboard-shell';
import { useLocale } from '../../components/locale-provider';
import {
  ResetPasswordDialog,
  type ResetPasswordTarget,
} from '../../components/users/reset-password-dialog';
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
} from '../../components/ui';

interface AdminUserItem {
  id: string;
  fullName: string;
  email: string;
  role: string;
  isActive: boolean;
  languageScope: string[];
  workload: number;
}

const ROLE_OPTIONS = [
  'counselor',
  'commercial',
  'content_manager',
  'moderator',
  'admin',
  'super_admin',
];

function splitList(value: string) {
  return value
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);
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

export default function UsersPage() {
  const { session } = useAdminAuth();
  const { t } = useLocale();
  const [users, setUsers] = useState<AdminUserItem[]>([]);
  const [selectedUserId, setSelectedUserId] = useState<string | null>(null);
  const [statusMessage, setStatusMessage] = useState<string | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [createForm, setCreateForm] = useState({
    fullName: '',
    email: '',
    role: 'counselor',
    languageScope: 'fr,en',
    isActive: true,
  });
  const [updateForm, setUpdateForm] = useState({
    role: 'counselor',
    isActive: true,
    workload: '0',
  });
  const [resetTarget, setResetTarget] = useState<ResetPasswordTarget | null>(
    null,
  );
  const [resetting, setResetting] = useState(false);
  const [credential, setCredential] = useState<{
    email: string;
    tempPassword: string;
  } | null>(null);

  function roleLabel(role: string) {
    return ROLE_OPTIONS.includes(role) ? t(`roles.${role}`) : role;
  }

  async function loadUsers() {
    setErrorMessage(null);
    try {
      const response = await apiFetch<{ items: AdminUserItem[] }>('/admin/users');
      setUsers(response.items);
      if (!selectedUserId && response.items[0]) {
        setSelectedUserId(response.items[0].id);
      }
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : t('users.loadError'),
      );
    }
  }

  useEffect(() => {
    if (!session) {
      return;
    }
    void loadUsers();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [session]);

  const selectedUser = useMemo(
    () => users.find((item) => item.id === selectedUserId) ?? null,
    [selectedUserId, users],
  );

  useEffect(() => {
    if (!selectedUser) {
      return;
    }
    setUpdateForm({
      role: selectedUser.role,
      isActive: selectedUser.isActive,
      workload: String(selectedUser.workload),
    });
  }, [selectedUser]);

  async function submitCreate(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setStatusMessage(null);
    setErrorMessage(null);

    try {
      const created = await apiFetch<{ email: string; tempPassword?: string }>(
        '/admin/users',
        {
          method: 'POST',
          body: {
            fullName: createForm.fullName,
            email: createForm.email,
            role: createForm.role,
            languageScope: splitList(createForm.languageScope),
            isActive: createForm.isActive,
          },
        },
      );
      setCreateForm({
        fullName: '',
        email: '',
        role: 'counselor',
        languageScope: 'fr,en',
        isActive: true,
      });
      if (created?.tempPassword) {
        setCredential({
          email: created.email,
          tempPassword: created.tempPassword,
        });
      }
      setStatusMessage(t('users.createSuccess'));
      await loadUsers();
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : t('users.createError'),
      );
    }
  }

  async function submitUpdate(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!selectedUser) {
      return;
    }

    setStatusMessage(null);
    setErrorMessage(null);
    // Don't leave a previously-issued temp password on screen during an
    // unrelated role/activation change.
    setCredential(null);

    try {
      await apiFetch(`/admin/users/${selectedUser.id}`, {
        method: 'PATCH',
        body: {
          role: updateForm.role,
          isActive: updateForm.isActive,
          workload: Number(updateForm.workload),
        },
      });
      setStatusMessage(t('users.updateSuccess'));
      await loadUsers();
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : t('users.updateError'),
      );
    }
  }

  // Appelée uniquement depuis la confirmation : le compte visé est celui
  // nommé dans le dialogue, même si la sélection a changé entre-temps.
  async function resetPassword() {
    const target = resetTarget;
    if (!target || resetting) {
      return;
    }
    setStatusMessage(null);
    setErrorMessage(null);
    setResetting(true);
    try {
      const result = await apiFetch<{ email: string; tempPassword: string }>(
        `/admin/users/${target.id}/reset-password`,
        { method: 'POST' },
      );
      setCredential({
        email: result.email,
        tempPassword: result.tempPassword,
      });
      setStatusMessage(t('users.resetSuccess'));
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : t('users.resetError'),
      );
    } finally {
      setResetting(false);
      setResetTarget(null);
    }
  }

  async function copyCredential() {
    if (!credential) {
      return;
    }
    try {
      await navigator.clipboard.writeText(credential.tempPassword);
      setStatusMessage(t('users.copySuccess'));
    } catch {
      // Clipboard may be unavailable (insecure context); value stays on screen.
    }
  }

  return (
    <DashboardShell title={t('users.title')} subtitle={t('users.subtitle')}>
      <div style={{ display: 'grid', gap: 14 }}>
        {statusMessage ? <Alert variant="success">{statusMessage}</Alert> : null}
        {errorMessage ? <Alert variant="danger">{errorMessage}</Alert> : null}
        {credential ? (
          <div
            style={{
              ...panelCardStyle,
              background: 'var(--warning-bg)',
              border: '1px solid var(--warning-fg)',
              display: 'grid',
              gap: 8,
            }}
          >
            <strong style={{ fontSize: 'var(--text-sm)' }}>
              {t('users.credentialTitle')} {credential.email}
            </strong>
            <code
              style={{
                fontSize: 18,
                fontWeight: 700,
                letterSpacing: 1,
                background: 'var(--surface)',
                border: '1px solid var(--border)',
                borderRadius: 10,
                padding: '8px 12px',
                wordBreak: 'break-all',
              }}
            >
              {credential.tempPassword}
            </code>
            <p style={{ margin: 0, fontSize: 'var(--text-xs)', color: 'var(--warning-fg)' }}>
              {t('users.credentialHint')}
            </p>
            <div style={{ display: 'flex', gap: 8 }}>
              <Button size="sm" onClick={copyCredential}>
                {t('users.copyCta')}
              </Button>
              <Button size="sm" variant="secondary" onClick={() => setCredential(null)}>
                {t('users.dismissCta')}
              </Button>
            </div>
          </div>
        ) : null}

        <div style={{ display: 'grid', gap: 14, gridTemplateColumns: '1.25fr 0.75fr' }}>
          <div style={{ display: 'grid', gap: 14, alignContent: 'start' }}>
            <AdminTable
              aria-label={t('users.title')}
              columns={[
                t('users.colName'),
                t('users.colRole'),
                t('users.colStatus'),
                t('users.colLanguages'),
                t('users.colWorkload'),
                t('users.colActions'),
              ]}
              cols="1.5fr 1fr 0.8fr 0.7fr 0.6fr 0.8fr"
              footnote={t('users.tableNote')}
            >
              {users.length === 0 ? (
                <EmptyState title={t('users.empty')} />
              ) : (
                users.map((user) => (
                  <AdminTableRow
                    key={user.id}
                    selected={selectedUserId === user.id}
                  >
                    <CellText primary={user.fullName} sub={user.email} />
                    <div>
                      <Badge variant="brand">{roleLabel(user.role)}</Badge>
                    </div>
                    <div>
                      <Badge variant={user.isActive ? 'success' : 'neutral'}>
                        {user.isActive ? t('users.active') : t('users.inactive')}
                      </Badge>
                    </div>
                    <CellText
                      primary={user.languageScope.join(', ').toUpperCase()}
                      muted
                    />
                    <CellText primary={String(user.workload)} muted />
                    <div>
                      <Button
                        size="sm"
                        variant={selectedUserId === user.id ? 'primary' : 'secondary'}
                        onClick={() => setSelectedUserId(user.id)}
                      >
                        {t('users.manageCta')}
                      </Button>
                    </div>
                  </AdminTableRow>
                ))
              )}
            </AdminTable>
          </div>

          <div style={{ display: 'grid', gap: 14, alignContent: 'start' }}>
            <section style={{ ...panelCardStyle, display: 'grid', gap: 12 }}>
              <h3 style={panelTitleStyle}>{t('users.createTitle')}</h3>
              <form onSubmit={submitCreate} style={{ display: 'grid', gap: 12 }}>
                <Field label={t('users.fullNameLabel')}>
                  {({ id }) => (
                    <Input
                      id={id}
                      value={createForm.fullName}
                      onChange={(event) =>
                        setCreateForm((current) => ({
                          ...current,
                          fullName: event.target.value,
                        }))
                      }
                    />
                  )}
                </Field>
                <Field label={t('users.emailLabel')}>
                  {({ id }) => (
                    <Input
                      id={id}
                      value={createForm.email}
                      onChange={(event) =>
                        setCreateForm((current) => ({
                          ...current,
                          email: event.target.value,
                        }))
                      }
                    />
                  )}
                </Field>
                <Field label={t('users.roleLabel')}>
                  {({ id }) => (
                    <Select
                      id={id}
                      value={createForm.role}
                      onChange={(event) =>
                        setCreateForm((current) => ({
                          ...current,
                          role: event.target.value,
                        }))
                      }
                    >
                      {ROLE_OPTIONS.map((role) => (
                        <option key={role} value={role}>
                          {roleLabel(role)}
                        </option>
                      ))}
                    </Select>
                  )}
                </Field>
                <Field label={t('users.languageScopeLabel')}>
                  {({ id }) => (
                    <Input
                      id={id}
                      value={createForm.languageScope}
                      onChange={(event) =>
                        setCreateForm((current) => ({
                          ...current,
                          languageScope: event.target.value,
                        }))
                      }
                    />
                  )}
                </Field>
                <label
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: 8,
                    fontSize: 'var(--text-sm)',
                    fontWeight: 600,
                  }}
                >
                  <input
                    type="checkbox"
                    checked={createForm.isActive}
                    onChange={(event) =>
                      setCreateForm((current) => ({
                        ...current,
                        isActive: event.target.checked,
                      }))
                    }
                  />
                  {t('users.activeLabel')}
                </label>
                <Button type="submit">{t('users.createCta')}</Button>
              </form>
            </section>

            {selectedUser ? (
              <section style={{ ...panelCardStyle, display: 'grid', gap: 12 }}>
                <h3 style={panelTitleStyle}>{t('users.updateTitle')}</h3>
                <p style={{ margin: 0, fontSize: 'var(--text-sm)', color: 'var(--text-muted)' }}>
                  {selectedUser.fullName} • {selectedUser.email}
                </p>
                <form onSubmit={submitUpdate} style={{ display: 'grid', gap: 12 }}>
                  <Field label={t('users.roleLabel')}>
                    {({ id }) => (
                      <Select
                        id={id}
                        value={updateForm.role}
                        onChange={(event) =>
                          setUpdateForm((current) => ({
                            ...current,
                            role: event.target.value,
                          }))
                        }
                      >
                        {ROLE_OPTIONS.map((role) => (
                          <option key={role} value={role}>
                            {roleLabel(role)}
                          </option>
                        ))}
                      </Select>
                    )}
                  </Field>
                  <Field label={t('users.workloadLabel')}>
                    {({ id }) => (
                      <Input
                        id={id}
                        value={updateForm.workload}
                        onChange={(event) =>
                          setUpdateForm((current) => ({
                            ...current,
                            workload: event.target.value,
                          }))
                        }
                      />
                    )}
                  </Field>
                  <label
                    style={{
                      display: 'flex',
                      alignItems: 'center',
                      gap: 8,
                      fontSize: 'var(--text-sm)',
                      fontWeight: 600,
                    }}
                  >
                    <input
                      type="checkbox"
                      checked={updateForm.isActive}
                      onChange={(event) =>
                        setUpdateForm((current) => ({
                          ...current,
                          isActive: event.target.checked,
                        }))
                      }
                    />
                    {t('users.activeLabel')}
                  </label>
                  <Button type="submit">{t('users.saveCta')}</Button>
                </form>
                <Button
                  variant="danger"
                  disabled={resetting}
                  onClick={() =>
                    setResetTarget({
                      id: selectedUser.id,
                      fullName: selectedUser.fullName,
                      email: selectedUser.email,
                    })
                  }
                >
                  {t('users.resetPasswordCta')}
                </Button>
                <p style={{ margin: 0, fontSize: 'var(--text-xs)', color: 'var(--text-muted)' }}>
                  {t('users.resetPasswordHint')}
                </p>
              </section>
            ) : null}
          </div>
        </div>
      </div>
      <ResetPasswordDialog
        target={resetTarget}
        isSelf={resetTarget !== null && resetTarget.id === session?.user.id}
        loading={resetting}
        onConfirm={() => void resetPassword()}
        onCancel={() => setResetTarget(null)}
      />
    </DashboardShell>
  );
}
