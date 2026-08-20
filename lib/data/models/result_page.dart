import 'package:equatable/equatable.dart';

/// Одна страница списочного ответа API.
///
/// Списки у Water CRM пагинированы: `{items, total, page, page_size, pages}`,
/// а `page_size` ограничен сотней. Раньше репозиторий обходил все страницы
/// сам и отдавал выдачу целиком — при тысяче заказчиков это десять
/// последовательных запросов на каждое открытие вкладки и на каждую паузу
/// в наборе поиска, плюс тысяча моделей в памяти.
///
/// Полная выборка никуда не делась: она по-прежнему нужна форме создания
/// маршрута (там выбирают из всех заказчиков) и экрану отчётов (должников и
/// остаток капсул сводка не отдаёт, они выводятся из справочника). Но списки,
/// которые человек листает, берут по странице.
///
/// Имя не `Page`: так называется класс навигации во Flutter.
class ResultPage<T> extends Equatable {
  const ResultPage({
    required this.items,
    required this.page,
    required this.hasMore,
    required this.total,
  });

  /// Пустая страница — когда запрашивать нечего.
  const ResultPage.empty()
      : items = const [],
        page = 1,
        hasMore = false,
        total = 0;

  final List<T> items;

  /// Номер этой страницы, считая с единицы.
  final int page;

  /// Есть ли что грузить дальше.
  final bool hasMore;

  /// Сколько записей всего — для подписи «База · 1240».
  final int total;

  @override
  List<Object?> get props => [items, page, hasMore, total];
}
