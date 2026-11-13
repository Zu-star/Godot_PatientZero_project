# Интеграция комнат — заметки

Порядок игры: splash → menu → комната 1 → комната 2 (Archive Room) → комната 3 (Quarantine Room) → комната 4 (Laboratory, последняя).
Резервные копии делает владелец проекта; git не используется.

## Журнал изменений

### Шаг A — GameFlow, комната 1, key_pickup

| Файл | Что изменено | Зачем | Как вернуть |
| --- | --- | --- | --- |
| `scripts/game_flow.gd` | Новый файл (autoload GameFlow) | Порядок комнат и переходы в одном месте | Удалить файл и строку autoload |
| `project.godot` | В `[autoload]` добавлена строка `GameFlow="*res://scripts/game_flow.gd"` (после ZombieAmbience) | Регистрация менеджера | Удалить строку |
| `scripts/menu.gd`, `_on_play()` | `get_tree().change_scene_to_file(ROOM_SCENE)` → `GameFlow.start_new_game()` | Новая игра сбрасывает прогресс комнат 2–3 и идёт через GameFlow | Вернуть прежнюю строку. Константа `ROOM_SCENE` оставлена, сейчас не используется |
| `scripts/room_1.gd`, `_escape_to_room_2()` | `tween_callback(func(): get_tree().change_scene_to_file(ROOM_2_SCENE))` → `tween_callback(func(): GameFlow.room_finished(1))` | Следующую комнату выбирает GameFlow | Вернуть прежнюю строку. Константа `ROOM_2_SCENE` оставлена, сейчас не используется |
| `scripts/room_1.gd`, `_on_take_key()` | `_play_sfx("key_pickup.wav", -3.0)` → `_play_sfx("key_pickup.mp3", -3.0)` | Файл на самом деле MP3 («Not a WAV file») | Вернуть `.wav` вместе со старым именем файла |
| `assets/sounds/key_pickup.wav` | Переименован в `key_pickup.mp3` (содержимое не менялось). Godot создал `key_pickup.mp3.import` | То же | Переименовать обратно и переимпортировать |
| `assets/sounds/key_pickup.wav.import` | Удалён (с разрешения) | Остался бы без исходного файла | Из резервной копии |
| `assets/sounds/key_pickup.wav.import 11.45.47 copy` | Удалён (с разрешения) | Мусорная копия | Из резервной копии |
| `scripts/menu.gd`, `_on_quit()` | `get_tree().quit()` → `GameFlow.quit_game()` (с разрешения) | Выход без ошибки об утечке `zombie_ambience.mp3` | Вернуть прежнюю строку |

Больше не используются, но **не удалены**: `scenes/room_2.tscn` и `scripts/room_2.gd` (старая заглушка «ROOM 2 / BACK TO MENU»).
README.md проекта устарел: в нём описаны кнопки NEXT ROOM / MAIN MENU у заглушки комнаты 2, которых в коде нет.


### Шаг B — комната 2 (Archive Room)

| Файл | Что изменено | Зачем | Как вернуть |
| --- | --- | --- | --- |
| `archive_room/` | Скопирован из `_incoming/PacientZeroArchive/archive_room/` **без изменений** (вместе с `.import` и `.uid`; проверено `diff -r`) | Комната 2 | Удалить папку |
| `project.godot` | В `[autoload]` добавлена строка `ArchiveSession="*res://archive_room/scripts/session.gd"` (между ZombieAmbience и GameFlow) | Требование автора: состояние и сохранение комнаты | Удалить строку |

`next_level_scene` у корня `ArchiveLevel` оставлен пустым. Переход делает GameFlow по сигналу `quarantine_entered`, поэтому двойного перехода нет.
Не скопированы: `.godot`, `tests`, `PREVIEW.jpg`, `SPOILERS.md`, `README.md`, `ASSET_NOTES.md`, `project.godot`, `.gitignore`.
Особенность комнаты: `quarantine_entered` испускается один раз на одно сохранение. Если сохранение уже «пройдено», дверь сигнал не испустит. Поэтому новая игра (и переход через F9) сбрасывает прогресс.

### Шаг C — комната 3 (Quarantine Room)

Скопированы `_incoming/QuarantineRoom_Standalone/{scenes,scripts,assets}` → `quarantine_room/` (вместе с `quarantine_room.gd.uid`).
**Не** скопированы `.import`: в них были старые пути `res://assets/...`, Godot создал новые. Также не скопированы `.godot`, `project.godot`, `README.txt`, `TEST_CHECKLIST.txt`, `IMPLEMENTATION_REPORT.txt`, `.DS_Store`.

| Файл | Что изменено | Зачем | Как вернуть |
| --- | --- | --- | --- |
| `quarantine_room/scenes/QuarantineRoom.tscn` | `path="res://scripts/quarantine_room.gd"` → `path="res://quarantine_room/scripts/quarantine_room.gd"` | Новое место скрипта | Заменить обратно |
| `quarantine_room/scripts/quarantine_room.gd` | Во всех 15 путях `"res://assets/` → `"res://quarantine_room/assets/` (BG_ROOM, 11 в ART, 3 звука) | Новое место ассетов | Заменить обратно |
| то же | После `extends Control` добавлен `signal room_completed` | GameFlow подключает его к `room_finished(3)` | Удалить строку |
| то же, `_build_ending()` | Кнопка «Continue»: `func(): show_view("laboratory")` → `_continue_from_ending`; добавлена функция `_continue_from_ending()`: если `GameFlow.ROOMS[4]` не пуст, испускает `room_completed`, иначе показывает прежнюю заглушку | Переход в комнату 4, когда она появится | Вернуть лямбду, удалить функцию |
| то же, `_build_laboratory()` | Добавлена кнопка «Main Menu» (`Rect2(430, 575, 420, 60)`, под «Back to Quarantine Room») → `GameFlow.go_to_menu()` | Выход из заглушки, чтобы не было тупика | Удалить строку |
| то же, `_open_keypad_modal()` (стр. 337) | `int(i / 4)` → `int(i / 4.0)` (результат тот же) | Убрать предупреждение «Integer division» | Заменить обратно |
| `scripts/game_flow.gd`, `quit_game()` | Перед выходом останавливает **все** `AudioStreamPlayer` в дереве, а не только ZombieAmbience | При закрытии окна в комнате 2 была ошибка об утечке `archive_room/assets/ambient.wav` | — |

