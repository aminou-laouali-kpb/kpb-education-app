// Classement public de la compétition des ambassadeurs.
//
// Fichier externe : la CSP du site (default-src 'self') bloque les scripts
// inline. Aucune insertion de HTML venant de l'API : tout passe par
// textContent. La page ne lit QUE quatre champs par ligne (rang, nom public,
// ville, nombre) — `toViewModel` les recopie un à un, si bien qu'un champ de
// trop dans la réponse ne pourrait jamais s'afficher. Idem pour les lauréats
// (rang du prix, montant, nom public, ville).
//
// Correctifs 57 : campagne close, le podium montre les lauréats EFFECTIFS
// servis par l'API (`winners`) — un prix déclaré forfait apparaît chez celui
// qui l'a reçu — tandis que la liste garde l'ordre réel du classement.
//
// Écrit en ES5 (var, function) : la page doit marcher sur les navigateurs
// d'entrée de gamme du public visé.
(function (root) {
  'use strict';

  var DEFAULT_SLUG = 'ambassadeurs-novembre-2026';
  var DEFAULT_API = 'https://api.kpbeducation.cloud/api';
  var REFRESH_MS = 60000;

  function stripAccents(s) {
    var str = String(s || '');
    if (str.normalize) str = str.normalize('NFD');
    return str
      .replace(/[\u0300-\u036f]/g, '')
      .toLowerCase()
      .trim();
  }

  function toInt(v) {
    var n = Number(v);
    return isFinite(n) ? Math.max(0, Math.floor(n)) : 0;
  }

  /** Réponse de l'API → modèle d'affichage fermé (aucun autre champ ne passe). */
  function toViewModel(payload) {
    var c = (payload && payload.campaign) || {};
    var entries = (payload && payload.entries) || [];
    return {
      name: String(c.nameFr || 'Compétition des ambassadeurs'),
      status: String(c.status || ''),
      phase: String(c.phase || ''),
      startsAt: String(c.startsAt || ''),
      endsAt: String(c.endsAt || ''),
      startDate: String(c.startDate || ''),
      endDate: String(c.endDate || ''),
      provisional: c.provisional !== false,
      rulesUrl: /^https:\/\//.test(String(c.rulesUrl || '')) ? String(c.rulesUrl) : '',
      updatedAt: String(c.updatedAt || ''),
      prizes: (c.prizes || []).map(function (p) {
        return { rank: toInt(p.rank), amountFcfa: toInt(p.amountFcfa) };
      }),
      serverTime: String((payload && payload.serverTime) || ''),
      entries: entries.map(function (e) {
        return {
          rank: e.rank === null || e.rank === undefined ? null : toInt(e.rank),
          name: String(e.name || ''),
          city: String(e.city || ''),
          qualified: toInt(e.qualified),
        };
      }),
      winners: ((payload && payload.winners) || []).map(function (w) {
        return {
          prizeRank: toInt(w.prizeRank),
          amountFcfa: toInt(w.amountFcfa),
          name: String(w.name || ''),
          city: String(w.city || ''),
        };
      }),
    };
  }

  /**
   * Les cartes du podium : les lauréats effectifs quand l'API les sert
   * (campagne close), sinon les trois premiers du classement provisoire avec
   * le prix de leur rang.
   */
  function podiumOf(vm) {
    if (vm.winners && vm.winners.length) {
      return vm.winners
        .filter(function (w) {
          return w.prizeRank >= 1 && w.prizeRank <= 3;
        })
        .map(function (w) {
          var entry = vm.entries.filter(function (e) {
            return e.name === w.name && e.city === w.city;
          })[0];
          return {
            rank: w.prizeRank,
            name: w.name,
            city: w.city,
            qualified: entry ? entry.qualified : null,
            amountFcfa: w.amountFcfa,
          };
        });
    }
    return vm.entries
      .filter(function (e) {
        return e.rank !== null && e.rank <= 3;
      })
      .map(function (e) {
        var prize = vm.prizes.filter(function (p) {
          return p.rank === e.rank;
        })[0];
        return {
          rank: e.rank,
          name: e.name,
          city: e.city,
          qualified: e.qualified,
          amountFcfa: prize ? prize.amountFcfa : null,
        };
      });
  }

  /** Filtre par nom (sans accents ni casse) et par ville. */
  function filterEntries(entries, query, city) {
    var q = stripAccents(query);
    var c = stripAccents(city);
    return entries.filter(function (e) {
      if (c && stripAccents(e.city) !== c) return false;
      if (q && stripAccents(e.name).indexOf(q) < 0) return false;
      return true;
    });
  }

  function citiesOf(entries) {
    var seen = {};
    var out = [];
    entries.forEach(function (e) {
      if (e.city && !seen[e.city]) {
        seen[e.city] = true;
        out.push(e.city);
      }
    });
    return out.sort(function (a, b) {
      return a.localeCompare(b, 'fr');
    });
  }

  function pad(n) {
    return n < 10 ? '0' + n : String(n);
  }

  /** Millisecondes → « 3 j 04 h 12 min 09 s ». */
  function formatCountdown(ms) {
    if (!(ms > 0)) return '0 s';
    var s = Math.floor(ms / 1000);
    var d = Math.floor(s / 86400);
    var h = Math.floor((s % 86400) / 3600);
    var m = Math.floor((s % 3600) / 60);
    var sec = s % 60;
    return (d > 0 ? d + ' j ' : '') + pad(h) + ' h ' + pad(m) + ' min ' + pad(sec) + ' s';
  }

  function formatFcfa(n) {
    return String(n).replace(/\B(?=(\d{3})+(?!\d))/g, ' ') + ' FCFA';
  }

  /** Libellé et cible du compte à rebours à l'instant `now` (ms). */
  function countdownTarget(vm, now) {
    var start = Date.parse(vm.startsAt);
    var end = Date.parse(vm.endsAt);
    if (vm.status === 'closed') return { label: 'Compétition terminée — résultats validés', target: null };
    if (isFinite(start) && now < start) return { label: 'La compétition commence dans', target: start };
    if (isFinite(end) && now < end && vm.status === 'live') return { label: 'Fin de la compétition dans', target: end };
    return { label: 'Compétition terminée — vérification en cours', target: null };
  }

  var api = {
    toViewModel: toViewModel,
    podiumOf: podiumOf,
    filterEntries: filterEntries,
    citiesOf: citiesOf,
    formatCountdown: formatCountdown,
    formatFcfa: formatFcfa,
    countdownTarget: countdownTarget,
    stripAccents: stripAccents,
  };

  if (typeof module !== 'undefined' && module.exports) {
    module.exports = api;
    return;
  }

  // ── Navigateur ────────────────────────────────────────────────────────────
  var doc = root.document;
  var $ = function (id) {
    return doc.getElementById(id);
  };
  var params = new URLSearchParams(root.location.search);
  var slug = (params.get('c') || DEFAULT_SLUG).replace(/[^a-z0-9-]/g, '').slice(0, 61) || DEFAULT_SLUG;
  var meta = doc.querySelector('meta[name="kpb-api"]');
  var apiBase = (meta && meta.getAttribute('content')) || DEFAULT_API;
  var local = /^(localhost|127\.0\.0\.1)$/.test(root.location.hostname);
  if (local && params.get('api')) apiBase = params.get('api');

  var state = { vm: null, offset: 0, timer: null };

  function text(el, value) {
    el.textContent = value;
    return el;
  }

  function el(tag, cls, value) {
    var node = doc.createElement(tag);
    if (cls) node.className = cls;
    if (value !== undefined) node.textContent = value;
    return node;
  }

  function renderPodium(vm) {
    var podium = $('podium');
    while (podium.firstChild) podium.removeChild(podium.firstChild);
    var top = podiumOf(vm);
    if (!top.length) {
      podium.hidden = true;
      return;
    }
    top.forEach(function (e) {
      var card = el('div', 'lb-step lb-step-' + e.rank);
      card.appendChild(el('span', 'lb-medal', String(e.rank)));
      card.appendChild(el('strong', 'lb-step-name', e.name));
      card.appendChild(el('span', 'lb-step-city', e.city));
      if (e.qualified !== null) {
        card.appendChild(el('span', 'lb-step-count', e.qualified + (e.qualified > 1 ? ' filleuls' : ' filleul')));
      }
      if (e.amountFcfa !== null) card.appendChild(el('span', 'lb-step-prize', formatFcfa(e.amountFcfa)));
      podium.appendChild(card);
    });
    podium.hidden = false;
  }

  function renderList() {
    var vm = state.vm;
    if (!vm) return;
    var list = $('list');
    while (list.firstChild) list.removeChild(list.firstChild);
    var shown = filterEntries(vm.entries, $('search').value, $('city').value);
    shown.forEach(function (e) {
      var li = el('li', 'lb-row');
      li.appendChild(el('span', 'lb-rank', e.rank === null ? '—' : String(e.rank)));
      var who = el('span', 'lb-who');
      who.appendChild(el('strong', null, e.name));
      if (e.city) who.appendChild(el('span', 'lb-city', ' — ' + e.city));
      li.appendChild(who);
      li.appendChild(el('span', 'lb-count', String(e.qualified)));
      list.appendChild(li);
    });
    $('empty').hidden = shown.length > 0 || vm.entries.length === 0;
  }

  function renderCities(vm) {
    var select = $('city');
    var current = select.value;
    while (select.options.length > 1) select.remove(1);
    citiesOf(vm.entries).forEach(function (c) {
      var o = el('option', null, c);
      o.value = c;
      select.appendChild(o);
    });
    select.value = current;
  }

  function tick() {
    var vm = state.vm;
    if (!vm) return;
    var now = Date.now() + state.offset;
    var t = countdownTarget(vm, now);
    $('countdown-card').hidden = false;
    text($('countdown-label'), t.label);
    text($('countdown-value'), t.target ? formatCountdown(t.target - now) : '');
  }

  function render(vm) {
    state.vm = vm;
    var server = Date.parse(vm.serverTime);
    state.offset = isFinite(server) ? server - Date.now() : 0;
    text($('campaign-name'), vm.name);
    text(
      $('campaign-status'),
      'Du ' + vm.startDate + ' au ' + vm.endDate + ' (heure d’Afrique de l’Ouest, UTC+1)' +
        (vm.prizes.length
          ? ' · Prix : ' +
            vm.prizes
              .map(function (p) {
                return p.rank + (p.rank === 1 ? 'er' : 'e') + ' ' + formatFcfa(p.amountFcfa);
              })
              .join(', ')
          : '')
    );
    $('provisional').hidden = !vm.provisional;
    $('error-card').hidden = true;
    renderPodium(vm);
    renderCities(vm);
    renderList();
    $('board-card').hidden = false;
    text(
      $('updated'),
      vm.updatedAt ? 'Mis à jour le ' + new Date(vm.updatedAt).toLocaleString('fr-FR') : ''
    );
    var rules = $('rules');
    if (vm.rulesUrl) {
      rules.href = vm.rulesUrl;
      rules.hidden = false;
    }
    tick();
  }

  function fail(message) {
    text($('campaign-status'), '');
    text($('error-text'), message);
    $('error-card').hidden = false;
  }

  function load() {
    var url = apiBase.replace(/\/+$/, '') + '/public/campaigns/' + encodeURIComponent(slug) + '/leaderboard';
    fetch(url, { credentials: 'omit' })
      .then(function (res) {
        if (res.status === 404) throw new Error('not_found');
        if (!res.ok) throw new Error('http_' + res.status);
        return res.json();
      })
      .then(function (payload) {
        render(toViewModel(payload));
      })
      .catch(function (err) {
        if (state.vm) return; // une panne passagère garde le dernier classement
        fail(
          err && err.message === 'not_found'
            ? 'Cette compétition n’existe pas ou n’a pas encore commencé.'
            : 'Le classement ne répond pas pour le moment. Réessaie dans quelques minutes.'
        );
      });
  }

  function share() {
    var link = root.location.origin + '/classement/?c=' + encodeURIComponent(slug);
    var shareText = 'Le classement des ambassadeurs KPB Education : ' + link;
    if (root.navigator.share) {
      root.navigator.share({ title: doc.title, text: shareText, url: link }).catch(function () {});
      return;
    }
    if (root.navigator.clipboard) {
      root.navigator.clipboard.writeText(link).then(function () {
        $('share-done').hidden = false;
      });
      return;
    }
    root.location.href = 'https://wa.me/?text=' + encodeURIComponent(shareText);
  }

  function start() {
    $('search').addEventListener('input', renderList);
    $('city').addEventListener('change', renderList);
    $('share').addEventListener('click', share);
    load();
    root.setInterval(load, REFRESH_MS);
    root.setInterval(tick, 1000);
  }

  if (doc.readyState === 'loading') doc.addEventListener('DOMContentLoaded', start);
  else start();
})(typeof window !== 'undefined' ? window : this);
