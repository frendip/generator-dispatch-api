# Generator Dispatch — API

Серверная часть системы доставки мобильных генераторов на подстанции. Предоставляет API для подстанций, баз, автомобилей и маршрутов, обращается к сервисам геокодирования и маршрутизации Яндекса и передаёт обновления клиентам через Socket.IO. В проекте также есть демонстрационная имитация движения автомобиля.

**Стек:** Node.js, TypeScript, Express, PostgreSQL, Socket.IO, Yandex Routing API и Геокодер.

## Требования

- Node.js 22.x, npm 10.x и Git.
- PostgreSQL с подготовленной схемой и данными проекта. Версия PostgreSQL в репозитории не зафиксирована.
- Подключение к PostgreSQL: по умолчанию в `src/db.ts` включён TLS. Настройка локальной базы без TLS описана в гайде ниже.
- Собственные ключи сервисов Яндекса для маршрутов / матрицы расстояний и геокодирования.

**Подготовка базы:** [короткий гайд](docs/database.md) объясняет создание шести таблиц, загрузку демоданных, настройку соединения и проверку API. Готовая [SQL-схема](docs/schema.sql) восстановлена по текущему коду и предназначена для новой демонстрационной базы; файлы `src/sql/*.table.sql` содержат начальные данные.

## Локальный запуск

Если запускаете проект с нуля, сначала выполните [гайд по подготовке PostgreSQL](docs/database.md). Ниже — команды для уже подготовленной базы.

1. Клонируйте репозиторий и установите зависимости:

   ```bash
   git clone https://github.com/frendip/generator-dispatch-api.git
   cd generator-dispatch-api
   npm ci
   ```

2. Создайте в корне файл `.env` и укажите свои значения:

   ```dotenv
   PORT=4000
   DB_HOST=localhost
   DB_NAME=generator_dispatch
   DB_USER=postgres
   DB_PASS=YOUR_POSTGRES_PASSWORD
   ROUTER_API_KEY=YOUR_YANDEX_ROUTING_API_KEY
   GEOCODE_API_KEY=YOUR_YANDEX_GEOCODER_API_KEY
   ```

   По умолчанию PostgreSQL использует порт `5432`; при необходимости задайте `PGPORT`. Файл `.env` исключён из Git. Серверные ключи не нужно передавать во frontend.

3. Запустите сервер:

   ```bash
   npm run dev
   ```

API будет доступен на `http://localhost:4000`, Socket.IO использует тот же порт. Корневой путь `/` не содержит страницы и возвращает 404; маршруты приложения начинаются с `/cars`, `/substations`, `/router` и `/geocode`.

Инициализация данных автоматически не запускается. Функции `setDbData` и `fillDistanceMatrix` очищают существующие таблицы и предназначены для подготовки демонстрационных данных.

## Проверка TypeScript

```bash
npx tsc --noEmit
```

Отдельные команды `npm run build` и `npm start` в проекте не настроены. Сервер разработки использует nodemon и ts-node.

## Связанные репозитории

- [generator-dispatch-web](https://github.com/frendip/generator-dispatch-web) — интерфейс диспетчера.
- [generator-dispatch-driver](https://github.com/frendip/generator-dispatch-driver) — приложение водителя.

Установка, проверка TypeScript и запуск HTTP-сервера проверены на Node.js 22.22.3 и npm 10.9.8. Схема и операции контроллеров с БД дополнительно проверены в PGlite (PostgreSQL 18.3); сетевое подключение PostgreSQL/TLS и реальные запросы к Яндексу не проверялись.
