# Relecture de `cmu_africa_mastercard_2027` — 06/11/2026

> Journal de ce qui a été **réellement lu**. Méthode :
> `docs/catalog-verification-sop.md`. La fiche, relue le 07/10, aurait dépassé
> 30 jours le 07/11 et remis au rouge le test de fraîcheur du backend
> (`reste importable à la date du jour`). Le 24/10, elle n'avait pas pu être lue
> (erreur de certificat TLS et 503).

## Méthode

- Les trois pages sources (`admissions/how-to-apply/index.html`, `admissions/faq.html`,
  `impact/mastercard-foundation-scholars.html` sur `www.africa.engineering.cmu.edu`)
  répondent 200 ce jour, sans erreur TLS. Le navigateur intégré n'a pas ouvert le
  site (navigation refusée) : les pages ont été téléchargées par `curl` (User-Agent
  de navigateur, rien de contourné) et converties en texte.
- **14 citations**, retrouvées mot pour mot dans le texte des pages :
  `docs/evidence/catalog-2026-11-06/citations.json`.
- `checkedAt` = l'heure de la lecture (`date -u`) : 17:29 UTC.
- Une seule lecture, par une seule personne.

## Résultat : confirmée, une phrase corrigée

- Confirmés : candidatures ouvertes depuis le 1ᵉʳ octobre (« Updated for fall
  2027 application ») ; échéance anticipée le 15 décembre, échéance finale le
  15 janvier, aucune heure publiée ; après le 15 décembre, score DET, IELTS ou
  TOEFL valide exigé ; un seul programme ; pas de moyenne plancher (la plupart
  des admis ont 3,0 ou plus) ; anglais recommandé TOEFL 81, IELTS 6,5, DET 120 ;
  candidature gratuite ; aide financière réservée aux admis de nationalité
  africaine ; trois quarts du cursus validés pour un candidat en dernière année ;
  avantages (scolarité, assurance, voyage, frais de vie de base, préparation,
  orientation, projets, entrepreneuriat). Le cycle reste `open`, clôture au
  15/01/2027.
- **Corrigé** : la description disait qu'il n'existe « ni formulaire ni date
  limite séparés » pour la bourse. La FAQ dit le contraire pour le formulaire :
  « Yes. A financial aid assessment form is available and can be completed after
  submission. » Seule la date limite n'est pas séparée.
- Non repris dans la fiche (information, pas d'erreur) : la FAQ donne un coût
  de 16 000 $ pour les étudiants africains et 60 300 $ pour les internationaux,
  et dit encore « GRE is not required for the fall 2026 intake » (libellé non
  mis à jour par l'établissement ; la fiche dit « GRE non exigé »).

## Après fusion

`publish-catalog` (import → reconcile → switch). Rien n'est déployé ici.
