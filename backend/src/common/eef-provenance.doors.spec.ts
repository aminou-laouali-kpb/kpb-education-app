// ─────────────────────────────────────────────────────────────────────────────
// Les PORTES : aucun lecteur de `Program` ou `Institution` sans garde déclarée.
//
// POURQUOI CE FICHIER EXISTE
//
// Le défaut que garde `common/eef-provenance.ts` a la forme que ce dépôt a déjà
// connue : une règle énoncée et appliquée à une porte sur quatre. Le catalogue
// général, les recommandations, la recherche, la shortlist, la file de
// revérification et le compteur du tableau de bord lisent tous ces deux tables.
// Les corriger un par un ne suffit pas — le septième lecteur, écrit dans six
// mois, ne saura pas qu'il existe une règle. Ce test le lui dit, à l'endroit où
// l'oubli se produit.
//
// COMMENT IL LIT LE CODE
//
// Par l'ARBRE SYNTAXIQUE de TypeScript, pas par des expressions régulières sur le
// texte. La première version retirait les commentaires par regex, dans le mauvais
// ordre : un `/*` cité dans un commentaire de ligne (`// … /catalog/*`) ouvrait un
// faux bloc jusqu'au prochain `*/` du fichier et AVALAIT le code entre les deux.
// Deux des quatre portes principales — le catalogue général et la recherche —
// étaient devenues invisibles, et le plancher « au moins six lecteurs » valait
// exactement le compte faux. Un arbre n'a pas ce défaut : un commentaire est un
// commentaire, une chaîne est une chaîne.
//
// CE QU'IL EXIGE
//
//   1. chaque fichier de `src/` qui appelle une méthode de `prisma.program` ou
//      `prisma.institution` figure dans le registre `DOORS`, et inversement ;
//   2. dans un fichier gardé, chaque MÉTHODE qui accède aux tables APPELLE les
//      fonctions de portée que le registre lui assigne (un `import` seul ne
//      compte pas — il survivrait à la suppression de l'appel) ;
//   3. le nombre d'accès de chaque fichier gardé est épinglé : en ajouter un
//      oblige à le reconnaître ici, donc à se demander s'il porte la portée ;
//   4. aucun accès par alias, déstructuration, crochets ou valeur : le scanner ne
//      sait pas les suivre, donc il les refuse ;
//   5. aucun SQL brut sur ces tables : il contournerait toute clause Prisma.
//
// Et il se TESTE LUI-MÊME (dernier bloc) sur des sources écrites à la main, dont
// le cas qui l'a pris en défaut.
// ─────────────────────────────────────────────────────────────────────────────
import { readFileSync, readdirSync } from 'node:fs';
import { join, relative, sep } from 'node:path';

import * as ts from 'typescript';

// ─── Le scanner ──────────────────────────────────────────────────────────────

const MODELS: ReadonlySet<string> = new Set(['program', 'institution']);
const RAW_SQL_CALLEES: ReadonlySet<string> = new Set([
  '$queryRaw',
  '$queryRawUnsafe',
  '$executeRaw',
  '$executeRawUnsafe',
  'raw',
  'sql',
]);
/// Les noms de table, tels que Prisma les écrit en SQL (`"Program"`).
const CATALOG_TABLE_NAME = /\b(Program|Institution)\b/;
/// Ce qui ressemble à un CLIENT Prisma. Sert aux seules formes « sans appel » : une
/// propriété `file.institution` d'un objet de données (le catalogue JSON de
/// l'import) a la même forme qu'un alias `const d = tx.program`, et seul le
/// récepteur les distingue — un scanner sans types ne peut pas faire mieux. Un
/// ACCÈS (`x.program.findMany(…)`) n'a pas besoin de ce filtre : personne ne nomme
/// `findMany` une méthode d'un objet de données.
const PRISMA_CLIENT_RECEIVER =
  /^(?:this\.)?(?:prisma|prismaService|tx|db|client|transaction)$/;
const MODULE_UNIT = '<module>';

