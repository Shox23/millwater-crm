import 'package:crm_millwater/data/models/customer.dart';
import 'package:crm_millwater/data/models/enums.dart';
import 'package:crm_millwater/data/models/result_page.dart';
import 'package:crm_millwater/data/repositories/mock_crm_repository.dart';
import 'package:crm_millwater/features/customers/bloc/customers_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Что именно ушло на сервер за одну загрузку списка.
typedef _Call = ({int page, bool? hasDebt, bool? isActive});

/// Запоминает параметры отбора и всегда обещает следующую страницу — иначе
/// догрузку не проверить, сид кончается на второй.
class _RecordingRepository extends MockCrmRepository {
  final calls = <_Call>[];

  @override
  Future<ResultPage<Customer>> getCustomersPage({
    int page = 1,
    String? search,
    bool? hasDebt,
    bool? isActive,
  }) async {
    calls.add((page: page, hasDebt: hasDebt, isActive: isActive));
    final items = await getCustomers(
      search: search,
      hasDebt: hasDebt,
      isActive: isActive,
    );
    return ResultPage(items: items, page: page, hasMore: true, total: 99);
  }
}

void main() {
  group('Чипы отбора', () {
    test('«Все» — это все активные', () {
      expect(CustomerFilter.all.hasDebt, isNull);
      // Отключённых в общем списке нет: страница про тех, с кем работают.
      expect(CustomerFilter.all.isActive, isTrue);
      expect(CustomerFilter.all.filtersCoolerLocally, isFalse);
    });

    test('каждый чип задаёт ровно один вопрос', () {
      expect(CustomerFilter.withDebt.hasDebt, isTrue);
      expect(CustomerFilter.withDebt.filtersCoolerLocally, isFalse);

      // Кулеры сервер больше не отбирает — этот чип считается на клиенте, и
      // серверных параметров он не задаёт вовсе.
      expect(CustomerFilter.withCooler.filtersCoolerLocally, isTrue);
      expect(CustomerFilter.withCooler.hasDebt, isNull);
      expect(CustomerFilter.withCooler.isActive, isTrue);
      expect(CustomerFilter.withDebt.isActive, isTrue);

      // Единственный, кто спрашивает про `false`, — и единственный путь к
      // отключённому заказчику, чтобы включить его обратно.
      expect(CustomerFilter.inactive.isActive, isFalse);
      expect(CustomerFilter.inactive.hasDebt, isNull);
    });
  });

  group('Блок заказчиков', () {
    late _RecordingRepository repo;
    late CustomersBloc bloc;

    setUp(() {
      repo = _RecordingRepository();
      bloc = CustomersBloc(repo);
      addTearDown(bloc.close);
    });

    /// Ждёт следующую полную загрузку: смена чипа сперва меняет состояние и
    /// лишь потом уходит в запрос.
    Future<void> loaded() async {
      await bloc.stream.firstWhere((s) => s.status == CustomersStatus.loading);
      await bloc.stream.firstWhere((s) => s.status == CustomersStatus.ready);
    }

    test('отбор уходит на сервер, а не режет загруженное', () async {
      bloc.add(const CustomersRequested());
      await loaded();
      expect(repo.calls.last.hasDebt, isNull);
      // Без единого чипа список всё равно просит только активных.
      expect(repo.calls.last.isActive, isTrue);

      bloc.add(const CustomersFilterChanged(CustomerFilter.withDebt));
      await loaded();

      expect(repo.calls.last.hasDebt, isTrue);
      expect(bloc.state.filter, CustomerFilter.withDebt);
    });

    test('смена чипа начинает список с первой страницы', () async {
      bloc.add(const CustomersRequested());
      await loaded();
      bloc.add(const CustomersNextPageRequested());
      await bloc.stream.firstWhere((s) => !s.loadingMore && s.page == 2);
      expect(repo.calls.last.page, 2);

      bloc.add(const CustomersFilterChanged(CustomerFilter.withCooler));
      await loaded();

      // Иначе первая страница отбора осталась бы за кадром.
      expect(repo.calls.last.page, 1);
      expect(bloc.state.page, 1);
    });

    test('догрузка не теряет выбранный чип', () async {
      bloc.add(const CustomersFilterChanged(CustomerFilter.withDebt));
      await loaded();

      bloc.add(const CustomersNextPageRequested());
      await bloc.stream.firstWhere((s) => !s.loadingMore && s.page == 2);

      expect(repo.calls.last.page, 2);
      expect(repo.calls.last.hasDebt, isTrue);
    });

    test('«С кулером» отбирает на клиенте: в запрос не уходит ничего',
        () async {
      bloc.add(const CustomersFilterChanged(CustomerFilter.withCooler));
      await loaded();

      // Параметра `has_cooler` у сервера больше нет, а неизвестный
      // query-параметр он молча игнорирует — отправлять его значило бы
      // показывать всех подряд под видом отбора. Активность — как у всех.
      expect(repo.calls.last.hasDebt, isNull);
      expect(repo.calls.last.isActive, isTrue);
      expect(bloc.state.customers.every((c) => c.hasCooler), isTrue);
      // Счётчик в шапке считает найденное, а не всю базу: серверный `total`
      // про кулеры ничего не знает.
      expect(bloc.state.total, bloc.state.customers.length);
    });

    test('повторное нажатие того же чипа запрос не шлёт', () async {
      bloc.add(const CustomersRequested());
      await loaded();
      final before = repo.calls.length;

      bloc.add(const CustomersFilterChanged(CustomerFilter.all));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(repo.calls.length, before);
    });
  });

  group('Мок отбирает так же, как сервер', () {
    test('отключённый заказчик виден только под «Неактивные»', () async {
      final repo = _RecordingRepository();
      final off = repo.store.customers.first.copyWith(isActive: false);
      repo.store.customers[0] = off;
      final bloc = CustomersBloc(repo);
      addTearDown(bloc.close);

      Future<void> loaded() async {
        await bloc.stream
            .firstWhere((s) => s.status == CustomersStatus.loading);
        await bloc.stream.firstWhere((s) => s.status == CustomersStatus.ready);
      }

      bloc.add(const CustomersRequested());
      await loaded();
      expect(bloc.state.customers.map((c) => c.id), isNot(contains(off.id)));

      bloc.add(const CustomersFilterChanged(CustomerFilter.inactive));
      await loaded();
      expect(bloc.state.customers.map((c) => c.id), [off.id]);
    });

    test('«Неактивные» отсекают по своему полю', () async {
      final repo = MockCrmRepository();
      final all = await repo.getCustomers();

      final active = await repo.getCustomers(isActive: true);
      final inactive = await repo.getCustomers(isActive: false);
      expect(active.every((c) => c.isActive), isTrue);
      expect(inactive.every((c) => !c.isActive), isTrue);
      expect(active.length + inactive.length, all.length);
    });
  });

  group('Пустой результат', () {
    test('под чипом подсказка про фильтр, а не про поиск', () {
      const state = CustomersState(
        status: CustomersStatus.ready,
        filter: CustomerFilter.withCooler,
      );

      expect(state.isEmptyFilter, isTrue);
      expect(state.isEmptySearch, isFalse);
    });

    test('пустая база под «Все» — это не пустой фильтр', () {
      const state = CustomersState(status: CustomersStatus.ready);

      expect(state.isEmptyFilter, isFalse);
      expect(state.isEmptySearch, isFalse);
    });
  });
}
