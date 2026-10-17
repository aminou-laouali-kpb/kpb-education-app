'use client';

import { useCallback, useEffect, useMemo, useState } from 'react';

import {
  type AdminMemberDetail,
  availableContentActions,
  type CommunityPermissions,
  communityAdminApi,
  type ContentAction,
  formatHours,
  isOverdue,
  plainText,
  QUEUE_KINDS,
  type QueueItem,
  type QueueKind,
  queueContent,
  queueMemberId,
  type QueueResponse,
  type QueueShortcut,
  type QueueSort,
  type SanctionKind,
  SANCTION_VARIANT,
  SHORTCUT_KEYS,
  shortcutFor,
  sortQueue,
  urgencyScore,
} from '../../lib/community-admin';
import { useLocale } from '../locale-provider';
import { Alert, Badge, Button, EmptyState } from '../ui';
import { ContentActionDialog, SanctionDialog } from './action-dialogs';
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
  panelCardStyle,
  ReportsList,
  SegmentsView,
  useLoader,
} from './shared';

/**
 * File de modération (§8.2) : contenus masqués automatiquement, contenus et
 * membres signalés. Liste à gauche, aperçu et actions à droite ; chaque
 * action ouvre une confirmation avec motif obligatoire.
 */
export function ModerationQueue({
  permissions,
  onOpenPost,
  onOpenMember,
}: Readonly<{
  permissions: CommunityPermissions;
  onOpenPost: (postId: string) => void;
  onOpenMember: (memberId: string) => void;
}>) {
  const { t } = useLocale();
  const [kind, setKind] = useState<QueueKind>('all');
  const [sort, setSort] = useState<QueueSort>('oldest');
  const [selectedKey, setSelectedKey] = useState<string | null>(null);
  const [extra, setExtra] = useState<QueueItem[]>([]);
  const [nextCursor, setNextCursor] = useState<string | null>(null);
  const [loadingMore, setLoadingMore] = useState(false);
  const [notice, setNotice] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);
  const [contentAction, setContentAction] = useState<ContentAction | null>(null);
  const [sanctionKind, setSanctionKind] = useState<SanctionKind | null>(null);

  const queue = useLoader<QueueResponse>(() => communityAdminApi.queue(kind), [kind]);

  useEffect(() => {
    setExtra([]);
    setNextCursor(queue.data?.nextCursor ?? null);
  }, [queue.data]);

  const items = useMemo(
    () => sortQueue([...(queue.data?.items ?? []), ...extra], sort),
    [queue.data, extra, sort],
  );
  const selected = items.find((item) => item.key === selectedKey) ?? items[0] ?? null;
  const memberId = selected ? queueMemberId(selected) : null;

  const history = useLoader<AdminMemberDetail>(
    () => communityAdminApi.member(memberId as string),
    [memberId],
    Boolean(memberId),
  );

  async function loadMore() {
    if (!nextCursor) return;
    setLoadingMore(true);
    try {
      const page = await communityAdminApi.queue(kind, nextCursor);
      setExtra((current) => [...current, ...page.items]);
      setNextCursor(page.nextCursor);
    } catch (e) {
      setActionError(errorText(t, e));
    } finally {
      setLoadingMore(false);
    }
  }

  const move = useCallback(
    (delta: number) => {
      if (items.length === 0) return;
      const index = Math.max(0, items.findIndex((item) => item.key === selected?.key));
      const next = items[Math.min(items.length - 1, Math.max(0, index + delta))];
      setSelectedKey(next.key);
    },
    [items, selected],
  );

  const trigger = useCallback(
    (shortcut: QueueShortcut) => {
      if (shortcut === 'next') return move(1);
      if (shortcut === 'previous') return move(-1);
      if (!selected) return;
      if (shortcut === 'warning' || shortcut === 'read_only' || shortcut === 'ban') {
        if (permissions.sanction && queueMemberId(selected)) setSanctionKind(shortcut);
        return;
      }
      const content = queueContent(selected);
      if (content && availableContentActions(content.content).includes(shortcut)) {
        setContentAction(shortcut);
      }
    },
    [move, permissions.sanction, selected],
  );

  useEffect(() => {
    function onKey(event: KeyboardEvent) {
      if (contentAction || sanctionKind) return;
      // Une boîte de dialogue (autre que les nôtres) est ouverte : on s'abstient.
      if (document.querySelector('[role="dialog"]')) return;
      const target = event.target as HTMLElement | null;
      const shortcut = shortcutFor({
        key: event.key,
        ctrlKey: event.ctrlKey,
        metaKey: event.metaKey,
        altKey: event.altKey,
        targetTag: target?.tagName ?? null,
        targetEditable: Boolean(target?.isContentEditable),
      });
      if (!shortcut) return;
      event.preventDefault();
      trigger(shortcut);
    }
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [contentAction, sanctionKind, trigger]);

  async function afterAction(message: string) {
    setContentAction(null);
    setSanctionKind(null);
    setNotice(message);
    setActionError(null);
    // La ligne traitée sort de la file : on garde la position (élément suivant).
    const index = items.findIndex((item) => item.key === selected?.key);
    const following = items[index + 1] ?? items[index - 1] ?? null;
    setSelectedKey(following?.key ?? null);
    await queue.reload();
    if (memberId) void history.reload();
  }

  const content = selected ? queueContent(selected) : null;
  const memberName =
    selected?.member?.displayName ?? content?.content.author.displayName ?? t('communityAdmin.member');

  return (
    <div style={{ display: 'grid', gap: 12 }}>
      {notice ? <Alert variant="success">{notice}</Alert> : null}
      {actionError ? <Alert variant="danger">{actionError}</Alert> : null}
      <QueueToolbar
        kind={kind}
        sort={sort}
        counts={queue.data?.counts ?? null}
        onKind={(next) => {
          setKind(next);
          setSelectedKey(null);
        }}
        onSort={setSort}
      />
      {queue.error ? (
        <LoadError error={queue.error} />
      ) : queue.loading && !queue.data ? (
        <EmptyState title={t('communityAdmin.loading')} />
      ) : (
        <div style={{ display: 'grid', gap: 12, gridTemplateColumns: 'minmax(280px, 1fr) minmax(320px, 1.4fr)', alignItems: 'start' }}>
          <div style={{ display: 'grid', gap: 8 }}>
            <QueueList items={items} selectedKey={selected?.key ?? null} onSelect={setSelectedKey} />
            {nextCursor ? (
              <Button variant="secondary" size="sm" loading={loadingMore} onClick={() => void loadMore()}>
                {t('communityAdmin.loadMore')}
              </Button>
            ) : null}
          </div>
          {selected ? (
            <QueuePreview
              item={selected}
              permissions={permissions}
              history={history.data}
              historyLoading={history.loading}
              onContentAction={setContentAction}
              onSanction={setSanctionKind}
              onOpenPost={onOpenPost}
              onOpenMember={onOpenMember}
            />
          ) : null}
        </div>
      )}
      <ShortcutHelp />

      <ContentActionDialog
        action={contentAction}
        targetLabel={content?.kind === 'reply' ? t('communityAdmin.theReply') : t('communityAdmin.thePost')}
        onCancel={() => setContentAction(null)}
        onConfirm={async (input) => {
          if (!content) return;
          if (content.kind === 'post') await communityAdminApi.postAction(content.content.id, input);
          else await communityAdminApi.replyAction(content.content.id, input);
          await afterAction(t(`communityAdmin.action.${input.action}.done`));
        }}
      />
      <SanctionDialog
        kind={sanctionKind}
        memberName={memberName}
        onCancel={() => setSanctionKind(null)}
        onConfirm={async (body) => {
          if (!memberId) return;
          await communityAdminApi.sanction(memberId, body);
          await afterAction(t(`communityAdmin.sanction.${body.kind}.done`));
        }}
      />
    </div>
  );
}

