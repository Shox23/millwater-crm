import 'package:crm_millwater/data/models/customer.dart';
import 'package:crm_millwater/data/models/enums.dart';
import 'package:crm_millwater/data/models/result_page.dart';
import 'package:crm_millwater/data/repositories/mock_crm_repository.dart';
import 'package:crm_millwater/features/customers/bloc/customers_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Что именно ушло на сервер за одну загрузку списка.
typedef _Call = ({int page, bool? hasDebt, bool? hasCooler, bool? isActive});

/// Запоминает параметры отбора и всегда обещает следующую страницу — иначе
/// догрузку не проверить, сид кончается на второй.
class _RecordingRepository extends MockCrmRepository {
  final calls = <_Call>[];

  @override
  Future<ResultPage<Customer>> getCustomersPage({
    int page = 1,
    String? search,
    bool? hasDebt,
    bool? hasCooler,
    bool? isActive,
  }) async {
    calls.add((
      page: page,
      hasDebt: hasDebt,
      hasCooler: hasCooler,
      isActive: isActive,
    ));
    final items = await getCustomers(
      search: search,
      hasDebt: hasDebt,
      hasCooler: hasCooler,
      isActive: isActive,
    );
    return ResultPage(items: items, page: page, hasMore: true, total: 99);
  }
}

void main() {
  group('Чипы отбора', () {
    test('«Все» не отправляет ни одного фильтра', () {
      expect(CustomerFilter.all.hasDebt, isNull);
      expect(CustomerFilter.all.hasCooler, isNull);
      expect(CustomerFilter.all.isActive, isNull);
    });

    test('каждый чип задаёт ровно один вопрос', () {
      expect(CustomerFilter.withDebt.hasDebt, isTrue);
      expect(CustomerFilter.withDebt.hasCooler, isNull);

      expect(CustomerFilter.withCooler.hasCooler, isTrue);
      expect(CustomerFilter.withCooler.hasDebt, isNull);

      // Единственный, кто спрашивает про `false`: пустое значение сервер
      // понял бы как «активные».
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
      bloc.add(const CustomersFilterChanged(CustomerFilter.withCooler));
      await loaded();

      bloc.add(const CustomersNextPageRequested());
      await bloc.stream.firstWhere((s) => !s.loadingMore && s.page == 2);

      expect(repo.calls.last.page, 2);
      expect(repo.calls.last.hasCooler, isTrue);
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
    test('«С кулером» и «Неактивные» отсекают по своим полям', () async {
      final repo = MockCrmRepository();
      final all = await repo.getCustomers();

      final withCooler = await repo.getCustomers(hasCooler: true);
      final withoutCooler = await repo.getCustomers(hasCooler: false);
      expect(withCooler.every((c) => c.hasCooler), isTrue);
      expect(withoutCooler.every((c) => !c.hasCooler), isTrue);
      // Проверяем правило, а не содержимое сида: два взаимодополняющих
      // отбора обязаны вместе давать всю базу и ничего не терять.
      expect(withCooler.length + withoutCooler.length, all.length);

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
