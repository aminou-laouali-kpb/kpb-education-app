import { podiumAssignments, reassignAfterForfeit, type PrizeSlot } from './prize-forfeit';

/**
 * Correctifs 57 — « Déclarer le prix forfait et réattribuer ». Un prix perdu
 * passe au suivant classé non primé ; un prix versé ne bouge jamais.
 */
describe('reassignAfterForfeit', () => {
  const ranked = [
    { id: 'A', rank: 1 },
    { id: 'B', rank: 2 },
    { id: 'C', rank: 3 },
    { id: 'D', rank: 4 },
    { id: 'E', rank: 5 },
  ];
  const slots = (paid: number[] = []): PrizeSlot[] =>
    [
      { rank: 1, participantId: 'A' },
      { rank: 2, participantId: 'B' },
      { rank: 3, participantId: 'C' },
    ].map((s) => ({ ...s, paid: paid.includes(s.rank) }));

  it('le 2e prix perdu : le 3e monte au 2e prix, le 4e entre au 3e prix', () => {
    expect(reassignAfterForfeit(slots(), 2, new Set(['B']), ranked)).toEqual([
      { rank: 2, participantId: 'C' },
      { rank: 3, participantId: 'D' },
    ]);
  });

  it('après un premier versement : le prix versé ne bouge pas, son titulaire n’est plus candidat', () => {
    // 1er prix versé à A ; B perd le 2e.
    expect(reassignAfterForfeit(slots([1]), 2, new Set(['B']), ranked)).toEqual([
      { rank: 2, participantId: 'C' },
      { rank: 3, participantId: 'D' },
    ]);
    // 3e prix déjà versé à C ; A (non versé) perd le 1er : B monte, C garde
    // son prix versé, le 2e va au suivant non primé (D).
    expect(reassignAfterForfeit(slots([3]), 1, new Set(['A']), ranked)).toEqual([
      { rank: 1, participantId: 'B' },
      { rank: 2, participantId: 'D' },
    ]);
  });

  it('un prix non versé d’un rang plus petit reste à son titulaire', () => {
    expect(reassignAfterForfeit(slots(), 3, new Set(['C']), ranked)).toEqual([
      { rank: 3, participantId: 'D' },
    ]);
  });

  it('un participant déjà forfait ne reprend jamais un prix', () => {
    // D a été forfait plus tôt : E reçoit le 3e prix.
    expect(reassignAfterForfeit(slots(), 3, new Set(['C', 'D']), ranked)).toEqual([
      { rank: 3, participantId: 'E' },
    ]);
  });

  it('plus de candidat : le prix reste non attribué', () => {
    const three = ranked.slice(0, 3);
    expect(reassignAfterForfeit(slots([1]), 2, new Set(['B']), three)).toEqual([
      { rank: 2, participantId: 'C' },
      { rank: 3, participantId: null },
    ]);
  });
});

describe('podiumAssignments', () => {
  const ranked = [
    { id: 'A', rank: 1 },
    { id: 'B', rank: 2 },
    { id: 'C', rank: 3 },
    { id: 'D', rank: 4 },
  ];

  it('sans forfait : le rang N reçoit le prix N (ancienne règle)', () => {
    expect(podiumAssignments([1, 2, 3], new Set(), ranked)).toEqual([
      { rank: 1, participantId: 'A' },
      { rank: 2, participantId: 'B' },
      { rank: 3, participantId: 'C' },
    ]);
  });

  it('une revalidation saute les participants déclarés forfait', () => {
    expect(podiumAssignments([1, 2, 3], new Set(['B']), ranked)).toEqual([
      { rank: 1, participantId: 'A' },
      { rank: 2, participantId: 'C' },
      { rank: 3, participantId: 'D' },
    ]);
  });
});
