#!/usr/bin/env bash
#
# Запуск и сборка с параметрами из dart_defines.json.
#
# Флаг --dart-define-from-file приходится помнить в каждой команде, а забытый
# он ничего не ломает громко: приложение просто собирается без ключей — без
# Sentry, с чужим адресом API и с запасным геокодером вместо Яндекса. Заметно
# это становится уже у пользователя. Поэтому единая точка входа.
#
#   tool/build.sh run                 # на подключённом устройстве
#   tool/build.sh run -d chrome       # лишние аргументы уходят дальше
#   tool/build.sh test
#   tool/build.sh apk | aab | ipa | windows
#   tool/build.sh flutter <что угодно>   # произвольная команда с ключами
#
# Файл параметров можно подменить: DART_DEFINES_FILE=dart_defines.stage.json

set -euo pipefail

cd "$(dirname "$0")/.."

DEFINES_FILE="${DART_DEFINES_FILE:-dart_defines.json}"

if [[ ! -f "$DEFINES_FILE" ]]; then
  echo "Нет файла параметров: $DEFINES_FILE" >&2
  echo "Скопируйте шаблон и заполните:" >&2
  echo "  cp dart_defines.example.json $DEFINES_FILE" >&2
  exit 1
fi

FLAG="--dart-define-from-file=$DEFINES_FILE"
COMMAND="${1:-run}"
shift || true

# Команду разбираем до всего остального: опечатка не должна тонуть в выводе.
case "$COMMAND" in
  run)     set -- run "$FLAG" "$@" ;;
  # Тестам параметры сборки не передаются намеренно: они не должны зависеть
  # от того, что лежит в dart_defines.json на конкретной машине. И один тест
  # прямо сторожит сборку без DSN — с ключами он падает
  # (`observability_test.dart`).
  test)    set -- test "$@" ;;
  apk)     set -- build apk --release "$FLAG" "$@" ;;
  aab)     set -- build appbundle --release "$FLAG" "$@" ;;
  ipa)     set -- build ipa --release "$FLAG" "$@" ;;
  windows) set -- build windows --release "$FLAG" "$@" ;;
  flutter) set -- "$@" "$FLAG" ;;
  *)
    echo "Неизвестная команда: $COMMAND" >&2
    echo "Доступно: run, test, apk, aab, ipa, windows, flutter <…>" >&2
    exit 1
    ;;
esac

# Показываем, с чем собираем: пустой ключ — самая частая причина «на моей
# машине работало». Значения не печатаем, только «есть» или «пусто»: в логах
# сборки и на демонстрации экрана им не место.
python3 - "$DEFINES_FILE" <<'PY'
import json, sys

path = sys.argv[1]
try:
    with open(path, encoding='utf-8') as f:
        data = json.load(f)
except Exception as error:                      # noqa: BLE001
    sys.exit(f'{path} не читается как JSON: {error}')

# Ключи, без которых сборка работает, но иначе, чем ожидают.
known = {
    'API_BASE_URL': 'адрес бэкенда',
    'SENTRY_DSN': 'отчёты об ошибках',
    'CAPSULE_PRICE': 'запасная цена капсулы',
    'YANDEX_GEOCODER_KEY': 'геокодер Яндекса (иначе OpenStreetMap)',
}

print(f'Параметры сборки из {path}:')
for key, what in known.items():
    value = str(data.get(key, '')).strip()
    if key == 'API_BASE_URL' or key == 'CAPSULE_PRICE':
        mark = value if value else 'ПУСТО'
    else:
        mark = 'есть' if value else 'пусто'
    print(f'  {key:<20} {mark:<28} — {what}')
PY

echo
echo "flutter $*"
echo
exec flutter "$@"
