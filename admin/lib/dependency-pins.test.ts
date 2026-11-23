import { readFileSync } from 'node:fs';
import { join } from 'node:path';

import { describe, expect, it } from 'vitest';

// Garde-fou de régression : la console admin est exposée publiquement
// (admin.kpbeducation.cloud), next <= 15.5.28 est visé par des avis de
// sécurité (GHSA-2464-fhr4-w9xw RCE, GHSA-p3m5-59mp-jv5r DoS Server Actions,
// GHSA-pc58-hwjq-p385). On garde un épinglage exact et >= 15.5.29.
const root = join(__dirname, '..');
const pkg = JSON.parse(readFileSync(join(root, 'package.json'), 'utf8'));
const lock = JSON.parse(readFileSync(join(root, 'package-lock.json'), 'utf8'));

const MIN_NEXT: [number, number, number] = [15, 5, 29];

const parse = (v: string): [number, number, number] => {
  const m = /^(\d+)\.(\d+)\.(\d+)$/.exec(v);
  if (!m) throw new Error(`version non exacte : ${v}`);
  return [Number(m[1]), Number(m[2]), Number(m[3])];
};

const atLeast = (v: string, min: [number, number, number]): boolean => {
  const p = parse(v);
  for (let i = 0; i < 3; i++) {
    if (p[i] !== min[i]) return p[i] > min[i];
  }
  return true;
};

describe('épinglage de next (avis de sécurité)', () => {
  it('épingle next en version exacte, corrigée (>= 15.5.29)', () => {
    const v: string = pkg.dependencies.next;
    expect(v).toMatch(/^\d+\.\d+\.\d+$/);
    expect(atLeast(v, MIN_NEXT)).toBe(true);
  });

  it('aligne eslint-config-next sur next', () => {
    expect(pkg.devDependencies['eslint-config-next']).toBe(pkg.dependencies.next);
  });

  it('résout next et @next/env à la version épinglée dans le lock', () => {
    const v: string = pkg.dependencies.next;
    expect(lock.packages['node_modules/next'].version).toBe(v);
    expect(lock.packages['node_modules/@next/env'].version).toBe(v);
  });

  it('refuse une version vulnérable (contrôle du comparateur)', () => {
    expect(atLeast('15.5.28', MIN_NEXT)).toBe(false);
    expect(atLeast('15.5.27', MIN_NEXT)).toBe(false);
    expect(atLeast('15.5.29', MIN_NEXT)).toBe(true);
    expect(atLeast('15.6.0', MIN_NEXT)).toBe(true);
  });
});
