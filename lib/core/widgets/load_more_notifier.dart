import 'package:flutter/material.dart';

/// Просит догрузить следующую страницу, когда прокрутка подошла к концу.
///
/// Оборачивает прокручиваемый список и слушает его уведомления, а не держит
/// свой `ScrollController`: контроллер пришлось бы протаскивать через все
/// слои виджетов и не забыть освободить в каждом.
///
/// Само по себе оно не считает, можно ли грузить, — это знает блок. Событие
/// приходит на каждый кадр у края, поэтому обработчик обязан быть дешёвым и
/// молча выходить, когда грузить нечего.
class LoadMoreNotifier extends StatelessWidget {
  const LoadMoreNotifier({
    super.key,
    required this.onLoadMore,
    required this.child,
    this.threshold = 400,
  });

  /// Вызывается, когда до конца списка осталось меньше [threshold].
  final VoidCallback onLoadMore;

  final Widget child;

  /// За сколько пикселей до конца начинать догрузку.
  ///
  /// Не ноль: страница идёт по сети, и если ждать самого края, пользователь
  /// упрётся в пустоту и увидит спиннер. Четырёх сотен хватает примерно на
  /// три карточки — этого времени достаточно, чтобы ответ успел прийти.
  final double threshold;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        // Горизонтальные полосы (ленты дат, фильтры) до догрузки не касаются.
        if (notification.metrics.axis != Axis.vertical) return false;

        final metrics = notification.metrics;
        // `maxScrollExtent` равен нулю, пока список короче экрана: догружать
        // там нечего, а деление на пустоту дало бы срабатывание на первом же
        // кадре.
        if (metrics.maxScrollExtent <= 0) return false;

        if (metrics.maxScrollExtent - metrics.pixels <= threshold) {
          onLoadMore();
        }
        // Уведомление не поглощаем: его ждут и другие — RefreshIndicator,
        // полоса прокрутки.
        return false;
      },
      child: child,
    );
  }
}

/// Строка «идёт догрузка» в конце списка.
///
/// Высота зарезервирована всегда, даже когда загрузки нет: появись она
/// внезапно — список дёрнулся бы ровно в тот момент, когда пользователь его
/// листает.
class LoadMoreFooter extends StatelessWidget {
  const LoadMoreFooter({super.key, required this.loading, this.height = 44});

  final bool loading;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: loading
          ? const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : null,
    );
  }
}
