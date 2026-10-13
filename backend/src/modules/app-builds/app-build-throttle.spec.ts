import {
  AppBuildThrottle,
  DEFAULT_APP_BUILD_THROTTLE,
} from './app-build-throttle';

const HOUR = 60 * 60 * 1000;
const MINUTE = 60 * 1000;
const T0 = Date.UTC(2026, 9, 13, 12, 0, 0);

const b54 = { version: '2.3.0', build: 54 };
const b56 = { version: '2.3.0', build: 56 };
const none = { version: null, build: null };

describe('AppBuildThrottle', () => {
  it('garde les valeurs demandées par le chantier : 6 h, 50 000 comptes', () => {
    expect(DEFAULT_APP_BUILD_THROTTLE.refreshIntervalMs).toBe(6 * HOUR);
    expect(DEFAULT_APP_BUILD_THROTTLE.maxEntries).toBe(50_000);
  });

  it('écrit la première requête d’un compte, pas les suivantes', () => {
    const throttle = new AppBuildThrottle();
    expect(throttle.shouldWrite('p1', b54, T0)).toBe(true);
    // Les requêtes parallèles d'un démarrage d'app : une seule écriture.
    expect(throttle.shouldWrite('p1', b54, T0)).toBe(false);
    expect(throttle.shouldWrite('p1', b54, T0 + 5 * HOUR)).toBe(false);
    // Les comptes sont indépendants.
    expect(throttle.shouldWrite('p2', b54, T0)).toBe(true);
  });

  it('réécrit une même valeur une fois le délai de 6 h écoulé', () => {
    const throttle = new AppBuildThrottle();
    throttle.shouldWrite('p1', b54, T0);
    expect(throttle.shouldWrite('p1', b54, T0 + 6 * HOUR - 1)).toBe(false);
    expect(throttle.shouldWrite('p1', b54, T0 + 6 * HOUR)).toBe(true);
    // Le délai repart de la dernière écriture.
    expect(throttle.shouldWrite('p1', b54, T0 + 7 * HOUR)).toBe(false);
    expect(throttle.shouldWrite('p1', b54, T0 + 12 * HOUR)).toBe(true);
  });

  it('écrit une mise à jour sans attendre 6 h, mais pas plus d’une fois par minute', () => {
    const throttle = new AppBuildThrottle();
    throttle.shouldWrite('p1', b54, T0);
    // La mise à jour arrive 30 s plus tard : retenue…
    expect(throttle.shouldWrite('p1', b56, T0 + 30 * 1000)).toBe(false);
    // …et écrite à la requête suivante passé la minute.
    expect(throttle.shouldWrite('p1', b56, T0 + MINUTE)).toBe(true);
    expect(throttle.shouldWrite('p1', b56, T0 + 2 * MINUTE)).toBe(false);
  });

  it('borne un client qui alternerait deux valeurs à une écriture par minute', () => {
    const throttle = new AppBuildThrottle();
    let writes = 0;
    for (let second = 0; second < 10 * 60; second += 1) {
      const reading = second % 2 === 0 ? b54 : b56;
      if (throttle.shouldWrite('p1', reading, T0 + second * 1000)) writes += 1;
    }
    expect(writes).toBeLessThanOrEqual(10);
  });

  it('un changement de version seule compte aussi comme une mise à jour', () => {
    const throttle = new AppBuildThrottle();
    throttle.shouldWrite('p1', { version: '2.3.0', build: null }, T0);
    expect(
      throttle.shouldWrite('p1', { version: '2.4.0', build: null }, T0 + MINUTE),
    ).toBe(true);
  });

  it('une requête sans en-tête ne passe pas pour un changement', () => {
    // Une build 54 dont un appel part sans en-tête (lecture de version
    // échouée) ne doit pas faire alterner « 54 » et « inconnu ».
    const throttle = new AppBuildThrottle();
    throttle.shouldWrite('p1', b54, T0);
    expect(throttle.shouldWrite('p1', none, T0 + 2 * MINUTE)).toBe(false);
    expect(throttle.shouldWrite('p1', b54, T0 + 3 * MINUTE)).toBe(false);
  });

  it('un compte sans en-tête est tout de même rafraîchi toutes les 6 h', () => {
    const throttle = new AppBuildThrottle();
    expect(throttle.shouldWrite('p53', none, T0)).toBe(true);
    expect(throttle.shouldWrite('p53', none, T0 + HOUR)).toBe(false);
    expect(throttle.shouldWrite('p53', none, T0 + 6 * HOUR)).toBe(true);
  });

  it('un compte passé d’une 53 à une 56 est écrit dès la minute écoulée', () => {
    const throttle = new AppBuildThrottle();
    throttle.shouldWrite('p1', none, T0);
    expect(throttle.shouldWrite('p1', b56, T0 + MINUTE)).toBe(true);
  });

  it('une horloge qui recule déclenche une écriture, puis la règle reprend', () => {
    const throttle = new AppBuildThrottle();
    throttle.shouldWrite('p1', b54, T0);
    expect(throttle.shouldWrite('p1', b54, T0 - 10 * 1000)).toBe(true);
    expect(throttle.shouldWrite('p1', b54, T0)).toBe(false);
  });

  it('plafonne la mémoire en oubliant le compte le moins récemment vu', () => {
    const throttle = new AppBuildThrottle({
      ...DEFAULT_APP_BUILD_THROTTLE,
      maxEntries: 3,
    });
    throttle.shouldWrite('a', b54, T0);
    throttle.shouldWrite('b', b54, T0);
    throttle.shouldWrite('c', b54, T0);
    // `a` est revu (sans écriture) : c'est désormais `b` le plus ancien.
    expect(throttle.shouldWrite('a', b54, T0 + 1000)).toBe(false);
    throttle.shouldWrite('d', b54, T0 + 2000);

    expect(throttle.size).toBe(3);
    // `a` est resté en mémoire : toujours retenu.
    expect(throttle.shouldWrite('a', b54, T0 + 3000)).toBe(false);
    // `b` a été oublié : il est réécrit, et pousse dehors le suivant.
    expect(throttle.shouldWrite('b', b54, T0 + 4000)).toBe(true);
    expect(throttle.size).toBe(3);
  });
});
