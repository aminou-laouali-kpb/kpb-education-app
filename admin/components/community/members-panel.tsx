'use client';

import { FormEvent, useState } from 'react';

import {
  type AdminMemberDetail,
  type CommunityPermissions,
  communityAdminApi,
  type QueueResponse,
  mostReportedMembers,
  plainText,
  type Page,
  type Sanction,
  SANCTION_VARIANT,
  type SanctionKind,
  type SanctionWithMember,
} from '../../lib/community-admin';
import { useLocale } from '../locale-provider';
import { AdminTable, AdminTableRow, Alert, Badge, Button, CellText, EmptyState, Field, Input } from '../ui';
import { ReasonDialog, SanctionDialog } from './action-dialogs';
import { PostsTable } from './content-panel';
import {
  AuthorLine,
  ContentStatusBadge,
  enumLabel,
  errorText,
  fill,
  formatDate,
  hintStyle,
  LoadError,
  Section,
  useLoader,
} from './shared';

/** Membres : plus signalés, recherche par identifiant public, fiche et sanctions (§8.3, §8.5). */
export function MembersPanel({
  permissions,
  memberId,
  onOpenMember,
  onOpenPost,
}: Readonly<{
  permissions: CommunityPermissions;
  memberId: string | null;
  onOpenMember: (memberId: string | null) => void;
  onOpenPost: (postId: string) => void;
}>) {
  const { t } = useLocale();
  if (memberId) {
    return (
      <div style={{ display: 'grid', gap: 12 }}>
        <div>
          <Button variant="ghost" size="sm" onClick={() => onOpenMember(null)}>
            ← {t('communityAdmin.members.back')}
          </Button>
        </div>
        <MemberDetailPanel memberId={memberId} permissions={permissions} onOpenPost={onOpenPost} />
      </div>
    );
  }
  return <MembersOverview permissions={permissions} onOpenMember={(id) => onOpenMember(id)} />;
}

function MembersOverview({
  permissions,
  onOpenMember,
}: Readonly<{ permissions: CommunityPermissions; onOpenMember: (memberId: string) => void }>) {
  const { t } = useLocale();
  const [lookup, setLookup] = useState('');
  const reported = useLoader<QueueResponse>(() => communityAdminApi.queue('members', null, 50), []);

  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const id = lookup.trim();
    if (id) onOpenMember(id);
  }

  return (
    <div style={{ display: 'grid', gap: 12 }}>
      <Section title={t('communityAdmin.members.lookupTitle')} hint={t('communityAdmin.members.lookupHint')}>
        <form onSubmit={submit} style={{ display: 'flex', gap: 10, alignItems: 'flex-end', flexWrap: 'wrap' }}>
          <div style={{ flex: '1 1 260px' }}>
            <Field label={t('communityAdmin.members.memberId')}>
              {({ id }) => <Input id={id} value={lookup} placeholder="cm_…" onChange={(e) => setLookup(e.target.value)} />}
            </Field>
          </div>
          <Button type="submit" disabled={!lookup.trim()}>
            {t('communityAdmin.members.open')}
          </Button>
        </form>
      </Section>

      <Section title={t('communityAdmin.members.mostReported')} hint={t('communityAdmin.members.mostReportedHint')}>
        {reported.error ? (
          <LoadError error={reported.error} />
        ) : reported.loading && !reported.data ? (
          <EmptyState title={t('communityAdmin.loading')} />
        ) : (
          <MostReportedTable data={reported.data} onOpenMember={onOpenMember} />
        )}
      </Section>

      <SanctionsSection permissions={permissions} onOpenMember={onOpenMember} />
    </div>
  );
}

