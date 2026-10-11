# Подготовка PostgreSQL и запуск API

Гайд для новой локальной демонстрационной базы. [schema.sql](schema.sql) восстановлен по SQL-запросам и TypeScript-типам текущего API; это не дамп исходной базы и не миграция существующих данных.

## 1. Подготовьте окружение

Нужны Node.js 22.x, npm 10.x, Git и установленный [PostgreSQL 18 с клиентом psql](https://www.postgresql.org/download/). Сервер PostgreSQL должен быть запущен. Примеры ниже используют локальный сервер на порту 5432 и пользователя `postgres`; если у вас другие параметры, подставьте их.

```bash
git clone https://github.com/frendip/generator-dispatch-api.git
cd generator-dispatch-api
npm ci
createdb -h localhost -p 5432 -U postgres -W generator_dispatch
```

`createdb` запросит пароль PostgreSQL. Пользователь должен иметь право создавать базы; альтернативно создайте пустую базу `generator_dispatch` через pgAdmin.

## 2. Создайте таблицы и загрузите данные

Из корня репозитория выполните:

```bash
psql -X -h localhost -p 5432 -U postgres -W -d generator_dispatch \
  -v ON_ERROR_STOP=1 -1 \
  -f docs/schema.sql \
  -f src/sql/substations.table.sql \
  -f src/sql/bases.table.sql \
  -f src/sql/cars.table.sql
```

Команда создаёт таблицы и загружает данные в одной транзакции: при SQL-ошибке изменения откатятся. Запускайте её один раз на **пустой базе**. Существующие seed-файлы привязывают базы к подстанциям с ID 1 и 2, поэтому их нельзя бездумно добавлять к уже заполненной базе.

Получатся **104 подстанции, 2 базы и 11 автомобилей**. Таблицы маршрутов, текущего обслуживания и матрицы расстояний изначально пустые.

Какие таблицы нужны:

- `substations` — подстанции: ID, координаты, статус, мощность, название и адрес.
- `bases` — базы генераторов и их количество. `base_id` ссылается на `substations.substation_id`: база — это одна из подстанций.
- `cars` — автомобили, водители, перевозимые генераторы, координаты, статус и ссылка на базу.
- `cars_routes` — маршрут автомобиля между двумя подстанциями; поле `route` хранит точки, длительность и расстояние в JSONB.
- `repairing_substations` — связь автомобиля с обслуживаемой подстанцией.
- `distance_matrix` — время и расстояние от каждой базы до подстанций для подбора автомобиля.

Все столбцы, типы, внешние ключи и допустимые статусы описаны в [schema.sql](schema.sql). Координаты имеют тип PostgreSQL [`point`](https://www.postgresql.org/docs/18/datatype-geometric.html) и порядок **(долгота, широта)**; PostGIS не нужен. Время в базе и JSON маршрута хранится в секундах, расстояние — в метрах. Первичные ключи — целые числа; названия подстанций не уникальны, поскольку текущие демоданные содержат повторы.

## 3. Настройте соединение

Создайте в корне `.env`:

```dotenv
PORT=4000
DB_HOST=localhost
PGPORT=5432
DB_NAME=generator_dispatch
DB_USER=postgres
DB_PASS=YOUR_POSTGRES_PASSWORD
ROUTER_API_KEY=YOUR_YANDEX_ROUTING_API_KEY
GEOCODE_API_KEY=YOUR_YANDEX_GEOCODER_API_KEY
```

Подставьте пароль своей базы. Для чтения подстанций и автомобилей ключи Яндекса не нужны; они понадобятся для маршрутов, матрицы расстояний и геокодирования.

**Локальная база без TLS:** в своей рабочей копии `src/db.ts` замените `ssl: true` на `ssl: false`, только если PostgreSQL работает на вашем компьютере и `DB_HOST=localhost`. Переменной `DB_SSL` в приложении нет, поэтому изменение одного `.env` не отключит TLS.

**Удалённая база или локальная база с TLS:** оставьте `ssl: true`, укажите её адрес и настройте доверие к сертификату. При собственной CA настройте `ssl.ca` по [инструкции node-postgres](https://node-postgres.com/features/ssl). Параметры подключения `psql` тоже должны соответствовать выбранному серверу. Не переносите локальное `ssl: false` на удалённую базу.

## 4. Запустите и проверьте

```bash
npm run dev
```

В другом терминале:

```bash
curl http://localhost:4000/substations
curl http://localhost:4000/substations/bases
curl http://localhost:4000/cars
```

Ожидается JSON с `success: true` и непустым массивом `data`. Путь `/` возвращает 404 — это API, а не сайт.

После этого можно запускать [интерфейс диспетчера](https://github.com/frendip/generator-dispatch-web) и [приложение водителя](https://github.com/frendip/generator-dispatch-driver). Для их карт нужен отдельный клиентский ключ Yandex Maps JS API v3. Для первого автомобиля адрес приложения водителя — `http://localhost:3000/?driverId=1` (или порт, выбранный в его `.env`).

## 5. Если нужны маршруты и подбор автомобиля

С ключом Routing API, имеющим доступ к маршрутам и матрице расстояний, один раз заполните `distance_matrix`:

```bash
npx ts-node -e "import {fillDistanceMatrix} from './src/utils/fillDistanceMatrix'; import {pool} from './src/db'; fillDistanceMatrix().catch(err => { console.error(err); process.exitCode = 1; }).finally(() => pool.end());"
```

Эта функция **очищает матрицу расстояний** и запрашивает новые значения у Яндекса; учитывайте лимиты своего ключа. После добавления подстанций матрицу нужно обновить. Без неё `GET /substations/7/repair-cars` вернёт пустой список.

Для первого автомобиля из демоданных можно создать маршрут от его базы (ID 2) до подстанции 7:

```bash
curl -X POST http://localhost:4000/cars/1/route \
  -H "Content-Type: application/json" \
  -d '{"start_substation_id":2,"end_substation_id":7}'

curl http://localhost:4000/cars/1/route
```

До назначения маршрута ответ 404 на этот GET нормален. POST добавляет запись, а не заменяет её: не повторяйте запрос для автомобиля с уже существующим маршрутом. Назначение маршрута само по себе не запускает серверную имитацию движения.

## Если что-то не работает

- `relation ... does not exist` — схема не применена к базе, указанной в `.env`.
- `The server does not support SSL connections` — локальный PostgreSQL работает без TLS; проверьте шаг 3.
- `password authentication failed` — проверьте пользователя и пароль PostgreSQL.
- Ошибка маршрутизации / геокодирования — проверьте ключ, доступ к нужному сервису и квоту.
- Функцию `setDbData()` не нужно включать при каждом запуске: она очищает данные и сбрасывает ID.

Схема, исходные seed-файлы и операции контроллеров с БД проверены в изолированном PGlite 0.5.8 (PostgreSQL 18.3), с разбором координат как в используемом приложением `pg`. Сетевое подключение PostgreSQL/TLS и реальные запросы к Яндексу этой проверкой не покрываются.
