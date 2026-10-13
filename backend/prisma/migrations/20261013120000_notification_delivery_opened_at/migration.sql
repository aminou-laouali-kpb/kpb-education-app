-- Ouverture d'une notification push de campagne (tap de l'élève).
--
-- Remplace les taux d'ouverture que fournissait le tableau de bord OneSignal :
-- l'application signale le tap (`POST /me/push-opens`) et la livraison reçoit
-- sa date d'ouverture. Null = pas (encore) ouverte, ou ouverte depuis une
-- version de l'application qui ne le signale pas.
--
-- ADDITIF SEULEMENT.

ALTER TABLE "NotificationDelivery" ADD COLUMN "openedAt" TIMESTAMP(3);
