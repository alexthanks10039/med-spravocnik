import { Prisma } from '@prisma/client';
import { Router } from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { z } from 'zod';

import { env } from '../../config/env.js';
import { prisma } from '../../shared/prisma.js';
import { authMiddleware } from '../../shared/middleware/auth.middleware.js';
import { AppError } from '../../shared/middleware/error.middleware.js';

export const authRouter = Router();

const schema = z.object({
  email: z.string().trim().email().max(254).transform((value) => value.toLowerCase()),
  password: z.string().min(6).max(128),
});

const parseCredentials = (body: unknown) => {
  const credentials = schema.parse(body);
  if (bcrypt.truncates(credentials.password)) {
    throw new AppError('Password is too long for the selected password hashing format', 400);
  }
  return credentials;
};

const token = (id: string, role: 'USER' | 'ADMIN') =>
  jwt.sign({ userId: id, role }, env.JWT_SECRET, { expiresIn: '30d' });

authRouter.post('/register', async (req, res, next) => {
  try {
    const d = parseCredentials(req.body);
    const user = await prisma.user.create({
      data: {
        email: d.email,
        password: await bcrypt.hash(d.password, 10),
      },
      select: { id: true, email: true, role: true, createdAt: true },
    });

    res.status(201).json({ user, token: token(user.id, user.role) });
  } catch (error) {
    if (
      error instanceof Prisma.PrismaClientKnownRequestError &&
      error.code === 'P2002'
    ) {
      next(new AppError('User already exists', 409));
      return;
    }
    next(error);
  }
});

authRouter.post('/login', async (req, res, next) => {
  try {
    const d = parseCredentials(req.body);
    const user = await prisma.user.findUnique({ where: { email: d.email } });

    if (!user || !(await bcrypt.compare(d.password, user.password))) {
      throw new AppError('Invalid credentials', 401);
    }

    res.json({
      user: {
        id: user.id,
        email: user.email,
        role: user.role,
        createdAt: user.createdAt,
      },
      token: token(user.id, user.role),
    });
  } catch (error) {
    next(error);
  }
});

authRouter.get('/me', authMiddleware, async (req, res, next) => {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.user!.userId },
      select: { id: true, email: true, role: true, createdAt: true },
    });
    if (!user) throw new AppError('User not found', 404);
    res.json(user);
  } catch (error) {
    next(error);
  }
});
