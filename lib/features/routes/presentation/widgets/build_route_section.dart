import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/location/device_location.dart';
import '../../../../core/maps/map_route.dart';
import '../../../../core/maps/yandex_route_launcher.dart';
import '../../../../core/widgets/action_feedback.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/section_block.dart';
import '../../../../data/models/route_models.dart';

/// Причина, по которой маршрут не строится, словами.
///
/// Коды приходят из `RouteData.validate` и `YandexRouteLauncher`: они про
/// язык интерфейса не знают, поэтому текст собирается здесь.
String _issueText(BuildContext context, RouteIssue issue) => switch (issue) {
      RouteHasNoPoints() => context.l10n.mapNeedOnePoint,
      RoutePointWithoutAddress(:final number) =>
        context.l10n.mapPointWithoutAddress(number),
      RouteOpenFailed() => context.l10n.mapOpenFailed,
    };

/// Блок «Построить маршрут»: запуск Яндекс.Карт.
///
/// Только для карточки водителя. Карты внутри приложения нет — точки уходят
/// в Яндекс.Карты ссылкой, см. [YandexRouteLauncher]. Тип передвижения не
/// спрашиваем: доставку возят машиной, поэтому маршрут всегда автомобильный.
///
/// Стартом всегда становится текущее место водителя, снятое по нажатию
/// кнопки: он не стоит у первого заказчика, и первый отрезок пути — «где я
/// сейчас → первая точка» — иначе выпал бы из маршрута. По этой же причине
/// блока нет в админской карточке: админ по маршруту не едет.
/// См. [_routeWithStart].
class BuildRouteSection extends StatefulWidget {
  const BuildRouteSection({
    super.key,
    required this.stops,
    this.launcher = const YandexRouteLauncher(),
    this.location = const DeviceLocationService(),
  });

  final List<RouteStop> stops;

  /// Подменяется в тестах, чтобы не дёргать реальный `url_launcher`.
  final YandexRouteLauncher launcher;

  /// Откуда берётся старт маршрута из одной точки. Подменяется в тестах.
  final DeviceLocationService location;

  @override
  State<BuildRouteSection> createState() => _BuildRouteSectionState();
}

class _BuildRouteSectionState extends State<BuildRouteSection> {
  bool _opening = false;

  /// Координаты у точки есть только там, где водитель уже был и зафиксировал
  /// их при завершении доставки. Пока их нет — уходит текстовый адрес, его
  /// геокодит сама веб-версия Яндекс.Карт.
  RouteData get _route => RouteData(
        points: [
          for (final stop in widget.stops)
            RoutePoint(
              address: stop.customerAddress,
              latitude: stop.customerLatitude,
              longitude: stop.customerLongitude,
            ),
        ],
        mode: MapRouteMode.auto,
      );

  /// Ставит первой точкой то место, где водитель стоит сейчас.
  ///
  /// Замер делается по нажатию, а не при открытии карточки: разрешение на
  /// геолокацию спрашивается только у того, кто действительно строит маршрут.
  ///
  /// Не получилось (отказ в доступе, выключенный GPS, таймаут) — маршрут
  /// уходит по одним остановкам: у нескольких точек стартом станет первая
  /// из них, у единственной старт останется пустым и «откуда» Яндекс.Карты
  /// спросят сами. Хуже, чем с замером, но лучше, чем не открыть маршрут.
  Future<RouteData> _routeWithStart() async {
    final route = _route;
    final fix = await widget.location.currentFix();
    if (!fix.isSuccess) return route;

    return RouteData(
      points: [
        RoutePoint(
          address: '',
          latitude: fix.latitude,
          longitude: fix.longitude,
        ),
        ...route.points,
      ],
      mode: route.mode,
    );
  }

  Future<void> _openRoute() async {
    setState(() => _opening = true);
    final result = await widget.launcher.openRoute(await _routeWithStart());
    // `State.mounted` — тот же признак, что и `context.mounted`, но именно его
    // требует use_build_context_synchronously для контекста State.
    if (!mounted) return;
    setState(() => _opening = false);
    if (!result.isSuccess) {
      showAppSnackBar(context, _issueText(context, result.error!),
          isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // Та же проверка, что и внутри сервиса: кнопка неактивна ровно тогда,
    // когда открытие всё равно вернуло бы ошибку.
    final blockedReason = _route.validate();

    return SectionBlock(
      label: context.l10n.mapSectionLabel,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpacing.md,
          children: [
            if (blockedReason != null)
              Text(_issueText(context, blockedReason),
                  style: AppTypography.secondary.copyWith(color: t.text2))
            // Стартом станет замер GPS — проговариваем, иначе запрос
            // разрешения при нажатии выглядит внезапным.
            else
              Text(context.l10n.mapFromCurrentPlace,
                  style: AppTypography.secondary.copyWith(color: t.text2)),
            if (_opening)
              const SizedBox(
                height: 52,
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                ),
              )
            else
              AppButton(
                label: context.l10n.mapBuildRoute,
                icon: Icons.map_outlined,
                enabled: blockedReason == null,
                onPressed: blockedReason == null ? _openRoute : null,
              ),
          ],
        ),
      ),
    );
  }
}
