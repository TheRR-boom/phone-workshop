# Ремонт Плюс

Симулятор мастерской по ремонту и продаже телефонов. Godot 4.x, GDScript,
2D, портрет, только тач.

![статус](https://img.shields.io/badge/MVP-играбельный%20вертикальный%20срез-38e8a0)

## Что уже работает

- Очередь клиентов на день, 5 типов характеров, жалобы и симптомы.
- Диагноз из 5 неисправностей: 2 ошибки — клиент уходит.
- Выбор запчасти: оригинал / копия / б/у (цена, надёжность, гарантия).
- Торг ползунком: клиент соглашается или уходит, репутация меняется.
- Ремонт: винты по порядку → замена модуля (drag-and-drop), чистка залития
  (тапы по окислам) или пайка разъёма (удержание контактов) → проверка.
  Шанс успеха зависит от детали, модели и повреждений.
- Деньги, репутация, опыт и уровни, аренда, закрытие дня.
- Магазин запчастей по классам устройств + 4 улучшения.
- Витрина на 3 телефона: битый лот → восстановление → продажа.
- Автосохранение в `user://`, пауза и сохранение при сворачивании.

## Запуск

```bash
# Godot 4.4+ (проверено на 4.7.2)
godot --path . --editor      # открыть в редакторе
godot --path .               # запустить игру
```

Headless-тесты (логика, полный цикл заказа, сохранение, вёрстка на трёх
соотношениях сторон):

```bash
godot --headless --path . res://tests/smoke.tscn
```

Скриншоты (нужен реальный GL-контекст, например Xvfb + Mesa):

```bash
godot --path . res://tests/shot.tscn
```

## Сборка APK

APK собирается в GitHub Actions (`.github/workflows/android.yml`) на каждый
push в `main`: Godot + шаблоны экспорта + Android SDK, прогон headless-тестов,
`--export-debug`, подпись отладочным ключом. Готовый файл — в артефактах
запуска и в релизе `apk-build-N`.

Локально:

```bash
# 1. шаблоны экспорта Godot 4.7.2 → ~/.local/share/godot/export_templates/4.7.2.stable
# 2. Android SDK + JDK 17, пути в Editor Settings → Export → Android
keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android \
  -keystore debug.keystore -storepass android \
  -dname "CN=Android Debug,O=Android,C=US" -validity 9999 -deststoretype pkcs12
godot --headless --path . --import
godot --headless --path . --export-debug "Android" build/repair-plus.apk
```

`export_presets.cfg` уже в репозитории: пакет `com.repairplus.game`,
arm64-v8a, immersive mode, без интернета.

## Структура

```
autoload/
  db.gd        контент → типизированные Resource (3 телефона, 5 поломок, 5 клиентов)
  game.gd      состояние: деньги, репутация, склад, заказы, витрина, сейв
  econ.gd      формулы цен, шансов, отзывов (чистые функции)
  router.gd    переходы между экранами + тосты
data/
  catalog.gd   таблицы контента и цен
  *.gd         PhoneModel, Fault, PartQuality, ClientType, Order
ui/
  ui.gd        палитра, шрифты, кнопки, карточки, бейджи, пилюли
  topbar.gd    день/деньги/репутация
  navbar.gd    нижняя навигация
scenes/        workshop, order, repair, inventory, shop, showcase
tests/         smoke.gd (107 проверок), shot.gd (скриншоты)
docs/GDD.md    дизайн-документ и экономика
```

## Мобильные правила, которые соблюдены

- Только тач: тапы, drag-and-drop детали, ползунок цены. Клавиатуры нет.
- Все кнопки ≥ 88 px при ширине 720 (44 dp), нижняя навигация — 112 px.
- Портрет, `canvas_items` + `expand`: на 16:9, 19.5:9 и 20:9 интерфейс
  растягивается по высоте, а не обрезается.
- Экраны прокручиваются, если контента больше высоты; шапка и навигация
  закреплены.
- Нет частиц, шейдеров и 3D; UI — Control-ноды, один шрифт.
- Пауза и сохранение при `NOTIFICATION_APPLICATION_PAUSED`.
- Офлайн: ни одного сетевого запроса.

## Лицензия

Код — MIT. Шрифт Noto Sans — SIL Open Font License (`assets/fonts/OFL.txt`).