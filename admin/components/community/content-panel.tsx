'use client';

import { FormEvent, useState } from 'react';

import {
  type AdminPost,
  type AdminReply,
  availableContentActions,
  type CommunityPermissions,
  communityAdminApi,
  CONTENT_STATUSES,
  type ContentAction,
  type Page,
  type PostDetail,
  type PostType,
  POST_TYPES,
  plainText,
  REPLY_BODY_MAX,
  type TeamIdentity,
  validateTeamPost,
  validateTeamReply,
} from '../../lib/community-admin';
import { useLocale } from '../locale-provider';
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
  Modal,
  Select,
  Textarea,
} from '../ui';
import { ContentActionDialog } from './action-dialogs';
import {
  AuthorLine,
  ContentStatusBadge,
  enumLabel,
  errorText,
  fill,
  FlagBadges,
  formatDate,
  hintStyle,
  LoadError,
  MentionList,
  ReportsList,
  Section,
  SegmentsView,
  useLoader,
} from './shared';

interface Filters {
  q: string;
  status: string;
  type: string;
}

/** Contenus : recherche, filtres, ouverture d'une discussion (§8.3). */
export function ContentPanel({
  permissions,
  postId,
  onOpenPost,
  onOpenMember,
}: Readonly<{
  permissions: CommunityPermissions;
  postId: string | null;
  onOpenPost: (postId: string | null) => void;
  onOpenMember: (memberId: string) => void;
}>) {
  const { t } = useLocale();
  if (postId) {
    return (
      <div style={{ display: 'grid', gap: 12 }}>
        <div>
          <Button variant="ghost" size="sm" onClick={() => onOpenPost(null)}>
            ← {t('communityAdmin.content.back')}
          </Button>
        </div>
        <PostDetailPanel postId={postId} permissions={permissions} onOpenMember={onOpenMember} />
      </div>
    );
  }
  return <ContentBrowser permissions={permissions} onOpenPost={(id) => onOpenPost(id)} />;
}

function ContentBrowser({
  permissions,
  onOpenPost,
}: Readonly<{ permissions: CommunityPermissions; onOpenPost: (postId: string) => void }>) {
  const { t } = useLocale();
  const [draft, setDraft] = useState<Filters>({ q: '', status: '', type: '' });
  const [filters, setFilters] = useState<Filters>(draft);
  const [extra, setExtra] = useState<AdminPost[]>([]);
  const [cursor, setCursor] = useState<string | null | undefined>(undefined);
  const [composing, setComposing] = useState(false);
  const list = useLoader<Page<AdminPost>>(
    async () => {
      const page = await communityAdminApi.posts(filters);
      setExtra([]);
      setCursor(page.nextCursor);
      return page;
    },
    [filters.q, filters.status, filters.type],
  );
  const [moreError, setMoreError] = useState<string | null>(null);

  async function more() {
    if (!cursor) return;
    try {
      const page = await communityAdminApi.posts({ ...filters, cursor });
      setExtra((current) => [...current, ...page.items]);
      setCursor(page.nextCursor);
    } catch (e) {
      setMoreError(errorText(t, e));
    }
  }

  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setFilters({ ...draft, q: draft.q.trim() });
  }

  const items = [...(list.data?.items ?? []), ...extra];

  return (
    <div style={{ display: 'grid', gap: 12 }}>
      <form onSubmit={submit} style={{ display: 'flex', gap: 10, flexWrap: 'wrap', alignItems: 'flex-end' }}>
        <div style={{ flex: '2 1 240px' }}>
          <Field label={t('communityAdmin.content.search')}>
            {({ id }) => (
              <Input
                id={id}
                type="search"
                value={draft.q}
                placeholder={t('communityAdmin.content.searchPlaceholder')}
                onChange={(e) => setDraft({ ...draft, q: e.target.value })}
              />
            )}
          </Field>
        </div>
        <Field label={t('communityAdmin.content.status')}>
          {({ id }) => (
            <Select id={id} value={draft.status} onChange={(e) => setDraft({ ...draft, status: e.target.value })}>
              <option value="">{t('communityAdmin.all')}</option>
              {CONTENT_STATUSES.map((s) => (
                <option key={s} value={s}>
                  {enumLabel(t, 'status', s)}
                </option>
              ))}
            </Select>
          )}
        </Field>
        <Field label={t('communityAdmin.content.type')}>
          {({ id }) => (
            <Select id={id} value={draft.type} onChange={(e) => setDraft({ ...draft, type: e.target.value })}>
              <option value="">{t('communityAdmin.all')}</option>
              {POST_TYPES.map((type) => (
                <option key={type} value={type}>
                  {enumLabel(t, 'postType', type)}
                </option>
              ))}
            </Select>
          )}
        </Field>
        <Button type="submit">{t('communityAdmin.content.searchCta')}</Button>
        {permissions.moderate ? (
          <Button variant="secondary" onClick={() => setComposing(true)}>
            {t('communityAdmin.teamPost.open')}
          </Button>
        ) : null}
      </form>
      {moreError ? <Alert variant="danger">{moreError}</Alert> : null}
      {list.error ? (
        <LoadError error={list.error} />
      ) : list.loading && !list.data ? (
        <EmptyState title={t('communityAdmin.loading')} />
      ) : (
        <PostsTable items={items} onOpen={onOpenPost} />
      )}
      {cursor ? (
        <div>
          <Button variant="secondary" size="sm" onClick={() => void more()}>
            {t('communityAdmin.loadMore')}
          </Button>
        </div>
      ) : null}
      <TeamPostModal
        open={composing}
        onClose={() => setComposing(false)}
        onCreated={(post) => {
          setComposing(false);
          onOpenPost(post.id);
        }}
      />
    </div>
  );
}