/** Sanctions en cours ou toutes (révision 1 : `GET /admin/community/sanctions`), avec levée. */
function SanctionsSection({
  permissions,
  onOpenMember,
}: Readonly<{ permissions: CommunityPermissions; onOpenMember: (memberId: string) => void }>) {
  const { t } = useLocale();
  const [status, setStatus] = useState<'active' | 'all'>('active');
  const [extra, setExtra] = useState<SanctionWithMember[]>([]);
  const [cursor, setCursor] = useState<string | null>(null);
  const [revoking, setRevoking] = useState<Sanction | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const list = useLoader<Page<SanctionWithMember>>(async () => {
    const page = await communityAdminApi.sanctions(status);
    setExtra([]);
    setCursor(page.nextCursor);
    return page;
  }, [status]);

  async function more() {
    if (!cursor) return;
    try {
      const page = await communityAdminApi.sanctions(status, cursor);
      setExtra((current) => [...current, ...page.items]);
      setCursor(page.nextCursor);
    } catch (e) {
      setError(errorText(t, e));
    }
  }

  return (
    <Section
      title={t('communityAdmin.members.activeSanctions')}
      hint={t('communityAdmin.members.sanctionsHint')}
      actions={
        <div style={{ display: 'flex', gap: 6 }} role="group" aria-label={t('communityAdmin.members.sanctionsFilter')}>
          {(['active', 'all'] as const).map((s) => (
            <Button key={s} size="sm" variant={status === s ? 'primary' : 'secondary'} aria-pressed={status === s} onClick={() => setStatus(s)}>
              {t(`communityAdmin.members.sanctionsStatus.${s}`)}
            </Button>
          ))}
        </div>
      }
    >
      {notice ? <Alert variant="success">{notice}</Alert> : null}
      {error ? <Alert variant="danger">{error}</Alert> : null}
      {list.error ? (
        <LoadError error={list.error} />
      ) : !list.data ? (
        <EmptyState title={t('communityAdmin.loading')} />
      ) : (
        <SanctionsTable
          items={[...list.data.items, ...extra]}
          canRevoke={permissions.sanction}
          onRevoke={setRevoking}
          onOpenMember={onOpenMember}
        />
      )}
      {cursor ? (
        <div>
          <Button size="sm" variant="secondary" onClick={() => void more()}>
            {t('communityAdmin.loadMore')}
          </Button>
        </div>
      ) : null}
      <ReasonDialog
        open={revoking !== null}
        title={t('communityAdmin.revoke.title')}
        description={revoking ? `${enumLabel(t, 'sanction', revoking.kind)} — ${revoking.reason}` : undefined}
        confirmLabel={t('communityAdmin.revoke.cta')}
        onCancel={() => setRevoking(null)}
        onConfirm={async (reason) => {
          if (!revoking) return;
          await communityAdminApi.revokeSanction(revoking.id, reason);
          setRevoking(null);
          setNotice(t('communityAdmin.revoke.done'));
          await list.reload();
        }}
      />
    </Section>
  );
}

export function SanctionsTable({
  items,
  canRevoke,
  onRevoke,
  onOpenMember,
}: Readonly<{
  items: readonly SanctionWithMember[];
  canRevoke: boolean;
  onRevoke: (sanction: Sanction) => void;
  onOpenMember: (memberId: string) => void;
}>) {
  const { t, locale } = useLocale();
  if (items.length === 0) return <EmptyState title={t('communityAdmin.members.noActiveSanctions')} />;
  return (
    <AdminTable
      cols="1.3fr 0.8fr 1.8fr 1fr 0.9fr"
      columns={[
        t('communityAdmin.members.colMember'),
        t('communityAdmin.members.colKind'),
        t('communityAdmin.members.colReason'),
        t('communityAdmin.members.colEnds'),
        t('communityAdmin.members.colState'),
      ]}
    >
      {items.map((s) => (
        <AdminTableRow key={s.id}>
          <div>
            {s.member?.memberId ? (
              <Button size="sm" variant="ghost" onClick={() => onOpenMember(s.member.memberId as string)}>
                {s.member.displayName}
              </Button>
            ) : (
              <CellText primary={s.member?.displayName ?? '—'} />
            )}
          </div>
          <div>
            <Badge variant={SANCTION_VARIANT[s.kind] ?? 'info'}>{enumLabel(t, 'sanction', s.kind)}</Badge>
          </div>
          <CellText primary={s.reason} sub={s.createdBy?.name ? `${s.createdBy.name} · ${formatDate(s.createdAt, locale)}` : formatDate(s.createdAt, locale)} />
          <CellText primary={s.endsAt ? formatDate(s.endsAt, locale) : s.kind === 'ban' ? t('communityAdmin.noEnd') : '—'} muted />
          <div>
            {s.active && s.kind !== 'warning' && canRevoke ? (
              <Button size="sm" variant="secondary" onClick={() => onRevoke(s)}>
                {t('communityAdmin.revoke.cta')}
              </Button>
            ) : s.revokedAt ? (
              <Badge variant="neutral">{t('communityAdmin.history.revoked')}</Badge>
            ) : s.active ? (
              <Badge variant="warning">{t('communityAdmin.history.active')}</Badge>
            ) : (
              <Badge variant="neutral">{t('communityAdmin.history.ended')}</Badge>
            )}
          </div>
        </AdminTableRow>
      ))}
    </AdminTable>
  );
}

