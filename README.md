# ARTEM — Train Emulator

Реалістичний симулятор залізничного транспорту України.
Старт — **Київська міська електричка (Kyiv City Express)** на електропоїздах **ЕР9М, ЕД9М, ЕПЛ9Т**,
з реалістичною кабіною, сигналізацією та правилами за ПТЕ. Далі — вся Україна та метро.

**Стек:** Godot 4.7.2 (GDScript, строга типізація) · дані в JSON + JSON Schema · інструменти на Python.
Настільна демка: [запуск, завантаження, клавіші та обмеження](docs/DEMO.md).

**Стадія:** M0–M3: ядро, пневматика й електрика ЕР9М, холодний запуск, 3D/2.5D-вид з камерами, пульт, записані звуки, інформатор і 20 станцій кільця.

> Artificial Realistic Train Emulator with Modifications

## Як запустити
- **Готові настільні збірки 0.3.4:** [Windows ZIP з EXE](https://raw.githubusercontent.com/editorrc/train-simulator-/5ebe30df639f9cbc0c7595a0c45c5997e0876ebd/ARTEM-Windows.zip) · [macOS DMG](https://raw.githubusercontent.com/editorrc/train-simulator-/5ebe30df639f9cbc0c7595a0c45c5997e0876ebd/ARTEM-macOS-universal.dmg) · [SHA256](https://raw.githubusercontent.com/editorrc/train-simulator-/5ebe30df639f9cbc0c7595a0c45c5997e0876ebd/SHA256SUMS.txt). Розпакувати / перенести застосунок у «Програми»; рушій встановлювати не потрібно.
- **У браузері (GitHub Pages):** https://editorrc.github.io/train-simulator-/ — після разового ввімкнення Settings → Pages → Source: GitHub Actions.
- **Веб-прев'ю без встановлення:** https://raw.githack.com/editorrc/train-simulator-/editorial/web_preview/index.html
- **Локально (гра):** Godot 4.7.2 → Import → `game/project.godot` → F5, або `make demo GODOT=...`.
- **Локально (веб-збірка):** `make web-export GODOT=...`, потім `make serve` → http://localhost:8000

Керування у поточних вихідних кодах: ↑/↓ — контролер, ←/→ — кран; ⌫ — екстрене,
R/Shift+R/Option+R — реверсор; Space/V — тифон/свисток, Z/C — двері.
Tab — ракурс, F — з платформи, D — пульт, M — схема, Esc — пауза з продовженням.
Налаштування — ⌘+, (Windows Ctrl+,); переназначення — у розділі «Керування».
Повна [інструкція](docs/DEMO.md); [roadmap](docs/ROADMAP.md);
[передача роботи Claude](docs/HANDOFF_CLAUDE.md).

**0.3.4:** меню ARTEM / Train Emulator, серії ЕР9М, ЕД9М, ЕПЛ9Т і ЕКр1 «Тарпан»
(параметри нових серій — оцінки), склади й по шість забарвлень, стрімінг сцени
навколо поїзда, кешовані панелі, безшовне утримання тифона/свистка.
Для фінальних шрифтів перед імпортом: `python tools/prepare_fonts.py`.


## Швидкий старт
```bash
pip install -r tools/requirements.txt
make check GODOT=/шлях/до/Godot_v4.7.2-stable   # дані + лінт + тести, як у CI
```
Відкрити в редакторі: Godot 4.7.2 → Import → `game/project.godot`, або одразу `make demo GODOT=...`.

**Без Godot:** відкрийте `web_preview/index.html` у браузері — той самий полігон і та сама фізика (порт на JS, звірений з Godot).

Керування: `W/S` контролер, `Q/E` кран машиніста, `Backspace` екстрене, `R` реверсор, `1/2` стрілки, `P` пауза. У настільній демці прискорення часу вимкнено.

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