export function PostsTable({ items, onOpen }: Readonly<{ items: readonly AdminPost[]; onOpen: (id: string) => void }>) {
  const { t, locale } = useLocale();
  if (items.length === 0) return <EmptyState title={t('communityAdmin.content.empty')} />;
  return (
    <AdminTable
      cols="2.2fr 1fr 0.8fr 0.6fr 0.9fr"
      columns={[
        t('communityAdmin.content.colPost'),
        t('communityAdmin.content.colAuthor'),
        t('communityAdmin.content.colStatus'),
        t('communityAdmin.content.colReplies'),
        t('communityAdmin.content.colDate'),
      ]}
    >
      {items.map((post) => (
        <AdminTableRow key={post.id} onSelect={() => onOpen(post.id)}>
          <CellText
            primary={
              <>
                {post.isPinned ? '📌 ' : ''}
                {post.title}
              </>
            }
            sub={`${enumLabel(t, 'postType', String(post.type))}${post.hasVerifiedAnswer ? ` · ✓ ${t('communityAdmin.verified')}` : ''}${
              post.openReportCount ? ` · ${fill(t('communityAdmin.queue.reports'), { n: post.openReportCount })}` : ''
            }`}
          />
          <CellText primary={post.author.displayName} sub={post.author.countryName ?? undefined} />
          <div>
            <ContentStatusBadge status={post.status} />
          </div>
          <CellText primary={String(post.replyCount ?? 0)} muted />
          <CellText primary={formatDate(post.createdAt, locale)} muted />
        </AdminTableRow>
      ))}
    </AdminTable>
  );
}

type Target = { kind: 'post'; id: string } | { kind: 'reply'; id: string };

