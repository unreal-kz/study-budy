# Процесс разработки (Linear)

Workspace: https://linear.app/study-buddy-daryn · Team: **Study-buddy** (`ST`) · Project: **Study Buddy — MVP**

## Модель: Kanban + Cycles

Одна доска статусов обслуживает обе методологии одновременно:

```
Backlog → Todo → In Progress → In Review → Done
                                   ↓
                       Canceled / Duplicate
```

- **Kanban** — работа с доской по статусам в любой момент, без привязки к спринту. Подходит для мелких фиксов, ad-hoc задач, поддержки.
- **Scrum-режим (Cycles)** — недельные спринты. Задачи из Backlog берутся в текущий Cycle перед его стартом; в течение недели статус двигается по доске; в конце — review состояния Cycle (что доехало до Done, что осталось).
- Длительность цикла — **1 неделя**. Включено в Linear: Team Settings → Study-buddy → **Workflow → Cycles**.
- Cycle 1 стартует 2026-10-04 (граница недели) — текущая неделя циклом не покрыта, это нормально для первого включения. [ST-21 (Merge to main)](https://linear.app/study-buddy-daryn/issue/ST-21) положен в Cycle 1.

## Labels

| Label | Когда ставить |
|---|---|
| `Backend` | Изменения в `server/` (FastAPI) |
| `Flutter` | Изменения в `lib/`, `test/` (Flutter-клиент) |
| `Process` | Релизный процесс, доки, CI, мерж-задачи |
| `Feature` | Новая функциональность (дефолтный label Linear) |
| `Improvement` | Улучшение существующего поведения |
| `Bug` | Дефект |

## Naming

- Issue title: `<Компонент>: <что делаем>` — например `Backend: rate-limit headers`.
- Ветка берётся из Linear (`gitBranchName` в issue) — `ukibasb/st-XX-slug`.
- Коммит, закрывающий issue: `Fixes ST-XX` или `Closes ST-XX` в теле PR/коммита — после подключения GitHub-интеграции Linear сам переводит статус.

## Estimate scale

Fibonacci-like points, по team-default Linear: `1, 2, 3, 5, 8` — где 1 ≈ до часа, 8 ≈ больше дня, требует дробления перед стартом.

## Definition of Done

Issue переводится в **Done** только когда:
1. Код смержен (или, для MVP-этапа задач без отдельного PR-на-issue — коммит присутствует на целевой ветке).
2. Тесты, относящиеся к задаче, зелёные (`flutter test` / `uv run pytest`).
3. Для задач с UI — фича руками проверена в работающем приложении (см. `CLAUDE.md` → "For UI or frontend changes...").

## GitHub

Репозиторий `unreal-kz/study-budy` подключён к Linear (issues зеркалятся в GitHub Issues #1+). При коммитах/PR с `Fixes ST-XX` / `Closes ST-XX` статус issue двигается автоматически.

## Текущее состояние на 2026-09-28

- MVP (`Study Buddy — MVP` project) — **Completed**: все 16 задач плана и мердж в `main` (ST-5…ST-21) сделаны, ветка `worktree-study-buddy-mvp` влита через PR #18.
- Активный project: **`Study Buddy — Beta (Daryn)`** — довести приложение до телефона Дарына без зависимости от Mac Баубека.
  - Housekeeping (Kanban, без цикла): ST-22 (sync main), ST-23 (чистка висячего worktree), ST-24 (ручной E2E).
  - Cycle 1 (2026-10-04 → 10-11): ST-26 (CI), ST-27 (spike: выбор $0-хостинга), ST-28 (защита `/buddy/chat`), ST-29 (деплой, блокируется ST-27+ST-28), ST-30 (релизный APK, блокируется ST-29).
  - Cycle 2 (2026-10-11 → 10-18): ST-31 (голос для AI Buddy — brainstorm + spec).
  - Backlog без цикла: ST-25 (реальный multi-user backend) — сознательно не в скоупе.