interface Access {
  readonly unit: string;
  readonly model: string;
  readonly method: string;
  readonly line: number;
}
interface Oddity {
  readonly unit: string;
  readonly form: string;
  readonly line: number;
}
interface ScanResult {
  readonly accesses: Access[];
  /** Les accès que le scanner ne sait pas suivre. */
  readonly oddities: Oddity[];
  readonly rawSql: Array<{ unit: string; line: number }>;
  /** Pour chaque unité (méthode, fonction), les noms qu'elle APPELLE. */
  readonly calls: Map<string, Set<string>>;
  /** Les fonctions déclarées dans le fichier. */
  readonly declared: Set<string>;
}

function isFunctionLike(node: ts.Node | undefined): boolean {
  return (
    node !== undefined &&
    (ts.isArrowFunction(node) || ts.isFunctionExpression(node))
  );
}

/**
 * Lit UN fichier source. Pur : aucune lecture disque, pour pouvoir le tester sur
 * des sources écrites à la main.
 */
function scanSource(source: string): ScanResult {
  const file = ts.createSourceFile(
    'scanned.ts',
    source,
    ts.ScriptTarget.Latest,
    true,
  );
  const result: ScanResult = {
    accesses: [],
    oddities: [],
    rawSql: [],
    calls: new Map(),
    declared: new Set(),
  };
  const lineOf = (node: ts.Node) =>
    file.getLineAndCharacterOfPosition(node.getStart(file)).line + 1;
  const callsOf = (unit: string) => {
    let calls = result.calls.get(unit);
    if (!calls) {
      calls = new Set();
      result.calls.set(unit, calls);
    }
    return calls;
  };

  /** Le nom de l'unité que ce nœud OUVRE, s'il en ouvre une. */
  const unitOpenedBy = (node: ts.Node): string | null => {
    if (
      ts.isMethodDeclaration(node) ||
      ts.isGetAccessorDeclaration(node) ||
      ts.isSetAccessorDeclaration(node)
    ) {
      return node.name.getText(file);
    }
    if (ts.isFunctionDeclaration(node)) return node.name?.text ?? '<anonyme>';
    if (ts.isConstructorDeclaration(node)) return 'constructor';
    if (ts.isPropertyDeclaration(node) && isFunctionLike(node.initializer)) {
      return node.name.getText(file);
    }
    if (
      ts.isVariableDeclaration(node) &&
      ts.isIdentifier(node.name) &&
      isFunctionLike(node.initializer)
    ) {
      return node.name.text;
    }
    return null;
  };

  /** `x.program` ou `x['program']` : le modèle nommé, sinon null. */
  const modelOf = (node: ts.Node): string | null => {
    if (ts.isPropertyAccessExpression(node) && MODELS.has(node.name.text)) {
      return node.name.text;
    }
    if (
      ts.isElementAccessExpression(node) &&
      ts.isStringLiteralLike(node.argumentExpression) &&
      MODELS.has(node.argumentExpression.text)
    ) {
      return node.argumentExpression.text;
    }
    return null;
  };

  const calleeName = (call: ts.CallExpression): string | null => {
    const callee = call.expression;
    if (ts.isIdentifier(callee)) return callee.text;
    if (ts.isPropertyAccessExpression(callee)) return callee.name.text;
    return null;
  };

  const visit = (node: ts.Node, unit: string): void => {
    // Seule l'unité la plus EXTÉRIEURE nomme : un rappel `(prisma) => …` dans une
    // méthode appartient à la méthode.
    const current = unit === MODULE_UNIT ? (unitOpenedBy(node) ?? unit) : unit;

    if (ts.isFunctionDeclaration(node) && node.name) {
      result.declared.add(node.name.text);
    }

    if (ts.isCallExpression(node)) {
      const name = calleeName(node);
      if (name) callsOf(current).add(name);

      // Un appel de méthode sur le délégué d'un modèle : `x.program.findMany(…)`.
      // L'arbre ne se soucie ni des retours à la ligne, ni de `?.`, ni des
      // arguments de type (`findMany<T>(…)`).
      if (ts.isPropertyAccessExpression(node.expression)) {
        const model = modelOf(node.expression.expression);
        if (model) {
          result.accesses.push({
            unit: current,
            model,
            method: node.expression.name.text,
            line: lineOf(node),
          });
        }
      }

      if (name && RAW_SQL_CALLEES.has(name)) {
        const text = node.arguments.map((arg) => arg.getText(file)).join(' ');
        if (CATALOG_TABLE_NAME.test(text)) {
          result.rawSql.push({ unit: current, line: lineOf(node) });
        }
      }
    }

    if (ts.isTaggedTemplateExpression(node)) {
      const tag = ts.isIdentifier(node.tag)
        ? node.tag.text
        : ts.isPropertyAccessExpression(node.tag)
          ? node.tag.name.text
          : null;
      if (
        tag &&
        RAW_SQL_CALLEES.has(tag) &&
        CATALOG_TABLE_NAME.test(node.template.getText(file))
      ) {
        result.rawSql.push({ unit: current, line: lineOf(node) });
      }
    }

    // Le délégué UTILISÉ AUTREMENT qu'appelé (`const d = tx.program`,
    // `const { program } = tx`) : le scanner ne suit pas un alias.
    const model = modelOf(node);
    if (
      model &&
      (ts.isPropertyAccessExpression(node) || ts.isElementAccessExpression(node)) &&
      PRISMA_CLIENT_RECEIVER.test(node.expression.getText(file))
    ) {
      const parent = node.parent;
      const isCalledThroughMethod =
        ts.isPropertyAccessExpression(parent) &&
        parent.expression === node &&
        ts.isCallExpression(parent.parent) &&
        parent.parent.expression === parent;
      if (!isCalledThroughMethod) {
        result.oddities.push({
          unit: current,
          form: `${model} utilisé sans appel de méthode`,
          line: lineOf(node),
        });
      }
    }
    if (
      ts.isBindingElement(node) &&
      ts.isObjectBindingPattern(node.parent) &&
      MODELS.has((node.propertyName ?? node.name).getText(file))
    ) {
      // `const { institution } = file` déstructure un objet de données ; seul
      // `const { program } = tx` (ou un paramètre typé Prisma) déstructure un client.
      const declaration = node.parent.parent;
      const source =
        ts.isVariableDeclaration(declaration) && declaration.initializer
          ? declaration.initializer.getText(file)
          : '';
      const typed =
        (ts.isParameter(declaration) || ts.isVariableDeclaration(declaration)) &&
        declaration.type !== undefined &&
        /Prisma/.test(declaration.type.getText(file));
      if (PRISMA_CLIENT_RECEIVER.test(source) || typed) {
        result.oddities.push({
          unit: current,
          form: `${(node.propertyName ?? node.name).getText(file)} déstructuré`,
          line: lineOf(node),
        });
      }
    }

    ts.forEachChild(node, (child) => visit(child, current));
  };

  visit(file, MODULE_UNIT);
  return result;
}