/** Une discussion complète, tous états, avec les actions de l'équipe. */
function PostDetailPanel({
  postId,
  permissions,
  onOpenMember,
}: Readonly<{ postId: string; permissions: CommunityPermissions; onOpenMember: (memberId: string) => void }>) {
  const { t } = useLocale();
  const detail = useLoader<PostDetail>(() => communityAdminApi.post(postId), [postId]);
  const [notice, setNotice] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [pending, setPending] = useState<{ target: Target; action: ContentAction } | null>(null);
  const [busy, setBusy] = useState<string | null>(null);

  async function run(label: string, fn: () => Promise<unknown>, success: string) {
    setBusy(label);
    setError(null);
    setNotice(null);
    try {
      await fn();
      setNotice(success);
      await detail.reload();
    } catch (e) {
      setError(errorText(t, e));
    } finally {
      setBusy(null);
    }
  }

  if (detail.error) return <LoadError error={detail.error} />;
  if (!detail.data) return <EmptyState title={t('communityAdmin.loading')} />;

  return (
    <div style={{ display: 'grid', gap: 12 }}>
      {notice ? <Alert variant="success">{notice}</Alert> : null}
      {error ? <Alert variant="danger">{error}</Alert> : null}
      <PostDetailView
        detail={detail.data}
        permissions={permissions}
        busy={busy}
        onOpenMember={onOpenMember}
        onAction={(target, action) => setPending({ target, action })}
        onPin={(pinned) =>
          void run('pin', () => communityAdminApi.setPinned(postId, pinned), t(pinned ? 'communityAdmin.pin.done' : 'communityAdmin.pin.undone'))
        }
        onVerify={(reply, verified) =>
          void run(
            `verify-${reply.id}`,
            () => communityAdminApi.setVerified(reply.id, verified),
            t(verified ? 'communityAdmin.verify.done' : 'communityAdmin.verify.undone'),
          )
        }
      />
      {permissions.moderate ? (
        <TeamReplyForm
          postId={postId}
          onPosted={async () => {
            setNotice(t('communityAdmin.teamReply.done'));
            await detail.reload();
          }}
        />
      ) : null}
      <ContentActionDialog
        action={pending?.action ?? null}
        targetLabel={pending?.target.kind === 'reply' ? t('communityAdmin.theReply') : t('communityAdmin.thePost')}
        onCancel={() => setPending(null)}
        onConfirm={async (input) => {
          if (!pending) return;
          if (pending.target.kind === 'post') await communityAdminApi.postAction(pending.target.id, input);
          else await communityAdminApi.replyAction(pending.target.id, input);
          setPending(null);
          setNotice(t(`communityAdmin.action.${input.action}.done`));
          await detail.reload();
        }}
      />
    </div>
  );
}

