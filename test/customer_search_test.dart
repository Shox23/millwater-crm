import 'package:crm_millwater/data/models/customer.dart';
import 'package:crm_millwater/data/models/result_page.dart';
import 'package:crm_millwater/data/repositories/mock_crm_repository.dart';
import 'package:crm_millwater/features/customers/bloc/customers_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Поиск заказчика — одним полем и силами сервера.
///
/// Раньше режимов было два: имя с телефоном искал сервер, а адрес клиент
/// досчитывал по полной выборке, потому что такого параметра в API не было.
/// Теперь серверный `search` идёт по имени, телефону и адресу сразу
/// (ILIKE по трём полям), и выкачивать базу ради адреса больше незачем.
/// Этот файл сторожит именно это: полная выборка на поиск не тянется.
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
  final searches = <String?>[];

  @override
  Future<List<Customer>> getCustomers({
    String? search,
    bool? hasDebt,
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
    bool? isActive,
  }) async {
    pageFetches++;
    searches.add(search);
    // Сервер ищет по трём полям — повторяем это здесь, иначе тест проверял бы
    // не поиск, а то, что запрос вообще ушёл.
    final query = (search ?? '').trim().toLowerCase();
    final found = query.isEmpty
        ? pool
        : pool
            .where((c) => [c.name, c.phone, c.address]
                .any((f) => f.toLowerCase().contains(query)))
            .toList();
    return ResultPage(
      items: found,
      page: page,
      hasMore: false,
      total: found.length,
    );
  }
}

void main() {
  final pool = [
    _customer('1', 'Кафе «Лола»', 'Чиланзар, 12 квартал, дом 4'),
    _customer('2', 'Салон «Гулнора»', 'Чиланзар, 9 квартал, дом 30'),
    _customer('3', 'Офис «Барака»', 'Мирабад, улица Нукус, дом 12'),
  ];

  group('Поиск заказчиков', () {
    late _CountingRepository repo;
    late CustomersBloc bloc;

    setUp(() {
      repo = _CountingRepository(pool);
      bloc = CustomersBloc(repo);
      addTearDown(bloc.close);
    });

    /// Ждёт полный цикл загрузки, подписываясь ДО события.
    Future<void> during(void Function() act) async {
      final done = bloc.stream
          .skipWhile((s) => s.status != CustomersStatus.loading)
          .firstWhere((s) => s.status == CustomersStatus.ready);
      act();
      await done;
    }

    Future<void> search(String query) =>
        during(() => bloc.add(CustomersSearchChanged(query)));

    test('запрос уходит на сервер, а базу целиком никто не тянет', () async {
      await search('чиланзар');

      expect(repo.searches.last, 'чиланзар');
      expect(repo.fullFetches, 0);
      expect(repo.pageFetches, greaterThan(0));
    });

    test('адрес находится тем же полем, что и имя', () async {
      await search('мирабад');
      expect(bloc.state.customers.single.id, '3');

      await search('гулнора');
      expect(bloc.state.customers.single.id, '2');
    });

    test('пустой запрос возвращает обычный постраничный список', () async {
      await search('   ');

      expect(repo.fullFetches, 0);
      expect(bloc.state.customers, hasLength(pool.length));
    });
  });
}
