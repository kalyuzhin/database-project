-- Настройка прокси для домена "Отзывы"
-- Создание расширения для работы с внешними данными
CREATE EXTENSION IF NOT EXISTS postgres_fdw;

-- Создание серверов для каждого шарда
CREATE SERVER reviews_shard1 FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS (host 'reviews_shard1', port '5432', dbname 'reviews');

CREATE SERVER reviews_shard2 FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS (host 'reviews_shard2', port '5432', dbname 'reviews');

-- Создание пользовательских маппингов
CREATE USER MAPPING FOR postgres SERVER reviews_shard1
    OPTIONS (user 'postgres', password 'postgres');

CREATE USER MAPPING FOR postgres SERVER reviews_shard2
    OPTIONS (user 'postgres', password 'postgres');

-- Создание внешних таблиц для каждого шарда
CREATE FOREIGN TABLE reviews_shard1 (
    id SERIAL,
    user_id INTEGER,
    user_mark DECIMAL(2,1) CHECK (
      user_mark IN (0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5, 4, 4.5, 5)
    ),
    criterion VARCHAR(255),
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    game_id INTEGER,
    jam_id INTEGER
) SERVER reviews_shard1 OPTIONS (schema_name 'public', table_name 'reviews');

CREATE FOREIGN TABLE reviews_shard2 (
    id SERIAL,
    user_id INTEGER,
    user_mark DECIMAL(2,1) CHECK (
      user_mark IN (0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5, 4, 4.5, 5)
    ),
    criterion VARCHAR(255),
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    game_id INTEGER,
    jam_id INTEGER
) SERVER reviews_shard2 OPTIONS (schema_name 'public', table_name 'reviews');

-- Создание представления, объединяющего все шарды
CREATE VIEW reviews AS
    SELECT * FROM reviews_shard1
    UNION ALL
    SELECT * FROM reviews_shard2;

-- Функция для определения шарда по ID пользователя
CREATE OR REPLACE FUNCTION get_review_shard(user_id INTEGER)
RETURNS TEXT AS $$
BEGIN
    IF MOD(user_id, 2)=0 THEN
        RETURN 'reviews_shard1';
    ELSIF MOD(user_id, 2)=1 THEN
        RETURN 'reviews_shard2';
    ELSE
        RAISE EXCEPTION 'Invalid user_id: %', user_id;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Функция для вставки отзыва в соответствующий шард
CREATE OR REPLACE FUNCTION insert_into_reviews_view()
RETURNS TRIGGER AS $$
DECLARE
  target_shard TEXT;
BEGIN
  IF NEW.user_id IS NULL THEN
    RAISE EXCEPTION 'user_id must be specified for insertion';
  END IF;

  target_shard := get_review_shard(NEW.user_id);

  IF target_shard = 'reviews_shard1' THEN
    INSERT INTO reviews_shard1(user_id, user_mark, criterion, created_at, updated_at, game_id, jam_id)
    VALUES (NEW.user_id, NEW.user_mark, NEW.criterion, NEW.created_at, NEW.updated_at, NEW.game_id, NEW.jam_id);
  ELSIF target_shard = 'reviews_shard2' THEN
    INSERT INTO reviews_shard2(user_id, user_mark, criterion, created_at, updated_at, game_id, jam_id)
    VALUES (NEW.user_id, NEW.user_mark, NEW.criterion, NEW.created_at, NEW.updated_at, NEW.game_id, NEW.jam_id);
  ELSE
    RAISE EXCEPTION 'Unknown shard: %', target_shard;
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Триггер для вставки отзыва
CREATE TRIGGER trg_insert_reviews
INSTEAD OF INSERT ON reviews
FOR EACH ROW
EXECUTE FUNCTION insert_into_reviews_view();