Остальной код комнаты 3 не менялся. Все правки помечены комментарием `# Integration (GameFlow)`.

### После шага C — зацикливание фоновых звуков (с разрешения)

До интеграции фоновые звуки молчали: код ставил `loop_mode = LOOP_FORWARD` без `loop_end`, а он по умолчанию 0, поэтому звук сразу останавливался. Код не менялся, правились только настройки импорта.

| Файл | Что изменено | Зачем | Как вернуть |
| --- | --- | --- | --- |
| `assets/sounds/menu_ambience.wav.import` | `edit/loop_mode=0` → `edit/loop_mode=2` (Forward, `loop_end=-1` = до конца файла) | Фон splash и меню | Вернуть `0` и переимпортировать |
| `assets/sounds/lab_ambience.wav.import` | то же | Фон комнаты 1 | то же |
| `quarantine_room/assets/audio/ambient.wav.import` | то же | Фон комнаты 3 | то же |

Проверено: у всех четырёх фонов `playing=true`. Теперь в splash, меню и комнате 1 их собственный фон звучит вместе с зомби-фоном.

### Шаг D — отладка и smoke-test

| Файл | Что изменено | Зачем | Как вернуть |
| --- | --- | --- | --- |
| `scripts/debug_panel.gd` | Новый файл: панель F9/F10 | Отладка | Удалить файл и строку в GameFlow |
| `scripts/game_flow.gd`, `_ready()` | `if OS.is_debug_build(): add_child(load("res://scripts/debug_panel.gd").new())` | Панель только в debug-сборке | Удалить строки |
| `scripts/game_flow.gd`, `quit_game()` | Добавлен параметр `exit_code` (по умолчанию 0) | Код выхода для smoke-test | — |
| `scripts/dev_smoke_test.gd` | Новый файл: smoke-test | Проверка, что все комнаты из `ROOMS` загружаются | Удалить файл |

**Панель отладки** (только debug-сборка, в экспорте release её нет):
- **F9** показывает и скрывает панель. Кнопки: «Меню», «Комната N» для каждой непустой записи в `ROOMS` (комната 4 появится сама), «Сбросить прогресс комнат 2–3».
- Переход в комнату через панель сначала сбрасывает её сохранение. Поэтому комната 2 с «пройденным» сохранением не застрянет.
- «Сбросить прогресс…» сбрасывает сохранения всех комнат, кроме 1. Если ты сейчас в комнате 2 или выше, комната перезагружается: иначе её состояние осталось бы в памяти.
- **F10** засчитывает текущую комнату пройденной (`room_finished`). В последней комнате и вне комнат ничего не происходит, только сообщение в выводе.
- F9 и F10 не пересекаются с клавишами комнат (Escape, H).

**Smoke-test:**
```sh
godot --headless --path . -s res://scripts/dev_smoke_test.gd
```
Тест по очереди загружает каждую комнату из `ROOMS`, создаёт её, ждёт 2 с и освобождает. Пустые пути пропускает. Код выхода: 0, если всё загрузилось, 1 при ошибке. Комната 3 при открытии записывает свой файл сохранения. Сцена создаётся напрямую, без GameFlow, поэтому переключение касаний и зомби-фона в тесте не проверяется.

### Шаг E — комната 4 (Laboratory)

Комната живёт только в `lab_room/`. Комнаты 1–3, `project.godot` и autoload не менялись.

| Файл | Что изменено | Зачем | Как вернуть |
| --- | --- | --- | --- |
| `lab_room/scenes/LabRoom.tscn` | Новый файл: корень `Control` со скриптом | Сцена комнаты 4 | Удалить |
| `lab_room/scripts/lab_room.gd` | Новый файл: вся комната строится кодом | Логика, HUD, окна | Удалить |
| `lab_room/scripts/lab_texts.gd` | Новый файл: все тексты, подсказки и код `417` | Лёгкая правка текстов | Удалить |
| `lab_room/assets/audio/ambient.wav`, `click.wav`, `release.wav` | Скопированы из `archive_room/assets/` без изменений | Свои звуки, без ссылок на чужую комнату | Удалить |
| `lab_room/assets/audio/ambient.wav.import` | `edit/loop_mode=0` → `edit/loop_mode=2` (как у фона комнаты 3) | Фон зациклен; предупреждений импорта нет | Вернуть `0` и переимпортировать |
| `lab_room/assets/**/*.import` | Созданы Godot при импорте картинок и звуков | — | — |
| `scripts/game_flow.gd`, `ROOMS` | `4: ""` → `4: "res://lab_room/scenes/LabRoom.tscn"` | Подключение комнаты 4 | Вернуть пустую строку |

Картинки (`backgrounds/`, `closeups/`, `icons/`) лежат там, куда их положил владелец; не перемещались и не переименовывались.

