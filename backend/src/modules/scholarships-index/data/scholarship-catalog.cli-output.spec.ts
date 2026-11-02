// La discipline de sortie du CLI de validation : stdout EST le rapport JSON,
// tout le reste vit sur stderr.
//
// ## L'accident que ce fichier empêche de revenir
//
// `catalog-freshness.yml` lit le rapport puis le donne à `JSON.parse`. Le CLI
// imprimait le JSON, PUIS les annotations `::warning::` de clôture proche — sur
// stdout aussi. Tant qu'aucune échéance n'entrait dans l'horizon de 14 jours,
// rien ne suivait le JSON et tout était vert. La première qui y entrait
// (Schwarzman, clôture le 09/09/2026 → entrée dans l'horizon au cron du
// 27/08/2026) aurait ajouté une ligne en queue, fait exploser `JSON.parse`, et
// tué l'étape AVANT l'écriture de ses sorties : ni issue, ni annotation.
// L'alarme mourait le jour précis où elle avait quelque chose à dire — encore
// un défaut caché par l'outil censé le détecter.
//
// ## Pourquoi ce test spawn le vrai CLI
//
// Le contrat porte sur ce que le PROCESSUS écrit sur chaque flux, pas sur une
// fonction : seul un vrai spawn le voit. Et il se joue à `--now 2026-08-27` —
// la date exacte de l'accident — parce qu'à une date sans clôture proche, le
// test resterait vert avec ou sans le défaut. Vu rouge par mutation : remettre
// les `::warning::` sur stdout fait échouer « stdout est du JSON pur ».

import { spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import * as path from 'node:path';

// __dirname = src/modules/scholarships-index/data → 4 crans = racine backend.
const BACKEND_ROOT = path.join(__dirname, '..', '..', '..', '..');

// Horloge ré-ancrée à chaque clôture de l'exemple : Schwarzman (09/09),
// Chevening (06/10) puis Open Doors (01/11) sont désormais `closed`. Le
// principe ne change pas — jouer le CLI un jour où une clôture entre dans
// l'horizon. Le 20/11/2026 à 06:00 UTC, l'heure du cron, ETH ESOP (clôture le
// 30/11) est à dix jours.
const ACCIDENT_CLOCK = '2026-11-20T06:00:00.000Z';

describe('validate-scholarship-catalog CLI — discipline de sortie', () => {
  let tmpDir: string;
  let stdout = '';
  let stderr = '';
  let reportRaw = '';

  beforeAll(() => {
    tmpDir = mkdtempSync(path.join(tmpdir(), 'catalog-cli-'));
    const reportPath = path.join(tmpDir, 'report.json');
    // `spawnSync`, pas `execFileSync` : il rend stdout ET stderr que le CLI
    // sorte en 0 ou en 1 — et le contrat de sortie doit tenir dans les deux
    // cas. `execFileSync` ne donne stderr que dans le chemin d'exception.
    const result = spawnSync(
      process.execPath,
      [
        '-r',
        'ts-node/register/transpile-only',
        'scripts/validate-scholarship-catalog.ts',
        '--structure-only',
        '--now',
        ACCIDENT_CLOCK,
        '--report',
        reportPath,
      ],
      { cwd: BACKEND_ROOT, encoding: 'utf8' },
    );
    if (result.error) throw result.error;
    stdout = result.stdout;
    stderr = result.stderr;
    reportRaw = readFileSync(reportPath, 'utf8');
  }, 120_000);

  afterAll(() => {
    rmSync(tmpDir, { recursive: true, force: true });
  });

  it("le 20/11 a bien quelque chose à annoncer — sinon ce test ne prouve rien", () => {
    const report = JSON.parse(reportRaw) as {
      closingSoon: Array<{ scholarshipId: string }>;
    };
    expect(report.closingSoon.length).toBeGreaterThanOrEqual(1);
    expect(
      report.closingSoon.map((entry) => entry.scholarshipId),
    ).toContain('eth_zurich_esop_2027');
  });

  it('le fichier --report est du JSON pur, annotations comprises dans la journée', () => {
    // C'est LA propriété que le workflow consomme : JSON.parse direct, sans
    // découpage. Elle doit tenir le jour où il y a des annotations.
    expect(() => JSON.parse(reportRaw)).not.toThrow();
  });

  it('stdout est du JSON pur — un `| jq` ou un JSON.parse ne casse jamais', () => {
    // Le défaut d'origine : les ::warning:: suivaient le JSON sur stdout.
    // JSON.parse sur le flux COMPLET est exactement ce qui explosait.
    expect(() => JSON.parse(stdout)).not.toThrow();
  });

  it('les annotations de clôture proche sortent sur stderr, et y sont bien', () => {
    // Pas seulement « stdout est propre » : l'annotation doit continuer
    // d'EXISTER — la déplacer était le correctif, la perdre serait une
    // régression pire (plus d'alarme du tout).
    expect(stderr).toContain('::warning::eth_zurich_esop_2027');
  });
});
