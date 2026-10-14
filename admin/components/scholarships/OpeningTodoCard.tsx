'use client';

import { CSSProperties } from 'react';

import { fill, todoRowText } from '../../lib/scholarship-opening';
import type {
  OpeningTodoItem,
  OpeningTodoResponse,
} from '../../lib/scholarship-opening-types';
import { useLocale } from '../locale-provider';
import { Button } from '../ui';

/**
 * « À faire » : les cycles servis ouverts aux étudiants que personne n'a
 * annoncés (ni annonce faite, ni écartée, ni programmée, ni ouverte avant la
 * mise en service). Masquée quand la liste est vide.
 */

const cardStyle: CSSProperties = {
  display: 'grid',
  gap: 10,
  background: 'var(--surface)',
  border: '1px solid var(--warning-bg)',
  borderLeft: '4px solid var(--warning-fg)',
  borderRadius: 16,
  padding: 16,
};

export function OpeningTodoCard({
  todo,
  onPrepare,
}: Readonly<{
  todo: OpeningTodoResponse | null;
  onPrepare: (item: OpeningTodoItem) => void;
}>) {
  const { t } = useLocale();
  if (!todo || todo.items.length === 0) return null;

  return (
    <section style={cardStyle} aria-label={t('scholarships.opening.todoTitle')}>
      <div style={{ display: 'grid', gap: 2 }}>
        <h3
          style={{
            margin: 0,
            fontSize: 'var(--text-base)',
            fontWeight: 800,
            color: 'var(--ink)',
          }}
        >
          {t('scholarships.opening.todoTitle')} ({todo.total})
        </h3>
        <span style={{ fontSize: 'var(--text-xs)', color: 'var(--text-muted)' }}>
          {t('scholarships.opening.todoHint')}
        </span>
      </div>
      <ul
        style={{
          margin: 0,
          padding: 0,
          listStyle: 'none',
          display: 'grid',
          gap: 6,
          maxHeight: 260,
          overflowY: 'auto',
        }}
      >
        {todo.items.map((item) => (
          <li
            key={item.cycleId}
            style={{
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
              gap: 12,
              background: 'var(--bg)',
              border: '1px solid var(--border-soft)',
              borderRadius: 12,
              padding: '8px 12px',
            }}
          >
            <span style={{ fontSize: 'var(--text-sm)', minWidth: 0 }}>
              {todoRowText(item, t)}
            </span>
            <Button size="sm" variant="secondary" onClick={() => onPrepare(item)}>
              {t('scholarships.opening.todoCta')}
            </Button>
          </li>
        ))}
      </ul>
      {todo.total > todo.items.length ? (
        <span style={{ fontSize: 'var(--text-xs)', color: 'var(--text-muted)' }}>
          {fill(t('scholarships.opening.todoMore'), {
            n: todo.total - todo.items.length,
          })}
        </span>
      ) : null}
    </section>
  );
}