**Как устроена комната 4**
- Состояние только в памяти (`notebook_read`, `has_keycard`, `card_selected`, `code_seen`, `keypad_unlocked`, `vault_open`, `has_vaccine`, `finished`). Сохранения нет, при каждом входе комната начинается заново. Поэтому `reset_room_progress()` для неё не нужен.
- Шаги: стол → записи «RESEARCH NOTES»; халат → карман → карта (сразу выбрана); доска → цифры 4, 1, 7 нарисованы кодом; хранилище → считыватель (нужна выбранная карта) → клавиатура (код 417) → открытое хранилище → пробирка → окно «VACCINE OBTAINED» → «Continue» → затемнение 0,6 с → финальный экран.
- Порядок свободный, кроме «хранилище требует карту» и «код вводится после карты». Тупиков нет: если закрыть окно вакцины через Escape, нажатие на пробирку откроет его снова.
- Финальный экран: `ending.png`, HUD скрыт, кнопки «Main Menu» (`GameFlow.go_to_menu()`) и «Play again» (`GameFlow.start_new_game()`).
- `signal room_completed` испускается **один раз** при показе финального экрана. GameFlow вызывает `room_finished(4)`, но `ROOMS[5]` нет, поэтому сцена не меняется (проверено: через 2 с игра остаётся в комнате 4). **Внимание:** если вписать комнату 5 в `ROOMS`, GameFlow переведёт игрока в неё сразу при показе финального экрана, и экран почти не будет виден. Тогда испускание `room_completed` нужно перенести из `_build_ending()` в кнопку (например, «Continue»).
- Касания: обычные `Button`, эмуляция касаний включена (комнаты 4 нет в `ROOMS_WITH_OWN_TOUCH_BRIDGE`).
- Звук: `ambient.wav` −15 дБ (зациклен), `click.wav` на всех кнопках, `release.wav` на успехах (карта принята, хранилище открыто, вакцина взята). «Sound: off» ставит фон на паузу. В `_exit_tree` все три плеера останавливаются.
- Нет картинки → на её месте тёмная заглушка с подписью, в выводе `MISSING ART: <файл>`.

**Проверено**: переход из комнаты 3 по «Continue» (без правок комнаты 3), кнопка «Комната 4» на панели F9, smoke-test (`room 4: OK`), полное прохождение скриптом через GameFlow, выход из игры в комнате 4 и после неё без утечек, отладчик без ошибок и предупреждений.

### Шаг F — новая комната 1 (FIRST ROOM) вместо старой

Источник: `_incoming/FIRST_ROOM/` (мини-проект 1280×617, `Main.tscn` + `main.gd`). Исходники в `_incoming` не менялись. Новая комната живёт только в `first_room/`. Старая комната 1, splash и меню не менялись и не удалялись.

**Что скопировано** (структура `assets/` сохранена, `.import` создал Godot):
- `first_room/scenes/FirstRoom.tscn` ← `Main.tscn`; `first_room/scripts/first_room.gd` ← `main.gd`.
- `first_room/assets/`: `room_closed.jpg`, `room_door_open.jpg`, `task_reference.jpg`, `key_reward_reference.jpg`, `game_over.jpg`, `room2_background.png`, `key.png`, `backgrounds/splash_icon_art.png`, `backgrounds/menu_cinematic.png`, `fonts/NotoSerif-CondensedBold.ttf`, `sounds/`: `user_ambient.wav`, `computer_beep.wav`, `correct_answer.wav`, `door_open.wav`, `key_pickup.wav`, `timer_tick.wav`, `user_click.wav`, `user_release.wav`, `zombie_attack.mp3`.
- `room2_background.png`, splash- и menu-картинки и шрифт нужны только заставке и меню комнаты (при запуске из игры не показываются), но скрипт грузит их через `preload`/`load`, поэтому скопированы.
- **Не** скопированы (скриптом не используются): `door_open_button_reference.jpg`, `hud_reference.jpg`, `main_menu.jpg`, `splash_screen.jpg`, `backgrounds/splash_screen.png`, `sounds/lab_ambience.wav`, `menu_ambience.wav`, `ui_click.wav`, `zombie_ambience.mp3`, `zombie_ambience.wav`, `zombie_stinger.wav`, а также `README.txt`, `project.godot`.

| Файл | Что изменено | Зачем | Как вернуть |
| --- | --- | --- | --- |
| `first_room/scenes/FirstRoom.tscn` | `path="res://main.gd"` → `path="res://first_room/scripts/first_room.gd"` | Новое место скрипта | Заменить обратно |
| `first_room/scripts/first_room.gd` | Во всех 13 путях `res://assets/` → `res://first_room/assets/` (9 `preload`, 2 шрифта, `user_ambient.wav`, папка звуков в `_play_sound`) | Новое место ассетов | Заменить обратно |
| то же, правка 1 (после `extends Control`) | Добавлены `signal room_completed` и `const DOOR_OPEN_DELAY := 2.5` | Конец комнаты для GameFlow | Удалить строки |
| то же, правка 2, `_ready()` | `_show_splash()` → `_restart_game()` (старая строка оставлена в комментарии) | Заставка и меню — свои у игры; комната сразу начинается: HUD, зоны, таймер | Вернуть `_show_splash()` |
| то же, правка 3, `_show_game_over()` и `_show_pause_menu()` | `main_menu.pressed.connect(_show_main_menu)` → `connect(_exit_to_game_menu)`; добавлена `_exit_to_game_menu()`: есть `/root/GameFlow` → `GameFlow.go_to_menu()`, иначе `_show_main_menu()` | «GO TO MAIN MENU» и кнопка меню на Game Over ведут в меню игры; отдельный запуск комнаты работает как раньше | Вернуть `_show_main_menu`, удалить функцию |
| то же, правка 4, `_show_door_open()` | В конце вызов `_emit_room_completed_later()`; добавлены функция и переменные `door_run_id`, `room_completed_sent`. Ждёт `DOOR_OPEN_DELAY`, пока пауза — ждёт возобновления, затем один раз испускает `room_completed`, только если комната всё ещё в состоянии `door_open` | Переход в комнату 2 через 2,5 с после открытия двери, без оверлеев. START AGAIN во время ожидания отменяет испускание | Удалить вызов, функцию и переменные |
| то же, правка 5, `_process()` и `_input()` | `get_global_mouse_position()` → `get_local_mouse_position()`; в `_input` проверки по `get_local_mouse_position()` и `key_sprite.get_rect()` вместо `event.position` и `get_global_rect()`; `key_drag_offset` от локальной позиции | Комната смещена на 51 px внутри обёртки; координаты (`door_drop_rect` и др.) остались прежними | Вернуть прежние строки |
| то же, правка 6, `_update_status_labels()` | `int(time_left / 60)` → `int(time_left / 60.0)` (результат тот же) | Предупреждение «Integer division» | Заменить обратно |
| `first_room/assets/sounds/user_ambient.wav.import` | `edit/loop_mode=0` → `edit/loop_mode=2` (правка 7, код не менялся) | Без неё фон комнаты молчал (`playing=false`), как раньше у других фонов | Вернуть `0` и переимпортировать |
| `first_room/scenes/FirstRoomHost.tscn`, `first_room/scripts/first_room_host.gd` | Новые файлы: обёртка | См. ниже | Удалить |
| `scripts/game_flow.gd`, `ROOMS` | `1: "res://scenes/room_1.tscn"` → `1: "res://first_room/scenes/FirstRoomHost.tscn"` | Подключение новой комнаты 1 | Вернуть старый путь |
| `scripts/game_flow.gd`, `_on_scene_changed()` | `current_room >= 2` → `current_room >= 1` | Зомби-фон выключается в любой комнате; у новой комнаты 1 свой фон `user_ambient.wav`. Меню включает его обратно (`menu.gd`, без изменений) | Вернуть `>= 2` (старая комната 1 сама вызывала `resume_ambience()`) |

