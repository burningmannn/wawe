# Wawe — обучающее приложение (SwiftUI, SOLID, MVI)

Wawe — мультиплатформенное (iOS/macOS) приложение для изучения английского с акцентом на удобство и масштабируемость. Содержит словарь, неправильные глаголы, вопросы/ответы (с тестами), гибкие заметки (таблицы + markdown), и профиль пользователя.

## Возможности
- Слова: добавление/редактирование, поиск, прогресс, авто-перенос изученных
- Неправильные глаголы: тройки форм, поиск, прогресс, пошаговый тест
- Вопросы: пары вопрос/ответ, поиск, прогресс, тесты по разделу
- Заметки:
  - Таблицы с заголовками/подвалом, добавление строк/колонок
  - Отдельные заметки с картинкой и markdown-описанием
- Настройки: лимиты повторов, экспорт/импорт, диагностика
- Профиль: базовая информация, бейджи, тема приложения

## Архитектура
- UI (SwiftUI):
  - Views: экраны разделов
  - Components: переиспользуемые компоненты (например, MarkdownEditor)
- Presentation (MVI):
  - ViewModels: состояние, интенты, фильтрация, связь с репозиториями/Store
- Domain:
  - Models: Word, IrregularVerb, QuestionItem, ImageNote
- Data:
  - Store: WordStore — единое хранилище данных и паблишеров
  - Repositories: протоколы + адаптеры к Store
  - Backup: структуры для экспорта/импорта
  - DI: AppContainer — контейнер зависимостей (store + репозитории)

Принципы:
- SOLID: разделение ответственности, работа через абстракции (репозитории), лёгкая расширяемость
- MVI: View → Intent → ViewModel → Repository/Store → Publisher → ViewModel.state → View

## Потоки данных (упрощённо)
```
UI(View) ── интент ──► ViewModel ──► Repository ──► Store
   ▲                                              │
   └───────────── ViewModel.state ◄── Publisher ──┘
```

## Структура проекта
```
wawe/
  Domain/
    Models.swift
  Data/
    Repositories.swift
    Backup.swift
    DI/
      AppContainer.swift
  Presentation/
    ViewModels/
      WordsMVI.swift
      VerbsMVI.swift
      QuestionsMVI.swift
  UI/
    Views/
      AboutView.swift
    Components/
      MarkdownEditor.swift
  ContentView.swift
```