export function PostDetailView({
  detail,
  permissions,
  busy,
  onOpenMember,
  onAction,
  onPin,
  onVerify,
}: Readonly<{
  detail: PostDetail;
  permissions: CommunityPermissions;
  busy: string | null;
  onOpenMember: (memberId: string) => void;
  onAction: (target: Target, action: ContentAction) => void;
  onPin: (pinned: boolean) => void;
  onVerify: (reply: AdminReply, verified: boolean) => void;
}>) {
  const { t, locale } = useLocale();
  const { post, replies, reports, log } = detail;
  const actions = permissions.moderate ? availableContentActions(post) : [];
  return (
    <>
      <Section
        title={post.title}
        hint={`${enumLabel(t, 'postType', String(post.type))} · ${formatDate(post.createdAt, locale)}`}
        actions={
          permissions.moderate && post.status === 'visible' ? (
            <Button size="sm" variant="secondary" loading={busy === 'pin'} disabled={busy !== null} onClick={() => onPin(!post.isPinned)}>
              {post.isPinned ? t('communityAdmin.pin.unpin') : t('communityAdmin.pin.pin')}
            </Button>
          ) : null
        }
      >
        <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', alignItems: 'center' }}>
          <ContentStatusBadge status={post.status} />
          {post.statusReason ? <Badge variant="warning">{enumLabel(t, 'statusReason', post.statusReason)}</Badge> : null}
          {post.isPinned ? <Badge variant="brand">{t('communityAdmin.pin.pinned')}</Badge> : null}
          {post.hasVerifiedAnswer ? <Badge variant="success">✓ {t('communityAdmin.verified')}</Badge> : null}
          <FlagBadges flags={post.filterFlags} />
        </div>
        <AuthorLine author={post.author} canViewIdentity={permissions.viewIdentity} onOpenMember={onOpenMember} />
        <SegmentsView segments={post.segments} fallback={plainText(post)} />
        <MentionList mentions={post.mentions} />
        {post.hashtags?.length ? (
          <p style={hintStyle}>{post.hashtags.map((h) => `#${h.display}`).join(' ')}</p>
        ) : null}
        {actions.length ? (
          <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
            {actions.map((action) => (
              <Button
                key={action}
                size="sm"
                variant={action === 'restore' ? 'success' : action === 'dismiss_reports' ? 'secondary' : 'danger'}
                onClick={() => onAction({ kind: 'post', id: post.id }, action)}
              >
                {t(`communityAdmin.action.${action}.cta`)}
              </Button>
            ))}
          </div>
        ) : null}
      </Section>

      <Section title={fill(t('communityAdmin.content.replies'), { n: replies.length })}>
        {replies.length === 0 ? (
          <p style={hintStyle}>{t('communityAdmin.content.noReplies')}</p>
        ) : (
          <ol style={{ listStyle: 'none', margin: 0, padding: 0, display: 'grid', gap: 10 }}>
            {replies.map((reply) => (
              <ReplyItem
                key={reply.id}
                reply={reply}
                permissions={permissions}
                busy={busy}
                onOpenMember={onOpenMember}
                onAction={(action) => onAction({ kind: 'reply', id: reply.id }, action)}
                onVerify={(verified) => onVerify(reply, verified)}
              />
            ))}
          </ol>
        )}
      </Section>

      <Section title={t('communityAdmin.content.reports')}>
        <ReportsList reports={reports} />
      </Section>

      <Section title={t('communityAdmin.content.log')}>
        {log.length === 0 ? (
          <p style={hintStyle}>{t('communityAdmin.log.empty')}</p>
        ) : (
          <ul style={{ margin: 0, paddingLeft: 18, fontSize: 'var(--text-sm)', display: 'grid', gap: 2 }}>
            {log.map((entry) => (
              <li key={entry.id}>
                {formatDate(entry.createdAt, locale)} · <strong>{enumLabel(t, 'logAction', entry.action)}</strong> ·{' '}
                {entry.moderatorName ?? '—'}
                {entry.reason ? ` — ${entry.reason}` : ''}
              </li>
            ))}
          </ul>
        )}
      </Section>
    </>
  );
}