Все правки в `first_room.gd` помечены комментарием `# Integration (GameFlow)`. Остальной код комнаты (задача, ключ, пауза, Game Over, заставка, меню, инструкция) не менялся.

**Как работает обёртка `FirstRoomHost`**
- Корень `Control` на весь экран 1280×720 → `Bars` (`ColorRect` на весь экран, `#04070c` — цвет фона проекта комнаты) → `Stage` (`Control` 1280×617, `position = (0, 51)`, `clip_contents = true`) → экземпляр `FirstRoom.tscn` (растянут на `Stage`, то есть ровно 1280×617, как в исходном проекте).
- У корня обёртки `signal room_completed`; `first_room_host.gd` пересылает в него сигнал комнаты. GameFlow подключает сигнал у корня текущей сцены (обёртки) к `room_finished(1)`.
- Все координаты комнаты остались в её системе 1280×617; на экране они на 51 px ниже.
- Комнату можно запускать отдельно (`FirstRoomHost.tscn` или `FirstRoom.tscn`): без GameFlow «GO TO MAIN MENU» открывает её собственное меню. Собственная заставка не показывается (она вызывалась из `_ready`).

**Звук**: в комнате 1 играет только `user_ambient.wav` (−5 дБ, зациклен) и короткие эффекты комнаты. Все плееры — дочерние узлы комнаты и исчезают вместе с ней при переходе в меню или комнату 2.
**Касания**: обычные `Button` и мышь, эмуляция касаний включена (комнаты 1 нет в `ROOMS_WITH_OWN_TOUCH_BRIDGE`). Ключ перетаскивается эмулированной мышью. На телефоне **не** проверено.
**Сохранения** у комнаты нет: при каждом входе она начинается заново, `reset_room_progress()` для неё не нужен.

**Старая комната 1 больше не используется, но не удалена**: `scenes/room_1.tscn`, `scripts/room_1.gd` (а также ранее отключённые `scenes/room_2.tscn`, `scripts/room_2.gd`; константа `ROOM_SCENE` в `menu.gd`). Ресурсы, которые использовала только она: `assets/backgrounds/medical_room.png`, `assets/backgrounds/storyboard/zombie_attack_art.jpg`, `assets/ui/key_icon.png`, `assets/ui/search_icon.png`, `assets/sounds/lab_ambience.wav`, `zombie_stinger.wav`, `computer_beep.wav`, `correct_answer.wav`, `door_open.wav`, `key_pickup.mp3`, `timer_tick.wav`; `zombie_attack.mp3` нужен только `ZombieAmbience.play_lose_sound()`, который вызывала только старая комната 1. Остальные картинки `storyboard/` могут быть нужны splash и меню — не проверялись по одной.

**Проверено** (временные тесты вне проекта, headless, ввод мышью через `Input.parse_input_event`):
- splash → меню → BEGIN SURVIVAL → новая комната 1: `current_room = 1`, эмуляция касаний включена, зомби-фон выключен, играет только `user_ambient.wav`;
- компьютер → C → SUBMIT → OK → перетаскивание ключа из (600,450) на дверь → через 2,5 с один `room_completed` → GameFlow с затемнением открывает комнату 2;
- пауза во время ожидания: пока открыта — сигнала нет, после RESUME/Escape — сразу; START AGAIN во время ожидания — сигнала нет, чистый запуск;
- 3 неверных ответа и истёкший таймер 35 с → Game Over; кнопка перезапуска и START AGAIN — чистый запуск (35 с, 3 попытки, дверь закрыта);
- «GO TO MAIN MENU» (пауза) и кнопка меню на Game Over → меню игры; звук комнаты пропадает, зомби-фон и фон меню снова играют;
- Escape открывает и закрывает паузу (таймер стоит и снова идёт);
- F9: на панели «Комната 1» открывает новую комнату; F10 в комнате 1 → комната 2;
- smoke-test: `room 1: OK (res://first_room/scenes/FirstRoomHost.tscn)`, `ALL OK`;
- предупреждения GDScript: в копии проекта с предупреждениями-как-ошибками у `first_room.gd` и `first_room_host.gd` их нет; запуск проекта в debug — ошибок нет.

### Шаг G (A) — новые фоны комнат 1 и 3

Источник: `_incoming/new_art/` (не менялся). Конвертация встроенной `sips` (JPG, качество 90). Старые картинки не удалены, а перенесены в `_old_art/` (в нём пустой `.gdignore`, Godot папку не импортирует).

