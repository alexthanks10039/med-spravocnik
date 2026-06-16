import dotenv from 'dotenv';
import { z } from 'zod';
dotenv.config();
export const env = z.object({ DATABASE_URL:z.string().min(1), JWT_SECRET:z.string().min(10), PORT:z.coerce.number().default(4000), NODE_ENV:z.string().default('development') }).parse(process.env);
