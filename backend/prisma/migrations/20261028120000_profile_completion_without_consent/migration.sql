-- Compétition ambassadeurs : « profil complété » sans `UserProfile.consentedAt`
-- (audit 57, F15).
--
-- DONNÉES SEULEMENT : aucun changement de schéma. Idempotent (ne touche que
-- les lignes où `profileCompletedAt` est encore NULL) ; rejouer n'écrit rien.
--
-- `consentedAt` n'est écrit par aucune build ni par le serveur : le rattrapage 3
-- de `20261022120000_referral_campaigns` (qui l'exigeait) n'a donc daté aucun
-- profil. Le prédicat ci-dessous est celui de
-- `src/modules/referrals/campaigns/profile-completion.ts` (`isProfileComplete`),
-- désormais sans la condition de consentement — la case reste obligatoire à
-- l'onboarding de l'app, avant toute synchronisation du profil.
--
-- Date posée : `updatedAt`, la dernière modification du profil. C'est la date
-- connue la plus TARDIVE à laquelle le profil était déjà complet, jamais
-- antérieure à la création du compte. Elle ne peut pas qualifier à tort un
-- filleul : la qualification (`campaign-qualification.ts`) prend
-- max(rattachement, création du compte, complétion), exige un rattachement
-- dans la fenêtre de la campagne et, par défaut (règlement §4 : « un compte
-- créé avant le 1er novembre ne compte pas »), un compte créé dans la fenêtre.
-- Un profil ancien daté ici reste donc hors compétition par sa date de
-- création ; un profil créé pendant la fenêtre reçoit une date ≥ sa création et
-- ≥ sa complétion réelle, donc au pire un peu tardive, jamais en avance.
UPDATE "UserProfile"
SET "profileCompletedAt" = "updatedAt"
WHERE "profileCompletedAt" IS NULL
  AND "accountType" = 'student'
  AND btrim("phone") <> ''
  AND "birthDate" IS NOT NULL
  AND cardinality("fieldIds") > 0
  AND cardinality("targetCountryIds") > 0
  AND ("birthDate" <= CURRENT_TIMESTAMP - INTERVAL '18 years' OR "guardianConsentedAt" IS NOT NULL);
