# Локальная среда MED SPRAVOCHNIK

## Что подготовлено

- PostgreSQL 17 в Docker на `localhost:5433`.
- pgAdmin на `http://localhost:5050`.
- Prisma для схемы, миграций и seed-данных.
- `pnpm` через Corepack: `corepack pnpm <command>`.

## Первый запуск

```powershell
corepack pnpm install
corepack pnpm db:up
corepack pnpm db:deploy
corepack pnpm db:seed
corepack pnpm dev
```

Backend будет доступен на `http://localhost:4000`.

## pgAdmin

```powershell
corepack pnpm db:tools
```

Открыть `http://localhost:5050`.

- Login: `admin@example.com`
- Password: `admin_dev_password`
- Сервер уже добавлен как `MED SPRAVOCHNIK local`.
- Пароль PostgreSQL: `med_dev_password`

Для DBeaver или SQLTools:

- Host: `localhost`
- Port: `5433`
- Database: `med_spravochnik`
- User: `med_user`
- Password: `med_dev_password`

## Тестовый пользователь API

- Email: `admin@med.local`
- Password: `Admin123!`

Готовые запросы находятся в `api/med-spravochnik.http` и запускаются расширением REST Client.

## Команды

```powershell
corepack pnpm db:up
corepack pnpm db:tools
corepack pnpm db:down
corepack pnpm db:migrate -- --name change_name
corepack pnpm db:seed
corepack pnpm db:studio
corepack pnpm check
```

Значения в `.env.example` предназначены только для локальной разработки. Том Docker сохраняет данные между перезапусками. Команда `docker compose down -v` удаляет локальную базу полностью.
