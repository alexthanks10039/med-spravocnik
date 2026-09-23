import crypto from 'node:crypto';
import { Router } from 'express';
import { Prisma } from '@prisma/client';
import { z } from 'zod';

import { prisma } from '../../shared/prisma.js';
import { adminMiddleware, authMiddleware } from '../../shared/middleware/auth.middleware.js';
import { AppError } from '../../shared/middleware/error.middleware.js';

export const dataRouter = Router();

const collectionSchema = z.object({
  key: z.string().trim().min(2).max(100).regex(/^[a-zA-Z0-9_-]+$/),
  name: z.string().trim().min(2).max(200),
  description: z.string().trim().max(2000).optional(),
  schema: z.unknown().optional(),
});

const listSchema = z.object({
  page: z.coerce.number().int().min(1).default(1),
  pageSize: z.coerce.number().int().min(1).max(200).default(50),
  q: z.string().trim().max(300).default(''),
  type: z.string().trim().max(100).optional(),
  status: z.enum(['ACTIVE', 'ARCHIVED']).default('ACTIVE'),
});

function textValue(value: unknown): string {
  if (value == null) return '';
  if (typeof value === 'string' || typeof value === 'number' || typeof value === 'boolean') return String(value);
  if (Array.isArray(value)) return value.map(textValue).filter(Boolean).join(' ');
  if (typeof value === 'object') return Object.values(value as Record<string, unknown>).map(textValue).filter(Boolean).join(' ');
  return '';
}

function pickTitle(record: Record<string, unknown>): string | undefined {
  for (const key of ['title', 'name', 'label', 'displayName', 'subject', 'question']) {
    const value = record[key];
    if (typeof value === 'string' && value.trim()) return value.trim().slice(0, 1000);
  }
  return undefined;
}

function pickExternalId(record: Record<string, unknown>, index: number): string {
  for (const key of ['id', 'externalId', 'uuid', 'key', 'slug']) {
    const value = record[key];
    if (typeof value === 'string' || typeof value === 'number') {
      const normalized = String(value).trim();
      if (normalized) return normalized.slice(0, 500);
    }
  }
  return crypto.createHash('sha256').update(JSON.stringify(record)).digest('hex').slice(0, 32) || String(index + 1);
}

function parseEmbeddedJson(value: unknown): unknown {
  if (typeof value !== 'string') return value;
  const text = value.trim();
  if (!text || (!text.startsWith('{') && !text.startsWith('['))) return value;
  try { return JSON.parse(text); } catch { return value; }
}

function unwrapMcpPayload(input: unknown): unknown[] {
  const root = parseEmbeddedJson(input);
  if (Array.isArray(root)) {
    const flattened: unknown[] = [];
    for (const item of root) {
      const parsed = parseEmbeddedJson(item);
      if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) {
        const obj = parsed as Record<string, unknown>;
        if (obj.type === 'text' && 'text' in obj) {
          const nested = parseEmbeddedJson(obj.text);
          if (Array.isArray(nested)) flattened.push(...nested);
          else if (nested && typeof nested === 'object') flattened.push(nested);
          else flattened.push(obj);
          continue;
        }
      }
      flattened.push(parsed);
    }
    return flattened;
  }
  if (!root || typeof root !== 'object') return [root];

  const object = root as Record<string, unknown>;
  for (const key of ['items', 'results', 'records', 'data', 'documents', 'resources']) {
    const candidate = parseEmbeddedJson(object[key]);
    if (Array.isArray(candidate)) return unwrapMcpPayload(candidate);
  }

  if (object.type === 'text' && 'text' in object) {
    const nested = parseEmbeddedJson(object.text);
    if (nested !== object) return unwrapMcpPayload(nested);
  }

  return [root];
}

function detectFormat(input: unknown): string {
  if (Array.isArray(input)) return 'json-array';
  if (input && typeof input === 'object') {
    const object = input as Record<string, unknown>;
    if (Array.isArray(object.content) || object.type === 'text') return 'mcp-content';
    if (Array.isArray(object.items) || Array.isArray(object.results) || Array.isArray(object.records)) return 'json-envelope';
  }
  return 'json-object';
}

function normalizeRecord(value: unknown, index: number) {
  const payload: Record<string, unknown> =
    value && typeof value === 'object' && !Array.isArray(value)
      ? value as Record<string, unknown>
      : { value };

  return {
    externalId: pickExternalId(payload, index),
    title: pickTitle(payload),
    recordType: typeof payload.type === 'string' ? payload.type.slice(0, 100) : undefined,
    searchText: textValue(payload).slice(0, 100_000),
    payload: payload as Prisma.InputJsonValue,
  };
}

dataRouter.use(authMiddleware, adminMiddleware);

dataRouter.get('/collections', async (_req, res, next) => {
  try {
    const collections = await prisma.dataCollection.findMany({
      orderBy: { updatedAt: 'desc' },
      include: { _count: { select: { records: true, imports: true } } },
    });
    res.json(collections);
  } catch (error) { next(error); }
});

dataRouter.post('/collections', async (req, res, next) => {
  try {
    const data = collectionSchema.parse(req.body);
    const collection = await prisma.dataCollection.create({
      data: {
        ...data,
        schema: data.schema === undefined ? undefined : data.schema as Prisma.InputJsonValue,
      },
    });
    await prisma.auditLog.create({
      data: { userId: req.user!.userId, action: 'CREATE', entity: 'DataCollection', entityId: collection.id },
    });
    res.status(201).json(collection);
  } catch (error) { next(error); }
});

