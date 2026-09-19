import 'dotenv/config';

import { z } from 'zod';

const envSchema = z
  .object({
    DATABASE_URL: z.string().min(1),
    JWT_SECRET: z.string().min(10),
    PORT: z.coerce.number().int().min(1).max(65535).default(4000),
    NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
    CORS_ORIGIN: z.string().default('*'),
  })
  .superRefine((value, ctx) => {
    if (value.NODE_ENV === 'production' && value.CORS_ORIGIN.trim() === '*') {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['CORS_ORIGIN'],
        message: 'CORS_ORIGIN must be explicit in production',
      });
    }
  });

export const env = envSchema.parse(process.env);
