import { Injectable } from '@nestjs/common';

/**
 * L'audience d'une annonce d'ouverture (chantier C) : lignes et comptes tirés
 * de `scholarship-follow.query.ts`, le texte SQL que partagent l'aperçu,
 * `activate` et l'envoi.
 *
 * Coquille posée par le lot « schema » ; rempli par le lot « fanout ».
 */
@Injectable()
export class ScholarshipOpeningAudienceService {}
