import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../../shared/prisma.js';
import { adminMiddleware, authMiddleware } from '../../shared/middleware/auth.middleware.js';
import { AppError } from '../../shared/middleware/error.middleware.js';

export const diseasesRouter = Router();
const schema = z.object({
  name: z.string().min(2),
  icd10: z.string().optional(),
  symptoms: z.string().optional(),
  diagnostics: z.string().optional(),
  treatment: z.string().optional(),
});

const querySchema = z.string().trim().max(200).default('');
const limitSchema = z.coerce.number().int().min(1).max(100).default(50);

diseasesRouter.get('/', async (req, res, next) => {
  try {
    const q = querySchema.parse(req.query.q);
    const limit = limitSchema.parse(req.query.limit);
    res.json(await prisma.disease.findMany({
      where: q
        ? {
            OR: [
              { name: { contains: q, mode: 'insensitive' } },
              { icd10: { contains: q, mode: 'insensitive' } },
              { symptoms: { contains: q, mode: 'insensitive' } },
              { treatment: { contains: q, mode: 'insensitive' } },
            ],
          }
        : undefined,
      orderBy: { name: 'asc' },
      take: limit,
    }));
  } catch (e) {
    next(e);
  }
});

diseasesRouter.get('/:id', async (req, res, next) => {
  try {
    const x = await prisma.disease.findUnique({ where: { id: req.params.id } });
    if (!x) throw new AppError('Disease not found', 404);
    res.json(x);
  } catch (e) {
    next(e);
  }
});

diseasesRouter.post('/', authMiddleware, adminMiddleware, async (req, res, next) => {
  try {
    res.status(201).json(await prisma.disease.create({ data: schema.parse(req.body) }));
  } catch (e) {
    next(e);
  }
});
