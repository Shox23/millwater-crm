import 'package:crm_millwater/data/network/api_config.dart';
import 'package:flutter_test/flutter_test.dart';

/// С 2026-10-12 API живёт под `/api/v1`, а загруженные файлы — в корне
/// сервера: `/api/v1/uploads/…` отвечает 404.
void main() {
  test('запросы к API идут под /api/v1', () {
    expect(ApiConfig.baseUrl, '${ApiConfig.serverUrl}/api/v1');
  });

  test('фото с сервера берутся от корня, а не от API', () {
    expect(
      ApiConfig.fileUrl('/uploads/payments/a.jpg'),
      '${ApiConfig.serverUrl}/uploads/payments/a.jpg',
    );
    expect(
      ApiConfig.fileUrl('uploads/payments/a.jpg'),
      '${ApiConfig.serverUrl}/uploads/payments/a.jpg',
    );
  });

  test('готовый URL фото не трогаем', () {
    const url = 'https://cdn.example.com/x/a.jpg';
    expect(ApiConfig.fileUrl(url), url);
  });
}
