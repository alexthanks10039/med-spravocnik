import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../../shared/prisma.js';
import { adminMiddleware, authMiddleware } from '../../shared/middleware/auth.middleware.js';
import { AppError } from '../../shared/middleware/error.middleware.js';

export const drugsRouter = Router();
const schema = z.object({
  name: z.string().min(2),
  internationalName: z.string().optional(),
  form: z.string().optional(),
  dosage: z.string().optional(),
  indications: z.string().optional(),
  contraindications: z.string().optional(),
  sideEffects: z.string().optional(),
  analogs: z.array(z.string()).default([]),
});
const limitSchema = z.coerce.number().int().min(1).max(100).default(50);

drugsRouter.get('/', async (req, res, next) => {
  try {
    const q = String(req.query.q ?? '').trim();
    const limit = limitSchema.parse(req.query.limit);
    res.json(await prisma.drug.findMany({
      where: q
        ? {
            OR: [
              { name: { contains: q, mode: 'insensitive' } },
              { internationalName: { contains: q, mode: 'insensitive' } },
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

drugsRouter.get('/:id', async (req, res, next) => {
  try {
    const x = await prisma.drug.findUnique({ where: { id: req.params.id } });
    if (!x) throw new AppError('Drug not found', 404);
    res.json(x);
  } catch (e) {
    next(e);
  }
});

drugsRouter.post('/', authMiddleware, adminMiddleware, async (req, res, next) => {
  try {
    const d = schema.parse(req.body);
    res.status(201).json(await prisma.drug.create({ data: d }));
  } catch (e) {
    next(e);
  }
});