| Файл | Что изменено | Зачем | Как вернуть |
| --- | --- | --- | --- |
| `quarantine_room/assets/backgrounds/quarantine_room.jpg` | Заменён: `room3_background.png` → JPG 1920×1080 (было 1024×572, растягивалось на 1280×720 с небольшим искажением) | Новый фон комнаты 3 | Перенести обратно `_old_art/quarantine_room/quarantine_room.jpg` |
| `first_room/assets/room_closed.jpg` | Заменён: `room1_closed.png` (5120×2468) → JPG 2560×1234 | Новый фон комнаты 1 | Перенести обратно `_old_art/first_room/room_closed.jpg` |
| `first_room/assets/room_door_open.jpg` | Заменён: `room1_door_open.png` → JPG 2560×1234 | То же, открытая дверь | Перенести обратно `_old_art/first_room/room_door_open.jpg` |
| `first_room/scripts/first_room.gd`, `_build_room()` | После `add_child(main_bg)` добавлена строка `main_bg.size = VIEW_SIZE` | До `add_child` размер TextureRect упирается в размер текстуры; со старой картинкой 1280×617 это совпадало, с 2560×1234 фон показывался вдвое крупнее (видна только левая верхняя четверть) | Удалить строку (и комментарий над ней) |
| `.import` этих трёх картинок | Не менялись; Godot переимпортировал картинки сам | — | — |

**Зоны** проверены рисованием поверх новых фонов и скриншотами из игры: координаты подходят, **не менялись**.
- Комната 1: `computer_hotspot` Rect2(88,198,340,214) — на мониторе; `door_hotspot` Rect2(895,98,320,420) и `door_drop_rect` Rect2(885,72,345,455) — на двери; `key_home_position` (600,450) — на столе. HUD (таймер, попытки, MENU) на непрозрачных панелях, читается.
- Комната 3: все 6 зон главного вида (кровать, папки, шкаф, щиток, терминал, дверь) на своих предметах. Крупные планы не трогались.

**Не меняли, но стоит знать**: `first_room/assets/task_reference.jpg` и `key_reward_reference.jpg` (окно задачи и окно с ключом) — полноэкранные картинки, по краям которых нарисована **старая** комната (тёмное окно, лампа, старый монитор). С новым фоном это заметно по стилю. `room2_background.png` используется только внутренним экраном «room2» комнаты 1, в игре он не показывается. `game_over.jpg` от фона не зависит.

### Шаг H (B) — общее меню паузы, звук в GameFlow, комнаты 3 и 4

| Файл | Что изменено | Зачем | Как вернуть |
| --- | --- | --- | --- |
| `game/ui/pz_pause_menu.gd` | Новый файл: общее меню паузы (не autoload) | Одинаковое меню во всех комнатах | Удалить файл (и подключения в комнатах) |
| `scripts/game_flow.gd` | Добавлены `var sound_enabled := true` и `func set_sound_enabled(on)` → `AudioServer.set_bus_mute(Master, not on)` | Звук всей игры включается и выключается из меню | Удалить переменную и функцию |
| `quarantine_room/scripts/quarantine_room.gd` | Добавлены `const PZ_PAUSE_MENU` (preload), `var pause_menu`; в конце `_ready()` создание меню и `setup(...)`; новая функция `_open_pause_menu()`. Кнопка «Menu» в `_update_hud()` и Escape в `_input()` вызывают `_open_pause_menu` вместо `show_menu` | Общее меню вместо своего | Вернуть `show_menu` в двух местах, удалить добавленные строки |
| то же | `show_menu`, `_toggle_hotspots`, `_toggle_sound`, `_confirm_restart` **не удалены**, помечены «no longer used» | Старый код остаётся | — |
| `lab_room/scripts/lab_room.gd` | То же, что в комнате 3: `PZ_PAUSE_MENU`, `pause_menu`, создание в `_ready()`, `_open_pause_menu()`; «Menu» в `_update_hud()` и Escape в `_input()` | То же | То же |
| то же | `show_menu`, `_toggle_hotspots_from_menu`, `_toggle_sound`, `_confirm_restart` не удалены, помечены «no longer used» | — | — |

Все правки в комнатах помечены `# Integration (GameFlow)`.

**Как устроено меню** (`game/ui/pz_pause_menu.gd`)
- `extends CanvasLayer`, `layer = 50`: выше комнат, ниже затемнения GameFlow (100) и панели F9 (110). Свой слой нужен, потому что комната 1 сидит в `Stage` 1280×617 со сдвигом 51 px; на CanvasLayer меню во всех комнатах в одних и тех же экранных координатах 1280×720. Стили и шрифт не наследуются от комнаты (своей темы нет, шрифт стандартный).
- `process_mode = ALWAYS`. `get_tree().paused` меню **не** трогает: комнаты 2–4 и раньше не останавливались, а комната 1 ставит на паузу свой таймер сама (через `on_open`/`on_close`).
- Подключение: `pause_menu = preload("res://game/ui/pz_pause_menu.gd").new()`, `add_child(pause_menu)`, `pause_menu.setup({...})`, затем `pause_menu.open()`. Ключи `setup`: `on_open` (если вернёт `false`, меню не откроется), `on_close`, `get_hotspots`, `set_hotspots(on)`, `on_restart`. Все необязательны.
- Вид: затемнение `(0.02, 0.015, 0.035, 0.78)`; панель Rect2(390, 80, 500, 560), заливка `#211b2a`, рамка `#9b89a5`, скругление 8; заголовок «PAUSE MENU» 30 px; 6 кнопок 280×64 (x = 500, y = 170 + 76·i), текст 20 px `#e4d9c3`, кнопки `#302a3b`/`#8d7d98` (наведение `#494054`/`#cab7c9`, нажатие `#66536d`). Цвета — из кода комнаты 3.
- Кнопки: Resume, Show hotspots: OFF/ON, Sound: ON/OFF, Restart level, Main menu, Close menu.
  - Resume и Close menu → `close()` → `on_close`.
  - Restart level → окно «Restart this level?» (Cancel → обратно в меню; Restart → `close()`, затем `on_restart`).
  - Main menu → окно «Return to the main menu?» / «Your progress in this level will be lost.» (Cancel → в меню; Main menu → `GameFlow.go_to_menu()`; кнопки блокируются, комната остаётся на паузе до смены сцены).
  - Окна подтверждения: панель Rect2(390, 190, 500, 330), кнопки 190×64.
