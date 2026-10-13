# Phase 2 — Scénario E2E (conversion France)

Objectif spec : **inscription → onboarding → quiz France → verdict éligible → demande pré-remplie ECE Lyon → soumission → timeline « Soumise »** en moins de 5 minutes.

## Prérequis backend

```bash
cd backend
npm run seed:catalog            # pays M5 + catalogue unique
npm run import:omnes:bundled    # régénère le JSON depuis scripts/data/omnes_fall_26.xlsx
npm run seed:omnes              # formations OMNES (seed:catalog ne les sème plus)
npm run dev
```

Vérifier : `GET /api/catalog/programs?limit=5` retourne des programmes `omnes-p-*`.

## Prérequis mobile

```bash
flutter run \
  --dart-define=KPB_ENABLE_REMOTE_SYNC=true \
  --dart-define=KPB_API_BASE_URL=http://127.0.0.1:4000/api
```

## Parcours manuel (checklist)

### 1. Onboarding (M2)
- [ ] Compléter les 6 étapes (ou reprendre si déjà partiel)
- [ ] Choisir **France** dans les pays cibles
- [ ] Activer les notifications (optionnel)

### 2. Quiz éligibilité France (M5)
- [ ] Accueil → **Destinations** → **France**
- [ ] Tap **Faire le quiz d'éligibilité**
- [ ] Répondre pour obtenir un verdict **Éligible** ou **Éligible sous conditions**
- [ ] Tap CTA principal → le tunnel s'ouvre avec :
  - Pays : France
  - École : ECE — Lyon (si catalogue OMNES sync)
  - Programme : ex. Bachelor ECE Lyon

### 3. Tunnel demande 5 étapes (M8)
- [ ] Étape 1 : **Inscription école** (pré-sélectionné)
- [ ] Étape 2 : contexte pré-rempli (France / ECE / programme)
- [ ] Étape 3 : documents (optionnel)
- [ ] Étape 4 : message libre
- [ ] Étape 5 : confirmation → **Soumettre**

### 4. Mes demandes + timeline (M14)
- [ ] Onglet **Demandes** → la nouvelle demande apparaît en tête
- [ ] Statut badge : **Envoyé** / Soumise
- [ ] Ouvrir le détail → timeline M14 :
  - ✅ **Soumise** (date du jour)
  - 🔄 étape courante suivante
  - ⏸ étapes à venir
- [ ] (Remote sync) Push « Demande reçue ✅ » si FCM configuré

### 5. Recherche universités (M6)
- [ ] Onglet **Universités** → **Partenaires KPB ⭐**
- [ ] Filtrer pays **France**, budget ≤ 10 000 €
- [ ] Vérifier présence programmes ECE Lyon
- [ ] Tap **Voir détails** → fiche programme → **M'inscrire avec KPB**

## Critères de succès

| Étape | Attendu |
|-------|---------|
| Catalogue | ≥ 700 programmes après `seed:omnes` |
| Quiz CTA | Pré-remplit pays + ECE Lyon quand disponible |
| Soumission | Statut `submitted`, code `KPB-YYYY-NNN` |
| Timeline | 1ère étape ✅ Soumise avec date |
| Durée | < 5 min sur device réel |

## Dépannage

| Problème | Action |
|----------|--------|
| Quiz indisponible | `npm run seed:countries-m5` |
| Pas de programmes ECE | `npm run seed:omnes` + pull-to-refresh app |
| Tunnel bloqué « Profil incomplet » | Terminer onboarding M2 |
| Sync API échoue | Vérifier auth + `KPB_API_BASE_URL` |

## Tests automatisés

```bash
flutter test test/features/program_recommendation_test.dart
flutter test test/features/timeline_crash_test.dart
```