// ─── Le registre ─────────────────────────────────────────────────────────────

interface Door {
  /** Pourquoi ce fichier a le droit de lire ces tables. */
  readonly reason: string;
  /**
   * Pour chaque méthode qui accède aux tables : les fonctions de portée qu'elle
   * doit APPELER (toutes).
   */
  readonly scoped: Readonly<Record<string, readonly string[]>>;
  /** Les méthodes qui lisent SANS portée, voulu — ou `'*'` pour toutes les autres. */
  readonly unscoped?: readonly string[] | '*';
  /** Nombre d'accès attendu ; absent pour un fichier entièrement non borné. */
  readonly accesses?: number;
}

const DOORS: Readonly<Record<string, Door>> = {
  'modules/catalog/catalog.service.ts': {
    reason:
      'Le catalogue GÉNÉRAL : ce que les builds récentes chargent page après '
      + 'page, et les builds installées en un appel de 1 000 lignes. Il ne sert '
      + 'jamais une ligne de l’import. `getPrograms` lit aussi les identifiants '
      + 'des partenaires publiés (hors import), pour les servir en tête.',
    scoped: {
      getInstitutions: ['notEefInstitution'],
      getPrograms: ['notEefProgram', 'publicPartnerInstitutionWhere'],
    },
    accesses: 5,
  },
  'modules/matches/matches.service.ts': {
    reason:
      'Le moteur de recommandation : le repli sur tout le catalogue chargerait des '
      + 'milliers de lignes de l’import en concurrence avec les écoles partenaires.',
    scoped: {
      loadPrograms: ['notEefProgram'],
      loadInstitutions: ['notEefInstitution'],
    },
    accesses: 2,
  },
  'modules/etudes-en-france/search/eef-search.service.ts': {
    reason:
      'La recherche de l’espace EEF : elle sert les lignes de l’import, à '
      + 'condition que leur établissement soit publié. `cities` en est la '
      + 'liste complète des villes : mêmes clauses (`buildEefSearchWhere`), même '
      + 'liste d’établissements publiés — un compteur de ville doit être le total '
      + 'de la recherche qui la choisit.',
    scoped: {
      search: ['loadPublishedInstitutions'],
      cities: ['loadPublishedInstitutions'],
    },
    // Accès écrits dans le source. `search` : `findMany`, `count`, `groupBy` (une
    // fois, rejoué par facette), `findFirst`. `cities` : `groupBy`, `count`,
    // `findFirst`.
    accesses: 7,
  },
  'modules/etudes-en-france/shortlist/eef-shortlist.service.ts': {
    reason:
      'La shortlist de l’espace EEF : une recommandation nominative n’a pas le '
      + 'droit de s’appuyer sur un établissement que personne n’a relu.',
    scoped: { getShortlist: ['loadPublishedInstitutions'] },
    accesses: 2,
  },
  'modules/etudes-en-france/catalog/eef-published-institutions.ts': {
    reason:
      'C’est LUI qui définit la portée de l’espace EEF : la liste des '
      + 'établissements publiés. Il lit `Institution` pour la construire.',
    scoped: {},
    unscoped: ['loadPublishedInstitutions'],
    accesses: 1,
  },
  'modules/reports/reports.service.ts': {
    reason:
      'Le compteur « Action immédiate requise » : il doit compter les mêmes '
      + 'lignes que la file de revérification, lignes en attente exclues.',
    scoped: {
      getDashboardActivation: [
        'institutionVerificationDueWhere',
        'programVerificationDueWhere',
      ],
    },
    accesses: 2,
  },
  'modules/admin-catalog/admin-catalog.service.ts': {
    reason:
      'L’administration édite le catalogue : elle doit voir TOUT ce qui est en '
      + 'base, publié ou non — c’est son travail. Le seul de ses lecteurs qui '
      + 'sert une file ou une alarme (`collectVerificationDue`, d’où viennent la '
      + 'file, le SLA de 07 h) porte la définition partagée.',
    scoped: {
      collectVerificationDue: [
        'institutionVerificationDueWhere',
        'programVerificationDueWhere',
      ],
    },
    unscoped: '*',
  },
  'modules/etudes-en-france/publication/eef-publication.service.ts': {
    reason:
      'L’acte de PUBLICATION de l’import, par un administrateur : il lit et écrit '
      + 'les lignes de l’import, jamais le catalogue général. Sa portée est '
      + 'l’identifiant (préfixe de l’import) et l’établissement demandé, répétés '
      + 'dans le plan pur comme dans chaque écriture ; le plan est recalculé DANS la '
      + 'transaction, en `RepeatableRead`. Il relit aussi les formations DÉJÀ '
      + 'actives de l’établissement (sans filtre de préfixe : la recherche les '
      + 'sert), car activer l’établissement les rend visibles. Il ne sert rien à '
      + 'un étudiant.',
    scoped: {},
    unscoped: '*',
    accesses: 11,
  },
  'modules/etudes-en-france/catalog/eef-pending-purge.ts': {
    reason:
      'L’outil d’exploitation qui supprime les lignes de l’import JAMAIS '
      + 'publiées ni vérifiées. Il ne sert rien à personne : sa portée est le '
      + 'préfixe de l’import (`startsWith`) et l’état « inactive, jamais vérifiée », '
      + 'répétés dans chaque suppression — jamais une ligne du catalogue général.',
    scoped: {},
    unscoped: ['purgePendingEefRows'],
    accesses: 6,
  },
  'modules/etudes-en-france/catalog/eef-catalog.reconcile.db.ts': {
    reason:
      'L’outil d’exploitation qui réaligne les lignes de l’import DÉJÀ en base '
      + '(publiées ou en attente) sur les règles du dépôt. Il ne sert rien à '
      + 'personne : chaque lecture porte le préfixe de l’import (`startsWith`), et '
      + 'chaque écriture vise un identifiant ainsi lu en répétant son établissement '
      + 'et les quatre champs lus — jamais une ligne du catalogue général.',
    scoped: {},
    unscoped: ['planEefReconcile', 'applyEefReconcile'],
    accesses: 3,
  },
  'modules/community/community-catalog.service.ts': {
    reason:
      'La communauté (C1 + C2) : valider une mention @école / @formation, '
      + 'l’autocomplétion, et les hôtes des sites officiels (liste blanche des '
      + 'liens). Seules les fiches actives et jamais une ligne de l’import en '
      + 'attente : une mention ouvre une fiche, elle doit exister pour l’élève.',
    scoped: {
      resolveEntities: ['notPendingEefInstitution', 'notPendingEefProgram'],
      suggest: ['notPendingEefInstitution', 'notPendingEefProgram'],
      officialHosts: ['notPendingEefInstitution'],
    },
    accesses: 6,
  },
  'modules/competition-readiness/admin/admin-partnerships.service.ts': {
    reason:
      'Lecture par identifiant d’un établissement, par un administrateur qui gère '
      + 'un partenariat : il faut pouvoir le retrouver quel que soit son état.',
    scoped: {},
    unscoped: '*',
  },
};