export function QueueToolbar({
  kind,
  sort,
  counts,
  onKind,
  onSort,
}: Readonly<{
  kind: QueueKind;
  sort: QueueSort;
  counts: QueueResponse['counts'] | null;
  onKind: (kind: QueueKind) => void;
  onSort: (sort: QueueSort) => void;
}>) {
  const { t } = useLocale();
  const countOf = (k: QueueKind): number | null => {
    if (!counts) return null;
    if (k === 'auto_hidden') return counts.autoHidden;
    if (k === 'reported') return counts.reported;
    if (k === 'members') return counts.members;
    return null;
  };
  return (
    <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', alignItems: 'center', justifyContent: 'space-between' }}>
      <nav style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }} aria-label={t('communityAdmin.queue.kinds')}>
        {QUEUE_KINDS.map((k) => {
          const n = countOf(k);
          return (
            <Button key={k} size="sm" variant={kind === k ? 'primary' : 'secondary'} aria-pressed={kind === k} onClick={() => onKind(k)}>
              {t(`communityAdmin.queue.kind.${k}`)}
              {n !== null ? ` (${n})` : ''}
            </Button>
          );
        })}
      </nav>
      <div style={{ display: 'flex', gap: 6 }} role="group" aria-label={t('communityAdmin.queue.sortLabel')}>
        {(['oldest', 'urgency'] as const).map((s) => (
          <Button key={s} size="sm" variant={sort === s ? 'primary' : 'ghost'} aria-pressed={sort === s} onClick={() => onSort(s)}>
            {t(`communityAdmin.queue.sort.${s}`)}
          </Button>
        ))}
      </div>
    </div>
  );
}

