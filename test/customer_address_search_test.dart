import 'package:crm_millwater/core/utils/text_match.dart';
import 'package:crm_millwater/data/models/customer.dart';
import 'package:crm_millwater/data/models/enums.dart';
import 'package:crm_millwater/data/models/result_page.dart';
import 'package:crm_millwater/data/repositories/mock_crm_repository.dart';
import 'package:crm_millwater/features/customers/bloc/customers_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

Customer _customer(String id, String name, String address) => Customer(
      id: id,
      name: name,
      phone: '+99890000000$id',
      address: address,
      createdAt: DateTime(2026),
    );

/// Считает, сколько раз спросили полную выборку и сколько — страницу.
class _CountingRepository extends MockCrmRepository {
  _CountingRepository(this.pool);

  final List<Customer> pool;
  int fullFetches = 0;
  int pageFetches = 0;

  @override
  Future<List<Customer>> getCustomers({
    String? search,
    bool? hasDebt,
    bool? hasCooler,
    bool? isActive,
  }) async {
    fullFetches++;
    return pool;
  }

  @override
  Future<ResultPage<Customer>> getCustomersPage({
    int page = 1,
    String? search,
    bool? hasDebt,
    bool? hasCooler,
    bool? isActive,
  }) async {
    pageFetches++;
    return ResultPage(
      items: pool.take(2).toList(),
      page: page,
      hasMore: true,
      total: pool.length,
    );
  }
}

void main() {
  final pool = [
    _customer('1', 'Кафе «Лола»', 'Чиланзар, 12 квартал, дом 4, подъезд 2'),
    _customer('2', 'Салон «Гулнора»', 'Чиланзар, 9 квартал, дом 30'),
    _customer('3', 'Офис «Барака»', 'Мирабад, улица Нукус, дом 12'),
    _customer('4', 'Дом Азиза', 'Юнусабад, 19 квартал, дом 4'),
  ];

  group('Совпадение по словам', () {
    test('слова ищутся в любом порядке', () {
      const address = 'Чиланзар, 12 квартал, дом 4, подъезд 2';

      expect(matchesAllWords(address, 'чиланзар дом 4'), isTrue);
      // Целиком такой подстроки в адресе нет — обычного contains тут мало.
      expect(matchesAllWords(address, 'дом 4 чиланзар'), isTrue);
    });

    test('регистр не важен, лишние пробелы тоже', () {
      expect(matchesAllWords('Мирабад, улица Нукус', '  МИРАБАД   нукус '),
          isTrue);
    });

    test('хотя бы одно непопавшее слово отсекает адрес', () {
      expect(matchesAllWords('Чиланзар, 12 квартал', 'чиланзар 19'), isFalse);
    });

    test('пустой запрос совпадает со всем: фильтровать нечем', () {
      expect(matchesAllWords('что угодно', '   '), isTrue);
    });
  });

  group('Поиск по адресу', () {
    late _CountingRepository repo;
    late CustomersBloc bloc;

    setUp(() {
      repo = _CountingRepository(pool);
      bloc = CustomersBloc(repo);
      addTearDown(bloc.close);
    });

    /// Ждёт полный цикл загрузки, подписываясь ДО события.
    ///
    /// Двумя `firstWhere` подряд это не ловится: когда выборка уже в памяти,
    /// `loading` и `ready` уходят в одном обороте, и второе ожидание успевает
    /// подписаться только после того, как `ready` уже прошёл.
    Future<void> during(void Function() act) async {
      final done = bloc.stream
          .skipWhile((s) => s.status != CustomersStatus.loading)
          .firstWhere((s) => s.status == CustomersStatus.ready);
      act();
      await done;
    }

    Future<void> mode(CustomerSearchMode value) =>
        during(() => bloc.add(CustomersSearchModeChanged(value)));

    Future<void> searchAddress(String query) =>
        during(() => bloc.add(CustomersSearchChanged(query)));

    test('идёт по полной выборке, а не по загруженной странице', () async {
      await mode(CustomerSearchMode.address);

      await searchAddress('чиланзар');

      // Страница отдаёт только первых двух; «Гулнора» нашлась бы и так, а вот
      // отсутствие «Барака» и «Азиза» доказывает, что отбор всё-таки был.
      expect(bloc.state.customers.map((c) => c.id), ['1', '2']);
      expect(bloc.state.total, 2);
    });

    test('находит по словам вразнобой', () async {
      await mode(CustomerSearchMode.address);

      await searchAddress('дом 4 чиланзар');

      expect(bloc.state.customers.single.id, '1');
    });

    test('догружать нечего: список уже полон', () async {
      await mode(CustomerSearchMode.address);
      await searchAddress('квартал');

      expect(bloc.state.hasMore, isFalse);

      final before = repo.fullFetches;
      bloc.add(const CustomersNextPageRequested());
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(repo.fullFetches, before);
    });

    test('набор текста не тянет выборку заново на каждую букву', () async {
      await mode(CustomerSearchMode.address);

      await searchAddress('чил');
      expect(repo.fullFetches, 1);

      await searchAddress('чиланзар');
      await searchAddress('чиланзар 12');

      // Обход всех страниц на каждое нажатие — это десятки запросов подряд.
      expect(repo.fullFetches, 1);
    });

    test('смена чипа выборку сбрасывает: она уже про других', () async {
      await mode(CustomerSearchMode.address);
      await searchAddress('квартал');
      expect(repo.fullFetches, 1);

      await during(
        () => bloc.add(const CustomersFilterChanged(CustomerFilter.withDebt)),
      );

      expect(repo.fullFetches, 2);
    });

    test('пустой запрос возвращает обычный постраничный список', () async {
      await mode(CustomerSearchMode.address);
      final pagesBefore = repo.pageFetches;

      await searchAddress('   ');

      // Тянуть всю базу ради «показать всех» незачем — это работа страниц.
      expect(repo.fullFetches, 0);
      expect(repo.pageFetches, pagesBefore + 1);
      expect(bloc.state.hasMore, isTrue);
    });

    test('в обычном режиме адрес не ищется здесь', () async {
      await searchAddress('чиланзар');

      // Поиск по имени и телефону остаётся за сервером.
      expect(repo.fullFetches, 0);
      expect(repo.pageFetches, greaterThan(0));
    });
  });
}
