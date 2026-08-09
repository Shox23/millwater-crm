import 'package:equatable/equatable.dart';


/// Точка маршрута: текстовый адрес и, если они известны, координаты.
///
/// Своей карты в приложении нет — точка нужна только для того, чтобы
/// превратиться в один элемент параметра `rtext` Яндекс.Карт.
class RoutePoint extends Equatable {
  const RoutePoint({
    required this.address,
    this.latitude,
    this.longitude,
  });

  final String address;
  final double? latitude;
  final double? longitude;

  /// Обе координаты заданы — точку можно отдать нативному приложению.
  bool get hasCoordinates => latitude != null && longitude != null;

  /// Значение точки для `rtext`: `lat,lon` при наличии координат, иначе адрес.
  ///
  /// Координаты точнее текста и не требуют геокодинга, поэтому при их наличии
  /// адрес не используется. Из текста убираются `~` (разделитель точек внутри
  /// `rtext`) и повторяющиеся пробелы. Экранирование — забота [Uri],
  /// здесь строка остаётся сырой.
  String toRtextValue() {
    if (hasCoordinates) return '$latitude,$longitude';
    return address.replaceAll('~', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  @override
  List<Object?> get props => [address, latitude, longitude];
}

/// Тип маршрута — значение параметра `rtt` Яндекс.Карт.
enum MapRouteMode {
  auto('auto'),
  transit('mt'),
  pedestrian('pd'),
  bicycle('bc');

  const MapRouteMode(this.code);

  /// Значение параметра `rtt` в ссылке.
  final String code;
}

/// Маршрут: упорядоченный список точек и тип передвижения.
class RouteData extends Equatable {
  const RouteData({required this.points, this.mode = MapRouteMode.auto});

  /// Точки в том порядке, в котором их надо объехать: первая — старт,
  /// последняя — финиш, остальные Яндекс.Карты считают промежуточными.
  ///
  /// Одна точка — тоже маршрут: она становится финишем, а старт Яндекс.Карты
  /// берут от текущего места пользователя. См. [rtext].
  final List<RoutePoint> points;
  final MapRouteMode mode;

  /// Причина, по которой маршрут строить нельзя, или null.
  ///
  /// Возвращается код, а не текст: подпись зависит от языка интерфейса,
  /// а модель маршрута про язык не знает.
  RouteIssue? validate() {
    if (points.isEmpty) return const RouteHasNoPoints();
    for (var i = 0; i < points.length; i++) {
      // Точка без координат опознаётся только по адресу, поэтому пустой
      // адрес здесь — нечего передавать в `rtext`.
      if (points[i].toRtextValue().isEmpty) {
        return RoutePointWithoutAddress(i + 1);
      }
    }
    return null;
  }

  /// Все точки заданы координатами — маршрут можно строить без геокодинга.
  bool get hasOnlyCoordinates => points.every((p) => p.hasCoordinates);

  /// В маршруте одна точка — её некуда вести, и она становится финишем.
  bool get isSingleStop => points.length == 1;

  /// Значение параметра `rtext`: точки через `~`, порядок сохраняется.
  ///
  /// У маршрута из одной точки первый элемент пустой: `~финиш`. Так точка
  /// попадает в поле «куда», а «откуда» Яндекс.Карты подставляют сами —
  /// текущее место пользователя. Отдай мы точку без `~`, она встала бы
  /// первой, то есть началом маршрута, и водителя повезло бы не туда.
  String get rtext {
    final values = points.map((p) => p.toRtextValue());
    return isSingleStop ? '~${values.first}' : values.join('~');
  }

  @override
  List<Object?> get props => [points, mode];
}

/// Почему маршрут нельзя построить или открыть.
///
/// Текст подбирает интерфейс — см. `BuildRouteSection`.
sealed class RouteIssue {
  const RouteIssue();
}

/// Точек нет вовсе.
class RouteHasNoPoints extends RouteIssue {
  const RouteHasNoPoints();
}

/// У точки [number] (нумерация с единицы) пустой адрес и нет координат.
class RoutePointWithoutAddress extends RouteIssue {
  const RoutePointWithoutAddress(this.number);

  final int number;
}

/// Ссылку не принял ни один обработчик: ни приложение карт, ни браузер.
class RouteOpenFailed extends RouteIssue {
  const RouteOpenFailed();
}
