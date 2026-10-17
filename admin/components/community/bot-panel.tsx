'use client';

import { useEffect, useState } from 'react';

import {
  BOT_LIST_STATUSES,
  BOT_STATUS_VARIANT,
  BOT_STATUSES,
  type BotDraft,
  type BotDraftDetail,
  type BotDraftListStatus,
  type BotDraftPage,
  type BotStats,
  botDraftActions,
  type CommunityPermissions,
  communityAdminApi,
  formatHours,
  isBotDraftStale,
  rawLabel,
  REPLY_BODY_MAX,
  safeSourceUrl,
  validateBotText,
} from '../../lib/community-admin';
import { useLocale } from '../locale-provider';
import { Alert, Badge, Button, EmptyState, Field, Textarea } from '../ui';
import { ReasonDialog } from './action-dialogs';
import {
  AuthorLine,
  errorText,
  fill,
  formatDate,
  hintStyle,
  LoadError,
  panelCardStyle,
  Section,
  SegmentsView,
  type Translate,
  useLoader,
} from './shared';

/** Libellé d'une clé `communityAdmin.bot.<groupe>.<valeur>`, valeur brute si inconnue. */
function botLabel(t: Translate, group: string, value: string | null | undefined): string {
  if (!value) return '—';
  const key = `communityAdmin.bot.${group}.${value}`;
  const label = t(key);
  return label === key ? rawLabel(value) : label;
}

function formatDay(iso: string | null | undefined, locale: 'fr' | 'en'): string {
  if (!iso) return '—';
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return '—';
  return new Intl.DateTimeFormat(locale === 'fr' ? 'fr-FR' : 'en-GB', { dateStyle: 'short', timeZone: 'UTC' }).format(date);
}

export function BotStatusBadge({ status }: Readonly<{ status: string }>) {
  const { t } = useLocale();
  const known = (BOT_STATUSES as readonly string[]).includes(status);
  return <Badge variant={BOT_STATUS_VARIANT[status] ?? 'neutral'}>{known ? t(`communityAdmin.bot.status.${status}`) : rawLabel(status)}</Badge>;
}

/**
 * Bot « Vérif » (révision 2 du contrat, §8.9) : la file des brouillons que le
 * bot prépare depuis les données vérifiées du catalogue. Un admin relit,
 * modifie au besoin, puis publie (ou rejette avec motif, ou régénère).
 */
export function BotPanel({
  permissions,
  onOpenPost,
}: Readonly<{ permissions: CommunityPermissions; onOpenPost: (postId: string) => void }>) {
  const { t } = useLocale();
  const [status, setStatus] = useState<BotDraftListStatus>('proposed');
  const [selected, setSelected] = useState<string | null>(null);
  const stats = useLoader<BotStats>(() => communityAdminApi.botStats(30), []);
  const list = useLoader<BotDraftPage>(() => communityAdminApi.botDrafts(status), [status]);
  const [extra, setExtra] = useState<BotDraft[]>([]);
  const [moreError, setMoreError] = useState<string | null>(null);
  const items = [...(list.data?.items ?? []), ...extra];
  const cursor = extra.length ? undefined : list.data?.nextCursor;

  useEffect(() => setExtra([]), [list.data]);

  async function more() {
    if (!list.data?.nextCursor) return;
    try {
      const page = await communityAdminApi.botDrafts(status, list.data.nextCursor);
      setExtra((current) => [...current, ...page.items]);
    } catch (e) {
      setMoreError(errorText(t, e));
    }
  }

  function refresh() {
    void list.reload();
    void stats.reload();
  }

  return (
    <div style={{ display: 'grid', gap: 12 }}>
      {stats.data ? <BotStatsView stats={stats.data} /> : stats.error ? <LoadError error={stats.error} /> : null}
      <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }} role="group" aria-label={t('communityAdmin.bot.filter')}>
        {BOT_LIST_STATUSES.map((s) => (
          <Button
            key={s}
            size="sm"
            variant={status === s ? 'primary' : 'secondary'}
            aria-pressed={status === s}
            onClick={() => {
              setStatus(s);
              setSelected(null);
            }}
          >
            {s === 'all' ? t('communityAdmin.all') : t(`communityAdmin.bot.status.${s}`)}
          </Button>
        ))}
      </div>
      {moreError ? <Alert variant="danger">{moreError}</Alert> : null}
      {list.error ? (
        <LoadError error={list.error} />
      ) : list.loading && !list.data ? (
        <EmptyState title={t('communityAdmin.loading')} />
      ) : (
        <div style={{ display: 'grid', gap: 12, gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))', alignItems: 'start' }}>
          <div style={{ display: 'grid', gap: 8 }}>
            <BotDraftList items={items} selectedId={selected} onSelect={setSelected} />
            {cursor ? (
              <div>
                <Button variant="secondary" size="sm" onClick={() => void more()}>
                  {t('communityAdmin.loadMore')}
                </Button>
              </div>
            ) : null}
          </div>
          {selected ? (
            <BotDraftPanel key={selected} draftId={selected} permissions={permissions} onChanged={refresh} onOpenPost={onOpenPost} />
          ) : (
            <EmptyState title={t('communityAdmin.bot.selectTitle')} description={t('communityAdmin.bot.selectBody')} />
          )}
        </div>
      )}
    </div>
  );
}