function ReplyItem({
  reply,
  permissions,
  busy,
  onOpenMember,
  onAction,
  onVerify,
}: Readonly<{
  reply: AdminReply;
  permissions: CommunityPermissions;
  busy: string | null;
  onOpenMember: (memberId: string) => void;
  onAction: (action: ContentAction) => void;
  onVerify: (verified: boolean) => void;
}>) {
  const { t, locale } = useLocale();
  const actions = permissions.moderate ? availableContentActions(reply) : [];
  return (
    <li
      data-reply-id={reply.id}
      style={{
        border: `1px solid ${reply.isVerified ? 'var(--success-fg)' : 'var(--border)'}`,
        borderRadius: 12,
        padding: 12,
        display: 'grid',
        gap: 8,
        opacity: reply.status === 'deleted' ? 0.6 : 1,
      }}
    >
      <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', alignItems: 'center' }}>
        {reply.isVerified ? <Badge variant="success">✓ {t('communityAdmin.verifiedAnswer')}</Badge> : null}
        <ContentStatusBadge status={reply.status} />
        {reply.statusReason ? <Badge variant="warning">{enumLabel(t, 'statusReason', reply.statusReason)}</Badge> : null}
        <FlagBadges flags={reply.filterFlags} />
        {reply.openReportCount ? (
          <Badge variant="warning">{fill(t('communityAdmin.queue.reports'), { n: reply.openReportCount })}</Badge>
        ) : null}
        <span style={hintStyle}>{formatDate(reply.createdAt, locale)}</span>
      </div>
      <AuthorLine author={reply.author} canViewIdentity={permissions.viewIdentity} onOpenMember={onOpenMember} />
      <SegmentsView segments={reply.segments} fallback={reply.body} />
      <MentionList mentions={reply.mentions} />
      {permissions.moderate ? (
        <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
          {reply.status === 'visible' || reply.isVerified ? (
            <Button
              size="sm"
              variant={reply.isVerified ? 'secondary' : 'success'}
              loading={busy === `verify-${reply.id}`}
              disabled={busy !== null}
              onClick={() => onVerify(!reply.isVerified)}
            >
              {reply.isVerified ? t('communityAdmin.verify.remove') : t('communityAdmin.verify.mark')}
            </Button>
          ) : null}
          {actions.map((action) => (
            <Button
              key={action}
              size="sm"
              variant={action === 'restore' ? 'success' : action === 'dismiss_reports' ? 'secondary' : 'dangerOutline'}
              onClick={() => onAction(action)}
            >
              {t(`communityAdmin.action.${action}.cta`)}
            </Button>
          ))}
        </div>
      ) : null}
    </li>
  );
}

/** Réponse au nom de l'équipe (§8.6) : jamais filtrée, notifie l'auteur et les abonnés. */
export function TeamReplyForm({ postId, onPosted }: Readonly<{ postId: string; onPosted: () => Promise<void> }>) {
  const { t } = useLocale();
  const [body, setBody] = useState('');
  const [as, setAs] = useState<TeamIdentity>('kpb_team');
  const [verified, setVerified] = useState(false);
  const [touched, setTouched] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const bodyError = validateTeamReply(body);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setTouched(true);
    if (bodyError) return;
    setBusy(true);
    setError(null);
    try {
      await communityAdminApi.teamReply(postId, { body: body.trim(), as, ...(verified ? { verified: true } : {}) });
      setBody('');
      setVerified(false);
      setTouched(false);
      await onPosted();
    } catch (e) {
      setError(errorText(t, e));
    } finally {
      setBusy(false);
    }
  }

  return (
    <Section title={t('communityAdmin.teamReply.title')} hint={t('communityAdmin.teamReply.hint')}>
      <form onSubmit={submit} style={{ display: 'grid', gap: 10 }}>
        {error ? <Alert variant="danger">{error}</Alert> : null}
        <Field label={t('communityAdmin.teamReply.as')}>
          {({ id }) => (
            <Select id={id} value={as} onChange={(e) => setAs(e.target.value as TeamIdentity)}>
              <option value="kpb_team">{t('communityAdmin.enum.badge.kpb_team')}</option>
              <option value="kpb_advisor">{t('communityAdmin.teamReply.asAdvisor')}</option>
            </Select>
          )}
        </Field>
        <Field
          label={t('communityAdmin.teamReply.body')}
          error={touched && bodyError ? t(`communityAdmin.errors.${bodyError}`) : undefined}
        >
          {({ id, invalid }) => (
            <Textarea
              id={id}
              required
              invalid={invalid}
              maxLength={REPLY_BODY_MAX}
              value={body}
              placeholder={t('communityAdmin.teamReply.placeholder')}
              onChange={(e) => setBody(e.target.value)}
            />
          )}
        </Field>
        <label style={{ display: 'flex', gap: 8, alignItems: 'center', fontSize: 'var(--text-sm)' }}>
          <input type="checkbox" checked={verified} onChange={(e) => setVerified(e.target.checked)} />
          {t('communityAdmin.teamReply.verified')}
        </label>
        <div>
          <Button type="submit" loading={busy} disabled={touched && Boolean(bodyError)}>
            {t('communityAdmin.teamReply.submit')}
          </Button>
        </div>
      </form>
    </Section>
  );
}

