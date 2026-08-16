import 'dart:convert';
import 'dart:typed_data';

import 'package:crm_millwater/data/repositories/api_crm_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Отдаёт заказчиков постранично и запоминает, о какой странице просили.
class _PagedAdapter implements HttpClientAdapter {
  _PagedAdapter({required this.total});

  final int total;

  /// Потолок сервера: `page_size` в схеме ограничен сотней.
  static const int pageSize = 100;

  /// Значения `page` в том порядке, в каком их запрашивали.
  final List<int> requestedPages = [];

  int get _pages => (total / pageSize).ceil();

  @override
  void close({bool force = false}) {}

  Map<String, dynamic> _customer(int i) => {
        'id': 'c$i',
        'full_name': 'Заказчик $i',
        'phone': '+99890000$i',
        'address': 'Адрес $i',
        'comment': null,
        'bottle_balance': 1,
        'prepayment': '0.00',
        'debt': i.isEven ? '0.00' : '10000.00',
        'last_order_date': null,
        'is_active': true,
        'created_at': '2026-01-01T00:00:00Z',
      };

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final page = int.parse('${options.queryParameters['page']}');
    requestedPages.add(page);

    final from = (page - 1) * pageSize;
    final to = (from + pageSize).clamp(0, total);
    final items = [for (var i = from; i < to; i++) _customer(i)];

    return ResponseBody.fromString(
      jsonEncode({
        'items': items,
        'total': total,
        'page': page,
        'page_size': pageSize,
        'pages': _pages,
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  ApiCrmRepository repoWith(_PagedAdapter adapter) =>
      ApiCrmRepository(Dio()..httpClientAdapter = adapter);

  group('Списки забираются целиком', () {
    test('одна страница — один запрос', () async {
      final adapter = _PagedAdapter(total: 42);

      final customers = await repoWith(adapter).getCustomers();

      expect(customers.length, 42);
      expect(adapter.requestedPages, [1]);
    });

    test('раньше на 101-м заказчике список молча обрывался', () async {
      final adapter = _PagedAdapter(total: 250);

      final customers = await repoWith(adapter).getCustomers();

      // Три страницы по сотне — и ни одного потерянного заказчика.
      expect(customers.length, 250);
      expect(adapter.requestedPages, [1, 2, 3]);
      expect(customers.last.name, 'Заказчик 249');
    });

    test('ровно на границе страницы лишнего запроса нет', () async {
      final adapter = _PagedAdapter(total: 200);

      final customers = await repoWith(adapter).getCustomers();

      expect(customers.length, 200);
      expect(adapter.requestedPages, [1, 2]);
    });

    test('пустой ответ не уводит в бесконечный цикл', () async {
      final adapter = _PagedAdapter(total: 0);

      final customers = await repoWith(adapter).getCustomers();

      expect(customers, isEmpty);
      expect(adapter.requestedPages, [1]);
    });
  });
}
