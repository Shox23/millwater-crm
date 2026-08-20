import 'package:crm_millwater/data/models/customer.dart';
import 'package:crm_millwater/data/models/result_page.dart';
import 'package:crm_millwater/data/repositories/mock_crm_repository.dart';
import 'package:crm_millwater/features/customers/bloc/customers_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Списки, которые человек листает, берут по странице, а не всю базу сразу.
/// Полная выборка осталась там, где она действительно нужна, — в форме
/// маршрута и в отчётах.
void main() {
  late MockCrmRepository repo;

  /// Заводит [count] заказчиков поверх сида, чтобы страниц было больше одной.
  Future<void> seed(int count) async {
    for (var i = 0; i < count; i++) {
      await repo.addCustomer(
        name: 'Заказчик $i',
        phone: '+99890000${i.toString().padLeft(4, '0')}',
        address: 'Улица $i',
      );
    }
  }

  setUp(() => repo = MockCrmRepository());

  group('Репозиторий отдаёт страницы', () {
    test('первая страница короче полной выдачи', () async {
      await seed(20);
      final all = await repo.getCustomers();
      final first = await repo.getCustomersPage();

      expect(first.items.length, MockCrmRepository.pageSize);
      expect(first.items.length, lessThan(all.length));
      expect(first.hasMore, isTrue);
      // Подпись шапки берётся отсюда: «База · 26», а не «База · 4».
      expect(first.total, all.length);
    });

    test('страницы идут подряд и не пересекаются', () async {
      await seed(20);
      final first = await repo.getCustomersPage();
      final second = await repo.getCustomersPage(page: 2);

      final ids = {...first.items.map((c) => c.id)};
      expect(ids.intersection({...second.items.map((c) => c.id)}), isEmpty);
      expect(second.page, 2);
    });

    test('последняя страница закрывает догрузку', () async {
      final all = await repo.getCustomers();
      final pages = (all.length / MockCrmRepository.pageSize).ceil();
      final last = await repo.getCustomersPage(page: pages);

      expect(last.hasMore, isFalse);
      expect(last.items, isNotEmpty);
    });

    test('за последней страницей — пусто, а не ошибка', () async {
      final page = await repo.getCustomersPage(page: 99);
      expect(page.items, isEmpty);
      expect(page.hasMore, isFalse);
    });

    test('поиск тоже пагинирован', () async {
      await seed(20);
      final page = await repo.getCustomersPage(search: 'Заказчик');
      expect(page.items.length, MockCrmRepository.pageSize);
      expect(page.total, 20);
    });
  });

  group('Блок догружает по требованию', () {
    test('стартует с первой страницы', () async {
      await seed(20);
      final bloc = CustomersBloc(repo)..add(const CustomersRequested());
      addTearDown(bloc.close);

      await bloc.stream.firstWhere((s) => s.status == CustomersStatus.ready);
      expect(bloc.state.customers.length, MockCrmRepository.pageSize);
      expect(bloc.state.hasMore, isTrue);
      expect(bloc.state.total, greaterThan(MockCrmRepository.pageSize));
    });

    test('следующая страница дописывается в конец, а не заменяет список',
        () async {
      await seed(20);
      final bloc = CustomersBloc(repo)..add(const CustomersRequested());
      addTearDown(bloc.close);
      await bloc.stream.firstWhere((s) => s.status == CustomersStatus.ready);

      final firstPage = [...bloc.state.customers];
      bloc.add(const CustomersNextPageRequested());
      await bloc.stream.firstWhere((s) => !s.loadingMore && s.page == 2);

      expect(bloc.state.customers.length, MockCrmRepository.pageSize * 2);
      // Начало списка не сдвинулось: пользователь листает, а не перечитывает.
      expect(bloc.state.customers.take(firstPage.length), firstPage);
    });

    test('догрузка не запускается, когда грузить нечего', () async {
      final bloc = CustomersBloc(repo)
        ..add(const CustomersSearchChanged('Кафе'));
      addTearDown(bloc.close);
      // Совпадений меньше страницы — hasMore ложь, и событие должно пройти
      // вхолостую, а не сходить в сеть за пустотой.
      await bloc.stream.firstWhere(
        (s) => s.status == CustomersStatus.ready && s.query == 'Кафе',
      );

      expect(bloc.state.hasMore, isFalse);
      final before = bloc.state;
      bloc.add(const CustomersNextPageRequested());
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(bloc.state, before);
    });

    test('повторные события у края списка не множат запросы', () async {
      await seed(20);
      final bloc = CustomersBloc(repo)..add(const CustomersRequested());
      addTearDown(bloc.close);
      await bloc.stream.firstWhere((s) => s.status == CustomersStatus.ready);

      // Обработчик прокрутки шлёт событие на каждый кадр у края.
      for (var i = 0; i < 5; i++) {
        bloc.add(const CustomersNextPageRequested());
      }
      await bloc.stream.firstWhere((s) => !s.loadingMore && s.page == 2);
      await Future<void>.delayed(const Duration(milliseconds: 250));

      // Догрузилась ровно одна страница, а не пять.
      expect(bloc.state.customers.length, MockCrmRepository.pageSize * 2);
    });

    test('новый поиск начинает список заново с первой страницы', () async {
      await seed(20);
      final bloc = CustomersBloc(repo)..add(const CustomersRequested());
      addTearDown(bloc.close);
      await bloc.stream.firstWhere((s) => s.status == CustomersStatus.ready);

      bloc.add(const CustomersNextPageRequested());
      await bloc.stream.firstWhere((s) => !s.loadingMore && s.page == 2);

      // Смена поиска сперва только записывает запрос в состояние, а сам
      // запрос уходит после debounce — ждать надо перезагрузки, а не первого
      // же состояния с новым текстом.
      bloc.add(const CustomersSearchChanged('Заказчик 1'));
      await bloc.stream.firstWhere((s) => s.status == CustomersStatus.loading);
      await bloc.stream.firstWhere((s) => s.status == CustomersStatus.ready);

      expect(bloc.state.page, 1);
      expect(bloc.state.customers.length,
          lessThanOrEqualTo(MockCrmRepository.pageSize));
    });
  });

  group('Полная выборка осталась там, где она нужна', () {
    test('getCustomers по-прежнему отдаёт всё — этим живут отчёты', () async {
      // ReportsSummary.from считает должников и остаток капсул по всему
      // справочнику: сводка API этих чисел не отдаёт.
      await seed(20);
      final all = await repo.getCustomers();
      expect(all.length, greaterThan(MockCrmRepository.pageSize));
    });
  });

  group('Пустая страница', () {
    test('конструктор ResultPage.empty ничего не обещает', () {
      const page = ResultPage<Customer>.empty();
      expect(page.items, isEmpty);
      expect(page.hasMore, isFalse);
      expect(page.total, 0);
      expect(page.page, 1);
    });
  });
}
