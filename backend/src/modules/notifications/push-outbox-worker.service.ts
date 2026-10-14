import { Injectable } from '@nestjs/common';

/**
 * Le worker de la boîte d'envoi push (chantier C) : réserve les lignes
 * `UserNotification` en attente, applique heures calmes, rythme et
 * regroupement, puis envoie par `PushSenderService`.
 *
 * Coquille posée par le lot « schema », sans `@Interval` : rien ne tourne tant
 * que le lot « fanout », qui possède ce fichier, ne l'a pas rempli.
 */
@Injectable()
export class PushOutboxWorkerService {}
