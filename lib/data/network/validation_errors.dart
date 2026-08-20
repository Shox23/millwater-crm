/// Перевод отлупа валидации FastAPI на язык интерфейса.
///
/// Единственная описанная в схеме ошибка — `HTTPValidationError` со списком
/// `ValidationError { loc, msg, type, input, ctx }`. Поле `msg` там всегда
/// английское («Input should be a valid integer»), и раньше оно доходило до
/// водителя как есть.
///
/// Показывать его нельзя, а выбрасывать жалко: рядом с ним лежат `type` —
/// машинный код причины, и `loc` — путь до поля. По ним текст собирается
/// заново, уже на нужном языке. Никаких договорённостей с бэкендом для этого
/// не нужно: коды Pydantic стабильны и в схеме уже есть.
library;

import '../../l10n/l10n.dart';

/// Собирает сообщение из тела `HTTPValidationError`.
///
/// `null` — разобрать не удалось: вызывающий покажет свой запасной текст.
String? validationErrorMessage(AppLocalizations l10n, Object? detail) {
  if (detail is! List) return null;

  final messages = <String>[];
  for (final item in detail) {
    if (item is! Map) continue;
    final message = _messageFor(l10n, item);
    // Одна и та же причина в двух полях сразу — обычное дело у пустой формы;
    // повторять её дважды незачем.
    if (message != null && !messages.contains(message)) messages.add(message);
  }

  if (messages.isEmpty) return null;
  // Показывать только первую из трёх причин — значит гонять пользователя по
  // кругу. Больше трёх не показываем: это уже не подсказка, а простыня.
  return messages.take(3).join('. ');
}

/// Текст одной ошибки. Поле неизвестно или причина незнакома — общий текст.
String? _messageFor(AppLocalizations l10n, Map<dynamic, dynamic> error) {
  final field = _fieldName(l10n, error['loc']);
  final type = error['type'];
  if (type is! String) return null;
  if (field == null) return l10n.validationGeneric;

  // Коды Pydantic v2. Хвост после точки отбрасываем: `string_too_short` и
  // `string_too_short.something` — одна и та же причина для пользователя.
  return switch (type.split('.').first) {
    'missing' || 'missing_argument' => l10n.validationRequired(field),
    'string_too_short' || 'too_short' => l10n.validationTooShort(field),
    'string_too_long' || 'too_long' => l10n.validationTooLong(field),
    'int_parsing' ||
    'int_type' ||
    'float_parsing' ||
    'float_type' ||
    'decimal_parsing' ||
    'decimal_type' =>
      l10n.validationNotNumber(field),
    'greater_than' ||
    'greater_than_equal' ||
    'less_than' ||
    'less_than_equal' =>
      l10n.validationOutOfRange(field),
    'string_pattern_mismatch' ||
    'uuid_parsing' ||
    'date_parsing' ||
    'date_from_datetime_parsing' ||
    'datetime_parsing' ||
    'enum' ||
    'literal_error' =>
      l10n.validationBadFormat(field),
    // Незнакомый код — общий текст. Английское `msg` наружу не идёт: оно
    // уходит в лог и в отчёт об ошибке, где ему и место.
    _ => l10n.validationGeneric,
  };
}

/// Имя поля из `loc` на языке интерфейса.
///
/// FastAPI кладёт туда путь: `["body", "full_name"]`, `["query", "page"]`,
/// `["body", "customer_ids", 0]`. Нужен последний строковый элемент —
/// индексы элементов списка человеку ничего не говорят.
String? _fieldName(AppLocalizations l10n, Object? loc) {
  if (loc is! List) return null;

  for (final part in loc.reversed) {
    if (part is! String) continue;
    // «body», «query», «path» — это не поля, а откуда пришло значение.
    if (part == 'body' || part == 'query' || part == 'path') continue;
    return _labels(l10n)[part];
  }
  return null;
}

/// Поля запросов Water CRM. Имена нейтральные, не привязанные к экрану:
/// одно и то же `full_name` на форме водителя подписано «Имя водителя», а на
/// форме заказчика — «Название / имя», и подставлять сюда любую из этих
/// подписей значило бы врать на другом экране.
Map<String, String> _labels(AppLocalizations l10n) => {
      'full_name': l10n.apiFieldFullName,
      'phone': l10n.apiFieldPhone,
      'address': l10n.apiFieldAddress,
      'comment': l10n.apiFieldComment,
      'password': l10n.apiFieldPassword,
      'old_password': l10n.apiFieldOldPassword,
      'new_password': l10n.apiFieldNewPassword,
      'date': l10n.apiFieldDate,
      'date_from': l10n.apiFieldDate,
      'date_to': l10n.apiFieldDate,
      'driver_id': l10n.apiFieldDriver,
      'customer_ids': l10n.apiFieldCustomers,
      'delivered_bottles': l10n.apiFieldCapsules,
      'payment_amount': l10n.apiFieldAmount,
      'payment_method': l10n.apiFieldPaymentMethod,
      'bottle_balance': l10n.apiFieldBalance,
      'water_price': l10n.apiFieldPrice,
      'deposit_price': l10n.apiFieldDeposit,
    };
