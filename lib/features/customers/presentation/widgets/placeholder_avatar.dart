import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_tokens.dart';

/// Аватар-плейсхолдер заказчика — скруглённый квадрат «водного» акцента.
class PlaceholderAvatar extends StatelessWidget {
  const PlaceholderAvatar({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: t.softOf(t.aqua),
        borderRadius: BorderRadius.circular(AppRadius.avatar),
      ),
      child: Icon(
        Icons.storefront_outlined,
        size: size * 0.44,
        color: t.aqua,
      ),
    );
  }
}