- Клавиши, пока меню открыто: Escape в меню закрывает его, в окне подтверждения работает как Cancel; H перехватывается (рамки не переключаются под меню). F9/F10 не перехватываются.
- Щелчок кнопок — `quarantine_room/assets/audio/click.wav`, −18 дБ, во всех комнатах один и тот же.
- Звук: `GameFlow.sound_enabled` хранится только до закрытия игры (на диск не пишется). Mute шины Master выключает всё, в том числе главное меню. Собственные `sound_enabled` комнат остаются `true` и не меняются, конфликта нет.

**Комнаты 3 и 4**: рамки — `show_hotspots = on; _refresh_view()`; перезапуск — `_reset_progress()` (комната 3, сохранение перезаписывается сброшенным) и `_restart_level()` (комната 4). Escape работает как раньше (закрыть окно комнаты → «назад» → меню), только открывает общее меню. Клавиша H вне меню — как раньше.

**Проверено** (временный тест вне проекта, окно, ввод через `Input.parse_input_event`): в комнатах 3 и 4 кнопка «Menu» и Escape открывают меню; панель и кнопки совпадают по координатам и размерам; рамки вкл/выкл, звук вкл/выкл (`AudioServer.is_bus_mute`), Close menu, Escape закрывает, Restart → Escape/Cancel → снова меню, Restart → прогресс сброшен, Main menu → Cancel → меню, Main menu → сцена меню. Скрипты без предупреждений (копия проекта, предупреждения по умолчанию → ошибки), smoke-test ALL OK, запуск без ошибок.

### Шаг I (C) — общее меню в комнатах 2 и 1

| Файл | Что изменено | Зачем | Как вернуть |
| --- | --- | --- | --- |
| `archive_room/scripts/archive_level.gd` | Добавлены `const PZ_PAUSE_MENU`, `var pause_menu`; в конце `_ready()` создание меню и `setup(...)`; функции `_open_pause_menu()` и `_restart_level()` (те же 4 действия, что у кнопки «Restart» в `confirm_reset()`: `ArchiveSession.reset()`, `card_selected = false`, `hint_step = 0`, `show_view("room")`). «Menu» в `update_hud()` и Escape в `_unhandled_key_input()` вызывают `_open_pause_menu` вместо `show_menu` | Общее меню; у старого перезапуска не было функции с именем | Вернуть `show_menu` в двух местах, удалить добавленные строки и функции |
| то же | `show_menu`, `confirm_reset` не удалены, помечены «no longer used». Строка «Progress saves automatically» и заголовок «ARCHIVE ROOM» больше не показываются (они были только в старом меню) | — | — |
| `first_room/scripts/first_room.gd` | Добавлены `const PZ_PAUSE_MENU`, `const HOTSPOT_OUTLINES`, `var pause_menu`, `var hotspot_outlines`; в `_ready()` после `_restart_game()` создание рамок и меню. В меню: `on_open` = `_pause_gameplay`, `on_close` = `_resume_game`, рамки = видимость `hotspot_outlines`, `on_restart` = `_restart_game` | Общее меню, пауза таймера как раньше | Удалить добавленные строки |
| то же | Начало `_show_pause_menu()` (проверка состояния, `state_before_pause`, `current_state = "paused"`, `timer.stop()`, `key_dragging = false`) вынесено **без изменений** в новую `_pause_gameplay() -> bool`; `_show_pause_menu()` теперь начинается с `if not _pause_gameplay(): return`, остальное (старое окно PAUSED) не менялось. Добавлена `_open_pause_menu()` | Разделить остановку таймера и показ меню | Вернуть строки в `_show_pause_menu()`, удалить две функции |
| то же | `menu_button.pressed` (HUD) и `task_menu.pressed` (окно задачи) → `_open_pause_menu` вместо `_show_pause_menu`. В `_input()` Escape: при `paused` → `pause_menu.close()` вместо `_resume_game()`, иначе → `_open_pause_menu()` вместо `_show_pause_menu()` (условия по состояниям прежние) | Кнопки MENU и Escape открывают общее меню | Вернуть прежние вызовы |
| `first_room/scripts/first_room_hotspot_outlines.gd` | Новый файл: рамки поверх `computer_hotspot`, `door_hotspot` и `key_sprite` (когда они есть и видны), каждый кадр по их текущему положению; `z_index = 13` (над зонами и ключом, под окном задачи 20); вид как у рамок комнат 2–4 | «Show hotspots» в комнате 1 без изменения того, как комната строит зоны | Удалить файл и строки в `_ready()` |

Все правки помечены `# Integration (GameFlow)`. Старое окно PAUSED (`_show_pause_menu`, RESUME / START AGAIN / GO TO MAIN MENU) не удалено и больше не вызывается. Game Over и остальные экраны комнаты 1 не менялись.

**Комната 1 и пауза**: меню открывается в тех же состояниях, что и старая пауза (кнопкой: всё, кроме `paused`, `menu`, `splash`, `gameover`; Escape: `playing`, `key_ready`, `room2`, `door_open`). При открытии таймер останавливается, при Resume / Close menu / Escape — состояние возвращается и таймер идёт дальше с того же значения. Restart level: меню закрывается (`_resume_game`), затем `_restart_game()`. Main menu: комната остаётся на паузе до смены сцены. Ожидание перехода после открытия двери (`_emit_room_completed_later`) по-прежнему ждёт, пока пауза.

**Комната 2 и касания**: меню на своём CanvasLayer получает нажатия, которые мост касаний комнаты (`_input`, `push_input`) превращает в мышь. Проверено касаниями `InputEventScreenTouch` (эмуляция касаний в комнате 2 выключена).

