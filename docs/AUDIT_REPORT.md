# Отчет аудита и синхронизации

Дата: 15 июня 2026 года.

## Обнаружено

GitHub `main` и локальная папка содержали две разные реализации:

- GitHub: Express, Prisma, PostgreSQL, mock Flutter и статический RAG;
- локально: FastAPI Knowledge API, отдельный Calculator API, реальный Flutter
  API client и внешний медицинский SQLite-корпус.

## Решение

- локальная реализация объявлена активной;
- предыдущий GitHub MVP сохранен в `archive/node-postgres-mvp`;
- локальные компоненты перенесены в `apps`, `services` и `scripts`;
- абсолютные пути заменены repo-relative defaults;
- приватный корпус и индексы исключены из Git;
- создан автономный synthetic-data Preview.

## Не перенесено

- `.venv`, кэши, Flutter build, `node_modules`, `dist`, логи;
- исходные PDF, OCR output, SQLite и embeddings;
- локальные IDE-конфиги;
- hidden/internal calculator benchmark splits;
- устаревшая копия pipeline из папки с временным названием.

## Сохранено в архиве

Express API, Prisma schema, PostgreSQL Compose, старый Flutter mock client,
статический web-клиент и старая документация. Они не участвуют в активной сборке.

## Оставшиеся риски

- полный корпус требует отдельного лицензирования и backup policy;
- version families и часть OCR-таблиц нуждаются в QC;
- production authentication и rate limiting еще не реализованы в активном API;
- Android release signing и публичный HTTPS не настроены.

Публичный CI не запускает один upstream-файл тестов, который требует
непубликуемый hidden benchmark. Локальная закрытая проверка может вернуть этот
набор отдельно.