// ─── L’arbre réel ────────────────────────────────────────────────────────────

const SRC_DIR = join(__dirname, '..');

/** Tous les `.ts` de production sous `src/`, specs exclus. */
function productionFiles(dir: string): string[] {
  return readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const path = join(dir, entry.name);
    if (entry.isDirectory()) return productionFiles(path);
    return entry.name.endsWith('.ts') && !entry.name.endsWith('.spec.ts')
      ? [path]
      : [];
  });
}

const SCOPE_FUNCTIONS = [
  ...new Set(Object.values(DOORS).flatMap((door) => Object.values(door.scoped).flat())),
];

/// Ne parse que ce qui peut compter : un fichier qui ne dit rien des tables, du
/// SQL brut ni d'une fonction de portée n'a rien à nous apprendre.
const CANDIDATE = new RegExp(
  [
    '\\b(?:program|institution|Program|Institution)\\b',
    '\\$queryRaw|\\$executeRaw|\\bsql\\b|\\braw\\b',
    ...SCOPE_FUNCTIONS.map((name) => `\\b${name.replace(/\$/g, '\\$')}\\b`),
  ].join('|'),
);

const scanned = productionFiles(SRC_DIR).flatMap((path) => {
  const text = readFileSync(path, 'utf8');
  if (!CANDIDATE.test(text)) return [];
  return [
    {
      key: relative(SRC_DIR, path).split(sep).join('/'),
      ...scanSource(text),
    },
  ];
});
const withAccess = scanned.filter((file) => file.accesses.length > 0);
const unitsOf = (file: { accesses: Access[] }) => [
  ...new Set(file.accesses.map((access) => access.unit)),
];

