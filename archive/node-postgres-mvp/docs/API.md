# REST API

Базовый URL локально: `http://localhost:4000/api`. Все тела запросов и ответов используют JSON.

## Общие ошибки

```json
{ "message": "Internal server error" }
```

При ошибке Zod возвращаются `message: "Validation error"` и объект `issues`. Защищённые маршруты ожидают заголовок `Authorization: Bearer <token>`.

## Служебный endpoint

### `GET /health`

Возвращает состояние сервера.

```json
{ "name": "MED SPRAVOCHNIK", "status": "ok" }
```

## Авторизация

### `POST /auth/register`

```json
{ "email": "doctor@example.com", "password": "secret12" }
```

Создаёт пользователя с ролью `USER` и возвращает пользователя и JWT. Возможные статусы: `201`, `400`, `409`.

### `POST /auth/login`

Принимает тот же формат и возвращает пользователя и JWT. Неверные данные дают `401`.

### `GET /auth/me`

Требует Bearer token. Возвращает текущего пользователя без хеша пароля.

## Препараты

### `GET /drugs?q=амоксициллин`

Возвращает список препаратов. Параметр `q` необязателен и ищет по `name` и `internationalName`.

### `GET /drugs/:id`

Возвращает препарат или `404`.

### `POST /drugs`

Требует роль `ADMIN`.

```json
{
  "name": "Амоксициллин",
  "internationalName": "Amoxicillin",
  "form": "таблетки",
  "dosage": "500 мг",
  "indications": "Бактериальные инфекции",
  "contraindications": "Гиперчувствительность",
  "sideEffects": "Аллергические реакции",
  "analogs": ["Амосин"]
}
```

## Заболевания

### `GET /diseases?q=I10`

Ищет по названию, МКБ-10, симптомам и лечению.

### `GET /diseases/:id`

Возвращает заболевание или `404`.

### `POST /diseases`

Требует роль `ADMIN`.

```json
{
  "name": "Артериальная гипертензия",
  "icd10": "I10",
  "symptoms": "Повышение артериального давления",
  "diagnostics": "Повторные измерения АД",
  "treatment": "Индивидуальная терапия"
}
```

## Статьи

### `GET /articles?q=антибиотики`

Возвращает только опубликованные статьи и ищет по заголовку, описанию и содержанию.

### `GET /articles/:id`

Неопубликованный материал для публичного запроса считается отсутствующим.

### `POST /articles`

Требует роль `ADMIN`.

```json
{
  "title": "Рациональная антибиотикотерапия",
  "slug": "antibiotic-stewardship",
  "category": "Клинические рекомендации",
  "description": "Краткие принципы назначения",
  "content": "Текст материала",
  "tags": ["антибиотики", "безопасность"],
  "isPublished": true
}
```

## Калькуляторы

### `POST /calculators/bmi`

```json
{ "weightKg": 70, "heightCm": 175 }
```

Пример ответа:

```json
{ "value": 22.9, "unit": "kg/m2", "category": "normal" }
```

### `POST /calculators/egfr`

Креатинин передаётся в мг/дл, возраст начинается с 18 лет.

```json
{ "age": 50, "creatinine": 1.1, "sex": "male" }
```

```json
{ "value": 82, "unit": "mL/min/1.73m2", "formula": "CKD-EPI 2021" }
```

Результаты калькуляторов требуют клинической интерпретации и не являются диагнозом.

## RAG

### `GET /rag?q=api&space=development`

`space` принимает `commercial`, `development` или `content`. Без фильтра поиск выполняется по всем массивам. Пустой `q` возвращает все документы выбранного пространства.