export function BotStatsView({ stats }: Readonly<{ stats: BotStats }>) {
  const { t, locale } = useLocale();
  const tiles: Array<[string, string]> = [
    [t('communityAdmin.bot.stats.proposed'), String(stats.current.proposed ?? 0)],
    [t('communityAdmin.bot.stats.published'), String(stats.created.published ?? 0)],
    [t('communityAdmin.bot.stats.rejected'), String(stats.created.rejected ?? 0)],
    [t('communityAdmin.bot.stats.obsolete'), String(stats.current.obsolete ?? 0)],
    [t('communityAdmin.bot.stats.delay'), formatHours(stats.medianHandlingHours, locale)],
  ];
  return (
    <section style={{ ...panelCardStyle, display: 'grid', gap: 10 }} aria-label={t('communityAdmin.bot.stats.title')}>
      <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', alignItems: 'center' }}>
        <strong>{t('communityAdmin.bot.modeLabel')}</strong>
        <Badge variant={stats.mode === 'auto' ? 'warning' : stats.mode === 'off' ? 'neutral' : 'info'}>
          {botLabel(t, 'mode', stats.mode)}
        </Badge>
        <span style={hintStyle}>{t(stats.llmEnabled ? 'communityAdmin.bot.llmOn' : 'communityAdmin.bot.llmOff')}</span>
      </div>
      <p style={{ ...hintStyle, margin: 0 }}>{botLabel(t, 'modeHint', stats.mode)}</p>
      <div style={{ display: 'grid', gap: 8, gridTemplateColumns: 'repeat(auto-fit, minmax(130px, 1fr))' }}>
        {tiles.map(([label, value]) => (
          <div key={label} data-tile={label} style={{ display: 'grid', gap: 2 }}>
            <span style={{ fontSize: 'var(--text-xs)', color: 'var(--text-muted)', fontWeight: 700 }}>{label}</span>
            <span style={{ fontSize: 22, fontWeight: 800, fontVariantNumeric: 'tabular-nums' }}>{value}</span>
          </div>
        ))}
      </div>
      <p style={{ ...hintStyle, margin: 0 }}>
        {fill(t('communityAdmin.bot.stats.window'), {
          days: stats.window.days,
          auto: stats.autoPublished,
          verified: stats.publishedVerified,
        })}
      </p>
    </section>
  );
}

