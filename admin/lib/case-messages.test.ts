import { readFileSync } from 'node:fs';
import { join } from 'node:path';

import { describe, expect, it } from 'vitest';

import {
  CASE_MESSAGE_MAX_LENGTH,
  applyReplyOverride,
  canSendDraft,
  caseMessagesPath,
  formatMessageTime,
  isValidClientMessageId,
  makeClientMessageId,
  mergeCaseMessages,
  messageSide,
  replyFieldsFromLatest,
  sameThread,
  sortAwaitingReplyFirst,
  type CaseMessage,
} from './case-messages';

function msg(id: string, createdAt: string, extra: Partial<CaseMessage> = {}): CaseMessage {
  return {
    id,
    senderName: 'Awa',
    senderRole: 'student',
    body: `corps ${id}`,
    createdAt,
    clientMessageId: null,
    ...extra,
  };
}

describe('identifiant d’idempotence', () => {
  it('rend un UUID conforme au motif du serveur', () => {
    const id = makeClientMessageId(() => '3f2b8c1e-9a4d-4e2f-8b7a-1c2d3e4f5a6b');
    expect(id).toBe('3f2b8c1e-9a4d-4e2f-8b7a-1c2d3e4f5a6b');
    expect(isValidClientMessageId(id)).toBe(true);
  });

  it('retire les caractères interdits et tronque à 64', () => {
    expect(makeClientMessageId(() => 'a.b/c d{e}')).toBe('abcde');
    expect(makeClientMessageId(() => 'x'.repeat(100))).toHaveLength(64);
  });

  it('se rabat sur un identifiant valide si le générateur ne rend rien d’utilisable', () => {
    const id = makeClientMessageId(() => '...');
    expect(isValidClientMessageId(id)).toBe(true);
  });

  it('le générateur par défaut produit des identifiants valides et distincts', () => {
    const a = makeClientMessageId();
    const b = makeClientMessageId();
    expect(isValidClientMessageId(a)).toBe(true);
    expect(a).not.toBe(b);
  });
});

describe('fusion des pages du fil', () => {
  it('ajoute une page plus ancienne devant, sans doublon, dans l’ordre chronologique', () => {
    const recent = [msg('m3', '2026-11-09T10:00:00Z'), msg('m4', '2026-11-09T11:00:00Z')];
    const older = [msg('m1', '2026-11-08T10:00:00Z'), msg('m2', '2026-11-08T11:00:00Z'), msg('m3', '2026-11-09T10:00:00Z')];
    expect(mergeCaseMessages(recent, older).map((m) => m.id)).toEqual(['m1', 'm2', 'm3', 'm4']);
  });

  it('une relève ajoute les nouveaux et garde l’historique déjà chargé', () => {
    const loaded = [msg('m1', '2026-11-08T10:00:00Z'), msg('m2', '2026-11-09T10:00:00Z')];
    const latest = [msg('m2', '2026-11-09T10:00:00Z'), msg('m3', '2026-11-09T12:00:00Z')];
    expect(mergeCaseMessages(loaded, latest).map((m) => m.id)).toEqual(['m1', 'm2', 'm3']);
  });

  it('la version reçue en dernier remplace l’ancienne', () => {
    const merged = mergeCaseMessages(
      [msg('m1', '2026-11-08T10:00:00Z', { body: 'avant' })],
      [msg('m1', '2026-11-08T10:00:00Z', { body: 'après' })],
    );
    expect(merged).toHaveLength(1);
    expect(merged[0].body).toBe('après');
  });

  it('un même clientMessageId ne s’affiche qu’une fois', () => {
    const merged = mergeCaseMessages(
      [msg('tmp', '2026-11-09T10:00:00Z', { clientMessageId: 'abc', senderRole: 'counselor' })],
      [msg('m9', '2026-11-09T10:00:01Z', { clientMessageId: 'abc', senderRole: 'counselor' })],
    );
    expect(merged.map((m) => m.id)).toEqual(['m9']);
  });

  it('départage deux messages de même horodatage par id, sans muter les entrées', () => {
    const current = [msg('b', '2026-11-09T10:00:00Z')];
    const incoming = [msg('a', '2026-11-09T10:00:00Z')];
    expect(mergeCaseMessages(current, incoming).map((m) => m.id)).toEqual(['a', 'b']);
    expect(current.map((m) => m.id)).toEqual(['b']);
  });

  it('sameThread ignore une relève qui n’apporte rien', () => {
    const a = [msg('m1', '2026-11-08T10:00:00Z')];
    expect(sameThread(a, [{ ...a[0] }])).toBe(true);
    expect(sameThread(a, [{ ...a[0], body: 'modifié' }])).toBe(false);
    expect(sameThread(a, [])).toBe(false);
  });
});