describe('provenance — aucune porte sans garde', () => {
  it('trouve bien des lecteurs — garde morte, sinon', () => {
    // Si le scanner se casse ou que le dossier change, la liste est vide et tous
    // les tests suivants passent sans rien garder. Le nombre est celui du
    // registre, pas un plancher calé sur ce que le scanner voit ce jour-là.
    expect(withAccess.map((file) => file.key).sort()).toEqual(
      Object.keys(DOORS).sort(),
    );
  });

  it('exige que TOUT fichier qui lit Program ou Institution soit déclaré, et inversement', () => {
    const seen = new Set(withAccess.map((file) => file.key));
    const undeclared = [...seen].filter((key) => !(key in DOORS));
    const dead = Object.keys(DOORS).filter((key) => !seen.has(key));

    expect({
      undeclared,
      dead,
      howTo:
        undeclared.length === 0 && dead.length === 0
          ? 'ok'
          : 'Un fichier qui lit Program ou Institution doit figurer dans DOORS avec '
            + 'la méthode qui lit et la fonction de portée qu’elle appelle '
            + '(notEefProgram, notEefInstitution, loadPublishedInstitutions…). '
            + 'Une entrée sans lecteur est un droit d’accès oublié : retire-la.',
    }).toEqual({ undeclared: [], dead: [], howTo: 'ok' });
  });

  it('exige que chaque MÉTHODE qui lit appelle sa fonction de portée', () => {
    const problems: string[] = [];
    for (const file of withAccess) {
      const door = DOORS[file.key];
      if (!door) continue;
      for (const unit of unitsOf(file)) {
        const required = door.scoped[unit];
        const allowedUnscoped =
          door.unscoped === '*' || (door.unscoped ?? []).includes(unit);
        if (required === undefined) {
          if (!allowedUnscoped) {
            problems.push(
              `${file.key} › ${unit} : lit Program/Institution sans être déclarée `
                + '(ni « scoped » avec sa fonction de portée, ni « unscoped » avec une raison).',
            );
          }
          continue;
        }
        const called = file.calls.get(unit) ?? new Set<string>();
        for (const token of required) {
          if (!called.has(token)) {
            problems.push(
              `${file.key} › ${unit} : ne APPELLE pas ${token}() — un import ou un `
                + 'commentaire ne garde rien.',
            );
          }
        }
      }
    }
    expect(problems).toEqual([]);
  });

  it('ne garde pas de méthode qui ne lit plus', () => {
    // Une entrée `scoped` dont la méthode n'accède plus aux tables affirmerait une
    // garde sur rien — et cacherait qu'elle a été déplacée.
    const dead: string[] = [];
    for (const file of withAccess) {
      const door = DOORS[file.key];
      if (!door) continue;
      const reading = new Set(unitsOf(file));
      for (const unit of Object.keys(door.scoped)) {
        if (!reading.has(unit)) dead.push(`${file.key} › ${unit}`);
      }
      if (Array.isArray(door.unscoped)) {
        for (const unit of door.unscoped) {
          if (!reading.has(unit)) dead.push(`${file.key} › ${unit} (unscoped)`);
        }
      }
    }
    expect(dead).toEqual([]);
  });

  it('épingle le nombre d’accès de chaque fichier gardé', () => {
    // Ajouter une requête dans une méthode déjà gardée ne la rend pas gardée : sa
    // clause peut oublier la portée. L'épingle oblige à le reconnaître ici.
    const wrong = withAccess
      .filter((file) => DOORS[file.key]?.accesses !== undefined)
      .filter((file) => file.accesses.length !== DOORS[file.key].accesses)
      .map((file) => ({
        file: file.key,
        declared: DOORS[file.key].accesses,
        found: file.accesses.length,
        lines: file.accesses.map((access) => access.line),
      }));
    expect(wrong).toEqual([]);
  });

  it('refuse tout accès que le scanner ne sait pas suivre', () => {
    // Un alias (`const d = tx.program`), une déstructuration (`const { program } =
    // tx`) ou une valeur passée en argument échappent à la vérification par
    // méthode : la seule réponse honnête est de les refuser.
    const odd = scanned.flatMap((file) =>
      file.oddities.map((o) => `${file.key}:${o.line} ${o.form} (${o.unit})`),
    );
    expect(odd).toEqual([]);
  });

  it('ne tolère aucun SQL brut sur ces tables', () => {
    // Le SQL brut ignore toute clause Prisma. S'il devient nécessaire, il faut
    // écrire la garde à la main ET l'ajouter à ce test.
    const raw = scanned.flatMap((file) =>
      file.rawSql.map((r) => `${file.key}:${r.line} (${r.unit})`),
    );
    expect(raw).toEqual([]);
  });

  it('exige une raison de chaque entrée', () => {
    for (const [key, door] of Object.entries(DOORS)) {
      expect({ key, hasReason: door.reason.trim().length > 0 }).toEqual({
        key,
        hasReason: true,
      });
    }
  });

  it('ne compte que des fonctions de portée qui existent encore', () => {
    // Une fonction renommée rendrait les vérifications ci-dessus vraies pour
    // personne, ou fausses pour tout le monde, sans que rien ne le dise. Elle doit
    // être DÉCLARÉE quelque part, pas seulement nommée dans un texte.
    const declared = new Set(scanned.flatMap((file) => [...file.declared]));
    const missing = SCOPE_FUNCTIONS.filter((name) => !declared.has(name));
    expect(missing).toEqual([]);
  });
});

