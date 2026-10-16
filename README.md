# Ukraine Visual Train Sim

Реалістичний симулятор залізничного транспорту України.
Старт — **Київська міська електричка (Kyiv City Express)** на електропоїздах **ЕР9М, ЕД9М, ЕПЛ9Т**,
з реалістичною кабіною, сигналізацією та правилами за ПТЕ. Далі — вся Україна та метро.

**Стек:** Godot 4.7.2 (GDScript, строга типізація) · дані в JSON + JSON Schema · інструменти на Python.
**Стадія:** M0–M3: ядро, пневматика й електрика ЕР9М, холодний запуск, 2.5D-вид з камерами, пульт, звук.

## Як запустити
- **У браузері (GitHub Pages):** https://editorrc.github.io/train-simulator-/ — після разового ввімкнення Settings → Pages → Source: GitHub Actions.
- **Веб-прев'ю без встановлення:** https://raw.githack.com/editorrc/train-simulator-/editorial/web_preview/index.html
- **Локально (гра):** Godot 4.7.2 → Import → `game/project.godot` → F5, або `make demo GODOT=...`.
- **Локально (веб-збірка):** `make web-export GODOT=...`, потім `make serve` → http://localhost:8000

Керування: B АКБ, N кола керування, Y (тримати) доп. компресор, U струмоприймач, G/H ГВ увімк/вимк, M доп. машини, K компресори, J ЕПГ, L прожектор, Space тифон; W/S контролер, Q/E кран 395, Backspace екстрене, R реверсор; C камера, [ ] поворот, PgUp/PgDn нахил, колесо — масштаб, F1 панелі, F10 скинути розкладку, Esc меню.

## Швидкий старт
```bash
pip install -r tools/requirements.txt
make check GODOT=/шлях/до/Godot_v4.7.2-stable   # дані + лінт + тести, як у CI
```
Відкрити в редакторі: Godot 4.7.2 → Import → `game/project.godot`, або одразу `make demo GODOT=...`.

**Без Godot:** відкрийте `web_preview/index.html` у браузері — той самий полігон і та сама фізика (порт на JS, звірений з Godot).

Керування: `W/S` контролер, `Q/E` кран машиніста, `Backspace` екстрене, `R` реверсор, `1/2` стрілки, `P` пауза, `T` прискорення часу.

## Структура
```
game/       Godot-проєкт: core/ (ядро симуляції), autoload/, views/, ui/, content/base/ (базовий вміст як мод), tests/
schemas/    JSON Schema для всіх типів даних
tools/      validate_data.py, build_web_preview.py (+ tests/)
web_preview/ веб-прев'ю: sim.js (порт ядра), app.html → index.html
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
