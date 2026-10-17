'use client';

import { useState } from 'react';

import { communityAdminApi, type ModerationLogEntry, type Page } from '../../lib/community-admin';
import { useLocale } from '../locale-provider';
import { AdminTable, AdminTableRow, Alert, Button, CellText, EmptyState } from '../ui';
import { enumLabel, errorText, formatDate, LoadError, useLoader } from './shared';

/** Journal de modération (§8.3) : qui a fait quoi, quand, pourquoi. */
export function ModerationLog({ onOpenPost }: Readonly<{ onOpenPost: (postId: string) => void }>) {
  const { t } = useLocale();
  const [extra, setExtra] = useState<ModerationLogEntry[]>([]);
  const [cursor, setCursor] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const log = useLoader<Page<ModerationLogEntry>>(async () => {
    const page = await communityAdminApi.log();
    setExtra([]);
    setCursor(page.nextCursor);
    return page;
  }, []);

  async function more() {
    if (!cursor) return;
    try {
      const page = await communityAdminApi.log(cursor);
      setExtra((current) => [...current, ...page.items]);
      setCursor(page.nextCursor);
    } catch (e) {
      setError(errorText(t, e));
    }
  }

  if (log.error) return <LoadError error={log.error} />;
  if (!log.data) return <EmptyState title={t('communityAdmin.loading')} />;
  return (
    <div style={{ display: 'grid', gap: 10 }}>
      {error ? <Alert variant="danger">{error}</Alert> : null}
      <LogTable entries={[...log.data.items, ...extra]} onOpenPost={onOpenPost} />
      {cursor ? (
        <div>
          <Button size="sm" variant="secondary" onClick={() => void more()}>
            {t('communityAdmin.loadMore')}
          </Button>
        </div>
      ) : null}
    </div>
  );
}

export function LogTable({
  entries,
  onOpenPost,
}: Readonly<{ entries: readonly ModerationLogEntry[]; onOpenPost: (postId: string) => void }>) {
  const { t, locale } = useLocale();
  if (entries.length === 0) return <EmptyState title={t('communityAdmin.log.empty')} />;
  return (
    <AdminTable
      cols="1fr 1fr 0.8fr 2fr 1fr"
      columns={[
        t('communityAdmin.log.colDate'),
        t('communityAdmin.log.colAction'),
        t('communityAdmin.log.colTarget'),
        t('communityAdmin.log.colReason'),
        t('communityAdmin.log.colModerator'),
      ]}
    >
      {entries.map((entry) => (
        <AdminTableRow key={entry.id} onSelect={entry.postId ? () => onOpenPost(entry.postId as string) : undefined}>
          <CellText primary={formatDate(entry.createdAt, locale)} muted />
          <CellText primary={enumLabel(t, 'logAction', entry.action)} />
          <CellText primary={enumLabel(t, 'target', entry.targetType)} muted />
          <CellText primary={entry.reason ?? '—'} />
          <CellText primary={entry.moderatorName ?? '—'} sub={entry.moderatorRole ?? undefined} />
        </AdminTableRow>
      ))}
    </AdminTable>
  );
}
