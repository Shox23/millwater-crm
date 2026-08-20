import 'package:dio/dio.dart';

import '../../core/utils/money_parser.dart';
import '../models/enums.dart';
import '../models/json.dart';
import '../models/route_models.dart';
import '../network/api_envelope.dart';
import 'driver_repository.dart';

/// Реализация водительской части поверх Water CRM API (Dio).
///
/// Отличия от админских эндпоинтов: списки приходят голым массивом (без
/// пагинации), в маршрутах нет полей водителя (он и так «свой»), а завершение
/// доставки принимает `multipart/form-data`, а не JSON.
class ApiDriverRepository implements DriverRepository {
  ApiDriverRepository(this._dio);

  final Dio _dio;

  @override
  Future<List<RouteListItem>> getMyRoutes() async {
    final res = await _dio.get('/driver/routes');
    // Маршрут, который не разобрался, пропускается — остальные водитель
    // должен увидеть. См. `parseList`.
    return parseList(unwrapData(res.data), RouteListItem.fromJson);
  }

  @override
  Future<RouteDetail?> getMyRoute(String id) async {
    final res = await _dio.get('/driver/routes/$id');
    return RouteDetail.fromJson(asMap(res.data));
  }

  @override
  Future<void> updateDeliveryStatus({
    required String stopId,
    required DeliveryStatus status,
  }) async {
    await _dio.patch(
      '/driver/routes/customers/$stopId/status',
      data: {'status': status.toJson()},
    );
  }

  @override
  Future<void> completeDelivery({
    required String stopId,
    required int capsules,
    required int amount,
    required int bottleBalance,
    required PaymentMethod method,
    String? photoPath,
    String? idempotencyKey,
    double? latitude,
    double? longitude,
  }) async {
    final form = FormData.fromMap({
      'delivered_bottles': capsules,
      'payment_amount': MoneyParser.toApi(amount),
      'payment_method': method.toJson(),
      // Без этого поля сервер отвечает 500, хотя в схеме оно необязательное.
      'bottle_balance': bottleBalance,
      if (photoPath != null)
        'payment_photo': await MultipartFile.fromFile(photoPath),
      // Только парой: одна координата без второй точку не задаёт, а поле
      // с половиной данных сервер будет вынужден отбрасывать сам.
      if (latitude != null && longitude != null) ...{
        'latitude': latitude,
        'longitude': longitude,
      },
    });

    await _dio.post(
      '/driver/routes/customers/$stopId/complete',
      data: form,
      options: Options(
        contentType: 'multipart/form-data',
        headers: {'Idempotency-Key': ?idempotencyKey},
      ),
    );
  }
}
