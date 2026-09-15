import 'package:flutter/material.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../data/models/customer.dart';

/// Фон карточки или строки заказчика по давности последнего заказа.
///
/// Одно правило на мобильный список и десктопную таблицу: жёлтый — не
/// заказывал больше месяца, светло-красный — больше двух. `null` — обычный
/// фон: заказчик активен, подсвечивать нечего.
Color? activityBackground(AppTokens t, CustomerActivity activity) =>
    switch (activity) {
      CustomerActivity.recent => null,
      CustomerActivity.stale => t.staleBg,
      CustomerActivity.dormant => t.dormantBg,
    };