/** Liste de la file : une carte par élément, motif principal et attente. */
export function QueueList({
  items,
  selectedKey,
  onSelect,
}: Readonly<{ items: readonly QueueItem[]; selectedKey: string | null; onSelect: (key: string) => void }>) {
  const { t, locale } = useLocale();
  if (items.length === 0) {
    return <EmptyState title={t('communityAdmin.queue.emptyTitle')} description={t('communityAdmin.queue.emptyBody')} />;
  }
  return (
    <ul style={{ listStyle: 'none', margin: 0, padding: 0, display: 'grid', gap: 6 }} aria-label={t('communityAdmin.queue.listLabel')}>
      {items.map((item) => {
        const content = queueContent(item);
        const isSelected = item.key === selectedKey;
        const title =
          content?.kind === 'post'
            ? content.content.title
            : content?.kind === 'reply'
              ? `${t('communityAdmin.replyOn')} « ${item.parentPost?.title ?? '…'} »`
              : (item.member?.displayName ?? t('communityAdmin.member'));
        const flags = content?.content.filterFlags ?? [];
        const overdue = isOverdue(item);
        return (
          <li key={item.key}>
            <button
              type="button"
              data-queue-key={item.key}
              aria-pressed={isSelected}
              onClick={() => onSelect(item.key)}
              style={{
                ...panelCardStyle,
                width: '100%',
                textAlign: 'left',
                cursor: 'pointer',
                padding: 12,
                display: 'grid',
                gap: 6,
                borderColor: isSelected ? 'var(--brand)' : 'var(--border)',
                boxShadow: isSelected ? '0 0 0 2px var(--brand-soft)' : undefined,
              }}
            >
              <span style={{ display: 'flex', gap: 6, flexWrap: 'wrap', alignItems: 'center' }}>
                <Badge variant="neutral">{enumLabel(t, 'target', item.targetType)}</Badge>
                {content ? <ContentStatusBadge status={content.content.status} /> : null}
                {item.openReportCount > 0 ? (
                  <Badge variant={item.openReportCount > 1 ? 'danger' : 'warning'}>
                    {fill(t('communityAdmin.queue.reports'), { n: item.openReportCount })}
                  </Badge>
                ) : null}
                <Badge variant={overdue ? 'danger' : 'neutral'}>
                  {overdue ? '⚠ ' : ''}
                  {fill(t('communityAdmin.queue.waiting'), { h: formatHours(item.waitingHours, locale) })}
                </Badge>
              </span>
              <strong style={{ fontSize: 'var(--text-sm)', overflow: 'hidden', textOverflow: 'ellipsis' }}>{title}</strong>
              {content?.content.statusReason ? (
                <span style={hintStyle}>
                  {enumLabel(t, 'statusReason', content.content.statusReason)}
                  {flags.length ? ` · ${flags.map((f) => enumLabel(t, 'flag', f)).join(', ')}` : ''}
                </span>
              ) : null}
              <span style={hintStyle} title={t('communityAdmin.queue.urgencyHint')}>
                {fill(t('communityAdmin.queue.urgency'), { n: urgencyScore(item) })} · {formatDate(item.flaggedAt, locale)}
              </span>
            </button>
          </li>
        );
      })}
    </ul>
  );
}

