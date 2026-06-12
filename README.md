# MED SPRAVOCHNIK

Медицинский справочник для быстрого поиска заболеваний, препаратов, клинических материалов и расчёта медицинских показателей. Репозиторий содержит REST API, статический web-клиент, Flutter-приложение и RAG-библиотеку для Codex.

> Проект находится на стадии MVP. Медицинские материалы предназначены только для справочного использования и не заменяют клиническое решение специалиста.

## Возможности

- каталог заболеваний, препаратов и статей;
- поиск по справочным материалам;
- калькуляторы BMI и eGFR CKD-EPI 2021;
- регистрация, вход и JWT-аутентификация;
- роли `USER` и `ADMIN`;
- RAG-поиск по коммерческому, инженерному и контентному пространствам;
- адаптивный Flutter-интерфейс с offline mock-репозиторием;
- статический web-интерфейс, раздаваемый backend-сервером.

## Состав системы

```text
MED SPRAVOCHNIK
├── src/                 Node.js REST API
│   ├── modules/         auth, drugs, diseases, articles, calculators
│   ├── rag/             RAG-библиотека и поисковый endpoint
│   └── shared/          Prisma и middleware
├── prisma/              схема PostgreSQL, миграции и seed
├── public/              статический web-клиент
├── flutter_app/         Flutter-клиент для web, Android и iOS
└── docs/                архитектура, API и правила RAG
```

Подробности: [архитектура](docs/ARCHITECTURE.md), [API](docs/API.md), [RAG](docs/RAG.md), [Flutter-клиент](flutter_app/README.md).

## Быстрый запуск backend

Требования: Node.js 22 LTS, Corepack и Docker Desktop.

```powershell
Copy-Item .env.example .env
corepack pnpm install
corepack pnpm db:up
corepack pnpm db:deploy
corepack pnpm db:seed
corepack pnpm dev
```

После запуска:

- web-интерфейс: `http://localhost:4000`;
- health check: `http://localhost:4000/api/health`;
- RAG API: `http://localhost:4000/api/rag`.

Для production-сборки:

```bash
npm run build
npm start
```

## Запуск Flutter-клиента

Требования: Flutter с Dart SDK `^3.12.1`.

```bash
cd flutter_app
flutter pub get
flutter run -d chrome --web-port 8080
```

Текущая Flutter-версия использует локальный `OfflineMedicalRepository`. Подключение REST API является следующим этапом интеграции.

## Переменные окружения

| Переменная | Назначение | Пример |
|---|---|---|
| `DATABASE_URL` | строка подключения Prisma | `postgresql://med_user:...@localhost:5433/med_spravochnik` |
| `JWT_SECRET` | ключ подписи JWT, минимум 10 символов | `replace-with-secure-secret` |
| `PORT` | порт API и web-клиента | `4000` |
| `NODE_ENV` | режим запуска | `development` |

Не добавляйте `.env`, базы данных и секреты в Git.

## Команды

| Команда | Назначение |
|---|---|
| `corepack pnpm dev` | сервер разработки с перезапуском |
| `corepack pnpm check` | проверка TypeScript без сборки |
| `corepack pnpm build` | сборка в `dist/` |
| `corepack pnpm db:up` | запуск PostgreSQL |
| `corepack pnpm db:tools` | запуск PostgreSQL и pgAdmin |
| `corepack pnpm db:deploy` | применение миграций |
| `corepack pnpm db:seed` | загрузка тестовых данных |

## Статус MVP

- CRUD-модули пока реализованы частично: чтение доступно публично, создание требует роли `ADMIN`.
- Flutter-клиент пока не синхронизирован с backend.
- Медицинский контент является демонстрационным и требует редакционной проверки, источников и дат пересмотра.
- Для стабильной работы Prisma рекомендуется Node.js 22 LTS.

Полная инструкция по PostgreSQL, pgAdmin, SQLTools и тестовым запросам: [локальная разработка](docs/LOCAL_DEVELOPMENT.md).

## Лицензия и ответственность

Лицензия пока не определена. До её добавления проект следует считать закрытым. Перед публикацией медицинского контента необходимо определить редакционную ответственность, источники, аудит изменений и юридический disclaimer.
