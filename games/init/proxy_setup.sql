-- Настройка прокси для домена "Игры"
-- Создание расширения для работы с внешними данными
CREATE EXTENSION IF NOT EXISTS postgres_fdw;

-- Создание серверов для каждого шарда
CREATE SERVER games_shard1 FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS (host 'games_shard1', port '5432', dbname 'games');

CREATE SERVER games_shard2 FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS (host 'games_shard2', port '5432', dbname 'games');

CREATE SERVER jams_proxy_server FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS(
      host 'jams_proxy',
      port '5432',
      dbname 'jams'
  );

CREATE SERVER users_proxy_server FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS(
      host 'users_proxy',
      port '5432',
      dbname 'users'
  );

CREATE SERVER reviews_proxy_server FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS(
      host 'reviews_proxy',
      port '5432',
      dbname 'reviews'
  );

-- Создание пользовательских маппингов
CREATE USER MAPPING FOR postgres SERVER games_shard1
    OPTIONS (user 'postgres', password 'postgres');

CREATE USER MAPPING FOR postgres SERVER games_shard2
    OPTIONS (user 'postgres', password 'postgres');

CREATE USER MAPPING FOR CURRENT_USER SERVER jams_proxy_server
    OPTIONS (user 'postgres', password 'postgres');

CREATE USER MAPPING FOR CURRENT_USER SERVER users_proxy_server
    OPTIONS (user 'postgres', password 'postgres');

CREATE USER MAPPING FOR CURRENT_USER SERVER reviews_proxy_server
    OPTIONS (user 'postgres', password 'postgres');

-- Создание внешних таблиц для каждого шарда
CREATE FOREIGN TABLE games_shard1 (
    id INTEGER,
    name VARCHAR(60),
    description TEXT,
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    author_id INTEGER
) SERVER games_shard1 OPTIONS (schema_name 'public', table_name 'games');

CREATE FOREIGN TABLE games_shard2 (
    id INTEGER,
    name VARCHAR(60),
    description TEXT,
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    author_id INTEGER
) SERVER games_shard2 OPTIONS (schema_name 'public', table_name 'games');

CREATE FOREIGN TABLE jams (
    id INTEGER,
    name CHAR(1),
    author_id INTEGER,
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    start_date DATE,
    deadline DATE,
    end_date DATE,
    description TEXT
) SERVER jams_proxy_server OPTIONS (schema_name 'public', table_name 'jams');

CREATE FOREIGN TABLE users (
    id INTEGER,
    full_name VARCHAR(255),
    nickname VARCHAR(255),
    email VARCHAR(255),
    pswd_hash TEXT,
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    birthday DATE,
    phone_number CHAR(1),
    location VARCHAR(255)
) SERVER users_proxy_server OPTIONS (schema_name 'public', table_name 'users');

CREATE FOREIGN TABLE reviews (
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
) SERVER reviews_proxy_server OPTIONS (schema_name 'public', table_name 'reviews');

-- Создание представления, объединяющего все шарды
CREATE VIEW games AS
    SELECT * FROM games_shard1
    UNION ALL
    SELECT * FROM games_shard2;

-- Создание внешних таблиц для game_tags
CREATE FOREIGN TABLE game_tags_shard1 (
    id INTEGER,
    game_id INTEGER,
    tag_id INTEGER,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
) SERVER games_shard1 OPTIONS (schema_name 'public', table_name 'game_tags');

CREATE FOREIGN TABLE game_tags_shard2 (
    id INTEGER,
    game_id INTEGER,
    tag_id INTEGER,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
) SERVER games_shard2 OPTIONS (schema_name 'public', table_name 'game_tags');

CREATE VIEW game_tags AS
    SELECT * FROM game_tags_shard1
    UNION ALL
    SELECT * FROM game_tags_shard2;

-- Импорт справочных таблиц из первого шарда (они идентичны на всех шардах)
CREATE FOREIGN TABLE tags (
    id INTEGER,
    name TEXT,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
) SERVER games_shard1 OPTIONS (schema_name 'public', table_name 'tags');

-- Функция для определения шарда по ID игры
CREATE OR REPLACE FUNCTION get_game_shard(game_id INTEGER)
RETURNS TEXT AS $$
BEGIN
    IF MOD(game_id, 2)=0 THEN
        RETURN 'games_shard1';
    ELSIF MOD(game_id, 2)=1 THEN
        RETURN 'games_shard2';
    ELSE
        RAISE EXCEPTION 'Invalid game_id: %', game_id;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Функция для вставки игры в соответствующий шард
CREATE OR REPLACE FUNCTION insert_into_games_view()
RETURNS TRIGGER AS $$
DECLARE
  target_shard TEXT;
  generated_id INTEGER;
BEGIN
  IF NEW.id IS NULL THEN
    SELECT nextval('global_games_id_seq') INTO generated_id;
    NEW.id := generated_id;
  END IF;

  target_shard := get_game_shard(NEW.id);

  IF target_shard = 'games_shard1' THEN
        INSERT INTO games_shard1(id, name, description, created_at, updated_at, author_id)
    VALUES (NEW.id, NEW.name, NEW.description, NEW.created_at, NEW.updated_at, NEW.author_id);
  ELSIF target_shard = 'games_shard2' THEN
        INSERT INTO games_shard2(id, name, description, created_at, updated_at, author_id)
    VALUES (NEW.id, NEW.name, NEW.description, NEW.created_at, NEW.updated_at, NEW.author_id);
  ELSE
    RAISE EXCEPTION 'Unknown shard: %', target_shard;
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Триггер для вставки игры
CREATE TRIGGER trg_insert_games
INSTEAD OF INSERT ON games
FOR EACH ROW
EXECUTE FUNCTION insert_into_games_view();

-- Функция для вставки связи игры с тегом в соответствующий шард
CREATE OR REPLACE FUNCTION insert_into_game_tags_view()
RETURNS TRIGGER AS $$
DECLARE
  target_shard TEXT;
BEGIN
  IF NEW.game_id IS NULL THEN
    RAISE EXCEPTION 'game_id must be specified for insertion';
  END IF;

  target_shard := get_game_shard(NEW.game_id);

  IF target_shard = 'games_shard1' THEN
    INSERT INTO games_shard1(name, description, created_at, updated_at, author_id)
    VALUES (NEW.name, NEW.description, NEW.created_at, NEW.updated_at, NEW.author_id);
  ELSIF target_shard = 'games_shard2' THEN
    INSERT INTO games_shard2(name, description, created_at, updated_at, author_id)
    VALUES (NEW.name, NEW.description, NEW.created_at, NEW.updated_at, NEW.author_id);
  ELSE
    RAISE EXCEPTION 'Unknown shard: %', target_shard;
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Триггер для вставки связи игры с тегом
CREATE TRIGGER trg_insert_game_tags
INSTEAD OF INSERT ON game_tags
FOR EACH ROW
EXECUTE FUNCTION insert_into_game_tags_view();

CREATE SEQUENCE global_games_id_seq
START WITH 7
INCREMENT BY 1
NO MINVALUE
NO MAXVALUE
CACHE 1;