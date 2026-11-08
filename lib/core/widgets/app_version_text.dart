import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';

import '../../app/theme/app_tokens.dart';
import '../../app/theme/app_typography.dart';
import '../app_version.dart';

/// Подпись «Версия 1.1.0+2» — по ней видно, какая сборка у человека.
///
/// Стоит на экране входа (чтобы версию можно было назвать, даже не войдя)
/// и внизу профиля и настроек. Если версию прочитать не удалось, подписи нет.
class AppVersionText extends StatelessWidget {
  const AppVersionText({super.key});

  @override
  Widget build(BuildContext context) {
    final label = AppVersion.label;
    if (label == null) return const SizedBox.shrink();
    return Text(
      context.l10n.appVersion(label),
      textAlign: TextAlign.center,
      style: AppTypography.secondary.copyWith(color: context.tokens.text3),
    );
  }
}
