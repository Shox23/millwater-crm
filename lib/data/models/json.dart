/// Чтение полей JSON, терпимое к неожиданному типу.
///
/// Раньше модели читали ответ жёсткими приведениями: `json['id'] as String`,
/// `DateTime.parse(json['created_at'] as String)`. Пока сервер отвечает ровно
/// по схеме, это работает. Но схема у Water CRM уже расходилась с боевыми
/// ответами, а цена ошибки несоразмерна: одно поле не того типа роняло разбор
/// **всей страницы**, и вместо девяноста девяти нормальных заказчиков
/// пользователь видел общую ошибку загрузки.
///
/// Здесь другой договор: поле, которое можно понять, — понимается; поле,
/// которое нельзя, — заменяется значением по умолчанию. Исключение бросает
/// только [requireString]: без идентификатора запись бесполезна, её честнее
/// пропустить целиком (см. `parseList`).
library;

/// Строка; `null` — поля нет или оно не строка.
///
/// Число превращается в строку намеренно: идентификаторы у части API
/// приходят то строкой, то числом, и терять запись из-за этого незачем.
String? optionalString(Object? value) {
  if (value == null) return null;
  if (value is String) return value.isEmpty ? null : value;
  if (value is num || value is bool) return value.toString();
  return null;
}

/// Строка или [fallback].
String stringOr(Object? value, [String fallback = '']) =>
    optionalString(value) ?? fallback;

/// Обязательное поле: без него запись не имеет смысла.
///
/// Бросает [FormatException], которую ловит `parseList` и пропускает одну
/// запись вместо того, чтобы уронить всю страницу.
String requireString(Object? value, String field) {
  final result = optionalString(value);
  if (result == null) {
    throw FormatException('Поле "$field" отсутствует или не строка: $value');
  }
  return result;
}

/// Целое; строка с числом тоже подходит.
int? optionalInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) {
    // Бесконечность и NaN в int не переводятся — `toInt()` бросает.
    if (!value.isFinite) return null;
    return value.round();
  }
  if (value is String) {
    final parsed = num.tryParse(value.trim());
    if (parsed == null || !parsed.isFinite) return null;
    return parsed.round();
  }
  return null;
}

/// Целое или [fallback].
int intOr(Object? value, [int fallback = 0]) => optionalInt(value) ?? fallback;

/// Логическое; строки «true»/«false» и числа 0/1 тоже понимаются.
bool boolOr(Object? value, [bool fallback = false]) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final lower = value.trim().toLowerCase();
    if (lower == 'true' || lower == '1') return true;
    if (lower == 'false' || lower == '0') return false;
  }
  return fallback;
}

/// Дробное; `null` — прочитать не вышло.
double? optionalDouble(Object? value) {
  if (value is num) return value.isFinite ? value.toDouble() : null;
  if (value is String) {
    final parsed = double.tryParse(value.trim());
    return (parsed != null && parsed.isFinite) ? parsed : null;
  }
  return null;
}

/// Дата; `null` — поля нет или оно не разбирается.
///
/// `DateTime.parse` бросает на любой мусор, а дата в ответе — не тот повод,
/// чтобы терять запись: у заказчика без `last_order_date` просто нет
/// последнего заказа.
DateTime? optionalDate(Object? value) {
  final text = optionalString(value);
  if (text == null) return null;
  return DateTime.tryParse(text);
}

/// Дата или [fallback].
///
/// Для полей вроде `created_at`, которые модель требует. Подставлять «сейчас»
/// нельзя — запись выглядела бы только что созданной; [fallback] задаёт
/// вызывающий, и обычно это [epoch].
DateTime dateOr(Object? value, DateTime fallback) =>
    optionalDate(value) ?? fallback;

/// Заведомо «пустая» дата: не сегодня и не в будущем, сортировка её узнает.
final DateTime epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

/// Список словарей из поля [field]; всё, что не словарь, отбрасывается.
List<Map<String, dynamic>> objectList(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is Map) item.cast<String, dynamic>(),
  ];
}

/// Разбирает список записей, пропуская непригодные.
///
/// Ради этого всё и затевалось: битая запись стоит одной строки в списке,
/// а не всего экрана. [onSkipped] сообщает, сколько записей потерялось, —
/// молча терять данные нельзя, это надо видеть в отчётах.
List<T> parseList<T>(
  Object? value,
  T Function(Map<String, dynamic>) fromJson, {
  void Function(int skipped)? onSkipped,
}) {
  final items = <T>[];
  var skipped = 0;

  for (final json in objectList(value)) {
    try {
      items.add(fromJson(json));
    } catch (_) {
      skipped++;
    }
  }

  if (skipped > 0) onSkipped?.call(skipped);
  return items;
}