describe('requêtes et affichage', () => {
  it('construit le chemin de page, avec ou sans `before`', () => {
    expect(caseMessagesPath('case-1')).toBe('/admin/cases/case-1/messages?limit=50');
    expect(caseMessagesPath('case-1', 'm42')).toBe('/admin/cases/case-1/messages?limit=50&before=m42');
  });

  it('place l’étudiant d’un côté, l’équipe de l’autre, le système à part', () => {
    expect(messageSide('student')).toBe('student');
    expect(messageSide('system')).toBe('system');
    for (const role of ['counselor', 'commercial', 'admin', 'super_admin', 'moderator']) {
      expect(messageSide(role)).toBe('staff');
    }
  });

  it('n’envoie ni un brouillon vide, ni pendant un envoi, ni au-delà de 3000', () => {
    expect(canSendDraft('', false)).toBe(false);
    expect(canSendDraft('   \n', false)).toBe(false);
    expect(canSendDraft('Bonjour', true)).toBe(false);
    expect(canSendDraft('Bonjour', false)).toBe(true);
    expect(canSendDraft('x'.repeat(CASE_MESSAGE_MAX_LENGTH), false)).toBe(true);
    expect(canSendDraft('x'.repeat(CASE_MESSAGE_MAX_LENGTH + 1), false)).toBe(false);
  });

  it('formate l’heure en français, et rend la chaîne brute si elle est illisible', () => {
    expect(formatMessageTime('2026-11-09T09:05:00Z', 'fr', 'Africa/Lagos')).toBe('09/11/2026 10:05');
    expect(formatMessageTime('pas une date', 'fr')).toBe('pas une date');
  });
});

describe('réponses attendues dans la liste des dossiers', () => {
  const cases = [
    { id: 'a', awaitingReply: false, lastMessageAt: '2026-11-09T08:00:00Z' },
    { id: 'b', awaitingReply: true, lastMessageAt: '2026-11-09T09:00:00Z' },
    { id: 'c' },
    { id: 'd', awaitingReply: true, lastMessageAt: '2026-11-08T09:00:00Z' },
    { id: 'e', awaitingReply: true, lastMessageAt: null },
  ];

  it('met les dossiers en attente devant, le plus ancien d’abord, le reste dans l’ordre du serveur', () => {
    expect(sortAwaitingReplyFirst(cases).map((c) => c.id)).toEqual(['d', 'b', 'e', 'a', 'c']);
    expect(cases.map((c) => c.id)).toEqual(['a', 'b', 'c', 'd', 'e']);
  });

  it('déduit l’état du dernier message du fil', () => {
    expect(replyFieldsFromLatest(undefined)).toBeNull();
    expect(replyFieldsFromLatest(msg('m1', '2026-11-09T10:00:00Z'))).toEqual({
      awaitingReply: true,
      lastMessageAt: '2026-11-09T10:00:00Z',
    });
    expect(
      replyFieldsFromLatest(msg('m2', '2026-11-09T11:00:00Z', { senderRole: 'counselor' }))?.awaitingReply,
    ).toBe(false);
  });

  it('le fil ouvert recouvre la liste, sauf si la liste est plus récente', () => {
    const item = { id: 'x', awaitingReply: true, lastMessageAt: '2026-11-09T10:00:00Z' };
    const replied = { awaitingReply: false, lastMessageAt: '2026-11-09T10:05:00Z' };
    expect(applyReplyOverride(item, replied)).toEqual({ id: 'x', ...replied });
    expect(applyReplyOverride(item, undefined)).toBe(item);
    const stale = { awaitingReply: false, lastMessageAt: '2026-11-09T09:00:00Z' };
    expect(applyReplyOverride(item, stale)).toBe(item);
    expect(
      applyReplyOverride(item, { awaitingReply: item.awaitingReply, lastMessageAt: item.lastMessageAt }),
    ).toBe(item);
    // Backend antérieur : la liste ne connaît pas encore ces champs.
    const legacy: { id: string; awaitingReply?: boolean; lastMessageAt?: string | null } = { id: 'y' };
    expect(applyReplyOverride(legacy, replied)).toEqual({ id: 'y', ...replied });
  });
});

describe('messages du fil', () => {
  type Messages = Record<string, unknown>;
  const load = (locale: string): Messages =>
    JSON.parse(readFileSync(join(__dirname, '..', 'messages', `${locale}.json`), 'utf8'));
  const lookup = (messages: Messages, key: string): unknown =>
    key.split('.').reduce<unknown>(
      (current, part) =>
        current && typeof current === 'object' ? (current as Messages)[part] : undefined,
      messages,
    );

  it('chaque clé `cases.…` utilisée par la page et le fil existe dans les deux langues', () => {
    const sources = ['page.tsx', 'case-messages-thread.tsx'].map((file) =>
      readFileSync(join(__dirname, '..', 'app', 'cases', file), 'utf8'),
    );
    const used = new Set(
      sources.flatMap((source) =>
        [...source.matchAll(/t\(\s*['`](cases\.[A-Za-z_.]+)['`]/g)].map((m) => m[1]),
      ),
    );
    expect(used.has('cases.messages.sendCta')).toBe(true);
    for (const messages of [load('fr'), load('en')]) {
      for (const key of used) {
        expect({ key, type: typeof lookup(messages, key) }).toEqual({ key, type: 'string' });
      }
    }
  });
});
