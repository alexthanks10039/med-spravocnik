# МедСправочник - Flutter-клиент

Flutter-клиент для двух локальных сервисов:

- `services/calculator-api` на порту `8080`;
- `services/knowledge-api` на порту `8090`.

Клиент поддерживает web/Windows-host, Android и iOS-проект. Проверенный рабочий
вариант на текущем компьютере - release Flutter web через local host.

Версия приложения: `0.0.0+1` (релиз `0.0.0.01`). Android APK/AAB и iOS IPA пока
не подтверждены как готовые релизные артефакты.

## Запуск всего проекта одной командой

Windows:

```powershell
.\start_project.bat
```

Из WSL:

```bash
./start_project.sh
```

Команда при необходимости пересобирает Flutter web, запускает оба изолированных
API и открывает приложение на `http://127.0.0.1:8787`. Для принудительной
пересборки используйте `start_project.bat -Rebuild`, для запуска без открытия
окна браузера - `start_project.bat -NoBrowser`.

## Отдельный запуск Flutter

```powershell
flutter pub get
flutter run --dart-define=CALCULATOR_API_URL=http://127.0.0.1:8080 --dart-define=KNOWLEDGE_API_URL=http://127.0.0.1:8090
```

Раздел «Протоколы» использует полнотекстовый поиск и presentation API. В UI
показываются нормализованные абзацы, списки, критерии, лабораторные значения,
лекарственные блоки и таблицы. Исходный OCR хранится в SQLite без изменений.

## Реализованные экраны

- каталог и поиск калькуляторов;
- динамическая форма расчёта и результат;
- каталог клинических протоколов и категории;
- полнотекстовый поиск по документам;
- карточка протокола с разделами, references и адаптивными таблицами;
- настройки URL и проверка доступности API.

Пока отсутствуют оглавление документа, просмотр исходного PDF/страницы цитаты,
избранное, история запросов и полноценный RAG-чат.

На физическом iPhone задайте доступные телефону HTTPS-адреса в настройках приложения или через `--dart-define`. Адрес `127.0.0.1` на iPhone не указывает на компьютер разработчика.

## Сборка iOS

Финальная iOS-сборка требует macOS, Xcode, Apple Developer Team и настроенный signing:

```bash
flutter pub get
flutter build ipa --release \
  --build-name=0.0.0 \
  --build-number=1 \
  --dart-define=CALCULATOR_API_URL=https://calculator.example.kz \
  --dart-define=KNOWLEDGE_API_URL=https://knowledge.example.kz
```

Архив появится в `build/ios/ipa/`.

## Установка на Windows

Если Visual Studio C++ toolchain недоступен, приложение устанавливается как локальное desktop web-приложение Edge с автоматическим запуском обоих API:

```powershell
flutter build web --release --dart-define=CALCULATOR_API_URL=http://127.0.0.1:8787/calculator --dart-define=KNOWLEDGE_API_URL=http://127.0.0.1:8787/knowledge
powershell -NoProfile -ExecutionPolicy Bypass -File tools\install_windows_web.ps1
```

Файлы устанавливаются в `%LOCALAPPDATA%\Programs\MedSpravochnik`, ярлыки создаются на рабочем столе и в меню «Пуск».

Общая документация проекта находится в корневой папке:

- [архитектура](../../docs/ARCHITECTURE.md);
- [установка](../../docs/SETUP.md);
- [структура](../../docs/PROJECT_STRUCTURE.md).
