'use client';

import {
  CSSProperties,
  FormEvent,
  KeyboardEvent,
  useEffect,
  useLayoutEffect,
  useRef,
  useState,
} from 'react';

import { Alert, Button, Field, Textarea } from '../../components/ui';
import { apiFetch } from '../../lib/api-client';
import {
  CASE_MESSAGE_MAX_LENGTH,
  CASE_MESSAGES_POLL_MS,
  canSendDraft,
  caseMessagesPath,
  formatMessageTime,
  makeClientMessageId,
  mergeCaseMessages,
  messageSide,
  replyFieldsFromLatest,
  sameThread,
  type CaseMessage,
  type CaseMessagesPage,
  type CaseReplyFields,
} from '../../lib/case-messages';

/**
 * Fil étudiant ↔ équipe du dossier sélectionné. La page le monte avec
 * `key={caseId}` : changer de dossier démonte le fil, ce qui arrête la relève
 * et jette le brouillon, sans état à nettoyer à la main.
 */
export function CaseMessagesThread({
  caseId,
  locale,
  t,
  onReplyFieldsChange,
}: Readonly<{
  caseId: string;
  locale: string;
  t: (key: string) => string;
  /** L'état « réponse attendue » vu dans le fil, pour la liste des dossiers. */
  onReplyFieldsChange: (caseId: string, fields: CaseReplyFields) => void;
}>) {
  const [messages, setMessages] = useState<CaseMessage[]>([]);
  const [hasMore, setHasMore] = useState(false);
  const [loading, setLoading] = useState(true);
  const [loadingOlder, setLoadingOlder] = useState(false);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [draft, setDraft] = useState('');
  const [sending, setSending] = useState(false);
  const [sendError, setSendError] = useState<string | null>(null);

  // Un identifiant par brouillon : réutilisé à chaque nouvel essai du même
  // texte (le serveur ne crée alors pas de doublon), oublié dès qu'il change.
  const clientMessageIdRef = useRef<string | null>(null);
  const aliveRef = useRef(true);
  const listRef = useRef<HTMLDivElement>(null);
  const scrollIntentRef = useRef<'bottom' | 'keep' | 'none'>('bottom');
  const keepAnchorRef = useRef({ height: 0, top: 0 });
  const onReplyFieldsChangeRef = useRef(onReplyFieldsChange);
  onReplyFieldsChangeRef.current = onReplyFieldsChange;

  function applyMessages(incoming: readonly CaseMessage[]) {
    setMessages((current) => {
      const merged = mergeCaseMessages(current, incoming);
      return sameThread(current, merged) ? current : merged;
    });
  }

  function isNearBottom(): boolean {
    const el = listRef.current;
    if (!el) return true;
    return el.scrollHeight - el.scrollTop - el.clientHeight < 80;
  }

  useEffect(() => {
    aliveRef.current = true;
    let timer: ReturnType<typeof setInterval> | null = null;
    let inFlight = false;
    let firstLoad = true;

    async function refresh() {
      if (inFlight) return;
      inFlight = true;
      try {
        const page = await apiFetch<CaseMessagesPage>(caseMessagesPath(caseId));
        if (!aliveRef.current) return;
        if (scrollIntentRef.current !== 'keep') {
          scrollIntentRef.current = firstLoad || isNearBottom() ? 'bottom' : 'none';
        }
        applyMessages(page.items);
        if (firstLoad) {
          // `hasMore` ne parle de l'historique qu'au premier chargement ; une
          // relève ne ramène que la dernière page.
          setHasMore(page.hasMore);
          firstLoad = false;
        }
        setLoadError(null);
      } catch (error) {
        if (!aliveRef.current) return;
        // Une relève ratée réessaie toute seule au prochain tour ; on ne crie
        // que si le fil n'a jamais pu s'afficher.
        if (firstLoad) {
          setLoadError(
            error instanceof Error && error.message
              ? error.message
              : t('cases.messages.loadError'),
          );
        }
      } finally {
        inFlight = false;
        if (aliveRef.current) setLoading(false);
      }
    }

    function start() {
      if (timer === null) {
        timer = setInterval(() => void refresh(), CASE_MESSAGES_POLL_MS);
      }
    }
    function stop() {
      if (timer !== null) {
        clearInterval(timer);
        timer = null;
      }
    }
    function onVisibilityChange() {
      if (document.visibilityState === 'visible') {
        void refresh();
        start();
      } else {
        stop();
      }
    }

    void refresh();
    if (document.visibilityState === 'visible') start();
    document.addEventListener('visibilitychange', onVisibilityChange);
    return () => {
      aliveRef.current = false;
      stop();
      document.removeEventListener('visibilitychange', onVisibilityChange);
    };
    // `t` change d'identité à chaque rendu du fournisseur de langue ; le fil
    // ne dépend que du dossier.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [caseId]);

  useLayoutEffect(() => {
    const el = listRef.current;
    if (!el) return;
    if (scrollIntentRef.current === 'bottom') {
      el.scrollTop = el.scrollHeight;
    } else if (scrollIntentRef.current === 'keep') {
      const { height, top } = keepAnchorRef.current;
      el.scrollTop = el.scrollHeight - height + top;
    }
    scrollIntentRef.current = 'none';
  }, [messages]);

  const latest = messages[messages.length - 1];
  useEffect(() => {
    const fields = replyFieldsFromLatest(latest);
    if (fields) onReplyFieldsChangeRef.current(caseId, fields);
  }, [caseId, latest]);

  async function loadOlder() {
    const oldest = messages[0];
    if (!oldest || loadingOlder) return;
    setLoadingOlder(true);
    setLoadError(null);
    try {
      const page = await apiFetch<CaseMessagesPage>(
        caseMessagesPath(caseId, oldest.id),
      );
      if (!aliveRef.current) return;
      const el = listRef.current;
      keepAnchorRef.current = {
        height: el?.scrollHeight ?? 0,
        top: el?.scrollTop ?? 0,
      };
      scrollIntentRef.current = 'keep';
      applyMessages(page.items);
      setHasMore(page.hasMore);
    } catch (error) {
      if (!aliveRef.current) return;
      setLoadError(
        error instanceof Error && error.message
          ? error.message
          : t('cases.messages.loadError'),
      );
    } finally {
      if (aliveRef.current) setLoadingOlder(false);
    }
  }

  async function send() {
    if (!canSendDraft(draft, sending)) return;
    const clientMessageId = clientMessageIdRef.current ?? makeClientMessageId();
    clientMessageIdRef.current = clientMessageId;
    setSending(true);
    setSendError(null);
    try {
      const created = await apiFetch<CaseMessage>(
        `/admin/cases/${encodeURIComponent(caseId)}/messages`,
        { method: 'POST', body: { body: draft.trim(), clientMessageId } },
      );
      if (!aliveRef.current) return;
      scrollIntentRef.current = 'bottom';
      applyMessages([created]);
      setDraft('');
      clientMessageIdRef.current = null;
    } catch (error) {
      if (!aliveRef.current) return;
      // Le texte reste dans la zone de saisie : un nouvel essai repart avec
      // le même identifiant.
      setSendError(
        error instanceof Error && error.message
          ? `${t('cases.messages.sendError')} ${error.message}`
          : t('cases.messages.sendError'),
      );
    } finally {
      if (aliveRef.current) setSending(false);
    }
  }

  function onSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    void send();
  }

  function onKeyDown(event: KeyboardEvent<HTMLTextAreaElement>) {
    if (event.key === 'Enter' && (event.ctrlKey || event.metaKey)) {
      event.preventDefault();
      void send();
    }
  }

  function roleLabel(role: string): string {
    if (role === 'student') return t('cases.messages.roleStudent');
    if (role === 'system') return t('cases.messages.roleSystem');
    const key = `roles.${role}`;
    const label = t(key);
    return label === key ? role : label;
  }

  return (
    <div style={{ display: 'grid', gap: 10 }}>
      <div style={{ display: 'grid', gap: 4 }}>
        <strong style={{ fontSize: 'var(--text-sm)', color: 'var(--ink)' }}>
          {t('cases.messages.title')}
        </strong>
        <span style={{ fontSize: 'var(--text-xs)', color: 'var(--text-muted)' }}>
          {t('cases.messages.hint')}
        </span>
      </div>

      {loadError ? <Alert variant="danger">{loadError}</Alert> : null}

      <div
        ref={listRef}
        role="log"
        aria-label={t('cases.messages.title')}
        aria-busy={loading || undefined}
        style={threadStyle}
      >
        {hasMore ? (
          <div style={{ display: 'flex', justifyContent: 'center' }}>
            <Button
              variant="ghost"
              size="sm"
              loading={loadingOlder}
              onClick={() => void loadOlder()}
            >
              {loadingOlder
                ? t('cases.messages.loadingOlder')
                : t('cases.messages.loadOlder')}
            </Button>
          </div>
        ) : null}

        {loading && messages.length === 0 ? (
          <p style={mutedStyle}>{t('cases.messages.loading')}</p>
        ) : null}
        {!loading && messages.length === 0 && !loadError ? (
          <p style={mutedStyle}>{t('cases.messages.empty')}</p>
        ) : null}

        {messages.map((message) => {
          const side = messageSide(message.senderRole);
          return (
            <div key={message.id} style={rowStyle[side]}>
              <div style={bubbleStyle[side]}>
                <div style={metaStyle}>
                  <strong style={{ color: 'var(--ink)' }}>
                    {message.senderName || roleLabel(message.senderRole)}
                  </strong>
                  {message.senderName ? ` • ${roleLabel(message.senderRole)}` : null}
                  {' • '}
                  <time dateTime={message.createdAt}>
                    {formatMessageTime(message.createdAt, locale)}
                  </time>
                </div>
                <p style={bodyStyle}>{message.body}</p>
              </div>
            </div>
          );
        })}
      </div>

      <form onSubmit={onSubmit} style={{ display: 'grid', gap: 8 }}>
        <Field label={t('cases.messages.replyLabel')}>
          {({ id }) => (
            <Textarea
              id={id}
              value={draft}
              maxLength={CASE_MESSAGE_MAX_LENGTH}
              readOnly={sending}
              placeholder={t('cases.messages.replyPlaceholder')}
              onKeyDown={onKeyDown}
              onChange={(event) => {
                setDraft(event.target.value);
                clientMessageIdRef.current = null;
                setSendError(null);
              }}
            />
          )}
        </Field>
        {sendError ? <Alert variant="danger">{sendError}</Alert> : null}
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            gap: 12,
            flexWrap: 'wrap',
          }}
        >
          <span style={{ fontSize: 'var(--text-xs)', color: 'var(--text-muted)' }}>
            {draft.length} / {CASE_MESSAGE_MAX_LENGTH} • {t('cases.messages.shortcutHint')}
          </span>
          <Button
            type="submit"
            loading={sending}
            disabled={!canSendDraft(draft, sending)}
          >
            {sending ? t('cases.messages.sending') : t('cases.messages.sendCta')}
          </Button>
        </div>
      </form>
    </div>
  );
}

