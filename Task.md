# TrafficMaster iOS -> Backend Integration Plan

Дата: 2026-05-30

## 0. Текущее направление

MVP переезжает с FSRS на backend-совместимый SuperMemo 2 / SM-2.

Источник истины для расписания карточек: backend `CardProgressService`.
iOS может считать SM-2 локально только как offline-first зеркало, но после синка должна принимать backend-значения.

## 1. Что найдено в backend

Репозиторий склонирован в `/Users/vlad/TM/trafficmaster-backend`.

Backend стек: FastAPI + SQLAlchemy + PostgreSQL + Redis.

Доменные сущности карточек:
- `Card`: `id`, `deck_id`, `question`, `answer`, `image_path`, `tags`, `created_at`, `updated_at`.
- `CardProgress`: `id`, `user_id`, `card_id`, `ease_factor`, `interval`, `repetitions`, `state`, `next_review_at`, `created_at`, `updated_at`.
- `ReviewLog`: append-only журнал повторений.

Backend states:
- `new`
- `learning`
- `review`
- `relearning`

Backend ratings:
- `AGAIN = 1`
- `HARD = 2`
- `GOOD = 3`
- `EASY = 4`

Backend deck config для SM-2:
- `daily_limits`: `new_cards_per_day`, `max_reviews_per_day`, `reviews_dont_bury_new`.
- `new_cards`: `learning_steps`, `graduating_interval`, `easy_interval`, `new_card_order`.
- `lapses`: `relearning_steps`, `min_interval`, `leech_threshold`, `leech_action`.
- `advanced`: `max_interval`, `ease_factor`, `easy_factor`, `interval_modifier`, `hard_interval`, `new_interval`.

## 2. Как backend считает SM-2

Для `new` и `learning`:
- `AGAIN`: `repetitions = 0`, следующий показ через первый `learning_step` в минутах.
- `HARD`: остаётся на текущем learning step.
- `GOOD`: переходит на следующий step; если steps закончились, карточка становится `review`, `interval = graduating_interval`, `repetitions = 1`.
- `EASY`: сразу `review`, `interval = easy_interval`, `repetitions = 1`.

Для `review`:
- `AGAIN`: `ease_factor -= 0.2`, минимум `1.3`; `interval = max(1, round(current_interval * new_interval))`; state -> `relearning`; `repetitions = 0`.
- `HARD`: `ease_factor -= 0.15`; интервал растёт через `hard_interval * interval_modifier`.
- `GOOD`: интервал растёт через `ease_factor * interval_modifier`.
- `EASY`: `ease_factor += 0.15`, максимум `5.0`; интервал растёт через `easy_factor`.

Для `relearning`:
- логика похожа на learning, но graduation возвращает в `review` с `interval = max(min_interval, текущий interval)`.

## 3. Что уже подогнано в iOS

- Локальный scheduler переписан под backend SM-2.
- В локальную `Question` добавлены backend-поля `sm2State` и `backendCardProgressID`.
- SQLite schema v5 добавляет `sm2_state` и `backend_card_progress_id`.
- Очередь обучения теперь смотрит на `sm2State`, а не на FSRS поля.
- API contracts стали терпимыми к фактическому backend shape: review queue может декодироваться как массив или как `{ items: [...] }`.
- Документация/задачи получают отдельный пункт: убрать FSRS как актуальную цель и вести MVP через SM-2.

## 4. Несостыковки frontend/backend

### P0 blockers

- В backend доменные handlers для cards/decks/card_progress есть, но HTTP routes сейчас подключают только `/v1/user`. В Swagger/OpenAPI карточные endpoints могут отсутствовать, пока backend не подключит routers.
- iOS уже ожидает endpoints:
  - `GET /v1/decks/{deck_id}/review-queue`
  - `POST /v1/cards/{card_id}/review`
  - `POST /v1/sync/push`
  - `POST /v1/auth/signup`
  - `POST /v1/auth/login`
  Сейчас это не подтверждено фактическим FastAPI route tree.
- Backend `ReviewQueueItemView` не содержит `answer_options`, а iOS карточки ПДД требуют 2-5 вариантов ответа и один правильный вариант.
- Backend `Card` имеет только `question` и `answer`; нет структуры MCQ-вариантов, `correct_option_id`, `explanation`, `section_title`, `chapter_title`.
- Backend `ReviewCardCommand` принимает только `card_id` и `rating`; текущий iOS outbox отправляет `selected_option_id`, `answered_at`, `time_spent_ms`, `client_event_id`, `device_id`.
- Backend OpenAPI не удалось сгенерировать локально из-за зависимости `psycopg2`: на машине нет `pg_config`. Нужен `libpq/postgresql` или замена dev-зависимости на `psycopg2-binary`.

### Existing local cards

Для уже загруженных iOS карточек не хватает backend identity:
- `backend_deck_id`
- `backend_card_id`
- `backend_card_progress_id`
- `sm2_state`

Для полноценного backend merge также нужны поля, которых сейчас нет в backend card model:
- варианты ответа;
- признак правильного варианта;
- объяснение;
- раздел/глава ПДД;
- стабильный внешний id импортированной карточки, чтобы не плодить дубликаты.

## 5. План интеграции

### P0

- Backend: подключить HTTP routers для auth, deck, card, card_progress, sync.
- Backend: добавить MCQ contract для карточек или отдельную таблицу/options model.
- Backend: опубликовать фактический Swagger/OpenAPI и зафиксировать response/request schemas.
- iOS: заменить все оставшиеся актуальные FSRS-упоминания в коде/доках на SM-2; исторические документы пометить как устаревшие.
- iOS: принимать backend `CardProgress` как источник истины после review/sync.
- iOS: мигрировать локальные карточки v5 и заполнить `sm2_state = new` для старых записей.

### P1

- iOS: добавить модели `APICard`, `APICardProgress`, `APIDeckConfig`, `APIReviewLog` один-в-один под Swagger.
- iOS: сделать import/export bridge: локальная `Question` <-> backend `Card + options/progress`.
- iOS: при `POST /review` обновлять `backend_card_progress_id`, `sm2State`, `interval`, `nextReviewDate`, `repetitions`, `easinessFactor`.
- Backend: добавить bulk endpoint для первичной загрузки/сопоставления 3000 ПДД карточек.
- Backend: добавить idempotency для `client_event_id`, чтобы offline outbox не дублировал review logs.

### P2

- Согласовать deck config defaults между backend и iOS UI.
- Добавить экран/настройки SM-2 deck config только после стабилизации backend endpoints.
- Добавить интеграционные тесты на одинаковый результат SM-2 для iOS и backend на наборах `new/learning/review/relearning + again/hard/good/easy`.

## 6. UI mapping ответов

| Ситуация пользователя | UI | Backend rating |
|---|---|---|
| Ответ неверный | Неверно | AGAIN (1) |
| Ответ верный, но пользователь угадал | Угадал | AGAIN (1) |
| Ответ верный, но были сомнения | Сомневался | HARD (2) |
| Ответ верный уверенно | Знал | GOOD (3) |
| Ответ верный мгновенно | Легко | EASY (4) |

Ключевое правило: `Угадал` не считается знанием и не должен повышать карточку как `GOOD`.