export function MostReportedTable({
  data,
  onOpenMember,
}: Readonly<{ data: QueueResponse | null; onOpenMember: (memberId: string) => void }>) {
  const { t } = useLocale();
  const rows = mostReportedMembers(data?.items ?? []);
  if (rows.length === 0) return <EmptyState title={t('communityAdmin.members.noneReported')} />;
  return (
    <AdminTable
      cols="1.6fr 1fr 0.7fr 1fr"
      columns={[
        t('communityAdmin.members.colMember'),
        t('communityAdmin.members.colCountry'),
        t('communityAdmin.members.colReports'),
        t('communityAdmin.members.colRestriction'),
      ]}
    >
      {rows.map((row) => {
        const member = row.member!;
        return (
          <AdminTableRow key={row.key} onSelect={member.memberId ? () => onOpenMember(member.memberId as string) : undefined}>
            <CellText primary={member.displayName} sub={member.badges?.map((b) => enumLabel(t, 'badge', b)).join(', ') || undefined} />
            <CellText primary={member.countryName ?? '—'} muted />
            <div>
              <Badge variant={row.openReportCount > 2 ? 'danger' : 'warning'}>{row.openReportCount}</Badge>
            </div>
            <div>
              {member.restriction ? (
                <Badge variant={SANCTION_VARIANT[member.restriction.kind] ?? 'warning'}>
                  {enumLabel(t, 'sanction', member.restriction.kind)}
                </Badge>
              ) : (
                <span style={hintStyle}>—</span>
              )}
            </div>
          </AdminTableRow>
        );
      })}
    </AdminTable>
  );
}

function MemberDetailPanel({
  memberId,
  permissions,
  onOpenPost,
}: Readonly<{ memberId: string; permissions: CommunityPermissions; onOpenPost: (postId: string) => void }>) {
  const { t } = useLocale();
  const detail = useLoader<AdminMemberDetail>(() => communityAdminApi.member(memberId), [memberId]);
  const [sanctionKind, setSanctionKind] = useState<SanctionKind | null>(null);
  const [revoking, setRevoking] = useState<Sanction | null>(null);
  const [dismissing, setDismissing] = useState(false);
  const [notice, setNotice] = useState<string | null>(null);

  if (detail.error) return <LoadError error={detail.error} />;
  if (!detail.data) return <EmptyState title={t('communityAdmin.loading')} />;
  const member = detail.data;

  return (
    <div style={{ display: 'grid', gap: 12 }}>
      {notice ? <Alert variant="success">{notice}</Alert> : null}
      <MemberDetailView
        member={member}
        permissions={permissions}
        onSanction={setSanctionKind}
        onRevoke={setRevoking}
        onDismissReports={() => setDismissing(true)}
        onOpenPost={onOpenPost}
      />
      <ReasonDialog
        open={dismissing}
        title={fill(t('communityAdmin.memberReports.title'), { member: member.displayName })}
        description={t('communityAdmin.memberReports.body')}
        confirmLabel={t('communityAdmin.memberReports.cta')}
        onCancel={() => setDismissing(false)}
        onConfirm={async (reason) => {
          const result = await communityAdminApi.dismissMemberReports(memberId, reason);
          setDismissing(false);
          setNotice(fill(t('communityAdmin.memberReports.done'), { n: result?.dismissed ?? 0 }));
          await detail.reload();
        }}
      />
      <SanctionDialog
        kind={sanctionKind}
        memberName={member.displayName}
        onCancel={() => setSanctionKind(null)}
        onConfirm={async (body) => {
          await communityAdminApi.sanction(memberId, body);
          setSanctionKind(null);
          setNotice(t(`communityAdmin.sanction.${body.kind}.done`));
          await detail.reload();
        }}
      />
      <ReasonDialog
        open={revoking !== null}
        title={t('communityAdmin.revoke.title')}
        description={revoking ? `${enumLabel(t, 'sanction', revoking.kind)} — ${revoking.reason}` : undefined}
        confirmLabel={t('communityAdmin.revoke.cta')}
        onCancel={() => setRevoking(null)}
        onConfirm={async (reason) => {
          if (!revoking) return;
          await communityAdminApi.revokeSanction(revoking.id, reason);
          setRevoking(null);
          setNotice(t('communityAdmin.revoke.done'));
          await detail.reload();
        }}
      />
    </div>
  );
}

