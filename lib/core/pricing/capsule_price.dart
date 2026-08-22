import 'package:dio/dio.dart';

import '../../data/models/price_settings.dart';
import '../../data/network/api_envelope.dart';
import '../product_config.dart';

/// Откуда берётся цена капсулы для расчётов в интерфейсе.
///
/// Отдельный источник, а не метод репозитория: цена нужна обеим ролям, а
/// `CrmRepository` водителю не положен — доступ по ролям держится тем, что
/// админского репозитория в его дереве нет вовсе (см. `app.dart`). Узкий
/// интерфейс на одно чтение этого не нарушает.
abstract class CapsulePrice {
  /// Текущая цена капсулы, сум.
  ///
  /// Не бросает никогда. Экран завершения доставки открывают в подъезде и во
  /// дворе, и упавший запрос за прайсом не должен мешать провести доставку —
  /// в худшем случае расчёт идёт по значению сборки.
  Future<int> value();
}

/// Цена из сборки — [ProductConfig.capsulePrice].
///
/// Значение по умолчанию там, где источник не передали: тесты и экраны,
/// которым сеть не положена.
class BuildCapsulePrice implements CapsulePrice {
  const BuildCapsulePrice();

  @override
  Future<int> value() async => ProductConfig.capsulePrice;
}

/// Цена из прайса сервера с откатом на значение сборки.
///
/// `GET /admin/prices/current` — единственное место, где цена вообще есть.
/// Админу он отвечает прайсом, водителю — 403: весь `/admin/*` под его
/// токеном закрыт. Отказ здесь не сбой, а ожидаемый ответ, поэтому он гасится
/// молча и расчёт продолжается по [ProductConfig.capsulePrice], как и раньше.
///
/// Запрос делается всё равно и под водительским токеном тоже. Сборки живут в
/// сторах месяцами, а цена в них зашита на день выпуска; в день, когда бэкенд
/// отдаст цену водителю — своим эндпоинтом или полем в точке маршрута, — уже
/// установленные приложения начнут считать по живому прайсу сами, без
/// обновления. Цена ошибки при этом нулевая: 403 не показывается водителю и
/// не уходит в трекер (`isReportableError` отсекает 4xx).
class ApiCapsulePrice implements CapsulePrice {
  ApiCapsulePrice(this._dio, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final Dio _dio;

  /// Часы. Подменяются в тестах: иначе срок годности кэша нечем проверить.
  final DateTime Function() _now;

  /// Сколько живёт удачно полученная цена.
  ///
  /// Водитель не перезапускает приложение сутками, а прайс меняют приказом
  /// среди дня. Без срока годности смена цены дошла бы до него только
  /// назавтра — то самое расхождение, ради которого всё и затевалось.
  static const Duration ttl = Duration(minutes: 30);

  int? _cached;
  DateTime? _cachedAt;

  /// Сервер ответил, что цена не для нас (403 у водителя). Спрашивать снова
  /// до перезапуска бессмысленно — роль в пределах сессии не меняется.
  bool _denied = false;

  /// Один запрос на всех: точки маршрута открывают подряд, и параллельные
  /// вызовы не должны множить обращения к серверу.
  Future<int>? _inFlight;

  @override
  Future<int> value() {
    if (_denied) return Future.value(ProductConfig.capsulePrice);

    final cached = _cached;
    if (cached != null && !_isExpired) return Future.value(cached);

    return _inFlight ??= _load().whenComplete(() => _inFlight = null);
  }

  bool get _isExpired {
    final at = _cachedAt;
    return at == null || _now().difference(at) >= ttl;
  }

  Future<int> _load() async {
    try {
      final res = await _dio.get('/admin/prices/current');
      final price = PriceSettings.fromJson(asMap(res.data)).capsulePrice;

      // Ноль и отрицательное — не цена, а неразобранный ответ: `MoneyParser`
      // отдаёт ноль на всём, чего не понял. Считать по нему значило бы тихо
      // выставить заказчику ноль сум.
      if (price <= 0) return ProductConfig.capsulePrice;

      _cached = price;
      _cachedAt = _now();
      return price;
    } on DioException catch (e) {
      // Отказ по существу — запоминаем. Сервер не сломался и не пропал, он
      // ответил, что этот эндпоинт не для нас.
      if (_isDenial(e)) _denied = true;
      // Обрыв связи и 5xx не запоминаем: следующая точка маршрута попробует
      // снова, и цена подхватится, как только связь вернётся.
      return ProductConfig.capsulePrice;
    } catch (_) {
      // Ответ не разобрался — цена всё равно нужна прямо сейчас.
      return ProductConfig.capsulePrice;
    }
  }

  /// Сервер ответил отказом, а не сломался и не пропал.
  static bool _isDenial(DioException e) =>
      e.type == DioExceptionType.badResponse &&
      (e.response?.statusCode ?? 500) < 500;
}
