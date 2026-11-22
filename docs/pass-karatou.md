# Pass Karatou : accès après paiement hors de l'app

Le Pass s'achète hors de l'app (mobile money, via un commercial). L'app ne vend
rien : elle lit seulement si un accès couvre l'instant présent. Les vidéos des
cours restent publiques sur YouTube ; le verrou ne vaut QUE dans l'app (décision
du propriétaire, 22/11/2026 : quelqu'un qui trouve le lien YouTube peut regarder).

## Le parcours

1. L'élève discute avec un commercial (WhatsApp ou messagerie de l'app).
2. Il paie par mobile money et envoie son reçu.
3. Le commercial remplit le formulaire n8n (ou, en secours, la page
   **Pass Karatou** de l'admin).
4. n8n appelle le webhook ; le serveur ouvre l'accès et notifie l'élève.

## Le webhook (n8n)

`POST https://api.kpbeducation.cloud/api/integrations/pass/grant`

En-têtes :

| En-tête | Valeur |
|---|---|
| `Content-Type` | `application/json` |
| `X-KPB-Webhook-Secret` | la valeur de `KPB_PASS_WEBHOOK_SECRET` du serveur |

Corps :

```json
{
  "email": "eleve@exemple.com",
  "durationDays": 30,
  "paymentReference": "OM-2611-4455",
  "amountXof": 15000,
  "salesAgent": "Moussa",
  "note": "facultatif"
}
```

- `email` : l'adresse avec laquelle l'élève se connecte à l'app.
- `durationDays` : 1 à 730.
- `paymentReference` : celle du reçu. Comparée sur ses seules lettres et
  chiffres : « OM-2611-4455 » et « om 2611 4455 » sont le même paiement.
- Tout autre champ est refusé (400) : ne transmettez que ces six-là.

Réponses :

| Code | Sens | À afficher au commercial |
|---|---|---|
| 200 `granted` | Accès ouvert | `account.fullName`, `account.email`, `activeUntil` : **vérifier que c'est la bonne personne** |
| 200 `already_granted` | Ce paiement avait déjà ouvert l'accès ; rien n'est ajouté | idem |
| 400 | Champ invalide | le `message` |
| 401 | Secret absent ou faux | — |
| 404 `ACCOUNT_NOT_FOUND` | Aucun compte avec cet e-mail | demander l'e-mail exact de l'app |
| 409 `PAYMENT_REFERENCE_TAKEN` | Référence déjà utilisée par un autre compte | ne pas forcer : vérifier le reçu |
| 503 | Secret non configuré sur le serveur | prévenir l'équipe technique |

Le formulaire n8n doit être protégé (mot de passe ou accès réservé à l'équipe) :
quiconque l'atteint peut ouvrir des accès.

## Règles

- Un nouvel accès **prolonge** le Pass en cours : il commence à sa fin.
- Une révocation (admin) ferme l'accès tout de suite ; la ligne reste dans
  l'historique. Chaque accès et chaque révocation écrit un `AdminAuditEvent`
  (`pass.granted`, `pass.revoked`).
- La notification « Ton Pass Karatou est actif » suit les heures calmes et le
  plafond quotidien des notifications ; elle reste dans le fil de l'app.
- Suppression du compte : ses accès partent avec lui. L'export RGPD les contient
  (dates, durée, référence, montant ; pas le commercial ni la note).

## Côté cours

Dans **Cours (Academy)** : cocher « Réservé au Pass Karatou » sur le cours, puis
« Aperçu gratuit » sur l'introduction et la première leçon.

- `GET /academy/courses/:id` (sans compte) : programme complet ; les leçons
  réservées ont `locked: true` et `videoUrl: null`.
- `GET /me/academy/courses/:id` (élève connecté) : mêmes leçons, ouvertes si le
  Pass est actif ; `viewerHasPass` dit lequel des deux cas.
- `GET /me/pass` : `{ active, activeUntil }`.

## Mise en service

1. Générer un secret : `openssl rand -hex 32`.
2. Le poser dans le `.env` du serveur (`KPB_PASS_WEBHOOK_SECRET=`) et dans
   l'en-tête du nœud HTTP de n8n.
3. Déployer (migration additive `20261122120000_pass_karatou`).
4. Tester avec un compte de test, puis révoquer l'accès de test dans l'admin.

## KPB Intelligence

Sans Pass : 5 messages par semaine. Pass actif : illimité, sous un garde-fou de
100 messages par JOUR contre l'abus (`PASS_COACH_DAILY_LIMIT`,
`backend/src/modules/coach/coach-quota.service.ts`), sur un compteur séparé
(`coach_pass`). Le Pass est relu à chaque message : une révocation vaut tout de
suite, et l'élève retrouve son compteur gratuit intact. Dans l'app, la pastille
affiche « Pass ∞ » au lieu du compteur.

## Dans l'app

L'entrée « Cours de langue (HSK, TOEFL…) » du profil n'apparaît que si le
drapeau distant `academy` est ouvert (Actions → VPS ops → `academy-on`, retour
arrière `academy-off`). Un cours réservé montre tout son programme ; une leçon
verrouillée affiche un cadenas et renvoie vers l'écran du Pass, sans prix ni
verbe d'achat. Avec un Pass actif, toutes les leçons s'ouvrent.

L'écran du Pass suit le même drapeau. Fermé : l'écran de la 59 (« Bientôt
disponible », liste d'attente). Ouvert : l'offre réelle — conseiller qui suit le
dossier, tous les cours, KPB Intelligence illimité, −20 % sur l'accompagnement
KPB, tableau gratuit / Pass,
« Ton Pass Karatou est actif jusqu'au … » pour un membre — toujours sans prix
ni verbe d'achat ; le seul bouton reste « Parler à un conseiller KPB ».