/** Publication de l'équipe (§8.6) — point d'entrée du futur bot « Vérif ». */
function TeamPostModal({
  open,
  onClose,
  onCreated,
}: Readonly<{ open: boolean; onClose: () => void; onCreated: (post: AdminPost) => void }>) {
  const { t } = useLocale();
  const [type, setType] = useState<PostType>('advice');
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [as, setAs] = useState<TeamIdentity>('kpb_team');
  const [pinned, setPinned] = useState(false);
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [busy, setBusy] = useState(false);
  const [serverError, setServerError] = useState<string | null>(null);

  async function submit() {
    const found = validateTeamPost({ title, body });
    setErrors(found);
    if (Object.keys(found).length) return;
    setBusy(true);
    setServerError(null);
    try {
      const post = await communityAdminApi.teamPost({ type, title: title.trim(), body: body.trim(), as, ...(pinned ? { pinned: true } : {}) });
      setTitle('');
      setBody('');
      setPinned(false);
      onCreated(post);
    } catch (e) {
      setServerError(errorText(t, e));
    } finally {
      setBusy(false);
    }
  }

  return (
    <Modal
      open={open}
      title={t('communityAdmin.teamPost.title')}
      onClose={onClose}
      busy={busy}
      size="lg"
      footer={
        <>
          <Button variant="secondary" onClick={onClose} disabled={busy}>
            {t('communityAdmin.cancel')}
          </Button>
          <Button onClick={() => void submit()} loading={busy}>
            {t('communityAdmin.teamPost.submit')}
          </Button>
        </>
      }
    >
      <div style={{ display: 'grid', gap: 10 }}>
        {serverError ? <Alert variant="danger">{serverError}</Alert> : null}
        <div style={{ display: 'grid', gap: 10, gridTemplateColumns: '1fr 1fr' }}>
          <Field label={t('communityAdmin.content.type')}>
            {({ id }) => (
              <Select id={id} value={type} onChange={(e) => setType(e.target.value as PostType)}>
                {POST_TYPES.map((p) => (
                  <option key={p} value={p}>
                    {enumLabel(t, 'postType', p)}
                  </option>
                ))}
              </Select>
            )}
          </Field>
          <Field label={t('communityAdmin.teamReply.as')}>
            {({ id }) => (
              <Select id={id} value={as} onChange={(e) => setAs(e.target.value as TeamIdentity)}>
                <option value="kpb_team">{t('communityAdmin.enum.badge.kpb_team')}</option>
                <option value="kpb_advisor">{t('communityAdmin.teamReply.asAdvisor')}</option>
              </Select>
            )}
          </Field>
        </div>
        <Field label={t('communityAdmin.teamPost.titleLabel')} error={errors.title ? t(`communityAdmin.errors.${errors.title}`) : undefined}>
          {({ id, invalid }) => <Input id={id} invalid={invalid} value={title} onChange={(e) => setTitle(e.target.value)} />}
        </Field>
        <Field label={t('communityAdmin.teamPost.bodyLabel')} error={errors.body ? t(`communityAdmin.errors.${errors.body}`) : undefined}>
          {({ id, invalid }) => <Textarea id={id} invalid={invalid} value={body} onChange={(e) => setBody(e.target.value)} />}
        </Field>
        <p style={hintStyle}>{t('communityAdmin.teamPost.mentionHint')}</p>
        <label style={{ display: 'flex', gap: 8, alignItems: 'center', fontSize: 'var(--text-sm)' }}>
          <input type="checkbox" checked={pinned} onChange={(e) => setPinned(e.target.checked)} />
          {t('communityAdmin.teamPost.pinned')}
        </label>
      </div>
    </Modal>
  );
}
