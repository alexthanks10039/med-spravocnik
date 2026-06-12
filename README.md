# MED TIM

Рабочий MVP медицинского справочника: REST API, авторизация, Prisma-хранилище, калькуляторы и RAG-библиотека для Codex.

## RAG-пространства

- `commercial`: позиционирование, модель продукта и коммерческие правила.
- `development`: архитектура, API-контракты и инженерные сведения.
- `content`: медицинская редакционная политика, таксономия и справочные материалы.

Массивы находятся в `src/rag/library.ts`, API поиска доступен по `GET /api/rag?q=&space=`.

## Запуск

```bash
copy .env.example .env
npm install
npm run prisma:generate
npm run db:push
npm run dev
```

Откройте `http://localhost:4000`.

## API

`/api/auth`, `/api/drugs`, `/api/diseases`, `/api/articles`, `/api/calculators`, `/api/rag`, `/api/health`.

Медицинские материалы в MVP предназначены только для справочного использования и должны проходить профессиональную редакционную проверку.
