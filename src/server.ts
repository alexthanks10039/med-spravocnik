import { app } from './app.js';
import { env } from './config/env.js';
import { prisma } from './shared/prisma.js';

const server = app.listen(env.PORT, () => {
  console.log('MED SPRAVOCHNIK: http://localhost:' + env.PORT);
});

const shutdown = (signal: string) => {
  console.log('Received ' + signal + ', shutting down...');

  server.close(() => {
    void prisma.$disconnect().finally(() => process.exit(0));
  });
};

process.once('SIGINT', () => shutdown('SIGINT'));
process.once('SIGTERM', () => shutdown('SIGTERM'));