export function BotDraftList({
  items,
  selectedId,
  onSelect,
}: Readonly<{ items: readonly BotDraft[]; selectedId: string | null; onSelect: (id: string) => void }>) {
  const { t, locale } = useLocale();
  if (items.length === 0) {
    return <EmptyState title={t('communityAdmin.bot.emptyTitle')} description={t('communityAdmin.bot.emptyBody')} />;
  }
  return (
    <ul style={{ listStyle: 'none', margin: 0, padding: 0, display: 'grid', gap: 6 }}>
      {items.map((draft) => (
        <li key={draft.id}>
          <button
            type="button"
            data-draft-id={draft.id}
            aria-pressed={draft.id === selectedId}
            onClick={() => onSelect(draft.id)}
            style={{
              ...panelCardStyle,
              width: '100%',
              textAlign: 'left',
              cursor: 'pointer',
              padding: 12,
              display: 'grid',
              gap: 4,
              outline: draft.id === selectedId ? '2px solid var(--brand)' : undefined,
            }}
          >
            <span style={{ display: 'flex', gap: 6, flexWrap: 'wrap', alignItems: 'center' }}>
              <BotStatusBadge status={draft.status} />
              {draft.confidence ? (
                <Badge variant={draft.confidence === 'high' ? 'success' : draft.confidence === 'low' ? 'warning' : 'neutral'}>
                  {botLabel(t, 'confidence', draft.confidence)}
                </Badge>
              ) : null}
              {draft.autoPublished ? <Badge variant="info">{t('communityAdmin.bot.auto')}</Badge> : null}
            </span>
            <strong style={{ fontSize: 'var(--text-sm)' }}>{draft.post?.title ?? draft.postId}</strong>
            <span style={hintStyle}>
              {[draft.entities.map((e) => e.label).join(', '), formatDate(draft.createdAt, locale)].filter(Boolean).join(' · ')}
            </span>
            {draft.statusReason ? <span style={hintStyle}>{botLabel(t, 'reason', draft.statusReason)}</span> : null}
          </button>
        </li>
      ))}
    </ul>
  );
}

function BotDraftPanel({
  draftId,
  permissions,
  onChanged,
  onOpenPost,
}: Readonly<{
  draftId: string;
  permissions: CommunityPermissions;
  onChanged: () => void;
  onOpenPost: (postId: string) => void;
}>) {
  const { t } = useLocale();
  const detail = useLoader<BotDraftDetail>(() => communityAdminApi.botDraft(draftId), [draftId]);
  const [text, setText] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [rejecting, setRejecting] = useState(false);

  useEffect(() => {
    setText(detail.data?.draft.proposedText ?? '');
  }, [detail.data?.draft.proposedText, detail.data?.draft.id]);

  if (detail.error) return <LoadError error={detail.error} />;
  if (!detail.data) return <EmptyState title={t('communityAdmin.loading')} />;
  const data = detail.data;

  async function run(action: () => Promise<unknown>, done: string) {
    setBusy(true);
    setError(null);
    setNotice(null);
    try {
      await action();
      setNotice(done);
      await detail.reload();
      onChanged();
    } catch (e) {
      setError(errorText(t, e));
      await detail.reload();
      onChanged();
    } finally {
      setBusy(false);
    }
  }

  const edited = text.trim() !== (data.draft.proposedText ?? '').trim();
  return (
    <>
      <BotDraftDetailView
        detail={data}
        text={text}
        canAct={permissions.moderate}
        busy={busy}
        error={error}
        notice={notice}
        onTextChange={setText}
        onReset={() => setText(data.draft.proposedText ?? '')}
        onPublish={(verified) =>
          void run(
            () => communityAdminApi.botPublish(draftId, { ...(edited ? { text: text.trim() } : {}), verified }),
            t(verified ? 'communityAdmin.bot.donePublishedVerified' : 'communityAdmin.bot.donePublished'),
          )
        }
        onReject={() => setRejecting(true)}
        onRegenerate={() => void run(() => communityAdminApi.botRegenerate(draftId), t('communityAdmin.bot.doneRegenerated'))}
        onOpenPost={onOpenPost}
      />
      <ReasonDialog
        open={rejecting}
        title={t('communityAdmin.bot.rejectTitle')}
        description={t('communityAdmin.bot.rejectBody')}
        confirmLabel={t('communityAdmin.bot.reject')}
        variant="danger"
        onCancel={() => setRejecting(false)}
        onConfirm={async (reason) => {
          await communityAdminApi.botReject(draftId, reason);
          setRejecting(false);
          setNotice(t('communityAdmin.bot.doneRejected'));
          await detail.reload();
          onChanged();
        }}
      />
    </>
  );
}

