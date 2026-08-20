# CRM Millwater

Приложение (Flutter) для компании по доставке питьевой воды в капсулах.
Две роли и две оболочки в одной сборке:

- **администратор** — заказчики, водители, маршруты, прайс, отчёты;
  на экране шире 1200 px открывается десктопная компоновка;
- **водитель** — свои маршруты, точки, завершение доставки с оплатой и фото.

Интерфейс на русском и узбекском, переключается в настройках.
Бэкенд — Water CRM API (`https://crm.millwater.uz`), схема — OpenAPI 3.1.

## Запуск

```bash
flutter pub get
flutter run                  # на подключённом устройстве
flutter test                 # тесты
flutter analyze              # статический анализ
```

## Параметры сборки

Живут в `dart_defines.json` — он в `.gitignore`, потому что у боевого стенда,
тестового и CI значения разные. Шаблон со всеми ключами:
`dart_defines.example.json`, скопируйте его и заполните.

| Ключ | Зачем | По умолчанию |
|---|---|---|
| `API_BASE_URL` | адрес бэкенда | `https://crm.millwater.uz` |
| `CAPSULE_PRICE` | цена капсулы для расчёта у водителя | `20000` |
| `SENTRY_DSN` | приём отчётов об ошибках; пусто — выключено | пусто |

Файл подставляется одним флагом:

```bash
flutter run  --dart-define-from-file=dart_defines.json
flutter test --dart-define-from-file=dart_defines.json
```

Без этого флага приложение работает, но отчёты об ошибках никуда не уходят:
`SENTRY_DSN` пуст, и Sentry не поднимается вовсе.

## Стек

- **flutter_bloc** — события и состояния, репозитории за интерфейсами
- **dio** — HTTP, обновление токена в интерсепторе, SSE-поток уведомлений
- **flutter_secure_storage** — токены сессии (Keychain / EncryptedSharedPreferences)
- **sentry_flutter** — отчёты об ошибках, с отсечкой сетевого шума
- **intl** + `gen_l10n` — форматирование и локализация (ru/uz)
- Шрифты **Inter** и **Onest** лежат в сборке (`assets/fonts`), не качаются

## Архитектура

```
lib/
  app/            корневой виджет, тема и токены, локаль, пороги ширины
  core/
    forms/        SubmitState — общее «идёт отправка» и текст ошибки
    observability/ перехват ошибок, фильтр шума для трекера
    utils/        деньги, телефоны, идемпотентность, ограничитель частоты
    widgets/      переиспользуемые виджеты (баррел: widgets.dart)
  data/
    models/       модели API (fromJson/toJson)
    network/      Dio, токены, SSE, разбор ошибок валидации
    repositories/ CrmRepository / DriverRepository / NotificationsRepository
                  + реализации поверх API и in-memory для тестов
  features/
    auth/ home/ routes/ drivers/ customers/ reports/ prices/ settings/
    driver/       водительские экраны
    desktop/      админская оболочка для широких экранов
```

Каждая фича: `bloc/` (Bloc + Event + State) и `presentation/`.
BLoC зависит от интерфейса репозитория, а не от реализации.

**Доступ по ролям держится деревом виджетов**, а не дисциплиной вызовов:
`app.dart` кладёт в дерево только те репозитории, которые роли положены.
У водителя `CrmRepository` физически отсутствует.

## Что стоит знать про API

Расхождения со схемой и решения по ним описаны в комментариях рядом с кодом.
Коротко:

- списки пагинированы, `page_size` ограничен сотней;
- денежные значения приходят строками (`"20000.00"`) — разбирает `MoneyParser`;
- единственная описанная ошибка — `HTTPValidationError`; её текст собирается
  заново по `type` и `loc`, английский `msg` наружу не идёт;
- должников и остаток капсул сводка не отдаёт — они выводятся из справочника
  заказчиков (см. `ReportsSummary.from`);
- цены водителю API не отдаёт, поэтому она берётся из сборки — временно,
  см. `ProductConfig.capsulePrice`.

## Шрифты

Пересобираются из вариативных Inter и Onest: ось веса закрепляется в
статические начертания, набор символов режется до латиницы и кириллицы.

```bash
python3 -m venv .fontenv
.fontenv/bin/pip install fonttools brotli
.fontenv/bin/python tool/build_fonts.py
```

Лицензии (SIL OFL 1.1) лежат рядом со шрифтами и должны там остаться.

## Релиз

```bash
# Android — в Play уходит AAB, Play нарежет его по архитектурам сам
flutter build appbundle --release \
  --dart-define-from-file=dart_defines.json \
  --obfuscate --split-debug-info=build/symbols

# iOS
flutter build ipa --release \
  --dart-define-from-file=dart_defines.json \
  --obfuscate --split-debug-info=build/symbols
```

Перед отправкой:

1. **Поставить релизную сборку на устройство и пройти вход и завершение
   доставки.** В release включён R8, а его ошибки проявляются только в
   рантайме — ни тесты, ни отладочная сборка их не покажут.
2. Ключ подписи Android положить в `android/key.properties`
   (шаблон — `key.properties.example`, файл в `.gitignore`).
   Без него сборка подписывается debug-ключом, и Play её не примет.
3. При включённой обфускации залить символы из `build/symbols` в Sentry,
   иначе стек в отчёте будет нечитаемым.
4. Разрешения, которые надо объявить в Play Data Safety и App Privacy:
   интернет, геолокация (построение маршрута от места водителя), камера и
   галерея (фото оплаты). Данные заказчиков в отчёты об ошибках не уходят —
   `sendDefaultPii` выключен, скриншотов нет.
