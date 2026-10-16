# Ukraine Visual Train Sim

Реалістичний симулятор залізничного транспорту України.
Старт — **Київська міська електричка (Kyiv City Express)** на електропоїздах **ЕР9М, ЕД9М, ЕПЛ9Т**,
з реалістичною кабіною, сигналізацією та правилами за ПТЕ. Далі — вся Україна та метро.

**Стек:** Godot 4.7.2 (GDScript, строга типізація) · дані в JSON + JSON Schema · інструменти на Python.
**Стадія:** M0 (фундамент) готовий; ядро колійного графа з тестами; далі — M1 (фізика руху).

## Швидкий старт
```bash
pip install -r tools/requirements.txt
make check GODOT=/шлях/до/Godot_v4.7.2-stable   # дані + лінт + тести, як у CI
```
Відкрити в редакторі: Godot 4.7.2 → Import → `game/project.godot`.

## Структура
```
game/       Godot-проєкт: core/ (ядро симуляції), autoload/, views/, ui/, content/base/ (базовий вміст як мод), tests/
schemas/    JSON Schema для всіх типів даних
tools/      validate_data.py (+ tests/)
mods/       приклади модів
docs/       план, архітектура, рішення, глосарій, задачі
```

## Документація
- [docs/PLAN.md](docs/PLAN.md) — бачення, вибір технологій, дорожня карта (M0–M9), MVP, ризики
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — архітектура, структура репозиторію, формати даних, моди
- [docs/SIMULATION.md](docs/SIMULATION.md) — фізика руху, гальма, електрика, АЛСН, сигнали, правила ПТЕ
- [docs/RESEARCH.md](docs/RESEARCH.md) — що треба дослідити й зібрати
- [docs/TASKS.md](docs/TASKS.md) — покрокові задачі з критеріями готовності (✅ — зроблено)
- [docs/DECISIONS.md](docs/DECISIONS.md) — журнал архітектурних рішень
- [docs/GLOSSARY.md](docs/GLOSSARY.md) — терміни UA/RU/EN і назви в коді
- [GEMINI.md](GEMINI.md) — правила для ШІ-агента, що реалізує проєкт

Дані карт: © OpenStreetMap contributors (ODbL) — коли будуть імпортовані.