**Проверено** (тот же временный тест, окно): во всех четырёх комнатах кнопка «Menu» и Escape открывают меню; **панель, заголовок и 6 кнопок совпадают по координатам и размерам во всех комнатах** (панель (390,80) 500×560, кнопки 280×64); рамки, звук, Close menu, Escape, Restart (Escape/Cancel/подтверждение, прогресс сброшен), Main menu (Cancel/подтверждение → сцена меню). Комната 1: таймер стоит, пока меню открыто (34 → 34 за 2,3 с), и идёт после Resume; MENU в окне задачи; рамки компьютера, двери и ключа; на Game Over меню не открывается; после открытия двери перехода нет, пока меню открыто, после Resume — переход в комнату 2. Комната 2: открытие и закрытие касанием. Скрипты без новых предупреждений, smoke-test ALL OK, запуск без ошибок.

### Шаг J (D) — полная проверка

Файлы проекта на этом шаге не менялись (только эти заметки). Временные тесты лежали вне проекта.

**Проверено** (окно, ввод через `Input.parse_input_event`):
- обычный старт: splash → меню → BEGIN SURVIVAL → комната 1, Escape открывает общее меню;
- во всех 4 комнатах: «Menu»/«MENU» и Escape открывают меню, все 6 кнопок и оба окна подтверждения работают (Cancel, Escape, подтверждение); раскладка панели и кнопок совпадает по координатам, а скриншоты панели совпадают попиксельно (кроме 4 скруглённых углов, где просвечивает фон комнаты);
- F9 при открытом меню показывает и скрывает панель отладки (она выше меню), кнопка «Комната 3» на ней работает; F10 при открытом меню и без него переводит в следующую комнату;
- H вне меню переключает рамки (комнаты 3, 4), при открытом меню не действует;
- звук: выключен в комнате 4 → остаётся выключенным в комнате 2, в главном меню и в комнате 1 (в меню «Sound: OFF»), включается обратно из любой комнаты;
- smoke-test ALL OK; запуск через debug без ошибок и предупреждений; изменённые и новые скрипты без предупреждений GDScript (копия проекта, предупреждения по умолчанию → ошибки), кроме старого известного `archive_level.gd:386`.

**Не проверено** (нужен телефон или прохождение руками): касания на телефоне (в комнатах 1, 3, 4 — эмуляция мыши, в комнате 2 проверено только синтетическими касаниями), читаемость и размер кнопок на реальном экране, полное прохождение всех комнат руками с меню.

**Известное, не исправлено** (ждёт решения владельца): иногда (≈1 раз из 5) при закрытии игры, когда открыта комната 3, выводится `2 ObjectDB instances were leaked` / `Resource still in use: quarantine_room/assets/audio/ambient.wav`. Причина — `GameFlow.quit_game()` ждёт после остановки звуков только 0,1 с. Было и до этих шагов. Возможное решение: ждать дольше (0,25 с и два кадра).

## Как подключить общее меню к новой комнате

1. `const PZ_PAUSE_MENU := preload("res://game/ui/pz_pause_menu.gd")`, в `_ready()`: `pause_menu = PZ_PAUSE_MENU.new()`, `add_child(pause_menu)`, `pause_menu.setup({...})` (ключи: `on_open`, `on_close`, `get_hotspots`, `set_hotspots`, `on_restart`; см. шаг H).
2. Кнопка «Menu» и Escape комнаты → `pause_menu.open()`. Escape внутри меню меню обрабатывает само.
3. Если в комнате есть таймер или другое, что должно стоять: остановить в `on_open` (вернуть `false`, если открывать нельзя), продолжить в `on_close`.
4. Свой звук комнате не нужен: звук всей игры — `GameFlow.set_sound_enabled()`.

## Комната 4: как поменять код, тексты и зоны

- **Код хранилища**: `lab_room/scripts/lab_texts.gd`, `VAULT_CODE := "417"`. От него автоматически меняются цифры на доске, длина ввода на клавиатуре и подсказка «Enter 4, 1, 7…». Цифры на доске идут слева направо: красная, синяя, зелёная. Код должен оставаться трёхзначным: на доске три квадрата (`CODE_CENTERS` в `lab_room.gd`).
- **Тексты, подсказки, подписи зон**: всё в `lab_texts.gd`. Подсказки — словарь `HINTS` по этапам (`start`, `card`, `code`, `reader`, `keypad`, `vaccine`), по 3 уровня.
- **Зоны нажатия**: в `lab_room.gd`, функции `_build_room()`, `_build_desk()`, `_build_coat()`, `_build_vault()`. Координаты на сетке 1280×720, видны клавишей H или «Show hotspots» в меню.
- **Центры цифр на доске**: `CODE_CENTERS` в начале `lab_room.gd`.

## Как заменить комнату 4

1. Положить новую комнату в свою папку и вписать путь в `GameFlow.ROOMS[4]`. Старую папку `lab_room/` можно оставить.
2. Если комната последняя: на финальном экране кнопка `GameFlow.go_to_menu()`. `signal room_completed` можно испускать в любой момент: пока `ROOMS[5]` пуст или его нет, GameFlow ничего не делает.
3. Если у новой комнаты есть свой файл сохранения — добавить ветку в `reset_room_progress()`; если она сама превращает касания в мышь — добавить 4 в `ROOMS_WITH_OWN_TOUCH_BRIDGE`.
4. Комната 3 менять не нужно: её «Continue» переходит в комнату 4, пока `ROOMS[4]` не пуст.
5. Запустить smoke-test.

## Известные предупреждения (оставлены по решению владельца)

Были до интеграции. Видны в отладчике при запуске сцены (в выводе `--headless` не печатаются):
- `scripts/room_1.gd:353`, `:363` — параметр `size` перекрывает свойство Control; `:512` — Integer division. После шага F старая комната 1 не загружается, поэтому в игре их больше нет (файл не менялся).
- `archive_room/scripts/archive_level.gd:386` (до шага C была строка 375) — Integer division, в `show_lock()`. Код комнаты 2 по ТЗ не правится. Решение: `int(i/3.0)` вместо `(i/3)`, если понадобится.

