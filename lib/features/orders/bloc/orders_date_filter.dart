import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/stats_period.dart';

/// За какие даты показывать заказы.
///
/// Ровно одно из трёх, а не пара нулевых полей: «за всё время», готовый
/// период и выбранный руками диапазон — состояния взаимоисключающие, и на
/// двух необязательных полях их пришлось бы держать договорённостью, которую
/// однажды нарушит третий экран.
///
/// Список заказов по умолчанию показывает всё время — этим он и отличается
/// от экрана маршрутов, привязанного ко дню. Дата здесь именно фильтр, а не
/// обязательный параметр, поэтому [OrdersAnyDate] и стоит по умолчанию.
sealed class OrdersDateFilter extends Equatable {
  const OrdersDateFilter();

  /// Границы для запроса; `null` — параметр не отправляем вовсе.
  ///
  /// Обе даты включительно: сервер сравнивает с `routes.date`, у которой
  /// времени нет, и «по 20-е» означает весь двадцатый день.
  (DateTime?, DateTime?) get range;

  @override
  List<Object?> get props => [range];
}

/// Все заказы за всё время — состояние по умолчанию.
class OrdersAnyDate extends OrdersDateFilter {
  const OrdersAnyDate();

  @override
  (DateTime?, DateTime?) get range => (null, null);
}

/// Готовый период: сегодня, неделя, месяц.
class OrdersPeriodDate extends OrdersDateFilter {
  const OrdersPeriodDate(this.period);

  final StatsPeriod period;

  @override
  (DateTime?, DateTime?) get range {
    final (from, to) = period.range;
    return (from, to);
  }

  @override
  List<Object?> get props => [period];
}

/// Диапазон, выбранный в календаре.
class OrdersCustomDate extends OrdersDateFilter {
  const OrdersCustomDate(this.from, this.to);

  final DateTime from;
  final DateTime to;

  /// Из результата календаря, который отдаёт [DateTimeRange].
  factory OrdersCustomDate.of(DateTimeRange range) =>
      OrdersCustomDate(range.start, range.end);

  @override
  (DateTime?, DateTime?) get range => (from, to);

  /// Как подписать диапазон на чипе: две короткие даты.
  ///
  /// Год ставим только когда концы приходятся на разные годы — иначе он
  /// повторяется дважды и удлиняет и без того узкий чип настолько, что
  /// подпись уезжает за край экрана. Формат общий у телефона и десктопа:
  /// два места форматирования однажды разошлись бы.
  (String, String) get labelParts {
    final sameYear = from.year == to.year;
    final short = DateFormat('dd.MM');
    return (
      short.format(from),
      sameYear ? short.format(to) : DateFormat('dd.MM.yy').format(to),
    );
  }

  @override
  List<Object?> get props => [from, to];
}