// ─── Le scanner se teste lui-même ────────────────────────────────────────────

describe('le scanner des portes — il voit ce qu’il doit voir', () => {
  const accessesOf = (source: string) =>
    scanSource(source).accesses.map((a) => `${a.unit}:${a.model}.${a.method}`);

  it('voit un accès dans une méthode, avec son nom', () => {
    expect(
      accessesOf(`class A { async load(tx) { return tx.program.findMany({}); } }`),
    ).toEqual(['load:program.findMany']);
  });

  it('voit une chaîne coupée sur deux lignes', () => {
    // La forme existe déjà dans le dépôt pour d'autres modèles : une regex sur
    // `.program.findMany(` ne la voyait pas.
    expect(
      accessesOf(`class A { async m(tx) {
        return tx.program
          .findMany({});
      } }`),
    ).toEqual(['m:program.findMany']);
  });

  it('voit un accès avec `?.` et un argument de type', () => {
    expect(
      accessesOf(`class A { m(tx) { return tx?.institution?.findMany<Row>({}); } }`),
    ).toEqual(['m:institution.findMany']);
  });

  it('voit un accès par crochets', () => {
    expect(
      accessesOf(`class A { m(tx) { return tx['program'].count(); } }`),
    ).toEqual(['m:program.count']);
  });

  it('voit aussi les écritures : `update`, `upsert` renvoient la ligne', () => {
    expect(
      accessesOf(`class A { m(tx) { return tx.program.upsert({}); } }`),
    ).toEqual(['m:program.upsert']);
  });

  it('nomme l’unité la plus extérieure, pas le rappel', () => {
    expect(
      accessesOf(`class A { m(client) { return client.execute((db) => db.program.count()); } }`),
    ).toEqual(['m:program.count']);
  });

  it('nomme une fonction fléchée de propriété, une fonction de module, le module', () => {
    expect(
      accessesOf(`class A { run = async (tx) => tx.program.count(); }`),
    ).toEqual(['run:program.count']);
    expect(
      accessesOf(`const load = async (tx) => tx.institution.findMany({});`),
    ).toEqual(['load:institution.findMany']);
    expect(accessesOf(`prisma.program.findMany({});`)).toEqual([
      '<module>:program.findMany',
    ]);
  });

  it('CAS QUI L’A PRIS EN DÉFAUT : un `/*` dans un commentaire de ligne', () => {
    // La regex d'avant retirait les blocs `/* … */` AVANT les lignes `//` : le
    // `/*` de la première ligne ouvrait un faux bloc, fermé par le `*/` du
    // commentaire final, et le code du milieu disparaissait. Le catalogue général
    // et la recherche étaient invisibles au cliquet qui devait les garder.
    const source = `
      // Les routes sont sous /etudes-en-france/*
      class A {
        async load(tx) {
          return tx.program.findMany({});
        }
      }
      /* fin de fichier */
    `;
    expect(accessesOf(source)).toEqual(['load:program.findMany']);
  });

  it('ne compte pas ce qui n’est qu’un commentaire ou une chaîne', () => {
    expect(
      accessesOf(`
        // tx.program.findMany({});
        /* tx.institution.count() */
        const doc = 'tx.program.findMany()';
        const tpl = \`tx.institution.findMany()\`;
      `),
    ).toEqual([]);
  });

  it('distingue un APPEL de la fonction de portée d’un simple import ou d’un commentaire', () => {
    const scan = scanSource(`
      import { notEefProgram } from './eef-provenance';
      // notEefProgram()
      class A {
        m(tx) { return tx.program.findMany({}); }
        n(tx) { return tx.program.findMany({ where: { ...notEefProgram() } }); }
      }
    `);
    expect(scan.calls.get('m')?.has('notEefProgram') ?? false).toBe(false);
    expect(scan.calls.get('n')?.has('notEefProgram')).toBe(true);
  });

  it('compte un appel fait dans un rappel de la méthode', () => {
    const scan = scanSource(`
      class A {
        m(prisma) {
          return prisma.execute(async (db) => db.program.count({ where: notEefProgram() }));
        }
      }
    `);
    expect(scan.calls.get('m')?.has('notEefProgram')).toBe(true);
  });

  it('refuse un alias et une déstructuration du délégué', () => {
    const oddities = (source: string) =>
      scanSource(source).oddities.map((o) => o.form);
    expect(oddities(`class A { m(tx) { const d = tx.program; return d.findMany(); } }`)).toEqual([
      'program utilisé sans appel de méthode',
    ]);
    expect(oddities(`class A { m(tx) { const { program } = tx; return program.findMany(); } }`)).toEqual([
      'program déstructuré',
    ]);
    expect(oddities(`class A { m(tx) { const { institution: inst } = tx; return inst; } }`)).toEqual([
      'institution déstructuré',
    ]);
  });

  it('refuse aussi l’alias par `this.prisma` et la déstructuration d’un paramètre typé', () => {
    const oddities = (source: string) =>
      scanSource(source).oddities.map((o) => o.form);
    expect(
      oddities(`class A { m() { const d = this.prisma.program; return d; } }`),
    ).toEqual(['program utilisé sans appel de méthode']);
    expect(
      oddities(`class A { m({ program }: PrismaClient) { return program.count(); } }`),
    ).toEqual(['program déstructuré']);
  });

  it('ne refuse pas la propriété d’un OBJET DE DONNÉES qui porte le même nom', () => {
    // `file.institution` (le catalogue JSON de l'import) a la forme d'un alias de
    // délégué. Sans ce cas le scanner refusait l'importeur et le validateur, qui ne
    // touchent aucune base.
    const oddities = (source: string) =>
      scanSource(source).oddities.map((o) => o.form);
    expect(
      oddities(`function plan(file) { const institution = file.institution; return institution; }`),
    ).toEqual([]);
    expect(
      oddities(`function plan(file) { const { institution } = file; return institution; }`),
    ).toEqual([]);
  });

  it('ne refuse pas un accès normal', () => {
    expect(
      scanSource(`class A { m(tx) { return tx.program.findMany({}); } }`).oddities,
    ).toEqual([]);
  });

  it('repère le SQL brut sur ces tables, quelle que soit sa forme', () => {
    const raw = (source: string) => scanSource(source).rawSql.length;
    expect(raw('class A { m(tx) { return tx.$queryRaw`SELECT * FROM "public"."Program"`; } }')).toBe(1);
    expect(raw('class A { m(tx) { return tx.$queryRawUnsafe(\'SELECT * FROM "Institution"\'); } }')).toBe(1);
    expect(raw('class A { m() { return Prisma.sql`SELECT 1 FROM "Program" p, "Institution" i`; } }')).toBe(1);
    // Du SQL brut sur d'autres tables n'est pas notre affaire.
    expect(raw('class A { m(tx) { return tx.$queryRaw`SELECT * FROM "Scholarship"`; } }')).toBe(0);
    // Un message d'erreur qui contient le mot n'est pas du SQL.
    expect(raw('class A { m() { throw new Error("Institution not found"); } }')).toBe(0);
  });

  it('relève les fonctions déclarées', () => {
    expect(
      [...scanSource('export function notEefProgram() { return 1; }').declared],
    ).toEqual(['notEefProgram']);
  });
});