export function MemberDetailView({
  member,
  permissions,
  onSanction,
  onRevoke,
  onDismissReports,
  onOpenPost,
}: Readonly<{
  member: AdminMemberDetail;
  permissions: CommunityPermissions;
  onSanction: (kind: SanctionKind) => void;
  onRevoke: (sanction: Sanction) => void;
  /** Classer sans suite les signalements visant le membre (révision 1). */
  onDismissReports?: () => void;
  onOpenPost: (postId: string) => void;
}>) {
  const { t, locale } = useLocale();
  const sanctions = member.sanctions ?? [];
  return (
    <>
      <Section
        title={member.displayName}
        hint={fill(t('communityAdmin.members.summary'), {
          posts: member.stats?.postsCount ?? 0,
          replies: member.stats?.repliesCount ?? 0,
          helpful: member.stats?.helpfulAnswersCount ?? 0,
          reports: member.openReportCount ?? 0,
        })}
        actions={
          permissions.sanction ? (
            <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
              {(member.openReportCount ?? 0) > 0 && onDismissReports ? (
                <Button size="sm" variant="secondary" onClick={onDismissReports}>
                  {t('communityAdmin.memberReports.cta')}
                </Button>
              ) : null}
              {(['warning', 'read_only', 'ban'] as const).map((kind) => (
                <Button key={kind} size="sm" variant={kind === 'warning' ? 'secondary' : 'dangerOutline'} onClick={() => onSanction(kind)}>
                  {t(`communityAdmin.sanction.${kind}.cta`)}
                </Button>
              ))}
            </div>
          ) : null
        }
      >
        <AuthorLine author={member} canViewIdentity={permissions.viewIdentity} />
        <p style={hintStyle}>
          {member.charterAcceptedAt
            ? fill(t('communityAdmin.members.charterAccepted'), {
                version: member.charterVersion ?? '—',
                date: formatDate(member.charterAcceptedAt, locale),
              })
            : t('communityAdmin.members.charterNotAccepted')}
        </p>
        {member.restriction ? (
          <Alert variant="warning" live={false}>
            {enumLabel(t, 'sanction', member.restriction.kind)} ·{' '}
            {member.restriction.until
              ? `${t('communityAdmin.until')} ${formatDate(member.restriction.until, locale)}`
              : t('communityAdmin.noEnd')}{' '}
            — {member.restriction.reason}
          </Alert>
        ) : null}
      </Section>

      <Section title={t('communityAdmin.members.sanctions')}>
        {sanctions.length === 0 ? (
          <p style={hintStyle}>{t('communityAdmin.members.noSanctions')}</p>
        ) : (
          <AdminTable
            cols="0.8fr 1.8fr 1fr 1fr 0.8fr"
            columns={[
              t('communityAdmin.members.colKind'),
              t('communityAdmin.members.colReason'),
              t('communityAdmin.members.colDate'),
              t('communityAdmin.members.colEnds'),
              t('communityAdmin.members.colState'),
            ]}
          >
            {sanctions.map((s) => (
              <AdminTableRow key={s.id}>
                <div>
                  <Badge variant={SANCTION_VARIANT[s.kind] ?? 'info'}>{enumLabel(t, 'sanction', s.kind)}</Badge>
                </div>
                <CellText primary={s.reason} sub={s.createdBy?.name} />
                <CellText primary={formatDate(s.createdAt, locale)} muted />
                <CellText primary={s.endsAt ? formatDate(s.endsAt, locale) : s.kind === 'ban' ? t('communityAdmin.noEnd') : '—'} muted />
                <div>
                  {s.active && s.kind !== 'warning' && permissions.sanction ? (
                    <Button size="sm" variant="secondary" onClick={() => onRevoke(s)}>
                      {t('communityAdmin.revoke.cta')}
                    </Button>
                  ) : s.revokedAt ? (
                    <Badge variant="neutral">{t('communityAdmin.history.revoked')}</Badge>
                  ) : s.active ? (
                    <Badge variant="warning">{t('communityAdmin.history.active')}</Badge>
                  ) : (
                    <Badge variant="neutral">{t('communityAdmin.history.ended')}</Badge>
                  )}
                </div>
              </AdminTableRow>
            ))}
          </AdminTable>
        )}
      </Section>

      <Section title={t('communityAdmin.members.recentPosts')}>
        <PostsTable items={member.recentPosts ?? []} onOpen={onOpenPost} />
      </Section>

      <Section title={t('communityAdmin.members.recentReplies')}>
        {(member.recentReplies ?? []).length === 0 ? (
          <p style={hintStyle}>{t('communityAdmin.content.noReplies')}</p>
        ) : (
          <ul style={{ listStyle: 'none', margin: 0, padding: 0, display: 'grid', gap: 6 }}>
            {(member.recentReplies ?? []).map((reply) => (
              <li key={reply.id} style={{ display: 'flex', gap: 8, alignItems: 'center', flexWrap: 'wrap', fontSize: 'var(--text-sm)' }}>
                <ContentStatusBadge status={reply.status} />
                <span style={{ flex: 1, minWidth: 0, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                  {plainText(reply)}
                </span>
                <Button size="sm" variant="ghost" onClick={() => onOpenPost(reply.postId)}>
                  {t('communityAdmin.openDiscussion')}
                </Button>
              </li>
            ))}
          </ul>
        )}
      </Section>
    </>
  );
}
