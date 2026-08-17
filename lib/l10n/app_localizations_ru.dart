// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'CRM Millwater';

  @override
  String get commonCancel => 'Отменить';

  @override
  String get commonCancelShort => 'Отмена';

  @override
  String get commonDelete => 'Удалить';

  @override
  String get commonSave => 'Сохранить';

  @override
  String get commonSaving => 'Сохранение…';

  @override
  String get commonAdd => 'Добавить';

  @override
  String get commonCreate => 'Создать';

  @override
  String get commonCreating => 'Создание…';

  @override
  String get commonEdit => 'Редактировать';

  @override
  String get commonRetry => 'Повторить';

  @override
  String get commonLeave => 'Выйти';

  @override
  String get commonStay => 'Остаться';

  @override
  String get commonOptional => 'Необязательно';

  @override
  String get commonClear => 'Очистить';

  @override
  String get commonNothingFound => 'Ничего не найдено';

  @override
  String get commonDone => 'Выполнено';

  @override
  String get commonPhone => 'Телефон';

  @override
  String get commonSum => 'сум';

  @override
  String moneyAmount(String amount) {
    return '$amount сум';
  }

  @override
  String moneyMillions(String amount) {
    return '$amount млн сум';
  }

  @override
  String get leaveWithoutSavingTitle => 'Выйти без сохранения?';

  @override
  String get leaveWithoutSavingMessage => 'Введённые данные будут потеряны.';

  @override
  String get errorGeneric => 'Ошибка запроса.';

  @override
  String get errorNoConnection => 'Нет связи с сервером.';

  @override
  String get errorLoadFailed => 'Не удалось загрузить данные';

  @override
  String get errorCheckConnection =>
      'Проверьте подключение и попробуйте ещё раз';

  @override
  String emptySearchTitle(String query) {
    return 'По запросу «$query» ничего нет';
  }

  @override
  String get emptySearchHint => 'Проверьте написание или сбросьте поиск';

  @override
  String get emptySearchAction => 'Сбросить поиск';

  @override
  String get fieldRequired => 'Заполните поле';

  @override
  String get fieldPhoneEmpty => 'Введите номер телефона';

  @override
  String fieldPhoneIncomplete(int count) {
    return 'Номер неполный — нужно $count цифр после +998';
  }

  @override
  String get fieldEmailInvalid => 'Неверный формат почты';

  @override
  String get fieldEmailEmpty => 'Введите электронную почту';

  @override
  String get fieldPasswordEmpty => 'Введите пароль';

  @override
  String fieldMinLength(int count) {
    return 'Минимум $count символов';
  }

  @override
  String fieldMaxLength(int count) {
    return 'Не более $count символов';
  }

  @override
  String get fieldShowPassword => 'Показать пароль';

  @override
  String get fieldHidePassword => 'Скрыть пароль';

  @override
  String get phoneCallUnavailable => 'Звонок недоступен — номер скопирован';

  @override
  String get phoneCopied => 'Номер скопирован';

  @override
  String get phoneCopy => 'Скопировать номер';

  @override
  String get photoTitle => 'Фото оплаты';

  @override
  String get photoSubtitle => 'Прикрепите чек или фото доставки';

  @override
  String get photoError => 'Не удалось получить фото. Проверьте доступ.';

  @override
  String get photoRemove => 'Убрать фото';

  @override
  String get photoCamera => 'Камера';

  @override
  String get photoGallery => 'Галерея';

  @override
  String photoSize(int size) {
    return ' · $size КБ';
  }

  @override
  String get themeSystem => 'Как в системе';

  @override
  String get themeSystemShort => 'Система';

  @override
  String get themeLight => 'Светлая';

  @override
  String get themeDark => 'Тёмная';

  @override
  String themeTitle(String mode) {
    return 'Тема · $mode';
  }

  @override
  String languageTitle(String name) {
    return 'Язык · $name';
  }

  @override
  String get languageRussian => 'Русский';

  @override
  String get languageUzbek => 'O‘zbekcha';

  @override
  String get languageSection => 'ЯЗЫК';

  @override
  String get roleAdmin => 'Администратор';

  @override
  String get roleDriver => 'Водитель';

  @override
  String get deliveryPending => 'Новый';

  @override
  String get deliveryOnWay => 'В пути';

  @override
  String get deliveryDelivered => 'Доставлен';

  @override
  String get deliveryFailed => 'Не доставлено';

  @override
  String get deliveryPaid => 'Оплачено';

  @override
  String get routeCreated => 'Создан';

  @override
  String get routeInProgress => 'Выполняется';

  @override
  String get routeCompleted => 'Завершён';

  @override
  String get routeCancelled => 'Отменён';

  @override
  String get filterAll => 'Все';

  @override
  String get filterInProgress => 'В пути';

  @override
  String get filterCompleted => 'Завершены';

  @override
  String get filterNew => 'Новые';

  @override
  String get paymentCash => 'Наличные';

  @override
  String get paymentCard => 'Карта';

  @override
  String get paymentTransfer => 'Перечисление';

  @override
  String get paymentDebt => 'В долг';

  @override
  String get periodToday => 'Сегодня';

  @override
  String get periodWeek => 'Неделя';

  @override
  String get periodMonth => 'Месяц';

  @override
  String get loginTitle => 'Вход в систему';

  @override
  String get loginPhone => 'Номер телефона';

  @override
  String get loginPassword => 'Пароль';

  @override
  String get loginSubmit => 'Войти';

  @override
  String get loginSubmitting => 'Вход…';

  @override
  String get loginErrorCredentials => 'Неверный телефон или пароль.';

  @override
  String get loginErrorGeneric => 'Ошибка входа. Попробуйте ещё раз.';

  @override
  String get loginErrorFailed => 'Не удалось войти. Попробуйте ещё раз.';

  @override
  String get sessionExpired => 'Сессия истекла. Войдите снова.';

  @override
  String get navRoute => 'Маршрут';

  @override
  String get navRoutes => 'Маршруты';

  @override
  String get navDrivers => 'Водители';

  @override
  String get navCustomers => 'Заказчики';

  @override
  String get navReports => 'Отчёты';

  @override
  String get navProfile => 'Профиль';

  @override
  String routesHeaderToday(String date) {
    return 'Сегодня · $date';
  }

  @override
  String routesHeaderOn(String date) {
    return 'На $date';
  }

  @override
  String get routesTitle => 'Маршруты';

  @override
  String get routesRefresh => 'Обновить маршруты';

  @override
  String get routesCreated => 'Маршрут создан';

  @override
  String get routesLoadFailed => 'Не удалось загрузить маршруты';

  @override
  String get routesEmptyTitle => 'Маршрутов пока нет';

  @override
  String routesEmptyDayHint(String date) {
    return 'На $date маршрутов нет';
  }

  @override
  String get dateTabsPick => 'Выбрать дату';

  @override
  String get filterEmptyTitle => 'В этом фильтре пусто';

  @override
  String get filterEmptyHint => 'Попробуйте другой фильтр';

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get routeCardTitle => 'Карточка маршрута';

  @override
  String get routeLoadFailed => 'Не удалось загрузить маршрут';

  @override
  String get routeNotFound => 'Маршрут не найден';

  @override
  String get routeCancelTitle => 'Отменить маршрут?';

  @override
  String get routeCancelMessage => 'Маршрут будет помечен как отменённый.';

  @override
  String get routeCancelAction => 'Отменить маршрут';

  @override
  String get routeCancelFailed => 'Не удалось отменить маршрут.';

  @override
  String get routeCancelled2 => 'Маршрут отменён';

  @override
  String get routeDriver => 'Водитель';

  @override
  String get routeStatDone => 'ВЫПОЛНЕНО';

  @override
  String get routeStatCollected => 'СОБРАНО';

  @override
  String get routeStops => 'ТОЧКИ МАРШРУТА';

  @override
  String routeStopsCount(int count) {
    return '$count точек';
  }

  @override
  String get routeDoneShort => 'выполнено';

  @override
  String get routeProgressTitle => 'Выполнено доставок';

  @override
  String get routeCollectedToday => 'Собрано сегодня';

  @override
  String get routeCollected => 'Собрано';

  @override
  String stopCapsules(int count) {
    return '$count капсул';
  }

  @override
  String get routeFormTitle => 'Новый маршрут';

  @override
  String get routeFormLoadFailed =>
      'Не удалось загрузить водителей и заказчиков';

  @override
  String get routeFormCreateFailed => 'Не удалось создать маршрут.';

  @override
  String get routeFormDate => 'ДАТА';

  @override
  String get routeFormDriver => 'ВОДИТЕЛЬ';

  @override
  String get routeFormNoDrivers => 'Сначала добавьте водителей';

  @override
  String get routeFormCustomers => 'ЗАКАЗЧИКИ';

  @override
  String get routeFormNoCustomers => 'Сначала добавьте заказчиков';

  @override
  String get routeEditTitle => 'Изменить маршрут';

  @override
  String get routeFormSaveFailed => 'Не удалось сохранить изменения.';

  @override
  String get routeEditInProgressHint =>
      'Маршрут уже в работе: дату и водителя менять поздно, можно только добавить заказчиков.';

  @override
  String routeFormSelected(int count) {
    return 'выбрано: $count';
  }

  @override
  String get customerSearch => 'Поиск заказчика';

  @override
  String get stopTitle => 'Точка маршрута';

  @override
  String get stopCapsulesDelivered => 'капсул доставлено';

  @override
  String get stopPaid => 'оплачено';

  @override
  String get stopCompleted => 'Завершено';

  @override
  String get stopPhotoLabel => 'ФОТО ОПЛАТЫ';

  @override
  String get stopPhotoFailed => 'Не удалось загрузить фото';

  @override
  String get mapSectionLabel => 'МАРШРУТ НА КАРТЕ';

  @override
  String get mapFromCurrentPlace =>
      'Маршрут построится от вашего текущего места.';

  @override
  String get mapBuildRoute => 'Построить маршрут';

  @override
  String get mapNeedOnePoint => 'Для маршрута нужна хотя бы одна точка.';

  @override
  String mapPointWithoutAddress(int number) {
    return 'У точки $number не заполнен адрес.';
  }

  @override
  String get mapOpenFailed => 'Не удалось открыть Яндекс.Карты';

  @override
  String get driversTitle => 'Водители';

  @override
  String driversHeader(int count) {
    return 'Команда · $count';
  }

  @override
  String driversHeaderFound(int count) {
    return 'Найдено · $count';
  }

  @override
  String get driversSearch => 'Поиск водителя';

  @override
  String get driversRefresh => 'Обновить список';

  @override
  String get driversLoadFailed => 'Не удалось загрузить водителей';

  @override
  String get driversEmptyTitle => 'Водителей пока нет';

  @override
  String get driversEmptyHint =>
      'Добавьте первого — на него можно будет назначить маршрут';

  @override
  String get driversEmptyAction => 'Добавить водителя';

  @override
  String get driverAdded => 'Водитель добавлен';

  @override
  String get driverDeleted => 'Водитель удалён';

  @override
  String get changesSaved => 'Изменения сохранены';

  @override
  String get driverDeleteTitle => 'Удалить водителя?';

  @override
  String driverDeleteMessage(String name) {
    return '$name будет удалён из списка.';
  }

  @override
  String get driverDeleteFailed => 'Не удалось удалить водителя.';

  @override
  String get driverTitle => 'Водитель';

  @override
  String get driverOnRoute => 'Сегодня на маршруте';

  @override
  String get driverNoTrips => 'Сегодня без поездок';

  @override
  String get driverTripsTotal => 'всего поездок';

  @override
  String get driverTripsToday => 'поездок сегодня';

  @override
  String get driverCreatedAt => 'Дата создания';

  @override
  String get driverTripsAndToday => '  ·  сегодня ';

  @override
  String get driverFormEditTitle => 'Редактирование водителя';

  @override
  String get driverFormNewTitle => 'Новый водитель';

  @override
  String get driverFormName => 'Имя водителя';

  @override
  String get driverFormNameHint => 'Например, Азиз Каримов';

  @override
  String get driverFormNameEmpty => 'Введите имя водителя';

  @override
  String get driverFormPassword => 'Пароль для входа';

  @override
  String get driverFormPasswordHelper =>
      'Стартовый пароль — водитель сменит его в настройках';

  @override
  String get driverFormSaveFailed => 'Не удалось сохранить водителя.';

  @override
  String get minSixChars => 'Минимум 6 символов';

  @override
  String get customersTitle => 'Заказчики';

  @override
  String customersHeader(int count) {
    return 'База · $count';
  }

  @override
  String customersHeaderFound(int count) {
    return 'Найдено · $count';
  }

  @override
  String get customersLoadFailed => 'Не удалось загрузить заказчиков';

  @override
  String get customersEmptyTitle => 'Заказчиков пока нет';

  @override
  String get customersEmptyHint =>
      'Добавьте первого — он появится в списке и в маршрутах';

  @override
  String get customersEmptyAction => 'Добавить заказчика';

  @override
  String get customerAdded => 'Заказчик добавлен';

  @override
  String get customerDeleted => 'Заказчик удалён';

  @override
  String get customerDeleteTitle => 'Удалить заказчика?';

  @override
  String customerDeleteMessage(String name) {
    return '$name будет удалён из базы.';
  }

  @override
  String get customerDeleteFailed => 'Не удалось удалить заказчика.';

  @override
  String get customerTitle => 'Заказчик';

  @override
  String get customerHasCooler => 'Есть кулер';

  @override
  String get customerFormHasCooler => 'У заказчика есть кулер';

  @override
  String get customerCapsulesBalance => 'капсул на руках';

  @override
  String get customerLastOrder => 'последний заказ';

  @override
  String customerLastOrderShort(String date) {
    return 'посл. заказ $date';
  }

  @override
  String get financePrepayment => 'Предоплата';

  @override
  String get financeDebt => 'Долг';

  @override
  String get customerFormEditTitle => 'Редактирование заказчика';

  @override
  String get customerFormNewTitle => 'Новый заказчик';

  @override
  String get customerFormName => 'Название / имя';

  @override
  String get customerFormNameHint => 'Например, Кафе «Nasiba»';

  @override
  String get customerFormNameEmpty => 'Введите название или имя';

  @override
  String get customerFormAddress => 'Адрес доставки';

  @override
  String get customerFormAddressHint => 'Район, улица, дом';

  @override
  String get customerFormAddressEmpty => 'Введите адрес доставки';

  @override
  String get customerFormComment => 'Комментарий';

  @override
  String get customerFormCommentHint => 'Например, район или ориентир';

  @override
  String get customerFormSaveFailed => 'Не удалось сохранить заказчика.';

  @override
  String get myRoutesTitle => 'Мои маршруты';

  @override
  String get myRoutesStatRoutes => 'всего маршрутов';

  @override
  String get myRoutesStatDeliveredToday => 'доставлено сегодня';

  @override
  String get myRoutesStatOrders => 'всего заказов';

  @override
  String get myRoutesEmptyHint =>
      'Когда диспетчер назначит маршрут, он появится здесь';

  @override
  String get myRouteTitle => 'Маршрут';

  @override
  String get myRouteStatusFailed => 'Не удалось изменить статус.';

  @override
  String myRouteStatusChanged(String status) {
    return 'Статус: $status';
  }

  @override
  String get myRouteChangeStatus => 'Изменить статус';

  @override
  String get completionTitle => 'Завершение доставки';

  @override
  String get completionCoordinates => 'КООРДИНАТЫ ТОЧКИ';

  @override
  String get completionCapsules => 'КОЛИЧЕСТВО КАПСУЛ';

  @override
  String completionCapsulesCaption(int liters) {
    return 'капсул $litersл';
  }

  @override
  String get completionBalance => 'КАПСУЛ У КЛИЕНТА';

  @override
  String get completionBalanceCaption =>
      'станет остатком у клиента вместо прежнего';

  @override
  String get completionBalanceUnchecked =>
      'Подставлено число привезённых. Сверьте со складом клиента — это значение заменит прежний остаток.';

  @override
  String get completionMethod => 'СПОСОБ ОПЛАТЫ';

  @override
  String get completionAmount => 'СУММА ОПЛАТЫ';

  @override
  String get completionAmountRequired =>
      'Укажите сумму. Ноль — если оплаты не было';

  @override
  String get completionTotal => 'Итого к оплате';

  @override
  String get completionSubmit => 'Завершить';

  @override
  String get completionForbidden =>
      'Завершать доставку может только водитель этого маршрута.';

  @override
  String get completionFailed => 'Не удалось завершить доставку.';

  @override
  String completionByPrice(String formula) {
    return 'По прайсу: $formula';
  }

  @override
  String get completionRestoreAmount => 'Вернуть расчёт';

  @override
  String get locationSearching => 'Определяем координаты…';

  @override
  String get locationFixed => 'Точка зафиксирована';

  @override
  String get locationNotFixed => 'Точка не зафиксирована';

  @override
  String get locationCanContinue => 'Доставку можно завершить и так.';

  @override
  String get locationRetry => 'Определить заново';

  @override
  String get locationDisabled => 'Геолокация выключена в настройках телефона.';

  @override
  String get locationDeniedForever =>
      'Доступ к геолокации запрещён. Разрешите его в настройках телефона.';

  @override
  String get locationDenied => 'Нет доступа к геолокации.';

  @override
  String get locationUnknown => 'Не удалось определить координаты.';

  @override
  String get profileTitle => 'Профиль';

  @override
  String get profileAccountLabel => 'Аккаунт';

  @override
  String get profileAccountSection => 'УЧЁТНАЯ ЗАПИСЬ';

  @override
  String get settingsAppearance => 'ОФОРМЛЕНИЕ';

  @override
  String get settingsAccount => 'АККАУНТ';

  @override
  String get settingsSessionActive => 'Сессия активна';

  @override
  String get settingsLogout => 'Выйти из аккаунта';

  @override
  String get settingsLogoutTitle => 'Выйти из аккаунта?';

  @override
  String get settingsLogoutMessage =>
      'Придётся войти заново по номеру телефона и паролю.';

  @override
  String get passwordChangeTitle => 'Смена пароля';

  @override
  String get passwordChangeTile => 'Сменить пароль';

  @override
  String get passwordChangeTileHint => 'Понадобится текущий пароль';

  @override
  String get passwordChanged => 'Пароль изменён';

  @override
  String get passwordCurrent => 'Текущий пароль';

  @override
  String get passwordCurrentEmpty => 'Введите текущий пароль';

  @override
  String get passwordNew => 'Новый пароль';

  @override
  String get passwordRepeat => 'Повторите новый пароль';

  @override
  String get passwordSameAsCurrent => 'Новый пароль совпадает с текущим';

  @override
  String get passwordMismatch => 'Пароли не совпадают';

  @override
  String get passwordChangeFailed => 'Не удалось сменить пароль.';

  @override
  String get passwordWrongCurrent => 'Неверный текущий пароль.';

  @override
  String get passwordKeepMessage => 'Пароль останется прежним.';

  @override
  String get passwordSubmit => 'Сменить';

  @override
  String get pricesTitle => 'Цены';

  @override
  String get pricesTileHint => 'Стоимость капсулы и залог за тару';

  @override
  String get pricesSection => 'ПРАЙС';

  @override
  String get pricesUpdated => 'Цены обновлены';

  @override
  String get pricesLoadFailed => 'Не удалось загрузить цены';

  @override
  String get pricesSaveFailed => 'Не удалось сохранить цены.';

  @override
  String get pricesCurrent => 'ДЕЙСТВУЮЩИЙ ПРАЙС';

  @override
  String get pricesNew => 'НОВЫЕ ЗНАЧЕНИЯ';

  @override
  String get pricesHistory => 'ИСТОРИЯ ИЗМЕНЕНИЙ';

  @override
  String get pricesCapsule => 'Цена капсулы';

  @override
  String pricesCapsuleHelper(int liters) {
    return 'Сум за одну капсулу $liters л';
  }

  @override
  String pricesCapsuleRow(int liters) {
    return 'Капсула $liters л';
  }

  @override
  String get pricesDeposit => 'Залог за тару';

  @override
  String get pricesDepositHelper => 'Сум; 0 — залога нет';

  @override
  String pricesDepositRow(String amount) {
    return 'залог $amount';
  }

  @override
  String get pricesEmpty => 'Укажите цену';

  @override
  String get pricesZero => 'Цена капсулы должна быть больше нуля';

  @override
  String get pricesConfirmTitle => 'Назначить новую цену?';

  @override
  String pricesConfirmMessage(String capsule, String deposit) {
    return 'Капсула — $capsule, залог — $deposit.';
  }

  @override
  String get pricesConfirmAction => 'Назначить';

  @override
  String pricesEffectiveFrom(String date) {
    return 'Действует с $date';
  }

  @override
  String get pricesHistoryFailed => 'Историю загрузить не удалось.';

  @override
  String get pricesHistoryEmpty => 'Прайс ещё не меняли — это первая цена.';

  @override
  String get reportsLabel => 'Аналитика';

  @override
  String get reportsTitle => 'Отчёты';

  @override
  String get reportsExport => 'Выгрузить в Excel';

  @override
  String get reportsExportSubject => 'Отчёт Millwater';

  @override
  String get reportsExportFailed => 'Не удалось выгрузить отчёт.';

  @override
  String get reportsLoadFailed => 'Не удалось загрузить отчёты';

  @override
  String get reportsRevenue => 'Выручка';

  @override
  String get reportsDeliveries => 'Доставки';

  @override
  String get reportsDebts => 'Долги';

  @override
  String get reportsCapsules => 'Капсулы у клиентов';

  @override
  String reportsCapsulesCount(int count) {
    return '$count шт';
  }

  @override
  String get reportsDebtors => 'Долги заказчиков';

  @override
  String capsulesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count капсул',
      few: '$count капсулы',
      one: '$count капсула',
    );
    return '$_temp0';
  }

  @override
  String tripsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count поездок',
      few: '$count поездки',
      one: '$count поездка',
    );
    return '$_temp0';
  }

  @override
  String clientsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count клиентов',
      few: '$count клиента',
      one: '$count клиент',
    );
    return '$_temp0';
  }
}
