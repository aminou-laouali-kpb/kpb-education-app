import { ServiceUnavailableException } from '@nestjs/common';
import type { PrismaClient } from '@prisma/client';

import type { PrismaService } from '../prisma/prisma.service';

/**
 * La communauté n'a pas de mode démonstration : sans base, 503. Évite de
 * propager le `T | null` de `PrismaService.execute` dans chaque appel.
 */
export async function runDb<T>(
  prisma: PrismaService,
  operation: (client: PrismaClient) => Promise<T>,
): Promise<T> {
  if (!prisma.isEnabled) {
    throw new ServiceUnavailableException('Database is not configured. Set DATABASE_URL.');
  }
  return (await prisma.execute(operation)) as T;
}
