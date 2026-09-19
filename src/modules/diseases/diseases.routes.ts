import { Router } from 'express';
import { z } from 'zod';

import { prisma } from '../../shared/prisma.js';
import { adminMiddleware, authMiddleware } from '../../shared/middleware/auth.middleware.js';
import { AppError } from '../../shared/middleware/error.middleware.js';

export const diseasesRouter = Router();

const schema = z.object({
  name: z.string().trim().min(2).max(300),
  icd10: z.string().trim().max(50).optional(),
  symptoms: z.string().max(20_000).optional(),
  diagnostics: z.string().max(20_000).optional(),
  treatment: z.string().max(20_000).optional(),
});

const querySchema = z.string().trim().max(200).default('');
const limitSchema = z.coerce.number().int().min(1).max(100).default(50);

diseasesRouter.get('/', async (req, res, next) => {
  try {
    const q = querySchema.parse(req.query.q);
    const limit = limitSchema.parse(req.query.limit);

    const items = await prisma.disease.findMany({
      select: { id: true, name: true, icd10: true },
      where: q
        ? {
            OR: [
              { name: { contains: q, mode: 'insensitive' } },
              { icd10: { contains: q, mode: 'insensitive' } },
              { symptoms: { contains: q, mode: 'insensitive' } },
              { diagnostics: { contains: q, mode: 'insensitive' } },
              { treatment: { contains: q, mode: 'insensitive' } },
            ],
          }
        : undefined,
      orderBy: { name: 'asc' },
      take: limit,
    });

    res.json(items);
  } catch (error) {
    next(error);
  }
});

diseasesRouter.get('/:id', async (req, res, next) => {
  try {
    const item = await prisma.disease.findUnique({
      select: { id: true, name: true, icd10: true, symptoms: true, diagnostics: true, treatment: true },
      where: { id: req.params.id },
    });
    if (!item) throw new AppError('Disease not found', 404);
    res.json(item);
  } catch (error) {
    next(error);
  }
});

diseasesRouter.post('/', authMiddleware, adminMiddleware, async (req, res, next) => {
  try {
    const item = await prisma.disease.create({ data: schema.parse(req.body) });
    res.status(201).json(item);
  } catch (error) {
    next(error);
  }
});