/** Aperçu d'un élément : contenu, mentions, signalements, auteur, actions. */
export function QueuePreview({
  item,
  permissions,
  history,
  historyLoading,
  onContentAction,
  onSanction,
  onOpenPost,
  onOpenMember,
}: Readonly<{
  item: QueueItem;
  permissions: CommunityPermissions;
  history: AdminMemberDetail | null;
  historyLoading: boolean;
  onContentAction: (action: ContentAction) => void;
  onSanction: (kind: SanctionKind) => void;
  onOpenPost: (postId: string) => void;
  onOpenMember: (memberId: string) => void;
}>) {
  const { t, locale } = useLocale();
  const content = queueContent(item);
  const author = content?.content.author ?? item.member;
  const memberId = queueMemberId(item);
  const postId = content?.kind === 'post' ? content.content.id : content?.kind === 'reply' ? content.content.postId : null;
  const actions = content && permissions.moderate ? availableContentActions(content.content) : [];
  const shortcutOf = (action: string) => SHORTCUT_KEYS.find(([, a]) => a === action)?.[0];

  return (
    <article style={{ ...panelCardStyle, display: 'grid', gap: 12 }} aria-label={t('communityAdmin.queue.previewLabel')}>
      {content ? (
        <>
          <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', alignItems: 'center' }}>
            <ContentStatusBadge status={content.content.status} />
            {content.content.statusReason ? (
              <Badge variant="warning">{enumLabel(t, 'statusReason', content.content.statusReason)}</Badge>
            ) : null}
            <FlagBadges flags={content.content.filterFlags} />
          </div>
          {content.kind === 'post' ? (
            <h3 style={{ margin: 0, fontSize: 'var(--text-lg)' }}>
              <Badge variant="neutral">{enumLabel(t, 'postType', String(content.content.type))}</Badge> {content.content.title}
            </h3>
          ) : (
            <p style={hintStyle}>
              {t('communityAdmin.replyOn')} « {item.parentPost?.title ?? '…'} »
              {item.parentPost ? <> · <ContentStatusBadge status={item.parentPost.status} /></> : null}
            </p>
          )}
          <SegmentsView segments={content.content.segments} fallback={plainText(content.content)} />
          <MentionList mentions={content.content.mentions} />
          <span style={hintStyle}>{formatDate(content.content.createdAt, locale)}</span>
        </>
      ) : null}

      {author ? <AuthorLine author={author} canViewIdentity={permissions.viewIdentity} onOpenMember={onOpenMember} /> : null}

      <div style={{ display: 'grid', gap: 6 }}>
        <strong style={{ fontSize: 'var(--text-sm)' }}>
          {fill(t('communityAdmin.queue.openReports'), { n: item.openReportCount })}
        </strong>
        <ReportsList reports={item.reports} />
      </div>

      {memberId ? <AuthorHistory history={history} loading={historyLoading} /> : null}

      <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
        {actions.map((action) => (
          <Button
            key={action}
            size="sm"
            variant={action === 'restore' ? 'success' : action === 'dismiss_reports' ? 'secondary' : 'danger'}
            aria-keyshortcuts={shortcutOf(action)}
            onClick={() => onContentAction(action)}
          >
            {t(`communityAdmin.action.${action}.cta`)}
            {shortcutOf(action) ? <kbd style={{ marginLeft: 6, opacity: 0.7 }}>{shortcutOf(action)}</kbd> : null}
          </Button>
        ))}
        {permissions.sanction && memberId
          ? (['warning', 'read_only', 'ban'] as const).map((kind) => (
              <Button
                key={kind}
                size="sm"
                variant={kind === 'warning' ? 'secondary' : 'dangerOutline'}
                aria-keyshortcuts={shortcutOf(kind)}
                onClick={() => onSanction(kind)}
              >
                {t(`communityAdmin.sanction.${kind}.cta`)}
                {shortcutOf(kind) ? <kbd style={{ marginLeft: 6, opacity: 0.7 }}>{shortcutOf(kind)}</kbd> : null}
              </Button>
            ))
          : null}
        {postId ? (
          <Button size="sm" variant="ghost" onClick={() => onOpenPost(postId)}>
            {t('communityAdmin.openDiscussion')}
          </Button>
        ) : null}
        {memberId ? (
          <Button size="sm" variant="ghost" onClick={() => onOpenMember(memberId)}>
            {t('communityAdmin.openMember')}
          </Button>
        ) : null}
      </div>
      {item.targetType === 'member' ? <p style={hintStyle}>{t('communityAdmin.queue.memberReportsHint')}</p> : null}
    </article>
  );
}

