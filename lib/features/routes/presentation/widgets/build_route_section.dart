import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/location/device_location.dart';
import '../../../../core/maps/geo_link.dart';
import '../../../../core/maps/map_route.dart';
import '../../../../core/maps/route_plan.dart';
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
///
/// Что попадёт в маршрут и с какими координатами, решает [RoutePlanner]:
/// закрытые точки отбрасываются, остальные идут по `sequence`, а адрес по
/// возможности превращается в координаты. Это не украшение — нативное
/// приложение Яндекс.Карт строит маршрут только по координатам, а текстовую
/// точку выбрасывает молча.
class BuildRouteSection extends StatefulWidget {
  const BuildRouteSection({
    super.key,
    required this.stops,
    this.launcher = const YandexRouteLauncher(),
    this.location = const DeviceLocationService(),
    this.planner,
  });

  final List<RouteStop> stops;

  /// Подменяется в тестах, чтобы не дёргать реальный `url_launcher`.
  final YandexRouteLauncher launcher;

  /// Откуда берётся старт маршрута из одной точки. Подменяется в тестах.
  final DeviceLocationService location;

  /// Сборщик маршрута. `null` — обычный, с разбором ссылок и геокодером по
  /// настройкам сборки.
  final RoutePlanner? planner;

  @override
  State<BuildRouteSection> createState() => _BuildRouteSectionState();
}

class _BuildRouteSectionState extends State<BuildRouteSection> {
  bool _opening = false;

  /// Остановки последнего построения, для которых не нашлось координат.
  ///
  /// Держим до следующей попытки: это единственное место, где водитель
  /// узнаёт, из-за какого адреса маршрут открылся не в приложении.
  List<RouteStop> _unplaced = const [];

  late final RoutePlanner _planner = widget.planner ?? RoutePlanner();

  /// Точки, которые ещё предстоит объехать, — по ним и проверка, и маршрут.
  List<RouteStop> get _pending => RoutePlanner.pendingStops(widget.stops);

  /// Маршрут по одним адресам: нужен только для проверки до нажатия —
  /// координаты добываются уже при построении и требуют сети.
  RouteData get _draft => RouteData(
        points: [
          for (final stop in _pending)
            RoutePoint.fromCustomer(
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
  Future<GeoPoint?> _start() async {
    final fix = await widget.location.currentFix();
    if (!fix.isSuccess) return null;
    return GeoPoint(
      latitude: fix.latitude!,
      longitude: fix.longitude!,
      source: GeoLinkSource.plain,
    );
  }

  Future<void> _openRoute() async {
    setState(() => _opening = true);

    final plan = await _planner.plan(widget.stops, start: await _start());
    if (!mounted) return;
    setState(() => _unplaced = plan.unplaced);

    if (plan.isEmpty) {
      setState(() => _opening = false);
      showAppSnackBar(context, context.l10n.mapNeedOnePoint, isError: true);
      return;
    }

    final result = await widget.launcher.openRoute(plan.route);
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
    // Та же проверка, что и внутри сервиса, но по точкам, которые ещё
    // предстоит объехать: кнопка неактивна ровно тогда, когда открытие всё
    // равно вернуло бы ошибку.
    final blockedReason =
        widget.stops.isNotEmpty && _pending.isEmpty ? null : _draft.validate();
    final allDone = widget.stops.isNotEmpty && _pending.isEmpty;

    return SectionBlock(
      label: context.l10n.mapSectionLabel,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpacing.md,
          children: [
            if (allDone)
              Text(context.l10n.mapAllStopsDone,
                  style: AppTypography.secondary.copyWith(color: t.text2))
            else if (blockedReason != null)
              Text(_issueText(context, blockedReason),
                  style: AppTypography.secondary.copyWith(color: t.text2))
            // Стартом станет замер GPS — проговариваем, иначе запрос
            // разрешения при нажатии выглядит внезапным.
            else
              Text(context.l10n.mapFromCurrentPlace,
                  style: AppTypography.secondary.copyWith(color: t.text2)),
            // Какие адреса не дали координат — водителю это важнее всего:
            // из-за них маршрут открывается не в приложении, а в вебе.
            if (_unplaced.isNotEmpty) _UnplacedNotice(stops: _unplaced),
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
                enabled: blockedReason == null && !allDone,
                onPressed:
                    (blockedReason == null && !allDone) ? _openRoute : null,
              ),
          ],
        ),
      ),
    );
  }
}

/// Список адресов, которым не нашлось точки на карте.
///
/// Отдельным блоком, а не строкой: имена нужны целиком — по ним менеджер
/// правит карточку заказчика, и только после этого маршрут начнёт
/// открываться в приложении.
class _UnplacedNotice extends StatelessWidget {
  const _UnplacedNotice({required this.stops});

  final List<RouteStop> stops;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: t.warnBg,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.xs,
        children: [
          Text(
            context.l10n.mapStopsWithoutPoint(stops.length),
            style: AppTypography.secondary.copyWith(color: t.text),
          ),
          for (final stop in stops)
            Text('• ${stop.customerName} — ${stop.customerAddress}',
                style: AppTypography.secondary.copyWith(color: t.text2),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          Text(context.l10n.mapAddMapLinkHint,
              style: AppTypography.secondary.copyWith(color: t.text3)),
        ],
      ),
    );
  }
}
