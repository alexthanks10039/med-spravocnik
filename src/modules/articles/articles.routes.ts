import { Router } from 'express';
import { z } from 'zod';

import { prisma } from '../../shared/prisma.js';
import { adminMiddleware, authMiddleware } from '../../shared/middleware/auth.middleware.js';
import { AppError } from '../../shared/middleware/error.middleware.js';

export const articlesRouter = Router();

const schema = z.object({
  title: z.string().trim().min(2).max(500),
  slug: z.string().trim().min(2).max(500),
  category: z.string().trim().min(2).max(200),
  description: z.string().max(5_000).optional(),
  content: z.string().min(2).max(500_000),
  tags: z.array(z.string().trim().min(1).max(100)).max(100).default([]),
  isPublished: z.boolean().default(true),
});

const querySchema = z.string().trim().max(200).default('');
const limitSchema = z.coerce.number().int().min(1).max(100).default(50);

articlesRouter.get('/', async (req, res, next) => {
  try {
    const q = querySchema.parse(req.query.q);
    const limit = limitSchema.parse(req.query.limit);

    const items = await prisma.article.findMany({
      select: { id: true, title: true, category: true, description: true },
      where: {
        isPublished: true,
        ...(q
          ? {
              OR: [
                { title: { contains: q, mode: 'insensitive' } },
                { description: { contains: q, mode: 'insensitive' } },
                { content: { contains: q, mode: 'insensitive' } },
              ],
            }
          : {}),
      },
      orderBy: { updatedAt: 'desc' },
      take: limit,
    });

    res.json(items);
  } catch (error) {
    next(error);
  }
});

articlesRouter.get('/:id', async (req, res, next) => {
  try {
    const item = await prisma.article.findUnique({
      select: { id: true, title: true, category: true, description: true, content: true },
      where: { id: req.params.id },
    });
    if (!item || !item.isPublished) throw new AppError('Article not found', 404);
    res.json(item);
  } catch (error) {
    next(error);
  }
});

articlesRouter.post('/', authMiddleware, adminMiddleware, async (req, res, next) => {
  try {
    const item = await prisma.article.create({ data: schema.parse(req.body) });
    res.status(201).json(item);
  } catch (error) {
    next(error);
  }
});
