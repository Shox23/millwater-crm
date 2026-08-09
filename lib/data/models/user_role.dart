import '../../l10n/l10n.dart';
/// Роль учётной записи. Значения совпадают с API (`UserRole`).
enum UserRole {
  admin('admin'),
  driver('driver');

  const UserRole(this.wire);

  /// Значение, которым роль называется в API.
  final String wire;

  /// Подпись роли на языке интерфейса.
  String label(AppLocalizations l10n) => switch (this) {
        UserRole.admin => l10n.roleAdmin,
        UserRole.driver => l10n.roleDriver,
      };

  /// Неизвестную роль трактуем как отсутствие роли: пускать такого
  /// пользователя в админскую часть нельзя.
  static UserRole? tryFromJson(String? value) {
    if (value == null) return null;
    for (final role in UserRole.values) {
      if (role.wire == value) return role;
    }
    return null;
  }

  String toJson() => wire;
}
