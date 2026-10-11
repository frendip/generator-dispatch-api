-- Схема для новой демонстрационной БД, восстановленная по текущему API.
-- Это не дамп исходной БД и не миграция существующей базы.
-- Порядок координат POINT: (долгота, широта). PostGIS не требуется.

CREATE TABLE public.substations (
    substation_id SERIAL PRIMARY KEY,
    coordinates POINT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('active', 'disabled', 'waiting')),
    power INTEGER NOT NULL,
    name TEXT NOT NULL,
    address TEXT NOT NULL
);

-- База является подстанцией: отдельной последовательности для base_id нет.
CREATE TABLE public.bases (
    base_id INTEGER PRIMARY KEY REFERENCES public.substations(substation_id),
    generators_count INTEGER NOT NULL
);

CREATE TABLE public.cars (
    car_id SERIAL PRIMARY KEY,
    coordinates POINT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('onBase', 'delivered', 'inWork')),
    driver_name TEXT NOT NULL,
    generator_name TEXT NOT NULL,
    generator_power INTEGER NOT NULL,
    base_id INTEGER NOT NULL REFERENCES public.bases(base_id)
);

CREATE TABLE public.cars_routes (
    cars_route_id SERIAL PRIMARY KEY,
    car_id INTEGER NOT NULL REFERENCES public.cars(car_id),
    start_substation_id INTEGER NOT NULL REFERENCES public.substations(substation_id),
    end_substation_id INTEGER NOT NULL REFERENCES public.substations(substation_id),
    -- {points: [[lng, lat], ...], duration: секунды, distance: метры}
    -- Nullable: mockDriveRoute создаёт обратный маршрут без поля route.
    route JSONB
);

CREATE TABLE public.repairing_substations (
    repairing_substation_id SERIAL PRIMARY KEY,
    car_id INTEGER NOT NULL REFERENCES public.cars(car_id),
    substation_id INTEGER NOT NULL REFERENCES public.substations(substation_id)
);

CREATE TABLE public.distance_matrix (
    substation_id INTEGER NOT NULL REFERENCES public.substations(substation_id),
    base_id INTEGER NOT NULL REFERENCES public.bases(base_id),
    duration_time DOUBLE PRECISION NOT NULL,
    distance DOUBLE PRECISION NOT NULL,
    PRIMARY KEY (substation_id, base_id)
);

CREATE INDEX cars_base_id_idx ON public.cars(base_id);
CREATE INDEX cars_routes_car_id_idx ON public.cars_routes(car_id);
CREATE INDEX repairing_substations_car_id_idx ON public.repairing_substations(car_id);