dataRouter.get('/collections/:collectionId/records', async (req, res, next) => {
  try {
    const parsed = listSchema.parse(req.query);
    const where: Prisma.DataRecordWhereInput = {
      collectionId: req.params.collectionId,
      status: parsed.status,
      ...(parsed.type ? { recordType: parsed.type } : {}),
      ...(parsed.q ? {
        OR: [
          { title: { contains: parsed.q, mode: 'insensitive' } },
          { externalId: { contains: parsed.q, mode: 'insensitive' } },
          { searchText: { contains: parsed.q, mode: 'insensitive' } },
        ],
      } : {}),
    };

    const [records, total] = await Promise.all([
      prisma.dataRecord.findMany({
        where,
        orderBy: { updatedAt: 'desc' },
        skip: (parsed.page - 1) * parsed.pageSize,
        take: parsed.pageSize,
        select: { id: true, externalId: true, title: true, recordType: true, payload: true, status: true, version: true, sourceFile: true, checksum: true, createdAt: true, updatedAt: true },
      }),
      prisma.dataRecord.count({ where }),
    ]);

    res.json({
      items: records,
      page: parsed.page,
      pageSize: parsed.pageSize,
      total,
      pages: Math.ceil(total / parsed.pageSize),
    });
  } catch (error) { next(error); }
});

dataRouter.get('/collections/:collectionId/records/:recordId', async (req, res, next) => {
  try {
    const record = await prisma.dataRecord.findFirst({
      where: { id: req.params.recordId, collectionId: req.params.collectionId },
    });
    if (!record) throw new AppError('Data record not found', 404);
    res.json(record);
  } catch (error) { next(error); }
});

dataRouter.post('/collections/:collectionId/import', async (req, res, next) => {
  try {
    const collection = await prisma.dataCollection.findUnique({ where: { id: req.params.collectionId } });
    if (!collection) throw new AppError('Data collection not found', 404);

    const filename = typeof req.body?.filename === 'string' ? req.body.filename.slice(0, 500) : undefined;
    const raw = req.body?.data ?? req.body?.payload ?? req.body;
    const source = unwrapMcpPayload(raw);
    const format = detectFormat(raw);
    if (source.length > 10_000) throw new AppError('Import is limited to 10,000 records per batch', 413);

    const job = await prisma.dataImport.create({
      data: { collectionId: collection.id, filename, format, status: 'RUNNING', total: source.length },
    });

    let imported = 0;
    let rejected = 0;
    const errors: Array<{ index: number; error: string }> = [];

    for (let offset = 0; offset < source.length; offset += 100) {
      const batch = source.slice(offset, offset + 100).map((item, index) => normalizeRecord(item, offset + index));
      try {
        await prisma.$transaction(
          batch.map((record) => prisma.dataRecord.upsert({
            where: { collectionId_externalId: { collectionId: collection.id, externalId: record.externalId } },
            update: {
              title: record.title,
              recordType: record.recordType,
              searchText: record.searchText,
              payload: record.payload,
              version: { increment: 1 },
              checksum: crypto.createHash('sha256').update(JSON.stringify(record.payload)).digest('hex'),
              sourceFile: filename,
              status: 'ACTIVE',
            },
            create: {
              collectionId: collection.id,
              ...record,
              checksum: crypto.createHash('sha256').update(JSON.stringify(record.payload)).digest('hex'),
              sourceFile: filename,
            },
          })),
        );
        imported += batch.length;
      } catch (error) {
        rejected += batch.length;
        errors.push({ index: offset, error: error instanceof Error ? error.message : 'Unknown import error' });
      }
    }

    const finished = await prisma.dataImport.update({
      where: { id: job.id },
      data: {
        status: rejected ? (imported ? 'PARTIAL' : 'FAILED') : 'COMPLETED',
        imported,
        rejected,
        errors: errors.length ? errors.slice(0, 50) : undefined,
        finishedAt: new Date(),
      },
    });

    await prisma.auditLog.create({
      data: {
        userId: req.user!.userId,
        action: 'IMPORT',
        entity: 'DataCollection',
        entityId: collection.id,
        metadata: { importId: job.id, total: source.length, imported, rejected, filename },
      },
    });

    res.status(201).json(finished);
  } catch (error) { next(error); }
});

dataRouter.get('/collections/:collectionId/export', async (req, res, next) => {
  try {
    const collection = await prisma.dataCollection.findUnique({ where: { id: req.params.collectionId } });
    if (!collection) throw new AppError('Data collection not found', 404);

    const records = await prisma.dataRecord.findMany({
      where: { collectionId: collection.id, status: 'ACTIVE' },
      orderBy: { createdAt: 'asc' },
      select: { externalId: true, payload: true },
    });

    const items = records.map((record) => record.payload);
    const format = String(req.query.format ?? 'array');
    if (format === 'ndjson') {
      res.type('application/x-ndjson').send(items.map((item) => JSON.stringify(item)).join('\n'));
      return;
    }
    if (format === 'envelope') {
      res.json({
        type: 'collection',
        collection: { id: collection.id, key: collection.key, name: collection.name },
        count: items.length,
        items,
      });
      return;
    }
    res.json(items);
  } catch (error) { next(error); }
});

dataRouter.get('/collections/:collectionId/imports', async (req, res, next) => {
  try {
    const imports = await prisma.dataImport.findMany({
      where: { collectionId: req.params.collectionId },
      orderBy: { startedAt: 'desc' },
      take: 50,
    });
    res.json(imports);
  } catch (error) { next(error); }
});
