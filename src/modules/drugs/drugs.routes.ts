import { Router } from 'express';
import { z } from 'zod';

import { prisma } from '../../shared/prisma.js';
import { adminMiddleware, authMiddleware } from '../../shared/middleware/auth.middleware.js';
import { AppError } from '../../shared/middleware/error.middleware.js';

export const drugsRouter = Router();

const schema = z.object({
  name: z.string().trim().min(2).max(300),
  internationalName: z.string().trim().max(300).optional(),
  form: z.string().trim().max(500).optional(),
  dosage: z.string().max(20_000).optional(),
  indications: z.string().max(20_000).optional(),
  contraindications: z.string().max(20_000).optional(),
  sideEffects: z.string().max(20_000).optional(),
  analogs: z.array(z.string().trim().min(1).max(300)).max(100).default([]),
});

const querySchema = z.string().trim().max(200).default('');
const limitSchema = z.coerce.number().int().min(1).max(100).default(50);

drugsRouter.get('/', async (req, res, next) => {
  try {
    const q = querySchema.parse(req.query.q);
    const limit = limitSchema.parse(req.query.limit);

    const items = await prisma.drug.findMany({
      select: { id: true, name: true, internationalName: true, form: true },
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
    });

    res.json(items);
  } catch (error) {
    next(error);
  }
});

drugsRouter.get('/:id', async (req, res, next) => {
  try {
    const item = await prisma.drug.findUnique({ where: { id: req.params.id } });
    if (!item) throw new AppError('Drug not found', 404);
    res.json(item);
  } catch (error) {
    next(error);
  }
});

drugsRouter.post('/', authMiddleware, adminMiddleware, async (req, res, next) => {
  try {
    const item = await prisma.drug.create({ data: schema.parse(req.body) });
    res.status(201).json(item);
  } catch (error) {
    next(error);
  }
});