/** Historique de l'auteur : restriction en cours, sanctions, signalements. */
export function AuthorHistory({ history, loading }: Readonly<{ history: AdminMemberDetail | null; loading: boolean }>) {
  const { t, locale } = useLocale();
  if (loading && !history) return <p style={hintStyle}>{t('communityAdmin.loading')}</p>;
  if (!history) return null;
  const sanctions = history.sanctions ?? [];
  return (
    <div style={{ display: 'grid', gap: 6, fontSize: 'var(--text-sm)' }} data-section="author-history">
      <strong>{t('communityAdmin.history.title')}</strong>
      <span style={{ color: 'var(--text-muted)' }}>
        {fill(t('communityAdmin.history.summary'), {
          posts: history.stats?.postsCount ?? 0,
          replies: history.stats?.repliesCount ?? 0,
          reports: history.openReportCount ?? 0,
          sanctions: sanctions.length,
        })}
      </span>
      {history.restriction ? (
        <Alert variant="warning" live={false}>
          {enumLabel(t, 'sanction', history.restriction.kind)} ·{' '}
          {history.restriction.until ? `${t('communityAdmin.until')} ${formatDate(history.restriction.until, locale)}` : t('communityAdmin.noEnd')}
        </Alert>
      ) : null}
      {sanctions.length ? (
        <ul style={{ margin: 0, paddingLeft: 18, display: 'grid', gap: 2 }}>
          {sanctions.slice(0, 5).map((s) => (
            <li key={s.id}>
              <Badge variant={SANCTION_VARIANT[s.kind] ?? 'info'}>{enumLabel(t, 'sanction', s.kind)}</Badge>{' '}
              {formatDate(s.createdAt, locale)} — {s.reason}
              {s.revokedAt ? ` (${t('communityAdmin.history.revoked')})` : s.active ? ` (${t('communityAdmin.history.active')})` : ''}
            </li>
          ))}
        </ul>
      ) : null}
    </div>
  );
}

function ShortcutHelp() {
  const { t } = useLocale();
  return (
    <details style={hintStyle}>
      <summary style={{ cursor: 'pointer' }}>{t('communityAdmin.shortcuts.title')}</summary>
      <p style={{ margin: '6px 0' }}>{t('communityAdmin.shortcuts.body')}</p>
      <ul style={{ margin: 0, paddingLeft: 18 }}>
        {SHORTCUT_KEYS.map(([key, action]) => (
          <li key={key}>
            <kbd>{key}</kbd> — {t(`communityAdmin.shortcuts.${action}`)}
          </li>
        ))}
      </ul>
    </details>
  );
}