Ключевые файлы:
- ContentView.swift — точки входа, TabView, экраны разделов, WordStore
- Presentation/ViewModels/*MVI.swift — ViewModel-и для разделов (состояние + интенты)
- Data/Repositories.swift — протоколы и адаптеры к WordStore
- Data/Backup.swift — экспорт/импорт, обратная совместимость
- Domain/Models.swift — бизнес-модели

## Навигация и UX
- Единый стиль: NavigationStack в каждом разделе
- Тулбар:
  - слева: «Тест» (запуск теста по текущему разделу)
  - справа: «+» (добавить элемент)
- Поиск: .searchable с live-фильтрацией через Intent .search
- Свайпы:
  - вправо: «+1 прогресс»
  - влево: «Удалить»
- Тема и акцент: системная/светлая/тёмная; в тёмной теме — синий акцент

## Сборка и запуск
- Откройте проект в Xcode (минимум Xcode 15 рекомендуется)
- Выберите платформу iOS или macOS
- Запустите (Cmd+R)

Хранилище (WordStore) использует UserDefaults и JSON-энкодинг для простого локального хранения; экспорт/импорт — через структуры BackupPayload/BackupSettings.

## Добавление фичи (гайд)
1. Domain: при необходимости добавьте модель в Domain/Models.swift
2. Data:
   - протокол в Data/Repositories.swift
   - адаптер (или реализацию) к Store/API
3. Presentation:
   - ViewModel (Intent + State) в Presentation/ViewModels
4. UI:
   - экран/компонент в UI/Views или UI/Components
5. Подключите навигацию и тулбар по общему паттерну

Рекомендуется использовать DI-контейнер (Data/DI/AppContainer.swift) для инициализации зависимостей вместо прямого создания адаптеров в экранах.

## Экспорт/импорт и диагностика
- Экспорт/импорт доступен из SettingsView:
  - Экспорт: сериализация текущих данных в JSON
  - Импорт: чтение JSON, обратная совместимость со старыми версиями
- Диагностика: запускает проверки базовых сценариев (добавление, прогресс)

## Платформенные нюансы
- iOS-модификаторы (textInputAutocapitalization, autocorrectionDisabled) применяются условно под iOS
- На macOS используется соответствующий .listStyle и тулбар-группы

## Кодстайл и соглашения
- SwiftUI, Combine, минимум побочных эффектов во View
- ViewModel-ы — ObservableObject, состояние @Published, интенты — enum
- Логика фильтрации/поиска — всегда в ViewModel
- Репозитории — абстракции, адаптеры к Store — в Data

## Дорожная карта (suggested)
- Полный переход на DI-контейнер в ContentView
- Разделение WordStore в отдельный файл Data/Store.swift
- Unit-тесты для ViewModel-ов и репозиториев
- Поддержка удалённого sync источника (замена/расширение Store)

## Монетизация и Доступ
- Уровни:
  - Бесплатный (Starter): базовые слова/глаголы/вопросы, ограниченные лимиты и простые тесты
  - Pro (Подписка): расширенные тесты, заметки (таблицы/картинки/markdown), расширенные лимиты, темы и бейджи
- Архитектура:
  - Entitlements: FeatureFlag‑ы определяют доступ (Free/Pro) для модулей
  - StoreKit 2: продукты подписки, проверка квитанций, статус entitlement локально + сервер (при появлении бэкенда)
  - DI: AppContainer выбирает реализации репозиториев/фич по уровню доступа
- Гейтинг функционала:
  - UI проверяет FeatureFlag через ViewModel/DI, показывает Paywall вместо недоступных действий
  - Стили и бейджи (VIP, DAY1, 10YR, Pro) доступны иконографически; активные — для Pro
- Поток оплаты:
  - Paywall экран: преимущества Pro, цены, кнопка подписки
  - Restore Purchases: восстановление через StoreKit в настройках
  - Синхронизация: при входе/восстановлении обновляется локальный entitlement и кэш
- Тестирование:
  - Моки StoreKit/Entitlements, UI‑тесты для гейтинга
  - Фичефлаги позволяют принудительно эмулировать уровни доступа

## Кодстайл (рекомендуется)
- Имена:
  - ViewModel: <Feature>ViewModel, интенты: <Feature>Intent, состояние: <Feature>ViewState
  - Репозитории: <Entity>Repository, адаптеры: <Entity>RepositoryStoreAdapter
  - Файлы: слой/назначение ясно из пути (Domain/Data/Presentation/UI)
- View:
  - Минимум логики во View, вся бизнес‑логика в ViewModel
  - .searchable и фильтрация — только через Intent .search
  - Стили листов: iOS .insetGrouped, macOS .automatic
- ViewModel:
  - @Published state только для чтения во View (.private(set))
  - bind(): подписки на паблишеры репозиториев/Store
  - filter(): нормализация ключа поиска (normalizedCompareKey), без побочных эффектов
- Репозитории:
  - Абстракции протоколов в Data/Repositories.swift
  - Адаптеры к Store (и далее к API) — через Combine
- Платформа:
  - iOS‑модификаторы (.textInputAutocapitalization, .autocorrectionDisabled) — только под iOS
  - Цвета не хардкодить в View, использовать AppColors/акцент

## Команды разработчика
- Сборка и запуск: Xcode → Cmd+R (iOS/macOS схемы)
- Проверка диагностик: Settings → «Проверить функционал»
- Экспорт/импорт: Settings → «Экспортировать/Импортировать данные»
- Lint/типизация:
  - Если команда есть в проекте — добавьте её в раздел «Команды» и используйте перед PR
  - Рекомендуется подключить SwiftLint (опционально) и правила под SwiftUI/MVI

## Интеграция API (план)
- Data:
  - Добавить APIClient, Endpoint‑ы, DTO
  - Реализовать RemoteRepository (Words/Verbs/Questions) с синхронизацией
  - Смешанный режим: Store как кэш, Remote как источник истины
- DI:
  - AppContainer: переключение Local/Remote через конфиг/фичефлаг
  - Тестирование: мок‑реализации репозиториев
- Миграции:
  - Экспорт/импорт остаются локально
  - Добавить версионирование схемы и миграции при переходе

## Вклад в проект (contributing)
- Ветки: feature/<name>, fix/<name>, docs/<name>
- PR: краткое описание задачи, скриншоты UI, список изменений по слоям
- Обязательные проверки (после подключения): lint, диагностические сценарии, базовые unit‑тесты

## FAQ
- Multiple commands produce '*.stringsdata':
  - Причина: дубликаты файлов (например, AboutView.swift/MarkdownEditor.swift/QuestionsMVI.swift) в нескольких папках
  - Решение: оставить единственную актуальную копию в соответствующих папках UI/… и Presentation/…
