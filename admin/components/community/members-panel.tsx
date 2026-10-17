'use client';

import { FormEvent, useState } from 'react';

import {
  type AdminMemberDetail,
  type CommunityPermissions,
  communityAdminApi,
  type QueueResponse,
  mostReportedMembers,
  plainText,
  type Sanction,
  SANCTION_VARIANT,
  type SanctionKind,
} from '../../lib/community-admin';
import { useLocale } from '../locale-provider';
import { AdminTable, AdminTableRow, Alert, Badge, Button, CellText, EmptyState, Field, Input } from '../ui';
import { ReasonDialog, SanctionDialog } from './action-dialogs';
import { PostsTable } from './content-panel';
import {
  AuthorLine,
  ContentStatusBadge,
  enumLabel,
  fill,
  formatDate,
  hintStyle,
  LoadError,
  Section,
  SoonState,
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
  return <MembersOverview onOpenMember={(id) => onOpenMember(id)} />;
}

function MembersOverview({ onOpenMember }: Readonly<{ onOpenMember: (memberId: string) => void }>) {
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

      <Section title={t('communityAdmin.members.activeSanctions')}>
        <SoonState title={t('communityAdmin.members.activeSanctionsSoon')} description={t('communityAdmin.members.activeSanctionsSoonBody')} />
      </Section>
    </div>
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
        onOpenPost={onOpenPost}
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
  onOpenPost,
}: Readonly<{
  member: AdminMemberDetail;
  permissions: CommunityPermissions;
  onSanction: (kind: SanctionKind) => void;
  onRevoke: (sanction: Sanction) => void;
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
