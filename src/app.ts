import express from 'express';
import cors from 'cors';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { authRouter } from './modules/auth/auth.routes.js';
import { drugsRouter } from './modules/drugs/drugs.routes.js';
import { diseasesRouter } from './modules/diseases/diseases.routes.js';
import { articlesRouter } from './modules/articles/articles.routes.js';
import { calculatorsRouter } from './modules/calculators/calculators.routes.js';
import { ragRouter } from './rag/rag.routes.js';
import { errorMiddleware } from './shared/middleware/error.middleware.js';
import { prisma } from './shared/prisma.js';
import { env } from './config/env.js';

export const app = express();
const root = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '../public',
);
const allowedOrigins =
    env.CORS_ORIGIN === '*'
        ? true
        : env.CORS_ORIGIN.split(',').map((origin) => origin.trim()).filter(Boolean);

app.disable('x-powered-by');
app.use(cors({ origin: allowedOrigins }));
app.use(express.json({ limit: '1mb' }));
app.use(express.static(root));

app.get('/api/health', (_req, res) =>
  res.json({ name: 'MED SPRAVOCHNIK', status: 'ok' }),
);

app.get('/api/ready', async (_req, res, next) => {
  try {
    await prisma.$queryRaw`SELECT 1`;
    res.json({ name: 'MED SPRAVOCHNIK', status: 'ready' });
  } catch (error) {
    next(error);
  }
});
app.use('/api/auth', authRouter);
app.use('/api/drugs', drugsRouter);
app.use('/api/diseases', diseasesRouter);
app.use('/api/articles', articlesRouter);
app.use('/api/calculators', calculatorsRouter);
app.use('/api/rag', ragRouter);
app.use(errorMiddleware);