const threadStyle: CSSProperties = {
  display: 'grid',
  gap: 10,
  alignContent: 'start',
  maxHeight: 420,
  minHeight: 120,
  overflowY: 'auto',
  padding: 12,
  background: 'var(--bg)',
  border: '1px solid var(--border)',
  borderRadius: 'var(--radius-md)',
};

const mutedStyle: CSSProperties = {
  margin: 0,
  fontSize: 'var(--text-sm)',
  color: 'var(--text-muted)',
  textAlign: 'center',
};

const metaStyle: CSSProperties = {
  fontSize: 'var(--text-xs)',
  color: 'var(--text-muted)',
  marginBottom: 4,
};

const bodyStyle: CSSProperties = {
  margin: 0,
  fontSize: 'var(--text-sm)',
  color: 'var(--text)',
  whiteSpace: 'pre-wrap',
  overflowWrap: 'anywhere',
};

const rowStyle: Record<'student' | 'staff' | 'system', CSSProperties> = {
  student: { display: 'flex', justifyContent: 'flex-start' },
  staff: { display: 'flex', justifyContent: 'flex-end' },
  system: { display: 'flex', justifyContent: 'center' },
};

const bubbleBase: CSSProperties = {
  maxWidth: '80%',
  padding: '8px 12px',
  borderRadius: 'var(--radius-md)',
  border: '1px solid var(--border)',
};

const bubbleStyle: Record<'student' | 'staff' | 'system', CSSProperties> = {
  student: { ...bubbleBase, background: 'var(--surface)', borderBottomLeftRadius: 4 },
  staff: {
    ...bubbleBase,
    background: 'var(--brand-soft)',
    borderColor: 'var(--info-bg)',
    borderBottomRightRadius: 4,
  },
  system: {
    ...bubbleBase,
    maxWidth: '90%',
    background: 'var(--surface-2)',
    borderStyle: 'dashed',
    fontStyle: 'italic',
  },
};