/** Vue d'un brouillon : question, faits avec sources cliquables, texte éditable, actions. */
export function BotDraftDetailView({
  detail,
  text,
  canAct,
  busy = false,
  error = null,
  notice = null,
  onTextChange,
  onReset,
  onPublish,
  onReject,
  onRegenerate,
  onOpenPost,
}: Readonly<{
  detail: BotDraftDetail;
  text: string;
  canAct: boolean;
  busy?: boolean;
  error?: string | null;
  notice?: string | null;
  onTextChange: (text: string) => void;
  onReset: () => void;
  onPublish: (verified: boolean) => void;
  onReject: () => void;
  onRegenerate: () => void;
  onOpenPost: (postId: string) => void;
}>) {
  const { t, locale } = useLocale();
  const { draft, post, live } = detail;
  const stale = isBotDraftStale(draft, live);
  const actions = botDraftActions(draft, live);
  const textError = validateBotText(text);
  const staleReason =
    draft.status === 'obsolete'
      ? botLabel(t, 'reason', draft.statusReason ?? 'post_not_visible')
      : !live.postVisible
        ? t('communityAdmin.bot.reason.post_not_visible')
        : t('communityAdmin.bot.reason.facts_changed');

  return (
    <div style={{ display: 'grid', gap: 12 }} data-draft-detail={draft.id}>
      {notice ? <Alert variant="success">{notice}</Alert> : null}
      {error ? <Alert variant="danger">{error}</Alert> : null}
      {stale ? (
        <div data-stale="true">
          <Alert variant="warning">
            <strong>{t('communityAdmin.bot.staleTitle')}</strong> {staleReason}. {t('communityAdmin.bot.staleBody')}
          </Alert>
        </div>
      ) : null}

      <Section
        title={t('communityAdmin.bot.question')}
        actions={
          <Button size="sm" variant="ghost" onClick={() => onOpenPost(post.id)}>
            {t('communityAdmin.openDiscussion')}
          </Button>
        }
      >
        <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', alignItems: 'center' }}>
          <BotStatusBadge status={draft.status} />
          {draft.confidence ? <Badge variant="neutral">{fill(t('communityAdmin.bot.confidenceLabel'), { level: botLabel(t, 'confidence', draft.confidence) })}</Badge> : null}
          <Badge variant={draft.complete ? 'success' : 'warning'}>{t(draft.complete ? 'communityAdmin.bot.complete' : 'communityAdmin.bot.incomplete')}</Badge>
          {draft.scamCaution ? <Badge variant="danger">{t('communityAdmin.bot.scamCaution')}</Badge> : null}
          <Badge variant="neutral">{draft.lang.toUpperCase()}</Badge>
        </div>
        <strong>{post.title}</strong>
        <AuthorLine author={post.author} canViewIdentity={false} />
        <SegmentsView segments={post.segments} fallback={post.body} />
        {draft.intents.length ? (
          <div style={{ display: 'flex', gap: 4, flexWrap: 'wrap', alignItems: 'center' }}>
            <span style={hintStyle}>{t('communityAdmin.bot.intents')}</span>
            {draft.intents.map((intent) => (
              <Badge key={intent} variant="brand">
                {botLabel(t, 'intent', intent)}
              </Badge>
            ))}
          </div>
        ) : null}
      </Section>

      <Section title={t('communityAdmin.bot.facts')} hint={t('communityAdmin.bot.factsHint')}>
        {draft.sources.length === 0 ? (
          <p style={hintStyle}>{botLabel(t, 'reason', draft.statusReason ?? 'no_entity')}</p>
        ) : (
          <ul style={{ margin: 0, paddingLeft: 18, display: 'grid', gap: 6, fontSize: 'var(--text-sm)' }}>
            {draft.sources.map((source) => {
              const url = safeSourceUrl(source.url);
              const entity = draft.entities.find((e) => e.type === source.type && e.id === source.id);
              return (
                <li key={`${source.type}:${source.id}`} data-source={`${source.type}:${source.id}`}>
                  <strong>{source.label}</strong> <span style={{ color: 'var(--text-muted)' }}>· {botLabel(t, 'entity', String(source.type))}</span>
                  {entity ? <span style={{ color: 'var(--text-muted)' }}> · {botLabel(t, 'resolvedBy', entity.resolvedBy)}</span> : null}
                  <div>
                    {source.verifiedAt
                      ? fill(t('communityAdmin.bot.verifiedOn'), { date: formatDay(source.verifiedAt, locale) })
                      : t('communityAdmin.bot.noVerifiedDate')}{' '}
                    {source.stale ? <Badge variant="warning">{t('communityAdmin.bot.staleSource')}</Badge> : null}
                  </div>
                  <div>
                    {url ? (
                      <a href={url} target="_blank" rel="noopener noreferrer" style={{ overflowWrap: 'anywhere' }}>
                        {url}
                      </a>
                    ) : (
                      <span style={hintStyle}>{t('communityAdmin.bot.noSource')}</span>
                    )}
                  </div>
                </li>
              );
            })}
          </ul>
        )}
        {draft.facts ? (
          <details>
            <summary style={hintStyle}>{t('communityAdmin.bot.rawFacts')}</summary>
            <pre style={{ whiteSpace: 'pre-wrap', fontSize: 'var(--text-xs)', overflowWrap: 'anywhere' }}>{JSON.stringify(draft.facts, null, 2)}</pre>
          </details>
        ) : null}
      </Section>

      {draft.proposedText !== null || draft.status === 'proposed' ? (
        <Section
          title={t('communityAdmin.bot.text')}
          hint={[
            botLabel(t, 'writer', draft.writer ?? 'template'),
            draft.llmFallbackReason ? fill(t('communityAdmin.bot.llmFallback'), { reason: botLabel(t, 'llmReason', draft.llmFallbackReason) }) : null,
          ]
            .filter(Boolean)
            .join(' · ')}
        >
          <Field
            label={t('communityAdmin.bot.textLabel')}
            error={textError && draft.status === 'proposed' ? t(`communityAdmin.errors.${textError}`) : undefined}
          >
            {({ id, invalid }) => (
              <Textarea
                id={id}
                rows={14}
                invalid={invalid}
                maxLength={REPLY_BODY_MAX}
                value={text}
                readOnly={!canAct || draft.status !== 'proposed'}
                onChange={(e) => onTextChange(e.target.value)}
              />
            )}
          </Field>
          <p style={{ ...hintStyle, margin: 0 }}>{fill(t('communityAdmin.bot.textHint'), { n: text.trim().length, max: REPLY_BODY_MAX })}</p>
          {canAct ? (
            <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
              <Button disabled={!actions.publish || Boolean(textError) || busy} loading={busy} onClick={() => onPublish(false)}>
                {t('communityAdmin.bot.publish')}
              </Button>
              <Button variant="success" disabled={!actions.publish || Boolean(textError) || busy} onClick={() => onPublish(true)}>
                {t('communityAdmin.bot.publishVerified')}
              </Button>
              <Button variant="dangerOutline" disabled={!actions.reject || busy} onClick={onReject}>
                {t('communityAdmin.bot.reject')}
              </Button>
              <Button variant="secondary" disabled={!actions.regenerate || busy} onClick={onRegenerate}>
                {t('communityAdmin.bot.regenerate')}
              </Button>
              {draft.status === 'proposed' && text.trim() !== (draft.proposedText ?? '').trim() ? (
                <Button variant="ghost" disabled={busy} onClick={onReset}>
                  {t('communityAdmin.bot.reset')}
                </Button>
              ) : null}
            </div>
          ) : null}
        </Section>
      ) : canAct && actions.regenerate ? (
        <div>
          <Button variant="secondary" disabled={busy} onClick={onRegenerate}>
            {t('communityAdmin.bot.regenerate')}
          </Button>
        </div>
      ) : null}

      {draft.status === 'published' ? (
        <p style={hintStyle} data-published="true">
          {fill(t(draft.autoPublished ? 'communityAdmin.bot.publishedAuto' : 'communityAdmin.bot.publishedBy'), {
            date: formatDate(draft.processedAt, locale),
            name: draft.processedBy?.name ?? '—',
          })}
          {draft.publishedVerified ? ` · ${t('communityAdmin.verifiedAnswer')}` : ''}
        </p>
      ) : null}
      {draft.status === 'rejected' ? (
        <p style={hintStyle}>
          {fill(t('communityAdmin.bot.rejectedBy'), {
            date: formatDate(draft.processedAt, locale),
            name: draft.processedBy?.name ?? '—',
            reason: draft.rejectReason ?? '—',
          })}
        </p>
      ) : null}
    </div>
  );
}
