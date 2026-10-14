import { Injectable } from '@nestjs/common';

/**
 * Phase 1 du worker (chantier C) : les annonces programmées arrivées à
 * échéance deviennent une ligne d'inbox par abonné, en un INSERT … SELECT.
 *
 * Coquille posée par le lot « schema » ; rempli par le lot « fanout ».
 */
@Injectable()
export class ScholarshipOpeningFanoutService {}
