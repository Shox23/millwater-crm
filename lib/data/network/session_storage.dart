import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Хранилище сессии между запусками приложения.
///
/// Вынесено за интерфейс, потому что `flutter_secure_storage` ходит в
/// платформенный канал — в тестах вместо него подставляется [InMemorySessionStorage].
abstract class SessionStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> deleteAll();
}

/// Keychain на iOS, EncryptedSharedPreferences на Android.
class SecureSessionStorage implements SessionStorage {
  const SecureSessionStorage([
    this._storage = const FlutterSecureStorage(
      // first_unlock: водитель открывает смену после разблокировки телефона,
      // фоновый refresh до первого анлока нам не нужен.
      iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    ),
  ]);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> deleteAll() => _storage.deleteAll();
}

/// Реализация для тестов и демо-режима.
class InMemorySessionStorage implements SessionStorage {
  InMemorySessionStorage([Map<String, String>? seed])
      : _values = {...?seed};

  final Map<String, String> _values;

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> deleteAll() async => _values.clear();
}
