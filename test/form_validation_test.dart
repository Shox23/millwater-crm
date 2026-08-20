import 'package:crm_millwater/app/theme/app_theme.dart';
import 'package:crm_millwater/core/widgets/app_button.dart';
import 'package:crm_millwater/data/models/customer.dart';
import 'package:crm_millwater/data/models/driver.dart';
import 'package:crm_millwater/data/repositories/crm_repository.dart';
import 'package:crm_millwater/data/repositories/mock_crm_repository.dart';
import 'package:crm_millwater/features/customers/presentation/customer_form_page.dart';
import 'package:crm_millwater/features/drivers/presentation/driver_form_page.dart';
import 'package:crm_millwater/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MockCrmRepository repo;

  setUp(() => repo = MockCrmRepository());

  void useLargeSurface(WidgetTester tester) {
    // В тестах вместо Inter подставляется шрифт тестового рендерера с более
    // широкими глифами — на узком экране подписи кнопок в него не влезают.
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  /// Прокачивает кадры вместо `pumpAndSettle`: автофокус держит мигающий
  /// курсор, и «до полной остановки» экран формы не доходит никогда.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Открывает форму отдельным маршрутом — как в приложении, чтобы
  /// сохранение и отмена могли закрыть экран.
  Future<void> pumpForm(WidgetTester tester, Widget page) async {
    useLargeSurface(tester);
    await tester.pumpWidget(
      RepositoryProvider<CrmRepository>.value(
        value: repo,
        child: MaterialApp(
            // Строки интерфейса берутся из локали: тесты идут на русской.
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocales.supported,
            locale: AppLocales.ru,
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context)
                      .push(MaterialPageRoute<bool>(builder: (_) => page)),
                  child: const Text('открыть'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('открыть'));
    await settle(tester);
  }

  /// Поле по подписи над ним: ближайший общий Column внутри LabeledTextField.
  Finder inputFor(String label) => find.descendant(
        of: find.ancestor(of: find.text(label), matching: find.byType(Column)).first,
        matching: find.byType(TextField),
      );

  String textOf(WidgetTester tester, String label) =>
      tester.widget<TextField>(inputFor(label)).controller!.text;

  /// Активна ли кнопка отправки: форма блокирует её, пока есть ошибки.
  bool submitEnabled(WidgetTester tester, String label) =>
      tester.widget<AppButton>(find.widgetWithText(AppButton, label)).enabled;

  /// Уводит фокус с текущего поля — по этому событию появляется первая
  /// подсветка ошибки. В приложении так же: пользователь ушёл из поля.
  ///
  /// Два кадра: первый доносит смену фокуса до `FocusManager`, второй
  /// перерисовывает поле с ошибкой.
  Future<void> leaveField(WidgetTester tester) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.pump();
  }

  // Мок отвечает через Future.delayed, а внутри testWidgets время фейковое:
  // запрос отправляем и прокручиваем часы, пока он не завершится.
  // Через runAsync нельзя — он пускает реальный асинхрон, и google_fonts
  // уходит грузить шрифты по сети.
  Future<List<Customer>> customers(WidgetTester tester) {
    final pending = repo.getCustomers();
    return tester.pump(const Duration(milliseconds: 300)).then((_) => pending);
  }

  Future<List<Driver>> drivers(WidgetTester tester) {
    final pending = repo.getDrivers();
    return tester.pump(const Duration(milliseconds: 300)).then((_) => pending);
  }

  group('Форма заказчика', () {
    testWidgets('пустая форма: кнопка заблокирована, ошибок ещё нет',
        (tester) async {
      await pumpForm(tester, const CustomerFormPage());

      // Пользователь ничего не трогал — краснеть нечему.
      expect(find.text('Введите название или имя'), findsNothing);
      expect(find.text('Введите номер телефона'), findsNothing);
      expect(submitEnabled(tester, 'Добавить'), isFalse);

      await tester.tap(find.text('Добавить'));
      await settle(tester);

      expect((await customers(tester)).length, 6);
    });

    testWidgets('ошибка загорается после ухода из поля, а не при вводе',
        (tester) async {
      await pumpForm(tester, const CustomerFormPage());

      await tester.enterText(inputFor('Номер телефона'), '+998 90 12');
      await settle(tester);
      // Пока пользователь в поле — подсказку не показываем.
      expect(find.textContaining('Номер неполный'), findsNothing);

      await leaveField(tester);
      expect(find.textContaining('Номер неполный'), findsOneWidget);
      // Соседнее поле не трогали — оно молчит, хотя тоже пустое.
      expect(find.text('Введите адрес доставки'), findsNothing);
    });

    testWidgets('исправление гасит ошибку, не дожидаясь ухода из поля',
        (tester) async {
      await pumpForm(tester, const CustomerFormPage());

      await tester.enterText(inputFor('Номер телефона'), '+998 90 12');
      await leaveField(tester);
      expect(find.textContaining('Номер неполный'), findsOneWidget);

      await tester.enterText(inputFor('Номер телефона'), '901234567');
      await settle(tester);

      expect(find.textContaining('Номер неполный'), findsNothing);
    });

    testWidgets('неполный телефон не даёт нажать «Добавить»', (tester) async {
      await pumpForm(tester, const CustomerFormPage());

      await tester.enterText(inputFor('Название / имя'), 'Чайхана «Тест»');
      await tester.enterText(inputFor('Номер телефона'), '+998 90 12');
      await tester.enterText(inputFor('Адрес доставки'), 'Чиланзар, 5');
      await settle(tester);

      expect(find.textContaining('Номер неполный'), findsOneWidget);
      expect(submitEnabled(tester, 'Добавить'), isFalse);

      await tester.tap(find.text('Добавить'));
      await settle(tester);

      expect((await customers(tester)).length, 6);
    });

    testWidgets('маска приводит ввод к виду +998 90 123 45 67',
        (tester) async {
      await pumpForm(tester, const CustomerFormPage());

      await tester.enterText(inputFor('Номер телефона'), '901234567');
      await tester.pump();
      expect(textOf(tester, 'Номер телефона'), '+998 90 123 45 67');

      // Вставка полного номера из буфера распознаётся так же.
      await tester.enterText(inputFor('Номер телефона'), '+998911234567');
      await tester.pump();
      expect(textOf(tester, 'Номер телефона'), '+998 91 123 45 67');
    });

    testWidgets('у новой формы в поле уже стоит код страны', (tester) async {
      await pumpForm(tester, const CustomerFormPage());
      expect(textOf(tester, 'Номер телефона'), '+998 ');
    });

    testWidgets('валидная форма сохраняет телефон в формате API',
        (tester) async {
      await pumpForm(tester, const CustomerFormPage());

      await tester.enterText(inputFor('Название / имя'), 'Чайхана «Тест»');
      await tester.enterText(inputFor('Номер телефона'), '901234567');
      await tester.enterText(inputFor('Адрес доставки'), 'Чиланзар, 5');
      await settle(tester);

      expect(submitEnabled(tester, 'Добавить'), isTrue);
      await tester.tap(find.text('Добавить'));
      await settle(tester);

      final added = (await customers(tester))
          .firstWhere((c) => c.name == 'Чайхана «Тест»');
      expect(added.phone, '+998901234567');
      expect(find.text('открыть'), findsOneWidget, reason: 'форма закрылась');
    });
  });

  group('Форма водителя', () {
    testWidgets('короткий пароль не даёт нажать «Добавить»', (tester) async {
      await pumpForm(tester, const DriverFormPage());

      await tester.enterText(inputFor('Имя водителя'), 'Азиз Каримов');
      await tester.enterText(inputFor('Номер телефона'), '901234567');
      await tester.enterText(inputFor('Пароль для входа'), '12345');
      await leaveField(tester);
      await settle(tester);

      expect(find.text('Минимум 6 символов'), findsOneWidget);
      expect(submitEnabled(tester, 'Добавить'), isFalse);

      await tester.tap(find.text('Добавить'));
      await settle(tester);

      expect((await drivers(tester)).length, 5);
    });

    testWidgets('пустой пароль водителя не пропускает', (tester) async {
      await pumpForm(tester, const DriverFormPage());

      await tester.enterText(inputFor('Имя водителя'), 'Тимур Юсупов');
      await tester.enterText(inputFor('Номер телефона'), '911234567');
      // Стереть заготовку можно — тогда создавать нечего.
      await tester.enterText(inputFor('Пароль для входа'), '');
      await settle(tester);

      expect(submitEnabled(tester, 'Добавить'), isFalse);

      await tester.tap(find.text('Добавить'));
      await settle(tester);

      expect(
        (await drivers(tester)).where((d) => d.fullName == 'Тимур Юсупов'),
        isEmpty,
      );
    });

    testWidgets('водитель заводится со сгенерированным паролем',
        (tester) async {
      await pumpForm(tester, const DriverFormPage());

      // Пароль подставлен заранее — админу достаточно имени и телефона.
      final generated =
          tester.widget<TextField>(inputFor('Пароль для входа')).controller!.text;
      expect(generated, hasLength(8));
      // Общей заготовки на всех больше нет: под учёткой водителя не войдёт
      // тот, кто просто знает номер телефона.
      expect(generated, isNot('123456'));

      await tester.enterText(inputFor('Имя водителя'), 'Тимур Юсупов');
      await tester.enterText(inputFor('Номер телефона'), '911234567');
      await settle(tester);

      expect(submitEnabled(tester, 'Добавить'), isTrue);
      await tester.tap(find.text('Добавить'));
      await settle(tester);

      final added = (await drivers(tester))
          .firstWhere((d) => d.fullName == 'Тимур Юсупов');
      expect(added.phone, '+998911234567');
    });


    testWidgets('кнопка «показать пароль» раскрывает ввод', (tester) async {
      await pumpForm(tester, const DriverFormPage());

      expect(
        tester.widget<TextField>(inputFor('Пароль для входа')).obscureText,
        isTrue,
      );

      await tester.tap(find.byTooltip('Показать пароль'));
      await tester.pump();

      expect(
        tester.widget<TextField>(inputFor('Пароль для входа')).obscureText,
        isFalse,
      );
    });
  });

  group('Уход с формы', () {
    testWidgets('пустую форму закрывает без вопросов', (tester) async {
      await pumpForm(tester, const CustomerFormPage());

      await tester.tap(find.text('Отменить'));
      await settle(tester);

      expect(find.text('Выйти без сохранения?'), findsNothing);
      expect(find.text('открыть'), findsOneWidget);
    });

    testWidgets('заполненная форма спрашивает подтверждение', (tester) async {
      await pumpForm(tester, const CustomerFormPage());

      await tester.enterText(inputFor('Название / имя'), 'Чайхана «Тест»');
      await tester.tap(find.text('Отменить'));
      await settle(tester);

      expect(find.text('Выйти без сохранения?'), findsOneWidget);

      await tester.tap(find.text('Остаться'));
      await settle(tester);
      expect(find.text('Новый заказчик'), findsOneWidget);
    });
  });
}
