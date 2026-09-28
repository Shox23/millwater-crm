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
  String get errorGeneric =>
      'Не удалось выполнить действие. Попробуйте ещё раз.';

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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count цифр',
      few: '$count цифры',
      one: '$count цифра',
    );
    return 'Номер неполный — нужно $_temp0 после +998';
  }

  @override
  String get fieldEmailInvalid => 'Неверный формат почты';

  @override
  String get fieldEmailEmpty => 'Введите электронную почту';

  @override
  String get fieldPasswordEmpty => 'Введите пароль';

  @override
  String fieldMinLength(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count символов',
      few: '$count символа',
      one: '$count символ',
    );
    return 'Минимум $_temp0';
  }

  @override
  String fieldMaxLength(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count символов',
      few: '$count символов',
      one: '$count символа',
    );
    return 'Не более $_temp0';
  }

  @override
  String get fieldShowPassword => 'Показать пароль';

  @override
  String get fieldHidePassword => 'Скрыть пароль';

  @override
  String get validationGeneric => 'Проверьте правильность заполнения';

  @override
  String validationRequired(String field) {
    return 'Заполните поле «$field»';
  }

  @override
  String validationTooShort(String field) {
    return 'Слишком короткое значение в поле «$field»';
  }

  @override
  String validationTooLong(String field) {
    return 'Слишком длинное значение в поле «$field»';
  }

  @override
  String validationNotNumber(String field) {
    return 'В поле «$field» нужно число';
  }

  @override
  String validationOutOfRange(String field) {
    return 'Значение в поле «$field» вне допустимых границ';
  }

  @override
  String validationBadFormat(String field) {
    return 'Неверный формат в поле «$field»';
  }

  @override
  String get apiFieldFullName => 'Имя или название';

  @override
  String get apiFieldPhone => 'Телефон';

  @override
  String get apiFieldAddress => 'Адрес';

  @override
  String get apiFieldComment => 'Комментарий';

  @override
  String get apiFieldPassword => 'Пароль';

  @override
  String get apiFieldOldPassword => 'Текущий пароль';

  @override
  String get apiFieldNewPassword => 'Новый пароль';

  @override
  String get apiFieldDate => 'Дата';

  @override
  String get apiFieldDriver => 'Водитель';

  @override
  String get apiFieldCustomers => 'Заказчики';

  @override
  String get apiFieldCapsules => 'Количество капсул';

  @override
  String get apiFieldAmount => 'Сумма оплаты';

  @override
  String get apiFieldPaymentMethod => 'Способ оплаты';

  @override
  String get apiFieldBalance => 'Остаток капсул';

  @override
  String get apiFieldPrice => 'Цена капсулы';

  @override
  String get phoneCallUnavailable => 'Звонок недоступен — номер скопирован';

  @override
  String get phoneCopied => 'Номер скопирован';

  @override
  String get phoneCopy => 'Скопировать номер';

  @override
  String get fieldCopy => 'Скопировать';

  @override
  String get fieldCopied => 'Скопировано';

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
    return '$size КБ';
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
  String get deliveryDelivered => 'Доставлено';

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
  String get filterCancelled => 'Отменённые';

  @override
  String get filterFailed => 'Не доставлены';

  @override
  String get filterWithDebt => 'С долгом';

  @override
  String get filterWithCooler => 'С кулером';

  @override
  String get filterInactive => 'Неактивные';

  @override
  String get sessionDiagTitle => 'Последний обрыв сессии';

  @override
  String get sessionDiagNever => 'Обрывов не было';

  @override
  String get sessionDiagCopied => 'Скопировано';

  @override
  String get sessionEndRefreshFailed => 'Не удалось обновить токен';

  @override
  String get sessionEndRestoreRejected => 'Сервер отклонил сохранённую сессию';

  @override
  String get sessionEndSignedOut => 'Выход по кнопке';

  @override
  String get customerFormIsActive => 'Активен';

  @override
  String get customerFormIsActiveHint =>
      'Неактивных не предлагают при сборке маршрута';

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
  String get periodCustom => 'Свои даты…';

  @override
  String dateRangeValue(String from, String to) {
    return '$from — $to';
  }

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
  String get desktopEditRoute => 'Редактировать маршрут';

  @override
  String get routeCancelShort => 'Отменить';

  @override
  String get routeCancelFailed => 'Не удалось отменить маршрут.';

  @override
  String get routeCancelled2 => 'Маршрут отменён';

  @override
  String get routeCompleteTitle => 'Завершить маршрут?';

  @override
  String get routeCompleteMessage =>
      'Маршрут будет закрыт, открыть его заново нельзя.';

  @override
  String routeCompleteMessageOpen(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count незакрытых точек будут отменены',
      few: '$count незакрытые точки будут отменены',
      one: '$count незакрытая точка будет отменена',
    );
    return '$_temp0. Маршрут будет закрыт, открыть его заново нельзя.';
  }

  @override
  String get routeCompleteAction => 'Завершить маршрут';

  @override
  String get routeAwaitsCompletion => 'Все точки закрыты — завершите маршрут';

  @override
  String get routeCompleteShort => 'Завершить';

  @override
  String get routeCompleteFailed => 'Не удалось завершить маршрут.';

  @override
  String get routeCompleted2 => 'Маршрут завершён';

  @override
  String get routeDriver => 'Водитель';

  @override
  String get routeStatDone => 'ВЫПОЛНЕНО';

  @override
  String get routeStatCollected => 'СОБРАНО';

  @override
  String get routeNoDriver => 'Водитель не назначен';

  @override
  String get routeNoDriverHint => 'Маршрут никто не повезёт, пока водителя нет';

  @override
  String get routeAssignDriver => 'Назначить';

  @override
  String get routeCashSection => 'КАССА МАРШРУТА';

  @override
  String get routeExpensesSection => 'РАСХОДЫ ВОДИТЕЛЯ';

  @override
  String get routeNoExpenses => 'Расходов по маршруту нет';

  @override
  String get routeStops => 'ТОЧКИ МАРШРУТА';

  @override
  String routeStopsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count точек',
      few: '$count точки',
      one: '$count точка',
    );
    return '$_temp0';
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
  String get routeFormTitle => 'Новый маршрут';

  @override
  String get routeFormLoadFailed =>
      'Не удалось загрузить водителей и заказчиков';

  @override
  String get routeFormCreateFailed => 'Не удалось создать маршрут.';

  @override
  String get routeFormDate => 'ДАТА';

  @override
  String get routeFormPurpose => 'ЦЕЛЬ МАРШРУТА';

  @override
  String get routeFormPurposeHint => 'Цель по умолчанию для всех точек';

  @override
  String get routeFormAssignLater => 'Назначить позже';

  @override
  String get routeFormAssignLaterHint =>
      'Маршрут останется новым, пока водителя нет';

  @override
  String get routeFormStopPurpose => 'Цель точки';

  @override
  String get routeFormBottleSell => 'КАПСУЛ К ДОСТАВКЕ';

  @override
  String get routeFormBottleSellHint => 'Сколько везти этому заказчику';

  @override
  String get routeFormBottleSellRequired => 'Укажите, сколько капсул везти';

  @override
  String get routeFormBottleSellLocked =>
      'Задано при добавлении точки — сервер менять его не умеет';

  @override
  String stopBottleSell(int count) {
    return 'Ожидаемое кол-во капсул: $count';
  }

  @override
  String get completionBottleSell => 'НАЗНАЧЕНО К ДОСТАВКЕ';

  @override
  String completionBottleSellValue(int count) {
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
  String get completionBottleSellHint =>
      'Столько назначил админ. Ниже отметьте, сколько привезли на самом деле';

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
  String get customerSearchAddress => 'Улица, массив, дом';

  @override
  String get customerSearchModeName => 'Имя и телефон';

  @override
  String get customerSearchModeAddress => 'Адрес';

  @override
  String get stopTitle => 'Точка маршрута';

  @override
  String get stopCapsulesDelivered => 'капсул доставлено';

  @override
  String stopBulkBottles(int count, int liters) {
    return '$count × $liters л';
  }

  @override
  String get stopNothingTaken => 'ничего не забрали';

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
  String get mapAllStopsDone =>
      'Все точки маршрута уже закрыты — вести некуда.';

  @override
  String mapStopsWithoutPoint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'У $count адресов нет точки на карте',
      few: 'У $count адресов нет точки на карте',
      one: 'У $count адреса нет точки на карте',
    );
    return '$_temp0';
  }

  @override
  String get mapAddMapLinkHint =>
      'Такой маршрут откроется в браузере. Чтобы он открывался в Яндекс.Картах, вставьте в адрес заказчика ссылку с карты.';

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
  String get driverReportTile => 'Отчёт по водителю';

  @override
  String get driverReportTileHint => 'Заказы и расходы в Excel за период';

  @override
  String get driverCreatedAt => 'Дата создания';

  @override
  String get driverTripsAndToday => 'сегодня';

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
      'Передайте пароль водителю — восстановить его потом нельзя';

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
  String get customerFormPhoneSecondary => 'Дополнительный телефон';

  @override
  String get customerFormComment => 'Комментарий';

  @override
  String get customerFormCommentHint => 'Например, район или ориентир';

  @override
  String get customerFormSaveFailed => 'Не удалось сохранить заказчика.';

  @override
  String get myRoutesTitle => 'Мои маршруты';

  @override
  String get myRoutesStatRoutes => 'маршрутов за день';

  @override
  String get myRoutesStatDeliveredToday => 'доставлено';

  @override
  String get myRoutesStatOrders => 'заказов за день';

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
    return 'капсул $liters л';
  }

  @override
  String get completionBalance => 'КАПСУЛ У КЛИЕНТА';

  @override
  String completionBalanceFormula(int before, int delivered) {
    return 'было $before + привезено $delivered';
  }

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
  String get profileStatsSection => 'СТАТИСТИКА';

  @override
  String get profileStatsCapsules => 'Продано капсул';

  @override
  String get profileStatsBulk => 'Опт 5 л / 10 л';

  @override
  String get profileStatsExpenses => 'Расходы за период';

  @override
  String get profileStatsFailed => 'Не удалось посчитать статистику';

  @override
  String profileStatsBulkValue(int five, int ten) {
    return '$five / $ten';
  }

  @override
  String get profileAccountSection => 'АККАУНТ';

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
  String get pricesEmpty => 'Укажите цену';

  @override
  String get pricesZero => 'Цена капсулы должна быть больше нуля';

  @override
  String get pricesConfirmTitle => 'Назначить новую цену?';

  @override
  String pricesConfirmMessage(String capsule) {
    return 'Капсула — $capsule.';
  }

  @override
  String get pricesConfirmAction => 'Назначить';

  @override
  String pricesEffectiveFrom(String date) {
    return 'Действует с $date';
  }

  @override
  String get pricesEffectiveFromColumn => 'Действует с';

  @override
  String get pricesHistoryFailed => 'Историю загрузить не удалось.';

  @override
  String get pricesHistoryEmpty => 'Прайс ещё не меняли — это первая цена.';

  @override
  String get reportsLabel => 'Аналитика';

  @override
  String get reportsTitle => 'Отчёты';

  @override
  String get reportExportTitle => 'Выгрузка в Excel';

  @override
  String get reportExportKind => 'ТИП ОТЧЁТА';

  @override
  String get reportKindGeneral => 'Общий';

  @override
  String get reportKindGeneralHint => 'Строка на каждую доставку';

  @override
  String get reportKindCustomers => 'Заказчики';

  @override
  String get reportKindCustomersHint => 'Итог по каждому заказчику за период';

  @override
  String get reportKindDrivers => 'Водители';

  @override
  String get reportKindDriversHint => 'Заказы и расходы по водителям';

  @override
  String get reportExportDriver => 'ВОДИТЕЛЬ';

  @override
  String get reportExportAllDrivers => 'Все водители';

  @override
  String get reportExportPeriod => 'ПЕРИОД';

  @override
  String get reportExportAction => 'Выгрузить';

  @override
  String get reportExportDone => 'Отчёт выгружен';

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
    return '$count шт.';
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

  @override
  String get desktopBrandSubtitle => 'Доставка воды';

  @override
  String get desktopNavGroup => 'РАБОТА';

  @override
  String get desktopOnLineTitle => 'СЕГОДНЯ НА ЛИНИИ';

  @override
  String desktopOnLineOf(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count водителей',
      one: '$count водителя',
    );
    return 'из $_temp0';
  }

  @override
  String get desktopSearchHint => 'Поиск';

  @override
  String get desktopNotifications => 'Уведомления';

  @override
  String get desktopAddDriver => 'Водитель';

  @override
  String get desktopAddRoute => 'Маршрут';

  @override
  String get desktopAddCustomer => 'Заказчик';

  @override
  String desktopRoutesSubtitle(String date, int count) {
    return '$date · $count в работе';
  }

  @override
  String get desktopDriverStubTitle => 'Это рабочее место администратора';

  @override
  String get desktopDriverStubHint =>
      'Маршруты и доставки открываются в мобильном приложении — зайдите с телефона.';

  @override
  String driversCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count водителей',
      few: '$count водителя',
      one: '$count водитель',
    );
    return '$_temp0';
  }

  @override
  String customersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count заказчиков',
      few: '$count заказчика',
      one: '$count заказчик',
    );
    return '$_temp0';
  }

  @override
  String get filterDelivered => 'Доставлены';

  @override
  String get desktopColCustomer => 'ЗАКАЗЧИК';

  @override
  String get desktopColDriver => 'ВОДИТЕЛЬ';

  @override
  String get desktopColCapsules => 'КАПСУЛЫ';

  @override
  String get desktopColSum => 'СУММА';

  @override
  String get desktopColPayment => 'ОПЛАТА';

  @override
  String get navCash => 'Касса';

  @override
  String get cashDesktopTitle => 'Касса и расходы';

  @override
  String get cashDesktopTotal => 'Расходы за период';

  @override
  String get cashDesktopEmpty => 'Расходов за период нет';

  @override
  String get cashDesktopEmptyHint => 'Попробуйте другой период или категорию';

  @override
  String get cashDesktopFailed => 'Не удалось загрузить расходы';

  @override
  String get desktopColCategory => 'КАТЕГОРИЯ';

  @override
  String get desktopColComment => 'КОММЕНТАРИЙ';

  @override
  String get desktopColDate => 'ДАТА';

  @override
  String get desktopColNumber => '№';

  @override
  String get desktopColPurpose => 'ЦЕЛЬ';

  @override
  String get desktopColDamaged => 'БРАК';

  @override
  String get desktopColStatus => 'СТАТУС';

  @override
  String get desktopKpiCollected => 'Собрано за день';

  @override
  String get desktopKpiDebt => 'В долг за день';

  @override
  String get desktopKpiCashBalance => 'Остаток кассы';

  @override
  String get desktopKpiExpenses => 'Расходы за день';

  @override
  String get desktopKpiCapsules => 'Выдано капсул';

  @override
  String get desktopKpiPlannedStops => 'Точек в плане';

  @override
  String get desktopExpectedWholeDay => 'Весь день';

  @override
  String get desktopKpiPlannedDrivers => 'Водителей на день';

  @override
  String get desktopKpiPlannedCustomers => 'Заказчиков в плане';

  @override
  String get desktopSummaryDone => 'Выполненные доставки';

  @override
  String get desktopSummaryPlanned => 'Запланировано доставок';

  @override
  String get desktopDebtShort => 'В долг';

  @override
  String get desktopDateToday => 'сегодня';

  @override
  String desktopDatePlanned(int count) {
    return '$count в плане';
  }

  @override
  String get desktopDayEmpty => 'На этот день доставок нет';

  @override
  String get desktopDayEmptyHint => 'Создайте маршрут или выберите другой день';

  @override
  String get desktopDebtEstimated => 'оценка по цене капсулы';

  @override
  String routesCountPlural(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count маршрутов',
      few: '$count маршрута',
      one: '$count маршрут',
    );
    return '$_temp0';
  }

  @override
  String get commonClose => 'Закрыть';

  @override
  String get desktopDeliveryTitle => 'Доставка';

  @override
  String get desktopFinishedAndPaid => 'Завершено и оплачено';

  @override
  String get desktopDeleteRoute => 'Удалить маршрут';

  @override
  String get routeDeleteTitle => 'Удалить маршрут?';

  @override
  String get routeDeleteMessage =>
      'Маршрут и все доставки по нему будут удалены без возможности восстановления.';

  @override
  String get routeDeleted => 'Маршрут удалён';

  @override
  String get routeDeleteFailed => 'Не удалось удалить маршрут.';

  @override
  String get desktopOnLine => 'На линии';

  @override
  String get desktopFree => 'Свободен';

  @override
  String get desktopColAddress => 'АДРЕС';

  @override
  String get desktopColBalance => 'БАЛАНС';

  @override
  String get desktopColLastOrder => 'ПОСЛ. ЗАКАЗ';

  @override
  String get desktopColCapsulesShort => 'КАПСУЛ';

  @override
  String desktopBalanceDebt(String amount) {
    return 'Долг $amount';
  }

  @override
  String desktopBalancePrepaid(String amount) {
    return 'Аванс $amount';
  }

  @override
  String get desktopSuccessDone => 'Готово';

  @override
  String get desktopWithCooler => 'С кулером';

  @override
  String get desktopWithoutCooler => 'Без кулера';

  @override
  String get desktopFieldCapsules => 'Капсулы';

  @override
  String get desktopFieldSum => 'Сумма';

  @override
  String get desktopFieldStatus => 'Статус';

  @override
  String get desktopFieldTime => 'Закрыта';

  @override
  String get desktopFieldAddress => 'Адрес';

  @override
  String get desktopChartTitle => 'Выручка по дням';

  @override
  String get desktopPrepayments => 'Предоплаты';

  @override
  String get desktopNoDebtors => 'Должников нет';

  @override
  String get desktopNoPrepayments => 'Предоплат нет';

  @override
  String get desktopCapsulesWithCooler => 'У заказчиков с кулером';

  @override
  String get desktopCapsulesWithoutCooler => 'У остальных';

  @override
  String get desktopFieldCooler => 'Кулер';

  @override
  String get orderPurposeDelivery => 'Доставка 19 л';

  @override
  String get orderPurposePickup => 'Вывоз';

  @override
  String get orderPurposeDeliveryShort => '19 л';

  @override
  String get orderPurposePickupShort => 'Вывоз';

  @override
  String get orderPurposeBulkShort => 'Опт';

  @override
  String get orderPurposeBulk => 'Опт 5/10 л';

  @override
  String coolersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count кулеров',
      few: '$count кулера',
      one: '$count кулер',
    );
    return '$_temp0';
  }

  @override
  String customerCustomPrice(String price) {
    return 'Своя цена: $price';
  }

  @override
  String get customerFormCoolers => 'Кулеров у заказчика';

  @override
  String get customerFormCoolersHint =>
      'К кулеру капсулу ставят, без него воду переливают';

  @override
  String get customerFormCapsules => 'Капсул у заказчика';

  @override
  String get customerFormCapsulesHint => 'Сколько тары на руках сейчас';

  @override
  String get customerFormCapsulesLocked =>
      'Заменит остаток, который ведёт водитель';

  @override
  String get customerFormLastOrder => 'Последний заказ';

  @override
  String get customerFormLastOrderHint =>
      'Когда заказчик брал воду в последний раз — по этому дню список подсвечивает замолчавших';

  @override
  String get customerFormLastOrderNone => 'Не указан';

  @override
  String get customerFormLastOrderLocked =>
      'Заменит дату, которую ставит закрытие доставки';

  @override
  String get customerFormBalance => 'Стартовый баланс';

  @override
  String get customerFormBalanceNone => 'Нет';

  @override
  String get customerFormBalanceDebt => 'Долг';

  @override
  String get customerFormBalancePrepayment => 'Предоплата';

  @override
  String get customerFormBalanceAmount => 'Сумма';

  @override
  String get customerFormBalanceEmpty => 'Введите сумму';

  @override
  String get customerFormBalanceHint =>
      'Долг и предоплата одновременно невозможны';

  @override
  String get customerFormPrice => 'Цена капсулы';

  @override
  String get customerFormPriceDefault => 'По прайсу';

  @override
  String get customerFormPriceCustom => 'Своя';

  @override
  String get customerFormPriceValue => 'Цена для заказчика';

  @override
  String get customerFormPriceEmpty => 'Введите цену';

  @override
  String customerFormPriceHelper(String price) {
    return 'Общая цена: $price';
  }

  @override
  String get pricesDamagedFine => 'Штраф за брак';

  @override
  String get pricesDamagedFineHelper => 'Сум за одну повреждённую капсулу';

  @override
  String get pricesDamagedFineRow => 'Штраф за капсулу';

  @override
  String get completionDebtLine => 'Уйдёт в долг';

  @override
  String get completionDebtHint =>
      'В долг деньги не принимают — сумма начисляется заказчику';

  @override
  String get completionReturned => 'ЗАБРАНО ПУСТЫХ';

  @override
  String get completionReturnedCaption => 'капсул забрали у заказчика';

  @override
  String get completionDamaged => 'ПОВРЕЖДЕНО';

  @override
  String get completionDamagedCaption => 'капсул с браком — за них штраф';

  @override
  String get completionPickedCoolers => 'КУЛЕРОВ ЗАБРАНО';

  @override
  String get completionPickedCoolersCaption => 'кулеров увозим с точки';

  @override
  String get completionPickedBottles => 'КАПСУЛ ЗАБРАНО';

  @override
  String get completionPickedBottlesCaption => 'капсул увозим с точки';

  @override
  String get completionBulk5l => 'БУТЫЛИ 5 Л';

  @override
  String get completionBulk10l => 'БУТЫЛИ 10 Л';

  @override
  String get completionBulkCount => 'количество';

  @override
  String get completionBulkPrice => 'Цена за бутыль';

  @override
  String get completionBulkPriceRequired =>
      'Укажите цену за бутыль — сервер иначе не примет';

  @override
  String get completionPickupHint =>
      'Сумма за вывоз — по договорённости с заказчиком';

  @override
  String get completionZeroNeedsDebt =>
      'Нулевую сумму сервер принимает только со способом «В долг»';

  @override
  String get completionPickupRequired =>
      'Укажите, что забрали: кулеры, капсулы или брак';

  @override
  String get completionDeliveryRequired =>
      'Укажите, что привезли, забрали брак или приняли возврат';

  @override
  String completionFormulaDamaged(
    String capsules,
    String price,
    String damaged,
    String fine,
  ) {
    return '$capsules × $price + брак $damaged × $fine';
  }

  @override
  String get errorBothBalances =>
      'У заказчика не может быть долга и предоплаты одновременно';

  @override
  String get errorOrderCompleted => 'Заказ уже закрыт';

  @override
  String get errorOrderNotCompleted => 'Заказ ещё не закрыт';

  @override
  String get errorRouteNotInProgress => 'Маршрут не в работе';

  @override
  String get errorBulkPriceRequired => 'Укажите цену для опта';

  @override
  String get errorInvalidDamagedCount =>
      'Повреждённых больше, чем привезли и забрали';

  @override
  String get errorCustomerPhoneExists =>
      'Этот телефон уже записан за другим заказчиком';

  @override
  String get errorPhoneExists => 'Этот телефон уже занят';

  @override
  String get errorDriverBusy => 'У водителя уже есть маршрут на эту дату';

  @override
  String get errorRouteStarted => 'Маршрут уже начат';

  @override
  String get errorRouteCompleted => 'Маршрут уже завершён';

  @override
  String get errorAccessDenied => 'Нет доступа';

  @override
  String get errorNotFound => 'Запись не найдена';

  @override
  String get ordersTitle => 'Заказы';

  @override
  String get ordersTileHint => 'Все заказы за всё время';

  @override
  String get ordersDateRange => 'Период…';

  @override
  String ordersDateRangeValue(String from, String to) {
    return '$from — $to';
  }

  @override
  String get ordersSearch => 'Заказчик, телефон, адрес';

  @override
  String get ordersEmpty => 'Заказов пока нет';

  @override
  String get ordersLoadFailed => 'Не удалось загрузить заказы';

  @override
  String ordersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count заказов',
      few: '$count заказа',
      one: '$count заказ',
    );
    return '$_temp0';
  }

  @override
  String orderNumber(int number) {
    return 'Заказ №$number';
  }

  @override
  String get orderNoDriver => 'Водитель не назначен';

  @override
  String get orderBulk5l => 'Бутыли 5 л';

  @override
  String get orderBulk10l => 'Бутыли 10 л';

  @override
  String get orderPickedCoolers => 'Кулеров забрано';

  @override
  String get orderPickedBottles => 'Капсул забрано';

  @override
  String get orderBulkTotal => 'Опт, сумма';

  @override
  String get orderSectionPayments => 'ИСТОРИЯ ПЛАТЕЖЕЙ';

  @override
  String get orderPaymentsEmpty => 'Платежей по заказу нет';

  @override
  String get orderPaymentRefund => 'Возврат';

  @override
  String get orderUnpaid => 'Осталось получить';

  @override
  String get orderSectionExpected => 'ОЖИДАЕТСЯ';

  @override
  String get orderExpectedCapsules => 'Ожидаемое кол-во капсул';

  @override
  String get orderExpectedAmount => 'Ожидаемая сумма';

  @override
  String get orderSectionComposition => 'СОСТАВ';

  @override
  String get orderSectionMoney => 'РАСЧЁТ';

  @override
  String get orderSectionRoute => 'МАРШРУТ';

  @override
  String get orderDelivered => 'Доставлено';

  @override
  String get orderReturned => 'Забрано пустых';

  @override
  String get orderDamaged => 'Повреждено';

  @override
  String get orderBalanceAfter => 'Остаток у заказчика';

  @override
  String get orderAmount => 'Сумма заказа';

  @override
  String get orderPriceApplied => 'Цена капсулы в заказе';

  @override
  String get orderFineApplied => 'Штраф за повреждённую';

  @override
  String get orderPaymentMethod => 'Способ оплаты';

  @override
  String get orderCompletedAt => 'Закрыт';

  @override
  String get orderCreatedAt => 'Создан';

  @override
  String get orderNotCompleted => 'Ещё не закрыт';

  @override
  String get orderOpenFailed => 'Не удалось открыть заказ';

  @override
  String get driverOrdersTitle => 'Мои заказы';

  @override
  String get driverOrdersTileHint => 'История заказов за всё время';

  @override
  String pricesFineRow(String amount) {
    return 'штраф $amount';
  }

  @override
  String pricesConfirmFine(String fine) {
    return 'Штраф за повреждённую капсулу — $fine.';
  }

  @override
  String get orderMoveTitle => 'Перенести заказ';

  @override
  String get orderMoveDate => 'Дата';

  @override
  String get orderMoveRoutes => 'МАРШРУТ НА ЭТУ ДАТУ';

  @override
  String get orderMoveNewRoute => 'Новый маршрут';

  @override
  String get orderMoveNewRouteHint =>
      'Сервер заведёт маршрут на выбранную дату';

  @override
  String get orderMoveNoDriver =>
      'У нового маршрута не будет водителя — назначьте его на экране маршрутов';

  @override
  String get orderMoveNoRoutes => 'На эту дату маршрутов пока нет';

  @override
  String get orderMoveRoutesFailed => 'Не удалось загрузить маршруты';

  @override
  String get orderMoveAction => 'Перенести';

  @override
  String get orderMoveFailed => 'Не удалось перенести заказ.';

  @override
  String get orderMoved => 'Заказ перенесён';

  @override
  String orderRouteStops(int count, String driver) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count точек',
      few: '$count точки',
      one: '$count точка',
    );
    return '$_temp0 · $driver';
  }

  @override
  String get orderNoDriverShort => 'без водителя';

  @override
  String get orderPaymentTitle => 'Изменение оплаты';

  @override
  String get orderPaymentAmount => 'Итоговая сумма заказа';

  @override
  String get orderPaymentAmountHint =>
      'Не доплата, а вся сумма заказа: разницу сервер посчитает сам';

  @override
  String get orderPaymentAmountEmpty => 'Введите сумму';

  @override
  String orderPaymentWasBecomes(String before, String after) {
    return 'Было $before → станет $after';
  }

  @override
  String get orderPaymentNote => 'Комментарий';

  @override
  String get orderPaymentNoteHint =>
      'Зачем правите — останется в истории платежей';

  @override
  String get orderPaymentBalanceNow => 'Баланс заказчика сейчас';

  @override
  String get orderPaymentBalanceHint =>
      'Разницу сервер запишет заказчику в долг или предоплату';

  @override
  String get orderPaymentSaved => 'Оплата изменена';

  @override
  String get orderPaymentFailed => 'Не удалось изменить оплату.';

  @override
  String get orderActionMove => 'Перенести';

  @override
  String get orderActionPayment => 'Изменить оплату';

  @override
  String get expenseCategoryFuel => 'Топливо';

  @override
  String get expenseCategoryLunch => 'Обед';

  @override
  String get expenseCategoryRepair => 'Ремонт';

  @override
  String get expenseCategoryOther => 'Прочее';

  @override
  String get cashTitle => 'Касса маршрута';

  @override
  String get cashOpen => 'Касса и расходы';

  @override
  String get cashCollectedCash => 'Наличными';

  @override
  String get cashCollectedCashless => 'Безналом';

  @override
  String get cashDebtAmount => 'Ушло в долг';

  @override
  String get cashExpensesTotal => 'Расходы';

  @override
  String get cashBalance => 'Остаток наличных';

  @override
  String get cashBalanceHint =>
      'Собранные наличные минус расходы — столько нужно сдать';

  @override
  String get cashExpensesSection => 'РАСХОДЫ';

  @override
  String get cashNoExpenses => 'Расходов пока нет';

  @override
  String get cashAddExpense => 'Добавить расход';

  @override
  String get cashLoadFailed => 'Не удалось загрузить кассу';

  @override
  String get expenseTitle => 'Новый расход';

  @override
  String get expenseAmount => 'Сумма расхода';

  @override
  String get expenseAmountHint => 'Сколько потратили из кассы';

  @override
  String get expenseAmountRequired => 'Укажите сумму больше нуля';

  @override
  String get expenseCategory => 'КАТЕГОРИЯ';

  @override
  String get expenseComment => 'Комментарий';

  @override
  String get expenseCommentHint => 'Зачем потратили — останется в отчёте';

  @override
  String get expensePhoto => 'Фото чека';

  @override
  String get expensePhotoSubtitle => 'Снимок чека — по нему сверяют расход';

  @override
  String get expenseSaved => 'Расход записан';

  @override
  String get expenseFailed => 'Не удалось записать расход.';

  @override
  String get expenseDelete => 'Удалить расход';

  @override
  String get expenseDeleteConfirm =>
      'Расход вычтется из кассы обратно. Удалить?';

  @override
  String get expenseDeleteFailed => 'Не удалось удалить расход.';

  @override
  String get errorDateInPast => 'Дата не может быть в прошлом';

  @override
  String get errorLastOrderDateFuture =>
      'Дата последнего заказа не может быть в будущем';

  @override
  String get deliveryCancelled => 'Отменён';

  @override
  String get orderReturnedFull => 'Возвращено с водой';

  @override
  String get completionReturnedFull => 'ВОЗВРАЩЕНО С ВОДОЙ';

  @override
  String get completionReturnedFullCaption =>
      'полных капсул заказчик вернул — уйдут из его остатка';

  @override
  String completionBalanceFormulaReturned(
    int before,
    int delivered,
    int returned,
  ) {
    return 'было $before + привезено $delivered − возвращено $returned';
  }

  @override
  String completionFormulaReturnedPart(String returned, String price) {
    return '− возврат $returned × $price';
  }

  @override
  String get completionReturnedFullHint =>
      'Итог по возврату посчитает сервер — сумма здесь ориентировочная';

  @override
  String get orderActionCancel => 'Отменить заказ';

  @override
  String get orderCancelTitle => 'Отмена заказа';

  @override
  String get orderCancelWarning =>
      'Заказ закроется без доставки. Вернуть его в работу нельзя.';

  @override
  String get orderCancelReason => 'Причина отмены';

  @override
  String get orderCancelReasonHint =>
      'Необязательно — останется в карточке заказа';

  @override
  String get orderCancelled => 'Заказ отменён';

  @override
  String get orderCancelFailed => 'Не удалось отменить заказ.';

  @override
  String get orderSectionCancellation => 'ОТМЕНА';

  @override
  String get orderCancelledAt => 'Отменён';

  @override
  String get orderCancelReasonEmpty => 'Причина не указана';

  @override
  String get orderCancelReasonRouteCompleted =>
      'Не выполнен до завершения маршрута';

  @override
  String get routeFormCustomPrice => 'Цена заказа';

  @override
  String get routeFormCustomPriceHint => 'По прайсу';

  @override
  String get routeFormCustomPriceHelper =>
      'Сум за весь заказ, сколько бы капсул ни привезли. Пусто — по прайсу';

  @override
  String get routeFormCustomPriceInvalid => 'Сумма должна быть больше нуля';

  @override
  String get routeFormPickupPriceHint => 'Без оплаты';

  @override
  String get routeFormPickupPriceHelper =>
      'Сум за вывоз кулера или капсул. Пусто — вывоз без оплаты';

  @override
  String stopCustomPrice(String amount) {
    return 'Ожидаемая сумма: $amount';
  }

  @override
  String get orderCustomPrice => 'Цена заказа (договорная)';

  @override
  String get completionCustomPrice => 'ЦЕНА ЗАКАЗА';

  @override
  String get completionCustomPriceCaption =>
      'Договорная сумма за весь заказ — капсулы, брак и возврат её не меняют';

  @override
  String get completionPickupCustomPriceCaption =>
      'Договорная сумма за вывоз — кулеры, капсулы и брак её не меняют';

  @override
  String completionByCustomPrice(String amount) {
    return 'По цене заказа: $amount';
  }

  @override
  String get routeCreateSearchHint => 'Улица, дом или название';

  @override
  String get routeCreateStopsLabel => 'МАРШРУТ';

  @override
  String routeCreateFound(int count) {
    return 'найдено $count';
  }

  @override
  String routeCreateBase(int count) {
    return '$count всего';
  }

  @override
  String get routeCreateTomorrow => 'Завтра';

  @override
  String get routeCreateDriverTitle => 'Водитель';

  @override
  String get routeCreateBadgeDue => 'ПОРА';

  @override
  String get routeCreateBadgeDebt => 'ДОЛГ';

  @override
  String routeCreateBadgeDebtAmount(String amount) {
    return 'ДОЛГ $amount';
  }

  @override
  String routeCreateUsual(int count) {
    return 'обычно $count';
  }

  @override
  String routeCreateLastDelivery(int count) {
    return 'последняя $count дн. назад';
  }

  @override
  String get routeCreateNoDeliveries => 'доставок ещё не было';

  @override
  String get routeCreateEmptyTitle => 'Точек пока нет';

  @override
  String get routeCreateEmptyHint =>
      'Выберите заказчика — точка добавится с обычным для него заказом, останется только проверить.';

  @override
  String get routeCreateOrderHint => 'порядок объезда';

  @override
  String get routeCreateDragHint => 'Перетащите, чтобы изменить порядок';

  @override
  String get routeCreateMoveUp => 'Выше';

  @override
  String get routeCreateMoveDown => 'Ниже';

  @override
  String get routeCreateRemoveStop => 'Убрать точку';

  @override
  String get routeCreateQtyTitle => 'Сколько капсул';

  @override
  String routeCreatePricePlaceholder(String amount) {
    return 'по прайсу · $amount';
  }

  @override
  String get routeCreatePriceReset => 'По прайсу';

  @override
  String routeCreatePriceHint(String price) {
    return 'Пусто — считаем по прайсу $price за капсулу';
  }

  @override
  String get routeCreatePickupPriceHint =>
      'Пусто — вывоз без оплаты, в итоги не попадёт';

  @override
  String get routeCreateBulkPriceHint =>
      'Пусто — цену опта водитель ставит на месте';

  @override
  String get routeCreateNoPayment => 'без оплаты';

  @override
  String get routeCreatePriceOnSite => 'цена на месте';

  @override
  String get routeCreateOwnPrice => 'своя цена';

  @override
  String get routeCreateTotalStops => 'Точек';

  @override
  String routeCreateTotalCapsules(String liters) {
    return 'Капсул $liters л';
  }

  @override
  String get routeCreateTotalMoney => 'Сумма';

  @override
  String routeCreateOverCapacity(int count) {
    return 'Больше, чем везёт машина — $count';
  }

  @override
  String routeCreateSubmit(int count) {
    return 'Создать маршрут · $count';
  }

  @override
  String routeCreateSubmitShort(int count) {
    return 'Создать · $count';
  }

  @override
  String get routeCreateSubmitEmpty => 'Добавьте точку';

  @override
  String routeCreateSheetTitle(String stops) {
    return '$stops в маршруте';
  }

  @override
  String get routeCreateSheetEmpty => 'Маршрут пуст';

  @override
  String get routeCreateSheetEmptyHint => 'Выберите заказчика из списка';

  @override
  String routeCreateSheetSummary(String capsules, String money) {
    return '$capsules · $money';
  }

  @override
  String get routeCreateBackToList => 'К списку';

  @override
  String routeCreateAdded(String name, String capsules) {
    return '$name · $capsules';
  }

  @override
  String get routeCreateRemoved => 'Точка убрана';

  @override
  String get orderComment => 'Комментарий водителю';

  @override
  String get orderCommentHint => 'Например: позвонить с парковки';

  @override
  String get orderCommentHelper =>
      'Необязательно — водитель увидит его в точке';

  @override
  String get orderCommentTitle => 'Комментарий';

  @override
  String get orderCommentHasOne => 'есть комментарий';

  @override
  String get routeCreateCollapseToDrag =>
      'Сверните точку, чтобы менять порядок';
}