## Как работает GameFlow

- `ROOMS` — словарь «номер → путь к сцене». **Единственное** место, где перечислены комнаты. Пустая строка значит, что комнаты пока нет.
- `ROOMS_WITH_OWN_TOUCH_BRIDGE` (рядом с `ROOMS`) — комнаты, которые сами превращают касания в мышь. Сейчас только `[2]`.
- `reset_room_progress(n)` (рядом с ними) — сброс сохранений комнат, у которых есть свой файл: 2 → `ArchiveSession.reset()`, 3 → удаление `user://quarantine_room_save.json`.
- `start_new_game()` сбрасывает прогресс всех комнат, кроме 1, и переходит в комнату 1.
- `go_to_room(n)`: затемнение 0,5 с, смена сцены, проявление 0,5 с. Во время перехода касания блокируются, а повторный вызов игнорируется.
- `room_finished(n)` переходит в комнату n+1, если её путь не пуст. Иначе ничего не делает: комната остаётся на своём финальном экране.
- `go_to_menu()` — переход в меню с тем же затемнением.
- `sound_enabled` / `set_sound_enabled(on)` — звук всей игры: mute шины Master. Вызывает общее меню паузы («Sound»). Хранится до закрытия игры, на диск не пишется.
- После **каждой** смены сцены, в том числе сделанной самой комнатой, срабатывает сигнал `SceneTree.scene_changed`. GameFlow тогда:
  1. определяет номер комнаты по пути сцены (меню и заглушки → 0);
  2. ставит `Input.emulate_mouse_from_touch = false` для комнат из `ROOMS_WITH_OWN_TOUCH_BRIDGE` и `true` для всех остальных сцен;
  3. для любой комнаты (1 и выше) вызывает `ZombieAmbience.stop_ambience()` (у всех свой эмбиент). В меню звук возвращает его собственный `resume_ambience()`;
  4. если у корня сцены есть сигнал `room_completed` или `quarantine_entered`, один раз (`CONNECT_ONE_SHOT`) подключает его к `room_finished(n)`.
- `quit_game()` (кнопка QUIT в меню) и закрытие окна: GameFlow выключает `auto_accept_quit`, перед выходом останавливает все `AudioStreamPlayer`, ждёт 0,1 с и выходит. Иначе Godot при выходе пишет «2 ObjectDB instances were leaked / resources still in use: zombie_ambience.mp3». Эта ошибка была и до интеграции.

## Касания (на телефоне НЕ проверено)

- В `project.godot` настройки `input_devices` **не менялись**: по умолчанию `emulate_mouse_from_touch = true`.
- Меню, комнаты 1, 3 и 4 сделаны на обычных `Button`, а они реагируют только на мышь. Поэтому эмуляция им нужна. В новой комнате 1 ключ тоже перетаскивается эмулированной мышью.
- Комната 2 (`archive_room/scripts/archive_level.gd`, `_input`) сама превращает первое касание в мышь. С включённой эмуляцией было бы двойное нажатие, поэтому в комнате 2 GameFlow её выключает.
- **Запасной вариант**, если на телефоне в комнате 2 будут проблемы (например, переключение посреди касания): оставить эмуляцию включённой везде (убрать 2 из `ROOMS_WITH_OWN_TOUCH_BRIDGE`) и в `archive_level.gd` в начале `_input` добавить `if Input.emulate_mouse_from_touch: return`. Тогда собственное преобразование комнаты отключится, а нажатия придут через эмуляцию Godot.

## Как заменить комнату 1

Сейчас комната 1 — `first_room/` (шаг F). Чтобы заменить её снова:

1. Положить новую комнату в свою папку (например `res://new_room_1/`) и поправить в ней пути `res://`. Папку `first_room/` можно оставить.
2. Вписать путь к сцене в `GameFlow.ROOMS[1]`. **Вернуть старую комнату**: `1: "res://scenes/room_1.tscn"` и в `_on_scene_changed()` снова `current_room >= 2` (старая комната сама включает зомби-фон).
3. Если комната не 1280×720, сделать обёртку, как `first_room/scenes/FirstRoomHost.tscn`: экран 1280×720, `Stage` нужного размера по центру, а в комнате мышь считать в локальных координатах (`get_local_mouse_position()`), а не по `event.position`.
4. Конец комнаты: на корне сцены (у обёртки — на её корне) `signal room_completed` и испустить его, GameFlow подключит сам. Или вызвать `GameFlow.room_finished(1)`.
5. Кнопка «в меню» внутри комнаты: `GameFlow.go_to_menu()`.
6. Если новая комната сама превращает касания в мышь, добавить 1 в `ROOMS_WITH_OWN_TOUCH_BRIDGE`. Если у неё свой файл сохранения, добавить ветку в `reset_room_progress()`.
7. Запустить smoke-test. Панель F9 и F10 подхватят новый путь сами.

## Как добавить комнату 4

Сделано в шаге E (`lab_room/`), см. выше. Инструкция оставлена для истории.

1. Скопировать комнату в свою папку, например `res://laboratory_room/`, и поправить в ней пути `res://`.
2. Вписать путь в `GameFlow.ROOMS[4]`.
3. На корне сцены объявить `signal room_completed`. Когда появится комната 5, испустить его в конце комнаты. Пока комната 4 последняя, сделать на её финальном экране кнопку `GameFlow.go_to_menu()`.
4. Больше ничего менять не нужно:
   - «Continue» в комнате 3 сам начнёт испускать `room_completed`, потому что `ROOMS[4]` больше не пуст, и GameFlow переведёт игрока в комнату 4;
   - кнопка «Комната 4» появится на панели F9;
   - в комнате 4 зомби-фон выключится, как и во всех комнатах с номером 2 и выше.
5. При необходимости обновить `ROOMS_WITH_OWN_TOUCH_BRIDGE` и `reset_room_progress()`, затем запустить smoke-test.
